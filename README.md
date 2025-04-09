# Timing Task Analysis Toolkit

This repository contains classes and dependencies for analyzing timing task data, originally developed for Hamilos et al., 2021 and extended for Hamilos et al., 2025.

## Authors
- **Allison E. Hamilos** (ahamilos[at]wi[dot]mit[dot]edu)  
For code usage or troubleshooting, please reach out - our team will be happy to assist.

## Description
Contains the latest release (v2.0.1) of timing task analysis code, building upon original versions from the eLife2021 repository.

## Quick Start
Each figure in Hamilos et al., 2025 includes:
1. A provenance file specifying required methods
2. Metadata for reproduction

To reproduce figures:
1. Generate `sObj` and `cObj` for your datasets
2. Run methods specified in the provenance files

## Version Information
**Current Release**: 2.0.1 (April 9, 2025)  
**Associated Publication**:  
- Hamilos et al., 2025 - *"A mechanism linking dopamine's roles in reinforcement, movement and motivation"*  
  [biorxiv preprint](https://doi.org/10.1101/2025.04.04.647288)

## Datasets
- **Hamilos et al., 2021 sample data**: [10.5281/zenodo.4062748](https://doi.org/10.5281/zenodo.4062748)
  - Directly compatible with this code
- **Hamilos et al., 2025 data** (coming soon):
  - Will be released via DANDI in NWB format
  - Requires conversion to .mat with proper directory structure

## Classes Overview
| Class | File | Description |
|-------|------|-------------|
| `sObj` | CLASS_photometry_roadmapv1_4.m | Processes single/composite session objects |
| `cObj` | CLASS_STATcollate_photometry_roadmapv1_4.m | Collates session data for analysis |
| `sloshing_obj` | CLASS_sloshing_obj.m | Sloshing regression models |
| `eps` | EphysStimPhot.m | Enhanced single-session objects (v2.0) |
| `zzt` | CLASS_ZigZagTimewindows.m | Block processing for Timeshift task |

## Setup Instructions

### 1. Directory Structure
Required organization:
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

## Exclusion File Syntax
Format trial exclusions in `Exclusions.txt` as:
```
- `4` → Excludes trial 4
- `4-12` → Excludes trials 4 through 12
- `4-12,15 17 20` → Excludes trials 4-12,15,17,20
- `510-end` → Excludes from trial 510 onward
```
*Note: Any numbers in the file will be excluded!*

### 2. Generating sObjs
**Basic command structure**:
```matlab
obj = CLASS_photometry_roadmapv1_4('v3x','times',17,{'multibaseline',10},30000,[],[],'stim_type')
```
*stim_type = 'stim' (uses stimulated trials only), 'nostim' (uses unstimulated trials only), 'off' (uses all trials)

### 3. Visualization
**Composite object operations**:
```matlab
obj.Stim = []; % This field is vestigial, remove it before using the composite sObj

% Lick-triggered average
obj.plot('LTA', [bins], false, [smoothing_kernel_milliseconds], 'last-to-first', true)
xlim([-2,7])
title('Your Signal Description')

% Cue-triggered average
obj.plot('CTA', [bins], false, 100, 'last-to-first', true)

% Combined cue+lick-triggered average
obj.plot('CLTA', [bins], false, 100, 'last-to-first', true)
```

### 4. Advanced Analyses
Load specialized objects:
```matlab
load_sObj_sloshing_zzt_FX([], true, true)
```
