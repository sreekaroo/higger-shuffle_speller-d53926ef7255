classdef calibGaze < PTBdisp
    
    properties
        % struct containing background, target and nonTarget fields (each a
        % column vector of length 4 [R, G, B, A]' from 0 - 255
        colorStruct
        
        % [4 x numBox] array, each col is typical PTB pos (see PTBdisp's
        % computePos)
        boxPos
        
        % [4 x numBox] array, each col is RGB color of the box
        boxColor
        
        % eye tracker object
        daqEyeObj
        
        % audio player object of trial noise (still audioplayer if no noise
        % passed, play() doesn't make a noise)
        trialSound
        
        keyCheckObj
    end
    
    properties
        QUIT = 1;
        PAUSE = 2;
    end
    
    methods
        function self = calibGaze(varargin)
            % super class constructor
            self = self@PTBdisp(varargin{:});
            
            grey = [150, 150, 150, 255]';
            black = [0, 0, 0, 255]';
            red = [255, 0, 0, 255]';
            green = [0, 255, 0, 255]';
            
            p = inputParser;
            p.KeepUnmatched = true;
            p.addParameter('targetDim', []);
            p.addParameter('boxCenter', []);
            p.addParameter('numTrialPerTarget', 4, @isscalar);
            p.addParameter('trialLengthSec', 5, @iscalar);
            p.addParameter('colorBackground', black);
            p.addParameter('colorNonTarget', grey);
            p.addParameter('colorPreTarget', red);
            p.addParameter('colorTarget', green);
            p.addParameter('boxLengthRat', .02, @isscalar);
            p.addParameter('daqEyeObj', []);
            p.addParameter('trialWav', '', @ischar);
            p.addParameter('keyQuit', dictKeyboard.esc);
            p.addParameter('keyPause', dictKeyboard.space);
            p.parse(varargin{:});
            
            % init keyboard event checker
            ptbKeyIdx(self.QUIT) = p.Results.keyQuit.ptbIdx;
            ptbKeyIdx(self.PAUSE) = p.Results.keyPause.ptbIdx;
            self.keyCheckObj = keyCheck(ptbKeyIdx);
            
            % store colors
            self.colorStruct.background = p.Results.colorBackground;
            self.colorStruct.target = p.Results.colorTarget;
            self.colorStruct.preTarget = p.Results.colorPreTarget;
            self.colorStruct.nonTarget = p.Results.colorNonTarget;
            self.daqEyeObj = p.Results.daqEyeObj;
            self.trialSound = makeAudioPlayer(p.Results.trialWav);
            
            % 'radius' of box in pixels
            boxRadPix = min(self.screenSizePix) * p.Results.boxLengthRat;
            
            % x and y are centers (as ratios to screen lengths) of boxes
            function c = getBoxCenter(numBoxPerAxis)
                toWall = .5 / (numBoxPerAxis * 2 - 1);
                c = linspace(toWall, 1 - toWall, numBoxPerAxis);
            end
            
            if ~isempty(p.Results.targetDim) && isempty(p.Results.boxCenter)
                x = getBoxCenter(p.Results.targetDim(1));
                y = getBoxCenter(p.Results.targetDim(2));
                [x, y] = meshgrid(x, y);
                boxCenter = [x(:), y(:)];
            elseif ~isempty(p.Results.boxCenter)
                boxCenter = p.Results.boxCenter;
            else
                error('either targetDim xor boxCenter required')
            end
            
            function pos = getBoxPos(boxCenterRat)
                pos = self.ComputePos(...
                    'posRatio', [boxCenterRat(:); boxCenterRat(:)]);
                pos = round(pos + [-1, -1, 1, 1]' * boxRadPix);
            end
            
            numBox = prod(p.Results.targetDim);
            self.boxPos = nan(4, numBox);
            for idx = 1 : size(boxCenter, 1)
                self.boxPos(:, idx) = getBoxPos(boxCenter(idx, :));
            end
        end
        
        function setBoxColor(self, varargin)
            % sets new target color (if passed)
            % Input:
            %   targetIdx = scalar, new target box
            
            p = inputParser;
            p.addParameter('targetIdx', []);
            p.addParameter('preTargetIdx', []);
            p.parse(varargin{:});
            
            % set all to non target
            numBox = size(self.boxPos, 2);
            self.boxColor = repmat(self.colorStruct.nonTarget, 1, numBox);
            
            if ~isempty(p.Results.targetIdx)
                self.boxColor(:, p.Results.targetIdx) = ...
                    self.colorStruct.target;
            end
            
            if ~isempty(p.Results.preTargetIdx)
                self.boxColor(:, p.Results.preTargetIdx) = ...
                    self.colorStruct.preTarget;
            end
        end
        
        function quitFlag = pause(self, varargin)
            
            defaultText = 'Press <space> to continue, <esc> to quit';
            
            p = inputParser;
            p.addParameter('timeOut', nan);
            p.addParameter('text', defaultText);
            p.parse(varargin{:});
            
            Screen('FillRect', self.windowPointer, ...
                self.colorStruct.background);
            
            % draws boxes, space to continue, esc to quit
            self.setBoxColor();
            self.drawBox();            
            textBoxObj = textBox('text', p.Results.text, ...
                                 'windowPointer', self.windowPointer);
            textBoxObj.Draw();
            self.Flip();
            
            quitFlag = false;
            self.keyCheckObj.resetCount();
            tic;
            while true
                keyFlag = self.keyCheckObj.keyPressed;
                if keyFlag(self.QUIT)
                    quitFlag = true;
                    break
                elseif keyFlag(self.PAUSE)
                    break
                elseif toc > p.Results.timeOut
                    break
                end                    
                pause(1/100);
            end
        end
        
        function drawBox(self)
            % draws boxes on screen in appropriate color and position
            
            % draw background
            Screen('FillRect', self.windowPointer, ...
                self.colorStruct.background);
            
            % draw boxes
            Screen('FillRect', self.windowPointer, ...
                self.boxColor, self.boxPos);
        end
        
        function trialStruct = runTrial(self, targetIdx, trialLengthSec, varargin)
            % performs a single trial
            %
            % Input:
            %   targetIdx = scalar, which box to highlight as target
            %   trialLengthSec = scalar, length of trial seconds
            % Output:
            %   trialStruct
            %       .posTarget  = [x, y] vector, center of target
            %       .posEye     = [2 x numSamples] eye gaze tracking
            
            p = inputParser;
            p.addParameter('preTrialTime', 1, @isscalar);
            p.parse(varargin{:});
            
            % pre trial
            self.setBoxColor('preTargetIdx', targetIdx);
            self.drawBox();
            self.Flip();
            
            pause(p.Results.preTrialTime);
            
            % color boxes
            self.setBoxColor('targetIdx', targetIdx);
            self.drawBox();
            self.Flip();
            
            % reset eye tracker (discards buffer)
            self.daqEyeObj.GetData();
            
            % wait
            pause(trialLengthSec);
            self.trialSound.play();
            
            % collect trialStruct data
            trialStruct.targetPos = ...
                [mean(self.boxPos([1, 3], targetIdx)) / self.screenSizePix(1), ...
                mean(self.boxPos([2, 4], targetIdx)) / self.screenSizePix(2)];
            trialStruct.targetIdx = targetIdx;
            
            [trialStruct.gazePos, ...
                trialStruct.time, ...
                trialStruct.status, ...
                trialStruct.lgazePos, ...
                trialStruct.rgazePos, ...
                trialStruct.lpos, ....
                trialStruct.rpos] = self.daqEyeObj.GetData();
        end
        
        function trialStruct = go(self, varargin)
            % performs calibration
            %
            % Input:
            %   numTrialPerTarget = scalar, num trials per target
            %   trialLengthSec = scalar, length of trial seconds
            %   interTrialLengthSec = scalar, pause time between trials
            % Output:
            %   trialStruct
            %       .posTarget  = [x, y] vector, center of target
            %       .posEye     = [2 x numSamples] eye gaze tracking
            
            p = inputParser;
            p.addParameter('numTrialPerTarget', 4, @isscalar);
            p.addParameter('trialLengthSec', 5, @isscalar);
            p.addParameter('interTrialLengthSec', 2, @isscalar);
            p.addParameter('breakEveryNTrial', nan, @isscalar);
            p.addParameter('breakLengthSec', 10, @isscalar);
            p.parse(varargin{:});
            
            % create targetIdx, a randomized vector of which target is
            % associated with each trial
            numBox = size(self.boxPos, 2);
            targetIdx = repmat(1 : numBox, 1, p.Results.numTrialPerTarget);
            targetIdx = targetIdx(randperm(numel(targetIdx)));
            
            % init trialStruct
            trialStruct = cell(length(targetIdx), 1);
            
            % pause
            quitFlag = self.pause();
            if quitFlag
                return
            end
            
            % perform trials
            idx = 1;
            while idx <= length(targetIdx)
                self.keyCheckObj.resetCount();
                
                trialStruct{idx} = self.runTrial(targetIdx(idx), ...
                    p.Results.trialLengthSec, ...
                    'preTrialTime', p.Results.interTrialLengthSec);
                
                keyFlag = self.keyCheckObj.keyPressed;
                
                if keyFlag(self.QUIT)
                    break
                elseif keyFlag(self.PAUSE)
                    quitFlag = self.pause();
                    if quitFlag
                        break
                    end      
                end
                                
                % auto break
                breakFlag = ~mod(idx, p.Results.breakEveryNTrial);
                if ~isnan(breakFlag) && breakFlag && idx ~= length(targetIdx)
                   self.pause('text', 'Break', ...
                              'timeOut', p.Results.breakLengthSec);
                end
                
                % increment trial idx
                idx = idx + 1;
            end
            
            % convert from cell to matrix (of structs).  trim trials which
            % aren't done
            trialStruct = cell2mat(trialStruct(1:length(targetIdx)));
        end
    end
    
end