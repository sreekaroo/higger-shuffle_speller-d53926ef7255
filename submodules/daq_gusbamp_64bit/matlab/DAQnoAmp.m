classdef DAQnoAmp < DAQbase
    % noAmpManager is an object which generates synthetic EEG data for use in "noAmp" mode
    % Data gets generated with randn 
    properties
    end
    
    properties (Hidden = true)
        % Time stamp to mark when GetData was called
        lastGetDataCallTic;
        
        % Custom trigger signal set by user with SetTrigger command.
        % GetData will return this to the user
        customTriggerSignal;
        
        % Constant amplitude
        signalAmplitude = 20e-6
    end    
    
    methods
        
        % Constructor for DAQnoAmp        
        % Input parameters from base
        % 'channelList'           - [numChannels x 1], active channels. 1 is
        %                           default
        % 'fs'                    - scalar, sampling freq of EEG. 256 default
        % 'triggerType'           - string, currently only 'custom' and 'block' mode
        %                           supported. 
        %                           'block' assumes data is vlaid only in
        %                           non-zero trigger values
        %                           'custom' allows user to write directly
        %                           to the trigger feed with SetTrigger
        %                           function.
        % 'frontEndFilterFlag'    - logical, if true then front end filter is
        %                           active. True is default
        % 'channelNames'          - cell of strings with channel names. Unused everywhere in the code
        %                           but helpful for people who want to store
        %                           objects. Default is to use the strings of
        %                           the channelList
        % 'frontEndFilterStruct'  - Filter struct to be used during
        %                           filtering. Empty if default filter is
        %                           to be used which is a high pass filter
        %             .Num        - Numerator coefficients. Just like b
        %                           input to filter function
        %             .Den        - Denominator coefficients. Just like b
        %                           input to filter function
        %             .groupDelay - Number of samples to delay trigger
        %                           after filtering.        
        function self = DAQnoAmp(varargin)
            % constructor
            self = self@DAQbase(varargin{:});
            
            self.customTriggerSignal = [];
            self.signalAmplitude = 20e-6;
            self.status = self.STATUS_STANDBY;
        end
        
        % StartAcquisition - marks new timestamp for acquisition        
        function StartAcquisition(self,varargin)
            self.lastGetDataCallTic = tic;
            self.customTriggerSignal = [];
            self.status = self.STATUS_ACQUIRINGDATA;
            disp('Recording started - (noAmp)');
        end
        
        % OpenDevice - does nothing. Placed here for compatibility
        function OpenDevice(self)
            self.status = self.STATUS_OPEN;
            disp('Connection with amplifier(s) open. - (noAmp)')
        end
        
        % GetData - gets available data from buffer
        %
        %   Inputs: 
        %       'numSamples'                - Number of samples to collect.
        %                                     [] gets all
        %                                     available samples (default
        %                                     behavior)
        %       
        %       'frontEndFilterFlag'        - True to return filtered data
        %       'triggerType'               - 'block' for block trigger.
        %                                     Check extra inputs below. 
        %                                     'custom' to return custom
        %                                     trigger channel
        %
        %       Used only by 'block' trigger
        %           'trialLengthSec'            - Length of trial in
        %                                         seconds. 1 by default
        %           'interTrialPauseLengthSec'  - Time between trials in seconds. 
        %                                         1 by default 
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
        function [data, triggerSignal] = GetData(self,varargin)
            p = inputParser;
            p.addParameter('frontEndFilterFlag',self.frontEndFilterFlag,@islogical);
            p.addParameter('triggerType',self.triggerType,@(x)(any(strcmp(x,{'custom','block'}))));
            p.addParameter('trialLengthSec',1,@isscalar);
            p.addParameter('numSamples',[],@isscalar);            
            p.addParameter('interTrialPauseLengthSec',1,@isscalar);
            p.parse(varargin{:});
            
            if isempty(self.lastGetDataCallTic)
                error('noAmpManager: you must call startAmps first!')
            else
                if isempty(p.Results.numSamples)
                    numSamples =  ceil(toc(self.lastGetDataCallTic)*self.fs);                    
                else
                    numSamples = p.Results.numSamples;
                end
            end
            self.lastGetDataCallTic = tic;
            
            % Generates random data. Order of sizes inverted in order to be
            % able to replicate the same dataset when rng seeds are used.
            % See the test script for this usage. 
            data = self.signalAmplitude*randn(length(self.channelList),numSamples).';
            
            % Generate fake triggers
            switch self.triggerType
                case 'block'
                    
                    % Create triggers according to block scheme
                    triggerActive = ones(1,ceil(p.Results.trialLengthSec*self.fs));
                    triggerPassive = zeros(1,ceil(p.Results.interTrialPauseLengthSec*self.fs));
                    numberOfStimuli = numSamples / length([triggerPassive triggerActive]);
                    triggerSignal = repmat([triggerPassive triggerActive],1,ceil(numberOfStimuli));
                    triggerSignal = triggerSignal(1:numSamples);
                    
                case 'custom'
                    
                    % Returns custom trigger to user
                    if numSamples > length(self.customTriggerSignal)
                        triggerSignal = [self.customTriggerSignal;zeros(numSamples-length(self.customTriggerSignal),1)];                        
                        self.customTriggerSignal = [];
                    else
                        triggerSignal = self.customTriggerSignal(1:numSamples);
                        self.customTriggerSignal =  self.customTriggerSignal(numSamples+1:end);
                    end
  
                otherwise
                    warning('only block triggers implemented, returning empty trigger');
                    triggerSignal = [];
            end
            
            % Apply filter if enabled but don't return it yet
            if self.frontEndFilterFlag
                [filteredData, filteredTriggerSignal] = self.ApplyFrontEndFilter(data,triggerSignal);
            end
            
            if p.Results.frontEndFilterFlag && self.frontEndFilterFlag
                data = filteredData;
                triggerSignal = filteredTriggerSignal;
            end
            
        end
        
        % SetTrigger - appends triggerSignal to internal trigger channel
        % Input
        %       triggerSignal   -   vector with custom trigger values to be
        %                           appended
        function SetTrigger(self, triggerSignal)
            
            self.customTriggerSignal = [self.customTriggerSignal; reshape(triggerSignal,[],1)];
            
        end
        
        % StopAcquisition - clears channel
        function StopAcquisition(self)
            disp('Recording stopped - (noAmp)')
            self.customTriggerSignal = [];
            self.status = self.STATUS_OPEN;
        end
        
        % CloseDevice - do nothing
        function CloseDevice(self)
            disp('Connection with amplifier(s) closed. - (noAmp)')
            self.status = self.STATUS_STANDBY;
        end
        
    end
end
