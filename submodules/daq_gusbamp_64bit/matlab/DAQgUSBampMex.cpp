// This mex function works as a link between the matlab class and the c++ class.
// Since this is a function and not a class, no state can be preserved (ie object instances between mex calls)
// The trick is to allocate a new object of daqgusbamp type, cast the pointer to an int pointer and
// output it so that it gets preserved in the matlab class. Then, with each new call to mex, the pointer is passed
// and casted to its original type, thus enabling execution of its methods and preservation of state.
// Mex can execute the methods with string commands passed from the matlab class. It's a little complicated,
// but it works well in practice. 
//
// The pointer to int conversion is handled by class_handle.hpp. This function only requires the DAQgUSBAmp.h header
// The mex function is compiled statically, so there is no need for the CAPI from gtec or the CSL DAQ lib during runtime

// Use dynamic AFX
#define _AFXDLL
#include <afx.h>
#include <string>
#include "mex.h"
#include "class_handle.hpp"
#include "DAQgUSBamp.h"

using namespace std;

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{	                                                	                                           
	// Get the command string
    char cmd[64];
	if (nrhs < 1 || mxGetString(prhs[0], cmd, sizeof(cmd)))
		mexErrMsgTxt("First input should be a command string less than 64 characters long.");
        
    // New: command to create a new object of type daq
    // Usage: 
    //             DAQgUSBampMex('new', uint8(numChannels), ...
    //                      uint8(self.channelList), int32(self.fs), ...
    //                      int32(self.triggerFlag), int32(self.ampFilterNdx),... 
    //                      int32(self.notchFilterNdx), uint8(ampMode), ...
    //                      int32(self.commonReference), int32(self.commonGround), ...
    //                      uint8(self.bipolarSettings));
    if (!strcmp("new", cmd)) 
    {        
        // Check parameters
        if (nlhs != 1 || nrhs != 11)
            mexErrMsgTxt("DAQgUSBamp: One output expected.");
        
        // Constructor parameters. Type checking is important here so this assumes that 
        // the correct types are sent from matlab
        unsigned char NumChannels = mxGetScalar(prhs[1]);
        unsigned char * tmpChannelArray = (unsigned char *)  mxGetData(prhs[2]);        
        std::vector<unsigned char> channelsToAcquire(tmpChannelArray, tmpChannelArray + NumChannels);
        unsigned char _mode = mxGetScalar(prhs[7]) ;                         									         
        int SampleRate = mxGetScalar(prhs[3]); 
        int TRIGGER =  mxGetScalar(prhs[4]);                                                              
        int BPFindex = mxGetScalar(prhs[5]);                     
        int Notchindex = mxGetScalar(prhs[6]);                     
        int * commonReference = (int *) mxGetData(prhs[8]);							
        int * commonGround = (int *) mxGetData(prhs[9]);	
        unsigned char * tmpBipolarArray = (unsigned char *)  mxGetData(prhs[10]);
        std::vector<unsigned char> bipolarSettings(tmpBipolarArray, tmpBipolarArray + NumChannels);
        
        // Return a handle to a new C++ instance
        plhs[0] = convertPtr2Mat<DAQgUSBamp>(new DAQgUSBamp( 
                channelsToAcquire, SampleRate, TRIGGER, BPFindex, 
                Notchindex, _mode, commonReference, commonGround, bipolarSettings));
        return;
    }
    
    // Check there is a second input, which should be the class instance handle
    if (nrhs < 2)
		mexErrMsgTxt("Second input should be a class instance handle.");
    
    // Delete: command to delete and deallocate object
    // Usage:
    //      DAQgUSBampMex('DeleteAll', self.objectHandle);
    if (!strcmp("DeleteAll", cmd)) 
    {        
        // Destroy the C++ object
        destroyObject<DAQgUSBamp>(prhs[1]);
        
        // Warn if other commands were ignored
        if (nlhs != 0 || nrhs != 2)
            mexWarnMsgTxt("Delete: Unexpected arguments ignored.");
        return;
    }
    
    // Get the class instance pointer from the second input
    DAQgUSBamp * DAQgUSBampObj = convertMat2Ptr<DAQgUSBamp>(prhs[1]);
       
    // Call the various class methods
    
    // OpenDevice: command to open and init device
    // Usage:
    //      DAQgUSBampMex('OpenDevice', self.objectHandle);
    //      DAQgUSBampMex('OpenDevice', self.objectHandle, ListedSerials);
    if (!strcmp("OpenDevice", cmd)) 
    {
        bool success = false;
        // Check parameters
        if (nlhs != 1 || nrhs!=3)
            mexErrMsgTxt("OpenDevice: Unexpected arguments.");

        size_t inputlen = mxGetN(prhs[2]) + 1;
        
        // if USBserial number is not specified
        if (inputlen == 1)
        {
            mexPrintf("No device is specified. The last detected gUSB will be selected as a master device.\n");
            success = DAQgUSBampObj->OpenAndInitDevice();
        }
        else
        {
            // Get list of all gUSBamp. The master device always should be the first one.
            mwSize total_num_of_cells = mxGetNumberOfElements(prhs[2]);
            char* USBserial;
            int checkflag = 0;
            std::deque<std::string> ListedSerials;
            
             for (mwIndex index = 0; index < total_num_of_cells; index++) 
             {
                 mxArray* cell_element_ptr = mxGetCell(prhs[2], index);
                 //mwSize  buflen = mxGetN(cell_element_ptr)*sizeof(mxChar)+1;
                 //USBserial = (char *) mxMalloc(buflen);
                 //int status = mxGetString(cell_element_ptr, USBserial, buflen);
                 
                 ListedSerials.push_back(std::string(mxArrayToString(cell_element_ptr)));
                 
                 /*
                 if(status)
                 {
                    checkflag = 1;
                    mexPrintf("OpenDevice: Could not find serial number %d.\n", index + 1);
                 }
                 else
                 {
                    mexPrintf("gUSBamp Serial:  %s\n", USBserial);
                    ListedSerials.push_back(USBserial);
                 }
                 */
                 if (cell_element_ptr == NULL) 
                 {
                    mexPrintf("\tEmpty Cell\n");
                    checkflag = 1;
                    success = 0;
                 }
             }
             if (!checkflag)     
                // Call the method    
                success = DAQgUSBampObj->OpenAndInitDevice(ListedSerials);
            
        }
        plhs[0] = mxCreateDoubleScalar((double) success); 
        return;
        
    }
    // Calibration: command to perform calibration
    // Usage: 
    //      DAQgUSBampMex('Calibration', self.objectHandle);
    if (!strcmp("Calibration", cmd)) 
    {
        // Check parameters
        if (nlhs != 0 || nrhs != 2)
            mexErrMsgTxt("Calibration: Unexpected arguments.");
        // Call the method        
        DAQgUSBampObj->AmpCalibration();
        return;
    }
    // StartAcquisition: command to perform acquisition. If filename is empty, no recording will be done
    // Usage:
    //      DAQgUSBampMex('StartAcquisition', self.objectHandle, fileName);
    if (!strcmp("StartAcquisition", cmd)) 
    {
        // Check parameters
        if (nlhs != 0 || nrhs != 3)
            mexErrMsgTxt("StartAcquisition: Unexpected arguments.");
        
        char * Filename;
        size_t filelen;
        int status;
        filelen = mxGetN(prhs[2]) + 1;
        
        // If filename is empty, no recording will be done
        if (filelen == 1)
        {
            mexPrintf("Start Acq.: No filename specified\n");
            DAQgUSBampObj->StartAcquisition();
        }
        else
        {
            // Get filename
            Filename = (char *) mxCalloc(filelen, sizeof(char));
            status = mxGetString(prhs[2], Filename, (mwSize) filelen);
            if(status)
                mexPrintf("Start Acq.: Could not make %s\n", std::string(mxArrayToString(prhs[2])));
            
            // Call the method    
            DAQgUSBampObj->StartAcquisition(Filename);
        }
        
        return;
    }
    
    // GetData: command to get data from buffer. If numSamples is -1, all samples from buffer will be output
    // The output is in float32 type.
    // Usage:
    //      dataBuffer = DAQgUSBampMex('GetData', self.objectHandle, int32(numSamples))
    if (!strcmp("GetData", cmd)) 
    {
        // Check parameters
        if (nlhs != 1 || nrhs != 3)
            mexErrMsgTxt("GetData: Unexpected arguments.");
        // Call the method
        int NumSamples = mxGetScalar(prhs[2]);
        
        if (NumSamples < 0)
            NumSamples = DAQgUSBampObj->AvailableSamples();
        
        plhs[0] = mxCreateNumericMatrix((DAQgUSBampObj->numChannels + DAQgUSBampObj->TRIGGER), NumSamples, mxSINGLE_CLASS, mxREAL);        
        float * dataBuffer = (float *) mxGetData(plhs[0]);
        
        DAQgUSBampObj->GetData(dataBuffer, NumSamples);
        return;
    }
    
    // AvailableSamples: command to return the number of available samples in buffer
    // Usage:
    //      nSamples = DAQgUSBampMex('AvailableSamples', self.objectHandle);
    if (!strcmp("AvailableSamples", cmd)) 
    {
        // Check parameters
        if (nlhs != 1 || nrhs != 2)
            mexErrMsgTxt("AvailableSamples: Unexpected arguments.");
        
        // Call the method
        int NumSamples = 0;
                
        NumSamples = DAQgUSBampObj->AvailableSamples();
        
        plhs[0] = mxCreateDoubleScalar((double) NumSamples);
        return;
    }
    
    // SendTrigger: sends trigger value through usb and Trigger Loopback Connector
    // Usage:
    //      DAQgUSBampMex('SendTrigger', self.objectHandle, logical(triggerState));
    if (!strcmp("SendTrigger", cmd)) 
    {
        // Check parameters
        if (nlhs != 0 || nrhs != 3)
            mexErrMsgTxt("SendTrigger: Unexpected arguments.");
        // Call the method
        bool * triggerState = (bool *) mxGetData(prhs[2]);        
        size_t numberOfBits = mxGetN(prhs[2]);
        
        if (numberOfBits != 4)
            mexErrMsgTxt("SendTrigger: Wrong number of bits.");
        
        DAQgUSBampObj->SendTrigger(triggerState);
        return;
    }
    
    // StopAcquisition: stops acquisition and closes file if applicable 
    // Usage: 
    //      DAQgUSBampMex('StopAcquisition', self.objectHandle);
    if (!strcmp("StopAcquisition", cmd)) 
    {
        // Check parameters
        if (nlhs != 0 || nrhs != 2)
            mexErrMsgTxt("StopAcquisition: Unexpected arguments.");
        // Call the method
        DAQgUSBampObj->StopAcquisition();
        return;
    }
    
    // CloseDevice: closes device 
    // Usage:
    //      DAQgUSBampMex('CloseDevice', self.objectHandle);
    if (!strcmp("CloseDevice", cmd)) 
    {
        // Check parameters
        if (nlhs != 0 || nrhs != 2)
            mexErrMsgTxt("CloseDevice: Unexpected arguments.");
        // Call the method
        DAQgUSBampObj->CloseDevice();
        return;
    } 
    
    // Got here, so command not recognized
    mexErrMsgTxt("Command not recognized.");
}

