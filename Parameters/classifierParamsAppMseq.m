%% ================================= CCA ==================================
% numHarmonics is a scalar number of harmonics to used to make the CCA
% target template.  It is traditionally set to 1 or 2.
DimReductCCAMeanObj = DimReductCCA('mode', 'mean');
DimReductCCAMedianObj = DimReductCCA('mode', 'median');


%% Correlation
DimReductCorrMeanObj = DimReductCorrelation(...
    'mode', 'mean', ...
    'aveDim', 3);
DimReductCorrMedianObj = DimReductCorrelation(...
    'mode', 'median', ...
    'aveDim', 3);

%% ============================= DimReductSeq =============================
classifierLabel{1} = 'mean-corr-KDE';
DimReductSequence{1} = {DimReductCorrMeanObj};

classifierLabel{2} = 'median-corr-KDE';
DimReductSequence{2} = {DimReductCorrMedianObj};
% 
% classifierLabel{3} = 'mean-CCA-KDE';
% DimReductSequence{3} = {DimReductCCAMeanObj};
% 
% classifierLabel{4} = 'median-CCA-KDE';
% DimReductSequence{4} = {DimReductCCAMedianObj};


%% ============================= Classifiers ==============================
numClasses = length(stimSSVEPObj.stimStruct);
prior = ones(numClasses, 1) / numClasses;

numClassifiers = length(DimReductSequence);
for idx = numClassifiers : -1 : 1
    classifierObj{idx} = ClassifierKDE(...
        'dimReductSequence',DimReductSequence{idx},...
        'k',kFoldk,...
        'prior',prior);
end

