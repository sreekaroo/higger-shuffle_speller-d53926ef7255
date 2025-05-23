//#include "stdafx.h"
#include <afxwin.h>
#include <afxmt.h>
#include <iostream>
#include <fstream>
#include <string>
#include <deque>
#include <time.h>
#include <vector>
#include <algorithm>
#include <math.h>
#include "ringbuffer.h"
#include "gUSBamp.h"
#include "DAQgUSBamp.h"

// Constructor
DAQgUSBamp::DAQgUSBamp(std::vector<UCHAR> inputChannelList, int f, int trig, int BPF, int Notch, UCHAR mode, int comRef[4], int comGRN[4], std::vector<UCHAR> bipoSet)
{
	// Get total number of channels to be acquired
	numChannels = inputChannelList.size();

	// Sample rate in Hz
	SampleRate = f;
	NumScans = SampleRate / 32;
	TRIGGER = trig;
	_mode = mode;
	BPFindex = BPF;
	Notchindex = Notch;
	for (int i = 0 ; i < 4 ; i++) 
	{
		commonReference[i] = comRef[i];
		commonGround[i] = comGRN[i];
	}

	correctedChannelList.resize(MAX_NUMBER_OF_DEVICES);
	correctedBipolarSettings.resize(MAX_NUMBER_OF_DEVICES);
	numChannelsPerAmp.resize(MAX_NUMBER_OF_DEVICES, 0);

	for (int i = 0; i < MAX_NUMBER_OF_DEVICES; i++)
		correctedBipolarSettings[i].resize(MAX_NUMBER_OF_CHANNELS, 0); 

	ConvertAmpChannels(inputChannelList, bipoSet);

	writeToFile = false;

}

void DAQgUSBamp::ConvertAmpChannels(std::vector<UCHAR> inputChannelList, std::vector<UCHAR> bipoSet)
{	
	channelsToAcquire = inputChannelList;
	bipolarSettings = bipoSet;

	int channelCounter = 0;
	int deviceIndex = 0;
	UCHAR correctedChannelIndex = 0;

	for (int i = 0 ; i < channelsToAcquire.size(); i++) 
	{
		deviceIndex = (int) floorf((float) (channelsToAcquire[i]-1) / MAX_NUMBER_OF_CHANNELS);
		correctedChannelIndex = (UCHAR) fmod((float) channelsToAcquire[i]-1, (float) MAX_NUMBER_OF_CHANNELS) + 1;
		correctedChannelList[deviceIndex].push_back( correctedChannelIndex );
		
		correctedBipolarSettings[deviceIndex][correctedChannelIndex-1] = (UCHAR) fmod((float) bipolarSettings[channelsToAcquire[i]-1]-1, (float) MAX_NUMBER_OF_CHANNELS) + 1;
		
		numChannelsPerAmp[deviceIndex] += 1;		
	}

	numDevices = deviceIndex+1;
}

std::deque<std::string> DAQgUSBamp::FindDevice()
{
	std::deque<std::string> deviceSerialList;
	HANDLE hDevice; 

	const UINT uiSize = 16;	

	for (int usbIndex = 0 ; usbIndex < MAX_NUMBER_USB_PORTS; usbIndex++){
		hDevice = GT_OpenDevice(usbIndex);
		if (hDevice)
		{
			char tmpSerial[uiSize];
			if (GT_GetSerial(hDevice, tmpSerial, uiSize))
			{				
				deviceSerialList.push_back(std::string(tmpSerial));
				std::cout << "gUSBDevice "<< deviceSerialList.size() << "   " << tmpSerial <<"\n";
			} 
			GT_CloseDevice(&hDevice);
		}
	}

	return deviceSerialList;
}

