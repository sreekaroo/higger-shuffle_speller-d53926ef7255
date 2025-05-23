clearvars; clc;

%% parameters
numStim = 2;
numTrialsPerStim = 3;
numTrialsPerStimChan = 4;

%% testing
calibStimSchedObj1 = calibStimSched(numStim,...
    'numTrialsPerStim', numTrialsPerStim);

calibStimSchedObj2 = calibStimSched(numStim,...
    'numTrialsPerStimChan', numTrialsPerStimChan);