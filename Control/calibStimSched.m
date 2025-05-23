classdef calibStimSched < handle
    % builds schedule of stimulation for training
    
    % ASSUME: numStim = numChan
    
    properties (SetAccess = protected)
        % [numStim x numTrials] mapping from stimuli to output channels
        % (LEDs).  Describes hwo stimuli move between LEDs during training
        chanIdx
        
        % [numTrials x 1] idx of target stim
        targetStimIdx
        
        % number of stimuli
        numStim
        
        % number of channels
        numChan
        
        % scalar, number of trials per stimulation, only populated if
        % 'numTrialsPerStim' passed in constructor
        numTrialsPerStim
        
        % scalar, number of trials per stimulation per channel, only
        % populated if 'numTrialsPerStimChan' passed in constructor
        numTrialsPerStimChan
    end
    
    properties (Dependent = true)
        targetChanIdx    % [numTrials x 1] target channel index
        
        numTrials        % number of trials
    end
    
    methods
        function self = calibStimSched(numStim, varargin)
            
            p = inputParser;
            p.addRequired('numStim',@(x)(ismember(x, 1:40)));
            p.addParameter('numTrialsPerStim', @isscalar);
            p.addParameter('numTrialsPerStimChan', nan, @isscalar);
            p.addParameter('shuffleFlag', true, @islogical);
            p.parse(numStim, varargin{:});
            
            % validate
            argPassed = @(x)(~ismember(x, p.UsingDefaults));
            if ~xor(argPassed('numTrialsPerStim'), ...
                    argPassed('numTrialsPerStimChan'))
                error('numTrialsPerStim  xor numTrialsPerStimChan required');
            end
            
            % set outputs
            self.numStim = p.Results.numStim;
            self.numChan = p.Results.numStim;   % assumption
            
            % build targetStimIdx and chanIdx
            if argPassed('numTrialsPerStim')
                self.numTrialsPerStim = p.Results.numTrialsPerStim;
                self.targetStimIdx = repmat(1:self.numStim, ...
                    [1, self.numTrialsPerStim]);
                
                self.chanIdx = repmat((1:self.numStim)', ...
                    [1, self.numTrialsPerStim * self.numStim]);
            else
                % numTrialsPerStimChan passed
                self.numTrialsPerStimChan = p.Results.numTrialsPerStimChan;
                
                self.targetStimIdx = repmat(1:self.numStim, ...
                    [1, self.numTrialsPerStimChan * self.numChan]);
                
                chanIdxTemp = repmat((1:self.numStim)', ...
                    [1, self.numTrialsPerStimChan * self.numStim]);
                
                self.chanIdx = [];
                for idx = 1 : self.numChan
                    self.chanIdx = ...
                        [self.chanIdx, circshift(chanIdxTemp, idx, 1)];
                end
            end
            
            % shuffle if need be
            if p.Results.shuffleFlag
               rndIdx = randperm(self.numTrials);
               self.chanIdx = self.chanIdx(:, rndIdx);
               self.targetStimIdx = self.targetStimIdx(:, rndIdx);
            end
            
        end
        
        function RmTrials(self, rmTrialFlag)
           % throws out a trial (see loadBlockTriggerData's trialKeptFlag
           % output) 
           % INPUT:
           %    trialKeptFlag = [numTrials x 1] logical, 1 keeps trial, 0
           %                    discards it
           
          self.chanIdx = self.chanIdx(:, ~rmTrialFlag);
          self.targetStimIdx = self.targetStimIdx(~rmTrialFlag);
          % targetChanIdx is dependant on the two above
        end
        
        function targetChanIdx = get.targetChanIdx(self)
            targetChanIdx = self.chanIdx(self.targetStimIdx);
        end
        
        function numTrials = get.numTrials(self)
           numTrials = length(self.targetStimIdx);
        end
    end
end