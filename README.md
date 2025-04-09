# timing-task-analysis
Contains classes and dependencies for all timing task analyses

Authors: Allison E Hamilos (ahamilos[at]wi[dot]mit[dot]edu)
If you'd like to use this code or if you run into issues, please reach out - our team will be happy to help.

Description: Contains the latest release of all timing task analysis code, built off original versions in the eLife2021 repository.
Instructions: Each figure in Hamilos et al., 2025 contains a provenance file (as well as metadata) specifying the method and class of analysis object needed to reporduce the figure from the raw datasets. Start by generating the sObj and cObj for the datasets in question, then run the methods specified in the provenance file to reproduce the figure.

Release version: 2.0.1 | April 9, 2025
Publications using this version: 
    - Hamilos et al., 2025 - "A mechanism linking dopamine’s roles in reinforcement, movement and motivation" (biorxiv) -- https://doi.org/10.1101/2025.04.04.647288

Datasets:
    - Sample raw datasets from Hamilos et al., 2021: 10.5281/zenodo.4062748
        - These files can be run directly from the Zenodo directories to produce sObjs, from which all analyses are run
    - Additional datasets from Hamilos et al., 2025 will be released via DANDI upon publication. These will be in NWB format and will need to be converted back to .mat files with the proper directory structure for the code below to process them

---
Classes included:

    * ```sObj``` (CLASS_photometry_roadmapv1_4.m): completes initial processing of single-session and composite session objects using the UI specified photometry signal.

    * ```cObj``` (CLASS_STATcollate_photometry_roadmapv1_4.m): allows collation of single-session data for analyses. Analyses specified in the header. Use #method-name to see associated functions available for each analysis.
    
    *   ```sloshing_obj``` (CLASS_sloshing_obj.m): produces sloshing regression models and analyses
    
    *   ```eps``` (EphysStimPhot.m): produces v2.0 versions of single-session objects, inherits methods from sObj with additional features
    
    * ```zzt``` (CLASS_ZigZagTimewindows.m): contains methods for block processing in the Timeshift version of the task (Hamilos et al., 2025)

---
Preparing analyses:
1. You will need to create a directory tree in the proper format:
  - For stimulation experiments, you will need a SHAM, STIM and NOSTIM directory. Within each, you need a directory for each signal type (e.g., VLS for rdlight and VLSred for tdt)
  - Each session must have a folder in the signal directory of the format NAME_SIGNAL_DAY# (the data is already formatted this way in the Zenodo 2021 repository)
  - This folder should have 2 files (and only 2) before running the analysis code: NAME_SESSION#_CED.mat is the spike2 file. Exclusions_null.txt is a text file with any trials we are excluding (i.e., grooming trials). Note that for zzt analyses, you will also need the MBI file in the folder, with the name formatted as NAME_SESSION#_MBI.mat (see HSOMbehaviorSuite for how to generate MBI objects).
      - Exclusions.txt:
        -  Can be empty or can have text describing the session. ANY NUMBERS WILL GET EXCLUDED. Do not put any numbers in the text file that you don’t want to exclude!
        - Syntax:
          - 4       *Excludes trial 4*
          - 4-12       *Excludes trials 4 through 12*
          - 4-12,15 17	20     *Excludes trials 4-12,15, 17 and 20*
          - 510-end    *Excludes trial 510 till the end of the session*
          - *All other characters will be ignored*

2. Generate analysis objects (sObjs)
   - Uses 10-trial multibaseline dF/F (Hamilos et al., 2021 and 2025) with photometry signals pooled into 1s bins (specified by 'times', 17) with respect to the cue:
    - For stimulation sessions, select the photometry or movement signal AND ChR2 from the UI list:
      - For Stimulated trials (in STIM directory), use:
        -  ```obj = CLASS_photometry_roadmapv1_4('v3x','times',17,{'multibaseline',10},30000,[],[],'stim')```
      - For unstimulated trials (in NOSTIM directory), use:
          -  ```obj = CLASS_photometry_roadmapv1_4('v3x','times',17,{'multibaseline',10},30000,[],[], 'nostim')```
    -  For no-stum sessions, select just the photometry or movement signal from the UI list:
          -  ```obj = CLASS_photometry_roadmapv1_4('v3x','times',17,{'multibaseline',10},30000,[],[], 'off')```
    In the outer (Host) folder, a composite obj of all sessions included in the Host folder will be generated with the tag "v3x" in the filename. Meanwhile, single session sObjs will be generated in each folder

4. Visualize composite photometry signals
   - Open the v3x composite sObj from the Host folder.
   - Run ```obj.Stim = [];```
   - To plot a lick-triggered average, run:
       ```obj.plot('LTA', [bins_to_include], false, smoothing_kernel_in_milliseconds(e.g., 100), 'last-to-first', true),xlim([-2,7]), title(‘SIGNAL NAME (e.g., PHOTOMETRY_INDICATOR, SIGNAL_NAME, stimulated trials only')```
    - To plot a cue-triggered average, run:
       ```obj.plot('CTA', [bins_to_include], false, smoothing_kernel_in_milliseconds(e.g., 100), 'last-to-first', true),xlim([-2,7]), title(‘SIGNAL NAME (e.g., PHOTOMETRY_INDICATOR, SIGNAL_NAME, stimulated trials only')```
  - To plot a cue-and-lick-triggered average, run:
   ```obj.plot('CLTA', [bins_to_include], false, smoothing_kernel_in_milliseconds(e.g., 100), 'last-to-first', true),xlim([-2,7]), title(‘SIGNAL NAME (e.g., PHOTOMETRY_INDICATOR, SIGNAL_NAME, stimulated trials only')```

5. Generate other analysis objects
    - Go to the single session folder and run:
    - ```load_sObj_sloshing_zzt_FX([], true, true)```




