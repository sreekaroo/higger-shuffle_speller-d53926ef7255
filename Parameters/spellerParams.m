langModelDm = false;

% eye tracker
% toggles eye tracker data collection
eyeTrackFlag = true;

% eyeFixCircleRadius in [0, 1), 0 to turn off
eyeFixCircleRadius = 0;

% toggles coloring of eyeFixCircle (during trial)
eyeTrackColorFlag = false;

% scalar, percentage of time eye gaze must be sustained on target
% for it to be considered a valid trial (otherwise repeated).  Active only
% when eyeTrackColorFlag = true;
eyeTrackMinThresh = .9;

%% HCI
% 'animate'   - icons translate to iconBox
% 'teleport'  - icons instantly to iconBox
% 'colorCode' - icons stay in initIconBox, share same color as associated 
%               iconBox
iconStimAssocMode = 'animate';

% logical, toggles whether icons are colored identically to destination
% iconBox (overrides colorTargetFlag below)
colorCodedIconFlag = true;

% toggle bar graph (in dashboard) on or off
barGraphFlag = false;

% by default, selects max ITR of a given classifier
pickMaxITRflag = true;

%% copyPhraseTask
% copyPhraseStr = {m x 1} cell of 'context %phrase' strings (each its own
% task)
%
% example: given the context "the quick brown " the user is asked to type
% "fox"
% copyPhraseStr = 'the quick brown %fox';
% 
% alternatively, select from our library of copyPhraseStr sets in
% 'copyPhraseTasks.csv' in the parameters folder
%
% to turn on free spell mode, set copyPhraseStr = '';
copyPhraseSetIdx = 10;
copyPhraseStr = copyPhraseReadCSV(copyPhraseSetIdx);
% copyPhraseStr = 'fill in your own by replacing (and uncommenting) %this';
% copyPhraseStr = 'APPLE';

% highlights the target letter a different color than the others (helpful
% for first time users)
colorTargetFlag = false;

% controls how many icons will fit in the typed text box.  make smaller to
% increase the font size in the typed text box.  Setting this so low that
% the copy phrase task context and target won't fit will cause an error.
% 50 fits 'sally sells sea shells down by the sea %shore' but its tight!
iconBoxNumIcons = 40;

%% msg encoding
% codeType describes what method is used to partition the letters among
% checkerboards, see codingForBCI (a submodule) for further details
% codeType = 'maxInfo', 'huffman', 'huffmanFreeze', 'uniform', 'random' or 
% 'sequential'
codeType = 'maxInfo';

% minimum probability required for a decision to be reached
minDecProb = .85;

%% interface
kbInterfaceFlag = false;
msInterfaceFlag = false; 

% requires a spacebar press between each trial (else 2 sec timeout)
spacebarInterTrial = true;

%% Quit Thresholds
% a copy phrase task is considered failed if more than maxCurrentWrong
% letters are selected.  Note that an incorrect deleted character does not
% count towards this total
maxCurrentWrong = 5;

% a copy phrase task is also considered failed if more than maxSequences
% sequences occurs
maxSequences = 10;

% min and max number of trials in a decision sequences.  setting min to be
% greater than or equal to 1 will disable auto type.  if a decision hasn't
% been reached @ max numTrials, then task is considered failed (set to nan
% for infinite trials per decision)
minMaxNumTrials = [1, 20];