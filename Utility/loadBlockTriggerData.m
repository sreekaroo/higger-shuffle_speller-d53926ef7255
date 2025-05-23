function [data, fs, channelNames, sessionFolder, trialKeptFlag] = loadBlockTriggerData(varargin)

%% input parser
p = inputParser;
p.addParameter('daqFile',[],@iscell);
p.addParameter('sessionFolder',[],@isstr);
p.addParameter('frontEndFilterFlag',false,@islogical);
p.addParameter('minToMaxTrial', 0, @isscalar);
p.addParameter('discardEyeRejectFlag', false, @islogical);
p.parse(varargin{:});

%% call loadSessionData, reads in .daq file
if ~isempty(p.Results.daqFile) && ~isempty(p.Results.sessionFolder)
    [inputData,triggerSignal,sampleRate,channelNames,~,~,~] = ...
        loadSessionDataBin(...
        'daqFileList',p.Results.daqFile,...
        'sessionFolder',p.Results.sessionFolder,...
        'saveMatFileFlag',false);
    sessionFolder = p.Results.sessionFolder;
else
    [inputData,triggerSignal,sampleRate,channelNames,~,~,sessionFolder] = ...
        loadSessionDataBin('saveMatFileFlag',false);
end

%% filter (if active)
numChannels = size(inputData,2);

if p.Results.frontEndFilterFlag
    % load daqEEGobj to apply filter
    fileStruct = dir(sessionFolder);
    files = {fileStruct(:).name};
    targetFileLogical = cellfun(@(x)(~isempty(x)), ...
        strfind(files, 'presObj.mat'));
    assert(sum(targetFileLogical) == 1, 'unique presObj file not found');
    targetFile = files{targetFileLogical};
    load([sessionFolder, targetFile]);
    
    % apply filter
    [inputData, triggerSignal] = ...
        daqEEGobj.ApplyFrontEndFilter(inputData,triggerSignal);
end

%% find starting and ending location of trials
startEndPoints = find(abs(diff(logical(triggerSignal))));

 %assumes a 0 starting trigger signal
pts = [startEndPoints(1:2:end) ,startEndPoints(2:2:end)];

%% discard eye track fails (if active)
if p.Results.discardEyeRejectFlag
    numTrials = size(pts, 1);
    assert(numTrials == length(eyeTrackSuccess), ...
        'invalid eyeTrackSuccess length')
    
    pts = pts(logical(eyeTrackSuccess), :);
end

% throw out all trial lengths which are < 95% of max trial length
trialLengths = diff(pts');
trialKeptFlag = ...
    trialLengths >= p.Results.minToMaxTrial * max(trialLengths);
pts = pts(trialKeptFlag, :);
trialLengths = trialLengths(trialKeptFlag);
minTrialLength = min(trialLengths);

%% report stats on read in data
numTrials = size(pts, 1);
fprintf('%g trials of length %g samples in %g channels were found\n', ...
    numTrials, minTrialLength, numChannels);

% data  = (numChannels x trialLength x numTrials)
for trialIdx = numTrials : -1 : 1
    startPt = pts(trialIdx, 1);
    data(:,:,trialIdx) = inputData(...
        startPt : startPt + minTrialLength - 1, :)';
end

fs = sampleRate;
end