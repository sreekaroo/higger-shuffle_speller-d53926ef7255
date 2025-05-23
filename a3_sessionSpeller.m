%% load parameters
clear; clc;

% build path
projectID = 'speller';
sessionID = 'dev';
path = setPathAndSavefile('targetFile', 'sessionSpeller.m');

% debug option (ensure false for real EEG please)
dummyDaqFlag = false;
 
%% load parameters
jheapcl;
presentationParams;
spellerParams;

%% select classifier
if ~strcmp(iconStimAssocMode, 'animate')
    timeAnim = 0;
end

[classifierObj, stimSSVEPObj, stimLengthSec, perfMetric, sessionFolder] = ...
    selectClassifier(...
    'interTrialWait', timePreAssocFirst + timeAnim + timePostAssoc, ...
    'pickMaxITRflag', pickMaxITRflag);

if length(stimSSVEPObj.stimStruct) ~= size(iconBoxesPosRatio, 2)
    error('numStim (stimSSVEPObj) does not match iconBoxesPosRatio')
end

%% param processing
allDictAlpha = dictAlpha.Convert(1:28);
iconPaths = {allDictAlpha.image};

numStim = length(stimSSVEPObj.stimStruct);
iconBoxesPerRowCol = [numStim / 2, 2];

dashPosRatio = [iconStimAssocWidth, 0, 1, 1];
iconStimAssocPosRatio = [0, 0, iconStimAssocWidth, 1];

