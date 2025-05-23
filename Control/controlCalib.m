classdef controlCalib < presMan
    properties        
        daqEEGobj
        
        % 1x1, see stimSSVEP from led-stimulus-dds submodule
        stimSSVEPObj
        
        % 1x1, see iconStimAssoc
        iconStimAssocObj
        
        % 1x1, see dashboard
        dashboardObj
        
        % 1x1, see LEDstimulation from led-stimulus-dds submodule
        LEDstimulationObj
        
        % scalar, minimum amount of wait time between trials 
        minWaitTimeSec
        
        % scalar logical, toggles spacebar input
        spacebarRequiredFlag        
        
        % number of trials which occur before a break
        trialsPerBreak
        
        % length of break time (in sec)
        breakTimeSec
        
        % toggles movement of target during trial
        moveTargetFlag
    end
    
    properties (Hidden = true)
        % str of image for puzzle or nan (if not in puzzle mode)
        puzzImg
    end
    
    methods
        function self = controlCalib(varargin)
            % constructor
            
            self = self@presMan(varargin{:});
                                 
            p = inputParser;
            p.KeepUnmatched = true;
            p.addParameter('daqEEGobj', []);
            p.addParameter('stimSSVEPObj', nan);
            p.addParameter('iconStimAssocObj', nan);
            p.addParameter('dashboardObj', nan);
            p.addParameter('LEDstimulationObj', nan);
            p.addParameter('minWaitTimeSec', 2, @isscalar);
            p.addParameter('spacebarRequiredFlag', true, @islogical);
            p.addParameter('puzzImg', nan);
            p.addParameter('trialsPerBreak', 15, @isscalar);
            p.addParameter('breakTimeSec', 25, @isscalar);
            p.addParameter('moveTargetFlag', false, @islogical);
            p.parse(varargin{:});
            
            argPassed = @(x)(~ismember(x, p.UsingDefaults));
            
            assert(argPassed('iconStimAssocObj'), 'iconStimAssocObj required');
            assert(argPassed('dashboardObj'), 'dashboardObj required');
            
            % set inputs
            self.daqEEGobj = p.Results.daqEEGobj;
            self.iconStimAssocObj = p.Results.iconStimAssocObj;
            self.dashboardObj = p.Results.dashboardObj;
            self.minWaitTimeSec = p.Results.minWaitTimeSec;
            self.spacebarRequiredFlag = p.Results.spacebarRequiredFlag;
            self.stimSSVEPObj = p.Results.stimSSVEPObj;
            self.puzzImg = p.Results.puzzImg;
            self.trialsPerBreak = p.Results.trialsPerBreak;
            self.breakTimeSec = p.Results.breakTimeSec;
            self.moveTargetFlag = p.Results.moveTargetFlag;
            
            % set LEDstimulationObj
            if ~argPassed('LEDstimulationObj')
               warning('LEDstimulationObj not passed, will init dummy');
               self.LEDstimulationObj = LEDstimulation('stimLengthSec', .5);
            else
                self.LEDstimulationObj = p.Results.LEDstimulationObj;
            end
            
            if self.moveTargetFlag && ~isempty(self.puzzImg)
               warning('target movement and puzzle, this will be hectic!') 
            end
                             
            % init textBoxFrmtObj
            self.textBoxFrmtObj = textBoxFormatted(...
                'windowPointer', self.windowPointer, ...
                'pos', self.dashboardObj.textBoxObj.pos, ...
                'horzVertText', [0, 0], ...
                'color', self.dashboardObj.textBoxObj.color, ...
                'textSize', self.dashboardObj.textBoxObj.textSize, ...
                'font', self.dashboardObj.textBoxObj.font);
            self.textBoxFrmtObj.styleStruct = ...
                self.dashboardObj.textBoxObj.styleStruct;
            
            self.iconStimAssocObj.mode = 'teleport';
        end
        
        function DrawRect(self, rectIdx)
           % draws a rectangle around the rectangle of the iconBox in
           % iconStimASsocObj
           
           iconBoxObj = self.iconStimAssocObj.iconBoxes(rectIdx);
           
           oldFlag = iconBoxObj.borderStruct.flag;
           iconBoxObj.borderStruct.flag = true;
           
           self.iconStimAssocObj.Fill(self.backgroundColor);
           iconBoxObj.DrawBorder;
           
           iconBoxObj.borderStruct.flag = oldFlag;
        end
        
        function [eyeTrackSuccess, dataStruct] = Run(self, calibStimSchedObj)
            %  runs training stimulation (including triggeyeTrackFlagers) and indicates
            %  targets to user
            % 
            %  OUTPUT:
            %   eyeTracks = [
            
            % fill screen with black
            self.Fill;
            self.Flip;
            
            function bbPosRatio = pos2bbPosRatio(self, pos, bbPosRatio)
               % converts a position to a posRatio within a bounding box 
               ssPix = self.screenSizePix(:);
               bbPosRatio = bbPosRatio(:);
               bbLeftTopPix = bbPosRatio(1:2) .* ssPix;
               bbWidthHeightPix = ...
                   (bbPosRatio(3:4) - bbPosRatio(1:2)) .* ssPix;
               bbPos = pos(:) - [bbLeftTopPix; bbLeftTopPix];
               bbPosRatio = bbPos ./ [bbWidthHeightPix; bbWidthHeightPix];
            end
            
            % init calibPuzz if needed
            if ischar(self.puzzImg) 
                numFragPiles = length(self.iconStimAssocObj.iconBoxes);
                for fragPileIdx = numFragPiles : -1 : 1
                    fragPilePosRatio(fragPileIdx, :) = pos2bbPosRatio(self, ...
                        self.iconStimAssocObj.iconBoxes(fragPileIdx).pos, ...
                        self.iconStimAssocObj.posRatio);
                end
                
                SCREEN2IMAGERATIO = .6;
                
                fragPileMinFrag = histc(calibStimSchedObj.targetStimIdx, 1:numFragPiles);
                
                puzzFlag = true;
                calibPuzzObj = calibPuzz(self.puzzImg, ...
                    fragPilePosRatio, ...
                    fragPileMinFrag, ...
                    'windowPointer', self.iconStimAssocObj.windowPointer, ...
                    'screen2ImageRatio', SCREEN2IMAGERATIO, ...
                    'posRatio', self.iconStimAssocObj.posRatio);
            else
                puzzFlag = false;
            end
            
            % start eye track acq (if needed).  init eyeTrackStruct
            if self.eyeTrackFlag
                self.daqEyeObj.StartAcquisition;
            end
            
            dataStruct(calibStimSchedObj.numTrials).eeg = [];
            
            trialIdx = 1;
            eyeTrackSuccess = [];
            while trialIdx <= calibStimSchedObj.numTrials
                % show user target checkerboard
                targetChanIdx = calibStimSchedObj.targetChanIdx(trialIdx);
                self.iconStimAssocObj.Fill(self.backgroundColor);
                self.DrawRect(targetChanIdx);
                
                if puzzFlag
                    calibPuzzObj.Draw;
                    calibPuzzObj.Flip;
                end
                
                self.otherPTBdispObj.Draw;
                 
                % show user trial count / get input if needed
                trialNofM = ['Trial ', num2str(trialIdx), ' of ', ...
                    num2str(calibStimSchedObj.numTrials), '\n'];
                
                if ~self.spacebarRequiredFlag
                    while true
                        if trialIdx == 1
                            % require spacebar press before 1st trial
                            maxCheckTime = inf;
                            waitMessage = [trialNofM, '\n Press <space> to continue'];
                        else
                            % timeout, if spacebar press then pause
                            maxCheckTime = self.minWaitTimeSec;
                            waitMessage = [trialNofM, 'Press <space> to pause'];
                        end
                        
                        [quitLogical, keyPressed] = self.DrawFlipPause(...
                            'quitFlag', true, ...
                            'userInput', dictKeyboard.space, ...
                            'addTextFlag', false, ...
                            'waitMessage', waitMessage, ...
                            'maxCheckTime' , maxCheckTime);
                        
                        % continue with trial
                        if isempty(keyPressed) || trialIdx == 1
                            break
                        end
                        
                        % pause until user presses space
                        self.textBoxFrmtObj.text = 'Press <space> to resume';
                        self.DrawFlipPause('userInput', dictKeyboard.space);
                    end
                else
                    % require spacebar press before each trial
                    self.textBoxFrmtObj.text = trialNofM;
                    [quitLogical, ~] = self.DrawFlipPause(...
                        'quitFlag', true, ...
                        'addTextFlag', true, ...
                        'pauseTime' , self.minWaitTimeSec);
                end
                
                if quitLogical
                    break
                end
                
                self.textBoxFrmtObj.Fill(self.backgroundColor);
                self.textBoxFrmtObj.Flip;
                
                if self.LEDstimulationObj.stimDevicePresent
                    % load LEDstimulation if different than last
                    chanIdx = calibStimSchedObj.chanIdx(:, trialIdx);
                    if ~isequal(self.LEDstimulationObj.stimStruct, ...
                            self.stimSSVEPObj.stimStruct(chanIdx))
                        
                        self.LEDstimulationObj.ConfigureStimulusDDS(...
                            self.stimSSVEPObj.stimStruct(chanIdx));
                    end
                end
                                
                % clear eye track (NOTE: not explicitly time aligned with EEG)
                if self.eyeTrackFlag
                    self.daqEyeObj.ClearBuffer;
                end
                if ~isempty(self.daqEEGobj)
                    self.daqEEGobj.GetData();
                end
                
                % color eye tracker
                if self.eyeTrackColorFlag
                    timerObj = self.colorEyeTrackTarget(...
                        'time', self.LEDstimulationObj.stimLengthSec);
                end
                
                % stimulate
                tic;
                self.LEDstimulationObj.Go('blockFlag', false);
                
                % move target if needed
                if self.moveTargetFlag
                   self.iconStimAssocObj.animateIconBox(targetChanIdx, ...
                        self.LEDstimulationObj.stimLengthSec)
                end
                
                
                % ensure trial has finished
                while toc < self.LEDstimulationObj.stimLengthSec
                    pause(.01)
                end
                % stop coloring eye tracker
                if self.eyeTrackColorFlag
                    dataStruct(trialIdx).eyeTargetSuccess = ...
                        self.eyeTargetSuccess;
                    stop(timerObj);
                    
                    if mean(self.eyeTargetSuccess) < self.eyeTrackMinThresh
                        % user has not had their eyes on the target for
                        % long enough to count as a trial
                        self.DrawFlipPause(...
                            'waitMessage', ['Please try again\n', ...
                            'Remember to focus your gaze on the circle'], ...
                            'maxCheckTime' , 2);
                        eyeTrackSuccess = [eyeTrackSuccess, 0]; %#ok<AGROW>
                        continue
                    end
                end
                eyeTrackSuccess = [eyeTrackSuccess, trialIdx]; %#ok<AGROW>
                
                % store eye track
                if self.eyeTrackFlag
                    switch class(self.daqEyeObj)
                        case 'DaqEyeXareaProp'
                            [pos, timeStamp, eyePresence] = self.daqEyeObj.GetData;
                            dataStruct(trialIdx).pos = pos;
                            dataStruct(trialIdx).timeStamp = timeStamp;
                            dataStruct(trialIdx).eyePresence = eyePresence;
                        case 'DaqPupil'
                            gazeStruct = self.daqEyeObj.GetData();
                            for f = fieldnames(gazeStruct)'
                                dataStruct(trialIdx).(f{1}) = ...
                                    gazeStruct.(f{1});
                            end
                        otherwise
                            error('daqEye not recognized')
                    end
                end
                
                if ~isempty(self.daqEEGobj)
                    dataStruct(trialIdx).eeg = self.daqEEGobj.GetData();
                end
                
                if puzzFlag
                   calibPuzzObj.Animate(targetChanIdx);
                end
                
                % take a break if no spacebarRequired
                if ~self.spacebarRequiredFlag && ...
                        ~mod(trialIdx, self.trialsPerBreak) && ...
                        trialIdx ~= calibStimSchedObj.numTrials
                    self.textBoxFrmtObj.text = ...
                        'Please take a few moments to rest\n';
                    
                    [quitLogical, ~] = self.DrawFlipPause(...
                        'maxCheckTime', 0, ...
                        'quitFlag', true, ...
                        'pauseTime' , self.breakTimeSec, ...
                        'addTextFlag', true);
                end    
                trialIdx = trialIdx + 1;
            end
            
            if puzzFlag && ~quitLogical
               calibPuzzObj.AnimateRest; 
            end
            
            if self.eyeTrackFlag
                self.daqEyeObj.StopAcquisition;
            end
            
            % display exit msg
            if quitLogical
                exitMsg = 'Training Status: Quit\n\n';
            else
                exitMsg = 'Training Status: Complete\n\n';
            end
            
            self.textBoxFrmtObj.Fill('color', self.backgroundColor);
            self.textBoxFrmtObj.text = exitMsg;
            self.textBoxFrmtObj.Draw;
            self.textBoxFrmtObj.Flip;
            pause(2);
        end
        
        function Tutorial(self, varargin)
            
            p = inputParser;
            p.addParameter('numTrials', nan);
            p.addParameter('trialLengthSec', 5);
            p.addParameter('keyboardFlag', true, @islogical);
            p.addParameter('numPracticeTrials', 5);
            p.parse(varargin{:});
            argPassed = @(x)(~ismember(x, p.UsingDefaults));
            
            numX = length(self.iconStimAssocObj.iconBoxes);
            
            % load LEDstimulationObj with first stim
            if isfield(self.stimSSVEPObj, 'stimStruct')
                self.LEDstimulationObj.ConfigureStimulusDDS(...
                    self.stimSSVEPObj.stimStruct);
            end
            
            pauseStr = '\n\nPress <space> to continue';
            addPauseStr = @(x)([x, pauseStr]);
            
            % intro screen
            self.Fill;
            self.Flip;
            waitMsg = ['Calibration Tutorial:\n', ...
                'Press <space> to begin\n', ...
                'Press <esc> to skip'];
            [continueLogical, ~] = self.DrawFlipPause(...
                'waitMessage', waitMsg, ...
                'quitFlag', true);
            if continueLogical
                self.textBoxFrmtObj.text = '';
                return
            end
            
            % instruction screen
            waitMsg = ['During calibration, the system will learn\n', ...
                'how your brain responds to the blinking\n', ...
                'lights. This will help it make correct\n', ...
                'guesses about which letters you want.'];
            self.DrawFlipPause('waitMessage', addPauseStr(waitMsg));
                        
            % introduce fix cross
            self.DrawRect(1);
            waitMsg = ['Focus your attention on the blinking\n', ...
                'light closest to the rectangle.\n', ...
                'Please continue focusing until the light\n', ...
                'stops blinking.'];
            self.DrawFlipPause('waitMessage', addPauseStr(waitMsg));
            self.textBoxFrmtObj.Fill(self.backgroundColor);
            self.textBoxFrmtObj.Flip;
            self.LEDstimulationObj.Go();
            
            % tell user how many long it will take
            if argPassed('numTrials') && argPassed('trialLengthSec')
                totalTimeMin = ceil(...
                    p.Results.numTrials * p.Results.trialLengthSec / 60);
                waitMsg = ['You will repeat this ', num2str(p.Results.numTrials), ...
                    ' times.  The entire\n', ...
                    'calibration takes about ', num2str(totalTimeMin), ' minutes.'];
            else
                waitMsg = 'You will repeat this multiple times';
            end
            self.DrawFlipPause('waitMessage', addPauseStr(waitMsg));
            
            % tell user they will be able to break using keyboard
            if p.Results.keyboardFlag
               waitMsg = ['You may take a break at any time.  Press\n', ...
                   'space when you are ready to start again.'];
            end
            self.DrawFlipPause('waitMessage', addPauseStr(waitMsg));
            
            % practice
            waitMsg = 'Lets practice now.  Are you ready?';
            self.DrawFlipPause('waitMessage', addPauseStr(waitMsg));
            
            while true
                waitMsg = @(x)(['Tutorial Trial ', num2str(x), ' of ', ...
                    num2str(p.Results.numPracticeTrials)]);
                
                for trialIdx = 1 : p.Results.numPracticeTrials
                    self.DrawRect(randi(numX));
                    quitLogical = self.DrawFlipPause(...
                        'waitMessage', addPauseStr(waitMsg(trialIdx)), ...
                        'quitFlag', true);
                    if quitLogical
                        break
                    end
                    self.textBoxFrmtObj.Fill(self.backgroundColor);
                    self.textBoxFrmtObj.Flip;
                    self.LEDstimulationObj.Go();
                end
                
                waitMsg = ['Tutorial Finished:\n', ...
                    'Press <esc> for more trials\n', ...
                    'Press <space> to continue'];
                [continueLogical, ~] = self.DrawFlipPause(...
                    'waitMessage', waitMsg, ...
                    'quitFlag', true);
                if ~continueLogical
                    break;
                end
            end           
        end
    end
end

