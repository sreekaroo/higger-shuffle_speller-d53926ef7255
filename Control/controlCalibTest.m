clearvars; clc; sca;
 
%% parameters 
minWaitTimeSec = 3;
spacebarRequiredFlag = false;

screenNumber = 1;

% Hawksbill_Turtle.jpg or dog.jpg
puzzImg = 'Hawksbill_Turtle.jpg';
% puzzImg = [];

trialsPerBreak = 10;
breakTimeSec = 4;

iconBoxesPerRowCol = [3;2];
iconBoxesBordRatio = .02;
dashWidthRatio = .3;
posRatioDash = [1-dashWidthRatio, 0, 1, 1];
posRatioIconStimAssoc = [0, 0, 1-dashWidthRatio, 1];

%% calibStimSchedObj
numTrialsPerStim = 3;
calibStimSchedObj = calibStimSched(prod(iconBoxesPerRowCol),...
    'numTrialsPerStim', numTrialsPerStim);

%% init
iconStimAssocObj = iconStimAssoc(...
    'screenNumber', screenNumber, ...
    'posRatio', posRatioIconStimAssoc, ...
    'iconBoxesPerRowCol', iconBoxesPerRowCol, ...
    'iconBoxesBordRatio', iconBoxesBordRatio);

dashboardObj = dashboard(...
    'windowPointer', iconStimAssocObj.windowPointer, ...
    'posRatio', posRatioDash);    

controlCalibObj = controlCalib(...
    'windowPointer', iconStimAssocObj.windowPointer, ...
    'iconStimAssocObj', iconStimAssocObj, ...
    'dashboardObj', dashboardObj, ...
    'minWaitTimeSec', minWaitTimeSec,...
    'spacebarRequiredFlag', spacebarRequiredFlag, ...
    'puzzImg', puzzImg, ...
    'trialsPerBreak', trialsPerBreak, ...
    'breakTimeSec', breakTimeSec);

%% test
ShowCursor;
controlCalibObj.Tutorial;
controlCalibObj.Run(calibStimSchedObj);

sca;