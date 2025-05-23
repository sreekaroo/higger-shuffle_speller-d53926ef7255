% DAQgUSBAmp wraps the C++ DAQgUSBAmp library through a mex layer. This object 
% controls all aspects of the daq including detecting, calibrating the amp, testing the trigger, initializing 
% the amps and setting up amp parameters.
%
% Here is the order of execution for general usage::
% (0) Turn on device and connect USB cable
% (1) Constructor: opens and inits device
% (2) OpenDevice
% (3) StartAcquisition: starts getting data (and put to file if enabled)
% (4) GetData, GetTrial, or do nothing
% (5) StopAcquistion: stops getting data and closes file if applicable
% (6) repeat (2)-(4) if needed
% (7) CloseDevice: good practice to call but the destructor will clean up
%                  appropiatedly
%
% This object can be stored and calling OpenDevice will reinitialize the
% amplifier with the stored parameters. Make sure you store teh object
% after the device has been closed
%
% List of methods in object:
%   From DAQgUSBAmp
%       .Constructor
%       .StartAcquisition
%       .GetData
%       .StopAcquistion
%       .CloseDevice
%       .ParallelPortTriggerTest
%       .USBTriggerTest
%       .SendTrigger
%   
%   From DAQBase
%       .ApplyFrontEndFilter
%       .GetTrial
%   
% Example:
%{
% Demo script for matlab daqgusbamp class
clc, clear;

% Set parameters and create object
numChannels = 3;
sampleRate = 256;
ampFilterNdx = 49;
notchFilterNdx = 3;
channelsToAcquire = [1, 3, 4];
fileName = 'DAQgUSBAmpTestFile.bin';

% Add stuff to path
mfilepath=fileparts(which('DAQgUSBAmpTest.m'));
addpath(fullfile(mfilepath,'../matlab'));

% Call constructor 
DAQClassObj = DAQgUSBAmp('channelList',channelsToAcquire, ...
                            'fs', sampleRate,...
                            'triggerFlag',logical(triggerFlag), ...
                            'notchFilterNdx',notchFilterNdx, ...
                            'ampFilterNdx',ampFilterNdx);

% Start data acquisition
DAQClassObj.StartAcquisition('fileName', fileName);

% Send a couple of triggers with some pauses in between
DAQClassObj.SendTrigger(0);
pause(1);
DAQClassObj.SendTrigger(1);
pause(1);
DAQClassObj.SendTrigger(0);
pause(1);
DAQClassObj.SendTrigger(1);
pause(1);
DAQClassObj.SendTrigger(0);
pause(3);
[dataBuffer, triggerSignal] = DAQClassObj.GetData();

% Stop data acquisition
DAQClassObj.StopAcquisition();

% Close and delete object
DAQClassObj.CloseDevice();
%}

