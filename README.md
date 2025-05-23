last edit matt.higger@gmail.com Sept 24, 2015

This repository contains the SSVEP speller, which spells using SSVEP.  It does so by partitioning letters among LED stimuli and deciding on a particular letter after multiple SSVEP trials.

| |
|:-------------:|
| ![shuffleScreenshot.png](https://bitbucket.org/repo/pMk6eG/images/4220207273-shuffleScreenshot.png)|

# Main Scripts: #

* **sessionCalib** - runs a training session, saves data

* **classifierTrain** - loads data, analyzes it, builds and saves classifiers.  show user performance metrics (acc, ITR, confusion matrix)
 
* **sessionSpeller** - query user for saved classifier, run a copyPhrase task

* **Control/shuffleControlTest** - run speller in keyboard mode, where a user inputs a key press rather than BCI inputs (helpful for demos / debugging)

All parameters are now contained in Parameters.  We expect OHSU collaborators to be interested in **presentationParams**, **spellerParams** and **trainingParams**.


# Submodules: #

* [modular-classifiers](https://bitbucket.org/cogsyslab/modular-classifiers)

* [codingForBCI](https://bitbucket.org/cogsyslab/codingforbci)

* [daq_gusbamp_32bit](https://bitbucket.org/cogsyslab/daq_gusbamp_32bit)

* [languageModel](https://bitbucket.org/cogsyslab/languagemodel)

* [matlabUtility](https://bitbucket.org/cogsyslab/matlabutility)

* [psychtoolboxObjects](https://bitbucket.org/cogsyslab/psychtoolboxobjects)

* [dictAlpha](https://bitbucket.org/cogsyslab/dictalpha)

* [led-stimulus-dds](https://bitbucket.org/cogsyslab/led-stimulus-dds)

* [puzzle](https://bitbucket.org/cogsyslab/puzzle)