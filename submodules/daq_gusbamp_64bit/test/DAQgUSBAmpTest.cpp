
#include "DAQgUSBamp.h"
#include <Windows.h>
#include <iostream>
#include <string>
#include <deque>

using namespace std;

void main()
{
	//int NumScans;
	int SampleRate = 256;
	int BPF = 49;
	int Notch = 3;
	int TRIGGER = 0;
	UCHAR mode = 0;
	long NumSec = 10; 
	int ComR[4] = {1, 1, 1 ,1};							//don't connect groups to common reference
	int ComG[4] = {1, 1, 1, 1};									//don't connect groups to common ground
	
	UCHAR bipolarSettingsArray[] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
	std::vector<UCHAR> bipolarSettings(bipolarSettingsArray, bipolarSettingsArray + sizeof(bipolarSettingsArray)/sizeof(bipolarSettingsArray[0]));
	UCHAR ChToAcqArray[] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
	std::vector<UCHAR> ChToAcq(ChToAcqArray, ChToAcqArray + sizeof(ChToAcqArray)/sizeof(ChToAcqArray[0]));

	const char* Filename = "data.bin";
	int NumSamples = 1000;
	float *data = new float[NumSamples * (ChToAcq.size() + TRIGGER)];
	
	//LPSTR AllSerials[] = {"UB-2013.06.13","UB-2009.07.05","UB-2013.06.12"};
	//std::vector<LPSTR> ListedSerials(AllSerials, AllSerials + sizeof(AllSerials)/sizeof(AllSerials[0]));
	
	DAQgUSBamp daq(ChToAcq, SampleRate, TRIGGER, BPF, Notch, mode, ComR, ComG, bipolarSettings);
	
	//find and initialize the device

	//daq.OpenAndInitDevice();
	//daq.AmpCalibration();
	//daq.CloseDevice();

	//daq.PrintFilterInfo(BPF);
	//daq.PrintNotchInfo(Notch);

	// string serialNumberStr("UB-2013.06.13");
	//std::deque<string> serialNumber;
	//serialNumber.push_back(serialNumberStr);

	if (daq.OpenAndInitDevice())
	{
		//daq.OpenAndInitDevice();
		daq.StartAcquisition(Filename);	

		//do acquistion
		daq.GetData(data, NumSamples);
 
		daq.StopAcquisition();
		daq.CloseDevice();
	}
	delete[] data;

	std::cout << "Clean up complete. Bye bye!" << "\n";	
    system("pause>nul");
}
