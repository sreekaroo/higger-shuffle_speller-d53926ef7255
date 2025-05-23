% get calibration data
% [file, path, ~] = uigetfile();
file = 'gazeShuffle_1RJ_Sep-26-2018_ 2-27_PMcalib.mat';
path = '/home/matt/.dropbox-mh/Dropbox/shuffle_jan_2019/shuffle_speller/Data/OLD/gazeShuffle_1RJ_Sep-26-2018_ 2-27_PM/';
load([path, file]);

k = 10;
gazeClassifierObj = gazeClassifier();
targetIdx = [trialStruct(:).targetIdx];
numTarget = max(targetIdx);
confMatrix = zeros(numTarget);
cvpart = cvpartition(targetIdx,'KFold',k);

for fold = 1 : k
    trialStructTrain = trialStruct(cvpart.training(fold));
    trialStructTest = trialStruct(cvpart.test(fold));
    gazeClassifierObj.Learn(trialStructTrain);
    confMatrix = confMatrix + gazeClassifierObj.getConfMatrix(trialStructTest);
end
confMatrix = confMatrix / k;
gazeClassifierObj.Learn(trialStruct);

save([path, 'classifier.mat'], 'gazeClassifierObj', 'targetDim', 'confMatrix');
disp(confMatrix);

close all;

% plot and print graph
numTarget = size(confMatrix, 1);
color = hsv(numTarget);
for idx = 1 : numTarget
    colorTarget = color(idx, :);
    targetPos = gazeClassifierObj.targetPos(:, idx);
    
    % get training data
    activeTrial = [trialStruct(:).targetIdx] == idx;
    trialStructTarget = trialStruct(activeTrial);
    gazePos = {trialStructTarget(:).gazePos};
    gazePos = vertcat(gazePos{:})';
    gazePos(:, logical(sum(isnan(gazePos)))) = [];
    gazePos = gazePos';
    
    scatter(gazePos(:, 1), gazePos(:, 2), 'c', 'filled', 'MarkerFaceColor', colorTarget);
    hold on;
    scatter(targetPos(1), targetPos(2), 's', 'filled', 'MarkerFaceColor', colorTarget, 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
    
end
title('observed gaze per target (calibration)');
ax = gca;
ax.YDir = 'reverse';
filename = strcat(path, 'scatter_observed.png');
saveas(gcf,filename)

% plot and print graph
figure;
for idx = 1 : numTarget
    colorTarget = color(idx, :);
    targetPos = gazeClassifierObj.targetPos(:, idx);
    
    % monte carlo sample
    mcPos = gazeClassifierObj.rand(idx);
    
    scatter(mcPos(:, 1), mcPos(:, 2), 'c', 'filled', 'MarkerFaceColor', colorTarget);
    hold on;
    scatter(targetPos(1), targetPos(2), 's', 'filled', 'MarkerFaceColor', colorTarget, 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
    
end
title('synthetic gaze per target (classifier)');
ax = gca;
ax.YDir = 'reverse';
filename = strcat(path, 'scatter_estimated.png');
saveas(gcf,filename)
