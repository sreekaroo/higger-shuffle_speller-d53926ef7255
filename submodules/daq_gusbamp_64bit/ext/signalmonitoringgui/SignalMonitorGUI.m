%% classdef SignalMonitorGUI < handle
% Instantiates a graphical user interface to display signal data from the data acquisition unit.

classdef SignalMonitorGUI < handle
    
    properties ( Access = private )
        
        % Data.
        displayMode; % Integer scalar; denotes the type of data that is to be displayed by the GUI.
        xScaleIndex; % Integer scalar; denotes the index of the scale of the x-axis that is to be used by the GUI.
        yScaleIndices; % [1,D] Integer matrix; denotes the indices of the scale of the y-axis that is to be used by the GUI.
        channelNames; % [1,N] cell matrix, each cell contains a [1,X] character matrix; new names of the channels for which data is to be displayed.
        channelStatuses; % [1,N] double matrix, each element is in the range [0,1]; denotes the statuses of the channels.
        channelDisplays; % [1,N] boolean matrix; determines if the channel is to be displayed. 
        isPaused; % Boolean scalar; determines if the display is paused.
        sampleRate; % Double scalar; number of samples of data to be displayed per second.
        dataBuffer; % [M,N+1] double matrix; data to be displayed when the GUI is not paused. The first row of this matrix is the ordinate data, while the rest is the abscissa data.
        dataBufferZeroPointer; % Integer scalar; index of the first element in the data buffer.
        pauseBuffer; % [M,N+1] double matrix; data to be displayed when the GUI is paused. The first row of this matrix is the ordinate data, while the rest is the abscissa data.
        pauseBufferZeroPointer; % Integer scalar; index of the first element in the pause buffer.
        
        % UI elements.
        frame; % Figure; window/frame that contains the GUI.
        
        menuPanel; % UI Panel; contains the drop down menus.
        modeTitleLabel; % Text box; displays the title of the mode menu;
        modeMenu; % Drop down menu; allows the user to select the GUI display mode.
        xAxisScaleTitleLabel; % Text box; displays the title of the x-axis scale menu;
        xAxisScaleMenu; % Drop down menu; allows the user to select the number of seconds worth of data to be displayed.
        yAxisScaleTitleLabel; % Text box; displays the title of the y-axis scale menu;
        yAxisScaleMenu; % Drop down menu; allows the user to select the scaling of the voltage of the data to be displayed.
        
        channelPanel; % UI Panel; contains the channel information.
        channelNameTitleLabel; % Text box; displays the title of the channel name labels.
        channelToggleDisplayTitleLabel; % Text box; displays the title of the channel display toggle buttons.
        channelStatusTitleLabel; % Text box; displays the title of channel status images.
        channelNameLabels; % Text box matrix; display the channel names.
        channelToggleDisplayButtons; % Toggle button matrix; allow the user to toggle the display of inidividual channels.
        channelStatusImages; % Image matrix; denote the statuses of the channels.
        enableAllChannelDisplaysButton; % Push button; used to enable all the channels at once.
        disableAllChannelDisplaysButton; % Push button; used to disable all the channels at once.
        pauseButton; % Toggle button; used to pause and unpause the display.
        
        displayAxes; % Axes; displays the data plots.
        
        % UI element parameters.
        GUIParameterStruct; % Struct; contains the data pertaining to the GUI layout.
        
    end
    
    properties ( GetAccess = public, SetAccess = immutable)
        displayModeOptions; % Vector with integers corresponding to options in displayMode
    end
    
    methods ( Access = public )
        
        %% Constructor
        function self = SignalMonitorGUI()
            
            addpath(genpath('.'));
            GUIParameters;
            self.GUIParameterStruct = GUIParameterStruct;
            self.displayModeOptions = self.GUIParameterStruct.displayModeOptions;
            self.displayMode = 1;
            self.xScaleIndex = self.GUIParameterStruct.xAxisScaleInitialValueIndex;
            self.yScaleIndices = self.GUIParameterStruct.yAxisScaleInitialValueIndices;
            self.channelNames = {};
            self.channelStatuses = [];
            self.channelDisplays = [];
            self.isPaused = false;
            self.sampleRate = 1;
            self.dataBuffer = [];
            self.dataBufferZeroPointer = 0;
            self.pauseBuffer = [];
            self.pauseBufferZeroPointer = 0;
            
        end
        
        %% function start(self)
        % Operation: Creates and displays GUI window/frame and elements.
        % Input variables: N/A
        % Output variables: N/A
        function start(self)
            
            % Check if the GUI window/frame does not exist.
            if ~self.isStarted();
                
                % Create new GUI window/frame.
                self.frame = figure(...
                                    'Name',self.GUIParameterStruct.frameTitle,...
                                    'NumberTitle','off',...
                                    'Units','Normalized',...
                                    'Toolbar','None',...
                                    'Menu','None',...
                                    'ResizeFcn',{@self.resize}...
                                   );
               
                % Create the menu panel.
                self.menuPanel = uipanel(...
                                         self.frame,...
                                         'Units','Normalized'...
                                        );
                                    
                % Add the menu titles to the menu panel.
                self.modeTitleLabel = uicontrol(...
                                                self.menuPanel,...
                                                'Style','Text',...
                                                'Units','Normalized',...
                                                'String',self.GUIParameterStruct.modeTitle,...
                                                'FontSize',self.GUIParameterStruct.fontSize...
                                               );
                                           
                self.xAxisScaleTitleLabel = uicontrol(...
                                                  self.menuPanel,...
                                                  'Style','Text',...
                                                  'Units','Normalized',...
                                                  'String',self.GUIParameterStruct.xAxisScaleTitle,...
                                                  'FontSize',self.GUIParameterStruct.fontSize...
                                                 );
                                             
                self.yAxisScaleTitleLabel = uicontrol(...
                                                      self.menuPanel,...
                                                      'Style','Text',...
                                                      'Units','Normalized',...
                                                      'String',self.GUIParameterStruct.yAxisScaleTitle,...
                                                      'FontSize',self.GUIParameterStruct.fontSize...
                                                     );
                                                 
                % Add the drop down menus to the menu panel.
                self.modeMenu = uicontrol(...
                                          self.menuPanel,...
                                          'Style','Popupmenu',...
                                          'Units','Normalized',...
                                          'BackgroundColor','white',...
                                          'String',self.GUIParameterStruct.modeOptions,...
                                          'Value',self.displayMode,...
                                          'FontSize',self.GUIParameterStruct.fontSize,...
                                          'Callback',{@self.updateDisplayMode}...
                                         );
                                     
                self.xAxisScaleMenu = uicontrol(...
                                            self.menuPanel,...
                                            'Style','Popupmenu',...
                                            'Units','Normalized',...
                                            'BackgroundColor','white',...
                                            'String',cellfun(@(array)([num2str(array),' ',self.GUIParameterStruct.xAxisUnit]),num2cell(self.GUIParameterStruct.xAxisScaleValues), 'UniformOutput', false),...
                                            'Value',self.xScaleIndex,...
                                            'FontSize',self.GUIParameterStruct.fontSize,...
                                            'Callback',{@self.updateAxes}...
                                           );
            
                self.yAxisScaleMenu = uicontrol(...
                                                self.menuPanel,...
                                                'Style','Popupmenu',...
                                                'Units','Normalized',...
                                                'BackgroundColor','white',...
                                                'String',cellfun(@(array)([num2str(array),' ',self.GUIParameterStruct.yAxisUnit{self.displayMode}]),num2cell(self.GUIParameterStruct.yAxisScaleValues{self.displayMode}), 'UniformOutput', false),...
                                                'Value',self.yScaleIndices(self.displayMode),...
                                                'FontSize',self.GUIParameterStruct.fontSize,...
                                                'Callback',{@self.updateAxes}...
                                               );

                % Create the channel panel.
                self.channelPanel = uipanel(...
                                            self.frame,...
                                            'Units','Normalized'...
                                           );
                                       
                % Add the channel titles to the channel panel.
                self.channelNameTitleLabel = uicontrol(...
                                                   self.channelPanel,...
                                                   'Style','Text',...
                                                   'Units','Normalized',...
                                                   'String',self.GUIParameterStruct.channelNameTitle,...
                                                   'FontSize',self.GUIParameterStruct.fontSize...
                                                  );
                self.channelToggleDisplayTitleLabel = uicontrol(...
                                                                self.channelPanel,...
                                                                'Style','Text',...
                                                                'Units','Normalized',...
                                                                'String',self.GUIParameterStruct.channelToggleDisplayTitle,...
                                                                'FontSize',self.GUIParameterStruct.fontSize...
                                                               );
                self.channelStatusTitleLabel = uicontrol(...
                                                         self.channelPanel,...
                                                         'Style','Text',...
                                                         'Units','Normalized',...
                                                         'String',self.GUIParameterStruct.channelStatusTitle,...
                                                         'FontSize',self.GUIParameterStruct.fontSize...
                                                        );

                % Declare the channel UI elements.
                self.channelNameLabels = zeros(1,length(self.channelNames));
                self.channelToggleDisplayButtons = zeros(1,length(self.channelNames));
                self.channelStatusImages = zeros(1,length(self.channelNames));
                
                % Initialise the channel UI elements.
                for i = 1:length(self.channelNames);

                    % Initialise the channel name labels.
                    self.channelNameLabels(i) = uicontrol(...
                                                          self.channelPanel,...
                                                          'Style','Text',...
                                                          'Units','Normalized',...
                                                          'String',self.channelNames{i},...
                                                          'FontSize',self.GUIParameterStruct.fontSize...
                                                         );

                    % Initialise the channel toggle buttons.
                    self.channelToggleDisplayButtons(i) = uicontrol(...
                                                                    self.channelPanel,...
                                                                    'Style','Togglebutton',...
                                                                    'Value',self.channelDisplays(i),...
                                                                    'Units','Normalized',...
                                                                    'String',num2str(length(self.channelNames) - i + 1),...
                                                                    'FontSize',self.GUIParameterStruct.fontSize,...
                                                                    'Callback',{@self.toggleChannelDisplay,i}...
                                                                   );
                                                               
                    % Initialise the channel status images.
                    self.channelStatusImages(i) = uipanel(...
                                                            self.channelPanel,...
                                                            'Units','Normalized',...
                                                            'BackgroundColor',[0,1,0]...
                                                           );
                                                       
                    % Update the channel status images.
                    updateStatusImage(self,i);

                end
                
                % Initialise the macro-control buttons.
                self.enableAllChannelDisplaysButton = uicontrol(...
                                                                self.channelPanel,...
                                                                'Style','Pushbutton',...
                                                                'Units','Normalized',...
                                                                'String',self.GUIParameterStruct.enableAllChannelDisplaysButtonText,...
                                                                'FontSize',self.GUIParameterStruct.fontSize,...
                                                                'Callback',{@self.enableAllChannelDisplays}...
                                                               );
                self.disableAllChannelDisplaysButton = uicontrol(...
                                                                self.channelPanel,...
                                                                'Style','Pushbutton',...
                                                                'Units','Normalized',...
                                                                'String',self.GUIParameterStruct.disableAllChannelDisplaysButtonText,...
                                                                'FontSize',self.GUIParameterStruct.fontSize,...
                                                                'Callback',{@self.disableAllChannelDisplays}...
                                                               );
                                                           
                self.pauseButton = uicontrol(...
                                             self.channelPanel,...
                                             'Style','Togglebutton',...
                                             'Value',self.isPaused,...
                                             'Units','Normalized',...
                                             'String',self.GUIParameterStruct.pauseButtonText.UNPAUSED,...
                                             'FontSize',self.GUIParameterStruct.fontSize,...
                                             'Callback',{@self.pauseDisplay}...
                                            );

                % Create the data axes.
                self.displayAxes = axes(...
                                        'Parent',self.frame,...
                                        'Units','Normalized',...
                                        'FontSize',self.GUIParameterStruct.fontSize...
                                       );
                                   
                % Update the display axes.
                self.updateAxes();

                % Maximise GUI window/frame. If JavaFrame is obsoleted, 
                %this code can be removed and the user can manually maximize 
                %the window.
                 drawnow;
                 f = get(handle(self.frame),'JavaFrame'); 
                 f.setMaximized(true);


            end
            
        end
        
        %% function stop(self)
        % Operation: Destroys GUI window/frame and elements.
        % Input variables: N/A
        % Output variables: N/A
        function stop(self)
            
            if self.isStarted();
                
                % Destroy window/frame.
                close(self.frame);
            end
            
        end
        
        %% function continueSession(self)
        % Operation: Executed when continueSession button is pressed.
        % Input variables: N/A
        % Output variables: N/A
        function continueSession(self)
            
            if self.isStarted();
                
                % Destroy window/frame.
                close(self.frame);
                self.displayMode = 0;
            end            
            
        end
        
        %% started = isStarted(self)
        % Operation: Destroys GUI window/frame and elements.
        % Input variables: N/A
        % Output variables:
        %   > started - boolean scalar; determines if the GUI window exists.
        function started = isStarted(self)
            
            %Check if self.frame is a graphics handle. Note that the if
            %statement is necessary because if self.frame is empty,
            %ishandle will return an empty array.
            if ishandle(self.frame)
                started = 1;
            
            else
                started = 0;
            end
            
        end
        
        %% function mode = getDisplayMode(self)
        % Operation: Returns the mode of the GUI. The mode is a numeral that denotes the type of data that is to be displayed by the GUI.
        % Input variables: N/A
        % Output variables:
        %   > mode - integer scalar; denotes the type of data that is to be displayed by the GUI.
        function mode = getDisplayMode(self)
            
            mode = self.displayMode;
            
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
            
            newChannelNames = fliplr(newChannelNames);
           
            if  ~isequal([self.channelNames{:}],[newChannelNames{:}])
            
                % If all of the above asserts are successful and the channel names are differents, set the value of channelNames to newChannelNames.
                self.channelNames = newChannelNames;

                % Reset channel info.
                self.channelStatuses = ones(1,length(self.channelNames));
                self.channelDisplays = true(1,length(self.channelNames));
                self.dataBuffer = zeros(0,length(self.channelNames) + 1);
                self.dataBufferZeroPointer = 0;
                self.pauseBuffer = zeros(0,length(self.channelNames) + 1);
                self.pauseBufferZeroPointer = 0;

                % Check if the GUI window/frame exists.
                if self.isStarted();

                    % Redraw the GUI.
                    self.stop();
                    self.start();  %It doesn't appear to have started?

                end
            
            end
            
        end
        
        %% function setSampleRate(self,newSampleRate)
        % Operation: Changes the names of the channels for which data is to be displayed.
        % Input variables:
        %   > newSampleRate - double scalar; number of samples of data to be displayed per second.
        % Output variables: N/A
        function setSampleRate(self,newSampleRate)
            
            assert(isa(newSampleRate,'double')); % Assert that newSampleRate is a double type.
            assert(isscalar(newSampleRate)); % Assert that newSampleRate is a double scalar.
            assert(0 < newSampleRate && newSampleRate < Inf); % Assert that newSampleRate is positive and finite.
            
            % If all of the above asserts are successful, set the value of sampleRate to newSampleRate.
            self.sampleRate = newSampleRate;
            
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
            
            % If all of the above asserts are successful, set the value of self.channelStatuses to channelStatuses.
            self.channelStatuses = fliplr(channelStatuses);
            
            % Update the channel status images.
            for i = 1:length(self.channelNames)
                self.updateStatusImage(i);
            end
            
            % Update the display axes.
            self.updateAxes();
            
        end
        
        %% function addData(self,data)
        % Operation: Adds the specified data to the buffer of data to be displayed.
        % Input variables:
        %   > data - [M,N] double matrix; new data to be added to the buffer of data to be displayed.
        % Output variables: N/A
        function addData(self,newData)
            
            assert(isa(newData,'double')); % Assert that data is a double type.
            assert(ismatrix(newData)); % Assert that data is a {0,1,2} dimensional cell matrix.
            assert(size(newData,2) == length(self.channelNames)); % Assert that data is a [M,N] matrix, for any M and such that N is the number of channels.
            
            % If all of the above asserts are successful, get the maximum value for the buffer size, in seconds.
            bufferLimit = max(self.GUIParameterStruct.xAxisScaleValues);
            
            % Flip the data.
            newData = fliplr(newData);
            
            % Add the data to the data buffer.
            if size(self.dataBuffer,1) == 0
                
                timestampData = transpose([0:(size(newData,1) - 1)]);
                timestampData = (timestampData / self.sampleRate);
                self.dataBufferZeroPointer = 1;
                
            else
                
                timestampData = transpose([1:size(newData,1)]);
                timestampData = (timestampData / self.sampleRate) + self.dataBuffer(end,1);
                
            end
            newData = [timestampData,newData];
            self.dataBuffer = [self.dataBuffer;newData];
            
            % If the data exceeds the buffer limit...
            if self.dataBuffer(end,1) > bufferLimit
                
                % Iterate backwards over the data, from the last to the first element.
                % For each element in this iteration, subtract the buffer limit from the time stamp data.
                % When the first element to not exceed the buffer limit is reached, set the data buffer zero pointer to the index of that element plus one, and then terminate the loop.
                index = size(self.dataBuffer,1);
                loop = true;
                while loop
                    
                    % If the index is less than 1, terminate the loop.
                    if index < 1
                        
                        loop = false;
                        
                    else
                        
                        % Check if the current element exceeds the buffer limit.
                        if self.dataBuffer(index,1) > bufferLimit

                            % Subtract the buffer limit from the time stamp data.
                            self.dataBuffer(index,1) = self.dataBuffer(index,1) - bufferLimit;
                            
                            index = index - 1;

                        else

                            % Set the data buffer zero pointer to the index of that element plus one, and then terminate the loop.
                            self.dataBufferZeroPointer = index + 1;
                            loop = false;

                        end
                        
                    end
                    
                    
                end
                
            end
            
            % Iterate backwards over the data, from the zero pointer to the first element.
            % If the time stamp data of the respective elements is less than the time stamp data of the last element, remove that element from the data.
            % If the zero pointer is reached, terminate the loop.
            index = self.dataBufferZeroPointer - 1;
            loop = true;
            lowerBound = 1;
            while loop
                
                % If the index is less than 1, terminate the loop.
                if index < 1

                    loop = false;
                    
                else
                    
                    if self.dataBuffer(index,1) < self.dataBuffer(end,1)
                    
                        lowerBound = index + 1;
                        loop = false;
                        
                    else
                        
                        index = index - 1;

                    end

                end
                
            end
            self.dataBufferZeroPointer = self.dataBufferZeroPointer - lowerBound + 1;
            indices = [lowerBound:size(self.dataBuffer,1)];
            self.dataBuffer = self.dataBuffer(indices,:);
            
            % Update the display axes.
            self.updateAxes();
            
        end
        
    end
    
    methods ( Access = private )
        
        %% function resize(self,~,~)
        % Operation: If the GUI window/frame exists, resets the positions of all its elements.
        % Input variables: N/A
        % Output variables: N/A
        function resize(self,~,~)
            
            % Check if the GUI window/frame exists.
            if self.isStarted();
                
                % Resize menu panel elements.
                set(self.menuPanel,'Position',self.GUIParameterStruct.menuPanelRect);
                set(self.modeTitleLabel,'Position',self.GUIParameterStruct.modeTitleRect);
                set(self.xAxisScaleTitleLabel,'Position',self.GUIParameterStruct.xAxisScaleTitleRect);
                set(self.yAxisScaleTitleLabel,'Position',self.GUIParameterStruct.yAxisScaleTitleRect);
                set(self.modeMenu,'Position',self.GUIParameterStruct.modeMenuRect);
                set(self.xAxisScaleMenu,'Position',self.GUIParameterStruct.xAxisScaleMenuRect);
                set(self.yAxisScaleMenu,'Position',self.GUIParameterStruct.yAxisScaleMenuRect);
                
                % Resize channel panel elements.
                set(self.channelPanel,'Position',self.GUIParameterStruct.channelPanelRect);
                set(self.channelNameTitleLabel,'Position',self.GUIParameterStruct.channelNameTitleRect);
                set(self.channelToggleDisplayTitleLabel,'Position',self.GUIParameterStruct.channelToggleDisplayTitleRect);
                set(self.channelStatusTitleLabel,'Position',self.GUIParameterStruct.channelStatusTitleRect);
                
                % Resize each of the channel panel list elements, using standardised spacing.
                for i = 1:length(self.channelNames);
                    
                    set(...
                        self.channelNameLabels(i),...
                        'Position',[...
                                    self.GUIParameterStruct.channelNamesLabelsRect(1),...
                                    (self.GUIParameterStruct.channelNamesLabelsRect(2) + (1 / 8) * (self.GUIParameterStruct.channelNamesLabelsRect(4) / length(self.channelNames)) + ((i - 1) * self.GUIParameterStruct.channelNamesLabelsRect(4) / length(self.channelNames))),...
                                    self.GUIParameterStruct.channelNamesLabelsRect(3),...
                                    (3 / 4) * (self.GUIParameterStruct.channelNamesLabelsRect(4) / length(self.channelNames))...
                                   ]...
                       );
                    
                    
                    set(...
                        self.channelToggleDisplayButtons(i),...
                        'Position',[...
                                    self.GUIParameterStruct.channelToggleDisplayButtonsRect(1),...
                                    (self.GUIParameterStruct.channelToggleDisplayButtonsRect(2) + (1 / 8) * (self.GUIParameterStruct.channelToggleDisplayButtonsRect(4) / length(self.channelNames)) + ((i - 1) * self.GUIParameterStruct.channelToggleDisplayButtonsRect(4) / length(self.channelNames))),...
                                    self.GUIParameterStruct.channelToggleDisplayButtonsRect(3),...
                                    (3 / 4) * (self.GUIParameterStruct.channelToggleDisplayButtonsRect(4) / length(self.channelNames))...
                                   ]...
                       );
                    
                    set(...
                        self.channelStatusImages(i),...
                        'Position',[...
                                    self.GUIParameterStruct.channelStatusImagesRect(1),...
                                    (self.GUIParameterStruct.channelStatusImagesRect(2) + (1 / 8) * (self.GUIParameterStruct.channelStatusImagesRect(4) / length(self.channelNames)) + ((i - 1) * self.GUIParameterStruct.channelStatusImagesRect(4) / length(self.channelNames))),...
                                    self.GUIParameterStruct.channelStatusImagesRect(3),...
                                    (3 / 4) * (self.GUIParameterStruct.channelStatusImagesRect(4) / length(self.channelNames))...
                                   ]...
                       );
                   
                end
                
                % Resize the macro-control buttons.
                set(self.enableAllChannelDisplaysButton,'Position',self.GUIParameterStruct.enableAllChannelDisplaysButtonRect);
                set(self.disableAllChannelDisplaysButton,'Position',self.GUIParameterStruct.disableAllChannelDisplaysButtonRect);
                set(self.pauseButton,'Position',self.GUIParameterStruct.pauseButtonRect);
                
                % Resize display axes.
                set(self.displayAxes,'Position',self.GUIParameterStruct.displayAxesRect);