classdef DAQgUSBAmp < DAQbase
    
    properties (SetAccess = private, Hidden = true)
        
        % Integer with a pointer to underlying C++ class instance. This is a neat C++ trick to 
        % get mex to wrap classes
        objectHandle; 
        
        % gUSBAmp mode
        ampMode;
                        
    end
    
    properties (SetAccess = private, Hidden = false)
        
        % True if the amp will collect trigger data
        triggerFlag;                
        
        % [4x1] vector that determines which group of channels will be tied
        % to common reference. [1 1 1 1] by default
        commonReference;
        
        % [4x1] vector that determines which group of channels will be tied
        % to common ground. [1 1 1 1] by default
        commonGround;
        
        % [1xnChannels] vector with the indexes to perform bipolar
        % operation. [] for unipolar mode
        bipolarSettings;
        
        % Index of notch filter. -1 to disable
        notchFilterNdx;
        
        % Index of bandpass filter. -1 to disable
        ampFilterNdx;
        
        % True to perform calibration
        calibrationFlag;
        
        % True to perform parallel port test
        testParallelPortFlag;
        
        % True to perform usb trigger test
        testUSBTriggerFlag;
        
        % Length in seconds of internal buffer i.e. determines maximum
        % amount of time between successive GetData class that result in
        % no data loss. Not used in current implementation
        ampBufferLengthSec;        
        
        % Amp serial number as a cell. If empty, first amp detected will be
        % used
        ampSerialNumbers;

    end
    
    methods
        
        % Constructor for DAQgUSBAmp
        % Input parameters from base class:
        %   'channelList'           - [numChannels x 1], active channels. 1 is
        %                             default
        %   'fs'                    - scalar, sampling freq of EEG. 256 default
        %   'triggerType'           - string, currently only 'custom' and 'block' mode
        %                             supported. 'block' is default used only
        %                             by GetTrial method. Check derived
        %                             classes if they use this parameter
        %   'frontEndFilterFlag'    - logical, if true then front end filter is
        %                             active. True is default
        %   'channelNames'          - cell of strings with channel names. Unused everywhere in the code
        %                             but helpful for people who want to store
        %                             objects. Default is to use the strings of
        %                             the channelList
        %   'frontEndFilterStruct'  - Filter struct to be used during
        %                             filtering. Empty if default filter is
        %                             to be used which is a high pass filter
        %                .Num       - Numerator coefficients. Just like b
        %                             input to filter function
        %                .Den       - Denominator coefficients. Just like b
        %                            input to filter function
        %              .groupDelay  - Number of samples to delay trigger
        %                             after filtering.
        %
        % Input parameters:
        %   'triggerFlag'           - True if the amp will collect trigger
        %                             data. True by default
        %   'commonReference'       - [4x1] vector that determines which group of channels will be tied
        %                             to common reference. [1 1 1 1] by
        %                             default. Don't change unless you
        %                             know what you are doing. 
        %   'commonGround'          - [4x1] vector that determines which group of channels will be tied
        %                             to common ground. [1 1 1 1] by
        %                             default. Don't change unless you
        %                             know what you are doing. 
        %   'bipolarSettings'       - [1 x nChannels] vector with the indexes to perform bipolar
        %                             operation. [] for unipolar mode.
        %                             Don't change unless you
        %                             know what you are doing. 
        %   'notchFilterNdx'        - Index of notch filter. -1 to disable.
        %                             3 by default (60 hz notch at 256 Hz
        %                             Fs). Check docs for more
        %                             filters
        %   'ampFilterNdx'          - Index of bandpass filter. -1 to
        %                             disable. 43 by default, bandpass at
        %                             [0.10	100.00] Hz. Check docs for more
        %                             filters
        %   'calibrationFlag'       - True to perform calibration during
        %                             construction. False by default.
        %                             Calibration can be called on demand
        %                             by the user if needed. 
        %   'testParallelPortFlag'  - True to perform parallel port trigger test during
        %                             construction. False by default.
        %                             Test can be called on demand
        %                             by the user if needed. 
        %   'testUSBTriggerFlag'    - True to perform usb trigger test during
        %                             construction. False by default.
        %                             Test can be called on demand
        %                             by the user if needed.
        %   'ampBufferLengthSec'    - Length in seconds of internal buffer i.e. determines maximum
        %                             amount of time between successive GetData class that result in
        %                             no data loss. Not used in current implementation
        %   'ampSerialNumbers'      - Amp serial number as a cell. If empty, first amp detected will be
        %                             used. Empty by default. First serial
        %                             is considered master
        
        function self = DAQgUSBAmp(varargin)
            
            % Constructor to base
            self = self@DAQbase(varargin{:});
        
            p = inputParser;
            
            % Ignore irrelevant fields
            p.KeepUnmatched = true;  
            
            p.addParameter('triggerFlag',true,@islogical);
            
            p.addParameter('commonReference',[1,1,1,1],@isscalar);
            p.addParameter('commonGround',[1,1,1,1],@isscalar);
            p.addParameter('bipolarSettings',[],@isscalar);
            
            p.addParameter('notchFilterNdx',3,@isscalar);
            p.addParameter('ampFilterNdx',49,@isscalar);
            p.addParameter('calibrationFlag',false,@isscalar);
            p.addParameter('testParallelPortFlag',false,@islogical);
            p.addParameter('testUSBTriggerFlag',false,@islogical);
            
            p.addParameter('ampBufferLengthSec',inf,@isscalar);
            
            p.addParameter('ampSerialNumbers',[],@iscell);

            p.parse(varargin{:});
            
            self.triggerFlag = p.Results.triggerFlag;            
            
            self.commonReference = p.Results.commonReference;
            self.commonGround = p.Results.commonGround;
            self.bipolarSettings = p.Results.bipolarSettings;
            
            self.notchFilterNdx         = p.Results.notchFilterNdx;
            self.ampFilterNdx           = p.Results.ampFilterNdx;
            self.calibrationFlag        = p.Results.calibrationFlag;
            self.testParallelPortFlag   = p.Results.testParallelPortFlag;
            self.testUSBTriggerFlag     = p.Results.testUSBTriggerFlag;
            self.ampSerialNumbers       = p.Results.ampSerialNumbers;
            
            % Hardcoded for normal operations
            self.ampMode = 0;
            
            % Not used for now
            % self.ampBufferLengthSec     = p.Results.ampBufferLengthSec;
            
            % Get number of active channels
            numChannels = length(self.channelList);
            
            % If no bipolar settings, set monopolar with 0's
            if isempty(self.bipolarSettings)
                self.bipolarSettings = zeros(numChannels,1);
            end 
            
            self.status = self.STATUS_STANDBY;                        
            
            % Calibrate amplifiers if need be
            if self.calibrationFlag
                self.CalibrateAmps();
            end
            
            % Test paralell port if need be
            if self.testParallelPortFlag
                self.ParallelPortTriggerTest();
            end
            
            % Test usb trigger if need be
            if self.testUSBTriggerFlag
                self.USBTriggerTest();
            end
                       
        end

        % OpenDevice - Opens and initializes device
        % Output:
        %   successFlag - True if opening the device was successful
        function successFlag = OpenDevice(self, varargin)                        
            
            numChannels = length(self.channelList);
            
            if self.status == self.STATUS_STANDBY
           
                successFlag = 0;
                while ~successFlag
                    
                    % Call mex new object command
                    self.objectHandle = DAQgUSBampMex('new', uint8(numChannels), ...
                                 uint8(self.channelList), int32(self.fs), ...
                                 int32(self.triggerFlag), int32(self.ampFilterNdx),... 
                                 int32(self.notchFilterNdx), uint8(self.ampMode), ...
                                 int32(self.commonReference), int32(self.commonGround), ...
                                 uint8(self.bipolarSettings));
                             
                    successFlag = DAQgUSBampMex('OpenDevice', self.objectHandle, self.ampSerialNumbers);
                    
                    if ~successFlag
                        disp('No amplifers detected.');
                        disp('Please, check power and USB connections.');
                        tryAgain = input('Try again? (y/n):','s');
                        
                        DAQgUSBampMex('DeleteAll', self.objectHandle);
                        
                        if(tryAgain=='n')
                            disp('Detecting amplifier(s) aborted by user.')
                            return;
                        end
                    end
                    
                    
                end

                self.status = self.STATUS_OPEN;
            else
                successFlag = 0;
                warning('OpenDevice can only be called when object is in standby mode');
            end

        end
        
        % CalibrateAmps - perform calibration.
        function CalibrateAmps(self)
            
            statusBeforeCalibration = self.status;
            
            if self.status == self.STATUS_STANDBY
                self.OpenDevice();
            end
            
            if self.status == self.STATUS_OPEN
                DAQgUSBampMex('Calibration', self.objectHandle);
            else
                warning('Calibration can only be performed when device is on STATUS_OPEN');
            end
            
            % Amp has to be reconfigured after calibration
            self.CloseDevice();
            
            % Return device to open state if it was the case before
            % calibration
            if statusBeforeCalibration == self.STATUS_OPEN
                self.OpenDevice();
            end

        end
        
        % StartAcquisition - starts acquisition after device has been
        % opened
        %
        % Inputs:
        %   'fileName'      -   Full path to filename where data will be
        %                       stored during acquisition
        function StartAcquisition(self, varargin)
            
            p = inputParser;
            p.KeepUnmatched = true;     %ignores irrelevant fields
            p.addParameter('fileName',[],@(x)(ischar(x) || isempty(x)));
            p.parse(varargin{:});
                        
            fileName = p.Results.fileName;
            
            % If device is on standby, open it first
            if self.status == self.STATUS_STANDBY
            	self.OpenDevice();   
                warning('You should OpenDevice explicitly before starting acquistion!');
            end
            
            if self.status == self.STATUS_OPEN
                DAQgUSBampMex('StartAcquisition', self.objectHandle, fileName);

                % Clears filter state and trigger buffer
                self.ResetFilterState();

                % Pause to prevent potential bug
                pause(1/10);
                
                % Set correct status 
                self.status = self.STATUS_ACQUIRINGDATA;
            else
                warning('StartAcquisition can only be called on STATUS_OPEN');
            end
        end
        
        % GetData - gets available data from buffer
        %
        %   Inputs: 
        %       'numSamples'            -   Number of samples to collect.
        %                                   Blocking if not enough samples
        %                                   are available. [] gets all
        %                                   available samples (default
        %                                   behavior)
        %       
        %       'frontEndFilterFlag'    -   True to return filtered data
        %
        %   Outputs:
        %
        %       data                    -   [nSamples x nChannels] array
        %                                   with data from amp in volts.
        %                                   Scaled inside by 1e-6
        %
        %       triggerSignal           -   [nSamples x 1] trigger signal.
        %                                   Empty if trigger disabled
        %
        function [data, triggerSignal] = GetData(self, varargin)
            
            p = inputParser;
            p.addParameter('numSamples',[],@isscalar);
            p.addParameter('frontEndFilterFlag',true,@isscalar);
            p.addParameter('adaptiveFilterFlag',self.adaptiveFilterFlag);
            p.parse(varargin{:});
                        
            numSamples = p.Results.numSamples;
            frontEndFilterFlag = p.Results.frontEndFilterFlag;
            adaptiveFilterFlag = p.Results.adaptiveFilterFlag;
            if isempty(adaptiveFilterFlag)
                adaptiveFilterFlag = 0;
            end
            if isempty(self.adaptiveFilterFlag)
                self.adaptiveFilterFlag = 0;
            end
            
            % Mex needs numSamples = -1 if we want all data 
            if isempty(numSamples)
                numSamples = -1;
            end
            
            if self.status ~= self.STATUS_ACQUIRINGDATA
                triggerSignal = [];
                data = [];
                warning('GetData only works when device is acquiring data');
                return
            end
            
            % If no data is available, return empty
            if (self.AvailableSamples() == 0) && (numSamples == -1)
                triggerSignal = [];
                data = [];
                return
            end
            
            % Convert to double from float32
            dataBuffer = double(DAQgUSBampMex('GetData', self.objectHandle, int32(numSamples)));
            
            % Trigger signal is "last channel" of data buffer
            % Scale to volts
            data = (1e-6)*dataBuffer(1:end-self.triggerFlag,:).';
            if self.triggerFlag
                triggerSignal =  dataBuffer(end,:).';
            else
                triggerSignal = [];
            end
            
            % Apply filter if enabled but don't return it yet
            if self.frontEndFilterFlag
                [filteredData, filteredTriggerSignal] = self.ApplyFrontEndFilter(data,triggerSignal);
            end   
            
            if frontEndFilterFlag && self.frontEndFilterFlag
                data = filteredData;
                triggerSignal = filteredTriggerSignal;
            end     
            
            % Apply adaptive filter if enabled but don't return it yet
            if self.adaptiveFilterFlag
                filteredData = self.ApplyAdaptiveFilter(data);
            end   
            
            if adaptiveFilterFlag && self.adaptiveFilterFlag
                data = filteredData;
            end     

        end
        
         % AvailableSamples - Gets available number of samples
         % Output:
         %      nSamples - number of available samples
        function nSamples = AvailableSamples(self)
            if self.status == self.STATUS_ACQUIRINGDATA
                nSamples = DAQgUSBampMex('AvailableSamples', self.objectHandle);
            else
                warning('AvailableSamples only works when device is acquiring data')
            end
        end
        
        % SendTrigger - Send trigger through USB using DigOut in the amp.
        % Needs Trigger Loopback Connector (TLC)
        % Input:   
        %       triggerState -  4 bit trigger as an integer (0-15)
        function SendTrigger(self, triggerValue)
            if self.status == self.STATUS_ACQUIRINGDATA
                
                % Flip vector to get first bit first
                binaryTriggerVector = logical(fliplr(char(dec2bin(triggerValue,4))-'0'));
                
                DAQgUSBampMex('SendTrigger', self.objectHandle, binaryTriggerVector);
            else
                warning('SendTrigger only works when device is acquiring data')
            end
        end
        
        % Tests the triggers received by the amplifiers. This function uses
        % the USB triggers provided by the library.             
        %   * The connection of the all bits.
        %   * The number of the triggers sent and received.
        %   * The values of the triggers sent and received.
        %   * The pulse width of the triggers sent and received.
        %   * The values of the first and last triggers sent and received.
        %
        %   Output:
        %
        %      success - A flag that show the success of the procedure.
        %    
        function success = USBTriggerTest(self)
            
            if ~self.triggerFlag
                success = 0;
                warning('Trigger disabled');
                return;
            end
            
            statusBeforeTest = self.status;
           
            if self.status == self.STATUS_STANDBY
                self.OpenDevice();
            end
            
            if self.status ~= self.STATUS_OPEN
                success = 0;
                warning('Trigger test only works if device is open or on stand by');
                return;
            end 
            
            self.StartAcquisition();            
            triggerTestContinue = 1;
            
            triggerPulsewidth = 10/self.fs;
            numberOfTestIterations = 10;
            triggerTestValues = [1; 15];
            triggerPulsewidthStdThreshold=1/self.fs;
            
            while(triggerTestContinue)
                pause(0.050);
                self.SendTrigger(0);
                
                % Using the inpout library to communicate with the PCI port.
                for idxIteration=1:numberOfTestIterations
                    for triggerTestIndex=1:length(triggerTestValues)
                        tic;
                        self.SendTrigger(triggerTestValues(triggerTestIndex));
                        while(toc<triggerPulsewidth)
                        end
                    end
                end
                self.SendTrigger(0);

                pause(0.1);
                
                % Reading the trigger data from amplifiers and testing if the received trigger properties are the same as the ones that we sent.
                [~,triggerSignal]=self.GetData('frontEndFilterFlag',false);
                
                diffTriggerLocs = find(diff(triggerSignal));
                triggerChangeValues = triggerSignal(diffTriggerLocs(1:end-1)+1);
                firstTriggerValue = triggerSignal(1);
                lastTriggerValue = triggerSignal(end);
                
                uniqueTriggerValues = unique(triggerSignal);
                if (isempty(find(uniqueTriggerValues==triggerTestValues(1), 1))) % Checking if the lower 4 bits are working properly
                    valueOfTriggerOK = 0;
                else
                    valueOfTriggerOK = 1;
                end
                
                if (firstTriggerValue~=0 || lastTriggerValue~=0) % First and last received trigger values should be zero
                    errorMsg = 'Trigger test failed: Cannot set the trigger to zero.';
                    success = 0;
                else
                    success = 0;
                    expectedTriggerValues=repmat(triggerTestValues,numberOfTestIterations,1);
                    if (valueOfTriggerOK)
                        if (length(expectedTriggerValues)~=length(triggerChangeValues)) % Checking the number of the received triggers
                            errorMsg = 'Trigger test failed: Unexpected number of trigger pulses';
                        else
                            if (std(diff(diffTriggerLocs(2:end)))>triggerPulsewidthStdThreshold) % Checking the pulsewidth of the received triggers
                                errorMsg = 'Trigger test failed: Trigger timing is not accurate.';
                            else
                                disp('Trigger test was successful.');
                                success = 1;
                            end
                        end
                    else
                        errorMsg = 'Trigger test failed: No triggers are received. Please check the connections.';
                    end
                end
                
                if (success==1)
                    triggerTestContinue = 0;
                else
                    disp(errorMsg);
                    tryAgain = input('Try again? (y/n):','s');
                    if (tryAgain=='n')
                        triggerTestContinue = 0;
                    end
                end
            end

            self.StopAcquisition();
            
            % Return device to open state if it was the case before
            % test
            if statusBeforeTest == self.STATUS_STANDBY
                self.CloseDevice();
            end
        
        end                
        
        % StopAcquisition - stops acquisition and closes file if one was
        % opened
        function StopAcquisition(self)
            
            if self.status == self.STATUS_ACQUIRINGDATA
                
                % To ensure group delay of filter is cleared
                waitGrouDelay = 1.2*(self.frontEndFilterStruct.groupDelay/self.fs);
                pause(waitGrouDelay);
                
                % Reset buffer by reading data
                self.GetData();
                
                % Clears filter state and trigger buffer
                self.ResetFilterState();
                
                DAQgUSBampMex('StopAcquisition', self.objectHandle);
                
                self.status = self.STATUS_OPEN;
                
            else                
                warning('StopAcquisition can only be run when device is acquiring data')                
            end
        end        
        
        % CloseDevice - closes device and destroys the C++ class instance
        function CloseDevice(self)
            
            if self.status == self.STATUS_ACQUIRINGDATA
                self.StopAcquisition();
                warning('CloseDevice should only be called if the device is open but not acquiring data')
            end
            
            if self.status == self.STATUS_OPEN               
                DAQgUSBampMex('CloseDevice', self.objectHandle);
                DAQgUSBampMex('DeleteAll', self.objectHandle);
                
                self.status = self.STATUS_STANDBY;
            else
                warning('CloseDevice can only be called if the device is open but not acquiring data')
            end
        end
                        
        % Destructor - stops and closes device according to object status 
        function delete(self)
        
            if self.status == self.STATUS_ACQUIRINGDATA  
                self.StopAcquisition();
            end
            
            if self.status == self.STATUS_OPEN  
                self.CloseDevice();
            end
            
        end

    end
end