%% find save folder
timestr = datestr(now,'mmm-dd-yyyy_HH-MM_AM');
saveFolder = [sessionFolder, sessionID, timestr, '\'];
mkdir(saveFolder);

%% init eyeTracker if need be
if eyeTrackFlag
    daqEyeObj = DaqEyeXareaProp();
        
    % ensure we're getting something
    daqEyeObj.OpenDevice;
    daqEyeObj.StartAcquisition;
    pause(.05);
    assert(~isempty(daqEyeObj.GetData), ...
        'eye tracker not returning data');
    daqEyeObj.StopAcquisition;
else
    daqEyeObj = [];
end

%% Initialize daqManager
idx = strfind(sessionFolder, '\');
idx = idx(end-1);
files = dir(sessionFolder(1:idx));
filenames = {files(:).name};
fileLogical = cellfun(@(x)(~isempty(x)), strfind(filenames, 'presObj.mat'));
saveObjs = load(filenames{fileLogical}, 'daqEEGobj');
daqEEGobj = saveObjs.daqEEGobj;
if dummyDaqFlag
    % replace live daqManager with a dummy
    daqEEGobj = DAQnoAmp('channelNames', daqEEGobj.channelNames);
end

% pre-launch GUI -visually inspect signals before proceeding
continueFlag = launchGUI('daqManagerObj', daqEEGobj);

if continueFlag
    fprintf('gui exited: launching SSVEP speller BCI (continue)\n');
else
    fprintf('gui exited: will not launch SSVEP speller (cancel) \n');
    return;
end

%% initialize stimulation object
LEDstimulationObj = LEDstimulation(...
    'stimLengthsec',stimLengthSec);
if numStim == 4
   LEDstimulationObj.activeChannels = [1, 3, 4, 6]; 
end
LEDstimulationObj.ConfigureStimulusDDS(stimSSVEPObj.stimStruct);

%% build appropriate code object
switch codeType
    case 'maxInfo'
        codeObj = MaxInfoCode('probYgivenX',perfMetric.confMatrix,...
            'calculationMethod','hillClimb');
        naiveDecFlag = false;
    case {'huffman', 'huffmanFreeze'}
        codeObj = HuffmanCode('probYgivenX',perfMetric.confMatrix,...
            'verboseFlag',false);
        naiveDecFlag = false;
        
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
        codeObj = SequentialCode('probYgivenX',perfMetric.confMatrix,...
            'verboseFlag',false);
        naiveDecFlag = true;
    case 'uniform'
        codeObj  = UniformCode('probYgivenX',perfMetric.confMatrix);
        naiveDecFlag = true;
    case 'random'
        codeObj  = RandomCode('probYgivenX',perfMetric.confMatrix);
        naiveDecFlag = false;
    otherwise
        error('code type not recognized')
end

%% init
% init copyPhraseObj (a factory!)
initCopyPhrase = @(x)(CopyPhrase(...
    'copyPhraseStr', x, ...
    'codeObj', codeObj, ...
    'minDecProb', minDecProb, ...
    'naiveDecFlag', naiveDecFlag, ...
    'minMaxNumTrials', minMaxNumTrials));

switch class(copyPhraseStr)
    case 'cell'
        % copyPhraseObj
        numCopyPhrase = length(copyPhraseStr);
        for copyPhraseIdx = 1 : numCopyPhrase
            copyPhraseObj(copyPhraseIdx) = ...
                initCopyPhrase(copyPhraseStr{copyPhraseIdx}); %#ok<SAGROW>
        end
    case 'char'
        copyPhraseObj = initCopyPhrase(copyPhraseStr);
    otherwise
        warning('invalid copyPhraseStr given, entering free spell mode');
        copyPhraseObj = initCopyPhrase('');
end

% init iconStimAssoc
iconStimAssocObj = iconStimAssoc(...
    'hideCursor', false, ...
    'screenNumber', screenNumber, ...
    'iconPaths', iconPaths,...
    'animTime', timeAnim,...
    'iconBoxesPerRowCol', iconBoxesPerRowCol,...
    'iconBoxesPosRatio', iconBoxesPosRatio, ...
    'initIconBoxPosRatio', initIconBoxPosRatio, ...
    'posRatio', iconStimAssocPosRatio,...
    'iconBoxesBordRatio', iconBoxesBordRatio, ...
    'mode', iconStimAssocMode, ...
    'iconBoxesColor', iconBoxesColor, ...
    'colorCodedIconFlag', colorCodedIconFlag);

% init eyeFixCircle if need be
if eyeFixCircleRadius
    white = ones(4, 1) * 255;
    black = [0; 0; 0; 255];
    mkPosRatio = @(x)([ones(2,1) * -x; ones(2,1) * x] + ones(4,1) * .5);
    otherPTBdispObj(1) = oval(...
        'windowPointer', iconStimAssocObj.windowPointer, ...
        'posRatio', mkPosRatio(eyeFixCircleRadius), ...
        'boundPosRatio', iconStimAssocObj.posRatio, ...
        'colorFill', white);
    otherPTBdispObj(2) = oval(...
        'windowPointer', iconStimAssocObj.windowPointer, ...        
        'boundPosRatio', iconStimAssocObj.posRatio, ...
        'posRatio', mkPosRatio(.01), ...
        'colorFill', black);
else
    otherPTBdispObj.Draw = [];
end

% init language model
languageModelObj = languageModel;

% init dashboard
dashboardObj = dashboard(...
    'windowPointer', iconStimAssocObj.windowPointer, ...
    'iconPointers', iconStimAssocObj.iconStruct.pointer, ...
    'posRatio', dashPosRatio, ...
    'iconBoxNumIcons', iconBoxNumIcons, ...
    'textBoxTextSize', textBoxTextSize, ...
    'wrapIconPointers', iconStimAssocObj.iconStruct.pointer(dictAlpha.sp.idx), ...
    'barGraphFlag', barGraphFlag);

% init shuffle control
controlShuffleObj = controlShuffle(...
    'windowPointer', dashboardObj.windowPointer, ...
    'languageModelObj', languageModelObj, ...
    'dashboardObj', dashboardObj, ...
    'iconStimAssocObj', iconStimAssocObj, ...
    'colorTargetFlag', colorTargetFlag, ...
    'timePreAssoc', timePreAssoc, ...
    'timePostAssoc', timePostAssoc, ...
    'timeBarAnim', timeBarAnim, ...
    'timePreAssocFirst', timePreAssocFirst, ...
    'soundTrialWav', soundTrialWav, ...
    'soundDecFlag', soundDecFlag, ...
    'soundDecNextFlag', soundDecNextFlag, ...
    'kbInterfaceFlag', kbInterfaceFlag, ...
    'msInterfaceFlag', msInterfaceFlag, ...
    'LEDstimulationObj', LEDstimulationObj, ...
    'daqManagerObj', daqEEGobj, ...
    'classifierObj', classifierObj, ...
    'daqEyeObj', daqEyeObj, ...
    'otherPTBdispObj', otherPTBdispObj, ...
    'eyeTrackColorFlag', eyeTrackColorFlag, ...
    'eyeTrackMinThresh', eyeTrackMinThresh, ...
    'activeRectColor', activeRectColor);

%% run experiment
daqEEGobj.OpenDevice;
daqEEGobj.StartAcquisition('fileName', [saveFolder, 'eeg.bin']);

try
    controlShuffleObj.RunCopyPhrase(copyPhraseObj, ...
        'spacebarInterTrial', spacebarInterTrial);
catch me
   disp(me.message)
   disp('Error in Run Copy Phrase. Attempting to save data...') 
end

daqEEGobj.StopAcquisition;
daqEEGobj.CloseDevice;
daqEEGobj.delete;

%% cleanup
sca;
delete(languageModelObj);

%% save results
savefile = [saveFolder, 'sessionData.mat'];
save(savefile,...
    'copyPhraseObj',...
    'controlShuffleObj',...
    'codeObj',...
    'classifierObj',...
    'stimSSVEPObj',...
    'stimLengthSec',...
    'perfMetric');

% save all data to mat file, just in case.
savefile = [saveFolder, 'everything.mat'];
save(savefile);

% Try saving the session information from the Copy Phrase Object
try
    % init some arrays for aggregate measures
    agDecTimeArray = [];
    agCharactersPerMinArray = [];
    agNumCorrectArrray = [];
    agTotalTypedArray = [];
    agTotalTimeArray = [];

    for cpIdx = 1 : length(copyPhraseObj)
        % export individual word stats and get back summary measures
        
       if copyPhraseObj(cpIdx).numDec > 0
           [averageDecTime, charactersPerMin, numCorrect, numTotal, totalTime] = copyPhraseObj(cpIdx).export(saveFolder);

           % append to the aggregate arrays
            agDecTimeArray = [agDecTimeArray, averageDecTime];
            agCharactersPerMinArray = [agCharactersPerMinArray, charactersPerMin];
            agNumCorrectArrray = [agNumCorrectArrray, numCorrect];
            agTotalTypedArray = [agTotalTypedArray, numTotal];
            agTotalTimeArray = [agTotalTimeArray, totalTime];
       else
           disp('Skipping empty copy phrase obj!')
       end
    end

    % get the means for the aggregate results
    agDecTime = mean(agDecTimeArray);
    agCharactersPerMin = mean(agCharactersPerMinArray);
    agPercentCorrect = sum(agNumCorrectArrray)/sum(agTotalTypedArray);
    agTotalTime = mean(agTotalTimeArray);
    acc = perfMetric.acc;
    ITR = perfMetric.ITR;

    % write a csv with aggregate data
    aggregateTable = table(agDecTime, agCharactersPerMin, agPercentCorrect, agTotalTime, stimLengthSec, acc, ITR);
    writetable(aggregateTable, [saveFolder, filesep, 'SummaryTable', '.csv'])
catch me
    warning('Error saving aggregate stats! Please look at everything.mat and calculate there. Report this error:')
    disp(me.message)
end
