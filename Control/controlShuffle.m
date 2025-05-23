classdef controlShuffle < controlSpell
    % runs shuffle freeSpell and copyPhrase tasks
    
    properties
        % 1x1, see LEDstimulation from led-stimulus-dds submodule
        LEDstimulationObj
        
        % daqManager object
        daqManagerObj
        
        % either 'eeg' or 'gaze'
        mode
        
        % RGB color of rects during data collection (or nan to deactivate)
        activeRectColor
    end
    
    methods
        function self = controlShuffle(varargin)
            self = self@controlSpell(varargin{:});
            
            % constructor - initialize properties, load instruction screen
            p = inputParser;
            p.KeepUnmatched = true;
            p.addParameter('LEDstimulationObj', nan);
            p.addParameter('daqManagerObj', nan, @(x)(isa(x, 'DAQbase')));
            p.addParameter('mode', 'eeg');
            p.addParameter('activeRectColor', nan);
            p.parse(varargin{:});
            
            argPassed = @(x)(~ismember(x, p.UsingDefaults));
            
            % load LEDstimulationObj
            if ~argPassed('LEDstimulationObj')
                self.LEDstimulationObj = LEDstimulation;
            else
                self.LEDstimulationObj = p.Results.LEDstimulationObj;
            end
            
            self.daqManagerObj = p.Results.daqManagerObj;
            self.activeRectColor = p.Results.activeRectColor;
            self.mode = p.Results.mode;
        end
        
        function StimulateTrial(self, varargin)
            % moves src icons (and clears eye track buffer) for trial
            p = inputParser;
            p.KeepUnmatched = true;
            p.addParameter('code', nan);
            p.parse(varargin{:});
            
            argPassed = @(x)(~ismember(x, p.UsingDefaults));
            
            assert(argPassed('code'), 'code required');
            
            self.iconStimAssocObj.Associate(p.Results.code);
        end
        
        function [probX, quitLogical, trialDataStruct] = GetProbX(self)
            
            initBoxColor = {};
            if ~isnan(self.activeRectColor)
                iconBoxes = self.iconStimAssocObj.iconBoxes;
                numBox = length(iconBoxes);
                for boxIdx = 1 : numBox
                    initBoxColor{end + 1} = iconBoxes(boxIdx).borderStruct.color;
                    iconBoxes(boxIdx).borderStruct.color = self.activeRectColor;
                end
                self.iconStimAssocObj.Draw();
                self.iconStimAssocObj.Flip();
            end
            
            switch self.mode
                case 'eeg'
                    [probX, quitLogical, trialDataStruct] = ...
                        self.GetProbXEEG();
                case 'gaze'
                    [probX, quitLogical, trialDataStruct] = ...
                        self.GetProbXgaze();
                otherwise
                    error('invalid mode given');
            end
            
            if ~isnan(self.activeRectColor)
                for boxIdx = 1 : numBox
                    iconBoxes(boxIdx).borderStruct.color = initBoxColor{boxIdx};
                end
                
                self.iconStimAssocObj.Draw();
                self.iconStimAssocObj.Flip();
            end
        end
        
        function [probX, quitLogical, trialDataStruct] = GetProbXgaze(self)
            % stimulates user, gets a trial's worth of data and classifies
            % it to produce probX
            
            self.daqEyeObj.GetData();
            
            pause(self.classifierObj.time);
            
            [trialDataStruct.gazePos, ...
                trialDataStruct.time, ...
                trialDataStruct.status, ...
                trialDataStruct.lgazePos, ...
                trialDataStruct.rgazePos, ...
                trialDataStruct.lpos, ....
                trialDataStruct.rpos] = self.daqEyeObj.GetData();
            
            quitLogical = false;
            
            estimateStruct = self.classifierObj.Classify(trialDataStruct);
            probX = estimateStruct.aPosteriori;
        end
        
        function [probX, quitLogical, trialDataStruct] = GetProbXEEG(self)
            % stimulates user, gets a trial's worth of data and classifies
            % it to produce probX
            
            trialDataStruct = struct;
            
            % clear eye track (NOTE: not explicitly time aligned with EEG)
            if self.eyeTrackFlag
                self.daqEyeObj.ClearBuffer;
            end
            
            % color eye tracker
            if self.eyeTrackColorFlag
                timerEyeColorObj = self.colorEyeTrackTarget(...
                    'time', self.LEDstimulationObj.stimLengthSec);
            end
            
            % stimualte user (non blocking)
            timerStimObj = self.LEDstimulationObj.Go('blockFlag', false);
            
            % give window of time where esc can be pressed to quit
            waitMsg = 'Press <esc> to quit';
            quitLogical = self.DrawFlipPause(...
                'maxCheckTime', self.LEDstimulationObj.stimLengthSec, ...
                'waitMessage', waitMsg, ...
                'quitFlag', true);
            
            if self.eyeTrackFlag
                [pos, timeStamp, eyePresence] = self.daqEyeObj.GetData;
                trialDataStruct.eyeTrack.pos = pos;
                trialDataStruct.eyeTrack.timeStamp = timeStamp;
                trialDataStruct.eyeTrack.eyePresence = eyePresence;
            end
            
            % clear textBox
            self.textBoxFrmtObj.Fill('color', self.backgroundColor);
            self.textBoxFrmtObj.Flip;
            
            % stop coloring eye tracker
            if self.eyeTrackColorFlag
                trialDataStruct.eyeTargetSuccess = self.eyeTargetSuccess;
                delete(timerEyeColorObj);
                
                if mean(self.eyeTargetSuccess) < self.eyeTrackMinThresh
                    % user has not had their eyes on the target for
                    % long enough to count as a trial
                    clearDaq;
                    probX = nan;
                    return
                end
            end
            
            if quitLogical
                % stop LEDstim
                delete(timerStimObj);
                
                clearDaq;
                
                % return with empty probX
                probX = [];
                return
            end
            
            % get trial
            eegData = self.daqManagerObj.GetTrial;
            delete(timerStimObj);
            trialDataStruct.eeg = eegData;
            
            % this transpose is a kludge, see issue 15 of
            % modular-classifiers
            estimateStruct = self.classifierObj.Classify(eegData');
            probX = estimateStruct.aPosteriori;
            
            function clearDaq
                % clear daq buffer (and group delayed buffer)
                while true
                    [~, triggerSignal] = self.daqManagerObj.GetData;
                    if ~isempty(triggerSignal) && ...
                            not(triggerSignal(end))
                        break
                    end
                    pause(.01);
                end
            end
        end
        
        function iconBoxPosRatio = GetAndPrepMouseInput(self)
            % returns the posRatio of the iconBoxes in iconstimASsocObj and
            % write msg to user to click area with target letter
            
            % get iconBoxPosRatio for all icon boxes
            iconBoxes = self.iconStimAssocObj.iconBoxes;
            numIconBoxes = length(iconBoxes);
            for iconBoxIdx = numIconBoxes : - 1 : 1
                iconBoxPosRatio(:, iconBoxIdx) = ...
                    iconBoxes(iconBoxIdx).posRatio;
            end
            
            % write msg to user
            msg = ['Please click area which \n', ...
                'contains your desired letter'];
            
            self.textBoxFrmtObj.Fill('color', self.backgroundColor);
            self.textBoxFrmtObj.text = msg;
            self.textBoxFrmtObj.Draw;
            self.textBoxFrmtObj.Flip;
        end
        
        function DrawProbXFeedback(self, probX)
            % shades iconBoxes according to probX
            self.iconStimAssocObj.ColorIcons;
            self.iconStimAssocObj.Draw('iconBoxShade', probX);
            self.Flip;
        end
    end
    
    methods (Access = protected)
        function [kbMsg, dictKeys] = getKeyQueryVar(self, varargin)
            % OUTPUT:
            %   kbMsg = string, msg to display when keyboard querying
            %   dictKeys = [numX x 1] dictKey, keys to press per user input
            
            kbMsg = ['Which box is your letter inside?\n', ...
                '1 is top left, idx across then down\n'];
            
            numX = length(self.iconStimAssocObj.iconBoxes);
            
            dictKeys = dictKeyboard.Convert(1:numX);
            
        end
    end
end