bool DAQgUSBamp::OpenAndInitDevice()
{   
	//find the device
	bool successFlag = false;

	deviceSerialList = FindDevice();

	if (deviceSerialList.empty())
	{
		// error 1
		std::cout << "No device found "<< "\n";
		return successFlag;
	}
	
	//make sure that not more than one device is connected
	if (deviceSerialList.size() > 1)
	{
		std::cout << "\n";
		std::cout << "Warnning: More than one device is detected!" << "\n";
		std::cout << "For using more than one gUSBamp you should define master and slave devices!" << "\n";
		std::cout << "\n";
		numDevices = 1;
	}

	if (channelsToAcquire.size() > MAX_NUMBER_OF_CHANNELS) 
	{
		channelsToAcquire.resize(MAX_NUMBER_OF_CHANNELS);
		bipolarSettings.resize(MAX_NUMBER_OF_CHANNELS);
		correctedChannelList.resize(1);
		correctedBipolarSettings.resize(1);
		numChannels = MAX_NUMBER_OF_CHANNELS;
	}

	std::string usbSerial = deviceSerialList.front();	
	deviceSerialList.clear();
	deviceSerialList.push_back(usbSerial);

	successFlag = OpenAndInitDevice(deviceSerialList);
	return successFlag;
}

bool DAQgUSBamp::OpenAndInitDevice(std::deque<std::string> inputUsbSerials)
{   
	HANDLE hDevice;
	//find the device
	bool successFlag = false;

	if (numDevices != inputUsbSerials.size())
	{
		std::cout << "Number of devices from channels does not match serials" << std::endl;
		return successFlag;
	}

	deviceSerialList = inputUsbSerials;
	std::reverse(deviceSerialList.begin(), deviceSerialList.end());
	
	std::string masterDevice = deviceSerialList.back();		

	for (int deviceIndex=0; deviceIndex < numDevices; deviceIndex++)
	{
		//open the device
		hDevice = GT_OpenDeviceEx(const_cast<LPSTR>(deviceSerialList[deviceIndex].c_str()));

		//add the device handle to the list of opened devices
		deviceHandleList.push_back(hDevice);
		if (hDevice == NULL)
		{
			// error 1
			std::cout << "Could not open device "<< deviceIndex << "\n";
			return successFlag;
		}
		else
		{
			std::cout << " Device  "<< deviceIndex + 1 << " opened "<< "\n";
			successFlag = true;
		}
		//determine master device as the last device in the list
		bool isSlave = (deviceSerialList[deviceIndex] != masterDevice);

		//set slave/master mode of the device
		if (!GT_SetSlave(hDevice, isSlave))
		{
			// error 2
			std::cout << "Error on GT_SetSlave: Couldn't set slave/master mode for device "<< "\n";
		}
	
		ApplySettings(hDevice, correctedChannelList[numDevices-1-deviceIndex], correctedBipolarSettings[numDevices-1-deviceIndex], deviceIndex);

		//for g.USBamp devices set common ground and common reference
		if (strncmp(deviceSerialList[deviceIndex].c_str(), "U", 1) == 0 && (_mode == M_NORMAL || _mode == M_COUNTER))
		{
			//set the common reference
			REF RefSetting = {commonReference[0], commonReference[1], commonReference[2], commonReference[3]};
			//REF tmp = {0,0,0,0};
			if (!GT_SetReference(hDevice, RefSetting))
			{
				// error 3
				std::cout << "Error on GT_SetReference: Couldn't set common reference for device " << "\n";				
			}

			//set the common ground
			GND GNDSetting = {commonGround[0], commonGround[1], commonGround[2], commonGround[3]};
			if (!GT_SetGround(hDevice, GNDSetting))
			{
				// error 4
				std::cout << "Error on GT_SetGround: Couldn't set common ground for device " << "\n";
			}
		}
	}
	std::cout << "All gUSBamp devices are initialized! " << "\n";
	return successFlag;
}

