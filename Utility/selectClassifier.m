%% selectClassifier.m
% loads classifiers from freqClassifierSSVEP, displays graphs of their
% performance across classifier and user and accepts commandline input from
% user to select from the classifiers.

function [classifierObj,stimSSVEPObj,stimLengthSec,perfMetric, sessionFolder] = selectClassifier(varargin) %#ok<STOUT>

%% inputParser
p = inputParser;
p.addParameter('interTrialWait',2,@isscalar);
p.addParameter('pickMaxITRflag', false, @islogical);
p.parse(varargin{:});

pickMaxITRflag = p.Results.pickMaxITRflag;

%% get file, load it, graph
[fileName,sessionFolder]=uigetfile('*.mat','Select appropriate classifiers.mat');
load([sessionFolder,fileName]);

%% perform selection
numClassifiers = length(classifierLabel); %#ok<*USENS>

userConfirmSelection = false;
while ~userConfirmSelection
    
    %% graph analysis for user
    [~, ITR_adjusted] = analyzeTrainClassifierObj.GraphPerformanceMetrics(...
        'perfMetric', perfMetric, ...
        'trialLength', trialLengthSec, ...
        'classifierDescription',classifierLabel,...
        'interTrialWait',p.Results.interTrialWait);
    
    validSelection = false;
    
    clc;
    while ~validSelection
        fprintf('Idx     Classifier Type\n');
        
        if numClassifiers > 1
            for classifierIdx = 1 : numClassifiers
                fprintf([num2str(classifierIdx), '       ', classifierLabel{classifierIdx}, '\n']);
            end
            fprintf('\n');
            
            selectionClassifierIdx = input('Please use graph to select classifier type idx: ');
        else
            selectionClassifierIdx = 1;
        end
        
        if ismember(selectionClassifierIdx,1:numClassifiers)
            if ~pickMaxITRflag
                fprintf('\nIdx     Trial Length\n');
                for trialLengthIdx = 1 : length(trialLengthSec)
                    fprintf([num2str(trialLengthIdx), '       ', num2str(trialLengthSec(trialLengthIdx)), ' sec \n']);
                end
                fprintf('\n');
                
                selectionTrialLengthIdx = input('Please select trial length idx: ');
                
                if ismember(selectionTrialLengthIdx,(1:length(trialLengthSec)));
                    validSelection = true;
                end
            else
                [~, selectionTrialLengthIdx] = ...
                    max(ITR_adjusted(:, selectionClassifierIdx));
                validSelection = true;
            end
        end
        
        if ~validSelection
            clc;
            fprintf('invalid selection\n\n');
        end
    end
    
    %% set outputs
    tempPerfMetric = perfMetric(selectionClassifierIdx,selectionTrialLengthIdx); %#ok<*NODEF>
    classifierObj = ...
        trainedClassifiers{selectionClassifierIdx,selectionTrialLengthIdx};
    stimLengthSec = trialLengthSec(selectionTrialLengthIdx);
    
    %% show user selection
    % compute ITR conversion factor (to real ITR)
    ITRconversionFactor = stimLengthSec / (p.Results.interTrialWait + stimLengthSec);
    
    clc; close all;
    fprintf('--------Selected Classifier Information--------\n');
    fprintf(['Classifier Type: ', classifierLabel{selectionClassifierIdx},'\n']);
    fprintf(['Trial Length: ', num2str(trialLengthSec(selectionTrialLengthIdx)),' sec \n\n']);
    fprintf('Assuming a uniform prior over checkerboards:\n');
    fprintf('... expected accuracy: %g \n', tempPerfMetric.acc*100);
    fprintf('... expected ITR no wait time (bits / min): %g \n', tempPerfMetric.ITR);
    fprintf('... expected ITR %g sec wait time (bits / min): %g \n\n', p.Results.interTrialWait,tempPerfMetric.ITR*ITRconversionFactor);
    fprintf('stim: ');
    stimSSVEPObj %#ok<NOPRT>
    fprintf('\n');
    fprintf('confusionMatrix:\n');
    disp(tempPerfMetric.confMatrix);
    
    %% confirm selection with user
    userConfirmInput = input('Is this the classifier you want to use? (y/n):','s');
    userConfirmSelection = strcmpi(userConfirmInput,'y');
    pickMaxITRflag = false;
end

perfMetric = tempPerfMetric;
end