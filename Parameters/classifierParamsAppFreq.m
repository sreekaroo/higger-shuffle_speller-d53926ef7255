%% ================================= CCA ==================================
% numHarmonics is a scalar number of harmonics to used to make the CCA
% target template.  It is traditionally set to 1 or 2.
numHarmonics = 2;

DimReductCCAObj = DimReductCCA(...
    'targetFreq', stimSSVEPObj.freq,...
    'fs',fs,...
    'numHarmonics',numHarmonics);


%% ================================= PSD ==================================
% PSDcenterFreq is a [lowDim x 1] vector of center frequencies of the
% bandpass filters, most often in SSVEP they are chosen as the target
% frequencies
PSDcenterFreq = stimSSVEPObj.freq;

% bandwidthHz is a scalar of the width of the pass band.  The stop band is
% twice the pass band's width
bandwidthHz = 1;

% minSignalLengthSec is a scalar, the bandpass filters suppess the stop
% band as much as possible without zero padding the signal. to ensure this,
% we impose that all signals have some minSignalLengthSec. effectively this
% means: filterOrder = floor(fs*minSignalLength).  This feature was
% introduced to allow for classification of multiple length signals, though
% in practice one should choose the maximum minimal length of a trial for
% best suppression
minSignalLengthSec = .8;

% scalar, dimension of inputData to filter along, this is the "time"
% dimension of a trial
filterDim = 2;

% vector, dimensions to average across before outputting lower dimensional
% data.  This feature was inroduced to heuristically incorporate multiple
% channels in a PSD classifier.
meanDim = 1;

% DimReductPowerSpecObj = DimReductPowerSpec(PSDcenterFreq,fs,...
%     'minSignalLength',minSignalLengthSec,...
%     'bandwidthHz',bandwidthHz,...
%     'filterDim',filterDim,...
%     'meanDim',meanDim);

%% ================================= LDA ==================================
DimReductLDAObj = DimReductLDA('prior','uniform');

%% ============================= DimReductSeq =============================
% DimReductSequence{1} = {};

DimReductSequence{2} = {DimReductCCAObj};

% DimReductSequence{3} = {DimReductPowerSpecObj};
% 
% DimReductSequence{4} = {DimReductCCAObj, DimReductLDAObj};
% 
% DimReductSequence{5} = {DimReductPowerSpecObj,DimReductLDAObj};


%% ============================= Classifiers ==============================
numClasses = length(stimSSVEPObj.freq);
prior = ones(numClasses, 1) / numClasses;

classifierLabel{1} = 'CCA-KDE';
classifierObj{1} = ClassifierKDE(...
    'dimReductSequence',DimReductSequence{2},...
    'k',kFoldk,...
    'prior',prior);

% classifierLabel{2} = 'PSD-KDE';
% classifierObj{2} = ClassifierKDE(...
%     'dimReductSequence',DimReductSequence{3},...
%     'k',kFoldk,...
%     'prior',prior);

% classifierLabel{3} = 'CCA-LDA-KDE';
% classifierObj{3} = ClassifierKDE(...
%     'dimReductSequence',DimReductSequence{4},...
%     'k',kFoldk,...
%     'prior',prior);
% 
% classifierLabel{4} = 'PSD-LDA-KDE';
% classifierObj{4} = ClassifierKDE(...
%     'dimReductSequence',DimReductSequence{5},...
%     'k',kFoldk,...
%     'prior',prior);

