classdef gazeClassifier < normalKDEbuilder & MAPclassifier
    % we use `error' to describe the x, y vector from the average gaze
    % position (over time) to a target center
    properties
        % [2 x numTarget] x, y position of target positions
        targetPos
        
        % {numTarget x 1} distribution of error per target
        distD
        
        % int, number of observations per trial (roughly) ... used for
        % rand()
        trialLength
    end
    
    properties (Hidden=true)
       time
    end
    
    methods
        function self = gazeClassifier(varargin)
            self = self@normalKDEbuilder(varargin{:});
        end
        
        function Learn(self, trialStruct)
            % trains self.distD
            
            % init self.targetPos
            targetIdxAll = [trialStruct(:).targetIdx];
            numTarget = size(unique(targetIdxAll), 2);
            
            self.targetPos = nan(2, numTarget);
            self.distD = cell(numTarget);
            for targetIdx = 1 : numTarget
                % save targetPos
                idx = find(targetIdx == targetIdxAll, 1);
                self.targetPos(:, targetIdx) = trialStruct(idx).targetPos;
                
                % build d (2 x numSamples) for all relevant trials
                % ... seriously?  lame MATLAB ...
                trialStructTarget = trialStruct(targetIdx == targetIdxAll);
                gazePos = {trialStructTarget(:).gazePos};
                gazePos = vertcat(gazePos{:})';
                gazePos(:, logical(sum(isnan(gazePos)))) = [];
                
                % build self.distD
                self.distD{targetIdx} = self.BuildKDE(gazePos);
            end
            
            self.trialLength = round(size(gazePos, 2) / length(trialStructTarget));
        end
        
        function [estimateStruct, d] = Classify(self, trialStruct)
            % INPUT
            %   trialStruct     = struct containing
            %       .gazePos    = [numSample x 2] x, y pos of gaze
            %
            % OUTPUT
            %   estimateStruct = vector of structs
            %       .classIdx  = scalar, idx of class estimate
            %       .likelihood = [numClasses x 1]
            %       .aPosteriori = [numClasses x 1]
            %
            %   d = [numTrials x 2 x numTarget] mean distances to target
            
            gazePos = trialStruct.gazePos;           
            gazePos(logical(sum(isnan(gazePos))), :) = [];
            
            numTarget = size(self.targetPos, 2);
            ll = nan(numTarget, 1);
            for targetIdx = 1 : numTarget
                ll(targetIdx) = -nanmean(nanmean(self.distD{targetIdx}.mahal(gazePos)));
            end
            estimateStruct.likelihood = exp(ll);
            ll = ll - max(ll);
            l = exp(ll);
            estimateStruct.aPosteriori = l / sum(l);
            [~, estimateStruct.classIdx] = max(estimateStruct.aPosteriori);
            if sum(isnan(estimateStruct.aPosteriori))
                error('nan in aposteriori')
            end
        end
        
        function x = rand(self, targetIdx)
           % generates a random position given targetIdx
           x = self.distD{targetIdx}.random(self.trialLength);
        end
        
        function confMatrix = getConfMatrix(self, trialStruct)
            
           % estimates confMatrix via monte carlo
           numTarget = size(self.targetPos, 2);
           confMatrix = zeros(numTarget);
           
           for trialIdx = 1 : length(trialStruct)
              trialStruct0 = trialStruct(trialIdx);
              estimateStruct = self.Classify(trialStruct0);
              estimateIdx = estimateStruct.classIdx;
              targetIdx = trialStruct0.targetIdx;
              confMatrix(estimateIdx, targetIdx) = ...
                  confMatrix(estimateIdx, targetIdx) + 1;
           end
           
           % normalize confusion
           confMatrix = confMatrix * diag(1 ./ sum(confMatrix, 1));           
        end
    end
end