//Apply all settings for each device
void DAQgUSBamp::ApplySettings(HANDLE h_device, std::vector<UCHAR> channelList, std::vector<UCHAR> bipolarSettings, int deviceIndex)
{
    int _trigger;

	//set trigger only for master device
	if (deviceIndex == numDevices-1)
		_trigger = TRIGGER;
	else 
		_trigger = 0;

	//set the channels from that data should be acquired
	if (!GT_SetChannels(h_device, &channelList[0], channelList.size()))
	{
		// error 5
		std::cout << "Error on GT_SetChannels: Couldn't set channels to acquire for device " << "\n";
	}

	//set the sample rate
	if (!GT_SetSampleRate(h_device, SampleRate))
	{
		// error 6
		std::cout << "Error on GT_SetSampleRate: Couldn't set sample rate for device " << "\n";
	}

	//disable the trigger line
	if (!GT_EnableTriggerLine(h_device, _trigger))
	{
		// error 7
		std::cout << "Error on GT_EnableTriggerLine: Couldn't enable/disable trigger line for device " << "\n";
	}

	//set the number of scans that should be received simultaneously
	if (!GT_SetBufferSize(h_device, NumScans))
	{
		// error 8
		std::cout << "Error on GT_SetBufferSize: Couldn't set the buffer size for device " << "\n";
	}
			
	for (int i=0; i < channelList.size(); i++)
	{
		//don't use a bandpass filter for any channel
		if (!GT_SetBandPass(h_device, channelList[i], BPFindex))
		{
			// error 9
			std::cout << "Error on GT_SetBandPass: Couldn't set no bandpass filter for device " << "\n";			
		}

		//don't use a notch filter for any channel
		if (!GT_SetNotch(h_device, channelList[i], Notchindex))
		{
			// error 10
			std::cout << "Error on GT_SetNotch: Couldn't set no notch filter for device " << "\n";
		}
	}

	//disable shortcut function
	if (!GT_EnableSC(h_device, false))
	{
		// error 11
		std::cout << "Error on GT_EnableSC: Couldn't disable shortcut function for device " << "\n";
	}
	
	CHANNEL bipolarSettingsStruct = {bipolarSettings[0], bipolarSettings[1], bipolarSettings[2], bipolarSettings[3], 
								bipolarSettings[4], bipolarSettings[5], bipolarSettings[6], bipolarSettings[7], 
								bipolarSettings[8], bipolarSettings[9], bipolarSettings[10], bipolarSettings[11], 
								bipolarSettings[12], bipolarSettings[13], bipolarSettings[14], bipolarSettings[15]};

	if (!GT_SetBipolar(h_device, bipolarSettingsStruct))
	{
		// error 12
		std::cout << "Error on GT_SetBipolar: Couldn't set unipolar derivation for device " << "\n";
	}

	if (_mode == M_COUNTER)
		if (!GT_SetMode(h_device, M_NORMAL))
		{
			// error 13
			std::cout << "Error on GT_SetMode: Couldn't set mode M_NORMAL (before mode M_COUNTER) for device " << "\n";
		}

	//set the acquisition mode
	if (!GT_SetMode(h_device, _mode))
	{
		// error 14
		std::cout << "Error on GT_SetMode: Couldn't set mode for device " << "\n";
	}

}

//Starts the thread that does the data acquisition.
void DAQgUSBamp::AmpCalibration()
{ 
	HANDLE hDevice;
	SCALE Scaling = {{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}};

	for (int i = 0; i < numDevices; i++)
	{
		hDevice = deviceHandleList[i];
		if (!GT_SetMode(hDevice, M_CALIBRATE))
		{
			// error 15
			std::cout << "Error on GT_SetMode: Could not enable calibration mode." << "\n";
		}
		if (!GT_GetScale(hDevice, &Scaling))
		{
			// error 16
			std::cout << "Error on GT_GetScale: Could not get the scaling values." << "\n";
		}
		if (!GT_Calibrate(hDevice, &Scaling))
		{
			// error 17
			std::cout << "Error on GT_Calibrate: Could not do calibration." << "\n";
		}
		if (!GT_SetScale(hDevice, &Scaling))
		{
			// error 18
			std::cout << "Error on GT_SetScale: Could not set the scaling values." << "\n";
		}
		else
			std::cout << "Calibration is performed successfully." << "\n";
	}
}

