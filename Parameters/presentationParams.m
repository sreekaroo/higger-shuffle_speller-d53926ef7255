%% ============================== Screen ==================================
% the PTB screen idx.  For single monitor setups, 0 is the only valid
% option.  For dual monitor setups 0 is BOTH screens, and 1 and 2 are the
% "primary" and "secondary" screens, determined by the operating system
screenNumber = 0;

%%  =============================== Timing ================================
% all times in seconds

% scalar, time it takes to animate bar graph
timeBarAnim = .3;

% scalar, times it takes before letter/LED associations.  In particular,
% timePreAssocFirst is how long it takes for the first trial in a sequence,
% timePreAssoc is the time it takes for all other trials
timePreAssocFirst = 5;
timePreAssoc = 2;

% scalar, time it takes for letters to move in animation mode, ignored in
% teleport or colorCode modes
timeAnim = 1;

% scalar, time that iconBoxes are shaded (according to classifier
% confidence in their selection, more opaque -> more confident) to give
% user feedback on their trial
timePostAssoc = .3;

%% ================================ Sound =================================
% sound played at end of each trial, nan to turn off
% 'tic.wav', 'pop.wav', 'toc.wav', 'boop.wav' or nan
soundTrialWav = 'boop.wav';

% toggles whether letter names are spoken after selection
soundDecFlag = true;

% toggles whether letter names are spoken before selection (next target)
soundDecNextFlag = false;

%%  ============================== Aesthetic ==============================

% color of all rects during trial data capture (or nan to deactivate)
activeRectColor = [255, 255, 255, 255];

iconBoxesPosRatio = [.2, 0, .8, .25; ...
                     0, .2, .25, .8; ...
                     .75, .2, 1, .8; ...
                      .2, .75,  .8, 1]';                     

% layout of the iconBoxes (areas which hold letters).  each column is its
% own iconBox (NOTE: must have same num col as numStim!).  format is
% typical PTB: [x1; y1; x2; y2] where (x1, y1) is top left and (x2, y2) is
% bottom right.  All num are in ratios where (0,0) is top left of monitor
% and (1,1) is the bottom right corner of the letter movement area (it
% doesn't include the dashboard).
% distLarge = .6;
% distShort = .25;
% spaceLarge = (1 - distLarge) / 2;  
% spaceShort  = (1 - distShort) / 2;

% iconBoxesPosRatio = [...
%      spaceLarge, 0, 1 - spaceLarge, distShort; ...
%     0, spaceLarge, distShort, 1 - spaceLarge; ...
%      1 - distShort, spaceLarge, 1, 1 - spaceLarge; ...
%     spaceLarge, 1 - distShort, 1 - spaceLarge, 1]';

% only valid if iconBoxesPosRatio = empty or nan
iconBoxesPerRowCol = [5, 2];

% describe area which the letters are contianed in at the start of each
% sequence, same format as above
initIconBoxPosRatio = [.1, .33, .9, .67]';

% scalar, width (ratio) of iconBox border to screenSize
iconBoxesBordRatio = .02;

% ratio of screen width of iconAssoc area (on the left)
% making this smaller will increase the width of the dashboard area on the
% right (bar graph / typed text / user messages)
iconStimAssocWidth = .7;

% scalar, size of text (in upper right hand corner) which gives user
% instructions.  Setting this too high will draw text outside of the
% window.
textBoxTextSize = 20;

% specifies colors of iconBoxes in iconStimAssoc
iconBoxesColor = ...
    [255, 255, 0, 255; ...
     255, 64, 0, 255; ...
     192, 128, 255, 255; ...
     192, 128, 255, 255; ...
     192, 128, 255, 255; ...
     0, 255, 255, 255]';