//_____________________________________________________________________________
//    DAQgUSBamp.h 
//
//	  Created: Oct 2015
//   
//_____________________________________________________________________________
//

#ifndef DAQGUSBAMP_H
#define DAQGUSBAMP_H

#include <afxwin.h>
#include <afxmt.h>
#include <string>
#include <deque>
#include <vector>
#include "ringbuffer.h"

class DAQgUSBamp	
{
private:

	// DAQ version
	static const int DAQ_VERSION = 1;

	// The size of the application buffer in seconds
	static const int BUFFER_SIZE_SECONDS = 1800;		
	
	// The number of GT_GetData calls that will be queued during acquisition to avoid loss of data
    static const int QUEUE_SIZE = 4;

	// Maximum number of channels per amplifier
	static const int MAX_NUMBER_OF_CHANNELS = 16;
	
	// Maximum number of gusbamps that can be connected
	static const int MAX_NUMBER_OF_DEVICES = 4;

	// Maximum number of USB ports to check
	static const int MAX_NUMBER_USB_PORTS = 31;

	// Flag that indicates if the thread is currently running
	bool _isRunning;						
	
	// Flag indicating if an overrun occurred at the application buffer
	bool _bufferOverrun;                    
	
	// Size of internal gusbamp buffer
	int NumScans;
	
	// Mutex used to manage concurrent thread access to the class data buffer
	CMutex _bufferLock;				
	
	// The thread that performs data acquisition
	CWinThread* _dataAcquisitionThread;		
	
	// The application buffer where received data will be stored for each device
	CRingBuffer<float> _buffer;				
	
	// Event that signals that data acquisition thread has been stopped
	CEvent _dataAcquisitionStopped;			
	
	// Event to avoid polling the application data buffer for new data
	CEvent _newDataAvailable;				
	
	// File where acquisition loop is storing the data
	CFile outputFile;             

	// Serial number of all devices. Master is last
	std::deque<std::string> deviceSerialList;   

	// Handle of the devices or NULL if opening fails. Master is last
	std::deque<HANDLE> deviceHandleList;	

	// Number of channels per amplifier
	std::vector<UCHAR> numChannelsPerAmp;

	// Channel array for each amplifier. Master is first
	std::vector< std::vector<UCHAR> > correctedChannelList;

	// bipolar settings for each amplifier. Master is first
	std::vector< std::vector<UCHAR> > correctedBipolarSettings;
	
	// Number of devices connected (or computed from channel vector)
	int numDevices;

	// Boolean set in StartAcquisition to check if a file will be written
	bool writeToFile;

	// Function to return a list of the serial number of connected devices
	std::deque<std::string> FindDevice();                          

	// Converts a vector of channel list and bipolar settings to a vector of channel lists for each amp
	void ConvertAmpChannels(std::vector<UCHAR> inputChannelList, std::vector<UCHAR> bipoSet);	

	// Read the available data from the application buffer and move into the destination buffer
	bool GetDataFromBuffer(float *destBuffer, int NumSamples);                           
	
	// Applies individual channel settings to given device (handle)
	void ApplySettings(HANDLE h_device, std::vector<UCHAR> channelList, std::vector<UCHAR> bipolarSettings, int deviceIndex);

protected:

	// Function that runs acquisition loop (thread)
	UINT DoAcquisition();

public:

	// Total number of channels to be acquired
	UCHAR numChannels;

	/* Mode: M_NORMAL (Acquires data from the 16 input channels)
	         M_CALIBRATE (Calibrates the input channels by Applying a calibration signal onto all input channels)
		     M_IMPEDANCE (Measures the electrode impedance)
			 M_COUNTER (Applies a counter on channel 16 if selected for acquisition (overrun at 1e6)) */
	UCHAR _mode;                         

	// Possible sampling rates: 2^n, for all n in [5, 16] interval.  
	int SampleRate;

	// Band-pass filter index (Please check the manual to use correct numbers)
	int BPFindex;
	
	// Notch filter index (Please check the manual to use correct numbers)
	int Notchindex;                      
	
	// Vecotr with common reference status for the 4 electrode groups
	int commonReference[4];							
	
	// Vecotr with common ground status for the 4 electrode groups
	int commonGround[4];	
	
	// 1 if trigger channel is enabled. 0 otherwise
	int TRIGGER;                                   
	
	// Bipolar label for each electrode. For instance, [2 3 0] means that the output will be chan1-chan2, chan2-chan3, and chan3
	std::vector<UCHAR> bipolarSettings;            
	
	// Channels to be used in data collection starting from 1 to N
	std::vector<UCHAR> channelsToAcquire;                                               
	
	// Constructor with full parametrization
	DAQgUSBamp(std::vector<UCHAR> ChToAcq, int f, int trig, int BPF, int Notch, UCHAR mode, int comRef[4], int comGRN[4], std::vector<UCHAR> bipoSet);
	
	// Custom destructor
	~DAQgUSBamp();                          

	// Finds the USB device, initializes the port for acquisition 
	bool OpenAndInitDevice();                                                 
	
	// Opens and initializes each device in deque according to serial
	bool OpenAndInitDevice(std::deque<std::string> inputUsbSerials);
	
	// Does Calibration for all channels
	void AmpCalibration();                                        
	
	// Starts acquisition loop
	void StartAcquisition();
	
	// Starts acquisition loop and stores data to file
	void StartAcquisition(const char *FileName);      
	
	// Stops the data acquisition thread
	void StopAcquisition();                                                     
	
	// Closes the gUSBamp identified by the handle
	void CloseDevice();                                                         
		
	// Static funtion that will be passed to the thread function
	static UINT StaticThreadProc(LPVOID param); 

	// Collects NumSamples data and puts it to data buffer and will saved all of the data in FileName file 
	void GetData(float *destBuffer, int  NumSamples);                             
	
	// Gets number of samples available in buffer
	int AvailableSamples();
	
	// Prints filter information given filter index
	void PrintFilterInfo(int filterIndex);
	
	// Prints notch filter information given filter index
	void PrintNotchInfo(int filterIndex);
	
	// Sends 4 bit trigger
	void SendTrigger(bool * state);

};
#endif
