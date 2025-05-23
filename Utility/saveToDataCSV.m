filename = 'allData.mat';
path = which(filename);

%allData.csv not found, make one
if isempty(path)
    targetFile = 'sessionSpeller.m';
    path = which(targetFile);
    path(end-length(targetFile)+1:end) = '';
    % assumes windows ...
    path = [path, 'Data\'];
    
    % row 1: save folder
    % row 2: copy phrase idx
    % row 3: target string
    % row 4: acc
    % row 5: time (sec)
    T = table;
else
    load(path);
    path = path(1: end - length(filename));
end

% collect data
numCp = length(copyPhraseObj);
trialLengthSec = stimLengthSec + timePostAssoc + timePreAssoc + timeBarAnim * barGraphFlag;
clear meanDecTime
for cpIdx = numCp : -1 : 1
    if isempty(copyPhraseObj(cpIdx).msgTarget)
        % free spell
        targetStr{cpIdx} = '';
    else
        % copy phrase
        targetStr{cpIdx} = [copyPhraseObj(cpIdx).msgTarget.str];
    end
   numDec = length(copyPhraseObj(cpIdx).decSeqVec(:));
   if ~numDec || isempty(copyPhraseObj(cpIdx).decSeqVec(1).probY)
       typedStr{cpIdx} = '';
       charAcc{cpIdx} = nan;
       meanDecTime{cpIdx} = nan;
       meanTrialsPerDec{cpIdx} = nan;
       numChar{cpIdx} = 0;
   else
       tempTypedStr = dictAlpha.Convert([copyPhraseObj(cpIdx).decSeqVec(:).msgIdxEstimate]);
       if ~isempty(tempTypedStr)
           tempTypedStr = [tempTypedStr.str];
           tempTypedStr(tempTypedStr == char(8)) = '<';
           typedStr{cpIdx} = tempTypedStr;
       else
           typedStr{cpIdx} = '';
       end
       correct = [copyPhraseObj(cpIdx).decSeqVec(:).correct];
       numTrials = [];
       for charIdx = length(correct) : -1 : 1
           numTrials(charIdx) = size(copyPhraseObj(cpIdx).decSeqVec(charIdx).probY, 2);
           if isempty(copyPhraseObj(cpIdx).decSeqVec(charIdx).probY)
               % auto typed, don't count towards correct
              correct(charIdx) = []; 
           end
       end
       charAcc{cpIdx} = mean(correct);
       meanTrialsPerDec{cpIdx} = mean(numTrials);
       meanDecTime{cpIdx} = trialLengthSec * meanTrialsPerDec{cpIdx};
       numChar{cpIdx} = length(correct);
   end
end
cpIdx = 1 : numCp;

if ~exist('copyPhraseIdx') %#ok<EXIST>
    copyPhraseSetIdx = 'none';
end

% build new table, concatenate, see readme_allData.txt
% NOTE: we keep cells for charAcc and numChar in case per copy phrase data
% is needed in a future version.
numCharsPerCP = [numChar{:}];
w = numCharsPerCP / sum(numCharsPerCP);

T_new = table;
pathSplit = strsplit(saveFolder, '\');
T_new.calibID = {pathSplit{end-3}};
T_new.sessionType = {sessionID};
T_new.date = {date};
T_new.staffInitials = {staffInitials};
T_new.sessionNumber = sessionNumber;
meanDecTime = sum(w .* [meanDecTime{:}], 'omitnan');
T_new.meanDecTime = meanDecTime;
T_new.expITR = perfMetric.ITR;
T_new.copyPhraseIdx = copyPhraseSetIdx;
temp = sum([copyPhraseObj(:).status]);
T_new.copyPhraseStatus = {temp.str};
T_new.charAcc = sum(w .* [charAcc{:}], 'omitnan');
T_new.numChar = sum(numCharsPerCP);
T_new.meanTrialsPerDec = sum([meanTrialsPerDec{:}] .* w, 'omitnan');
T_new.trialLengthSec = trialLengthSec;
% weighted by numChar
T_new.numCharPerMin = 60 / meanDecTime;
T_new.rawDataPath = {saveFolder};

T = vertcat(T, T_new);

% save to mat and csv
save([path, filename], 'T');
csvPath = [path, 'allData.csv'];
writetable(T, csvPath);