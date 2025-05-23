% Demo for load session data file
clear; clc;

% add path
mfilepath=fileparts(which('loadSessionDataTest.m'));
addpath(fullfile(mfilepath,'../matlab'));

% File stored in repo ( I know, I know, bad practice)
inputFileName = 'loadSessionDataTestFile.bin';

% Load data
[rawData, triggerSignal, sampleRate, channelList, daqInfo, filterInfo] = loadSessionData('daqFileName',inputFileName,...
                                                                                         'saveMatFileFlag',false);


figure(1)
subplot(2,1,1)
t = (0:size(rawData,1)-1)/sampleRate;

plot(t,rawData(:,1));
hold on
plot(t,rawData(:,2));
plot(t,rawData(:,3));
legend('ch 1', 'ch 2', 'ch 3')
hold off
xlim([0.5 max(t)])
xlabel('time [s]')
ylabel('amplitude')
title('Signals')
hold off
xlim([0.5 max(t)])
subplot(2,1,2)
plot(t,triggerSignal);
xlim([0.5 max(t)])
xlabel('time [s]')
ylabel('trigger')
title('Trigger signal')

%%
clear

[rawData, triggerSignal, sampleRate, channelList, daqInfo, filterInfo] = loadSessionData('daqType','dsi');