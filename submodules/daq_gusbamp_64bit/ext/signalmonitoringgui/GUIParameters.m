%% GUI Layout.
% Expressed in percentage of the window/frame.
% [left,bottom,width,height]
GUIParameterStruct.menuPanelRect = [0,0.9,1,0.075];
GUIParameterStruct.channelPanelRect = [0,0,0.2,0.9];
GUIParameterStruct.displayAxesRect = [0.25,0.09,0.7,0.72];

% Expressed in percentage of the menu panel.
% [left,bottom,width,height]
GUIParameterStruct.modeTitleRect = [0.025,0.5,(1/3)-0.05,0.5];
GUIParameterStruct.xAxisScaleTitleRect = [(1/3)+0.025,0.5,(1/3)-0.05,0.5];
GUIParameterStruct.yAxisScaleTitleRect = [(2/3)+0.025,0.5,(1/3)-0.05,0.5];
GUIParameterStruct.modeMenuRect = [0.025,0,(1/3)-0.05,0.5];
GUIParameterStruct.xAxisScaleMenuRect = [(1/3)+0.025,0,(1/3)-0.05,0.5];
GUIParameterStruct.yAxisScaleMenuRect = [(2/3)+0.025,0,(1/3)-0.05,0.5];

% Expressed in percentage of the channel panel.
% [left,bottom,width,height]
GUIParameterStruct.channelNameTitleRect = [0.025,0.9,(1/3)-0.05,0.1];
GUIParameterStruct.channelToggleDisplayTitleRect = [(1/3)+0.025,0.9,(1/3)-0.05,0.1];
GUIParameterStruct.channelStatusTitleRect = [(2/3)+0.025,0.9,(1/3)-0.05,0.1];
GUIParameterStruct.channelNamesLabelsRect = [0.025,0.1,(1/3)-0.05,0.8];
GUIParameterStruct.channelToggleDisplayButtonsRect = [(1/3)+0.025,0.1,(1/3)-0.05,0.8];
GUIParameterStruct.channelStatusImagesRect = [(2/3)+0.025,0.1,(1/3)-0.05,0.8];
GUIParameterStruct.enableAllChannelDisplaysButtonRect = [0.025,0.025,(1/3)-0.05,0.05];
GUIParameterStruct.disableAllChannelDisplaysButtonRect = [(1/3)+0.025,0.025,(1/3)-0.05,0.05];
GUIParameterStruct.pauseButtonRect = [(2/3)+0.025,0.025,(1/3)-0.05,0.05];

%% GUI Text.
GUIParameterStruct.fontSize = 12;
GUIParameterStruct.frameTitle = 'Signal Monitor GUI'; % Title of the main frame/window.
GUIParameterStruct.modeTitle = 'Display Mode'; % Title above the menu to select different modes.
GUIParameterStruct.xAxisScaleTitle = 'Select X-Scale (Seconds to display)'; % Title above the menu to select different X scales.
GUIParameterStruct.yAxisScaleTitle = 'Select Y-Scale (Volts / div.)'; % Title above the menu to select different Y scales.
GUIParameterStruct.channelNameTitle = 'Channel Names'; % Title above the list of channel names.
GUIParameterStruct.channelToggleDisplayTitle = 'Toggle Channel Display'; % Title above the list of buttons used to toggle channel display for individual channels.
GUIParameterStruct.channelStatusTitle = 'Channel Status'; % Title above the list of images used to indicate the status of the channels.
GUIParameterStruct.enableAllChannelDisplaysButtonText = 'Enable all'; % Text on the button used to enable all the channels at once.
GUIParameterStruct.disableAllChannelDisplaysButtonText = 'Disable all'; % Text on the button used to disable all the channels at once.
GUIParameterStruct.pauseButtonText.UNPAUSED = 'Pause'; % Text on button used to pause and unpause the display.
GUIParameterStruct.pauseButtonText.PAUSED = 'Unpause'; % Text on button used to pause and unpause the display.

%% GUI Modes.
GUIParameterStruct.modeOptions = {...
                                  'No Data',... % 1
                                  'Raw Data',... % 2
                                  'Filtered Data',... % 3
%                                  'Attention Monitoring Data'... % 4'
                                 }; % Drop down menu options for the menu to select different modes.

GUIParameterStruct.displayModeOptions.NO_DATA = 1; % No data being sent.
GUIParameterStruct.displayModeOptions.RAW_DATA = 2; % Raw data being sent.
GUIParameterStruct.displayModeOptions.FILTERED_DATA = 3; % Filtered data being sent.
GUIParameterStruct.displayModeOptions.AM_DATA = 4;
%% GUI X Scales.
GUIParameterStruct.xAxisLabel = 'Seconds';
GUIParameterStruct.xAxisUnit = 'Seconds';
GUIParameterStruct.xAxisScaleValues = [20,10,5,2];
GUIParameterStruct.xAxisScaleInitialValueIndex = 1;

%% GUI Y Scales.
GUIParameterStruct.yAxisLabel = 'Channel';
GUIParameterStruct.yAxisUnit{1} = '';
GUIParameterStruct.yAxisScaleValues{1} = [0];
GUIParameterStruct.yAxisScaleInitialValueIndices(1) = 1;
GUIParameterStruct.yAxisScaleMultipier(1) = 1;
GUIParameterStruct.yAxisUnit{2} = 'Micro Volts';
GUIParameterStruct.yAxisScaleValues{2} = [1E6,5E5,1E5,5E5,1E4,5E3,1E3,5E2,1E2,5E1,1E1,5E0,1E0];
GUIParameterStruct.yAxisScaleInitialValueIndices(2) = 9;
GUIParameterStruct.yAxisScaleMultipier(2) = 1E-6;
GUIParameterStruct.yAxisUnit{3} = 'Micro Volts';
GUIParameterStruct.yAxisScaleValues{3} = [1E6,5E5,1E5,5E5,1E4,5E3,1E3,5E2,1E2,5E1,1E1,5E0,1E0];
GUIParameterStruct.yAxisScaleInitialValueIndices(3) = 9;
GUIParameterStruct.yAxisScaleMultipier(3) = 1E-6;
GUIParameterStruct.yAxisUnit{4} = '(Micro Volts)²';
GUIParameterStruct.yAxisScaleValues{4} = [1E12,5E11,1E11,5E10,1E10,5E9,1E9,5E8,1E8,5E7,1E7,5E6,1E6];
GUIParameterStruct.yAxisScaleInitialValueIndices(4) = 9;
GUIParameterStruct.yAxisScaleMultipier(4) = 1E-12;