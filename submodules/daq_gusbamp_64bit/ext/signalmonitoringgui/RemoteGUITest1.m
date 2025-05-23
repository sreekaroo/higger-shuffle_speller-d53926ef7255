clear;
clc;

channelNames = {'A','B','C','D'};
channelStatuses = ones(1,length(channelNames));

RemoteGUIObj = RemoteSignalMonitorGUI();
RemoteGUIObj.start(true,'localhost','localhost',33333);
RemoteGUIObj.setChannelNames(channelNames);
RemoteGUIObj.setSampleRate(10);

serverRunning = true;
clientRunning = false;
while serverRunning
    
    switch RemoteGUIObj.getDisplayMode(1)

        case 2
            % Send data packet.
            data = (rand(1,3) - 0.5) / 1E5;
            data = [data,sin(GetSecs() * 5) / 1E5];
            RemoteGUIObj.addData(data);
            
            if true % Debug switch.
        
                changingChannelStatus = randi([1,length(channelNames)],1); % Select a random channel.
                channelStatuses(changingChannelStatus) = channelStatuses(changingChannelStatus) - 0.05 + (rand(1) * 0.1); % Change channel status by <5%.
                if channelStatuses(changingChannelStatus) > 1; channelStatuses(changingChannelStatus) = 1; end;
                if channelStatuses(changingChannelStatus) <0; channelStatuses(changingChannelStatus) = 0; end;
                RemoteGUIObj.setChannelStatuses(channelStatuses);
            end

    end
    
    if clientRunning
        
        if ~(RemoteGUIObj.isStarted(1))
            
            serverRunning = false;
            
        end
        
    else
        
        if RemoteGUIObj.isStarted(1)
        
            clientRunning = true;

        end
        
    end
    
    pause(0.01);

end

RemoteGUIObj.stop();