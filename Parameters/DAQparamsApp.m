% all parameters necessary to run daq.  See also daqManager and its
% subclasses gUSBmanager and noAmpManager

%% ================================ Basic =================================
% Type of DAQ connected to computer: 'gUSBAmp' or 'noAmp'.  Both have
% ability to start/stop acquisition and get data.  noAmp's data is
% arbitrary gaussian (for testing without amplifier)
daqType = 'gUSBAmp';

% cell of channel names (almost exclusively for record keeping and setup
% instructions)
channelNames = {'Oz', 'O1', 'O2'};
% channelNames = {'left_v-','left_v+','both_h+','left_h-','right_v-','right_v+','right_h-'};
% channelNames = {'Oz'};

% [numChannels x 1], active channels, eg 1,2,4,6 omits the 3 and 5th chan
channelList = 1 : length(channelNames);

% frontEndFilterFlag enables filtering of data in testing modes (causes no
% change in non-testing modes)
frontEndFilterFlag = false;

% Sampling Frequency of EEG data
fs = 256;           

% calibrationFlag enables calibration of the amps. If disabled, amplifiers
% will initialize quicker but may contain unusal offsets or scales.
% (recommended on)
calibrationFlag = false;

% ampBufferLengthSec is the buffer length (in sec) of the data acquisition
% toolbox. If set to 'Inf' the data acquisition toolbox continually
% acquires data.
ampBufferLengthSec = Inf;


%% ================================ Filter ================================
% Filter indices for using built-in amplifier filters, -1 toggles each off
ampFilterNdx = -1; 
notchFilterNdx = 3; 

%     Valid Bandpass Filters for 256 Hz:
%     Filter:	HP:		LP:		Order:	Type:
%     __________________________________________
%     32		0.10	0.00	8		butter
%     33		1.00	0.00	8		butter
%     34		2.00	0.00	8		butter
%     35		5.00	0.00	8		butter
%     36		0.00	30.00	8		butter
%     37		0.00	60.00	8		butter
%     38		0.00	100.00	8		butter
%     39		0.01	30.00	6		butter
%     40		0.01	60.00	8		butter
%     41		0.01	100.00	8		butter
%     42		0.10	30.00	8		butter
%     43		0.10	60.00	8		butter
%     44		0.10	100.00	8		butter
%     45		0.50	30.00	8		butter
%     46		0.50	60.00	8		butter
%     47		0.50	100.00	8		butter
%     48		2.00	30.00	8		butter
%     49		2.00	60.00	8		butter
%     50		2.00	100.00	8		butter
%     51		5.00	30.00	8		butter
%     52		5.00	60.00	8		butter
%     53		5.00	100.00	8		butter
% 
%     Valid Notch Filters for 256 Hz:
%     Filter:	HP:		LP:		Order:	Type:
%     __________________________________________
%     2		48.00	52.00	4		butter
%     3		58.00	62.00	4		butter
%
% To find filter indices for other sample rate - use gUSBampShowFilter(fs)