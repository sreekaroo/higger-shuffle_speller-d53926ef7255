function continueFlag = launchGUI(varargin)
% Launches GUI to observe signals. User can provide a daq obj or give some
% parameters to set up a local daq obj. 
% Inputs:
%   'fileName'      -   String with path to file that will store data collected
%                       during GUI execution
%   'fs'            -   Sample rate in Hz
%   'channelList'   -   List of channels to acquire [1xnChannels]
%   'channelNames'  -   Cell with strings to label channels in GUI [nChannels x 1]
%   'daqType'       -   gUSBAmp (default) or noAmp
%   'daqManagerObj' -   Daq obj to use for GUI execution (overrides
%                       settings)

% Input parser
p = inputParser;
p.addParameter('fileName',[],@isstr);
p.addParameter('fs',256, @isscalar);
p.addParameter('channelList',1, @isnumeric);
p.addParameter('channelNames',{'Oz'}, @iscell);
p.addParameter('daqType','gUSBAmp', @isstr);
p.addParameter('daqManagerObj', []);
p.parse(varargin{:});

argPassed = @(x)(~ismember(x, p.UsingDefaults));

% Add stuff to path
mfilepath=fileparts(which('launchGUI.m'));
addpath(fullfile(mfilepath,'../matlab'));
addpath(fullfile(mfilepath,'../ext/signalmonitoringgui'));

if argPassed('daqManagerObj')
    daqManagerObj = p.Results.daqManagerObj;
    daqStatusInit = daqManagerObj.status;
else
    % If no saq obj is given, create one here
    fs = p.Results.fs;
    channelList = p.Results.channelList;
    daqType = p.Results.daqType;
    
    if argPassed('channelNames')
        channelNames = p.Results.channelNames;
    else
        % built list of channel names from channelList idxs
        channelNames = cellstr(num2str(p.Results.channelList(:)))';
    end
    
    if numel(channelNames) ~= numel(channelList)
        warning('Number of channels and channel names do not match');
    end
    
    % Initialize daqManager
    switch daqType
        case 'gUSBAmp'
            daqManagerObj = DAQgUSBAmp(...
                'fs',fs,...
                'testParalellPortFlag', false,...            
                'channelList', channelList, ...
                'channelNames', channelNames);
        case 'noAmp'
            error('Not yet implemented')
            daqManagerObj = noAmpManager(...
                 'fs',fs,...
                 'channelParametersFilename','channels.csv',...
                 'genericRecordFilename',genericRecordFilename, ...
                 'channelNames', channelNames);
        otherwise
            error('invalid daqType');
    end
end

%% init save folder
fileName = p.Results.fileName;

% launchGUI
showGUI = 1;
guiRunIndex = 0;
popUpWindowDecision = true;
if daqManagerObj.status == daqManagerObj.STATUS_STANDBY;
    daqManagerObj.OpenDevice;
end
    
while popUpWindowDecision
    
    [selection,~] = listdlg(...
        'PromptString','Select which action you would like to run:',...
        'ListString',{'Monitor signals in GUI', 'Continue session'},...
        'SelectionMode', 'single');
    
    if isempty(selection) % If no option is selected
        popUpWindowDecision = false;
        continueFlag = false;
        showGUI = false;
    elseif selection == 1 % If monitoring signal in gui is selected
        continueFlag = false;
        showGUI = true;
    elseif selection == 2 % If continue session is selected
        popUpWindowDecision = false;
        continueFlag = true;
        showGUI = false;
    end
    
    if showGUI
        % Start GUI MATLAB
        displayMode = 0;
        
        GUI = SignalMonitorGUI();
        GUI.start();
        GUI.setChannelNames(daqManagerObj.channelNames);
        GUI.setSampleRate(daqManagerObj.fs);
        
        % Start data acquisition
        daqManagerObj.StartAcquisition('fileName',fileName);

    end
    
    % Show signals with GUI
    while(showGUI)
        % Get display mode: 1 - no data, 2 - raw data, 3 - filtered data
        newDisplayMode = GUI.getDisplayMode();
        
        if displayMode ~= newDisplayMode
            displayMode = newDisplayMode;
            % Initialise new display mode properties.
            switch displayMode;
                case {GUI.displayModeOptions.RAW_DATA,GUI.displayModeOptions.FILTERED_DATA}
                    GUI.setChannelNames(daqManagerObj.channelNames);
            end
        end
        
        % Fetch appropriate data
        frontEndFilterFlag = displayMode == GUI.displayModeOptions.FILTERED_DATA;
        [data,~] = daqManagerObj.GetData('frontEndFilterFlag', frontEndFilterFlag);
        
        if ~isempty(data)
            GUI.addData(data);
        end
        
        % Check if GUI frame is still open
        showGUI = GUI.isStarted();
        
        if ~GUI.isStarted()
            showGUI = false;
            daqManagerObj.StopAcquisition();
            
            guiRunIndex = guiRunIndex + 1;
        end
        
        pause(1/40)
    end        
    
end

% cleanup
if argPassed('daqManagerObj')
    % return device to initial status
    if daqStatusInit ~= daqManagerObj.STATUS_OPEN
        % device was not open when passed, close before returning
        daqManagerObj.CloseDevice();
    end
else
    % Close and delete object (if user didn't pass it in the first place)
    daqManagerObj.CloseDevice();
    delete(daqManagerObj);
end