void DAQgUSBamp::PrintFilterInfo(int filterIndex)
{ 
	int nFilters = 0;
	GT_GetNumberOfFilter(&nFilters);	
	FILT *FilterSpec = new FILT[nFilters];
	GT_GetFilterSpec(FilterSpec);	
	std::cout << "filter #" << filterIndex << std::endl;
	std::cout << "	fu:" << FilterSpec[filterIndex].fu << std::endl;
	std::cout << "	fo:" << FilterSpec[filterIndex].fo << std::endl;
	std::cout << "	fs:" << FilterSpec[filterIndex].fs << std::endl;
	std::cout << "	type:" << FilterSpec[filterIndex].type << std::endl;
	std::cout << "	order:" << FilterSpec[filterIndex].order << std::endl;

	delete [] FilterSpec;
}

void DAQgUSBamp::PrintNotchInfo(int filterIndex)
{ 
	int nFilters = 0;
	GT_GetNumberOfNotch(&nFilters);	
	FILT *FilterSpec = new FILT[nFilters];
	GT_GetNotchSpec(FilterSpec);	
	std::cout << "filter #" << filterIndex << std::endl;
	std::cout << "	fu:" << FilterSpec[filterIndex].fu << std::endl;
	std::cout << "	fo:" << FilterSpec[filterIndex].fo << std::endl;
	std::cout << "	fs:" << FilterSpec[filterIndex].fs << std::endl;
	std::cout << "	type:" << FilterSpec[filterIndex].type << std::endl;
	std::cout << "	order:" << FilterSpec[filterIndex].order << std::endl;

	delete [] FilterSpec;
}


//Starts the thread that does the data acquisition
void DAQgUSBamp::StartAcquisition()
{
	_isRunning = true;
	_bufferOverrun = false;
	int modestatus;

	for (int deviceIndex=0; deviceIndex < numDevices; deviceIndex++)
	{
		modestatus = GT_SetMode(deviceHandleList[deviceIndex], _mode);
	}

	//give main process (the data processing thread) high priority
	HANDLE hProcess = GetCurrentProcess();
	SetPriorityClass(hProcess, HIGH_PRIORITY_CLASS);

	//initialize application data buffer to the specified number of seconds
	_buffer.Initialize(BUFFER_SIZE_SECONDS * SampleRate * (numChannels + TRIGGER));

	//reset event
	_dataAcquisitionStopped.ResetEvent();

	//create data acquisition thread with high priority
	_dataAcquisitionThread = AfxBeginThread(StaticThreadProc, this, THREAD_PRIORITY_TIME_CRITICAL, 0, 0, NULL);
	_dataAcquisitionThread->ResumeThread();

	std::cout << " started!" << "\n";
}

//Starts the thread and generates a file from measured data
void DAQgUSBamp::StartAcquisition(const char *FileName)
{  
	std::cout << "opening file" << std::endl;

	// check the output file
	if (!outputFile.Open(FileName, CFile::modeCreate | CFile::modeWrite | CFile::typeBinary))
	{
		// error 19
		std::cout <<"Error on creating/opening output file: the file couldn't be opened." << "\n";
	}

	// Write file header
	outputFile.Write(&DAQ_VERSION, 1 * sizeof(int));
	outputFile.Write(&SampleRate, 1 * sizeof(int));
	outputFile.Write(&numChannels, 1 * sizeof(UCHAR));
	outputFile.Write(&TRIGGER, 1 * sizeof(int));
	outputFile.Write(&channelsToAcquire[0], numChannels * sizeof(UCHAR));

	writeToFile = true;

	// Call start acquisition method with no arguments
	StartAcquisition();

}

