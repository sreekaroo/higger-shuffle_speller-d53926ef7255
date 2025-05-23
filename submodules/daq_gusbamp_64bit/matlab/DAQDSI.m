classdef DAQDSI < DAQbase
    
    properties (SetAccess = private, Hidden = true)
        
        % Integer with a pointer to underlying Python object
        objectHandle; 
        
        % Default address and port for DSI Streamer
        defaultAddress = '127.0.0.1';       
        defaultPort = 8844;       
        
        % Default sample rate. (it will change during call to start
        % acquisition
        defaultFs = 300;        
        
        % Number of cahnnels
        N_CHANNELS = 20;    
        
        INVALID_HANDLE = -1; 
        
        defaultChannelNames = {'P3','C3','F3','Fz','F4','C4','P4','Cz','A1','Fp1','Fp2','T3','T5','O1','O2','F7','F8','A2','T6','T4'};
                   
    end
    
    properties (SetAccess = private, Hidden = false)
        
        % True if the amp will collect trigger data
        triggerFlag;                

        % True to perform parallel port test
        testParallelPortFlag;
        
        % Address and port for DSI Streamer
        address;
        port;
        
        trigSample = [];
        
    end
    
    methods
        
        % Constructor for DAQgUSBAmp       
        %
        % These parameters will get overwritten!
        %
        %   'channelList'           - [numChannels x 1], active channels. 1 is
        %                             default
        %   'fs'                    - scalar, sampling freq of EEG. 256 default
        %   'channelNames'          - cell of strings with channel names. Unused everywhere in the code
        %                             but helpful for people who want to store
        %                             objects. Default is to use the strings of
        %                             the channelList
        %
        % Input parameters from base class:
        %
        %   'frontEndFilterFlag'    - logical, if true then front end filter is
        %                             active. True is default
        %
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
        %   'testParallelPortFlag'  - True to perform parallel port trigger test during
        %                             construction. False by default.
        %                             Test can be called on demand
        %                             by the user if needed. 
        
        function self = DAQDSI(varargin)
            
            % Constructor to base
            self = self@DAQbase(varargin{:});
        
            p = inputParser;
            
            % Ignore irrelevant fields
            p.KeepUnmatched = true;  
            
            p.addParameter('triggerFlag',true,@islogical);        
            p.addParameter('address',self.defaultAddress,@isstr);        
            p.addParameter('port',self.defaultPort,@isscalar);        
            p.addParameter('testParallelPortFlag',false,@islogical);
             
            p.parse(varargin{:});
            
            % self.channelList = 1:self.N_CHANNELS;
            % self.channelNames = cellstr(num2str(reshape(self.channelList,[],1))).';
            
            self.triggerFlag = p.Results.triggerFlag;            
            
            self.address = p.Results.address;            
            self.port = p.Results.port;            
        
            self.testParallelPortFlag   = p.Results.testParallelPortFlag;

            self.status = self.STATUS_STANDBY;   
            
            self.fs = self.defaultFs;
            
            % Test paralell port if need be
            if self.testParallelPortFlag
                self.ParallelPortTriggerTest();
            end
            
            self.objectHandle = self.INVALID_HANDLE;
                       
        end

        % OpenDevice - Opens and initializes device
        % Output:
        %   successFlag - True if opening the device was successful
        function successFlag = OpenDevice(self, varargin)                                               
            
            if self.status == self.STATUS_STANDBY
                
                % Add python file to Python path
                mfilepath=fileparts(which('DAQDSI.m'));
                addpath(fullfile(mfilepath,'../python'));
                addToPyPath('daq_dsi.py', 'verbose', false);
                
                % Instantiate object
                self.objectHandle = py.daq_dsi.DaqDSI(self.address, int32(self.port));
                self.objectHandle.open_device();
                
                successFlag = 1;
                self.status = self.STATUS_OPEN;
            else
                successFlag = 0;
                warning('OpenDevice can only be called when object is in standby mode');
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
                
                if self.objectHandle == self.INVALID_HANDLE
                    error('invalid python object handle')
                end
                
                self.trigSample = [];
                
                self.objectHandle.start_acquisition(fileName)

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
            p.addParameter('frontEndFilterFlag',true,@isscalar);
            p.parse(varargin{:});
                        
            frontEndFilterFlag = p.Results.frontEndFilterFlag;           
            
            if self.status ~= self.STATUS_ACQUIRINGDATA
                triggerSignal = [];
                data = [];
                warning('GetData only works when device is acquiring data');
                return
            end
            
            % Convert to double from float32
            if self.objectHandle == self.INVALID_HANDLE
                error('invalid python object handle')
            end
            
            tmpData = self.objectHandle.get_data();
            
            % If data is empty
            if tmpData.size == 0;
                triggerSignal = [];
                data = [];
                return
            end
            
            dataBuffer = toggleNumpy(tmpData);
                        
            % Trigger signal is "last channel" of data buffer
            % Scale to volts
            data = (1e-6)*dataBuffer(:,self.channelList);
            if self.triggerFlag                                                
                triggerSignal = dataBuffer(:,end);                                
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
                
                if self.objectHandle == self.INVALID_HANDLE
                    error('invalid python object handle')
                end
                self.objectHandle.stop_acquisition()
                
                self.status = self.STATUS_OPEN;
                
            else                
                warning('StopAcquisition can only be run when device is acquiring data')                
            end
        end        
        
        % CloseDevice - closes device and destroys the python class instance
        function CloseDevice(self)
            
            if self.status == self.STATUS_ACQUIRINGDATA
                self.StopAcquisition();
                warning('CloseDevice should only be called if the device is open but not acquiring data')
            end
            
            if self.status == self.STATUS_OPEN               
                if self.objectHandle == self.INVALID_HANDLE
                    error('invalid python object handle')
                end
                self.objectHandle.close_device()
                self.objectHandle = self.INVALID_HANDLE;
                
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
