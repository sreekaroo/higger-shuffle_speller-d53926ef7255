clear;
clc;

channelNames = {'A','B','C','D'};
channelStatuses = ones(1,length(channelNames));

GUIObj = SignalMonitorGUI();
GUIObj.setChannelNames(channelNames);
GUIObj.setSampleRate(10);
GUIObj.start();

while GUIObj.isStarted()
    
    switch GUIObj.getDisplayMode();

        case 2
            % Send data packet.
            data = (rand(1,3) - 0.5) / 10;
            data = [data,sin(GetSecs() * 5) / 10];
            GUIObj.addData(data);
            
            if true % Debug switch.
        
                changingChannelStatus = randi([1,length(channelNames)],1); % Select a random channel.
                channelStatuses(changingChannelStatus) = channelStatuses(changingChannelStatus) - 0.05 + (rand(1) * 0.1); % Change channel status by <5%.
                if channelStatuses(changingChannelStatus) > 1; channelStatuses(changingChannelStatus) = 1; end;
                if channelStatuses(changingChannelStatus) <0; channelStatuses(changingChannelStatus) = 0; end;

                GUIObj.setChannelStatuses(channelStatuses);

            end

    end
    
    pause(0.01);

end

GUIObj.stop();