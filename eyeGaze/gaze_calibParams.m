% ptb idx of screen
screenNumber = 0;

% targets are equally spaced in an array of dimensions targetDim in the
% screen.  first val is number of targets horizontally
targetDim = [];

% boxCenter is the [numBox x 2] center of boxes as ratio to full screen.
% note that targetDim xor boxCenter is required to construct calibGaze
% (other should be = [])
border = .05;
boxCenter = [.5, border;...
            border, .5; ...
            (1-border), .5; ...
            .5, (1 - border)];

% number of times a trial is repeated
numTrialPerTarget = 3;

% length of time of a trial (seconds)
trialLengthSec = 3;

% length of time between trials (seconds)
interTrialLengthSec = 2;

% length ratio of box to minimal side of monitor (horz or vert)
boxLengthRat = .02;

% wav to signify start of trial (empty string to toggle off)
trialWav = 'boop.wav';

breakEveryNTrial = 10;
breakLengthSec = 3;