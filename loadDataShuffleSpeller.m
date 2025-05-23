function [data, fs, channelNames, sessionFolder, trials, pts, numTrials, targetIdx] = loadDataShuffleSpeller(varargin)

%% input parser
p = inputParser;
p.addParameter('daqFile',[],@isstr);
p.addParameter('sessionFolder',[],@isstr);
p.addParameter('frontEndFilterFlag',false,@islogical);
p.addParameter('minToMaxTrial', 0, @isscalar);
p.addParameter('discardEyeRejectFlag', false, @islogical);
p.parse(varargin{:});

%% call loadSessionData, reads in .daq file

[inputData,triggerSignal,sampleRate,channelNames,~,~,~] = ...
    loadSessionDataBin(...
    'daqFileName',p.Results.daqFile,...
    'sessionFolder',p.Results.sessionFolder,...
    'saveMatFileFlag',false);
sessionFolder = p.Results.sessionFolder;


%% filter (if active)
numChannels = size(inputData,2);

% load calibration objects
addpath(genpath(sessionFolder));


% Recursively search for any file containing '_presObj.mat'
targetFileStr = '_presObj.mat';
allFiles = dir(fullfile(sessionFolder, '**', ['*' targetFileStr]));
assert(~isempty(allFiles), 'No _presObj.mat file found');
% Construct full path to file
targetFilePath = fullfile(allFiles(1).folder, allFiles(1).name);
% Load the file
load(targetFilePath, 'calibStimSchedObj');
targetIdx = calibStimSchedObj.targetStimIdx;  

%% find starting and ending location of trials
startEndPoints = find(abs(diff(logical(triggerSignal))));

 %assumes a 0 starting trigger signal
pts = [startEndPoints(1:2:end) ,startEndPoints(2:2:end)];

% throw out all trial lengths which are < 95% of max trial length
trialLengths = diff(pts');
minTrialLength = min(trialLengths);

%% report stats on read in data
numTrials = size(pts, 1);
fprintf('%g trials of length %g samples in %g channels were found\n', ...
    numTrials, minTrialLength, numChannels);

% data  = (numChannels x trialLength x numTrials)
for trialIdx = numTrials : -1 : 1
    startPt = pts(trialIdx, 1);
    trials(:,:,trialIdx) = inputData(...
        startPt : startPt + minTrialLength - 1, :)';
end

fs = sampleRate;

data = inputData;

end