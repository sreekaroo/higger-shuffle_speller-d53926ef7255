%% [rawData, triggerSignal, sampleRate, channelList, daqInfo, filterInfo] = loadSessionData(varargin)
%  Loads data recorded by gUsbAmp using CSL daq library.
%
%   Inputs:
%            'daqFileName'    -	 Full path filename of .bin file with data.
%                                If empty, a dialog box will be open at
%                                location provided by sessionFolder
%            'sessionFolder'  -  Path to location where mat file will be stored
%            'saveMatFileFlag -  true if output of function is to be stored in a mat file   
%
%   Outputs:
%           rawData         -   A matrix containing the eeg data. Each column
%                               corresponds to a different channel.
%           triggerSignal   -   A vector containing the trigger data.
%           sampleRate      -   The sampling frequency in Hz.
%           channelList     -   A vector containing the channel names used in the experiment.
%           daqInfo         -   A structure containing the information about the
%                               data acquisiton file.
%                .version           -    Version of file   
%           filterInfo      -   A structure containing the information about the
%                               filter used in the amplifiers during the data acquisition. The
%                               followings are the elements of this structure.
%                .filterInfo.BPLow  -    The lower cut off frequency of the
%                                        bandpass filter.
%                .filterInfo.BPHigh -    The higher cutoff frequency of the
%                                        bandpass filter.
%                .filterInfo.Notch  -    The frequency of the notch filter.            
%
% The daq file is a custom binary file with format defined below
%   
%  V1.0:
%       Daq version     (int32) [1]  1 for version 1                              
%       SampleRate      (int32) [1]  Sample rate in Hz
%       nChannels       (uint8) [1]  Number of channels
%       trigger         (int32) [1]  1 if trigger was enabled, 0 otherwise
%       channelList     (int32) [1 x nChannels] 
%                                    Vector with channel list
%       recordedData    (float32) [(nChannels+trigger) x nSamples] 
%                                    Data from file. The samples from channels and trigger are
%                                    sequential i.e. sample1_ch1,...,sample1_chN, sample1_trig, sample2_ch1, ... 

function [rawData, triggerSignal, sampleRate, channelList, daqInfo, filterInfo, sessionFolder] = loadSessionDataBin(varargin)

% input parser
p = inputParser;
p.addParameter('daqFileName',[],@isstr);
p.addParameter('sessionFolder',[],@isstr);
p.addParameter('saveMatFileFlag',false, @islogical);
p.parse(varargin{:});
    
% Query user about data location if not given in daqFileList
if isempty(p.Results.daqFileName)
    [daqFileName, sessionFolder] = uigetfile(fullfile(p.Results.sessionFolder, ['*.*']),...
                                   'Please select the data recording files');
                               
    if daqFileName == 0
        error('No file was selected');
    end
    daqFileFolder = sessionFolder;
    [~, daqFileName, daqFileExtension] = fileparts(daqFileName);
else
    % else, remove "p.Results" for readability
    [daqFileFolder, daqFileName, daqFileExtension] = fileparts(p.Results.daqFileName);
    sessionFolder = p.Results.sessionFolder;
end

daqType = daqFileExtension;

%% Obtaining information about the amplfiers and data acquisition set up
if ~exist(fullfile(daqFileFolder, [daqFileName, daqFileExtension]), 'file')
    error(['File ' fullfile(daqFileFolder, [daqFileName, daqFileExtension]) ' not found']);
end

switch daqType 
    
    case '.bin'

        fid = fopen(fullfile(daqFileFolder, [daqFileName, daqFileExtension]), 'rb');

        daqInfo.version = double(fread(fid, 1, 'int32'));
        sampleRate = double(fread(fid, 1, 'int32'));
        nChannels = double(fread(fid, 1, 'uint8'));
        triggerFlag = double(fread(fid, 1, 'int32'));
        channelList = double(fread(fid, nChannels, 'uint8'));

        % Data is arranged sequentially, one sample from each channel at a time
        % i.e sample1_ch1,...,sample1_chN, sample1_trig, sample2_ch1, ... 
        dataBuffer = double(fread(fid, [(nChannels + triggerFlag) Inf], 'float32'));
        fclose(fid);

        % scale to volts
        rawData = (1e-6)*dataBuffer(1:end-triggerFlag,:).';

        % Trigger signal is "last channel" of data buffer
        if triggerFlag
            triggerSignal =  dataBuffer(end,:).';
        else
            triggerSignal = [];
        end

        % Not yet implemented
        filterInfo = [];
        
    case '.csv'
        nChannels = 24;
        fileID = fopen(fullfile(daqFileFolder, [daqFileName, daqFileExtension]));
        header = textscan(fileID, '%s %s', 2, 'delimiter', ',');
        sampleRate = str2double(header{2}{2});
        channelList = textscan(fileID, repmat('%s ',1, nChannels), 1, 'delimiter', ',');
        channelList = [channelList{:}];
        fclose(fileID);

        rawData = csvread(fullfile(daqFileFolder, [daqFileName, daqFileExtension]), 3, 0);
        triggerSignal = rawData(:,end);
        rawData = (1e-6)*rawData(:,1:end-1);

        filterInfo = [];
        daqInfo.daqType = 'dsi';        
        
    otherwise
        
        error('not implemented')
        
end

%% Save to mat file
% save('/Users/srikarananthoju/cambi/data/temp/temp.mat', 'rawData', 'triggerSignal', 'sampleRate', 'channelList', 'filterInfo', 'daqInfo');

% save(fullfile(sessionFolder , [daqFileName '.mat']), 'rawData','triggerSignal','sampleRate','channelList','filterInfo','daqInfo');
end