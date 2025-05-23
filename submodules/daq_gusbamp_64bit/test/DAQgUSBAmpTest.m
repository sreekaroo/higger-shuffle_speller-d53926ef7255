%% Demo script for matlab daqgusbamp class. Assumes device is on and 
% Trigger Loopback Connector is attached

clc, clear;

% Here is the order of execution for general usage:
% (0) Turn on device and connect USB cable
% (1) Constructor: opens and inits device
% (2) OpenDevice
% (3) StartAcquisition: starts getting data (and put to file if enabled)
% (4) GetData, GetTrial, or do nothing
% (5) StopAcquistion: stops getting data and closes file if applicable
% (6) repeat (2)-(4) if needed
% (7) CloseDevice: good practice to call but the destructor will clean up
%                  appropiatedly

% Set parameters and create object
sampleRate = 512;
ampFilterNdx = 64;
notchFilterNdx = 5;
triggerFlag = 1;
channelsToAcquire = [1, 2, 3];
testTriggers = 0;
fileName = 'DAQgUSBAmpTestFile.bin';
serialNumbers = {};
% serialNumbers = {'UB-2013.06.13', 'UB-2009.07.05'};

% Add stuff to path
mfilepath=fileparts(which('DAQgUSBAmpTest.m'));
addpath(fullfile(mfilepath,'../matlab'));

% Call constructor 
DAQClassObj = DAQgUSBAmp('channelList',channelsToAcquire, ...
                            'fs', sampleRate,...
                            'triggerFlag',logical(triggerFlag), ...
                            'notchFilterNdx',notchFilterNdx, ...
                            'ampFilterNdx',ampFilterNdx, ...
                            'frontEndFilterFlag', false, ...
                            'calibrationFlag', false, ...
                            'ampSerialNumbers', serialNumbers);

% Demo trigger test
if testTriggers
    DAQClassObj.USBTriggerTest();                        
    DAQClassObj.ParallelPortTriggerTest();                        
end

% Start data acquisition
DAQClassObj.OpenDevice();
DAQClassObj.StartAcquisition('fileName', fileName);

% Send a couple of triggers with some pauses in between
DAQClassObj.SendTrigger(0);
elapsedTime = zeros(4,1);
tStart = tic;
pause(1);
elapsedTime(1) = toc(tStart);
DAQClassObj.SendTrigger(1);
tStart = tic;
pause(1);
elapsedTime(2) = toc(tStart);
DAQClassObj.SendTrigger(0);
tStart = tic;
pause(1);
elapsedTime(3) = toc(tStart);
DAQClassObj.SendTrigger(15);
tStart = tic;
pause(1);
elapsedTime(4) = toc(tStart);
DAQClassObj.SendTrigger(0);
pause(3);
[dataBuffer, triggerSignal] = DAQClassObj.GetData('numSamples',2560);

% Stop data acquisition
DAQClassObj.StopAcquisition();

% Close and delete object
DAQClassObj.CloseDevice();

%% Plot data, trigger, and spectrum
rawDataSpectrum = fft(dataBuffer(300:end,1));
nSamples = size(dataBuffer,1);
t = (0:nSamples-1)/sampleRate;
nSamples = length(rawDataSpectrum);
f = (0:nSamples-1)/nSamples*sampleRate;

figure(1)
subplot(2,1,1)
plot(t,dataBuffer(:,1), 'r');
hold on
plot(t,dataBuffer(:,2), 'b');
plot(t,dataBuffer(:,3), 'g');
legend('ch 1', 'ch 2', 'ch 3')
hold off
xlim([0.5 max(t)])
xlabel('time [s]')
ylabel('amplitude')
title('Signals')

subplot(2,1,2)
stem(t,triggerSignal);
xlabel('time [s]')
ylabel('trigger')

if testTriggers
    % Get timing from trigger
    elapsedTimeTrigger = t(diff(triggerSignal)<0) - t(diff(triggerSignal)>0);
end

figure(2)
plot(f,20*log10(abs(rawDataSpectrum)));
xlim([0 250])

xlabel('frequency [Hz]')
ylabel('amplitude [dB]')
title('Power spectrum of raw data')

save('DAQClassObjTest.mat', 'DAQClassObj');

clear DAQClassObj;

load('DAQClassObjTest.mat');

[dataBufferFromFile, triggerSignalFromFile] = loadSessionData('daqFileName', fileName);
[dataBufferFromFile, triggerSignalFromFile] = DAQClassObj.ApplyFrontEndFilter(dataBufferFromFile,triggerSignalFromFile);

% Check first 8 seconds of data
T = 4; 
lastIdx = find(t>=T, 1, 'first');

figure(3)
subplot(4,1,1)
plot(t(1:lastIdx),dataBufferFromFile(1:lastIdx,1)-dataBuffer(1:lastIdx,1));
title('Signal difference between offline and online filtering: ch1')
xlim([0 T])
ylabel('amplitude')
subplot(4,1,2)
plot(t(1:lastIdx),dataBufferFromFile(1:lastIdx,2)-dataBuffer(1:lastIdx,2));
title('Signal difference between offline and online filtering: ch2')
xlim([0 T])
ylabel('amplitude')
subplot(4,1,3)
plot(t(1:lastIdx),dataBufferFromFile(1:lastIdx,3)-dataBuffer(1:lastIdx,3));
title('Signal difference between offline and online filtering: ch3')
xlim([0 T])
ylabel('amplitude')
xlabel('time [s]')

if testTriggers
    subplot(4,1,4)
    stem(t(1:lastIdx),triggerSignalFromFile(1:lastIdx)-triggerSignal(1:lastIdx));
    xlim([0 T])
    xlabel('time [s]')
    ylabel('trigger')
    title('Trigger difference between offline and online filtering')
end

%% Plot data, trigger, and spectrum
% Start data acquisition

DAQClassObj.OpenDevice();
DAQClassObj.StartAcquisition();

% Send a couple of triggers with some pauses in between
DAQClassObj.SendTrigger(0);
elapsedTime = zeros(4,1);
tStart = tic;
pause(1);
elapsedTime(1) = toc(tStart);
DAQClassObj.SendTrigger(3);
tStart = tic;
pause(1);
elapsedTime(2) = toc(tStart);
DAQClassObj.SendTrigger(0);
tStart = tic;
pause(1);
elapsedTime(3) = toc(tStart);
DAQClassObj.SendTrigger(7);
tStart = tic;
pause(1);
elapsedTime(4) = toc(tStart);
DAQClassObj.SendTrigger(0);
pause(3);
[dataBuffer, triggerSignal] = DAQClassObj.GetData();

% Stop data acquisition
DAQClassObj.StopAcquisition();

% Close and delete object
DAQClassObj.CloseDevice();

%%
nSamples = size(dataBuffer,1);
t = (0:nSamples-1)/DAQClassObj.fs;

figure(4)
subplot(2,1,1)
plot(t,dataBuffer(:,1),'r');
hold on
plot(t,dataBuffer(:,2),'g');
plot(t,dataBuffer(:,3),'b');
legend('ch 1', 'ch 2', 'ch 3')
hold off
xlim([0.5 max(t)])
xlabel('time [s]')
ylabel('amplitude')
title('Signals')

subplot(2,1,2)
stem(t,triggerSignal);
xlabel('time [s]')
ylabel('trigger')

clear;
