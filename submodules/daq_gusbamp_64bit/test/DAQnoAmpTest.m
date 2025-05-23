clear;
clc;

% Add stuff to path
mfilepath=fileparts(which('DAQnoAmpTest.m'));
addpath(fullfile(mfilepath,'../matlab'));

% Parameters
fs = 256;
T = 3;

daqNoAmpObj = DAQnoAmp('channelList', [1 2 5], ...
                        'triggerType', 'custom', ...
                        'fs', fs, ...
                        'frontEndFilterFlag', false);
t = (0:1/fs:T-1/fs);
nSamples = length(t);    

% Create custom triangle trigger
customTrigerSignal = [0:floor(nSamples/2) ceil(nSamples/2):nSamples-1];

% does nothing
daqNoAmpObj.OpenDevice();

rng('default');

% Start acquisition. no filename used by this method
daqNoAmpObj.StartAcquisition();
daqNoAmpObj.SetTrigger(customTrigerSignal);

% Get data in two chunks
pause(T/2)
[rawData, triggerSignal] = daqNoAmpObj.GetData();                  
pause(T/2)
[rawData2, triggerSignal2] = daqNoAmpObj.GetData();        

figure(1)
subplot(2,1,1)
plot([rawData(:,1); rawData2(:,1)]);
xlabel('samples')
ylabel('amplitude')
title('raw data from channel 1')
subplot(2,1,2)
plot([triggerSignal; triggerSignal2]);
hold on
plot(customTrigerSignal,'r--');
hold off
xlabel('samples')
ylabel('trigger')
legend('measured','provided')
title('triggers signals')

daqNoAmpObj.StopAcquisition();
daqNoAmpObj.CloseDevice();

prevRawData = [rawData(:,1); rawData2(:,1)];

%%

% Create custom triangle trigger
customTrigerSignal = [zeros(1,nSamples/4) ones(1,nSamples/2) zeros(1,nSamples/4)];

% does nothing
daqNoAmpObj.OpenDevice();

% Start acquisition. no filename used by this method
rng('default');
daqNoAmpObj.StartAcquisition();
daqNoAmpObj.SetTrigger(customTrigerSignal);

% Get data in two chunks
rawData = daqNoAmpObj.GetTrial('triggerType', 'block');                  

figure(2)
subplot(2,1,1)
plot([zeros(nSamples/4,1); rawData(:,1)]);
xlabel('samples')
ylabel('amplitude')
title('raw data from channel 1')
ylim([-5e-5 5e-5]);

subplot(2,1,2)
plot(prevRawData(1:nSamples*3/4,1));
xlabel('samples')
ylabel('amplitude')
title('raw data from prev run for channel 1')
ylim([-5e-5 5e-5]);

assert(all(prevRawData(nSamples/4+(1:nSamples/2),1) == rawData(:,1)), 'data with the same seed does not produce same results');

daqNoAmpObj.StopAcquisition();
daqNoAmpObj.CloseDevice();


