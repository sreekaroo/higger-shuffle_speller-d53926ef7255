% 'pupil', 'eyex' or 'none'
eyeTrack = 'none';

% toggles whether target is animated from center in calib
moveTargetFlag = false;

% scalar, percentage of time eye gaze must be sustained on target
% for it to be considered a valid trial (otherwise repeated).  Active only
% when eyeTrackColorFlag = true;
eyeTrackMinThresh = .9;

% eyeFixCircleRadius in [0, 1), 0 to turn off
eyeFixCircleRadius = 0;

% toggles coloring of eyeFixCircle (during trial)
eyeTrackColorFlag = false;

% either 'freq', 'mSeq' or 'none' (corresponds to stimSSVEP subclass)
stimMode = 'freq';

% number of LED stimuli
numStim = 6;

% frequencies to stimulate
freq = linspace(6, 36, numStim);

% needed for mSeq
stimFs = 60;
seqLength = 31;
seqIndex = 1 : numStim;
bitRate = 1;

% number of trials for each stimulus
numTrialsPerStim = 20;

% scalar, minimum amount of wait time between trials
minWaitTimeSec = 1;

% scalar logical, toggles spacebar input
spacebarRequiredFlag  = false;

% length of time of each stimulation
stimLengthSec = 5;

% image to show as training puzzle (jpg). set to empty to disable puzzle
% to add image, place a jpg somewhere on the MATLAB path (feel free to make
% a folder)
% puzzImg = 'Hawksbill_Turtle.jpg';
puzzImg = [];

% NOTE: breaks are only active in spacebarRequiredFlag = false mode
% (otherwise the user can take a break between any two trials)

% number of trials which occur before a break
trialsPerBreak = 10;

% length of break time (in sec)
breakTimeSec = 10;