//Stops the data acquisition thread
void DAQgUSBamp::StopAcquisition()
{
	//tell thread to stop data acquisition
	_isRunning = false;

	//wait until the thread has stopped data acquisition
	DWORD ret = WaitForSingleObject(_dataAcquisitionStopped.m_hObject, 60000);

	//reset the main process (data processing thread) to normal priority
	HANDLE hProcess = GetCurrentProcess();
	SetPriorityClass(hProcess, NORMAL_PRIORITY_CLASS);
	//close output file
	if (writeToFile)
		outputFile.Close();

	_buffer.Reset();

	writeToFile = false;
}

UINT DAQgUSBamp::DoAcquisition()
{
	int _trigger[MAX_NUMBER_OF_DEVICES];
	int queueIndex = 0;
	int _NPoints = NumScans * (numChannels + TRIGGER);
	DWORD numBytesReceived = 0;
	// This variable ....
	const int QUEUE_SIZE = 4;

	//create the temporary data buffers (the device will write data into those)
	BYTE*** buffers = new BYTE**[numDevices];
	OVERLAPPED** overlapped = new OVERLAPPED*[numDevices];

	__try 
	{
		//for each device create a number of QUEUE_SIZE data buffers
		for (int deviceIndex=0; deviceIndex < numDevices; deviceIndex++)
		{
			if (deviceIndex == numDevices-1)
				_trigger[deviceIndex] = TRIGGER;
			else 
				_trigger[deviceIndex] = 0;

			int nPoints = NumScans * (numChannelsPerAmp[deviceIndex] + _trigger[deviceIndex]);
			DWORD bufferSizeBytes = HEADER_SIZE + nPoints * sizeof(float);

			buffers[deviceIndex] = new BYTE*[QUEUE_SIZE];
			overlapped[deviceIndex] = new OVERLAPPED[QUEUE_SIZE];

			//for each data buffer allocate a number of bufferSizeBytes bytes
			for (queueIndex=0; queueIndex < QUEUE_SIZE; queueIndex++)
			{
				buffers[deviceIndex][queueIndex] = new BYTE[bufferSizeBytes];
				memset(&(overlapped[deviceIndex][queueIndex]), 0, sizeof(OVERLAPPED));

				//create a windows event handle that will be signalled when new data from the device has been received for each data buffer
				overlapped[deviceIndex][queueIndex].hEvent = CreateEvent(NULL, false, false, NULL);
			}
		}

		//start the devices (master device must be started at last)
		for (int deviceIndex=0; deviceIndex < numDevices; deviceIndex++)
		{
			int nPoints = NumScans * (numChannelsPerAmp[deviceIndex] + _trigger[deviceIndex]);
			DWORD bufferSizeBytes = HEADER_SIZE + nPoints * sizeof(float);

			HANDLE hDevice = deviceHandleList[deviceIndex];

			if (!GT_Start(hDevice))
			{
				// error 20
				std::cout << "\tError on GT_Start: Couldn't start data acquisition of device.\n";
				return 0;
			}

			//queue-up the first batch of transfer requests
			for (queueIndex=0; queueIndex <QUEUE_SIZE; queueIndex++)
			{
				if (!GT_GetData(hDevice, buffers[deviceIndex][queueIndex], bufferSizeBytes, &overlapped[deviceIndex][queueIndex]))
				{
					// error 21
					std::cout << "\tError on GT_GetData.\n";
					return 0;
				}
			}
		}

		queueIndex = 0;

		//continouos data acquisition
		while (_isRunning) 
		{
			//receive data from each device
			for (int deviceIndex = 0; deviceIndex < numDevices; deviceIndex++)
			{
				int nPoints = NumScans * (numChannelsPerAmp[deviceIndex] + _trigger[deviceIndex]);
				DWORD bufferSizeBytes = HEADER_SIZE + nPoints * sizeof(float);

				//wait for notification from the system telling that new data is available
				if (WaitForSingleObject(overlapped[deviceIndex][queueIndex].hEvent, 1000) == WAIT_TIMEOUT)
				{
					// error 22
					std::cout << "Error on data transfer: timeout occurred." << "\n";
					return 0;
				}
				//get number of received bytes...
				GetOverlappedResult(deviceHandleList[deviceIndex], &overlapped[deviceIndex][queueIndex], &numBytesReceived, false);
			
				//check if we lost something (number of received bytes must be equal to the previously allocated buffer size)
				if (numBytesReceived != bufferSizeBytes)
				{
					// error 23
					std::cout << "Error on data transfer: samples lost." << "\n";
					return 0;
				}
			}

			//to store the received data into the application data buffer at once, lock it
			_bufferLock.Lock();

			float * bufferAddress;

			__try 
			{
				//if we are going to overrun on writing the received data into the buffer, set the appropriate flag; the reading thread will handle the overrun
				_bufferOverrun = (_buffer.GetFreeSize() < _NPoints);

				//store received data from each device in the correct order (that is scan-wise, where one scan includes all channels of all devices) ignoring the header
				for (int scanIndex = 0; scanIndex < NumScans; scanIndex++)
				{
					// start from master
					for (int deviceIndex=numDevices-1; deviceIndex >= 0; deviceIndex--)
					{
						// get address of data 
						bufferAddress = (float*) (buffers[deviceIndex][queueIndex] + scanIndex * (numChannelsPerAmp[deviceIndex] + _trigger[deviceIndex]) * sizeof(float) + HEADER_SIZE);

						// if device index is master
						if (deviceIndex==numDevices-1)
						{
							// write only channel data
							_buffer.Write(bufferAddress, numChannelsPerAmp[deviceIndex]);
							if (writeToFile)
								outputFile.Write(bufferAddress, numChannelsPerAmp[deviceIndex] * sizeof(float));
						} // for the other devices
						else 
						{
							// write the data and triggers (none existing in current implementation)
							_buffer.Write(bufferAddress, numChannelsPerAmp[deviceIndex] + _trigger[deviceIndex]);
							if (writeToFile)
								outputFile.Write(bufferAddress, (numChannelsPerAmp[deviceIndex] + _trigger[deviceIndex]) * sizeof(float));
						}
						
					}
					
					// after all devices have been process, write trigger data only
					bufferAddress = (float*) (buffers[numDevices-1][queueIndex] + numChannelsPerAmp[numDevices-1] * sizeof(float) + scanIndex * (numChannelsPerAmp[numDevices-1] + _trigger[numDevices-1]) * sizeof(float) + HEADER_SIZE);
					_buffer.Write(bufferAddress, _trigger[numDevices-1]);
					if (writeToFile)
						outputFile.Write(bufferAddress, (_trigger[numDevices-1]) * sizeof(float));
				}
			} 
			__finally 
			{
				//release the previously acquired lock
				_bufferLock.Unlock();
			}

			//add new GetData call to the queue replacing the currently received one
			for (int deviceIndex = 0; deviceIndex < numDevices; deviceIndex++)
			{
				int nPoints = NumScans * (numChannelsPerAmp[deviceIndex] + _trigger[deviceIndex]);
				DWORD bufferSizeBytes = HEADER_SIZE + nPoints * sizeof(float);

				if (!GT_GetData(deviceHandleList[deviceIndex], buffers[deviceIndex][queueIndex], bufferSizeBytes, &overlapped[deviceIndex][queueIndex]))
				{
					// error 24
					std::cout << "\tError on GT_GetData.\n";

					return 0;
				}
			}

			//signal processing (main) thread that new data is available
			_newDataAvailable.SetEvent();
			
			//increment circular queueIndex to process the next queue at the next loop repitition (on overrun start at index 0 again)
			queueIndex = (queueIndex + 1) % QUEUE_SIZE;
		}
	}
	__finally
	{
		std::cout << "Stopping devices and cleaning up..." << "\n";

		//clean up allocated resources for each device
		for (int i=0; i < numDevices; i++)
		{

			//clean up allocated resources for each queue per device
			for (int j=0; j < QUEUE_SIZE; j++)
			{
				WaitForSingleObject(overlapped[i][queueIndex].hEvent, 1000);
				CloseHandle(overlapped[i][queueIndex].hEvent);

				delete [] buffers[i][queueIndex];

				//increment queue index
				queueIndex = (queueIndex + 1) % QUEUE_SIZE;
			}

			//stop device
			GT_Stop(deviceHandleList[i]);

			//reset device
			GT_ResetTransfer(deviceHandleList[i]);

			delete [] overlapped[i];
			delete [] buffers[i];
		}

		delete [] buffers;
		delete [] overlapped;

		//reset _isRunning flag
		_isRunning = false;

		//signal event
		_dataAcquisitionStopped.SetEvent();

		//end thread
		AfxEndThread(0xdead);
	}

	return 0xdead;
}

