%% classdef RemoteSignalMonitorGUI < handle
% Instantiates a remotely connected graphical user interface to display signal data from the data acquisition unit.

classdef RemoteSignalMonitorGUI < handle
    
    properties (Access = private)
        
        % Core objects/structs.
        TCPIPObject;
        BCIPacketStruct;
        GUIObject;
        
        % Variables.
        channelNames;
        
    end
    
    methods (Access = public)
        
        %% Constructor
        function self = RemoteSignalMonitorGUI()
            
            addpath(genpath('.')); % In case it isn't already done.
            
            self.TCPIPObject = [];
            self.BCIPacketStruct = [];
            self.GUIObject = [];
            
            self.channelNames = {};
            
        end
        
        
        %% function start(self,autoLaunchRemoteGUI,mainIP,remoteIP,port)
        % Operation: Creates and displays remote GUI window/frame and elements.
        % Input variables:
        %   > autoLaunchRemoteGUI - boolean scalar; if true, then the remote GUI is automatically launched.
        %   > mainIP - [1,N] character matrix; determines the IP address of the main server.
        %   > remoteIP - [1,N] character matrix; determines the IP address of the remote client.
        %   > port - integer scalar; determines the port number of the server and client.
        % Output variables: N/A
        function start(self,autoLaunchRemoteGUI,mainIP,remoteIP,port)
            
            assert(isa(autoLaunchRemoteGUI,'logical'));
            
            assert(isa(mainIP,'char'));
            assert(isvector(mainIP));
            
            assert(isa(remoteIP,'char'));
            assert(isvector(remoteIP));
            
            assert(isnumeric(port));
            assert(isscalar(port));
            assert(mod(port,1) == 0);
            
            if and(autoLaunchRemoteGUI,strcmp(mainIP,remoteIP))
                
                dos(['matlab -nosplash -r "addpath(genpath(''.''));GUI=RemoteSignalMonitorGUI();GUI.runClient(''',mainIP,''',',num2str(port),')" &']);
                
            end
            
            [~,main2GUICommObjectStruct,self.BCIPacketStruct] = sender2receiverCommInitialize('main','GUI',false,[],remoteIP,port);
            self.TCPIPObject = main2GUICommObjectStruct.main2GUICommObject;
            
        end
        
        %% function stop(self)
        % Operation: Destroys remote GUI window/frame and elements.
        % Input variables: N/A
        % Output variables: N/A
        function stop(self)
            
            if ~isempty(self.TCPIPObject)
                
                outPacket.header = self.BCIPacketStruct.HDR.STOP;
                outPacket.data = [];
                sendBCIPacket(self.TCPIPObject,self.BCIPacketStruct,outPacket);
                
            end
            
            fclose(self.TCPIPObject);
            
        end
        
        %% started = isStarted(self)
        % Operation: Destroys GUI window/frame and elements.
        % Input variables:
        %   > timeout - double scalar; number of seconds under which the display mode must be obtained.
        % Output variables:
        %   > started - boolean scalar; determines if the GUI window exists.
        function started = isStarted(self,timeout)
            
            assert(isa(timeout,'double')); % Assert that newSampleRate is a double type.
            assert(isscalar(timeout)); % Assert that newSampleRate is a double scalar.
            assert(0 < timeout); % Assert that newSampleRate is positive.
            
            started = false;
            
            if ~isempty(self.TCPIPObject)
                
                % Send a request to the remote GUI for the display mode.
                outPacket.header = self.BCIPacketStruct.HDR.STATE;
                outPacket.data = 'outPacket.header=self.BCIPacketStruct.HDR.STATE;outPacket.data=[''started='',num2str(self.GUIObject.isStarted()),'';''];sendBCIPacket(self.TCPIPObject,self.BCIPacketStruct,outPacket);';
                sendBCIPacket(self.TCPIPObject,self.BCIPacketStruct,outPacket);
                
                % Stall until there are bytes available.
                startTime = GetSecs();
                duration = 0;
                while (duration < timeout) && (self.TCPIPObject.BytesAvailable == 0);
                    currentTime = GetSecs();
                    duration = currentTime - startTime;
                end
                
                % Receive the return packet.
                inPacket = receiveBCIPacket(self.TCPIPObject,self.BCIPacketStruct);
                    
                if inPacket.header == self.BCIPacketStruct.HDR.STATE;
                    
                    % Evaluate packet data.
                    eval(inPacket.data);

                end
                
            end
            
        end
        
        %% function mode = getDisplayMode(self,timeout)
        % Operation: Returns the mode of the GUI. The mode is a numeral that denotes the type of data that is to be displayed by the GUI.
        % Input variables:
        %   > timeout - double scalar; number of seconds under which the display mode must be obtained.
        % Output variables:
        %   > mode - integer scalar; denotes the type of data that is to be displayed by the GUI.
        function mode = getDisplayMode(self,timeout)
            
            assert(isa(timeout,'double')); % Assert that newSampleRate is a double type.
            assert(isscalar(timeout)); % Assert that newSampleRate is a double scalar.
            assert(0 < timeout); % Assert that newSampleRate is positive.
            
            mode = 0;
            
            if ~isempty(self.TCPIPObject)
                
                % Send a request to the remote GUI for the display mode.
                outPacket.header = self.BCIPacketStruct.HDR.STATE;
                outPacket.data = 'outPacket.header=self.BCIPacketStruct.HDR.STATE;outPacket.data=[''mode='',num2str(self.GUIObject.getDisplayMode()),'';''];sendBCIPacket(self.TCPIPObject,self.BCIPacketStruct,outPacket);';
                sendBCIPacket(self.TCPIPObject,self.BCIPacketStruct,outPacket);
                
                % Stall until there are bytes available.
                startTime = GetSecs();
                duration = 0;
                while (duration < timeout) && (self.TCPIPObject.BytesAvailable == 0);
                    currentTime = GetSecs();
                    duration = currentTime - startTime;
                end
                
                % Receive the return packet.
                inPacket = receiveBCIPacket(self.TCPIPObject,self.BCIPacketStruct);
                    
                if inPacket.header == self.BCIPacketStruct.HDR.STATE;
                    
                    % Evaluate packet data.
                    eval(inPacket.data);

                end
                
            end
            
        end
        
        %% function setChannelNames(self,newChannelNames)
        % Operation: Changes the names of the channels for which data is to be displayed.
        % Input variables:
        %   > newChannelNames - [1,N] cell matrix, each cell contains a [1,X] character matrix; new names of the channels for which data is to be displayed.
        % Output variables: N/A
        function setChannelNames(self,newChannelNames)
            
            assert(isa(newChannelNames,'cell')); % Assert that newChannelNames is a cell type.
            assert(ismatrix(newChannelNames)); % Assert that newChannelNames is a {0,1,2} dimensional cell matrix.
            assert(size(newChannelNames,1) <= 1); % Assert that newChannelNames is either a [1,N] cell matrix, or an empty cell matrix.
            for i = length(newChannelNames);
                
                assert(isa(newChannelNames{i},'char')); % Assert that every element of newChannelNames is a character matrix.
                
            end
            
            % Ensure that the data isn't being sent uneccesarily.
            if ~isequal([self.channelNames{:}],[newChannelNames{:}])
            
                % If all of the above asserts are successful, send the new channel names to the remote GUI in a packet.
                if ~isempty(self.TCPIPObject)

                    outPacket.header = self.BCIPacketStruct.HDR.STATE;
                    outPacket.data = ['newChannelNames=','{',sprintf('''%s'',',newChannelNames{1:end-1}),sprintf('''%s''',newChannelNames{end}),'};'];
                    sendBCIPacket(self.TCPIPObject,self.BCIPacketStruct,outPacket);

                end

                self.channelNames = newChannelNames;
            
            end
            
            
            
        end
        
        %% function setSampleRate(self,newSampleRate)
        % Operation: Changes the names of the channels for which data is to be displayed.
        % Input variables:
        %   > newSampleRate - scalar double; number of samples of data to be displayed per second.
        % Output variables: N/A
        function setSampleRate(self,newSampleRate)
            
            assert(isa(newSampleRate,'double')); % Assert that newSampleRate is a double type.
            assert(isscalar(newSampleRate)); % Assert that newSampleRate is a double scalar.
            assert(0 < newSampleRate && newSampleRate < Inf); % Assert that newSampleRate is positive and finite.
            
            % If all of the above asserts are successful, send the new sample rate to the remote GUI in a packet.
            if ~isempty(self.TCPIPObject)
                
                outPacket.header = self.BCIPacketStruct.HDR.STATE;
                outPacket.data = ['newSampleRate=hex2num(''',num2hex(newSampleRate),''');'];
                sendBCIPacket(self.TCPIPObject,self.BCIPacketStruct,outPacket);
                
            end
            
        end
        
        %% function setChannelStatuses(self,channelStatuses)
        % Operation: Changes the channel status image next to a channel name label.
        % Input variables:
        %   > channelStatuses - [1,N] double array; denotes the statuses of the channels.
        % Output variables: N/A
        function setChannelStatuses(self,channelStatuses)
            
            assert(isnumeric(channelStatuses)); % Assert that array of channel statuses is a numeric type.
            assert(isequal(size(channelStatuses),[1,length(self.channelNames)])); % Assert that the array of channel statuses are the same size as the array of channel names.
            assert(isa(channelStatuses,'double')); % Assert that the array of channel statuses is a double type.
            assert(and(all(0 <= channelStatuses),all(channelStatuses <= 1))); % Assert that all the elements of the array of channel statuses are within the range [0,1].
            
            % If all of the above asserts are successful, send the channel status to the remote GUI in a packet.
            if ~isempty(self.TCPIPObject)
                
                outPacket.header = self.BCIPacketStruct.HDR.STATE;
                hexData = num2hex(channelStatuses);
                outPacket.data = ['channelStatuses=transpose([hex2num(reshape(''',reshape(hexData,1,numel(hexData)),''',',num2str(length(self.channelNames)),',16))]);'];
%                 disp(outPacket.data);
                sendBCIPacket(self.TCPIPObject,self.BCIPacketStruct,outPacket);
                
            end
            
        end
        
        %% function addData(self,data)
        % Operation: Appends the input data to the buffer of data to be displayed.
        % Input variables:
        %   > data - [M,N] double matrix; new data to be appended to the buffer of data to be displayed.
        % Output variables: N/A
        function addData(self,newData)
            
            assert(isa(newData,'double')); % Assert that data is a double type.
            assert(ismatrix(newData)); % Assert that data is a {0,1,2} dimensional cell matrix.
            assert(size(newData,2) == length(self.channelNames)); % Assert that data is a [M,N] matrix, for any M and such that N is the number of channels.
            
            % If all of the above asserts are successful, send the data to the remote GUI in a packet.
            if ~isempty(self.TCPIPObject)
                
                outPacket.header = self.BCIPacketStruct.HDR.STATE;
                hexData = num2hex(newData);
                outPacket.data = ['newData=reshape(hex2num(reshape(''',reshape(hexData,1,numel(hexData)),''',',num2str(size(hexData,1)),',',num2str(size(hexData,2)),')),',num2str(size(newData,1)),',',num2str(size(newData,2)),');'];
                sendBCIPacket(self.TCPIPObject,self.BCIPacketStruct,outPacket);
                
            end
            
        end
        
        %% function runClient(self)
        % Operation: Runs the remote GUI client.
        % Input variables:
        %   > mainIP - [1,N] character matrix; determines the IP address of the main server.
        %   > mainPort - integer scalar; determines the port number of the main server.
        % Output variables: N/A
        function runClient(self,mainIP,port)
            
            % Initialise TCPIP connection.
            [~,CommObjectStruct,self.BCIPacketStruct] = sender2receiverCommInitialize('GUI','main',false,[],mainIP,port);
            self.TCPIPObject = CommObjectStruct.GUI2mainCommObject;
            
            % Initialise GUI object.
            self.GUIObject = SignalMonitorGUI();
            self.GUIObject.start();
            
            % Initialise loop.
            loop = true;
            while loop
                
                % Check if the GUI has been closed.
                if ~self.GUIObject.isStarted()
                    
                    % Terminate client.
                    loop = false;
                
                else
                    
                    % Check if there are incoming packets.
                    if self.TCPIPObject.BytesAvailable

                        inPacket = receiveBCIPacket(self.TCPIPObject,self.BCIPacketStruct);
                        switch inPacket.header

                            case self.BCIPacketStruct.HDR.STOP

                                % Terminate client.
                                loop = false;

                            case self.BCIPacketStruct.HDR.STATE

                                % Evaluate packet data.
%                                 disp(inPacket.data)
                                eval(inPacket.data);

                                % Set channel names.
                                if exist('newChannelNames','var');

                                    self.GUIObject.setChannelNames(newChannelNames);
                                    clear newChannelNames;

                                end

                                % Set sample rate.
                                if exist('newSampleRate','var');

                                    self.GUIObject.setSampleRate(newSampleRate);
                                    clear newSampleRate;

                                end

                                % Set channel status.
                                if exist('channelStatuses','var');
                                    
                                    self.GUIObject.setChannelStatuses(channelStatuses);
                                    clear channelStatuses;

                                end

                                % Add data.
                                if exist('newData','var');

                                    self.GUIObject.addData(newData);
                                    clear newData;

                                end

                        end
                        
                    else
                        
                        pause(0.001);
                        
                    end
                
                end
                
            end
            
            self.GUIObject.stop();
            fclose(self.TCPIPObject);
            close;
            clear;
            exit;
            
        end
        
    end
    
end