colors = hsv(prod(targetDim));
markerSize = 60;
for idx = 1 : length(trialStruct)
    targetIdx = trialStruct(idx).targetIdx;
    targetPos = trialStruct(idx).targetPos;
    gazePos = mean(trialStruct(idx).gazePos);
    
    % plot mean trial
    scatter(gazePos(1), 1 - gazePos(2), markerSize, 'o', ...
        'MarkerFaceColor', colors(targetIdx, :), ...
        'MarkerEdgeColor', [1, 1, 1]);
    
    hold on;
    
    % plot target
    scatter(targetPos(1), 1 - targetPos(2), 1.5 * markerSize, 's', ...
        'MarkerFaceColor', colors(targetIdx, :), ...
        'MarkerEdgeColor', [1, 1, 1]);
    
end

title('mean eye gaze')
ylabel('y pos')
xlabel('x pos')
grid on;