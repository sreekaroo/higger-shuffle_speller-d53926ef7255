% Add stuff to path
clear; clc;
mfilepath=fileparts(which('launchGUITest.m'));
addpath(fullfile(mfilepath,'../matlab'));
addpath(fullfile(mfilepath,'../ext/signalmonitoringgui'));

%%
% Launch GUI test. Daq object stays within function scopes
launchGUI('channelList', [1 2 3 4]);

%%

daqNoAmpObj = DAQnoAmp('channelList', [1 2 5]);
launchGUI('daqManagerObj', daqNoAmpObj);

%%
% Launch GUI test. Daq object stays within function scopes
% Set parameters and create object
channelsToAcquire = [1:32];
serialNumbers = {'UB-2013.06.13', 'UB-2009.07.05'};

% Call constructor 
DaqObj = DAQgUSBAmp('channelList', channelsToAcquire, ...
                    'ampSerialNumbers', serialNumbers);

% DaqObj = DAQgUSBAmp('channelList',channelsToAcquire);
                        
launchGUI('daqManagerObj', DaqObj);

%%
% Launch GUI test
channelsToAcquire = [1:4];

% Call constructor 
adaptiveFilterParams.delta = 1e-10;
adaptiveFilterParams.lambda = 0.95;
adaptiveFilterParams.order = 5;
adaptiveFilterParams.refIdx = 1;
DaqObj = DAQgUSBAmp('channelList', channelsToAcquire, 'adaptiveFilterFlag', true, ...
                     'adaptiveFilterParams', adaptiveFilterParams);
                        
launchGUI('daqManagerObj', DaqObj);

%%

daqObj = DAQDSI('fs', 300, 'channelList', 1:20);
launchGUI('daqManagerObj', daqObj, 'fileName', 'testGUI.csv');