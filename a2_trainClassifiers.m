clearvars; clc;

timeDim = 2;    % dim which seperates data in time
trialDim = 3;   % dim which seperates data among trials

%% load data
% load EEG data
[EEGdata, fs, channelNames, sessionFolder, trialKeptFlag] = ...
    loadDataShuffleSpeller(...
    'minToMaxTrial', .95, ...
    'discardEyeRejectFlag', true);

% load calibration objects
addpath(genpath(sessionFolder));
% Go two levels up from eegFolder
parent1 = fileparts(sessionFolder);  % first level up
parent2 = fileparts(parent1);  % second level up
sessionFolderTrue = fileparts(parent2);  % second level up


% Recursively search for any file containing '_presObj.mat'
targetFileStr = '_presObj.mat';
allFiles = dir(fullfile(sessionFolderTrue, '**', ['*' targetFileStr]));

assert(~isempty(allFiles), 'No _presObj.mat file found');
assert(length(allFiles) == 1, 'Multiple _presObj.mat files found');

% Construct full path to file
targetFilePath = fullfile(allFiles(1).folder, allFiles(1).name);

% Load the file
load(targetFilePath);


%% load classifierParams
stimSSVEPObj = controlCalibObj.stimSSVEPObj;
classifierParamsApp;

%% build trialLengthSec
trialLengthSec = linspace(minTrialLengthSec, size(EEGdata,2) / fs, numTrialLengths);

%% discard any trials which are not at least 95% length of longest
calibStimSchedObj.RmTrials(~trialKeptFlag);

%% stack EEG data by target class
numClasses = length(stimSSVEPObj.stimStruct);
sortEEGdata = cell(numClasses, 1);
for classIdx = 1 : numClasses
    classMask = calibStimSchedObj.targetStimIdx == classIdx;
    sortEEGdata{classIdx} = EEGdata(:, :, classMask);
end

%%
analyzeTrainClassifierObj = analyzeTrainClassifier(classifierObj,...
    'verboseFlag', verboseFlag,...
    'paralellFlag', false);

[trainedClassifiers, perfMetric] = ...
    analyzeTrainClassifierObj.Learn(sortEEGdata,fs, ...
    'timeDim', timeDim, ...
    'trialDim', trialDim, ...
    'kFoldk',kFoldk,...
    'trialLengthSec',trialLengthSec,...
    'prior',prior);

if graphFlag
    analyzeTrainClassifierObj.GraphPerformanceMetrics(...
        'classifierDescription',classifierLabel, ...
        'trialLength', trialLengthSec, ...
        'perfMetric', perfMetric);
end

%% save trained classifiers and performance metrics in original folder
timestamp = datestr(now,'_mmm-dd-yyyy_HH-MM_AM');
saveFolder = [sessionFolder, 'classifiers', timestamp];
mkdir(saveFolder);
savefilename = [saveFolder, '\classifiers.mat'];

save(savefilename, ...
    'trainedClassifiers', ...
    'perfMetric', ...
    'stimSSVEPObj', ...
    'trialLengthSec', ...
    'fs', ...
    'analyzeTrainClassifierObj', ...
    'classifierLabel');

% mv all files with 'classifierParamsApp' from param to 'classifiers'
% folder
targetFile = 'classifierParamsApp.m';
targetFolder = which(targetFile);
targetFolder = targetFolder(1:end-length(targetFile));
files = dir(targetFolder);
files = {files.name};
targetPresent = strfind(files, targetFile(1:end-2));
targetPresent = cellfun(@(x)(~isempty(x)), targetPresent);
files = files(targetPresent);
for fileIdx = 1 : length(files)
    filename = files{fileIdx};
    copyfile([targetFolder, filename], ...
        [saveFolder, '\save_', filename]);
end