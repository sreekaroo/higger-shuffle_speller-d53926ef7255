function runnerLoadData()
% runnerLoadData Recursively loads EEG data across all subjects
% and sessions in the shuffleSpeller dataset, saving processed outputs.

rootDir = '/Users/srikarananthoju/cambi/data/shuffleSpellerData';
subjectDirs = dir(rootDir);
subjectDirs = subjectDirs([subjectDirs.isdir] & ~startsWith({subjectDirs.name}, '.'));

for i = 1:length(subjectDirs)
    subjPath = fullfile(rootDir, subjectDirs(i).name);
    
    % Find session directories under each subject
    sessionDirs = dir(subjPath);
    sessionDirs = sessionDirs([sessionDirs.isdir] & ~startsWith({sessionDirs.name}, '.'));
    
    for j = 1:length(sessionDirs)
        sessPath = fullfile(subjPath, sessionDirs(j).name);

        % Locate all eeg.bin files within this session folder
        binFiles = dir(fullfile(sessPath, '**', 'eeg.bin'));
        
        if isempty(binFiles)
            warning('Skipping %s (no eeg.bin found)\n', sessPath);
            continue;
        end

        % Process each eeg.bin individually
        for k = 1:numel(binFiles)
            eegFolder = binFiles(k).folder;
            binFilePath = fullfile(eegFolder, 'eeg.bin');
            fprintf('\nProcessing file %d of %d in session: %s\n', k, numel(binFiles), binFilePath);
            
            try
                [inputData, fs, chNames, sessionFolderUsed, trials, pts, numTrials, targetIdx] = ...
                    loadDataShuffleSpeller('sessionFolder', sessPath, 'daqFile', binFilePath);
                
                % Save processed data
                save(fullfile(eegFolder, 'all_data_2.mat'), ...
                    'inputData', 'fs', 'chNames', 'trials', 'pts', 'numTrials', 'targetIdx');

            catch ME
                warning('Failed to process %s:\n%s\n', binFilePath, ME.message);
            end
        end
    end
end
end
