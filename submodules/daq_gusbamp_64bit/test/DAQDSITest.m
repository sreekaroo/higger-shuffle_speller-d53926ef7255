%% Demo script for matlab daq dsi
clc, clear;

% Set parameters and create object
mfilepath=fileparts(which('DAQDSITest.m'));
addpath(fullfile(mfilepath,'../matlab'));

fileName = 'testDSI.csv';
testTriggers = true;

if testTriggers 
    triggerObj = TriggerParallel();
    triggerObj.SendTrigger(0);     
end

% Call constructor 
daqObj = DAQDSI('fs',300, 'channelList', 1:20);

% Start data acquisition
daqObj.OpenDevice();

if testTriggers
    daqObj.ParallelPortTriggerTest();
end

disp('Enable streaming and press a key to continue')
pause();

daqObj.StartAcquisition('fileName', fileName);

% Get 1 second data
pause(1)

if testTriggers
    triggerObj.SendTrigger(1);
    pause(1)
    triggerObj.SendTrigger(0);
    pause(0.5)
end

[dataBuffer, triggerSignal] = daqObj.GetData();

% Stop data acquisition
daqObj.StopAcquisition();

% Close and delete object
daqObj.CloseDevice();