UINT DAQgUSBamp::StaticThreadProc(LPVOID param)
{
	// Cast user parameter to type DAQgUSBamp
	DAQgUSBamp* pThis = reinterpret_cast<DAQgUSBamp*>(param);
	if ( pThis != NULL )
	{
		// Run acquisition loop
		pThis->DoAcquisition();
	}

	return (0);
}

bool DAQgUSBamp::GetDataFromBuffer(float *destBuffer, int NumSamples)
{
	int validPoints = (numChannels + TRIGGER) * NumSamples;
	
	//wait until requested amount of data is ready
	if (_buffer.GetSize() < validPoints)
	{
		// error 25
		std::cout << "Not enough data available"<< "\n";
		return false;
	}

	//acquire lock on the application buffer for reading
	_bufferLock.Lock();

	__try
	{
		//if buffer run over report error and reset buffer
		if (_bufferOverrun)
		{
			_buffer.Reset();
			// error 26
			std::cout << "Error on reading data from the application data buffer: buffer overrun."<< "\n";

			_bufferOverrun = false;
			return false;
		}

		//copy the data from the application buffer into the destination buffer
		_buffer.Read(destBuffer, validPoints);
	}
	__finally
	{
		_bufferLock.Unlock();
	}
	return true;
}

int DAQgUSBamp::AvailableSamples()
{ 
	int numberOfSamples;
	numberOfSamples = _buffer.GetSize() / (numChannels + TRIGGER);
	return numberOfSamples;
}

