classdef DAQbase < handle
    % Daq manager is a superclass that manages getting trials and filtering
    properties
        
        % [numChannels x 1], active channels
        channelList
        
        % scalar, sampling freq of EEG
        fs
        
        % string, currently only 'block' mode supported
        triggerType
        
        % logical, if true then front end filter is active
        frontEndFilterFlag
        
        % cell of strings with channel names. Unused everywhere in the code
        % but helpful for people who want to store objects
        channelNames
        
        % Adaptive filter flag
        adaptiveFilterFlag
    end
    
    properties (SetAccess = protected, Hidden = false)
        % Status that determines state of device
        %  0 - STATUS_STANDBY       Object has been constructed but device
        %                           hasn't been initialized
        %  1 - STATUS_OPEN          Device has been opened and is ready for
        %                           acquisition
        %  2 - STATUS_ACQUIRINGDATA Device is currently acquiring data
        status;
        
        % Status constants
        STATUS_STANDBY          = 0;
        STATUS_OPEN             = 1;
        STATUS_ACQUIRINGDATA    = 2;
    end
    
    properties (Hidden=true)
        
        % struct containing front end filter info
        frontEndFilterStruct
        %   .groupDelay     = scalar, group delay of filter
        %   .Den            = vector, denominator of filter
        %   .Num            = vector, numerator of filter
        
        % [groupDelay x 1] last information run through filter
        filterState
        
        % [groupDelay x 1] buffer of trigger data
        triggerBuffer
        
        % Adaptive filter parameter struct
        adaptiveFilterParams
               
        % Adaptive filter objects
        adaptiveFilterObj
    end
    
    methods (Abstract)
        
       % Creates internal instance and connection to device 
       successFlag = OpenDevice(self, varargin); 
       
       % Starts data acquisition thread
       StartAcquisition(self, varargin); 
       
       % Stops acquisition thread
       StopAcquisition(self);
       
       % Closes and cleans internal device instance
       CloseDevice(self);
       
       % Gets data from internal buffer
       [data, triggerSignal] = GetData(self, varargin);
       
    end
    
    methods
        
        % Constructor
        % Input parameters
        % 'channelList'           - [numChannels x 1], active channels. 1 is
        %                           default
        % 'fs'                    - scalar, sampling freq of EEG. 256 default
        % 'triggerType'           - string, currently only 'custom' and 'block' mode
        %                           supported. 'block' is default used only
        %                           by GetTrial method. Check derived
        %                           classes if they use this parameter
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
        % 'adaptiveFilterFlag'    - Adaptive filter flag (false default)
        % 'adaptiveFilterParams'  - Struct for adaptive filter parameters.
        %                           This is what is currently supported:
        %             .delta      - Initial variance of noise channel (1e-10 default)
        %             .lambda     - Forgetting factor (0.95 default)
        %             .order      - Filter order (5 default)
        %             .refIdx     - Channel idx for noise reference (1 default)        
        function self = DAQbase(varargin)
            p = inputParser;
            p.KeepUnmatched = true;     %ignores irrelevant fields
            p.addParameter('fs',256,@isscalar);
            p.addParameter('channelList',1,@isnumeric);
            p.addParameter('channelNames',[],@iscell);
            
            p.addParameter('triggerType','block',@(x)(any(strcmp(x,{'custom','block'}))));
            p.addParameter('frontEndFilterFlag',true,@islogical);
            
            % To be added: custom filtering
            p.addParameter('frontEndFilterStruct',[]);
            
            p.addParameter('adaptiveFilterFlag',false);
            
            adaptiveFilterParamsDefault.delta = 1e-10;
            adaptiveFilterParamsDefault.lambda = 0.95;
            adaptiveFilterParamsDefault.order = 5;
            adaptiveFilterParamsDefault.refIdx = 1;
            p.addParameter('adaptiveFilterParams',adaptiveFilterParamsDefault);

            p.parse(varargin{:});
            argPassed = @(x)(~ismember(x, p.UsingDefaults));
            
            self.channelList            = p.Results.channelList;
            self.channelNames           = p.Results.channelNames;
            if length(self.channelList) ~= length(self.channelNames)
                if argPassed('channelList') && argPassed('channelNames')
                    % user specified contradiction
                    error('channelList and channelNames must have same length');
                elseif argPassed('channelNames')
                    % user only specified channelNames, build channelList
                    % default to comply with channelNames
                    self.channelList = 1 : length(self.channelNames);
                else
                    % user did not specify channelNames, build channelNames
                    % default to comply with channelList
                    self.channelNames = cellstr(num2str(reshape(self.channelList,[],1))).';
                end
            end
            
            self.fs                     = p.Results.fs;

            self.triggerType            = p.Results.triggerType;
            
            self.frontEndFilterFlag     = p.Results.frontEndFilterFlag;
            
            if isempty(p.Results.frontEndFilterStruct)
                % Call front end filter function with Fstop = 2 and Fpass = 5
                frontEndFilterStructTmp = frontEndFilterBP(self.fs);
                self.frontEndFilterStruct.Num = frontEndFilterStructTmp.Numerator;
                self.frontEndFilterStruct.Den = 1;
                groupDelay = frontEndFilterStructTmp.groupdelay;
                
                % Assume constant group delay
                self.frontEndFilterStruct.groupDelay = round(groupDelay.Data(1));
            else
                self.frontEndFilterStruct     = p.Results.frontEndFilterStruct;
            end
            
            self.adaptiveFilterFlag = p.Results.adaptiveFilterFlag;
            if isempty(self.adaptiveFilterFlag)
                self.adaptiveFilterFlag = false;
            end
            self.adaptiveFilterParams = p.Results.adaptiveFilterParams;
            
            self.ResetFilterState();
        end
        
        function [filteredData, delayedTriggerSignal] = ApplyFrontEndFilter(self,rawData,triggerSignal)
            % Applies front end fitlering with state:
            % Inputs:
            %   rawData         -           raw data matrix (nSamples x nChannels)
            %   triggerSignal   -           trigger signal (nSamples x 1)
            %
            % Ouputs
            %   filteredData    -           filtered data of same size as rawData
            %   triggerSignal   -           delayed trigger signal to align
            %                               filtered dfata to eeg events
            
            % filter data (if non empty)
            if ~isempty(rawData)
                [filteredData, self.filterState] = filter(...
                                                    self.frontEndFilterStruct.Num,...
                                                    self.frontEndFilterStruct.Den,...
                                                    rawData,...
                                                    self.filterState,...
                                                    1);     % dim to filter along
                
                allTriggers = [self.triggerBuffer; triggerSignal(:)];
                delayedTriggerSignal = allTriggers(1:length(triggerSignal));
                self.triggerBuffer = allTriggers(length(triggerSignal)+1:end);
            else
                filteredData = [];
                delayedTriggerSignal = [];
            end
        end
        
        function [filteredData] = ApplyAdaptiveFilter(self, rawData)
            % Applies adaptive filter 
            
            % filter data (if non empty)
            if ~isempty(rawData)
                filteredData = zeros(size(rawData));
                numChannels = length(self.channelList);                            
                
                refIdx = find(self.channelList==self.adaptiveFilterParams.refIdx,1);
                noiseSignal = rawData(:,refIdx);

                for idxChannel = 1:numChannels
                    [~,filteredData(:,idxChannel)]  = step(self.adaptiveFilterObj{idxChannel},noiseSignal,rawData(:,idxChannel)); 
                end
            else
                filteredData = [];
            end
        end
                
        function trialData = GetTrial(self,varargin)
            % Gets data from amp according to trigger type. One trial at a
            % time.
            %
            % Inputs:
            %   'triggerType'         -    'block' : assumes that valid
            %                               data occurs only on non-zero trigger
            %   'checkFreq'           -     Frequency of checking for valid
            %                               trial if none exists. 10 Hz default
            %   'maxCheckTime'        -     Timeout in seconds. 10 seconds
            %                               default
            %
            % Ouputs
            %   trialData             -     Data for a valid trial
            %                               
            
            p = inputParser;
            p.addParameter('frontEndFilterFlag',self.frontEndFilterFlag,@islogical);
            p.addParameter('adaptiveFilterFlag',self.adaptiveFilterFlag);
            p.addParameter('triggerType',self.triggerType,@(x)(any(strcmpi(x,{'custom','block'}))));
            p.addParameter('checkFreq',10,@isscalar);
            p.addParameter('maxCheckTime',10,@isscalar);
            p.parse(varargin{:});
            
            switch p.Results.triggerType
                case 'block'
                    tStart = tic;
                    triggerSignal = [];
                    
                    trialData = [];
                    
                    toZeroExists = @(x)(any(diff(logical(x)) == -1));
                    
                    triggerCheck = true;
                    
                    while true
                        pause(1/p.Results.checkFreq);
                        [data, tmpTriggerSignal] = self.GetData('frontEndFilterFlag',p.Results.frontEndFilterFlag,'adaptiveFilterFlag',p.Results.adaptiveFilterFlag);
                                                
                        if triggerCheck && ~isempty(tmpTriggerSignal) && logical(tmpTriggerSignal(1))
                            warning('init trigger not 0');
                        end
                        triggerCheck = false;
                        
                        triggerSignal = [triggerSignal; tmpTriggerSignal]; %#ok<AGROW>
                        trialData = [trialData ; data]; %#ok<AGROW>
                         
                        tEnd = toc(tStart);
                        timeout = tEnd > p.Results.maxCheckTime;
                        
                        if timeout || toZeroExists(triggerSignal)
                            break
                        end
                    end
                    
                    trialData = trialData(logical(triggerSignal),:);
                    
                    firstTrialEndIdx = find(~(diff(logical(triggerSignal))+1),1,'first');
                    lastTrialBeginIdx =  find(~(diff(logical(triggerSignal))-1),1,'last');
                    
                    if ~isempty(lastTrialBeginIdx)
                        if (lastTrialBeginIdx > firstTrialEndIdx) && ~strcmpi(class(self),'DAQnoAmp')
                            error('More than 1 block trial detected!  Call getTrial when there is <= 1 trial available.')
                        end
                    end
                otherwise
                    warning('Trigger type not supported in GetTrial')
            end
            
            if timeout
                error('getTrial timeout, %g sec passed without receiving full trial',p.Results.maxCheckTime);
            end
        end
        
        % ResetFilterState - clears the internal trigger buffer and filter state
        function ResetFilterState(self)
            
            % Set filter state to 0s
            self.filterState = zeros(max(length(self.frontEndFilterStruct.Num),length(self.frontEndFilterStruct.Den))-1,...
                                length(self.channelList));
                            
            % Set triggerBuffer equal to group delay to align trigger with
            % collected eeg traces
            self.triggerBuffer = zeros(self.frontEndFilterStruct.groupDelay, 1);
            
            % Reset adaptive filters if enabled
            if self.adaptiveFilterFlag
                numChannels = length(self.channelList);
                invCovariance = (1/self.adaptiveFilterParams.delta)*eye(self.adaptiveFilterParams.order,self.adaptiveFilterParams.order); % Initial setting for the P matrix
                for idxChannel = 1:numChannels
                    self.adaptiveFilterObj{idxChannel} = dsp.RLSFilter(self.adaptiveFilterParams.order,'InitialInverseCovariance',invCovariance,'ForgettingFactor',self.adaptiveFilterParams.lambda);
                end
            end
            
        end
        
        function success = ParallelPortTriggerTest(self)
            % Tests the triggers received by the amplifiers. This function uses the inpout
            % library for the communication with the PCI port. The function checks the
            % following properties of the triggers.
            %   * The connection of the higher and the lower 4 bits.
            %   * The number of the triggers sent and received.
            %   * The values of the triggers sent and received.
            %   * The pulse width of the triggers sent and received.
            %   * The values of the first and last triggers sent and received.           
            %
            %   Output:
            %
            %      success - A flag that show the success of the procedure.
            %          
            
            if ~self.triggerFlag
                success = 0;
                warning('Trigger disabled');
                return;
            end
            
            triggerObj = TriggerParallel();
            
            triggerPulsewidth = 10/self.fs;
            numberOfTestIterations = 10;
            triggerTestValues = [15;240];
            triggerPulsewidthStdThreshold=1/self.fs;
            
            statusBeforeTest = self.status;
            
            if self.status == self.STATUS_STANDBY
                self.OpenDevice();
            end
            
            if self.status ~= self.STATUS_OPEN
                success = 0;
                warning('Trigger test only works if device is open or on stand by');
                return;
            end            
            
            disp('Testing the connection between the parallel port and the amplifier(s)...')
                       
            self.StartAcquisition();            
            triggerTestContinue = 1;
            
            while(triggerTestContinue)
                pause(0.050);
                
                % Using the inpout library to communicate with the PCI port.
                for idxIteration=1:numberOfTestIterations
                    for triggerTestIndex=1:length(triggerTestValues)
                        tic;
                        triggerObj.SendTrigger(triggerTestValues(triggerTestIndex));
                        while(toc<triggerPulsewidth)
                        end
                    end
                end
                triggerObj.SendTrigger(0);
                               
                pause(0.5);
                
                % Reading the trigger data from amplifiers and testing if the received trigger properties are the same as the ones that we sent.
                [~,triggerSignal]=self.GetData('frontEndFilterFlag',false);
                
                diffTriggerLocs=find(diff(triggerSignal));
                triggerChangeValues=triggerSignal(diffTriggerLocs(1:end-1)+1);
                firstTriggerValue=triggerSignal(1);
                lastTriggerValue=triggerSignal(end);
                
                uniqueTriggerValues=unique(triggerSignal);
                if(isempty(find(uniqueTriggerValues==triggerTestValues(1), 1))) % Checking if the lower 4 bits are working properly
                    lower4bitsOk=0;
                else
                    lower4bitsOk=1;
                end
                
                if(isempty(find(uniqueTriggerValues==triggerTestValues(2), 1))) % Checking if the higher 4 bits are working properly
                    higher4bitsOk=0;
                else
                    higher4bitsOk=1;
                end
                
                if(firstTriggerValue~=0 || lastTriggerValue~=0) % First and last received trigger values should be zero
                    errorMsg='Trigger test failed: Cannot set the trigger to zero.';
                    success=0;
                else
                    success=0;
                    expectedTriggerValues=repmat(triggerTestValues,numberOfTestIterations,1);
                    if(lower4bitsOk && higher4bitsOk)
                        if(length(expectedTriggerValues)~=length(triggerChangeValues)) % Checking the number of the received triggers
                            errorMsg='Trigger test failed: Unexpected number of trigger pulses';
                        else
                            if(any(expectedTriggerValues~=round(triggerChangeValues))) % Checking the values of the received triggers
                                errorMsg='Trigger test failed: Digital I/O cables might be connected in wrong order. Please swap the cables.';
                            else
                                if(std(diff(diffTriggerLocs(2:end)))>triggerPulsewidthStdThreshold) % Checking the pulsewidth of the received triggers
                                    errorMsg='Trigger test failed: Trigger timing is not accurate.';
                                else
                                    disp('Trigger test was successful.');
                                    success=1;
                                end
                            end
                        end
                    elseif(~lower4bitsOk && higher4bitsOk)
                        errorMsg='Trigger test failed: First digital I/O cable is not working.';
                    elseif(lower4bitsOk && ~higher4bitsOk)
                        errorMsg='Trigger test failed: Second digital I/O cable is not working.';
                    else
                        errorMsg='Trigger test failed: No triggers are received. Please check the connections.';
                    end
                end
                
                if(success==1)
                    triggerTestContinue=0;
                else
                    disp(errorMsg);
                    tryAgain=input('Try again? (y/n):','s');
                    if(tryAgain=='n')
                        triggerTestContinue=0;
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
        
    end
end