%                 self.updateAxes();
                
            end
            
        end
        
        %% function toggleChannelDisplay(self,~,~,channel)
        % Operation: Callback function for the buttons that control the channels to be displayed.
        % Input variables:
        %   > channel - integer scalar; index of the channel to be toggled.
        % Output variables: N/A
        function toggleChannelDisplay(self,~,~,channel)
            
            if self.isStarted();
            
                self.channelDisplays(channel) = ~self.channelDisplays(channel);
            
            end
            
            % Update the display axes.
            self.updateAxes();
            
        end
        
        %% function enableAllChannelDisplays(self,~,~)
        % Operation: Callback function for the button that causes all of the channels to be displayed.
        % Input variables: N/A
        % Output variables: N/A
        function enableAllChannelDisplays(self,~,~)
            
            if self.isStarted();
            
                set(self.channelToggleDisplayButtons(:),'Value',true);
                self.channelDisplays(:) = true;
            
            end
            
            % Update the display axes.
            self.updateAxes();
            
        end
        
        %% function disableAllChannelDisplays(self,~,~)
        % Operation: Callback function for the button that causes none of the channels to be displayed.
        % Input variables: N/A
        % Output variables: N/A
        function disableAllChannelDisplays(self,~,~)
            
            if self.isStarted();
            
                set(self.channelToggleDisplayButtons(:),'Value',false);
                self.channelDisplays(:) = false;
            
            end
            
            % Update the display axes.
            self.updateAxes();
            
        end
        
        %% function updateStatusImage(self,channel)
        % Operation: Update the channel status image.
        % Input variables:
        %   > channel - integer scalar; index of the channel status image to change.
        % Output variables: N/A
        function updateStatusImage(self,channel)
            
            % Check if the GUI window/frame exists.
            if self.isStarted();
                
                % Update the channel status image.
                if self.channelStatuses(channel) > 0.5
                    
                    set(self.channelStatusImages(channel),'BackgroundColor',[(1 - self.channelStatuses(channel)) * 2,1,0]);
                
                elseif self.channelStatuses(channel) < 0.5
                    
                    set(self.channelStatusImages(channel),'BackgroundColor',[1,self.channelStatuses(channel) * 2,0]);
                    
                else %self.channelStatuses(channel) == 0.5
                    
                    set(self.channelStatusImages(channel),'BackgroundColor',[1,1,0]);
                    
                end
                
            end
            
        end
        
        %% function pauseDisplay(self,~,~)
        % Operation: Callback function for the pause button.
        % Input variables: N/A
        % Output variables: N/A
        function pauseDisplay(self,~,~)
            
            if self.isStarted();
            
                self.isPaused = ~self.isPaused;
                if get(self.pauseButton,'Value');

                    set(self.pauseButton,'String',self.GUIParameterStruct.pauseButtonText.PAUSED);
                    self.pauseBuffer = self.dataBuffer;
                    self.pauseBufferZeroPointer = self.dataBufferZeroPointer;

                else

                    set(self.pauseButton,'String',self.GUIParameterStruct.pauseButtonText.UNPAUSED);
                    self.pauseBuffer = [];
                    self.pauseBufferZeroPointer = 0;

                end
                
                % Update the display axes.
                self.updateAxes();
            
            end
            
        end
        
        %%function updateDisplayMode(self,~,~)
        % Operation: Update the display mode.
        % Input variables: N/A
        % Output variables: N/A
        function updateDisplayMode(self,~,~)
            
            self.displayMode = get(self.modeMenu,'Value');
            
            set(...
                self.xAxisScaleMenu,...
                'String',cellfun(@(array)([num2str(array),' ',self.GUIParameterStruct.xAxisUnit]),num2cell(self.GUIParameterStruct.xAxisScaleValues), 'UniformOutput', false),...
                'Value',self.xScaleIndex...
               );
           
           set(...
                self.yAxisScaleMenu,...
                'String',cellfun(@(array)([num2str(array),' ',self.GUIParameterStruct.yAxisUnit{self.displayMode}]),num2cell(self.GUIParameterStruct.yAxisScaleValues{self.displayMode}), 'UniformOutput', false),...
                'Value',self.yScaleIndices(self.displayMode)...
               );
            
        end
        
        %%function updateAxes(self,~,~)
        % Operation: Update the data plots on the display axes.
        % Input variables: N/A
        % Output variables: N/A
        function updateAxes(self,~,~)
            
            if self.isStarted();
            
                % Get the axes scaling indices.
                self.xScaleIndex = get(self.xAxisScaleMenu,'Value');
                self.yScaleIndices(self.displayMode) = get(self.yAxisScaleMenu,'Value');
                
                % Get the axes scaling values.
                xScale = self.GUIParameterStruct.xAxisScaleValues(self.xScaleIndex);
                yScale = self.GUIParameterStruct.yAxisScaleValues{self.displayMode}(self.yScaleIndices(self.displayMode)) * self.GUIParameterStruct.yAxisScaleMultipier(self.displayMode);
                
                % Check if there is data to be displayed.
                if size(self.dataBuffer,1) > 0

                    % Build the matrix of data to be displayed.
                    if get(self.pauseButton,'Value');

                        displayDataSource = self.pauseBuffer;

                    else

                        displayDataSource = self.dataBuffer;

                    end
                    
                    % Ensure that the display data is in chronological order.
                    currentTime = displayDataSource(end,1);
                    [~,indices] = sort(displayDataSource(:,1));
                    displayDataSource = displayDataSource(indices,:);

                    % Calculate the range of the x values of the new display data.
                    newXMax = currentTime;
                    newXMin = newXMax - mod(newXMax,xScale);
                    
                    % Curtail data to range of x values of the new display data.
                    newDisplayIndices = and((newXMin <= displayDataSource(:,1)),(displayDataSource(:,1) < newXMax));
                    newDisplayData = displayDataSource(newDisplayIndices,:);
                    newDisplayData(:,1) = newDisplayData(:,1) - newXMin;

                    % Calculate the range of the x values of the existing display data.
                    if newXMin == 0
                        
                        existingXMax = max(self.GUIParameterStruct.xAxisScaleValues);
                        
                    else
                        
                        existingXMax = newXMin;
                        
                    end
                    existingXMin = existingXMax - xScale + mod(newXMax,xScale);
                    
                    % Curtail data to range of x values of the existing display data.
                    existingDisplayIndices = and((existingXMin <= displayDataSource(:,1)),(displayDataSource(:,1) < existingXMax));
                    existingDisplayData = displayDataSource(existingDisplayIndices,:);
                    existingDisplayData(:,1) = existingDisplayData(:,1) - existingXMin + mod(newXMax,xScale);
                    
                    % Create the dataset to be rendered.
                    displayData = [newDisplayData;existingDisplayData];
                    [~,indices] = sort(displayData(:,1));
                    displayData = displayData(indices,:);
                    
                    % Curtail data to plots that are to be displayed.
                    newDisplayIndices = [true,self.channelDisplays];
                    displayData = displayData(:,newDisplayIndices);
                    
                    % Scale, recenter, and distribute data over the y axis.
                    displayData(:,2:end) = displayData(:,2:end) / yScale; % Scaling.
                    displayData(:,2:end) = displayData(:,2:end) + 0.5; % Centering data at 0.5.
                    displacement = repmat([0,0:(size(displayData,2)-2)],size(displayData,1),1); % Distribution requires that the y values from any two channels (N) and (N+1) have a difference of 1 between them.
                    displayData = displayData + displacement; % Distributing.

                    % Check if there is data to plot.
                    if size(displayData,2) > 1
                        
                        % Plot data.
                        plot(...
                             self.displayAxes,...
                             displayData(:,1),...
                             displayData(:,2:end)...
                            );
                        line(...
                             [mod(currentTime,xScale),mod(currentTime,xScale)],...
                             [0,sum(self.channelDisplays)],...
                             'Parent',self.displayAxes,...
                             'Color','r'...
                            );
                        
                    else
                        
                        % Clear axes.
                        cla(self.displayAxes);
                        
                    end

                end
                
                % Set plot axes.
                xlim(self.displayAxes,[0,xScale]);
                ylim(self.displayAxes,[0,max(sum(self.channelDisplays),1)]);
                set(self.displayAxes,'YTick',([1:sum(self.channelDisplays)] - 0.5));
                set(self.displayAxes,'YTickLabel',self.channelNames(self.channelDisplays));
                xlabel(...
                       self.displayAxes,...
                       self.GUIParameterStruct.xAxisLabel,...
                       'FontSize',self.GUIParameterStruct.fontSize...
                      );
                ylabel(...
                       self.displayAxes,...
                       self.GUIParameterStruct.yAxisLabel,...
                       'FontSize',self.GUIParameterStruct.fontSize...
                      );
            
            end
            
        end
        
    end
    
end