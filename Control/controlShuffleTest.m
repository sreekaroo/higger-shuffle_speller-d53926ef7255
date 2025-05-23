clearvars; clc; sca; jheapcl;

%% BCI meeting params
copyPhraseStr = '%salad for dinner';

% maxInfo, uniform, random, huffman, sequential, huffmanFreeze
codeType = 'maxInfo';

% for decision tree style codes only.  if true, naively selects the leaf of
% the decision tree.  If false, selects the most likely letter given
% language model and all evidence inputs.
naiveDecFlag = true;

% number of user symbol (unique SSVEP, MI etc).  must be even for demo
numX = 6;

% accuracy of each user symbol (mistakes assumed uniformly distributed)
probYgivenX = lins pace(.9, .5, numX);

%% parameters
screenNumber = 0;

% 'animate', 'teleport', 'colorCode'
iconStimAssocMode = 'animate';
colorCodedIconFlag = true;
colorTargetFlag = false;
screenSizePix = [1, 1, 800, 600];
% screenSizePix = [1930, 10, 1930 + 950, 1070];

% 'alpha' or 'binary'
mode = 'alpha';
msgTargetBin = [dictAlpha.yes, dictAlpha.yes, dictAlpha.no];

% for testing mode, select either keyboard xor mouse input, if neither are
% selected it will attempt to stimulate and get data from daq
kbInterfaceFlag = false;
msInterfaceFlag = true; 

minMaxNumTrials = [1, nan];

% timing params 
timeBarAnim = 1;
timePreAssocFirst = 3;
timePreAssoc = .75;
timeAnim = .75;
timePostAssoc = 0;

minDecProb = .85;

iconBoxNumIcons = 100;
textBoxTextSize = 18;
barGraphFlag = true;

% confusion matrix
% probYgivenX = linspace(.95, 1/numX, numX);
probYgivenX = diag(probYgivenX) + ...
    (ones(numX) - eye(numX)) * diag((1-probYgivenX) / (numX - 1));

iconBoxesPerRowCol = [numX / 2, 2];

% where to indicate sounds, after a decision has been made (dec) or before
% a decision, indicating target (next).  Only one may be active
soundDecFlag = true;
soundDecNextFlag = false;
soundTrialWav = 'tic.wav';

%% dependant / lesser params
iconStimAssocWidth = .7;
dashPosRatio = [iconStimAssocWidth, 0, 1, 1];
iconStimAssocPosRatio = [0, 0, iconStimAssocWidth, 1];

switch mode
    case 'alpha'
        dictAlphaSym = dictAlpha.Convert(1:28);
    case 'binary'
        dictAlphaSym = [dictAlpha.yes, dictAlpha.no];
    otherwise
        error('invalid mode');
end
iconPaths = {dictAlphaSym(:).image};
%% init codeObj
switch codeType
    case 'maxInfo'
        codeObj = MaxInfoCode('probYgivenX', probYgivenX,...
            'calculationMethod','hillClimb');
    case {'huffman', 'huffmanFreeze'}
        codeObj = HuffmanCode('probYgivenX', probYgivenX,...
            'verboseFlag',false);
        if strcmp(codeType, 'huffmanFreeze')
            letterProbLoad;
            % alphabetize
            [~, idx] = sort(letter);
            
            % http://norvig.com/mayzner.html
            SP_PROB = 1/5.79;
            
            letterProb = [letterProb(idx) * (1-SP_PROB); SP_PROB];
            
            BS_PROB = .05;
            letterProb = [letterProb * (1 - BS_PROB); BS_PROB];
            
            codeObj.Build(letterProb);
            codeObj.freezeFlag = true;
        end
        
    case 'sequential'
        codeObj = SequentialCode('probYgivenX', probYgivenX,...
            'verboseFlag',false);
    case 'uniform'
        codeObj  = UniformCode('probYgivenX', probYgivenX);
    case 'random'
        codeObj  = RandomCode('probYgivenX', probYgivenX);
    otherwise
        error('code type not recognized')
end

%% init
% init iconStimAssoc
iconStimAssocObj = iconStimAssoc(...
    'screenNumber', screenNumber, ... 
    'iconPaths',iconPaths,...
    'animTime', timeAnim,...
    'iconBoxesPerRowCol', iconBoxesPerRowCol,...
    'posRatio', iconStimAssocPosRatio,...
    'iconBoxesBordPix', 20, ...
    'mode', iconStimAssocMode, ...
    'colorCodedIconFlag', colorCodedIconFlag);

% init language model
if ispc && strcmp(mode, 'alpha');
    languageModelObj = languageModel;
else
    languageModelObj = languageModelDM(...
            'numChar', length(dictAlphaSym));
end

% init copyPhrase
switch mode
    case 'alpha'
        copyPhraseObj = CopyPhrase(...
            'copyPhraseStr', copyPhraseStr, ...
            'codeObj', codeObj, ...
            'minDecProb', minDecProb, ...
            'naiveDecFlag', naiveDecFlag, ...
            'dictAlphaSym', dictAlphaSym, ...
            'minMaxNumTrials', minMaxNumTrials);
        wrapIconPointers = iconStimAssocObj.iconStruct.pointer(dictAlpha.sp.idx);
        barGraphDirection = 'up';
    case 'binary'
        copyPhraseObj = CopyPhrase(...
            'msgTarget', msgTargetBin, ...
            'codeObj', codeObj, ...
            'minDecProb', minDecProb, ...
            'naiveDecFlag', naiveDecFlag, ...
            'dictAlphaSym', dictAlphaSym, ...
            'minMaxNumTrials', minMaxNumTrials);
        wrapIconPointers = [];
        barGraphDirection = 'left';
end

% init dashboard
dashboardObj = dashboard(...
    'windowPointer', iconStimAssocObj.windowPointer, ...
    'iconPointers', iconStimAssocObj.iconStruct.pointer, ...
    'posRatio', dashPosRatio, ...
    'iconBoxNumIcons', iconBoxNumIcons, ...
    'textBoxTextSize', textBoxTextSize, ...
    'barGraphFlag', barGraphFlag, ...
    'wrapIconPointers', wrapIconPointers, ...
    'barGraphDirection', barGraphDirection);

% init controlShuffle
controlShuffleObj = controlShuffle(...
    'windowPointer', dashboardObj.windowPointer, ...
    'dictAlphaSym', dictAlphaSym, ...
    'languageModelObj', languageModelObj, ...
    'dashboardObj', dashboardObj, ...
    'iconStimAssocObj', iconStimAssocObj, ...
    'kbInterfaceFlag', kbInterfaceFlag, ...
   'msInterfaceFlag', msInterfaceFlag, ...
    'colorTargetFlag', colorTargetFlag, ...
    'timePreAssocFirst', timePreAssocFirst, ...
    'timePreAssoc', timePreAssoc, ...
    'timePostAssoc', timePostAssoc, ...
    'timeBarAnim', timeBarAnim, ...
    'soundTrialWav', soundTrialWav, ...
    'soundDecNextFlag', soundDecNextFlag, ...
    'soundDecFlag', soundDecFlag);

ShowCursor;

% controlShuffleObj.Tutorial;
controlShuffleObj.RunCopyPhrase(copyPhraseObj);

sca;