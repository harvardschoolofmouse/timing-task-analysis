# Timing Task Analysis Toolkit

This repository contains classes and dependencies for analyzing timing task data, originally developed for Hamilos et al., 2021 and extended for Hamilos et al., 2025.

## Authors
- **Allison E. Hamilos** (ahamilos[at]wi[dot]mit[dot]edu)  
For code usage or troubleshooting, please reach out - our team will be happy to assist.

## Description
Contains the latest release (v2.0.1) of timing task analysis code, building upon original versions from the eLife2021 repository.

## Quick Start
More detailed instructions available in the original repo [/elife2021](https://github.com/harvardschoolofmouse/eLife2021). Installation time for all software (e.g., Matlab) -- approx 10 min.

Each figure in Hamilos et al., 2025 includes:
1. A provenance file specifying required methods
2. Metadata for reproduction

To reproduce figures:
1. Generate `sObj` and `cObj` for your datasets
2. Run methods specified in the provenance files

## Version Information
**Current Release**: 2.0.2 (June 16, 2026)  
**Associated Publication**:  
- Hamilos et al., 2025 - *"A mechanism linking dopamine's roles in reinforcement, movement and motivation"*  
  [biorxiv preprint](https://doi.org/10.1101/2025.04.04.647288)


### Installation Guide
**Operating Systems**: Windows 10+, MacOS Sonoma 14.5

**Matlab Versions**: 2023B, 2024A

1. Download Matlab 2023B from the Mathworks website.
2. Add the Github repo to your path
3. Add the dependencies (below) using the AddOns tool. linspecer.m and violin.m can be searched using the AddOns manager.
4. To demo the analysis code, set your path to the demo dataset folder (B5_SNc_13)

### Matlab dependencies
- Curve Fitting Toolbox v3.5.8+
- Statistics and Machine Learning Toolbox v11.4+
- Signal Processing Toolbox v8.1+
- Optimization Toolbox v8.2+
- Image Processing Toolbox v10.3+
- DSP System Toolbox v9.7+
- Control System Toolbox v10.5+
- Lansey, Jonathan, 2013: linspecer.m - Matlab toolbox for creating optimal color schemes for plot visualizations.
- Hoffmann H, 2015: violin.m - Simple violin plot using matlab default kernel density estimation. INRES (University of Bonn), Katzenburgweg 5, 53115 Germany.

## Datasets
- **Hamilos et al., 2021 sample data**: [10.5281/zenodo.4062748](https://doi.org/10.5281/zenodo.4062748)
  - Directly compatible with this code
- **Small sample dataset for reviewers**: [https://www.dropbox.com/scl/fi/x3ypj4vwyxi53zyvy6xro/B5_SNc_13.zip?rlkey=q3eyyvnp96ozjqqqdhaoontr2&dl=0]
  - Directly compatible with this code. Contains one GCaMP6f recording session from mouse B5 at SNc. See Demo below
- **Hamilos et al., 2025 data** (coming soon):
  - Will be released via DANDI in NWB format
  - Requires conversion to .mat with proper directory structure

## Classes Overview
| Class | File | Description |
|-------|------|-------------|
| `sObj` | CLASS_photometry_roadmapv1_4.m | Processes single/composite session objects |
| `cObj` | CLASS_STATcollate_photometry_roadmapv1_4.m | Collates session data for analysis |
| `sloshing_obj` | CLASS_sloshing_model_obj.m | Sloshing regression models |
| `eps` | EphysStimPhot.m | Enhanced single-session objects (v2.0) |
| `zzt` | CLASS_ZigZagTimewindows.m | Block processing for Timeshift task |


## Demo Analysis Instructions
Sample dataset contents: Mouse B5, SNc GCaMP6f, day 13 of recording (B5_SNc_13 from the Zenodo dataset)

```
├── MOUSENAME_SIGNAL_RECORDINGDAY#
│   └── exclusions_file.txt      contains any trials excluded for rare grooming-touches of the spout
│   └── CED file                 raw dataset from CED acquisition system
│   └── sObj                     processed raw data packaged for analysis (this is made using the sObj constructor, below)

EXAMPLE DATASET:
├── B5_SNc_13
│   └── B5_exclusions_13.txt           Exclusions file
│   └── b5_day13_hybop0.mat            raw CED dataset
│   └── b5_SNc_13_REVISED_sObj.mat     sObj for this session. REVISED tag indicates software version

```
## Demo Analysis
Load specialized objects: go to the session folder (e.g., the uncompressed B5_SNc_13 folder) and run the following to extract all analysis objects
```matlab
[sObj, sloshing_obj, zzt] = load_sObj_sloshing_zzt_FX([], true, true)
```
Run the single session, single-trial "sloshing" GLM:
```matlab
sloshing_obj.resetLTA(0,500); % sets the window for consideration to be 0-500ms after the first lick
[Name,mdls] = runNTrialsBackModel(sloshing_obj,'LTA-&-EMG-&-tdt',true,true, false, 'none', 0, false)
```
Expected output: Plots of the regression model, coefficients, and the Matlab fitglm regression object, which contains all data and statistics from the model:

<img width="200" height="333" alt="image" src="https://github.com/user-attachments/assets/21524872-6bbf-411e-922c-241df6542cca" />
<img width="200" height="275" alt="image" src="https://github.com/user-attachments/assets/7a65ab7f-3eae-4ce2-b0ef-1e9be03064dc" />


## How to generate sObj analysis objects from raw datasets

### 1. Directory Structure
Required file organization:
```
For stimulation experiments:
├── SHAM
│   └── [signal_type] (e.g., VLS, VLSred)
│       └── NAME_SIGNAL_DAY#
├── STIM
│   └── [signal_type]
│       └── NAME_SIGNAL_DAY#
└── NOSTIM
    └── [signal_type]
        └── NAME_SIGNAL_DAY#
```

Each session folder must contain:
- `NAME_SESSION#_CED.mat` (Spike2 file)
- `Exclusions_null.txt` (Trial exclusion file)
- For zzt analyses: `NAME_SESSION#_MBI.mat`

### Exclusion File Syntax
Format trial exclusions in `Exclusions.txt` as:
```
- `4` → Excludes trial 4
- `4-12` → Excludes trials 4 through 12
- `4-12,15 17 20` → Excludes trials 4-12,15,17,20
- `510-end` → Excludes from trial 510 onward
```
*Note: Any numbers in the file will be excluded!*

### To generate analysis objects from scratch (sObjs):
**Basic command structure**:
```matlab
obj = CLASS_photometry_roadmapv1_4('v3x','times',17,{'multibaseline',10},30000,[],[],'stim_type')
```
*stim_type = 'stim' (uses stimulated trials only), 'nostim' (uses unstimulated trials only), 'off' (uses all trials)

