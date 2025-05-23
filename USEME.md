# 🧠 BIDS Conversion Use Case Overview

## Why Use MATLAB?

The raw EEG data and trigger-related information are stored in `.bin` and `.mat` formats, which are only loadable using MATLAB code. To convert these into [BIDS](https://bids.neuroimaging.io/), we must first extract the necessary data using MATLAB.

---

## What Are We Exporting from MATLAB?

We're focusing on the **Shuffle Speller** dataset. This repository contains all the relevant code.

### MATLAB Workflow:

* The entry point is [`runnerLoadData.m`](./runnerLoadData.m).
* This script iterates through a root dataset folder and:

  * Locates all `eeg.bin` files — each file contains raw EEG samples and metadata.
  * Finds the session-specific `*_pres_obj.mat` file — this includes stimulus/target trigger info (`targetIdx`).

> Each session can have **multiple `eeg.bin` files**, but only **one `*_pres_obj.mat` file**.

---

## MATLAB Code Breakdown

### File: `loadDataShuffleSpeller.m`

* A wrapper for `loadSessionDataBin.m`.
* It loads and extracts:

  * `pts`: Start/end indices for each trial (relative to EEG sample index).
  * `inputData`: Raw EEG samples for the session.

---

## Exporting from MATLAB → Python

To prepare for BIDS conversion in Python:

1. In `runnerLoadData.m`, we iterate over each `eeg.bin` file.
2. For each session, we collect:

   * `inputData`
   * `pts`
   * `targetIdx`
3. These are saved to a MATLAB file: `all_data_2.mat`.

```matlab
% Example MATLAB save call
save(fullfile(eegFolder, 'all_data_2.mat'), ...
    'inputData', 'fs', 'chNames', 'trials', 'pts', 'numTrials', 'targetIdx');
```

---

## In Python

We then load this `all_data_2.mat` file using `scipy.io.loadmat()` and proceed to convert the structured data into BIDS-compliant files.

