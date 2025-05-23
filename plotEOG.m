clear;
clc;

eegChannels = [1:7];

ampFilterNdx = -1;
notchFilterNdx = 3;
fsEOG = 256;
pauseTime = 10;

eegObj = DAQgUSBAmp('channelList', eegChannels, ...
                            'notchFilterNdx',notchFilterNdx, ...
                            'ampFilterNdx',ampFilterNdx, ...
                            'frontEndFilterFlag', false);
                        
%%

eegObj.OpenDevice();
eegObj.StartAcquisition();

disp('press a key to continue')
pause();

eegObj.GetData();

pause(pauseTime);

eegData = eegObj.GetData();

eegObj.StopAcquisition();
eegObj.CloseDevice();

%% 

NEOG = size(eegData,1); 
tEOG = (0:NEOG-1)/fsEOG;

tAxis = [0 10];

figure(1)
subplot(2,1,1)
% yyaxis left
plot(tEOG, eegData(:,2)-eegData(:,1), 'linewidth',1.5) % 2 - 1
ylabel('EOG [\muV]', 'fontsize', 26)
xlabel('time [s]', 'fontsize', 26)
title('Vertical left eye', 'fontsize', 30)
grid on
xlim(tAxis);

subplot(2,1,2)
% yyaxis left
plot(tEOG, eegData(:,3), 'linewidth',1.5)  % 3
ylabel('EOG [\muV]', 'fontsize', 26)
xlabel('time [s]', 'fontsize', 26)
grid on
xlim(tAxis);
title('Horizontal left eye', 'fontsize', 30)

%%

figure(2)
subplot(2,1,1)
% yyaxis left
plot(tEOG, eegData(:,6)-eegData(:,5), 'linewidth',1.5)
ylabel('EOG [\muV]', 'fontsize', 26)
xlabel('time [s]', 'fontsize', 26)
title('Vertical right eye', 'fontsize', 30)
grid on
xlim(tAxis);
subplot(2,1,2)
% yyaxis left
plot(tEOG, eegData(:,3)-eegData(:,7), 'linewidth',1.5)
xlabel('time [s]', 'fontsize', 26)
ylabel('EOG [\muV]', 'fontsize', 26)
grid on
xlim(tAxis);
title('Horizontal right eye', 'fontsize', 30)