% this script details the parameters of classifiers to be trained.
%
% it is expected that some stimSSVEPObj is in workspace when this is called
%
% Please note that the output of this script (and the input to
% classifierAnalysis) is simply a cell array of classifiers and the
% associated trial lengths each should operate on.

%% analysis parameters
% kFoldk is a scalar number of folds in k fold cross validation
kFoldk = 10;

%% computation parameters
% verboseFlag is 1x1 logical which toggles command line output of progress
verboseFlag = true;

% graphFlag is a 1x1 logical which triggers graphing of acc/ITR vs time
graphFlag = true;

%% basic classifier parameters
% classifiers are trained on different trial lengths to allow a caretaker
% to select the best one

% shortest trial length
minTrialLengthSec = 1;

% total number of trial lengths to train on
numTrialLengths = 20;

switch class(stimSSVEPObj)
    case 'stimFreq'
        fprintf('training freq classifiers\n');
        classifierParamsAppFreq;        
    case 'stimMSeq'
        fprintf('training mSeq classifiers\n');
        classifierParamsAppMseq;
    otherwise
        error('stim not recognized, maybe implement your own classifier?')   
end