void DAQgUSBamp::GetData(float * destBuffer, int  NumSamples)
{
	
	//to stop the application after a specified time, get start time
	while (AvailableSamples() < NumSamples)
	{
		WaitForSingleObject(_newDataAvailable.m_hObject, 100);
	}
	
	//read data from the application buffer and stop application if buffer overrun
	GetDataFromBuffer(destBuffer, NumSamples);

}

void DAQgUSBamp::SendTrigger(bool * state)
{
	
	DigitalOUT dout = {1, state[0], 1, state[1], 1, state[2], 1, state[3]};
	//select master device 
	HANDLE hDevice = deviceHandleList[numDevices-1];
	if (TRIGGER)
		BOOL status = GT_SetDigitalOutEx(hDevice, dout);	
	
}

void DAQgUSBamp::CloseDevice()
{
	std::cout << "Closing devices...\n";
	while (!deviceHandleList.empty())
	{
		//closes each opened device and removes it from the call sequence
		GT_Stop(&deviceHandleList.front());
		BOOL ret = GT_CloseDevice(&deviceHandleList.front());
		deviceHandleList.pop_front();
	}

	deviceSerialList.clear();
	if (writeToFile)
		outputFile.Close();
}

// Destructor
DAQgUSBamp::~DAQgUSBamp() {
	std::cout << "Runnig destructor\n";
	CloseDevice();
}
