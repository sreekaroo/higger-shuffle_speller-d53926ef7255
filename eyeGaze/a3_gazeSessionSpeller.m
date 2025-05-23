%% load parameters
clear; clc; jheapcl;

%% load parameters
timeGaze = 1;

presentationParams;
spellerParams;

%% select classifier
[file, path, ~] = uigetfile();
load([path, file]);

% set save path
savepath = [path, 'session', datestr(now,'mmm-dd-yyyy_HH-MM_SS')];
mkdir(savepath);

% ensure targetDim is consistent from training to online
iconBoxesPerRowCol = targetDim;

%% param processing
gazeClassifierObj.time = timeGaze;
allDictAlpha = dictAlpha.Convert(1:28);
iconPaths = {allDictAlpha.image};

dashPosRatio = [iconStimAssocWidth, 0, 1, 1];
iconStimAssocPosRatio = [0, 0, iconStimAssocWidth, 1];

%% init eyeTracker, validate its running
daqEyeObj = DaqTobiiEyeX();
daqEyeObj.ValidateAnyData();

%% build appropriate code object
switch codeType
    case 'maxInfo'
        codeObj = MaxInfoCode('probYgivenX', confMatrix,...
            'calculationMethod','hillClimb');
        naiveDecFlag = false;
    case {'huffman', 'huffmanFreeze'}
        codeObj = HuffmanCode('probYgivenX', confMatrix,...
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
        codeObj = SequentialCode('probYgivenX', confMatrix,...
            'verboseFlag',false);
        naiveDecFlag = true;
    case 'uniform'
        codeObj  = UniformCode('probYgivenX', confMatrix);
        naiveDecFlag = true;
    case 'random'
        codeObj  = RandomCode('probYgivenX', confMatrix);
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
    'iconBoxesPosRatio', iconBoxesPosRatio,...
    'initIconBoxPosRatio', initIconBoxPosRatio, ...
    'posRatio', iconStimAssocPosRatio,...
    'iconBoxesBordRatio', iconBoxesBordRatio, ...
    'mode', iconStimAssocMode, ...
    'colorCodedIconFlag', colorCodedIconFlag, ...
    'iconBoxesColor', iconBoxesColor);

% add targets to classifierObj
getCenter = @(x)(mean(reshape(x, 2, 2), 2));
numTarget = prod(iconBoxesPerRowCol);
for tIdx = 1 : numTarget
    posRatio = iconStimAssocObj.iconBoxes(tIdx).posRatio;
    gazeClassifierObj.targetPos(:, tIdx) = getCenter(posRatio);
end

% init language model
if langModelDm
    languageModelObj = languageModelDM();
else
    languageModelObj = languageModel();
end

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
    'classifierObj', gazeClassifierObj, ...
    'daqEyeObj', daqEyeObj, ...
    'mode', 'gaze', ...
    'eyeTrackFlag', true, ...
    'activeRectColor', activeRectColor);

% start eye tracking
daqEyeObj.OpenDevice();
daqEyeObj.StartAcquisition();

%% run experiment
controlShuffleObj.RunCopyPhrase(copyPhraseObj, ...
    'spacebarInterTrial', spacebarInterTrial);

%% cleanup
sca;
delete(languageModelObj);

%% save results
savefile = [savepath, '\sessionData.mat'];
save(savefile,...
    'copyPhraseObj',...
    'controlShuffleObj',...
    'codeObj',...
    'daqEyeObj', ...
    'gazeClassifierObj',...
    'timeGaze',...
    'confMatrix');

% save all data to mat file, just in case.
savefile = [savepath, '\everything.mat'];
save(savefile);

% % Try saving the session information from the Copy Phrase Object
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
           [averageDecTime, charactersPerMin, numCorrect, numTotal, totalTime] = copyPhraseObj(cpIdx).export(savepath);

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

    % write a csv with aggregate data
    aggregateTable = table(agDecTime, agCharactersPerMin, agPercentCorrect, agTotalTime, timeGaze);
    writetable(aggregateTable, [savepath, filesep, 'SummaryTable', '.csv'])
catch me
    warning('Error saving aggregate stats! Please look at everything.mat and calculate there. Report this error:')
    disp(me.message)
end
