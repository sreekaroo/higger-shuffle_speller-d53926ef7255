clearvars; clc; jheapcl;

projectID = 'gazeShuffle';
subjectID = 'matt';

%% load parameters
saveFileStem = setPathAndSavefile(...
    'projectID', projectID, ...
    'subjectID', subjectID);

% load params
gaze_calibParams;

daqEyeObj = DaqTobiiEyeX();
daqEyeObj.OpenDevice();
daqEyeObj.StartAcquisition();
daqEyeObj.ValidateAnyData()

calibGazeObj = calibGaze(...
    'screenNumber', screenNumber, ...
    'targetDim', targetDim, ...
    'boxCenter', boxCenter, ...
    'daqEyeObj', daqEyeObj, ...
    'trialWav', trialWav);

trialStruct = calibGazeObj.go(...
    'numTrialPerTarget', numTrialPerTarget, ...
    'trialLengthSec', trialLengthSec, ...
    'interTrialLengthSec', interTrialLengthSec, ...
    'breakEveryNTrial', breakEveryNTrial, ...
    'breakLengthSec', breakLengthSec);

saveFile = [saveFileStem, 'calib.mat'];
save(saveFile);

sca;

%% print trajectories fig
figure;
colors = hsv(prod(targetDim));
for trialIdx = 1 : length(trialStruct)
    t = trialStruct(trialIdx);
    
    % plot target
    scatter(t.targetPos(1), 1 - t.targetPos(2), 's', ...
        'MarkerFaceColor', colors(t.targetIdx, :));
    hold on;
    
    
    % plot trajectory, label end
    plot(t.gazePos(:, 1), 1 - t.gazePos(:, 2), ...
        'Color', colors(t.targetIdx, :));
end
grid on;
print([saveFileStem, '_trajectories'], '-dpng');