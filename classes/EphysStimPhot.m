classdef EphysStimPhot < CLASS_photometry_roadmapv1_4
    % 
    %   Creates an object for analyzing HSOM photometry, spike data and optogenetics
    %   
    %   Created     ahamilos    4/26/2023
    %   Modified    ahamilos    4/9/2025       versionCode = 'v2.0.1'
    %   Dependencies:   
    %                   cprintf Toolbox
    %                   SpikeSorter output csv files:
    %     For use with csv files produced from Spike Sorter v5.0 from Swindale
    %           lab, British Columbia 
    %               https://swindale.ecc.ubc.ca/home-page/software/
    % 
    properties
        SpikeSorterData
        Intan
    end

    properties (Transient)
        ImportedData
    end

    %----------------------------------------------------
    %       Methods
    %----------------------------------------------------
    methods
        function [obj,tr,ss] = EphysStimPhot(sObj, cObj, fetchSpikes)
            if nargin < 3, fetchSpikes = false;end
            %
            %   Can either take an existing sObj and make an EphysStimPhot object, or it can create from scratch
            %   input2 would be a collated stat obj
            if nargin == 2
                obj.Plot = [];
                obj.iv = cObj.iv;
                obj.Mode = 'cObj_processed';
                obj.BinParams = [];
                obj.BinnedData = [];
                obj.SaveMode = [];
                obj.Log = [];
                obj.Stat = [];
                obj.Stim = [];
                obj.ChR2 = [];
                obj.gFitLP = [];
                obj.GLM = [];
                obj.ts = [];
                obj.CtrlCh = [];
                obj.video = [];
                try
                    obj.iv.signalname = obj.iv.signal;
                end
            elseif nargin == 1 || nargin == 3
                obj.Plot = sObj.Plot;
                obj.iv = sObj.iv;
                obj.Mode = sObj.Mode;
                obj.BinParams = sObj.BinParams;
                obj.BinnedData = sObj.BinnedData;
                obj.SaveMode = sObj.SaveMode;
                obj.Log = sObj.Log;
                obj.Stat = sObj.Stat;
                obj.Stim = sObj.Stim;
                obj.ChR2 = sObj.ChR2;
                obj.gFitLP = sObj.gFitLP;
                obj.GLM = sObj.GLM;
                obj.ts = sObj.ts;
                obj.CtrlCh = sObj.CtrlCh;
                obj.video = sObj.video;
            else % initialize a new SpikeStudio session...
               error('need to have sObj first')
            end
            obj.iv.versionCode = 'v0.1';

            % check if the sObj is empty -- if so, we are creating the ESP
            % obj from Intan data alone.
            if isempty(sObj.iv)
                obj.initializeIntanOnlyDataset();
            end

            obj.iv.signaltype_ = 'ephys';
            if ~isfield(obj.iv, 'signalname_')
                obj.iv.signalname_ = obj.iv.signalname{1}; 
            end
            if nargin <2
                obj.iv.sessionCode = [obj.iv.mousename_ '_' obj.iv.signalname_ '_' obj.iv.daynum_];
            end
            obj.ephysAlerts;
            obj.alert(['*' mat2str(obj.iv.ephysAlerts.info)], '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
            obj.alert(['*' mat2str(obj.iv.ephysAlerts.info)], ['             EphysStimPhot, ' obj.iv.versionCode ' \n'])
            obj.alert('info', '            "We''ve got the spikes" ')
            disp(' ')
            obj.alert('info', '       (c) Harvard School of Mouse, 2023 ')
            obj.alert(['*' mat2str(obj.iv.ephysAlerts.info)], '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
            % import data
            if fetchSpikes
                    try
                        [tr, ss] = obj.initializeObj([], [], true);
                    catch
                        obj.alert('achtung', 'We did not manage to finish initializing obj. You''ll need to run [tr, ss] = obj.initializeObj([], [], true); to get your spikes imported and be able to plot them.')
                    end
                    obj.alert('info', 'FYI: tr is TetrodeRecording object. This is capable of fetching Intan data. If you already have intan data stored, this obj can be initialized as an empty obj.')
                    obj.alert('info', 'FYI: ss is SpikeStudio object. This is capable of plotting Intan data in interesting ways. It can be initialized empty if Intan data is already imported. (ss=Spikestudio(tr), where tr is empty)')
                    try
                        obj.save(ss, tr);
                    catch
                        obj.alert('achtung', 'Hey! ss or tr did not save correctly! try again!')
                        try 
                            obj.save;
                            try
                                save('tr.mat', 'tr', '-v7.3');
                            catch
                                obj.alert('achtung', 'Hey! tr did not save correctly! try again!')
                            end
                        end
                    end 
            else
                obj.alert('achtung','EphysStimPhot obj initialized but NOT saved yet.')
            end
            % save the obj
            
            disp(' ')
            obj.alert('info', ['    (' datestr(now,'mm/dd/yyyy HH:MM AM') ') EphysStimPhot Session Initialized.']);
            obj.alert('info', '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
            % obj.save();
        end
        function save(obj, ss, tr)
            retdir = pwd;
            try
                cd(obj.iv.Path)
            end
            if nargin > 1
                ss.save;
            end
            if nargin > 2
                tr.save;
            end

            timestamp_now = datestr(now,'yyyymmdd__HHMM');
            if ~isfield(obj.iv,'signalname_'), obj.iv.signalname_ = obj.iv.signalname{1};end
            savefilename = ['ESPobj_' obj.iv.mousename_ '_' obj.iv.signalname_ '_' obj.iv.daynum_ '_' timestamp_now];
            obj.iv.filename_ = savefilename;
            save([savefilename, '.mat'], 'obj', '-v7.3');
            disp(' ')
            obj.alert('info', ['(' datestr(now,'mm/dd/yyyy HH:MM AM') ') Saved EphysStimPhot Session to ' strjoin(strsplit(pwd, '\'), '/') savefilename '.mat']);
            disp(' ')
            disp(' ')
            cd(retdir)
        end
        function ephysAlerts(obj)
            % 
            %   Sets color palette for SpikeStudio alerts! (cprintf)
            % 
            obj.iv.ephysAlerts.info = [0,0.6,0.6];
            obj.iv.ephysAlerts.achtung = '*[1,0.6,0]';
            obj.iv.ephysAlerts.thinking = [0.3,0.5,0.8];
        end
        function alert(obj, Style, txt)
            Alerts = obj.iv.ephysAlerts;
            try
                switch Style
                    case 'info'
                        cprintf(Alerts.info, [txt, '\n'])
                    case 'achtung'
                        cprintf(Alerts.achtung, [txt, '\n'])
                    case 'thinking'
                        cprintf(Alerts.thinking, [txt, '\n'])
                    otherwise
                        cprintf(Style, [txt, '\n'])
                end
            catch
                disp(txt)
            end
        end
        function initializeIntanOnlyDataset(obj, sObj, automated)
            % 
            %   Will be called if we input an empty sObj to ESP
            % 
            ephysAlerts(obj);
            if nargin < 3, automated = false;end
            if ~automated % prompt user to pick folder with the rhd files
                obj.alert('achtung', ' *!! -- Select folder with the ''.rhd'' files for this session.')
                Path = uigetdir('select folder with .rhd files for the session');
            end
            cd(Path)
            % 
            %   Parse the folder name
            %   
            seshID_ = strsplit(correctPathOS(Path, 'mac'), '/');
            seshID_ = strsplit(seshID_{end}, '_');
            sObj.iv.ESPtype = 'Intan-Only';
            sObj.iv.versionCode = 'Intan-Only v0.0';
            sObj.iv.mousename_ = seshID_{1};
            sObj.iv.signalname_ = 'Intan';
            sObj.iv.daynum_ = seshID_{2};
            sObj.iv.sessionCode = [sObj.iv.mousename_ '_' sObj.iv.signalname_ '_' sObj.iv.daynum_];
            sObj.iv.exclusions_struct.Excluded_Trials = [];
            sObj.iv.correctedSamplingRate = true;
            sObj.iv.setStyle = 'ESP Intan-Only';
            sObj.iv.Path = Path;
            sObj.Mode = 'Intan';   

            obj.iv = sObj.iv;
            obj.Mode = sObj.Mode;
        end
        function [tr, ss] = initializeObj(obj, tr, ss, rewrite)
            % this function will import all our data from kilosort or other spike sorting programs...
            if nargin < 4, rewrite = false;end
            if rewrite, obj.alert('achtung', 'ESP: overwriting existing Intan and spike data... kill fxn to prevent!'),end
            if isempty(obj.Intan) || rewrite
                try
                    if nargin <2 || isempty(tr) || rewrite
                        tr = runSynchronizationProcedure(obj);
                    end
                catch
                    obj.alert('achtung', '!!!! We failed to make tr. Rerun tr = runSynchronizationProcedure(obj);')
                end
            elseif nargin <2 || isempty(tr)
                tr = TetrodeRecording();
            end
            try
                if nargin <3 || isempty(ss) || rewrite
                    ss = SpikeStudio(tr);
                end
            catch
                obj.alert('achtung', '!!!! We failed to make SpikeStudio obj. Rerun ss = SpikeStudio(tr);')
                ss = [];
            end
            try
                if isempty(obj.SpikeSorterData) || rewrite
                    obj.import_spikes;
                end
            catch
                obj.alert('achtung', '!!!! We failed to import_spikes. Rerun obj.import_spikes;;')
            end

        end
        function units = import_spikes(obj, Recycle)
            %
            %  For use with csv files produced from Spike Sorter v5.0 from Swindale
            %  lab, British Columbia 
            %       https://swindale.ecc.ubc.ca/home-page/software/
            %       Saved to Assad Lab / Spike Sorting folder on server
            %
            %   Start by sorting your spikes in Spike Sorter. Export the csv file.
            %   Read it in here
            % 
            obj.alert('thinking', ['(' datestr(now,'mm/dd/yyyy HH:MM AM') ') Loading SpikeSorter units...'])
            if nargin <2 || ~ Recycle
                [FileName,PathName,FilterIndex]= uigetfile('./*.csv', 'Select SpikeSorter CSV file (*.csv)');
                obj.iv.SpikeSorterCSVfile = [PathName, FileName];
                if ~ischar(PathName)
                    units = [];
                    return
                end
                cd(PathName)
            end            
            % pull in the spike data: Col1=times, Col2=unit#, Col3=electrode channel#
            A = readmatrix(obj.iv.SpikeSorterCSVfile);
            % allocate spike times to each unit
            unit_nos = unique(A(:,2));
            units.times = {};
            units.channels = {};
            for u = 1:max(unit_nos)
                if isempty(find(A(:,2)==u)), continue, end
                units(u).times = A(A(:,2)==u,1);
                units(u).channels = A(A(:,2)==u,3);
                if sum(units(u).times ~= sort(units(u).times)) >0
                    numoff = sum(units(u).times ~= sort(units(u).times));
                    obj.alert('achtung', ['     Found ' num2str(numoff) ' timestamp(s) out of order for unit ', num2str(u) ]) %: ' mat2str(units(u).times(units(u).times ~= sort(units(u).times)))])
                end
            end 
            obj.SpikeSorterData = units;
        end
        function plotAndSaveAllUnits(obj, unitNos, event,s_b4,s_post, s_per_bin,ss, trialsIncluded, skipMerges,OmkarHidePlot)
            if nargin < 10, OmkarHidePlot=false;end
            if nargin < 9, skipMerges = false;end
            if nargin <8, trialsIncluded = 1:numel(obj.Intan.flick_s_wrtc);end
            obj.alert('info', '>> EphysStimPhot: Pick the save folder for all the figures ')
            d = uigetdir();
            nUnits = numel(unitNos);
            for unitNo = unitNos
                if isempty(obj.SpikeSorterData(unitNo).times)
                    continue
                end
                [f,~] = obj.plotUnitSummary(unitNo, event,s_b4,s_post, s_per_bin,ss, trialsIncluded, skipMerges,OmkarHidePlot);%obj.plotUnitRaster(unitNo, event,s_b4,s_post, s_per_bin,ss);
                obj.suppressNsaveFigure(d, ['Unit_' num2str(unitNo), '_' event '-aligned_'], f)
            end
            obj.alert('info', ['>> EphysStimPhot: All unit ' event '-aligned rasters saved to  ' d])
        end
        function [f, axs, PETHdata] = plotUnitSummary(obj, unitNo, event, s_b4, s_post, s_per_bin, ss, trialRange, skipMerges,OmkarHidePlot)
            if nargin <10, OmkarHidePlot=false;end
            if nargin < 9, skipMerges = false;end
            if nargin < 8, trialRange = 1:numel(obj.Intan.flick_s_wrtc);end
            if nargin < 7, ss = [];end
            if skipMerges && sum(isnan(obj.SpikeSorterData(unitNo).OriginalUnit))>0
                obj.alert('info', ['>> EphysStimPhot: Unit ' num2str(unitNo) ' was merged with another unit in SpikeStudio. Skipping.']);return;
            elseif sum(isnan(obj.SpikeSorterData(unitNo).OriginalUnit))>0
                obj.alert('achtung', ['>> EphysStimPhot: Unit ' num2str(unitNo) ' was merged with another unit in SpikeStudio. Consider skipping by using skipMerges = true!']);
            end
            [f,ax] = makeStandardFigure;
            f.Units = 'normalized';
            f.Position = [0.2, 0.2, 0.75, 0.5];
            set(f, 'name', [obj.iv.filename_ ': Unit#' num2str(unitNo) ' | ' event])
            ax_raster = ax;
            ax_raster.Units = 'normalized';ax_raster.Position = [0.035, 0.1, 0.65, 0.8];
            ax_CLTA = axes('units', 'normalized', 'position', [0.8, 0.7, 0.15, 0.23]);
            ax_CTA = axes('units', 'normalized', 'position', [0.8, 0.4, 0.15, 0.23]);
            ax_LTA = axes('units', 'normalized', 'position', [0.8, 0.08, 0.15, 0.23]);


            % bin up the spikes
            obj.getBinnedPETH('unitno', unitNo, 'mode', 'custom', 'nbins', [0,1,3.3,7,17]);
                try
                obj.plotESP('clta', 2:3,0,ax_CLTA); xlim(ax_CLTA,[-3,4.3])
                obj.plotESP('cta', 2:3,0,ax_CTA); xlim(ax_CTA,[-3,7])
                obj.plotESP('lta2l', 2:3,0,ax_LTA); xlim(ax_LTA,[-3.3,3])
                [~,~,PETHdata] = obj.plotUnitRaster(unitNo,event,s_b4,s_post,s_per_bin,ss,f,ax_raster, trialRange,OmkarHidePlot);

                legend(ax_CLTA, 'hide'); 
                legend(ax_LTA, 'hide');title(ax_CTA, 'CTA'), xlabel(ax_CLTA, ''),xlabel(ax_CTA, '')
                title(ax_LTA, 'LTA2l')
                legend(ax_raster, 'location', 'best')

                axs = [ax_raster,ax_LTA,ax_CLTA];
            catch
                [~,~,PETHdata] = obj.plotUnitRaster(unitNo,event,s_b4,s_post,s_per_bin,ss,f,ax_raster, trialRange,OmkarHidePlot);
                axs = [ax_raster,ax_LTA,ax_CLTA];
            end
        end
        function [ax,f,PETHdata] = plotUnitRaster(obj, unitNo, event,s_b4,s_post, s_per_bin,ss, f, ax, trialRange, OmkarHidePlot)
            if nargin < 10, OmkarHidePlot=false;end
            if nargin < 9, trialRange = 20:4:100; end%numel(obj.Intan.flick_s_wrtc);end
            %
            %   You have to synchronize clocks before running this... use obj.synchronizeClocks and importIntanDigitalEvents(tr)
            %
            if nargin < 8 
                [f,ax] = makeStandardFigure();
                f.Units = 'normalized';
                f.Position = [0.2, 0.2, 0.75, 0.5];
            end
            if nargin < 7 || isempty(ss), plotWave = false;else, plotWave=true;end
            if nargin < 6, s_per_bin = 0.1;end
            if nargin < 4; s_b4 = 5;end
            if nargin < 5; s_post = 5;end
            
            switch event
                case 'cue'
                    Title = 'Cue-aligned, trials in order';
                    refevents = obj.Intan.cue_s;
                    Ylabel = 'trial #';
                    % correction = obj.Intan.sync.cue_timeDiff_Intan_minus_CED;
                case 'flick'
                    Title = 'First-lick-aligned, trials in order';
                    Ylabel = 'trial #';
                    refevents = nan(size(obj.Intan.flick_s_wrtc));
                    refevents(~isnan(obj.Intan.flick_s_wrtc)) = obj.Intan.firstLick_s;
                case 'lick'
                    Title = 'Lick-aligned, trials in order';
                    Ylabel = 'lick #';
                    refevents = obj.Intan.lick_s;
                case 'lamp off'
                    Ylabel = 'trial #';
                    Title = 'Lamp-off-aligned, trials in order';
                    refevents = obj.Intan.lampOff_s;
                case 'cta2l' % will arrange by lick-time
                    Ylabel = 'trial #';
                    Title = 'Cue-aligned, trials sorted by first-lick time';
                    refevents = obj.Intan.cue_s;
                case 'lta2l' % will arrange by lick-time
                    Ylabel = 'trial #';
                    Title = 'First-lick-aligned, trials sorted by first-lick time';
                    refevents = nan(size(obj.Intan.flick_s_wrtc));
                    refevents(~isnan(obj.Intan.flick_s_wrtc)) = obj.Intan.firstLick_s;
            end
            if strcmp(event, 'cta2l') || strcmp(event,'lta2l')
                [sorted_lick_times, sorted_idx] = sort(obj.Intan.flick_s_wrtc);
            else
                sorted_idx = 1:numel(refevents);
            end
            sorted_lick_times = sorted_lick_times(trialRange);
            sorted_idx = sorted_idx(trialRange);
            obj.alert('achtung', 'Our trial range is decided after sorting')
            % 
            markerDivisor = numel(obj.GLM.flick_s_wrtc)/20;
            %
            %   plot other relevant events first
            %
            events = obj.Intan.firstLick_s;
            [~, events_wrt_event, first_events_wrt_event] = obj.binupspikes(events, refevents,s_b4, s_post);
            events_wrt_event = events_wrt_event(sorted_idx);
            first_events_wrt_event = first_events_wrt_event(sorted_idx);
            if ~OmkarHidePlot
                ax = obj.plotraster(events_wrt_event, first_events_wrt_event,...
                     'ax', ax,...
                     'dispName', 'first lick',...
                     'referenceEventName', event,...
                     'plotFirst', false,...
                     'markerSize', round(150/markerDivisor),...
                     'Alpha', 0.7,...
                     'color', [0.9,0,0.5]...
                     );
            end

            events = obj.Intan.lick_s;
            [~, events_wrt_event, first_events_wrt_event] = obj.binupspikes(events, refevents,s_b4, s_post);
            events_wrt_event = events_wrt_event(sorted_idx);
            first_events_wrt_event = first_events_wrt_event(sorted_idx);
            if ~OmkarHidePlot
                ax = obj.plotraster(events_wrt_event, first_events_wrt_event,...
                 'ax', ax,...
                 'dispName', 'lick',...
                 'referenceEventName', event,...
                 'plotFirst', false,...
                 'markerSize', round(100/markerDivisor),...
                 'append',true,...
                 'Alpha', 0.4,...
                 'color', [0,0.5,0.5]...
                 );
            end

            events = obj.Intan.cue_s;
            [~, events_wrt_event, first_events_wrt_event] = obj.binupspikes(events, refevents,s_b4, s_post);
            events_wrt_event = events_wrt_event(sorted_idx);
            first_events_wrt_event = first_events_wrt_event(sorted_idx);
            if ~OmkarHidePlot
                ax = obj.plotraster(events_wrt_event, first_events_wrt_event,...
                 'ax', ax,...
                 'dispName', 'cue',...
                 'referenceEventName', event,...
                 'append', true,...
                 'plotFirst', false,...
                 'markerSize', round(100/markerDivisor),...
                 'Alpha', 0.4,...
                 'color', [1,0,0]...
                 );
            end

            events = obj.Intan.lampOff_s;
            [~, events_wrt_event, first_events_wrt_event] = obj.binupspikes(events, refevents,s_b4, s_post);
            events_wrt_event = events_wrt_event(sorted_idx);
            first_events_wrt_event = first_events_wrt_event(sorted_idx);
            if ~OmkarHidePlot
                ax = obj.plotraster(events_wrt_event, first_events_wrt_event,...
                 'ax', ax,...
                 'dispName', 'lamp off',...
                 'referenceEventName', event,...
                 'append', true,...
                 'plotFirst', false,...
                 'markerSize', round(100/markerDivisor),...
                 'color', [0,0,1],...
                 'Alpha', 0.4...
                 );
            end


            spikes = obj.SpikeSorterData(unitNo).times;
            channels = unique(obj.SpikeSorterData(unitNo).channels);
            if numel(channels) == 1
                C = [0,0,0];
            elseif numel(unique(channels)) == 1
                C = [0,0.7, 0.5];
            else
                C = linspecer(numel(channels));
            end
            
            for ii = 1:numel(channels)
                ix = obj.SpikeSorterData(unitNo).channels == channels(ii);
                these_spikes = spikes(ix);
                % let's now split the spikes up by channel
                [~, spikes_wrt_event, first_spike_wrt_event] = obj.binupspikes(these_spikes, refevents,s_b4, s_post);
                spikes_wrt_event = spikes_wrt_event(sorted_idx);
                first_spike_wrt_event = first_spike_wrt_event(sorted_idx);
                %
                %   Plot the spike times
                %
                ax = obj.plotraster(spikes_wrt_event, first_spike_wrt_event,...
                     'ax', ax,...
                     'dispName', ['Unit #' num2str(unitNo) ' | channels: ' mat2str(channels)],...
                     'referenceEventName', event,...
                     'color', C(ii,:),...
                     'append', true);
                % 
                %   Let's get the PSTH
                % 
                yyaxis(ax, 'right')
                [ax, PETHdata] = obj.plotPETH(spikes_wrt_event, ax, C(ii,:), ['Unit #' num2str(unitNo) ' | channels: ' mat2str(channels)], s_b4, s_post,s_per_bin);
                yyaxis(ax, 'left')
            end
            if ~OmkarHidePlot
                xlim(ax,[-1*s_b4, s_post])
                ylabel(ax, Ylabel);
                title(ax, Title);
            else
                set(f,'visible','off') % hide for Omkar's pipeline to be efficient
            end

            % now plot the waveforms
            if plotWave
                axx = axes(f, 'units','normalized', 'position', [0.04,0.88,0.08,0.1], 'color', 'white', 'box', 'on');
                if numel(unique(channels)) == 1
                    C = [0,0.7, 0.5];
                else
                    C = linspecer(numel(channels));
                end
                for ii = 1:numel(channels)
                    ss.plotMeanWaveform(axx, unitNo, ii, C(ii,:))
                end
                legend(axx, 'hide')
                % xticklabels(axx,[])
                xlabel(axx, [])
                xlim(axx,[-0.5,0.5])
                xticks(axx,[-0.5,0,0.5])
            end
        end
        function get_siITI_lick_events(obj, lockoutWindow_s)
            % siITI is a bit more complicated... we need to exclude excluded trials. we also need to exclude in-trial licks
            if nargin < 2, lockoutWindow_s = 1;end
            refevents = obj.Intan.lick_s;
            % first, eliminate if a lick is within lockout of another lick
            lickDiffs = [nan; obj.Intan.lick_s(2:end) - obj.Intan.lick_s(1:end-1)];
            removeLockout = lickDiffs <= lockoutWindow_s;
            refevents(removeLockout) = [];
            % eliminate any that are within the cue-lick interval
            removeFlick = ismember(refevents, obj.Intan.firstLick_s);
            refevents(removeFlick) = [];
            % lets ref to flick
            flick_s = nan(size(obj.Intan.cue_s));
            flick_s(~isnan(obj.Intan.flick_s_wrtc)) = obj.Intan.firstLick_s;
            % eliminate any between lamoOff-cue
            obj.Intan.siITI_s_by_trial = cell(numel(obj.Intan.cue_s)-1,1);
            for trial = 1:numel(obj.Intan.cue_s)-1
                ii = find(refevents>obj.Intan.lampOff_s(trial), 1, 'first');
                del_cue = obj.Intan.cue_s(trial) - obj.Intan.lampOff_s(trial);
                del_sus = refevents(ii) - obj.Intan.lampOff_s(trial);
                if del_sus < del_cue
                    refevents(ii) = [];
                end
                obj.Intan.siITI_s_by_trial{trial} = refevents(refevents>flick_s(trial) & refevents<obj.Intan.lampOff_s(trial+1));
            end
            obj.Intan.siITI_s = refevents;
            obj.Intan.siITI_table = [];obj.Intan.siITI_table.time = [];obj.Intan.siITI_table.trial = []; obj.Intan.siITI_table.time_to_prev_lick = [];
            for ii = 1:numel(obj.Intan.siITI_s_by_trial)
                for jj = 1:numel(obj.Intan.siITI_s_by_trial{ii})
                    obj.Intan.siITI_table(end+1).time = obj.Intan.siITI_s_by_trial{ii}(jj);obj.Intan.siITI_table(end).trial = ii;
                    prevlick_time = obj.Intan.lick_s(find(obj.Intan.lick_s < obj.Intan.siITI_s_by_trial{ii}(jj), 1, 'last'));
                    obj.Intan.siITI_table(end).time_to_prev_lick = obj.Intan.siITI_s_by_trial{ii}(jj)-prevlick_time;
                end
            end
            obj.Intan.siITI_table(1) = [];

            % check our work:
            [~,ax] = makeStandardFigure;
            events = obj.Intan.firstLick_s;
            [~, events_wrt_event, first_events_wrt_event] = obj.binupspikes(events, obj.Intan.cue_s,3, 17);
            ax = obj.plotraster(events_wrt_event, first_events_wrt_event,'ax', ax,'dispName', 'first lick','referenceEventName', 'cue','plotFirst', false,'markerSize', 300,'Alpha', 0.7,'color', [0.9,0,0.5]);
            events = obj.Intan.lick_s;
            [~, events_wrt_event, first_events_wrt_event] = obj.binupspikes(events, obj.Intan.cue_s,3, 17);
            ax = obj.plotraster(events_wrt_event, first_events_wrt_event,'ax', ax,'dispName', 'lick','referenceEventName', 'cue','plotFirst', false,'markerSize', 200,'append',true,'Alpha', 0.4,'color', [0,0,0.0]);
            events = obj.Intan.lampOff_s;
            [~, events_wrt_event, first_events_wrt_event] = obj.binupspikes(events, obj.Intan.cue_s,3, 17);
            ax = obj.plotraster(events_wrt_event, first_events_wrt_event,'ax', ax,'dispName', 'lamp off','referenceEventName', 'cue','append', true,'plotFirst', false,'markerSize', 200,'color', [0,0,1],'Alpha', 0.4);
            [~, events_wrt_event, first_events_wrt_event] = obj.binupspikes(refevents, obj.Intan.cue_s,3, 17);
            ax = obj.plotraster(events_wrt_event, first_events_wrt_event,'ax', ax,'dispName', 'siITI','referenceEventName', 'cue','append', true,'plotFirst', false,'markerSize', 100,'color', [1,0,0],'Alpha', 1);
        end
        function [ax, PETHdata] = plotPETH(obj,spikes_wrt_event, ax, C, dispName, s_b4, s_post,s_per_bin)
            % 
            % can also take firstspike_wrt_event to just plot the first event
            % this is gonna normalize to the timebase... that gives us the rate
            %     
            if nargin < 8, s_per_bin=0.1;end
            if s_b4 >0, s_b4=-1*s_b4;end
            bin_edges = s_b4:s_per_bin:s_post;
            if iscell(spikes_wrt_event), noEvents = numel(spikes_wrt_event); spikes_wrt_event = cell2mat(spikes_wrt_event);end
            [no_spikes_per_bin,~] = histcounts(spikes_wrt_event, bin_edges);
            Hz = no_spikes_per_bin ./ s_per_bin./noEvents;
            plot(ax, bin_edges(1:end-1)+0.05, Hz,'linewidth', 2, 'Color', C, 'DisplayName',dispName)
            plot(ax, [0,0], [min(Hz),max(Hz)],'linewidth', 2, 'Color', 'k', 'HandleVisibility','off')
            legend(ax,'show')
            ylabel(ax, 'spikes/s')
            xlabel(ax, 'time (s)')

            PETHdata.Hz = Hz; PETHdata.bin_edge_data = bin_edges(1:end-1)+0.05; 
        end
        function [trials_in_each_bin, pooledData_Hz] = binPETH(obj, poolEdges, timePad, s_per_bin, flick_times, spikes, siITI)
            nPools = numel(poolEdges)-1;
            pooledData_Hz = cell(1,nPools);
            trials_in_each_bin = cell(nPools,1);
            for ii = 1:nPools
                % find the trials that should be included
                trialsIncluded = flick_times >= poolEdges(ii) & flick_times < poolEdges(ii+1);
                spikes_wrt_event = spikes(trialsIncluded);
                trials_in_each_bin{ii} = find(trialsIncluded);
                % construct psth
                bin_edges = -1*timePad:s_per_bin:timePad;
                if iscell(spikes_wrt_event), noEvents = numel(spikes_wrt_event); spikes_wrt_event = cell2mat(spikes_wrt_event);end
                [no_spikes_per_bin,~] = histcounts(spikes_wrt_event, bin_edges);
                Hz = no_spikes_per_bin ./ s_per_bin./noEvents;
                % append to pooled data
                pooledData_Hz{ii} = Hz;
                % 
                %   Append the legend
                % 
                if siITI
                    obj.ts.BinParams.Legend_s.siITI{ii} = [num2str(round(poolEdges(ii),3)) 's - ' num2str(round(poolEdges(ii + 1),3)) 's | n=' num2str(numel(trials_in_each_bin{ii}))];
                    % 
                    %   Get Bin Time Centers and Ranges
                    % 
                    obj.ts.BinParams.s(ii).siITI_Min = poolEdges(ii);
                    obj.ts.BinParams.s(ii).siITI_Max = poolEdges(ii + 1);
                    obj.ts.BinParams.s(ii).siITICenter = (poolEdges(ii) + (poolEdges(ii+1) - poolEdges(ii))/2);
                else
                    obj.ts.BinParams.Legend_s.CLTA{ii} = [num2str(round(poolEdges(ii),3)) 's - ' num2str(round(poolEdges(ii + 1),3)) 's | n=' num2str(numel(trials_in_each_bin{ii}))];
                    % 
                    %   Get Bin Time Centers and Ranges
                    % 
                    obj.ts.BinParams.s(ii).CLTA_Min = poolEdges(ii);
                    obj.ts.BinParams.s(ii).CLTA_Max = poolEdges(ii + 1);
                    obj.ts.BinParams.s(ii).CLTA_Center = (poolEdges(ii) + (poolEdges(ii+1) - poolEdges(ii))/2);
                end
            end
        end
        function getBinnedPETH(obj, varargin)
            % 
            %   Modes:  
            %       'Custom' -- nbins is the user input bin windows
            %       'SingleTrial' -- makes a bin for every trial in the session
            %       'SingleTrialwrtLO' -- same idea, but bins wrt LIGHTS OUT
            %       'Times' -- nbins = total number of bins.
            %       'Trials' -- nbins = number of trials in each bin
            %       'Outcome' -- nbins has no effect
            %       'Paired' -- nbins instead is a cell:
            %           {# of bins n, [cat1min, cat1max], [cat2min, cat2max]}. Time windows wrt cue on in ms
            %       'Triplet' -- nbins instead is a cell:
            %           {# of bins n, [cat1min, cat1max], [cat2min, cat2max]}. Time windows wrt cue on in ms
            %       'Paired-nLicksBaseline' -- nbins instead is a cell:
            %           {# of bins n, [cat1min, cat1max], [cat2min, cat2max], baselineWindow (ms)}. Time windows wrt cue on in ms 
            % 
            p = inputParser;
            addParameter(p, 'UnitNo', 1, @isnumeric); 
            addParameter(p, 'Mode', 'times', @ischar); 
            addParameter(p, 'nBins', 17, @isnumeric);
            addParameter(p, 'Channels', [], @isnumeric);
            addParameter(p, 'sPerBin', 0.1, @isnumeric);
            addParameter(p, 'TimePad', 20, @isnumeric); % nb is in SECONDS, unlike photometry obj
            addParameter(p, 'TrialsIncluded', [], @isnumeric);
            addParameter(p, 'ConditionNm1RewOrEarly', '', @ischar); % 'early' or 'reward'
            parse(p, varargin{:});
            unitNo              = p.Results.UnitNo;
            Mode                = p.Results.Mode;
            nbins               = p.Results.nBins;
            channels            = p.Results.Channels;
            s_per_bin           = p.Results.sPerBin;
            timePad                 = p.Results.TimePad;
            trialsIncluded          = p.Results.TrialsIncluded;
            conditionNm1RewOrEarly  = p.Results.ConditionNm1RewOrEarly;
            
            % deal with some default settings
            if isempty(channels), 
                % obj.alert('achtung', ['>> EphysStimPhot: Using all channels for Unit #' num2str(unitNo)]);
                 channels = unique(obj.SpikeSorterData(unitNo).channels);
             end
            if strcmpi(Mode, 'Paired') && nbins == 17 ,  nbins = {2, [0,3.30], [3.34,7]};end
            if isempty(trialsIncluded)
                trialsIncluded = obj.Intan.fLick_trial_num; flick_Idx = 1:numel(obj.Intan.firstLick_s);
            else
                trialsIncluded = obj.Intan.fLick_trial_num(ismember(obj.Intan.fLick_trial_num, trialsIncluded));
                flick_Idx = find(ismember(obj.Intan.fLick_trial_num, trialsIncluded));
            end
            if strcmpi(conditionNm1RewOrEarly, 'Reward')
                obj.alert('achtung', '>> Conditioning on n-1th trial being rewarded!')
                nm1rew = 1+find(obj.Intan.flick_s_wrtc>=3.333);
                trialsIncluded = trialsIncluded(ismember(trialsIncluded, nm1rew));
                flick_Idx = find(ismember(obj.Intan.fLick_trial_num, trialsIncluded));
            elseif strcmpi(conditionNm1RewOrEarly, 'Early')
                obj.alert('achtung', '>> Conditioning on n-1th trial being early!')
                nm1norew = 1+find(obj.Intan.flick_s_wrtc<3.333);
                trialsIncluded = trialsIncluded(ismember(trialsIncluded, nm1norew));
                flick_Idx = find(ismember(obj.Intan.fLick_trial_num, trialsIncluded));
            end

            % set up the binning
            flick_s_wrtc = nan(size(obj.Intan.cue_s));
            flick_s_wrtc(trialsIncluded) = obj.Intan.flick_s_wrtc(trialsIncluded);
            % obj.alert('info', '>> Overwritting previously-binned spike or timeseries data...')
            obj.ts = {};
            % record who is included
            obj.ts.unitNo = unitNo;
            obj.ts.channels = channels;
            obj.ts.s_per_bin = s_per_bin;

            % get all the spikes wrt cue and flick
            spikes = obj.SpikeSorterData(unitNo).times(ismember(obj.SpikeSorterData(unitNo).channels, channels));
            [~, all_spikes_wrt_cue, ~] = obj.binupspikes(spikes, obj.Intan.cue_s,timePad, timePad);
            refevents = nan(size(obj.Intan.flick_s_wrtc));
            refevents(~isnan(obj.Intan.flick_s_wrtc)) = obj.Intan.firstLick_s;
            [~, all_spikes_wrt_flick, ~] = obj.binupspikes(spikes, refevents,timePad, timePad);

            [~, all_spikes_wrt_lampoff, ~] = obj.binupspikes(spikes, obj.Intan.lampOff_s,timePad, timePad);
%             [~, all_spikes_wrt_lick, ~] = obj.binupspikes(spikes, obj.Intan.lick_s,timePad, timePad);
            % set all the un-included trials to nans
            spikes_wrt_cue = cell(size(all_spikes_wrt_cue));
            spikes_wrt_cue(trialsIncluded) = all_spikes_wrt_cue(trialsIncluded);
            spikes_wrt_flick = cell(size(all_spikes_wrt_flick));
            spikes_wrt_flick(trialsIncluded) = all_spikes_wrt_flick(trialsIncluded);
            spikes_wrt_lampoff = cell(size(all_spikes_wrt_lampoff));
            spikes_wrt_lampoff(trialsIncluded) = all_spikes_wrt_lampoff(trialsIncluded);
            if ~isfield(obj.Intan, 'siITI_s'),obj.get_siITI_lick_events;end
            si_included = find(ismember([obj.Intan.siITI_table.trial], trialsIncluded));
            spikes_wrt_siITI = [obj.Intan.siITI_table(si_included).time]';
            trials_wrt_siITI = [obj.Intan.siITI_table(si_included).trial]';
            time_to_prev_lick_siITI = [obj.Intan.siITI_table(si_included).time_to_prev_lick]';




            % handle binning. we need to get the pool edges and pass those in
            % 
            %   Trials go in each bin (for example...):
            %       CTA             LTA             siITI
            % 1| 0:1s wrtCue    0:1s wrtCue     0:1s wrtLastLick
            % 2| 1:2s wrtCue    1:2s wrtCue     1:2s wrtLastLick
            % ...
            % 
            switch Mode
            case 'times'
                % obj.alert('info', ['>> Attempting to bin spike data by time... (' datestr(now,'HH:MM AM') ')']);
                poolEdges = linspace(0,17,nbins+1); % we specify the poolEdges in our input to nbins
            case 'trials'
                totaltrials = sum(~isnan(flick_s_wrtc));
                trials_per_bin = floor(totaltrials/nbins);
                trial_times_sorted = sort(flick_s_wrtc(~isnan(flick_s_wrtc)));
                poolEdges = trial_times_sorted(1:trials_per_bin:end);
                if numel(poolEdges) < nbins, poolEdges(end) = trial_times_sorted(end);end
                % obj.alert('info', ['>> Attempting to bin spike data with equal numbers of trials per bin... (' datestr(now,'HH:MM AM') ')']);
            case 'custom'
                poolEdges = nbins; % we specify the poolEdges in our input to nbins
                nbins = numel(poolEdges) -1;
                % obj.alert('info', ['>> Attempting to bin spike data based on UI-defined windows... (' datestr(now,'HH:MM AM') ')']);
            end
            nPools = numel(poolEdges) - 1;
            % obj.alert('info',['>> nPools: ' num2str(nPools) ' || poolEdges (s): ' mat2str(poolEdges)]);
            % get binned data for each type of lick
            [trials_in_each_bin, obj.ts.BinnedData.CTA] = obj.binPETH(poolEdges, timePad, s_per_bin, flick_s_wrtc, spikes_wrt_cue, false);
            [~, obj.ts.BinnedData.LTA] = obj.binPETH(poolEdges, timePad, s_per_bin, flick_s_wrtc, spikes_wrt_flick, false);
            [~, obj.ts.BinnedData.LOTA] = obj.binPETH(poolEdges, timePad, s_per_bin, flick_s_wrtc, spikes_wrt_lampoff, false);
            [siITInum_in_each_bin, obj.ts.BinnedData.siITI] = obj.binPETH(poolEdges, timePad, s_per_bin, time_to_prev_lick_siITI, num2cell(spikes_wrt_siITI), true);

            siITImap.si_lick_indicies_in_each_bin = [];
            siITImap.trials_in_each_bin = [];
            for ii = 1:numel(siITInum_in_each_bin)
                siITImap(ii).si_lick_indicies = siITInum_in_each_bin{ii};
                siITImap(ii).trials = trials_wrt_siITI(siITInum_in_each_bin{ii});
                siITImap(ii).time_to_prev_lick = time_to_prev_lick_siITI(siITInum_in_each_bin{ii});
            end


            obj.ts.BinParams.binEdges_CLTA = poolEdges;
            obj.ts.BinParams.trials_in_each_bin = trials_in_each_bin;
            obj.ts.BinParams.siITImap = siITImap;
            obj.ts.BinParams.nbins_CLTA = nbins;
            xx = -timePad:s_per_bin:timePad;
            xx = xx(1:end-1)+0.05;

            obj.ts.Plot.CTA.xticks.s = xx;
            obj.ts.Plot.LTA.xticks.s = xx;
                
        end
        function tr = runSynchronizationProcedure(obj)
            % 
            %   Gets the intan digital events, allowing us to align our CED and Intan clocks. You need to select all the files that went into the spike sorting...
            % 
            tr = TetrodeRecording();
            % Select files
            obj.alert('info', '     Be sure to select all RHD files that were sorted' ) %: ' mat2str(units(u).times(units(u).times ~= sort(units(u).times)))])
            tr.SelectFiles();
            tr.ReadFiles('detectspikes', false,...
                'ChunkSize', 5);
            % import the digital events to ephystimobj
            obj.importIntanDigitalEvents(tr);
            try
                % get the intan flick wrt cue
                obj.getIntanflickwrtc(true);
                % synchronize the CED clock with Intan
                obj.synchronizeClocks;
            catch
                obj.alert('achtung', 'Failed to finish obj.getIntanflickwrtc(true); and obj.synchronizeClocks; rereun this')
            end
        end
        function importIntanDigitalEvents(obj,tr)
            if isfield(obj.iv, 'ESPtype') && strcmpi(obj.iv.ESPtype, 'Intan-Only')
                % this is a Suyang or LFH obj
                % figure out which:
                if ~isfield(tr.DigitalEvents, 'StimOn')
                    obj.Intan.UserTag = 'Suyang';
                    % these are placeholders
                    obj.Intan.cue_s = tr.DigitalEvents.PressOff';
                    obj.Intan.lampOff_s = tr.DigitalEvents.PressOff';
                    warning('pretending that press is a lick')
                    obj.Intan.lick_s = tr.DigitalEvents.PressOn';

                    obj.Intan.pressOn_s = tr.DigitalEvents.PressOn';
                    obj.Intan.pressOff_s = tr.DigitalEvents.PressOff';
                    % obj.Intan.lick_s = tr.DigitalEvents.LickOn';
                    obj.Intan.juice_s = tr.DigitalEvents.RewardOn';

                    % we will pretend the lick is the press
                    [~, ~, lick_events] = histcounts(obj.Intan.pressOn_s, obj.Intan.pressOff_s);
                    [fLick_trial_num, idx_event, ~] = unique(lick_events);
                    if fLick_trial_num(1) == 0
                        fLick_trial_num = fLick_trial_num(2:end);
                        idx_event = idx_event(2:end);
                    end
                    % since we may not have taken the whole session for spike
                    % sorting, we need to trim off flick_trial_nums
                    exclIdx = find(ismember(fLick_trial_num, obj.iv.exclusions_struct.Excluded_Trials));
                    fLick_trial_num(exclIdx) = [];
                    idx_event(exclIdx) = [];
                    obj.Intan.fPress_trial_num = fLick_trial_num;
                    obj.Intan.firstPress_s = obj.Intan.pressOn_s(idx_event);

                    if ~isempty(obj.Intan.lick_s)
                        [~, ~, lick_events] = histcounts(obj.Intan.lick_s, obj.Intan.pressOff_s);
                        [fLick_trial_num, idx_event, ~] = unique(lick_events);
                        if fLick_trial_num(1) == 0
                            fLick_trial_num = fLick_trial_num(2:end);
                            idx_event = idx_event(2:end);
                        end
                        % since we may not have taken the whole session for spike
                        % sorting, we need to trim off flick_trial_nums
                        exclIdx = find(ismember(fLick_trial_num, obj.iv.exclusions_struct.Excluded_Trials));
                        fLick_trial_num(exclIdx) = [];
                        idx_event(exclIdx) = [];
                        obj.Intan.fLick_trial_num = fLick_trial_num;                    
                        obj.Intan.firstLick_s = obj.Intan.lick_s(idx_event);
                    else
                        obj.Intan.fLick_trial_num = [];
                        obj.Intan.firstLick_s = [];
                    end

                    obj.iv.rxnwin_ = '0';
                    obj.iv.num_trials = numel(obj.Intan.cue_s);
                    obj.iv.num_trials_category = 'not applicable';
                    obj.iv.exptype_ = 'Suyang self-initiated press task';
                    obj.iv.signalname = 'SNc/SNr';
                elseif isfield(tr.DigitalEvents, 'StimOn')
                    error('not implemented')
                    obj.Intan.UserTag = 'LFH';
                    % these are placeholders
                    obj.Intan.cue_s = tr.DigitalEvents.PressOff';
                    obj.Intan.lampOff_s = tr.DigitalEvents.PressOff';
                    warning('pretending that press is a lick')
                    obj.Intan.lick_s = tr.DigitalEvents.PressOn';

                    obj.Intan.pressOn_s = tr.DigitalEvents.PressOn';
                    obj.Intan.pressOff_s = tr.DigitalEvents.PressOff';
                    % obj.Intan.lick_s = tr.DigitalEvents.LickOn';
                    obj.Intan.juice_s = tr.DigitalEvents.RewardOn';

                    % we will pretend the lick is the press
                    [~, ~, lick_events] = histcounts(obj.Intan.pressOn_s, obj.Intan.pressOff_s);
                    [fLick_trial_num, idx_event, ~] = unique(lick_events);
                    if fLick_trial_num(1) == 0
                        fLick_trial_num = fLick_trial_num(2:end);
                        idx_event = idx_event(2:end);
                    end
                    % since we may not have taken the whole session for spike
                    % sorting, we need to trim off flick_trial_nums
                    exclIdx = find(ismember(fLick_trial_num, obj.iv.exclusions_struct.Excluded_Trials));
                    fLick_trial_num(exclIdx) = [];
                    idx_event(exclIdx) = [];
                    obj.Intan.fPress_trial_num = fLick_trial_num;
                    obj.Intan.firstPress_s = obj.Intan.pressOn_s(idx_event);

                    if ~isempty(obj.Intan.lick_s)
                        [~, ~, lick_events] = histcounts(obj.Intan.lick_s, obj.Intan.pressOff_s);
                        [fLick_trial_num, idx_event, ~] = unique(lick_events);
                        if fLick_trial_num(1) == 0
                            fLick_trial_num = fLick_trial_num(2:end);
                            idx_event = idx_event(2:end);
                        end
                        % since we may not have taken the whole session for spike
                        % sorting, we need to trim off flick_trial_nums
                        exclIdx = find(ismember(fLick_trial_num, obj.iv.exclusions_struct.Excluded_Trials));
                        fLick_trial_num(exclIdx) = [];
                        idx_event(exclIdx) = [];
                        obj.Intan.fLick_trial_num = fLick_trial_num;                    
                        obj.Intan.firstLick_s = obj.Intan.lick_s(idx_event);
                    else
                        obj.Intan.fLick_trial_num = [];
                        obj.Intan.firstLick_s = [];
                    end

                    obj.iv.rxnwin_ = '0';
                    obj.iv.num_trials = numel(obj.Intan.cue_s);
                    obj.iv.num_trials_category = 'not applicable';
                    obj.iv.exptype_ = 'Suyang self-initiated press task';
                    obj.iv.signalname = 'SNc/SNr';
                else
                    error('is this LFH data? need to write case')
                end
            else
                obj.Intan.cue_s = tr.DigitalEvents.START_CUOn';
                obj.Intan.lick_s = tr.DigitalEvents.LICKOn';
                obj.Intan.lampOff_s = tr.DigitalEvents.LAMPOff';
                [~, ~, lick_events] = histcounts(obj.Intan.lick_s, obj.Intan.cue_s);
                [fLick_trial_num, idx_event, ~] = unique(lick_events);
                if fLick_trial_num(1) == 0
                    fLick_trial_num = fLick_trial_num(2:end);
                    idx_event = idx_event(2:end);
                end
                % since we may not have taken the whole session for spike
                % sorting, we need to trim off flick_trial_nums
                exclIdx = find(ismember(fLick_trial_num, obj.iv.exclusions_struct.Excluded_Trials));
                fLick_trial_num(exclIdx) = [];
                idx_event(exclIdx) = [];
                obj.Intan.fLick_trial_num = fLick_trial_num;
                obj.Intan.firstLick_s = obj.Intan.lick_s(idx_event);
            end
        end
        function getIntanflickwrtc(obj, overwrite)
            % must call importIntanDigitalEvents(tr) first
            if nargin < 2
                overwrite = false;
            end
            if ~isfield(obj.Intan, 'flick_pos_wrtc') || overwrite
                obj.Intan.flick_s_wrtc = nan(size(obj.Intan.cue_s));
                obj.Intan.flick_s_wrtc(obj.Intan.fLick_trial_num) = obj.Intan.firstLick_s - obj.Intan.cue_s(obj.Intan.fLick_trial_num);
                obj.Intan.flick_pos_wrtc = round(obj.Intan.flick_s_wrtc*30000);

                if isfield(obj.Intan, 'pressOff_s')
                    % this should be Suyang data
                    warning('this step should only be for Suyang, not LFH!')
                    obj.Intan.fpress_s_wrtc = nan(size(obj.Intan.pressOff_s));
                    obj.Intan.fpress_s_wrtc(obj.Intan.fPress_trial_num) = obj.Intan.firstPress_s - obj.Intan.pressOn_s(obj.Intan.fPress_trial_num);
                    obj.Intan.fpress_pos_wrtc = round(obj.Intan.fpress_s_wrtc*30000);
                    % need to get longest trial length...
                    obj.iv.total_time_ = num2str((ceil(max(obj.Intan.fpress_s_wrtc))+5)*1000);
                    obj.Plot.wrtCue.Events.s = [];
                end
            end
        end
        function synchronizeClocks(obj)
            %
            %   We need to nab the time of the first 3 cue events off Intan and CED
            %
            if isfield(obj.iv, 'ESPtype') && strcmpi(obj.iv.ESPtype, 'Intan-Only')
                %  we should not synchronize. there is no CED data...
                cue_CED = obj.Intan.cue_s;
                obj.Intan.sync.cue_timeDiff_Intan_minus_CED = obj.Intan.cue_s - cue_CED;
                lick_CED = obj.Intan.lick_s;
                obj.Intan.sync.lick_timeDiff_Intan_minus_CED = obj.Intan.lick_s - lick_CED;
                flick_CED = obj.Intan.flick_s_wrtc;
                obj.Intan.sync.flick_timeDiff_Intan_minus_CED = obj.Intan.flick_s_wrtc - flick_CED;
                lampOff_CED = obj.Intan.lampOff_s;
                obj.Intan.sync.lampOff_timeDiff_Intan_minus_CED = obj.Intan.lampOff_s - lampOff_CED;  
            else

                cue_CED = obj.GLM.cue_s(1:numel(obj.Intan.cue_s));
                obj.Intan.sync.cue_timeDiff_Intan_minus_CED = obj.Intan.cue_s - cue_CED;

                try
                   lick_CED = obj.GLM.lick_s(1:numel(obj.Intan.lick_s));
                   obj.Intan.sync.lick_timeDiff_Intan_minus_CED = obj.Intan.lick_s - lick_CED;
                catch
                   try
                       if numel(obj.Intan.lick_s) > obj.GLM.lick_s
                           warning(['intan got more licks (' num2str(numel(obj.Intan.lick_s)) ') than CED ' num2str(numel(obj.GLM.lick_s)) '. we will just take those found by CED'])
                       else
                           warning('unknown error!!')
                           warning(['intan licks (' num2str(numel(obj.Intan.lick_s)) ') | CED ' num2str(numel(obj.GLM.lick_s)) '. This is mismatched???'])
                       end
                   catch
                   end
                   lick_CED = obj.GLM.lick_s(1:end);
                   obj.Intan.sync.lick_timeDiff_Intan_minus_CED = obj.Intan.lick_s(1:numel(lick_CED)) - lick_CED;
                end
               
                try
                   flick_CED = obj.GLM.flick_s_wrtc(1:numel(obj.Intan.flick_s_wrtc));
                   obj.Intan.sync.flick_timeDiff_Intan_minus_CED = obj.Intan.flick_s_wrtc - flick_CED;
                catch
                   try
                       if numel(obj.Intan.flick_s_wrtc) > obj.GLM.flick_s_wrtc
                           warning(['intan got more flick_s_wrtc (' num2str(obj.Intan.flick_s_wrtc) ') than CED ' num2str(obj.GLM.flick_s_wrtc) '. we will just take those found by CED'])
                       else
                           warning('unknown error!!')
                           warning(['intan flicks (' num2str(obj.Intan.flick_s_wrtc) ') | CED ' num2str(obj.GLM.flick_s_wrtc) '. This is mismatched???'])
                       end
                   catch
                   end
                   flick_s_wrtc = obj.GLM.flick_s_wrtc(1:end);
                   obj.Intan.sync.flick_timeDiff_Intan_minus_CED = obj.Intan.flick_s_wrtc(1:numel(flick_s_wrtc)) - flick_s_wrtc;
               end

               lampOff_CED = obj.GLM.lampOff_s(1:numel(obj.Intan.lampOff_s));
               obj.Intan.sync.lampOff_timeDiff_Intan_minus_CED = obj.Intan.lampOff_s - lampOff_CED;           
           end
        end
        function suppressNsaveFigure(obj, Folder, FigureName, f)
            % 
            %   Input the directory to save to
            %   Figure name will go between:
            %       FigureName_Mousename_signal_day_timestamp.fig
            % 
            tstamp = datestr(now, 'yyyy_mm_dd_HHMM');
            filename = [FigureName, '_' obj.iv.filename_(1:end-1) '_' tstamp '.fig'];
            f.Name = filename;

            retdir = pwd;
            cd(Folder)
            filename = regexprep(filename, ':', '-');
            print(f,'-depsc','-painters', [filename, '.eps'])
            savefig(f, filename);
            close(f);
            cd(retdir);
        end
        function [f,ax] = plotESP(obj, Mode, bins, smoothing, inset, Order)
            % 
            %   An updated version of the plot function from photometry obj 
            % 
            if nargin < 6, Order = 'last-to-first';end
            if nargin < 5, inset = false; end
            if nargin < 4, smoothing = 0; end
            [f,ax] = obj.plot(Mode, bins, inset, smoothing, Order, true);
            mid = strjoin(strsplit(obj.iv.filename_,{'_', '.'}), ' ');
            Title = [mid ' | Unit ' num2str(obj.ts.unitNo), ' Ch ' num2str(obj.ts.channels') ' | ' Mode];
            title(ax, Title)
            set(f, 'userdata', ['obj.plotESP(' Mode ', ' mat2str(bins) ', ' num2str(smoothing) ' | s_per_bin: ' num2str(obj.ts.s_per_bin)])
            xlabel(ax,'time (s)')
            ylabel(ax,'Hz')
            switch Mode
            case 'cta'
                xlim(ax,[-3,8])
            case 'cta2l'
                xlim(ax,[-3,7])
            case 'lta'
                xlim(ax,[-8,3])
            case 'lta2l'
                xlim(ax,[-7,3])
            case 'clta'
                xlim(ax,[-3,8])
            end
            if ~strcmpi(Mode, 'clta')
                nc = (numel(bins)+1)*(numel(bins)>=10) + (numel(bins)<10)*10;
                C = linspecer(nc);
                iix = ceil(linspace(1,nc, numel(bins)+1));
                
                if strcmpi(Order, 'last-to-first')
                    C = [flipud(C(iix,:))];
                else
                    C = C(iix,:);
                end
                set(ax, 'ColorOrder', C);
            end
            legend(ax,'location', 'best')

            if strcmp(obj.iv.exptype_, 'Suyang self-initiated press task')
                obj.alert('achtung', 'WARNING!! This is a Suyang dataset!! \n-- we are pretending that press-ON is a lick and press-OFF \nis the cue to make plotting simpler. \nBut NB this is not plotting licks or cues, even if using LTA! \nIt''s press on wrt last press off')
            end
        end



        % stimulation functions
        function boot_ecdf = boot_ecdf_helper(obj,boot_data_row, boot_ecdf, ecdf_X)
            % boot_ecdf = obj.boot_ecdf_helper(boot_stim(ii,:), stim_X)
            [e_remapped, ix_remapped] = obj.remap_boot_ecdf(boot_data_row, ecdf_X);
            boot_ecdf(ix_remapped) = e_remapped;
            if isnan(boot_ecdf(1)), boot_ecdf(1) = 0;end
            if isnan(boot_ecdf(end)), boot_ecdf(end) = 1;end
            boot_ecdf = fillmissing(boot_ecdf,'previous');
        end
        function [stim_flicks,unstim_flicks,stim_nexttrial_flicks,unstim_nexttrial_flicks,stim_nexttrial_flicks2,unstim_nexttrial_flicks2,f] = plotStimulation(obj, compositeMode, NoLickMode, plotFigs)
            if nargin < 4, plotFigs = true;end
            if nargin < 3, NoLickMode = false;end
            if nargin <2 || isempty(compositeMode), compositeMode = false;end
            if ~isfield(obj.ChR2, 'stimMode'), obj.alert('achtung', 'obj.ChR2.stimMode should be either stim or sham. this plotting function is designed for stimulation sessions.');obj.ChR2.stimMode = 'assume stim'; end
            % 
            %   We will plot a histogram overlay of the stim and unstim distributions. 
            %   We will also plot the eCDF
            % 
            match_MBI_mode = false; % this is to try to check against the mousebehaviorinterface plot -- looks ok!

            stimcolor = [0.3,0.7,1];
            Edges = 0:0.5:17;
            nboot = 1000;

            if ~compositeMode
                obj.getflickswrtc();
            end
            allflicks = [obj.GLM.flick_s_wrtc; nan; nan];
            if NoLickMode
                allflicks(isnan(allflicks)) = 18.5; % sets all trials with no-lick to 18.5
                allflicks(obj.iv.exclusions_struct.Excluded_Trials) = nan; % set all excluded trials back to nan
            end

            if match_MBI_mode
                warning('match_MBI_mode on. you probably don''t want this')
                allflicks(allflicks<=0.5) = nan;
            end

            if ~compositeMode
                stim_flicks = allflicks(obj.GLM.stimTrials);
                unstim_flicks = allflicks(obj.GLM.noStimTrials);
                stim_nexttrial_flicks = allflicks(obj.GLM.stimTrials+1);
                stim_nexttrial_flicks(isnan(allflicks(obj.GLM.stimTrials)))=nan;
                %% Consider setting nan if the sti crrent was nan!!!
                obj.GLM.NANFLAG = true; % added 3-20-24 to elininate pairs fron cdf that shold be excl
                unstim_nexttrial_flicks = allflicks(obj.GLM.noStimTrials+1);
                unstim_nexttrial_flicks(isnan(allflicks(obj.GLM.noStimTrials)))=nan;
                stim_nexttrial_flicks2 = allflicks(obj.GLM.stimTrials+2);
                stim_nexttrial_flicks2(isnan(allflicks(obj.GLM.stimTrials)))=nan;
                unstim_nexttrial_flicks2 = allflicks(obj.GLM.noStimTrials+2);
                unstim_nexttrial_flicks2(isnan(allflicks(obj.GLM.noStimTrials)))=nan;

                obj.GLM.stim_flicks = stim_flicks;
                obj.GLM.unstim_flicks = unstim_flicks;
                obj.GLM.stim_nexttrial_flicks = stim_nexttrial_flicks;
                obj.GLM.unstim_nexttrial_flicks = unstim_nexttrial_flicks;
                obj.GLM.stim_nexttrial_flicks2 = stim_nexttrial_flicks2;
                obj.GLM.unstim_nexttrial_flicks2 = unstim_nexttrial_flicks2;
            else
                stim_flicks = obj.GLM.stim_flicks;
                unstim_flicks = obj.GLM.unstim_flicks;
                stim_nexttrial_flicks = obj.GLM.stim_nexttrial_flicks;
                unstim_nexttrial_flicks = obj.GLM.unstim_nexttrial_flicks;
                stim_nexttrial_flicks2 = obj.GLM.stim_nexttrial_flicks2;
                unstim_nexttrial_flicks2 = obj.GLM.unstim_nexttrial_flicks2;
            end

            
            if ~compositeMode
                obj.plotScatterStim(unstim_flicks,unstim_nexttrial_flicks,stim_flicks,stim_nexttrial_flicks, stimcolor, allflicks);
            end

            stim_flicks(isnan(stim_flicks)) = [];
            unstim_flicks(isnan(unstim_flicks)) = [];            
            [stim_ecdf,stim_X] = ecdf(stim_flicks);
            [unstim_ecdf,unstim_X] = ecdf(unstim_flicks);

            stim_nexttrial_flicks(isnan(stim_nexttrial_flicks)) = [];
            unstim_nexttrial_flicks(isnan(unstim_nexttrial_flicks)) = [];
            [stim_nt_ecdf,stim_nt_X] = ecdf(stim_nexttrial_flicks);
            [unstim_nt_ecdf,unstim_nt_X] = ecdf(unstim_nexttrial_flicks);

            
            stim_nexttrial_flicks2(isnan(stim_nexttrial_flicks2)) = [];
            unstim_nexttrial_flicks2(isnan(unstim_nexttrial_flicks2)) = [];
            [stim_nt_ecdf2,stim_nt_X2] = ecdf(stim_nexttrial_flicks2);
            [unstim_nt_ecdf2,unstim_nt_X2] = ecdf(unstim_nexttrial_flicks2);

            boot_stim = obj.bootdata(stim_flicks, nboot);boot_stim_ecdf = nan(nboot, numel(stim_X));
            boot_unstim = obj.bootdata(unstim_flicks, nboot);boot_unstim_ecdf = nan(nboot, numel(unstim_X));
            
            boot_stim_nt = obj.bootdata(stim_nexttrial_flicks, nboot);boot_stim_nt_ecdf = nan(nboot, numel(stim_nt_X));
            boot_unstim_nt = obj.bootdata(unstim_nexttrial_flicks, nboot);boot_unstim_nt_ecdf = nan(nboot, numel(unstim_nt_X));
            
            boot_stim_nt2 = obj.bootdata(stim_nexttrial_flicks2, nboot);boot_stim_nt_ecdf2 = nan(nboot, numel(stim_nt_X2));
            boot_unstim_nt2 = obj.bootdata(unstim_nexttrial_flicks2, nboot);boot_unstim_nt_ecdf2 = nan(nboot, numel(unstim_nt_X2));
            
            for ii = 1:nboot
                % have to account for fact x's will get duplicated when sampling with replacement
                boot_stim_ecdf(ii,:)  = obj.boot_ecdf_helper(boot_stim(ii,:), boot_stim_ecdf(ii,:), stim_X);
                boot_unstim_ecdf(ii,:)  = obj.boot_ecdf_helper(boot_unstim(ii,:), boot_unstim_ecdf(ii,:), unstim_X);
                boot_stim_nt_ecdf(ii,:)  = obj.boot_ecdf_helper(boot_stim_nt(ii,:), boot_stim_nt_ecdf(ii,:), stim_nt_X);
                boot_unstim_nt_ecdf(ii,:)  = obj.boot_ecdf_helper(boot_unstim_nt(ii,:), boot_unstim_nt_ecdf(ii,:), unstim_nt_X);
                boot_stim_nt_ecdf2(ii,:)  = obj.boot_ecdf_helper(boot_stim_nt2(ii,:), boot_stim_nt_ecdf2(ii,:), stim_nt_X2);
                boot_unstim_nt_ecdf2(ii,:)  = obj.boot_ecdf_helper(boot_unstim_nt2(ii,:), boot_unstim_nt_ecdf2(ii,:), unstim_nt_X2);
            end
            [ci_l_stim_ecdf, ci_u_stim_ecdf] = obj.bootCI(boot_stim_ecdf, 0.05);
            [ci_l_unstim_ecdf, ci_u_unstim_ecdf] = obj.bootCI(boot_unstim_ecdf, 0.05);

            [ci_l_stim_nt_ecdf, ci_u_stim_nt_ecdf] = obj.bootCI(boot_stim_nt_ecdf, 0.05);
            [ci_l_unstim_nt_ecdf, ci_u_unstim_nt_ecdf] = obj.bootCI(boot_unstim_nt_ecdf, 0.05);

            [ci_l_stim_nt_ecdf2, ci_u_stim_nt_ecdf2] = obj.bootCI(boot_stim_nt_ecdf2, 0.05);
            [ci_l_unstim_nt_ecdf2, ci_u_unstim_nt_ecdf2] = obj.bootCI(boot_unstim_nt_ecdf2, 0.05);

            if plotFigs
                [f,ax] = makeStandardFigure(6, [3, 2]);
                prettyHxg(ax(1), unstim_flicks, 'no stim trials', 'k', Edges);
                prettyHxg(ax(1), stim_flicks, [obj.ChR2.stimMode ' trials'], stimcolor, Edges);
                title(ax(1), 'Current trial')

                plot(ax(2), unstim_X, unstim_ecdf, 'k-', 'linewidth',3, 'DisplayName', 'no stim')
                plot(ax(2), unstim_X, ci_l_unstim_ecdf, 'k-', 'linewidth',1, 'DisplayName', 'no stim 95%CI')
                plot(ax(2), unstim_X, ci_u_unstim_ecdf, 'k-', 'linewidth',1, 'DisplayName', 'no stim 95%CI')
                plot(ax(2), stim_X, stim_ecdf, '-', 'color', stimcolor, 'linewidth',3, 'DisplayName', 'stim')
                plot(ax(2), stim_X, ci_l_stim_ecdf, '-', 'color', stimcolor,'linewidth',1, 'DisplayName', 'stim 95%CI')
                plot(ax(2), stim_X, ci_u_stim_ecdf, '-', 'color', stimcolor,'linewidth',1, 'DisplayName', 'stim 95%CI')
                title(ax(2), 'Current trial')

                prettyHxg(ax(3), unstim_nexttrial_flicks, 'no stim trials', 'k', Edges);
                prettyHxg(ax(3), stim_nexttrial_flicks, [obj.ChR2.stimMode ' trials'], stimcolor, Edges);
                title(ax(3), 'Next trial')

                plot(ax(4), unstim_nt_X, unstim_nt_ecdf, 'k-', 'linewidth',3, 'DisplayName', 'no stim')
                plot(ax(4), unstim_nt_X, ci_l_unstim_nt_ecdf, 'k-', 'linewidth',1, 'DisplayName', 'stim 95%CI')
                plot(ax(4), unstim_nt_X, ci_u_unstim_nt_ecdf, 'k-', 'linewidth',1, 'DisplayName', 'stim 95%CI')
                plot(ax(4), stim_nt_X, stim_nt_ecdf, '-', 'color', stimcolor, 'linewidth',3, 'DisplayName', 'stim')
                plot(ax(4), stim_nt_X, ci_l_stim_nt_ecdf, '-', 'color', stimcolor,'linewidth',1, 'DisplayName', 'stim 95%CI')
                plot(ax(4), stim_nt_X, ci_u_stim_nt_ecdf, '-', 'color', stimcolor,'linewidth',1, 'DisplayName', 'stim 95%CI')
                title(ax(4), 'Next trial')

                prettyHxg(ax(5), unstim_nexttrial_flicks2, 'no stim trials', 'k', Edges);
                prettyHxg(ax(5), stim_nexttrial_flicks2, [obj.ChR2.stimMode ' trials'], stimcolor, Edges);
                title(ax(5), '2 trials forward')

                plot(ax(6), unstim_nt_X2, unstim_nt_ecdf2, 'k-', 'linewidth',3, 'DisplayName', 'no stim')
                plot(ax(6), unstim_nt_X2, ci_l_unstim_nt_ecdf2, 'k-', 'linewidth',1, 'DisplayName', 'stim 95%CI')
                plot(ax(6), unstim_nt_X2, ci_u_unstim_nt_ecdf2, 'k-', 'linewidth',1, 'DisplayName', 'stim 95%CI')
                plot(ax(6), stim_nt_X2, stim_nt_ecdf2, '-', 'color', stimcolor, 'linewidth',3, 'DisplayName', 'stim')
                plot(ax(6), stim_nt_X2, ci_l_stim_nt_ecdf2, '-', 'color', stimcolor,'linewidth',1, 'DisplayName', 'stim 95%CI')
                plot(ax(6), stim_nt_X2, ci_u_stim_nt_ecdf2, '-', 'color', stimcolor,'linewidth',1, 'DisplayName', 'stim 95%CI')
                title(ax(6), '2 trials forward')

                for ii = 1:6
                    legend(ax(ii), 'show')
                    if ismember(ii, [1,3,5])
                        xlim(ax(ii), [0,17])
                        xlabel(ax(ii),'time wrtc (s)')
                        ylabel(ax(ii),'# first-licks')
                    else
                        xlabel(ax(ii),'time wrtc (s)')
                        ylabel(ax(ii),'eCDF')
                    end
                end
                set(f, 'userdata', 'obj.plotStimulation')
            end

            
        end
        function [stim_flicks,unstim_flicks,stim_nexttrial_flicks,unstim_nexttrial_flicks,stim_nexttrial_flicks2,unstim_nexttrial_flicks2,f] = plotStimulation_collated(obj, NoLickMode, plotFigs)
            %
            %   USE THIS FOR COLLATED NOW! 12/17/23
            %
            if nargin < 3, plotFigs = true;end
            if nargin < 2, NoLickMode = false;end
            if ~isfield(obj.ChR2, 'stimMode'), obj.alert('achtung', 'obj.ChR2.stimMode should be either stim or sham. this plotting function is designed for stimulation sessions.');obj.ChR2.stimMode = 'assume stim'; end
            % 
            %   We will plot a histogram overlay of the stim and unstim distributions. 
            %   We will also plot the eCDF
            % 

            stimcolor = [0.3,0.7,1];
            Edges = 0:0.5:17;
            nboot = 1000;

            allflicks = obj.GLM.flick_s_wrtc;
            if NoLickMode
                allflicks(isnan(allflicks)) = 18.5; % sets all trials with no-lick to 18.5
            end
            ntrialsforward = obj.GLM.ntrialsforward;

            
            stim_flicks = obj.GLM.stim_flicks;
            unstim_flicks = obj.GLM.unstim_flicks;
            stim_nexttrial_flicks = obj.GLM.stim_nexttrial_flicks;
            unstim_nexttrial_flicks = obj.GLM.unstim_nexttrial_flicks;           

            stim_flicks(isnan(stim_flicks)) = [];
            unstim_flicks(isnan(unstim_flicks)) = [];            
            [stim_ecdf,stim_X] = ecdf(stim_flicks);
            [unstim_ecdf,unstim_X] = ecdf(unstim_flicks);

            stim_nexttrial_flicks(isnan(stim_nexttrial_flicks)) = [];
            unstim_nexttrial_flicks(isnan(unstim_nexttrial_flicks)) = [];
            [stim_nt_ecdf,stim_nt_X] = ecdf(stim_nexttrial_flicks);
            [unstim_nt_ecdf,unstim_nt_X] = ecdf(unstim_nexttrial_flicks);


            boot_stim = obj.bootdata(stim_flicks, nboot);boot_stim_ecdf = nan(nboot, numel(stim_X));
            boot_unstim = obj.bootdata(unstim_flicks, nboot);boot_unstim_ecdf = nan(nboot, numel(unstim_X));
            
            boot_stim_nt = obj.bootdata(stim_nexttrial_flicks, nboot);boot_stim_nt_ecdf = nan(nboot, numel(stim_nt_X));
            boot_unstim_nt = obj.bootdata(unstim_nexttrial_flicks, nboot);boot_unstim_nt_ecdf = nan(nboot, numel(unstim_nt_X));
            

            
            for ii = 1:nboot
                % have to account for fact x's will get duplicated when sampling with replacement
                boot_stim_ecdf(ii,:)  = obj.boot_ecdf_helper(boot_stim(ii,:), boot_stim_ecdf(ii,:), stim_X);
                boot_unstim_ecdf(ii,:)  = obj.boot_ecdf_helper(boot_unstim(ii,:), boot_unstim_ecdf(ii,:), unstim_X);
                boot_stim_nt_ecdf(ii,:)  = obj.boot_ecdf_helper(boot_stim_nt(ii,:), boot_stim_nt_ecdf(ii,:), stim_nt_X);
                boot_unstim_nt_ecdf(ii,:)  = obj.boot_ecdf_helper(boot_unstim_nt(ii,:), boot_unstim_nt_ecdf(ii,:), unstim_nt_X);
            end
            [ci_l_stim_ecdf, ci_u_stim_ecdf] = obj.bootCI(boot_stim_ecdf, 0.05);
            [ci_l_unstim_ecdf, ci_u_unstim_ecdf] = obj.bootCI(boot_unstim_ecdf, 0.05);

            [ci_l_stim_nt_ecdf, ci_u_stim_nt_ecdf] = obj.bootCI(boot_stim_nt_ecdf, 0.05);
            [ci_l_unstim_nt_ecdf, ci_u_unstim_nt_ecdf] = obj.bootCI(boot_unstim_nt_ecdf, 0.05);

            % get significant not overlap:
            n_interrogations = 1000;
            signif_diff_t0 = nan(1,n_interrogations);
            signif_diff_tn = nan(1,n_interrogations);
            interrogation_points = linspace(0.001,17, n_interrogations);%, linspace(3.301,7, n_interrogations/2)]';
            for i_query = 1:numel(interrogation_points)
                stim_point_left = find(stim_X <= interrogation_points(i_query), 1, 'last');
                stim_point_right = find(stim_X >= interrogation_points(i_query), 1, 'first');
                xright = stim_X(stim_point_right);
                xleft = stim_X(stim_point_left);
                yright = ci_l_stim_ecdf(stim_point_right);
                yleft = ci_l_stim_ecdf(stim_point_left);
                if isempty(xleft), xleft = 0;end
                if isempty(xright), xright = 17;end
                if isempty(yright), yright = 1;end
                if isempty(yleft), yleft = 0;end
                b = (yright-yleft)/(xright-xleft);
                interppoint_stim = yleft + b*(interrogation_points(i_query)-xleft);
                %            
                nostim_point_left = find(unstim_X <= interrogation_points(i_query), 1, 'last');
                nostim_point_right = find(unstim_X >= interrogation_points(i_query), 1, 'first');
                xright = unstim_X(nostim_point_right);
                xleft = unstim_X(nostim_point_left);
                yright = ci_u_unstim_ecdf(nostim_point_right);
                yleft = ci_u_unstim_ecdf(nostim_point_left);
                if isempty(xleft), xleft = 0;end
                if isempty(xright), xright = 17;end
                if isempty(yright), yright = 1;end
                if isempty(yleft), yleft = 0;end
                b = (yright-yleft)/(xright-xleft);
                interppoint_nostim = yleft + b*(interrogation_points(i_query)-xleft);
                %
                signif_diff_t0(i_query) = interppoint_nostim - interppoint_stim < 0;

                stim_point_left = find(stim_nt_X <= interrogation_points(i_query), 1, 'last');
                stim_point_right = find(stim_nt_X >= interrogation_points(i_query), 1, 'first');
                xright = stim_nt_X(stim_point_right);
                xleft = stim_nt_X(stim_point_left);
                yright = ci_l_stim_nt_ecdf(stim_point_right);
                yleft = ci_l_stim_nt_ecdf(stim_point_left);
                if isempty(xleft), xleft = 0;end
                if isempty(xright), xright = 17;end
                if isempty(yright), yright = 1;end
                if isempty(yleft), yleft = 0;end
                b = (yright-yleft)/(xright-xleft);
                interppoint_stim = yleft + b*(interrogation_points(i_query)-xleft);
                %            
                nostim_point_left = find(unstim_nt_X <= interrogation_points(i_query), 1, 'last');
                nostim_point_right = find(unstim_nt_X >= interrogation_points(i_query), 1, 'first');
                xright = unstim_nt_X(nostim_point_right);
                xleft = unstim_nt_X(nostim_point_left);
                yright = ci_u_unstim_nt_ecdf(nostim_point_right);
                yleft = ci_u_unstim_nt_ecdf(nostim_point_left);
                if isempty(xleft), xleft = 0;end
                if isempty(xright), xright = 17;end
                if isempty(yright), yright = 1;end
                if isempty(yleft), yleft = 0;end
                b = (yright-yleft)/(xright-xleft);
                interppoint_nostim = yleft + b*(interrogation_points(i_query)-xleft);
                %
                signif_diff_tn(i_query) = interppoint_nostim - interppoint_stim < 0;
            end

            signif_diff_t0 = double(signif_diff_t0);
            signif_diff_tn = double(signif_diff_tn);
            signif_diff_t0(signif_diff_t0<1) = nan;
            signif_diff_tn(signif_diff_tn<1) = nan;


            if plotFigs
                [f,ax] = makeStandardFigure(4, [2, 2]);
                set(f, 'userdata',obj.setUserDataStandards(['obj.plotStimulation_collated(NoLickMode=' num2str(NoLickMode) ')'], f),...
                    'name', [obj.iv.nmice, ' mice | ' obj.iv.nsesh, ' sesh | using ' num2str(ntrialsforward) ' trials forward, COMPOSITE'])
                prettyHxg(ax(1), unstim_flicks, 'no stim trials', 'k', Edges);
                prettyHxg(ax(1), stim_flicks, [obj.ChR2.stimMode ' trials'], stimcolor, Edges);
                title(ax(1), 'Current trial')

                plot(ax(2), unstim_X, unstim_ecdf, 'k-', 'linewidth',3, 'DisplayName', 'no stim')
                plot(ax(2), unstim_X, ci_l_unstim_ecdf, 'k-', 'linewidth',1, 'DisplayName', 'no stim 95%CI')
                plot(ax(2), unstim_X, ci_u_unstim_ecdf, 'k-', 'linewidth',1, 'DisplayName', 'no stim 95%CI')
                plot(ax(2), stim_X, stim_ecdf, '-', 'color', stimcolor, 'linewidth',3, 'DisplayName', 'stim')
                plot(ax(2), stim_X, ci_l_stim_ecdf, '-', 'color', stimcolor,'linewidth',1, 'DisplayName', 'stim 95%CI')
                plot(ax(2), stim_X, ci_u_stim_ecdf, '-', 'color', stimcolor,'linewidth',1, 'DisplayName', 'stim 95%CI')
                title(ax(2), 'Current trial')
                plot(ax(2), interrogation_points,signif_diff_t0, 'g-')
                

                prettyHxg(ax(3), unstim_nexttrial_flicks, 'no stim trials', 'k', Edges);
                prettyHxg(ax(3), stim_nexttrial_flicks, [obj.ChR2.stimMode ' trials'], stimcolor, Edges);
                title(ax(3), 'Next trial')

                plot(ax(4), unstim_nt_X, unstim_nt_ecdf, 'k-', 'linewidth',3, 'DisplayName', 'no stim')
                plot(ax(4), unstim_nt_X, ci_l_unstim_nt_ecdf, 'k-', 'linewidth',1, 'DisplayName', 'stim 95%CI')
                plot(ax(4), unstim_nt_X, ci_u_unstim_nt_ecdf, 'k-', 'linewidth',1, 'DisplayName', 'stim 95%CI')
                plot(ax(4), stim_nt_X, stim_nt_ecdf, '-', 'color', stimcolor, 'linewidth',3, 'DisplayName', 'stim')
                plot(ax(4), stim_nt_X, ci_l_stim_nt_ecdf, '-', 'color', stimcolor,'linewidth',1, 'DisplayName', 'stim 95%CI')
                plot(ax(4), stim_nt_X, ci_u_stim_nt_ecdf, '-', 'color', stimcolor,'linewidth',1, 'DisplayName', 'stim 95%CI')
                title(ax(4), 'Next trial')
                plot(ax(4), interrogation_points,signif_diff_tn, 'g-')


                for ii = 1:4
                    legend(ax(ii), 'show')
                    if ismember(ii, [1,3,5])
                        xlim(ax(ii), [0,17])
                        xlabel(ax(ii),'time wrtc (s)')
                        ylabel(ax(ii),'# first-licks')
                    else
                        xlabel(ax(ii),'time wrtc (s)')
                        ylabel(ax(ii),'eCDF')
                    end
                    xlim(ax(ii), [0,7])
                end
            end
            
            
        end
        function plotScatterStim(obj, unstim_flicks,unstim_nexttrial_flicks,stim_flicks,stim_nexttrial_flicks, stimcolor, allflicks)
            [f2,ax2] = makeStandardFigure(9,[3,3]);

            % scatter plot
            scatter(ax2(1), unstim_flicks, unstim_nexttrial_flicks, 30, [0.7,0.7,0.7], 'filled', 'DisplayName', 'non-stimulated trial n', 'MarkerFaceAlpha',0.4);
            scatter(ax2(1), stim_flicks, stim_nexttrial_flicks, 30, stimcolor, 'filled', 'DisplayName', 'stimulated trial n', 'MarkerFaceAlpha',0.4);
            plot(ax2(1), [0.5, 0.5],[0,17], 'k--')
            plot(ax2(1), [0,17], [0.5, 0.5],'k--')
            plot(ax2(1), [0,17], [0,17], 'k--')
            xlim(ax2(1), [0,17])
            ylim(ax2(1), [0,17])
            xlabel(ax2(1),'this trial')
            ylabel(ax2(1),'next trial')


            % top row distributions            
            
            notisearly = allflicks >3.333;
            mask = allflicks;
            mask(notisearly) = nan;
            stim_flicks_early = mask(obj.GLM.stimTrials);
            unstim_flicks_early = mask(obj.GLM.noStimTrials);
            prettyHxg(ax2(2), stim_flicks_early - stim_nexttrial_flicks, 'stim n-(n+1)',stimcolor,-17:0.5:3.5);
            prettyHxg(ax2(2), unstim_flicks_early - unstim_nexttrial_flicks, 'unstim n-(n+1)',[0.2,0.2,0.2],-14:0.5:7);
            mean_stim = nanmean(stim_flicks_early - stim_nexttrial_flicks);
            mean_nostim = nanmean(unstim_flicks_early - unstim_nexttrial_flicks);
            yy = get(ax2(2), 'ylim');
            plot(ax2(2), [mean_stim, mean_stim], yy, 'b--', 'displayname', 'stim mean');
            plot(ax2(2), [mean_nostim, mean_nostim], yy, 'k--', 'displayname', 'nostim mean');
            xlabel(ax2(2),'trial n - trial (n+1) [neg: move later]')
            ylabel(ax2(2),'p')
            title(ax2(2),'unrewarded trial n')


            % look only at rewarded trials
            notisrew = allflicks <3.333 | allflicks >7.0;
            mask = allflicks;
            mask(notisrew) = nan;
            stim_flicks_rew = mask(obj.GLM.stimTrials);
            unstim_flicks_rew = mask(obj.GLM.noStimTrials);
            prettyHxg(ax2(3), stim_flicks_rew - stim_nexttrial_flicks, 'stim n-(n+1)',stimcolor,-17:0.5:3.5);
            prettyHxg(ax2(3), unstim_flicks_rew - unstim_nexttrial_flicks, 'unstim n-(n+1)',[0.2,0.2,0.2],-14:0.5:7);
            xlabel(ax2(3),'trial n - trial (n+1) [neg: move later]')
            ylabel(ax2(3),'p')
            title(ax2(3),'rewarded trial n')
            mean_stim = nanmean(stim_flicks_rew - stim_nexttrial_flicks);
            mean_nostim = nanmean(unstim_flicks_rew - unstim_nexttrial_flicks);
            yy = get(ax2(3), 'ylim');
            plot(ax2(3), [mean_stim, mean_stim], yy, 'b--', 'displayname', 'stim mean');
            plot(ax2(3), [mean_nostim, mean_nostim], yy, 'k--', 'displayname', 'nostim mean');



            % middle row distributions  
            notisearly = allflicks >3.333 | allflicks <0.5;
            mask = allflicks;
            mask(notisearly) = nan;
            stim_flicks_early = mask(obj.GLM.stimTrials);
            unstim_flicks_early = mask(obj.GLM.noStimTrials);
            
            
            % scatter plot
            scatter(ax2(4), unstim_flicks_early, unstim_nexttrial_flicks, 30, [0.7,0.7,0.7], 'filled', 'DisplayName', 'non-stimulated trial n', 'MarkerFaceAlpha',0.4);
            scatter(ax2(4), stim_flicks_early, stim_nexttrial_flicks, 30, stimcolor, 'filled', 'DisplayName', 'stimulated trial n', 'MarkerFaceAlpha',0.4);
            plot(ax2(4), [0.5, 0.5],[0,17], 'k--')
            plot(ax2(4), [0,17], [0.5, 0.5],'k--')
            plot(ax2(4), [0,17], [0,17], 'k--')
            xlim(ax2(4), [0,17])
            ylim(ax2(4), [0,17])
            xlabel(ax2(4),'this trial')
            ylabel(ax2(4),'next trial')

            
            prettyHxg(ax2(5), stim_flicks_early - stim_nexttrial_flicks, 'stim n-(n+1)',stimcolor,-17:0.5:3.5);
            prettyHxg(ax2(5), unstim_flicks_early - unstim_nexttrial_flicks, 'unstim n-(n+1)',[0.2,0.2,0.2],-14:0.5:7);
            mean_stim = nanmean(stim_flicks_early - stim_nexttrial_flicks);
            mean_nostim = nanmean(unstim_flicks_early - unstim_nexttrial_flicks);
            yy = get(ax2(5), 'ylim');
            plot(ax2(5), [mean_stim, mean_stim], yy, 'b--', 'displayname', 'stim mean');
            plot(ax2(5), [mean_nostim, mean_nostim], yy, 'k--', 'displayname', 'nostim mean');
            xlabel(ax2(5),'trial n - trial (n+1) [neg: move later]')
            ylabel(ax2(5),'p')
            title(ax2(5),'EXCL rxn n; unrew trial n')

            delete(ax2(6))



            % no rxns on n or n+1
            notisearly = allflicks >3.333 | allflicks <0.5;
            mask = allflicks;
            mask(notisearly) = nan;
            stim_flicks_early = mask(obj.GLM.stimTrials);
            unstim_flicks_early = mask(obj.GLM.noStimTrials);
            isrxn_nexttrial = [allflicks(2:end) <0.5; 0];
            mask = [allflicks(2:end); nan];
            mask(logical(isrxn_nexttrial)) = nan;
            unstim_nexttrial_flicks_norxn = mask(obj.GLM.noStimTrials);
            stim_nexttrial_flicks_norxn = mask(obj.GLM.stimTrials);



            scatter(ax2(7), unstim_flicks_early, unstim_nexttrial_flicks_norxn, 30, [0.7,0.7,0.7], 'filled', 'DisplayName', 'non-stimulated trial n', 'MarkerFaceAlpha',0.4);
            scatter(ax2(7), stim_flicks_early, stim_nexttrial_flicks_norxn, 30, stimcolor, 'filled', 'DisplayName', 'stimulated trial n', 'MarkerFaceAlpha',0.4);
            scatter(ax2(7), unstim_flicks_rew, unstim_nexttrial_flicks_norxn, 30, [0.7,0.7,0.7], 'filled', 'DisplayName', 'non-stimulated trial n', 'MarkerFaceAlpha',0.4);
            scatter(ax2(7), stim_flicks_rew, stim_nexttrial_flicks_norxn, 30, stimcolor, 'filled', 'DisplayName', 'stimulated trial n', 'MarkerFaceAlpha',0.4);
            plot(ax2(7), [0.5, 0.5],[0,17], 'k--')
            plot(ax2(7), [0,17], [0.5, 0.5],'k--')
            plot(ax2(7), [0,17], [0,17], 'k--')
            xlim(ax2(7), [0,17])
            ylim(ax2(7), [0,17])
            xlabel(ax2(7),'this trial')
            ylabel(ax2(7),'next trial')


            prettyHxg(ax2(8), stim_flicks_early - stim_nexttrial_flicks_norxn, 'stim n-(n+1)',stimcolor,-17:0.5:3.5);
            prettyHxg(ax2(8), unstim_flicks_early - unstim_nexttrial_flicks_norxn, 'unstim n-(n+1)',[0.2,0.2,0.2],-14:0.5:7);
            mean_stim = nanmean(stim_flicks_early - stim_nexttrial_flicks_norxn);
            mean_nostim = nanmean(unstim_flicks_early - unstim_nexttrial_flicks_norxn);
            yy = get(ax2(8), 'ylim');
            plot(ax2(8), [mean_stim, mean_stim], yy, 'b--', 'displayname', 'stim mean');
            plot(ax2(8), [mean_nostim, mean_nostim], yy, 'k--', 'displayname', 'nostim mean');
            xlabel(ax2(8),'trial n - trial (n+1) [neg: move later]')
            ylabel(ax2(8),'p')
            title(ax2(8),'EXCL rxn n, n+1; unrew trial n')


            prettyHxg(ax2(9), stim_flicks_rew - stim_nexttrial_flicks_norxn, 'stim n-(n+1)',stimcolor,-17:0.5:3.5);
            prettyHxg(ax2(9), unstim_flicks_rew - unstim_nexttrial_flicks_norxn, 'unstim n-(n+1)',[0.2,0.2,0.2],-14:0.5:7);
            mean_stim = nanmean(stim_flicks_rew - stim_nexttrial_flicks_norxn);
            mean_nostim = nanmean(unstim_flicks_rew - unstim_nexttrial_flicks_norxn);
            yy = get(ax2(9), 'ylim');
            plot(ax2(9), [mean_stim, mean_stim], yy, 'b--', 'displayname', 'stim mean');
            plot(ax2(9), [mean_nostim, mean_nostim], yy, 'k--', 'displayname', 'nostim mean');
            xlabel(ax2(9),'trial n - trial (n+1) [neg: move later]')
            ylabel(ax2(9),'p')
            title(ax2(9),'EXCL rxn n, n+1; rew trial n')
        end
        function plotDelTimeVsTrialNByStim(obj, compositeMode,plotFigs)
            % 
            %   Goal is we want to pool trials by movement time on trial n and then find the change in movement time on the next trial...
            %  
            if nargin < 3, plotFigs = true;end
            if nargin < 2, compositeMode = false;end 
            nbins = 34;
            stimcolor = [0.3,0.7,1];
            bin_edges = linspace(0,17, nbins+1);
            if ~compositeMode
                obj.getflickswrtc();
            end
            allflicks = [obj.GLM.flick_s_wrtc; nan; nan];
            stim_flicks = allflicks;
            stim_flicks(obj.GLM.noStimTrials) = nan;
            unstim_flicks = allflicks;
            unstim_flicks(obj.GLM.stimTrials) = nan;

            stim_nexttrial_flicks = nan(size(allflicks));
            stim_nexttrial2_flicks = nan(size(allflicks));
            stim_nexttrial_flicks(obj.GLM.stimTrials) = allflicks(obj.GLM.stimTrials+1);
            stim_nexttrial2_flicks(obj.GLM.stimTrials) = allflicks(obj.GLM.stimTrials+2);

            unstim_nexttrial_flicks = nan(size(allflicks));
            unstim_nexttrial2_flicks = nan(size(allflicks));
            unstim_nexttrial_flicks(obj.GLM.noStimTrials) = allflicks(obj.GLM.noStimTrials+1);
            unstim_nexttrial2_flicks(obj.GLM.noStimTrials) = allflicks(obj.GLM.noStimTrials+2);
            

            del_allflicks = allflicks(2:end) - allflicks(1:end-1);
            del_stim_flicks = stim_nexttrial_flicks - stim_flicks;
            del_unstim_flicks = unstim_nexttrial_flicks - unstim_flicks;
            if plotFigs
                [f,ax] = makeStandardFigure(3, [1,3]);

                plot(ax(1), [0,18.5], [0,-18.5], '--', 'color', [0.3,0.3, 0.3])
                plot(ax(1), [0,18.5], [18.5,0], '--', 'color', [0.3,0.3, 0.3])

                scatter(ax(1), allflicks(1:end-1), del_allflicks, 50, [0,0.,0.], 'filled');
                scatter(ax(1), unstim_flicks, del_unstim_flicks, 20, [0.7,0.7,0.7], 'filled');
                plot(ax(1), [0,18.5], [0,0], '--', 'color', [0.3,0.3, 0.3])
                scatter(ax(1), stim_flicks, del_stim_flicks, 20, stimcolor, 'filled');
                ylabel(ax(1),'del (s, +: moved later on next trial)')
                xlabel(ax(1),'trial n lick time')
            end

            [~,~,pool_no] = histcounts(allflicks, bin_edges);

            for ipool = 1:nbins
                % get the mean and median of the pool
                mean_del_all(ipool) = nanmean(del_allflicks(pool_no == ipool));
                median_del_all(ipool) = nanmedian(del_allflicks(pool_no == ipool));

                mean_del_stim(ipool) = nanmean(del_stim_flicks(pool_no == ipool));
                median_del_stim(ipool) = nanmedian(del_stim_flicks(pool_no == ipool));
                
                mean_del_unstim(ipool) = nanmean(del_unstim_flicks(pool_no == ipool));
                median_del_unstim(ipool) = nanmedian(del_unstim_flicks(pool_no == ipool));
            end


            xx = linspace(0,17, nbins+1)+(17/nbins)/2;
            xx = xx(1:end-1);

            if plotFigs
                bar(ax(2), xx, mean_del_all, 0.5, 'edgecolor', 'k', 'facecolor', 'k', 'linewidth', 3, 'displayname', 'all');
                bar(ax(2), xx, mean_del_unstim, 0.5,'edgecolor',[0.2,0.2,0.2], 'facecolor', 'none', 'linewidth', 3, 'displayname', 'no-stim');
                bar(ax(2), xx, mean_del_stim, 0.5, 'edgecolor',stimcolor, 'facecolor', 'none', 'linewidth', 3, 'displayname', 'stim');
                xlim(ax(2), [0,7])
                yy = get(ax(2), 'ylim');
                plot(ax(2), [0.5,0.5], yy, 'k-', 'handlevisibility', 'off')
                plot(ax(2), [3.333,3.333], yy, 'k-', 'handlevisibility', 'off')
                plot(ax(2), [0,18.5], [0,-18.5], '--', 'color', [0.7,0.7, 0.7], 'handlevisibility', 'off')
                plot(ax(2), [0,18.5], [18.5,0], '--', 'color', [0.7,0.7, 0.7], 'handlevisibility', 'off')
                plot(ax(2), [0,18.5], [18.5,0], '--', 'color', [0.3,0.3, 0.3], 'displayname', 'limit');
                meanlicktime = nanmean(unstim_flicks);
                del_reg_to_mean = meanlicktime-xx;
                plot(ax(2), xx, del_reg_to_mean, 'r--', 'displayname', 'reg. to mean, no-stim trials')
                plot(ax(2), [0,18.5], [0,-18.5], '--', 'color', [0.3,0.3, 0.3], 'handlevisibility', 'off')
                plot(ax(2), [0,18.5], [18.5,0], '--', 'color', [0.3,0.3, 0.3], 'handlevisibility', 'off')
                ylim(ax(2), yy);
                ylabel(ax(2), 'del (s, +: moved later on next trial)')
                xlabel(ax(2), 'lick time, trial n')
                legend(ax(2),'show')
                title(ax(2), 'mean del')


            
                bar(ax(3), xx, median_del_all, 0.5, 'edgecolor', 'k', 'facecolor', 'k', 'linewidth', 3, 'displayname', 'all');
                bar(ax(3), xx, median_del_unstim, 0.5,'edgecolor',[0.2,0.2,0.2], 'facecolor', 'none', 'linewidth', 3, 'displayname', 'no-stim');
                bar(ax(3), xx, median_del_stim, 0.5, 'edgecolor',stimcolor, 'facecolor', 'none', 'linewidth', 3, 'displayname', 'stim');
                xlim(ax(3), [0,7])
                yy = get(ax(3), 'ylim');
                plot(ax(3), [0.5,0.5], yy, 'k-', 'handlevisibility', 'off')
                plot(ax(3), [3.333,3.333], yy, 'k-', 'handlevisibility', 'off')
                plot(ax(3), [0,18.5], [0,-18.5], '--', 'color', [0.7,0.7, 0.7], 'handlevisibility', 'off')
                plot(ax(3), [0,18.5], [18.5,0], '--', 'color', [0.7,0.7, 0.7], 'handlevisibility', 'off')
                plot(ax(3), [0,18.5], [18.5,0], '--', 'color', [0.3,0.3, 0.3], 'displayname', 'limit');
                meanlicktime = nanmean(unstim_flicks);
                del_reg_to_mean = meanlicktime-xx;
                plot(ax(3), xx, del_reg_to_mean, 'r--', 'displayname', 'reg. to mean, no-stim trials')
                plot(ax(3), [0,18.5], [0,-18.5], '--', 'color', [0.3,0.3, 0.3], 'handlevisibility', 'off')
                plot(ax(3), [0,18.5], [18.5,0], '--', 'color', [0.3,0.3, 0.3], 'handlevisibility', 'off')
                ylim(ax(3), yy);
                ylabel(ax(3), 'del (s, +: moved later on next trial)')
                xlabel(ax(3), 'lick time, trial n')
                legend(ax(3),'show')
                title(ax(3), 'median del')
            end

        end
        function plotDelTimeVsTrialNByStim_collated(obj,plotFigs)
            %   USE THIS FOR COLLATED DATA NOW 12-17-23
            % 
            %   Goal is we want to pool trials by movement time on trial n and then find the change in movement time on the next trial...
            %  
            if nargin < 2, plotFigs = true;end
            nbins = 34;
            stimcolor = [0.3,0.7,1];
            bin_edges = linspace(0,17, nbins+1);

            allflicks = obj.GLM.flick_s_wrtc;
            stim_flicks = obj.GLM.stim_flicks;
            unstim_flicks = obj.GLM.unstim_flicks;
            n = obj.GLM.ntrialsforward;

            stim_nexttrial_flicks = obj.GLM.stim_ntrialforward_flicks;
            unstim_nexttrial_flicks = obj.GLM.unstim_ntrialforward_flicks;
            
            del_allflicks = allflicks(2:end) - allflicks(1:end-1); 
            del_stim_flicks = stim_nexttrial_flicks - stim_flicks;
            del_unstim_flicks = unstim_nexttrial_flicks - unstim_flicks;
            if plotFigs
                [f,ax] = makeStandardFigure(3, [1,3]);
                set(f, 'position', [0.3208    0.1811    0.5924    0.6967])
                set(f, 'userdata', obj.setUserDataStandards('obj.plotDelTimeVsTrialNByStim_collated(true)', f),...
                    'name', [obj.iv.nmice, ' mice | ' obj.iv.nsesh, ' sesh | using ' num2str(n), ' trials forward'])

                plot(ax(1), [0,18.5], [0,-18.5], '--', 'color', [0.3,0.3, 0.3])
                plot(ax(1), [0,18.5], [18.5,0], '--', 'color', [0.3,0.3, 0.3])

                scatter(ax(1), allflicks(1:end-1), del_allflicks, 50, [0,0.,0.], 'filled');
                scatter(ax(1), unstim_flicks, del_unstim_flicks, 20, [0.7,0.7,0.7], 'filled');
                plot(ax(1), [0,18.5], [0,0], '--', 'color', [0.3,0.3, 0.3])
                scatter(ax(1), stim_flicks, del_stim_flicks, 20, stimcolor, 'filled');
                ylabel(ax(1),'del (s, +: moved later on next trial)')
                xlabel(ax(1),'trial n lick time')
            end

            [~,~,pool_no] = histcounts(allflicks, bin_edges);

            for ipool = 1:nbins
                % get the mean and median of the pool
                mean_del_all(ipool) = nanmean(del_allflicks(pool_no == ipool));
                median_del_all(ipool) = nanmedian(del_allflicks(pool_no == ipool));

                mean_del_stim(ipool) = nanmean(del_stim_flicks(pool_no == ipool));
                median_del_stim(ipool) = nanmedian(del_stim_flicks(pool_no == ipool));
                
                mean_del_unstim(ipool) = nanmean(del_unstim_flicks(pool_no == ipool));
                median_del_unstim(ipool) = nanmedian(del_unstim_flicks(pool_no == ipool));
            end


            xx = linspace(0,17, nbins+1)+(17/nbins)/2;
            xx = xx(1:end-1);

            if plotFigs
                bar(ax(2), xx, mean_del_all, 0.5, 'edgecolor', 'k', 'facecolor', 'k', 'linewidth', 3, 'displayname', 'all');
                bar(ax(2), xx, mean_del_unstim, 0.5,'edgecolor',[0.2,0.2,0.2], 'facecolor', 'none', 'linewidth', 3, 'displayname', 'no-stim');
                bar(ax(2), xx, mean_del_stim, 0.5, 'edgecolor',stimcolor, 'facecolor', 'none', 'linewidth', 3, 'displayname', 'stim');
                xlim(ax(2), [0,7])
                yy = get(ax(2), 'ylim');
                plot(ax(2), [0.5,0.5], yy, 'k-', 'handlevisibility', 'off')
                plot(ax(2), [3.333,3.333], yy, 'k-', 'handlevisibility', 'off')
                plot(ax(2), [0,18.5], [0,-18.5], '--', 'color', [0.7,0.7, 0.7], 'handlevisibility', 'off')
                plot(ax(2), [0,18.5], [18.5,0], '--', 'color', [0.7,0.7, 0.7], 'handlevisibility', 'off')
                plot(ax(2), [0,18.5], [18.5,0], '--', 'color', [0.3,0.3, 0.3], 'displayname', 'limit');
                meanlicktime = nanmean(unstim_flicks);
                del_reg_to_mean = meanlicktime-xx;
                plot(ax(2), xx, del_reg_to_mean, 'r--', 'displayname', 'reg. to mean, no-stim trials')
                plot(ax(2), [0,18.5], [0,-18.5], '--', 'color', [0.3,0.3, 0.3], 'handlevisibility', 'off')
                plot(ax(2), [0,18.5], [18.5,0], '--', 'color', [0.3,0.3, 0.3], 'handlevisibility', 'off')
                ylim(ax(2), yy);
                ylabel(ax(2), 'del (s, +: moved later on next trial)')
                xlabel(ax(2), 'lick time, trial n')
                % legend(ax(2),'show')
                title(ax(2), 'mean del')


            
                bar(ax(3), xx, median_del_all, 0.5, 'edgecolor', 'k', 'facecolor', 'k', 'linewidth', 3, 'displayname', 'all');
                bar(ax(3), xx, median_del_unstim, 0.5,'edgecolor',[0.2,0.2,0.2], 'facecolor', 'none', 'linewidth', 3, 'displayname', 'no-stim');
                bar(ax(3), xx, median_del_stim, 0.5, 'edgecolor',stimcolor, 'facecolor', 'none', 'linewidth', 3, 'displayname', 'stim');
                xlim(ax(3), [0,7])
                yy = get(ax(3), 'ylim');
                plot(ax(3), [0.5,0.5], yy, 'k-', 'handlevisibility', 'off')
                plot(ax(3), [3.333,3.333], yy, 'k-', 'handlevisibility', 'off')
                plot(ax(3), [0,18.5], [0,-18.5], '--', 'color', [0.7,0.7, 0.7], 'handlevisibility', 'off')
                plot(ax(3), [0,18.5], [18.5,0], '--', 'color', [0.7,0.7, 0.7], 'handlevisibility', 'off')
                plot(ax(3), [0,18.5], [18.5,0], '--', 'color', [0.3,0.3, 0.3], 'displayname', 'limit');
                meanlicktime = nanmean(unstim_flicks);
                del_reg_to_mean = meanlicktime-xx;
                plot(ax(3), xx, del_reg_to_mean, 'r--', 'displayname', 'reg. to mean, no-stim trials')
                plot(ax(3), [0,18.5], [0,-18.5], '--', 'color', [0.3,0.3, 0.3], 'handlevisibility', 'off')
                plot(ax(3), [0,18.5], [18.5,0], '--', 'color', [0.3,0.3, 0.3], 'handlevisibility', 'off')
                ylim(ax(3), yy);
                ylabel(ax(3), 'del (s, +: moved later on next trial)')
                xlabel(ax(3), 'lick time, trial n')
                % legend(ax(3),'show')
                title(ax(3), 'median del')
            end

        end
        function mergeUnits(obj, UnitNo1, UnitNo2, ss)
            unitNo = numel(obj.SpikeSorterData) + 1;

            obj.SpikeSorterData(unitNo).OriginalUnit = [UnitNo1, UnitNo2];
            obj.SpikeSorterData(UnitNo1).OriginalUnit = nan;
            obj.SpikeSorterData(UnitNo2).OriginalUnit = nan;
            combinedTimes = [obj.SpikeSorterData(UnitNo1).times; obj.SpikeSorterData(UnitNo2).times];
            combinedChannels = [obj.SpikeSorterData(UnitNo1).channels; obj.SpikeSorterData(UnitNo2).channels];
            [obj.SpikeSorterData(unitNo).times, ia] = uniquetol(combinedTimes, 0.000001);
            obj.SpikeSorterData(unitNo).channels = combinedChannels(ia);

            % handle waveforms now
            ch_idx = 1;
            if ~isfield(ss.iv, 'waveformspath_')
                ss.alert('info', '>> SpikeStudio: select path with waveforms .mat files from SpikeInterface')
                ss.iv.waveformspath_ = uigetdir(pwd, 'Select waveforms folder');
            end
            % open the file with the waveform data
            retdir = pwd;
            cd(ss.iv.waveformspath_)
            unitNos = [UnitNo1,UnitNo2];
            for ii = 1:2
                % get waveforms for each original unit
                if isempty(ss.SpikeSorterData(unitNos(ii)).Unit)
                    wavefile = load(['Unit_' num2str(unitNos(ii)) '_scipy.mat']);
                    wavestructname = fieldnames(wavefile);
                    wavefile = eval(['wavefile.' wavestructname{1}]);
                    
                    ss.SpikeSorterData(unitNos(ii)).Unit(ch_idx).Channel = wavefile.Channel;
                    ss.SpikeSorterData(unitNos(ii)).Unit(ch_idx).Unit = wavefile.Unit;
                    ss.SpikeSorterData(unitNos(ii)).Unit(ch_idx).Sample = wavefile.Sample;
                    noisewaveidx = isnan(ss.SpikeSorterData(unitNos(ii)).Unit.Unit);

                    if noisewaveidx(end), noisewaveidx(end) = false;end
                    spikewaveidx = ~isnan(ss.SpikeSorterData(unitNos(ii)).Unit.Unit);
                    ss.SpikeSorterData(unitNos(ii)).Unit(ch_idx).Waveforms = wavefile.Waveform(spikewaveidx, :);
                    ss.SpikeSorterData(unitNos(ii)).Unit(ch_idx).NoiseWaveforms = wavefile.Waveform(noisewaveidx, :);

                    if size(wavefile.timestamps, 1) > 1 || size(wavefile.timestamps, 2) ~= size(ss.SpikeSorterData(unitNos(ii)).Unit(ch_idx).Waveforms, 2)
                        ss.alert('achtung', '>> SpikeStudio: WARNING: @OMKAR we need to get the actual waveform times from Spike interface')
                        ss.SpikeSorterData(unitNos(ii)).Unit(ch_idx).WaveformTimestamps = linspace(-1000*size(ss.SpikeSorterData(unitNos(ii)).Unit(ch_idx).Waveforms, 2)/2/30000, 1000*size(ss.SpikeSorterData(unitNos(ii)).Unit(ch_idx).Waveforms, 2)/2/30000, size(ss.SpikeSorterData(unitNos(ii)).Unit(ch_idx).Waveforms, 2));
                    else
                        ss.SpikeSorterData(unitNos(ii)).Unit(ch_idx).WaveformTimestamps = wavefile.timestamps;
                    end
                end
            end
            % merge the waveforms
            ss.SpikeSorterData(unitNo).Unit(ch_idx).Channel = [ss.SpikeSorterData(UnitNo1).Unit(ch_idx).Channel,ss.SpikeSorterData(UnitNo2).Unit(ch_idx).Channel];
            ss.SpikeSorterData(unitNo).Unit(ch_idx).Unit = [ss.SpikeSorterData(UnitNo1).Unit(ch_idx).Unit, ss.SpikeSorterData(UnitNo2).Unit(ch_idx).Unit];
            ss.SpikeSorterData(unitNo).Unit(ch_idx).Sample = [ss.SpikeSorterData(UnitNo1).Unit(ch_idx).Sample, ss.SpikeSorterData(UnitNo2).Unit(ch_idx).Sample];
            ss.SpikeSorterData(unitNo).Unit(ch_idx).Waveforms = [ss.SpikeSorterData(UnitNo1).Unit(ch_idx).Waveforms; ss.SpikeSorterData(UnitNo2).Unit(ch_idx).Waveforms];
            ss.SpikeSorterData(unitNo).Unit(ch_idx).NoiseWaveforms = [ss.SpikeSorterData(UnitNo1).Unit(ch_idx).NoiseWaveforms; ss.SpikeSorterData(UnitNo2).Unit(ch_idx).NoiseWaveforms];
            ss.SpikeSorterData(unitNo).Unit(ch_idx).WaveformTimestamps = ss.SpikeSorterData(UnitNo1).Unit(ch_idx).WaveformTimestamps;
            
            obj.alert('info', ['>> EphysStimPhot: Merged units ' num2str(UnitNo1) ' + ' num2str(UnitNo2) ' -> ' num2str(unitNo)])
            [f, ax] = makeStandardFigure(3, [1,3]);
            ss.plotMeanWaveform(ax(1), UnitNo1, 1,[0,0.5,0], ['Unit #',num2str(UnitNo1)])
            ss.plotMeanWaveform(ax(2), UnitNo2, 1,[0,0.5,0], ['Unit #',num2str(UnitNo2)])
            ss.plotMeanWaveform(ax(3), unitNo, 1,[0,0.5,0], ['Unit #',num2str(unitNo)])
        end
        function [pvalue, test_stat] = slosh_bootranktest(obj, Mode, nboot, downsample_nostim, excludeITI, stimData, shamData, Plot)
            %
            %  based on powersimulation_bootstrappedranktest.m
            %   Modes: next-trial, current-trial, 2-trials-forward...
            %
            if nargin < 8, Plot = true;end
            if nargin < 5, excludeITI = true;end
            if nargin < 4, downsample_nostim =false; end
            if nargin < 3, nboot = 1000; end
            if nargin < 2, Mode = 'next-trial';end
            if Plot
                obj.alert('info', '>> Not accounting in any special way for excluded trials or trials followed by no-lick.')
            end
            EOT = 7;
           

            % [f,ax] = makeStandardFigure; 

            if ~isfield(obj.iv, 'sessionCode')
                obj.iv.sessionCode = ['nmice=' obj.iv.nmice ' nsesh=' obj.iv.nsesh];
            end

            % set(f, 'name', [num2str(obj.GLM.ntrialsforward) ' trials forward | ' obj.iv.sessionCode ' obj.slosh_bootranktest(' Mode ', nboot=' num2str(nboot) ', downsample_nostim=' num2str(downsample_nostim) ', excludeITI=' num2str(excludeITI) ')'])
            % obj.setUserDataStandards([num2str(obj.GLM.ntrialsforward) ' trials forward | ' obj.iv.sessionCode ' obj.slosh_bootranktest(' Mode ', nboot=' num2str(nboot) ', downsample_nostim=' num2str(downsample_nostim) ', excludeITI=' num2str(excludeITI) ')'], f);


            if strcmpi(Mode,'current-trial')
                data_nostim_full = obj.GLM.unstim_flicks;%obj.GLM.flick_s_wrtc(noStimTrials);
                data_stim = obj.GLM.stim_flicks;%obj.GLM.flick_s_wrtc(stimTrials);
            elseif strcmpi(Mode,'next-trial')
                data_nostim_full = obj.GLM.unstim_nexttrial_flicks;%obj.GLM.flick_s_wrtc(noStimTrials);
                data_stim = obj.GLM.stim_nexttrial_flicks;%obj.GLM.flick_s_wrtc(stimTrials);
            elseif strcmpi(Mode, '2-trials-forward')
                data_nostim_full = obj.GLM.unstim_nexttrial_flicks2;
                data_stim = obj.GLM.stim_nexttrial_flicks2;
            elseif strcmpi(Mode, 'UI')
                data_stim = stimData;
                data_nostim_full = shamData;
            else
                error('undefined mode')
            end

            if excludeITI,
                data_nostim_full(data_nostim_full>EOT) = [];
                data_stim(data_stim>EOT) = [];
            end

            ntrials = numel(data_nostim_full) + numel(data_stim);

            n_stim = numel(data_stim);
            n_nostim = numel(data_nostim_full);
            
            % we have more stim than unstim. Maybe we should downsample?
            if downsample_nostim
                data_nostim = data_nostim_full(randi(n_nostim, n_stim, 1));
                n_nostim = n_stim;
            else
                data_nostim = data_nostim_full;
            end
            
            try
                [nostim_cdf,nostim_x] = ecdf(data_nostim);
            catch
                warning('not enough data?')
                nostim_cdf=nan(size(data_nostim));
                nostim_x=nan(size(data_nostim));
            end
            try
                [stim_cdf,stim_x] = ecdf(data_stim);
            catch
                warning('not enough data?')
                stim_cdf = nan(size(data_stim));
                stim_x = nan(size(data_stim));
            end
            
            if Plot
                [f,ax] = makeStandardFigure(3, [1,3]);
                
                plot(ax(1),stim_x,stim_cdf, '-', 'color', [0,0.2,0.8], 'linewidth', 3)
                plot(ax(1),nostim_x,nostim_cdf, '-', 'color', [0.2,0.2,0.2],'linewidth', 3)

                getlinesandshadebetween(ax(1));
            end
            
            
            % bootstrapped rank test
            
            % interpolate the stim at the nostim points
            n_interrogations = 1000;
            deltas = nan(1,n_interrogations);
            interrogation_points = linspace(0.001,EOT, n_interrogations);%, linspace(3.301,7, n_interrogations/2)]';
            for i_query = 1:numel(interrogation_points)
                stim_point_left = find(stim_x <= interrogation_points(i_query), 1, 'last');
                stim_point_right = find(stim_x >= interrogation_points(i_query), 1, 'first');
                xright = stim_x(stim_point_right);
                xleft = stim_x(stim_point_left);
                yright = stim_cdf(stim_point_right);
                yleft = stim_cdf(stim_point_left);
                if isempty(xleft), xleft = 0;end
                if isempty(xright), xright = EOT;end
                if isempty(yright), yright = 1;end
                if isempty(yleft), yleft = 0;end
                b = (yright-yleft)/(xright-xleft);
                interppoint_stim = yleft + b*(interrogation_points(i_query)-xleft);
                % plot(ax(1),interrogation_points(i_query),interppoint_stim, 'bo')
            
                nostim_point_left = find(nostim_x <= interrogation_points(i_query), 1, 'last');
                nostim_point_right = find(nostim_x >= interrogation_points(i_query), 1, 'first');
                xright = nostim_x(nostim_point_right);
                xleft = nostim_x(nostim_point_left);
                yright = nostim_cdf(nostim_point_right);
                yleft = nostim_cdf(nostim_point_left);
                if isempty(xleft), xleft = 0;end
                if isempty(xright), xright = EOT;end
                if isempty(yright), yright = 1;end
                if isempty(yleft), yleft = 0;end
                b = (yright-yleft)/(xright-xleft);
                interppoint_nostim = yleft + b*(interrogation_points(i_query)-xleft);
            
                % plot(ax(1),interrogation_points(i_query),interppoint_nostim, 'ko')
            
                deltas(i_query) = interppoint_nostim - interppoint_stim;
            end
            if Plot
                stem(ax(2),interrogation_points,deltas);
            end
            
            % test statistic
            true_percent_positive = sum(deltas>0)/numel(deltas);
            
            % bootstrap the test statistic
            
            
            % make og dataset
            datapool = [data_nostim;data_stim];
            percent_positives = nan(nboot,1);

            for iboot = 1:nboot
                % draw a new dataset for stim and nostim
                data_nostim = [datapool(randi(n_nostim+n_stim,n_nostim,1))];
                data_stim = [datapool(randi(n_nostim+n_stim,n_stim,1))];
                
                % get bootstrapped cdf
                [nostim_cdf,nostim_x] = ecdf(data_nostim);
                [stim_cdf,stim_x] = ecdf(data_stim);
                % figure
                % plot(stim_x,stim_cdf)
                % hold on
                % plot(nostim_x,nostim_cdf)
            
            
                % interpolate the stim at the nostim points
                deltas = nan(1,n_interrogations);
                for i_query = 1:numel(interrogation_points)
                    stim_point_left = find(stim_x <= interrogation_points(i_query), 1, 'last');
                    stim_point_right = find(stim_x >= interrogation_points(i_query), 1, 'first');
                    xright = stim_x(stim_point_right);
                    xleft = stim_x(stim_point_left);
                    yright = stim_cdf(stim_point_right);
                    yleft = stim_cdf(stim_point_left);
                    if isempty(xleft), xleft = 0;end
                    if isempty(xright), xright = EOT;end
                    if isempty(yright), yright = 1;end
                    if isempty(yleft), yleft = 0;end
                    b = (yright-yleft)/(xright-xleft);
                    interppoint_stim = yleft + b*(interrogation_points(i_query)-xleft);
                
                    nostim_point_left = find(nostim_x <= interrogation_points(i_query), 1, 'last');
                    nostim_point_right = find(nostim_x >= interrogation_points(i_query), 1, 'first');
                    xright = nostim_x(nostim_point_right);
                    xleft = nostim_x(nostim_point_left);
                    yright = nostim_cdf(nostim_point_right);
                    yleft = nostim_cdf(nostim_point_left);
                    if isempty(xleft), xleft = 0;end
                    if isempty(xright), xright = EOT;end
                    if isempty(yright), yright = 1;end
                    if isempty(yleft), yleft = 0;end
                    b = (yright-yleft)/(xright-xleft);
                    interppoint_nostim = yleft + b*(interrogation_points(i_query)-xleft);
                
                
                    deltas(i_query) = interppoint_nostim - interppoint_stim;
                end
                percent_positives(iboot) = sum(deltas>0)/numel(deltas);
            end
        
            pvalue = sum(true_percent_positive > percent_positives)/nboot;
            test_stat = true_percent_positive;
            % set(f, 'name', [obj.iv.sessionCode ' obj.slosh_bootranktest(' Mode ', nboot=' num2str(nboot) ', downsample_nostim=' num2str(downsample_nostim) ', excludeITI=' num2str(excludeITI) ')'], 'userdata', ['obj.slosh_bootranktest(' num2str(downsample_nostim)  ')'])
            if Plot
                set(f, 'name', [num2str(obj.GLM.ntrialsforward) ' trials forward | ' obj.iv.sessionCode ' obj.slosh_bootranktest(' Mode ', nboot=' num2str(nboot) ', downsample_nostim=' num2str(downsample_nostim) ', excludeITI=' num2str(excludeITI) ')'],...
                    'position', [0.0354    0.5022    0.9396    0.3822])
                obj.setUserDataStandards([num2str(obj.GLM.ntrialsforward) ' trials forward | ' obj.iv.sessionCode ' obj.slosh_bootranktest(' Mode ', nboot=' num2str(nboot) ', downsample_nostim=' num2str(downsample_nostim) ', excludeITI=' num2str(excludeITI) ')'], f);

                h = prettyHxg(ax(3), percent_positives, 'bootstrapped % positive ranks', [0.2,0.8,0.2], [], 100);
                yy = get(ax(3), 'ylim');
                plot(ax(3), [true_percent_positive, true_percent_positive], yy, 'k--')
                xlabel(ax(3), '% positive rank')
                ylabel(ax(3), 'p')
                
                title(ax(3), ['p = ' num2str(pvalue)])
                
                for ii=1:2
                    xlim(ax(ii), [0,7])
                    xticks(ax(ii), 0:7)
                end
                ylim(ax(ii), [-0.08, 0.08])
            end
        end
        function [pvalue, test_stat, ksstats] = slosh_boot_dAUC(obj, Mode, nboot, downsample_nostim, excludeITI, inclusive, Plot)
            %
            %  based on original dAUC calculations from Hamilos et al., eLife 2021
            %   See CLASS_optogenetics_legacy_obj.m > @getvalidblocks
            %   Modes: next-trial, current-trial, 2-trials-forward...
            %
            %   Also returns the kstest2 result!
            %
            if nargin < 7, Plot = true;end
            if nargin < 6, inclusive = false;end % this will set the cdf at 7s to 1
            if nargin < 5, excludeITI = true;end % this will set the cdf at 7s to 1
            if nargin < 4, downsample_nostim =false; end
            if nargin < 3, nboot = 1000; end
            if nargin < 2, Mode = 'next-trial';end
            if Plot
                obj.alert('info', '>> Not accounting in any special way for excluded trials or trials followed by no-lick.')
            end
            EOT = 7;


            if ~isfield(obj.iv, 'sessionCode')
                obj.iv.sessionCode = ['nmice=' obj.iv.nmice ' nsesh=' obj.iv.nsesh];
            end
            if Plot
                [f,ax] = makeStandardFigure(2, [1,2]); 
                set(f, 'name', [num2str(obj.GLM.ntrialsforward) ' trials forward | ' obj.iv.sessionCode ' obj.slosh_boot_dAUC(' Mode ', nboot=' num2str(nboot) ', downsample_nostim=' num2str(downsample_nostim) ', excludeITI=' num2str(excludeITI) ', inclusive=' num2str(inclusive) ')'],...
                    'units', 'normalized',...
                    'position', [0.3049, 0.4722, 0.6361, 0.4133]);

                for ii=1:2
                    set(ax(ii), 'fontsize', 20)
                end
                xlabel(ax(1), 'time (s)')
                ylabel(ax(1), 'ecdf')
            end

            if strcmpi(Mode,'current-trial')
                data_nostim_full = obj.GLM.unstim_flicks;
                data_stim = obj.GLM.stim_flicks;
            elseif strcmpi(Mode,'next-trial')
                data_nostim_full = obj.GLM.unstim_nexttrial_flicks;
                data_stim = obj.GLM.stim_nexttrial_flicks;
            elseif strcmpi(Mode, '2-trials-forward')
                data_nostim_full = obj.GLM.unstim_nexttrial_flicks2;
                data_stim = obj.GLM.stim_nexttrial_flicks2;
            elseif strcmpi(Mode, 'UI')
                data_stim = stimData;
                data_nostim_full = shamData;
            else
                error('undefined mode')
            end

            if excludeITI
                data_nostim_full(data_nostim_full>EOT) = [];
                data_stim(data_stim>EOT) = [];
            end

            ntrials = numel(data_nostim_full) + numel(data_stim);

            n_stim = numel(data_stim);
            n_nostim = numel(data_nostim_full);

            % we have more stim than unstim. Maybe we should downsample?
            if downsample_nostim
                data_nostim = data_nostim_full(randi(n_nostim, n_stim, 1));
                n_nostim = n_stim;
            else
                data_nostim = data_nostim_full;
            end
            
            try
                [nostim_cdf,nostim_x] = ecdf(data_nostim);
            catch
                warning('not enough data?')
                nostim_cdf=nan(size(data_nostim));
                nostim_x=nan(size(data_nostim));
            end
            try
                [stim_cdf,stim_x] = ecdf(data_stim);
            catch
                warning('not enough data?')
                stim_cdf=nan(size(data_stim));
                stim_x=nan(size(data_stim));
            end

            if Plot
                plot(ax(1),stim_x,stim_cdf, '-', 'color', [0,0.2,0.8], 'linewidth', 3)
                plot(ax(1),nostim_x,nostim_cdf, '-', 'color', [0.2,0.2,0.2], 'linewidth', 3)
                getlinesandshadebetween(ax(1));
            end
            % qqplot(ax(2), data_nostim,data_stim)
            % qqplot(ax(2), nostim_cdf,stim_cdf)
            % plot(ax(2),nostim_cdf,stim_cdf)
            % xlabel(ax(2), 'no stim')
            % ylabel(ax(2), 'stim')


            % bootstrapped dAUC test

            [delAUCun_minus_stim,delAUC_EOTun_minus_stim,delAUC_EOTinclusive_un_minus_stim,xs,AUCs] = AUC_helper_bootdAUCtest(nostim_x, nostim_cdf, stim_x, stim_cdf, EOT);
            % seems includive just sets the cdf at 7s = what it would be at 17s. I
            % don't think we want to do this

            % test statistic
            if ~inclusive
                if excludeITI
                    test_stat = delAUC_EOTun_minus_stim;
                    AUC_stim = AUCs.stim_AUC_EOT;
                    AUC_nostim = AUCs.nostim_AUC_EOT;
                    x_nostim = xs.nostim_x_EOT;
                    x_stim = xs.stim_x_EOT;
                else
                    test_stat = delAUCun_minus_stim;
                    AUC_stim = AUCs.stim_AUC;
                    AUC_nostim = AUCs.nostim_AUC;
                    x_nostim = xs.nostim_x;
                    x_stim = xs.stim_x;
                end
            else
                test_stat = delAUC_EOTinclusive_un_minus_stim;
                AUC_stim = AUCs.stim_AUC_EOTinclusive;
                AUC_nostim = AUCs.nostim_AUC_EOTinclusive;
                x_nostim = xs.stim_x_EOTinclusive;
                x_stim = xs.nostim_x_EOTinclusive;
            end

            % bootstrap the test statistic
            % make og dataset
            datapool = [data_nostim;data_stim];
            boot_stats = nan(nboot,1);

            % figure
            for iboot = 1:nboot
                % draw a new dataset for stim and nostim
                data_nostim_b = [datapool(randi(n_nostim+n_stim,n_nostim,1))];
                data_stim_b = [datapool(randi(n_nostim+n_stim,n_stim,1))];
                
                % get bootstrapped cdf
                [nostim_cdf_b,nostim_x_b] = ecdf(data_nostim_b);
                [stim_cdf_b,stim_x_b] = ecdf(data_stim_b);
                
                % plot(stim_x_b,stim_cdf_b, 'b--')
                % hold on
                % plot(nostim_x_b,nostim_cdf_b, 'k--')


                [delAUCun_minus_stim_b,delAUC_EOTun_minus_stim_b,delAUC_EOTinclusive_un_minus_stim_b] = AUC_helper_bootdAUCtest(nostim_x_b, nostim_cdf_b, stim_x_b, stim_cdf_b, EOT);
                
                if ~inclusive
                    if excludeITI
                        boot_stats(iboot) = delAUC_EOTun_minus_stim_b;
                    else
                        boot_stats(iboot) = delAUCun_minus_stim_b;
                    end
                else
                    boot_stats(iboot) = delAUC_EOTinclusive_un_minus_stim_b;
                end
            end

            % [f,ax] = makeStandardFigure();
            % set(f, 'name', [num2str(obj.GLM.ntrialsforward) ' trials forward | ' obj.iv.sessionCode ' obj.slosh_boot_dAUC(' Mode ', nboot=' num2str(nboot) ', downsample_nostim=' num2str(downsample_nostim) ', excludeITI=' num2str(excludeITI) ', inclusive=' num2str(inclusive) ')'])
            % obj.setUserDataStandards(obj.slosh_boot_dAUC(' Mode ', nboot=' num2str(nboot) ', downsample_nostim=' num2str(downsample_nostim) ', excludeITI=' num2str(excludeITI) ', inclusive=' num2str(inclusive) ')', f);
            % h = prettyHxg(ax, boot_stats, 'bootstrapped dAUC', [0.2,0.8,0.2], [], 100);
            pvalue = sum(boot_stats < test_stat)/nboot;
            [h,p,ks2stat] = kstest2(x_nostim, x_stim);
            ksstats = [h,p,ks2stat];
            if Plot
                h = prettyHxg(ax(2), boot_stats, 'bootstrapped dAUC', [0.2,0.8,0.2], [], 100);
                % yy = get(ax, 'ylim');
                yy = get(ax(2), 'ylim');
                % plot(ax, [test_stat, test_stat], yy, 'k--')
                plot(ax(2), [test_stat, test_stat], yy, 'k--')
                if excludeITI
                    xlabel(ax(2), 'dAUC EOT')
                else
                    xlabel(ax(2), 'dAUC, including ITI')
                end
                ylabel(ax(2), 'p')

                title(ax(2), ['p = ' num2str(pvalue)])
                % let's also do the ks2 test here
                
                set(f, 'userdata',...
                    [obj.setUserDataStandards([obj.iv.sessionCode ' obj.slosh_boot_dAUC(' Mode ', nboot=' num2str(nboot) ', downsample_nostim=' num2str(downsample_nostim) ', excludeITI=' num2str(excludeITI) ', inclusive=' num2str(inclusive) ')'], f),...
                    '\n\ndAUC results:',...
                    '\n    dAUC=' num2str(test_stat),...
                    '\n    p=' num2str(pvalue),...
                    '\n\nKS2 test:',...
                    '\n    p=' num2str(p),...
                    '\n    ks2stat=' num2str(ks2stat),...
                    ]);
            end
            
            
        end
        function [boot_dAUC, boot_ks2] = slosh_boot_dAUC_bootstatforgroup(obj, Mode, nboot, downsample_nostim, excludeITI, inclusive, Plot)
            %
            %  based on the above fxn, except here we arent testing against chance, we are gathering 10000 saples of the stat fro resapled dataset
            %   to do across group coparisons
            %
            %   copare to the  boot_dAUC of another grop
            %
            %   Also returns the kstest2 result!
            %
            if nargin < 7, Plot = true;end
            if nargin < 6, inclusive = false;end % this will set the cdf at 7s to 1
            if nargin < 5, excludeITI = true;end % this will set the cdf at 7s to 1
            if nargin < 4, downsample_nostim =false; end
            if nargin < 3, nboot = 1000; end
            if nargin < 2, Mode = 'next-trial';end
            if Plot
                obj.alert('info', '>> Not accounting in any special way for excluded trials or trials followed by no-lick.')
            end
            EOT = 7;


            if ~isfield(obj.iv, 'sessionCode')
                obj.iv.sessionCode = ['nmice=' obj.iv.nmice ' nsesh=' obj.iv.nsesh];
            end
            if Plot
                [f,ax] = makeStandardFigure(2, [1,2]); 
                set(f, 'name', [num2str(obj.GLM.ntrialsforward) ' trials forward | ' obj.iv.sessionCode ' obj.slosh_boot_dAUC(' Mode ', nboot=' num2str(nboot) ', downsample_nostim=' num2str(downsample_nostim) ', excludeITI=' num2str(excludeITI) ', inclusive=' num2str(inclusive) ')'],...
                    'units', 'normalized',...
                    'position', [0.3049, 0.4722, 0.6361, 0.4133]);

                for ii=1:2
                    set(ax(ii), 'fontsize', 20)
                end
                xlabel(ax(1), 'time (s)')
                ylabel(ax(1), 'ecdf')
            end

            if strcmpi(Mode,'current-trial')
                data_nostim_full = obj.GLM.unstim_flicks;
                data_stim = obj.GLM.stim_flicks;
            elseif strcmpi(Mode,'next-trial')
                data_nostim_full = obj.GLM.unstim_nexttrial_flicks;
                data_stim = obj.GLM.stim_nexttrial_flicks;
            elseif strcmpi(Mode, '2-trials-forward')
                data_nostim_full = obj.GLM.unstim_nexttrial_flicks2;
                data_stim = obj.GLM.stim_nexttrial_flicks2;
            elseif strcmpi(Mode, 'UI')
                data_stim = stimData;
                data_nostim_full = shamData;
            else
                error('undefined mode')
            end

            if excludeITI
                data_nostim_full(data_nostim_full>EOT) = [];
                data_stim(data_stim>EOT) = [];
            end

            data_stim = data_stim(~isnan(data_stim));
            data_nostim_full = data_nostim_full(~isnan(data_nostim_full));

            n_stim = numel(data_stim);
            n_nostim = numel(data_nostim_full);


            % we have more stim than unstim. Maybe we should downsample?
            if downsample_nostim
                data_nostim = data_nostim_full(randi(n_nostim, n_stim, 1));
                n_nostim = n_stim;
            else
                data_nostim = data_nostim_full;
            end


            %% now we need to bootstrap these sets....
            boot_dAUC = nan(nboot,1);
            for ii = 1:nboot
                b_data_stim = data_stim(randi(n_stim, n_stim, 1));
                b_data_nostim = data_nostim(randi(n_nostim, n_nostim, 1));
                
                [stim_cdf,stim_x] = ecdf(b_data_stim);
                [nostim_cdf,nostim_x] = ecdf(b_data_nostim);
                
                [delAUCun_minus_stim,delAUC_EOTun_minus_stim,delAUC_EOTinclusive_un_minus_stim,xs,AUCs] = AUC_helper_bootdAUCtest(nostim_x, nostim_cdf, stim_x, stim_cdf, EOT);
                 % test statistic
                if ~inclusive
                    if excludeITI
                        test_stat = delAUC_EOTun_minus_stim;
                        % AUC_stim = AUCs.stim_AUC_EOT;
                        % AUC_nostim = AUCs.nostim_AUC_EOT;
                        x_nostim = xs.nostim_x_EOT;
                        x_stim = xs.stim_x_EOT;
                    else
                        test_stat = delAUCun_minus_stim;
                        % AUC_stim = AUCs.stim_AUC;
                        % AUC_nostim = AUCs.nostim_AUC;
                        x_nostim = xs.nostim_x;
                        x_stim = xs.stim_x;
                    end
                else
                    test_stat = delAUC_EOTinclusive_un_minus_stim;
                    % AUC_stim = AUCs.stim_AUC_EOTinclusive;
                    % AUC_nostim = AUCs.nostim_AUC_EOTinclusive;
                    x_nostim = xs.stim_x_EOTinclusive;
                    x_stim = xs.nostim_x_EOTinclusive;
                end
                boot_dAUC(ii) = test_stat;
                [~,~,ks2stat] = kstest2(x_nostim, x_stim);
                boot_ks2(ii) = ks2stat;
            end
            
        end
        function ntrialsforwardflicks = get_n_trials_forward_flick(obj, n, valid_idxs, flickswrtc)
            % we will pick of the flick time ntrials foward...
            %   n is number of trials forward
            %   valid_idx will determine if we consider this trial at all
            %       we'll return as indexed array relative to the session...ie
            %       we will keep trial order and numel
            ntrialsforwardflicks = nan(size(flickswrtc));
            idx_to_get = [1:numel(flickswrtc)]' + n;
            idx_to_get(idx_to_get>numel(flickswrtc)) = [];
            % if not a valid trial index, we should not get it
            % if current trial is nan, we should also not get
            % those...isundefined
            idx_to_get(isnan(flickswrtc)) = nan;
            idx_to_get(~ismember(idx_to_get, valid_idxs+n)) = nan;
            % get rid of nans to use as indexing
            idx_to_get(isnan(idx_to_get)) = [];
            % now, get the lick time of the valids...
            ntrialsforwardflicks(idx_to_get-n) = flickswrtc(idx_to_get);
        end
        function [pvalue, test_stat, influence] = slosh_emery_boot_test(obj,nboot,excludeITI_prevtrial,excludeITI_nexttrial,ntrialsforward, Plot,runCrossSeshVersion)
            if nargin < 7, runCrossSeshVersion = false;end
            if nargin < 6, Plot=true;end
            if nargin < 5, ntrialsforwardflicks = 1;end
            if nargin < 4, excludeITI_nexttrial = true; end
            if nargin < 3, excludeITI_prevtrial = false; end
            if nargin < 2, nboot = 10000;end
            EOT = 7;
            considerationBoundary_ms = 0;

            if ~isfield(obj.iv, 'sessionCode')
                obj.iv.sessionCode = ['nmice=' obj.iv.nmice ' nsesh=' obj.iv.nsesh];
            end


            % prev_trial = [obj.GLM.flick_s_wrtc(1:end-1); nan]; 
            % next_trial = [obj.GLM.flick_s_wrtc(2:end); nan]; 
            %
            % get the difference between current lick time and next. if nan, is just
            % nan!
            % to get this, we have to consider which sesh is which...
            % del_lick_time_p_minus_next = next_trial-prev_trial;

            del_lick_time_p_minus_next = [];
            stim_del_lick_time = [];
            nostim_del_lick_time = [];
            prev_trial = [];
            stimTrials = [];
            noStimTrials = [];
            seshs = unique(obj.GLM.seshNoIdx);
            for seshNo = 1:numel(seshs)
                ii = seshs(seshNo);
                prev_trial_thissesh = obj.GLM.flick_s_wrtc(obj.GLM.seshNoIdx == ii);
                % handle EOT:
                if excludeITI_prevtrial
                    prev_trial_thissesh(prev_trial_thissesh > EOT) = nan;
                end
                prev_trial = [prev_trial;prev_trial_thissesh];

                if runCrossSeshVersion % for use with cObj.sloshing_extract_stim_test_stats_forbetweengroupcomparison #sloshingStimulation
                    next_trial_this_sesh = sum([obj.GLM.unstim_nexttrial_flicks, obj.GLM.stim_nexttrial_flicks], 2, 'omitnan');
                else
                    next_trial_this_sesh = obj.get_n_trials_forward_flick(ntrialsforward, 1:numel(prev_trial_thissesh), prev_trial_thissesh);            
                end
                if excludeITI_nexttrial
                    next_trial_this_sesh(next_trial_this_sesh > EOT) = nan;
                end
                del_this_sesh = next_trial_this_sesh-prev_trial_thissesh;
                del_lick_time_p_minus_next = [del_lick_time_p_minus_next; del_this_sesh];

                % stim to next
                these_rows = find(obj.GLM.seshNoIdx == ii);
                stim_trials_this_sesh = ismember(these_rows, obj.GLM.stimTrials);
                stimTrials = [stimTrials;stim_trials_this_sesh];
                nostim_trials_this_sesh = ismember(these_rows, obj.GLM.noStimTrials);
                noStimTrials = [noStimTrials;nostim_trials_this_sesh];

                stim_del_this_sesh = nan(size(these_rows));
                nostim_del_this_sesh = nan(size(these_rows));
                stim_del_this_sesh(stim_trials_this_sesh) = del_this_sesh(stim_trials_this_sesh);
                nostim_del_this_sesh(nostim_trials_this_sesh) = del_this_sesh(nostim_trials_this_sesh);

                stim_del_lick_time = [stim_del_lick_time;stim_del_this_sesh];
                nostim_del_lick_time = [nostim_del_lick_time;nostim_del_this_sesh];
                mean_deldel_stim(seshNo) = nanmean(stim_del_this_sesh);
                mean_deldel_nostim(seshNo) = nanmean(nostim_del_this_sesh);
                if Plot
                    disp(['mean deldel stim:   ' num2str(mean_deldel_stim(seshNo))])
                    disp(['mean deldel unstim: ' num2str(mean_deldel_nostim(seshNo))])
                end
                % stim_del_this_sesh(obj.GLM.stimTrials) = del_lick_time_p_minus_next(obj.GLM.stimTrials);
                % nostim_del_this_sesh(obj.GLM.noStimTrials) = del_lick_time_p_minus_next(obj.GLM.noStimTrials);
            end
            if Plot
                [f,ax] = makeStandardFigure(3, [1,3]);
                set(f, 'position', [0.0701    0.4711    0.8709    0.4133]);
                for ii=1:3
                    set(ax(ii), 'fontsize', 20)
                end
                axs = ax;
    %             ax = axs(1);
                
                stem(ax(2), mean_deldel_stim, 'c', 'linewidth', 5)
                stem(ax(2), mean_deldel_nostim, 'k', 'linewidth', 5)
                stem(ax(2), mean_deldel_stim-mean_deldel_nostim, 'r', 'linewidth', 5)
                xlabel(ax(2), 'sessionID')
                xticks(ax(2), 1:numel(seshs))
                xticklabels(ax(2), cellfun(@(x) strjoin(strsplit(x, '_'), ' '),obj.iv.files, 'uniformoutput', 0))
                set(ax(2), 'fontsize', 10)
                
                ylabel(ax(2), 'mean deldel ∆(∆s)')


                prettyHxg(ax(3), stim_del_lick_time, 'stim', 'c', [], 100)
                prettyHxg(ax(3), nostim_del_lick_time, 'nostim', 'k', [], 100)
                xlabel(ax(3), 'deldel ∆(∆s)') 
                ylabel(ax(3), 'p')
            end
            

            influence.mean_stim = nanmean(stim_del_lick_time);
            influence.mean_nostim = nanmean(nostim_del_lick_time);
            if Plot
                disp(['mean stim influence ' num2str(influence.mean_stim)])
                disp(['mean NO stim influence ' num2str(influence.mean_nostim)])
            end

            influence.mean_stim_early = nanmean(stim_del_lick_time(prev_trial<=3.3));
            influence.mean_nostim_early = nanmean(nostim_del_lick_time(prev_trial<=3.3));
            if Plot
                disp(['mean stim influence | stim was early ' num2str(influence.mean_stim_early)])
                disp(['mean NO stim influence | NO stim was early ' num2str(influence.mean_nostim_early)])
            end

            influence.mean_stim_reward = nanmean(stim_del_lick_time(prev_trial>=3.3 & prev_trial<=7));
            influence.mean_nostim_reward = nanmean(nostim_del_lick_time(prev_trial>=3.3  & prev_trial<=7));
            if Plot
                disp(['mean stim influence | stim was rew ' num2str(influence.mean_stim_reward)])
                disp(['mean NO stim influence | NO stim was rew ' num2str(influence.mean_nostim_reward)])
            end

            influence.mean_stim_iti = nanmean(stim_del_lick_time(prev_trial>7));
            influence.mean_nostim_iti = nanmean(nostim_del_lick_time(prev_trial>7));
            if Plot
                disp(['mean stim influence | stim was iti ' num2str(influence.mean_stim_iti)])
                disp(['mean NO stim influence | NO stim was iti ' num2str(influence.mean_nostim_iti)])
            end

            %% now let's bootstrap this shiz:

            test_stat = nanmean(stim_del_lick_time) - nanmean(nostim_del_lick_time);


            all_trials = find(~isnan(prev_trial));

            boot_stat_stim = nan(numel(seshs),1);
            boot_stat_nostim = nan(numel(seshs),1);
            boot_stat_del = nan(numel(seshs),1);
            % for ii = 1:nboot
            %     % we want to change identities of stim and no stim trials
            %     bootStimTrials = randsample(all_trials, numel(stimTrials), true);
            %     bootNoStimTrials = randsample(all_trials, numel(noStimTrials), true);


            %     % stim to next
            %     stim_del_lick_time_b = nan(size(del_lick_time_p_minus_next));
            %     nostim_del_lick_time_b = nan(size(del_lick_time_p_minus_next));
            %     stim_del_lick_time_b(bootStimTrials) = del_lick_time_p_minus_next(bootStimTrials);
            %     nostim_del_lick_time_b(bootNoStimTrials) = del_lick_time_p_minus_next(bootNoStimTrials);
                
            %     boot_stat_stim(ii) = nanmean(stim_del_lick_time_b);
            %     boot_stat_nostim(ii) = nanmean(nostim_del_lick_time_b);
            %     boot_stat_del(ii) = boot_stat_stim(ii) - boot_stat_nostim(ii);
            % end

            
            % let's try doing this within a session:
             for nn = 1:nboot
                mean_deldel_stim_b = [];
                mean_deldel_nostim_b = [];
                stim_del_lick_time_b = [];
                nostim_del_lick_time_b = [];
                for seshNo = 1:numel(seshs)
                    ii = seshs(seshNo);
                    prev_trial_thissesh = obj.GLM.flick_s_wrtc(obj.GLM.seshNoIdx == ii);
                    % handle EOT:
                    if excludeITI_prevtrial
                        prev_trial_thissesh(prev_trial_thissesh > EOT) = nan;
                    end
                    % 
                    % here we bootstrap each session's data
                    %   this eliminates nonstationarity - is not corect
                    % prev_trial_thissesh = randsample(prev_trial_thissesh, numel(prev_trial_thissesh), true);
                    if runCrossSeshVersion % for use with cObj.sloshing_extract_stim_test_stats_forbetweengroupcomparison #sloshingStimulation
                        next_trial_this_sesh = sum([obj.GLM.unstim_nexttrial_flicks, obj.GLM.stim_nexttrial_flicks], 2, 'omitnan');
                    else
                        next_trial_this_sesh = obj.get_n_trials_forward_flick(ntrialsforward, 1:numel(prev_trial_thissesh), prev_trial_thissesh);            
                    end
                    if excludeITI_nexttrial
                        next_trial_this_sesh(next_trial_this_sesh > EOT) = nan;
                    end
                    del_this_sesh = next_trial_this_sesh-prev_trial_thissesh;
                    del_lick_time_p_minus_next = [del_lick_time_p_minus_next; del_this_sesh];

                    % stim to next
                    % 
                    %   here we need to permute...we need to shuffle the order of stim vs unstim
                    % 
                    these_rows = find(obj.GLM.seshNoIdx == ii);
                    nostim_trials_this_sesh = 1:numel(these_rows);
                    nstim_this_sesh = sum(ismember(these_rows, obj.GLM.stimTrials));
                    stim_trials_this_sesh = randperm(numel(these_rows),nstim_this_sesh);
                    nostim_trials_this_sesh(ismember(nostim_trials_this_sesh, stim_trials_this_sesh)) = [];
                    % stim_trials_this_sesh = ismember(these_rows, obj.GLM.stimTrials);
                    % nostim_trials_this_sesh = ismember(these_rows, obj.GLM.noStimTrials);

                    stim_del_this_sesh = nan(size(these_rows));
                    nostim_del_this_sesh = nan(size(these_rows));
                    stim_del_this_sesh(stim_trials_this_sesh) = del_this_sesh(stim_trials_this_sesh);
                    nostim_del_this_sesh(nostim_trials_this_sesh) = del_this_sesh(nostim_trials_this_sesh);

                    stim_del_lick_time_b = [stim_del_lick_time_b;stim_del_this_sesh];
                    nostim_del_lick_time_b = [nostim_del_lick_time_b;nostim_del_this_sesh];
                    mean_deldel_stim_b = nanmean(stim_del_lick_time_b);
                    mean_deldel_nostim_b = nanmean(nostim_del_lick_time_b);
                    % disp(['mean deldel stim:   ' num2str(mean_deldel_stim_b)])
                    % disp(['mean deldel unstim: ' num2str(mean_deldel_nostim_b)])
                end


                % stim to next
                % stim_del_lick_time_b = stim_del_lick_time_b;
                % nostim_del_lick_time_b = nostim_del_lick_time_b;
                
                boot_stat_stim(nn) = nanmean(stim_del_lick_time_b);
                boot_stat_nostim(nn) = nanmean(nostim_del_lick_time_b);
                boot_stat_del(nn) = boot_stat_stim(nn) - boot_stat_nostim(nn);
            end

            pvalue = sum(boot_stat_del < test_stat)/nboot;
            if Plot
                obj.setUserDataStandards([num2str(ntrialsforward), ' trials forward | ' obj.iv.sessionCode ' obj.slosh_emery_boot_test(nboot=' num2str(nboot) ', excludeITI_prevtrial=' num2str(excludeITI_prevtrial) ', excludeITI_nexttrial=' num2str(excludeITI_nexttrial) ', ntrialsforward=' num2str(ntrialsforward) ')'], f);
                set(f, 'name', [num2str(ntrialsforward), ' trials forward | ' obj.iv.sessionCode ' obj.slosh_emery_boot_test(nboot=' num2str(nboot) ', excludeITI_prevtrial=' num2str(excludeITI_prevtrial) ', excludeITI_nexttrial=' num2str(excludeITI_nexttrial) ', ntrialsforward=' num2str(ntrialsforward) ')'])
                h = prettyHxg(ax(1), boot_stat_del, 'bootstrapped dAUC', [0.2,0.8,0.2], [], 100);
                yy = get(ax(1), 'ylim');
                plot(ax(1), [test_stat, test_stat], yy, 'r--')
                if excludeITI_prevtrial
                    xlabel(ax(1), 'mean del stim - no stim EOT prev')
                elseif excludeITI_prevtrial && excludeITI_nexttrial
                    xlabel(ax(1), 'mean del stim - no stim EOT prev+next')
                elseif excludeITI_nexttrial
                    xlabel(ax(1), 'mean del stim - no stim EOT next')
                else
                    xlabel(ax(1), 'mean del stim - no stim, including ITI')
                end
                ylabel(ax(1), 'p')
                title(ax(1), ['p = ' num2str(pvalue)])
            end
        end
        function [h_stim, h_sham] = slosh_comparecdf(obj_a, obj_s, exclude_ITI, Mode, nameA, nameS)
            % 
            %   use composite made from STAT_Collate #sloshingstim and then compare
            % 
            nboot=1000;
            EOT=7;
            trialrange = obj_a.iv.TRIALRANGE;
            nTrialsForward = obj_a.GLM.ntrialsforward;
            if nargin < 3, exclude_ITI = true;end
            if nargin < 4, Mode = 'all';end
            if nargin < 5, nameA = 'stim';end
            if nargin < 5, nameS = 'sham';end
            % default is to get for all mice
            mice_a = obj_a.iv.names;
            nmice_a = obj_a.iv.nmice;
            mice_s = obj_s.iv.names;
            nmice_s = obj_s.iv.nmice;
            

            % get the cdf for each session...
            [f,ax] = makeStandardFigure; 
            set(f, 'name', [num2str(nTrialsForward) ' trials forward | Mode=' Mode ' | exclude_ITI=' num2str(exclude_ITI)  ' trialrange=' mat2str([min(trialrange), max(trialrange)]) ],...
                'units', 'normalized',...
                'position', [ 0.4486    0.1256    0.5410    0.7867]);
            set(f, 'userdata', sprintf(['\n',...
                    obj_a.setUserDataStandards(['esp_a.slosh_comparecdf(esp_s, exclude_ITI=' num2str(exclude_ITI) ',' Mode ')'], f)...
                    obj_s.setUserDataStandards(['-- esp_s data:'], f)
                    ]));
                

            for ii=1
                set(ax(ii), 'fontsize', 20)
                xlabel(ax(ii), 'time (s)')
                ylabel(ax(ii), 'ecdf')
                xlim(ax(ii), [0,EOT]);
            end
            
            % do stim first
            flickswrtc = obj_a.GLM.flick_s_wrtc;
            stimTrials = obj_a.GLM.stimTrials;
            noStimTrials = obj_a.GLM.noStimTrials;

            if strcmpi(Mode, 'all')
                data = obj_a.get_n_trials_forward_flick(nTrialsForward, 1:numel(flickswrtc), flickswrtc);
            elseif strcmpi(Mode, 'stim')
                data = obj_a.get_n_trials_forward_flick(nTrialsForward, stimTrials, flickswrtc);
            elseif strcmpi(Mode, 'sham')
                data = obj_a.get_n_trials_forward_flick(nTrialsForward, noStimTrials, flickswrtc);
            else
                error('undefined mode, must use ''all'', ''stim'', or ''sham''')
            end
            if exclude_ITI
                data(data>EOT) = [];
                data(data>EOT) = [];
            end
            [cdf_stim,stim_X] = ecdf(data);
            boot_stim = obj_a.bootdata(data, nboot);boot_stim_ecdf = nan(nboot, numel(stim_X));    
    

            % SHAM
            flickswrtc = obj_s.GLM.flick_s_wrtc;
            stimTrials = obj_s.GLM.stimTrials;
            noStimTrials = obj_s.GLM.noStimTrials;

            if strcmpi(Mode, 'all')
                data = obj_s.get_n_trials_forward_flick(nTrialsForward, 1:numel(flickswrtc), flickswrtc);
            elseif strcmpi(Mode, 'stim')
                data = obj_s.get_n_trials_forward_flick(nTrialsForward, stimTrials, flickswrtc);
            elseif strcmpi(Mode, 'sham')
                data = obj_s.get_n_trials_forward_flick(nTrialsForward, noStimTrials, flickswrtc);
            else
                error('undefined mode, must use ''all'', ''stim'', or ''sham''')
            end
            if exclude_ITI
                data(data>EOT) = [];
                data(data>EOT) = [];
            end
            [cdf_sham,unstim_X] = ecdf(data);
            boot_sham = obj_s.bootdata(data, nboot);boot_sham_ecdf = nan(nboot, numel(unstim_X));    
            

            if numel(mice_s) ~= numel(mice_a), warning('hey! these numbers don''t match!');end

            % get 95% boot CI and plot
            % get significant not overlap:
            for ii = 1:nboot
                % have to account for fact x's will get duplicated when sampling with replacement
                boot_stim_ecdf(ii,:)  = obj_a.boot_ecdf_helper(boot_stim(ii,:), boot_stim_ecdf(ii,:), stim_X);
                boot_sham_ecdf(ii,:)  = obj_s.boot_ecdf_helper(boot_sham(ii,:), boot_sham_ecdf(ii,:), unstim_X);
            end
            [ci_l_stim_ecdf, ci_u_stim_ecdf] = obj_a.bootCI(boot_stim_ecdf, 0.05);    
            [ci_l_sham_ecdf, ci_u_sham_ecdf] = obj_a.bootCI(boot_sham_ecdf, 0.05);    


            n_interrogations = 1000;
            signif_diff_LEFT = nan(1,n_interrogations);
            signif_diff_RIGHT = nan(1,n_interrogations);
            interrogation_points = linspace(0.001,17, n_interrogations);%, linspace(3.301,7, n_interrogations/2)]';
            for i_query = 1:numel(interrogation_points)
                stim_point_left = find(stim_X <= interrogation_points(i_query), 1, 'last');
                stim_point_right = find(stim_X >= interrogation_points(i_query), 1, 'first');
                xright = stim_X(stim_point_right);
                xleft = stim_X(stim_point_left);
                yright = ci_l_stim_ecdf(stim_point_right);
                yleft = ci_l_stim_ecdf(stim_point_left);
                if isempty(xleft), xleft = 0;end
                if isempty(xright), xright = 17;end
                if isempty(yright), yright = 1;end
                if isempty(yleft), yleft = 0;end
                b = (yright-yleft)/(xright-xleft);
                interppoint_stim = yleft + b*(interrogation_points(i_query)-xleft);
                %            
                nostim_point_left = find(unstim_X <= interrogation_points(i_query), 1, 'last');
                nostim_point_right = find(unstim_X >= interrogation_points(i_query), 1, 'first');
                xright = unstim_X(nostim_point_right);
                xleft = unstim_X(nostim_point_left);
                yright = ci_u_sham_ecdf(nostim_point_right);
                yleft = ci_u_sham_ecdf(nostim_point_left);
                if isempty(xleft), xleft = 0;end
                if isempty(xright), xright = 17;end
                if isempty(yright), yright = 1;end
                if isempty(yleft), yleft = 0;end
                b = (yright-yleft)/(xright-xleft);
                interppoint_nostim = yleft + b*(interrogation_points(i_query)-xleft);
                %
                signif_diff_LEFT(i_query) = interppoint_nostim - interppoint_stim < 0;


                stim_point_left = find(stim_X <= interrogation_points(i_query), 1, 'last');
                stim_point_right = find(stim_X >= interrogation_points(i_query), 1, 'first');
                xright = stim_X(stim_point_right);
                xleft = stim_X(stim_point_left);
                yright = ci_u_stim_ecdf(stim_point_right);
                yleft = ci_u_stim_ecdf(stim_point_left);
                if isempty(xleft), xleft = 0;end
                if isempty(xright), xright = 17;end
                if isempty(yright), yright = 1;end
                if isempty(yleft), yleft = 0;end
                b = (yright-yleft)/(xright-xleft);
                interppoint_stim = yleft + b*(interrogation_points(i_query)-xleft);
                %            
                nostim_point_left = find(unstim_X <= interrogation_points(i_query), 1, 'last');
                nostim_point_right = find(unstim_X >= interrogation_points(i_query), 1, 'first');
                xright = unstim_X(nostim_point_right);
                xleft = unstim_X(nostim_point_left);
                yright = ci_l_sham_ecdf(nostim_point_right);
                yleft = ci_l_sham_ecdf(nostim_point_left);
                if isempty(xleft), xleft = 0;end
                if isempty(xright), xright = 17;end
                if isempty(yright), yright = 1;end
                if isempty(yleft), yleft = 0;end
                b = (yright-yleft)/(xright-xleft);
                interppoint_nostim = yleft + b*(interrogation_points(i_query)-xleft);
                %
                signif_diff_RIGHT(i_query) = interppoint_stim-interppoint_nostim < 0;                
            end

            signif_diff_LEFT = double(signif_diff_LEFT);
            signif_diff_RIGHT = double(signif_diff_RIGHT);
            signif_diff_LEFT(signif_diff_LEFT<1) = nan;
            signif_diff_RIGHT(signif_diff_RIGHT<1) = nan;


            
            h_sham = plot(ax,unstim_X,cdf_sham, '--', 'color', [0,0,0], 'linewidth', 3, 'displayname', nameS);
            h1_sham = plot(ax,unstim_X,ci_l_sham_ecdf, '-', 'color', [0,0,0], 'linewidth', 1, 'displayname', '95%CI');
            h2_sham = plot(ax,unstim_X,ci_u_sham_ecdf, '-', 'color', [0,0,0], 'linewidth', 1, 'displayname', '95%CI');
            getlinesandshadebetween(ax, [h1_sham,h2_sham], 'k');

            h_stim = plot(ax,stim_X,cdf_stim, '-', 'color', [0,0.5,0.9], 'linewidth', 3, 'displayname', nameA);
            h1_stim = plot(ax,stim_X,ci_l_stim_ecdf, '-', 'color', [0,0.5,0.9], 'linewidth', 1, 'displayname', '95%CI');
            h2_stim = plot(ax,stim_X,ci_u_stim_ecdf, '-', 'color', [0,0.5,0.9], 'linewidth', 1, 'displayname', '95%CI');
            getlinesandshadebetween(ax, [h1_stim,h2_stim], 'k');

            
            getlinesandshadebetween(ax, [h_stim,h_sham], 'c');
            reversePlotOrder(ax, 'reverse')

            plot(ax, interrogation_points, signif_diff_RIGHT, 'r-', 'linewidth', 6)
            plot(ax, interrogation_points, signif_diff_LEFT, 'g-', 'linewidth', 6)
        end
        function [bootNoStim, bootStim, boot_flick_s_wrtc, boot_stimTrialNos,boot_noStimTrialNos] = bootstrap_stim_dataset(obj, bootData0_or_shuffleStimID1_or_shuffleTrialOrder2, nboot)
            % 
            %   This function will bootstrap a new dataet for analysis
            %       if
            %           bootData0_or_shuffleStimID1_or_shuffleTrialOrder2 = 0:
            %               we will just regather the existing data, keeping labels the same
            %       if bootData0_or_shuffleStimID1_or_shuffleTrialOrder2 = 1;
            %               we will boot as above, but then shuffle the trial categories (stim vs sham)
            %       if bootData0_or_shuffleStimID1_or_shuffleTrialOrder2 = 2;
            %               we will boot as above, but then shuffle the trial ORDER
            %           ^^^ I'M NOT SURE METHOD 2 IS CORRECT...need to rewrite I think
            % 
            %       Assume we are calling from sloshingStimulation cObj. That means 
            %           data_nostim_full = obj.GLM.unstim_nexttrial_flicks;
            %           data_stim = obj.GLM.stim_nexttrial_flicks;
            %           will both have the nth trial forward (or 0 trial forward) built in
            % 
            % if ~isfield(obj.GLM.unstim_nexttrial_flicks_og)
            %     data_nostim_full = obj.GLM.unstim_nexttrial_flicks;
            %     data_stim = obj.GLM.stim_nexttrial_flicks;
            %     % save this before boot:
            %     obj.GLM.unstim_nexttrial_flicks_og = data_nostim_full;
            %     obj.GLM.stim_nexttrial_flicks_og = data_stim;
            % else
            %     % use the original data to boot
            %     data_nostim_full = obj.GLM.unstim_nexttrial_flicks_og;
            %     data_stim = obj.GLM.stim_nexttrial_flicks_og;
            % end
            disp('******check data_nostim_full and data_stim if this is a multi-session ESPobj')
            disp('*******this probs doesn''t work for session partition analysis')
            % should already be in sesssion trial order with nans in place
            data_nostim = obj.GLM.unstim_nexttrial_flicks;
            data_stim = obj.GLM.stim_nexttrial_flicks;

            allLickTrials = find(~isnan(obj.GLM.flick_s_wrtc));
            % we need to bootstrap trial numbers. Then we can map back onto whether they were stim or not
            bootTrials = allLickTrials(randi(numel(allLickTrials), numel(allLickTrials),nboot, 1));
            % decide if we will boot or permut
            if bootData0_or_shuffleStimID1_or_shuffleTrialOrder2 == 0 % boot a dataset
                bootStim = nan(size(bootTrials));
                bootStim(ismember(bootTrials, obj.GLM.stimTrials)) = data_stim(bootTrials(ismember(bootTrials, obj.GLM.stimTrials)));
                bootNoStim = nan(size(bootTrials));
                bootNoStim(ismember(bootTrials, obj.GLM.noStimTrials)) = data_nostim(bootTrials(ismember(bootTrials, obj.GLM.noStimTrials)));

                % get percent stim
                ogPercStim = sum(~isnan(obj.GLM.flick_s_wrtc(obj.GLM.stimTrials)))/(sum(~isnan(obj.GLM.flick_s_wrtc(obj.GLM.stimTrials))) + sum(~isnan(obj.GLM.flick_s_wrtc(obj.GLM.noStimTrials))));
                percStim = sum(~isnan(bootStim), 1)./(sum(~isnan(bootNoStim), 1)+sum(~isnan(bootStim), 1));
                disp([' %stim og: ' num2str(ogPercStim) ' | new %stim: ' num2str(percStim)])
                if sum(abs(ogPercStim-percStim) > 0.05) > 0
                    warning(['looking off wrt num stim, sum(abs(ogPercStim-percStim) > 0.05)=' num2str(sum(abs(ogPercStim-percStim) > 0.05)) ' (' num2str(sum(abs(ogPercStim-percStim) > 0.05)/nboot) ')'])
                end
            elseif bootData0_or_shuffleStimID1_or_shuffleTrialOrder2 == 1 % shuffle test -- here we change the trial identities
                ogPercStim = sum(~isnan(obj.GLM.flick_s_wrtc(obj.GLM.stimTrials)))/(sum(~isnan(obj.GLM.flick_s_wrtc(obj.GLM.stimTrials))) + sum(~isnan(obj.GLM.flick_s_wrtc(obj.GLM.noStimTrials))));
                permtrials = allLickTrials(randperm(numel(allLickTrials),numel(allLickTrials)));
                stimpermtrials = permtrials(1:floor(ogPercStim*numel(allLickTrials)));
                nostimpermtrials = permtrials(floor(ogPercStim*numel(allLickTrials)+1:end));
                alldata = sum([obj.GLM.unstim_nexttrial_flicks, obj.GLM.stim_nexttrial_flicks], 2, 'omitnan');
                alldata(alldata==0) = nan;
                bootStim = nan(size(bootTrials));
                bootStim(ismember(bootTrials, stimpermtrials)) = alldata(bootTrials(ismember(bootTrials, stimpermtrials)));
                bootNoStim = nan(size(bootTrials));
                bootNoStim(ismember(bootTrials, nostimpermtrials)) = alldata(bootTrials(ismember(bootTrials, nostimpermtrials)));
                percStim = sum(~isnan(bootStim), 1)./(sum(~isnan(bootNoStim), 1)+sum(~isnan(bootStim), 1));
                disp([' %stim og: ' num2str(ogPercStim) ' | new %stim: ' num2str(percStim)])
                if sum(abs(ogPercStim-percStim) > 0.05) > 0
                    warning(['looking off wrt num stim, sum(abs(ogPercStim-percStim) > 0.05)=' num2str(sum(abs(ogPercStim-percStim) > 0.05)) ' (' num2str(sum(abs(ogPercStim-percStim) > 0.05)/nboot) ')'])
                end
            elseif bootData0_or_shuffleStimID1_or_shuffleTrialOrder2 == 2 % shuffle test -- here we change the trial ORDER
                error('I don''t think this is working, this should erase any structure...but I guess there was structure not due to stim...and we are erasing that...')
                ogPercStim = sum(~isnan(obj.GLM.flick_s_wrtc(obj.GLM.stimTrials)))/(sum(~isnan(obj.GLM.flick_s_wrtc(obj.GLM.stimTrials))) + sum(~isnan(obj.GLM.flick_s_wrtc(obj.GLM.noStimTrials))));
                alldata = sum([obj.GLM.unstim_nexttrial_flicks, obj.GLM.stim_nexttrial_flicks], 2, 'omitnan');
                alldata(alldata==0) = nan;
                % shuffle next trial here:
                alldata = alldata(randperm(numel(alldata),numel(alldata)));
                bootStim = nan(size(bootTrials));
                bootStim(ismember(bootTrials,obj.GLM.stimTrials)) = alldata(bootTrials(ismember(bootTrials, obj.GLM.stimTrials)));
                bootNoStim = nan(size(bootTrials));
                bootNoStim(ismember(bootTrials,obj.GLM.noStimTrials)) = alldata(bootTrials(ismember(bootTrials, obj.GLM.noStimTrials)));
                percStim = sum(~isnan(bootStim), 1)./(sum(~isnan(bootNoStim), 1)+sum(~isnan(bootStim), 1));
                disp([' %stim og: ' num2str(ogPercStim) ' | new %stim: ' num2str(percStim)])
                if sum(abs(ogPercStim-percStim) > 0.05) > 0
                    warning(['looking off wrt num stim, sum(abs(ogPercStim-percStim) > 0.05)=' num2str(sum(abs(ogPercStim-percStim) > 0.05)) ' (' num2str(sum(abs(ogPercStim-percStim) > 0.05)/nboot) ')'])
                end
            end

            boot_stimTrialNos = nan(size(bootTrials));
            boot_stimTrialNos(ismember(bootTrials, obj.GLM.stimTrials)) = bootTrials(ismember(bootTrials, obj.GLM.stimTrials));

            boot_noStimTrialNos = nan(size(bootTrials));
            boot_noStimTrialNos(ismember(bootTrials, obj.GLM.noStimTrials)) = bootTrials(ismember(bootTrials, obj.GLM.noStimTrials));

            boot_flick_s_wrtc = nan(size(bootTrials));
            boot_flick_s_wrtc = obj.GLM.flick_s_wrtc(bootTrials);

        end
    end




















    methods (Static)
        function [binned_spikes, spikes_wrt_event, firstspike_wrt_event] = binupspikes(spikes, refevents,s_b4, s_post)
            binned_spikes = cell(numel(refevents),1);    
            spikes_wrt_event = cell(numel(refevents),1);
            firstspike_wrt_event = nan(numel(refevents),1);
            for i_ref = 1:numel(refevents)
                spikes_before_event = spikes < refevents(i_ref) + s_post;
                spikes_after_event = spikes > refevents(i_ref)-s_b4;
                binned_spikes{i_ref} = spikes(spikes_before_event & spikes_after_event);
                spikes_wrt_event{i_ref} = binned_spikes{i_ref} - refevents(i_ref);
                
                if ~isempty(spikes_wrt_event{i_ref})
                    % get the first spike wrt the event:
                    firstspike_idx = find(spikes_wrt_event{i_ref}>0,1,'first');
                    if ~isempty(firstspike_idx)
                        firstspike_wrt_event(i_ref) = spikes_wrt_event{i_ref}(firstspike_idx);
                    end

                    % assert conditions for binning
                    assert(binned_spikes{i_ref}(1) > refevents(i_ref)-s_b4 && binned_spikes{i_ref}(end) < refevents(i_ref)+s_post);
                    assert(spikes_wrt_event{i_ref}(1) > 0-s_b4 && spikes_wrt_event{i_ref}(end) < s_post);
                end
            end
        end
        function ax = plotraster(spikes_wrt_event, first_spike_wrt_event, varargin)
            p = inputParser;
            addParameter(p, 'ax', [], @isaxes); 
            addParameter(p, 'markerSize', 10, @isnumeric); 
            addParameter(p, 'dispName', 'data', @ischar);
            addParameter(p, 'Color', [0,0,0], @isnumeric);
            addParameter(p, 'referenceEventName', 'Reference Event', @ischar);
            addParameter(p, 'append', false, @islogical);
            addParameter(p, 'plotFirst', true, @islogical);
            addParameter(p, 'Alpha', 0.7, @isnumeric)
            parse(p, varargin{:});
            ax      = p.Results.ax;
            markerSize      = p.Results.markerSize;
            dispName        = p.Results.dispName;
            Color           = p.Results.Color;
            ReferenceEventName  = p.Results.referenceEventName;
            append          = p.Results.append;
            plotFirst       = p.Results.plotFirst;
            Alpha           = p.Results.Alpha;
            if isempty(ax), [~, ax] = makeStandardFigure();end
            % 
            %   Plot raster of all licks with first licks overlaid
            % 
            numRefEvents = numel(first_spike_wrt_event);
            if ~append
                plot(ax, [0,0], [1,numRefEvents],'r-', 'DisplayName', ReferenceEventName)
                set(ax,  'YDir','reverse')
                ylim(ax, [1, numRefEvents])
            end
            if plotFirst % plot the first event after the cue
                scatter(ax, first_spike_wrt_event, 1:numRefEvents, markerSize+150, Color, 'filled', 'DisplayName', dispName, 'MarkerFaceAlpha',0.3, 'markeredgecolor', 'k');
            end
            
        %   for iexc = obj.iv.exclusions_struct.Excluded_Trials
        %       spikes_wrt_event{iexc} = [];
        %     end
            for itrial = 1:numRefEvents
                plotpnts = spikes_wrt_event{itrial};
                if ~isempty(plotpnts)
                    if ~plotFirst && itrial==1
                        scatter(ax, plotpnts, itrial.*ones(numel(plotpnts), 1), markerSize, Color, 'filled','DisplayName', dispName, 'MarkerFaceAlpha',Alpha)             
                    else
                        scatter(ax, plotpnts, itrial.*ones(numel(plotpnts), 1), markerSize, Color, 'filled','handlevisibility', 'off', 'MarkerFaceAlpha',Alpha)               
                    end
                end
            end 
            yy = get(ax, 'ylim');
            ylim(ax, yy);
            legend(ax,'show', 'location', 'best')
            ylabel(ax,[ReferenceEventName, ' #'])
            xlabel(ax,['Time (s) wrt ' ReferenceEventName])
        end

        function b = bootdata(data, n)
            b = nan(n, numel(data));
            for ii = 1:n
                b(ii, :) = datasample(data,numel(data));
            end
        end
        function [ci_l, ci_u] = bootCI(b, Alpha)
            % 
            %   rows = replicates, columns = data
            % 
            i_l = round((Alpha/2)*size(b, 1));
            i_u = round((1-(Alpha/2))*size(b, 1));
            
            bsorted = sort(b, 1);
            if sum(sum(isnan(b))) > 0
                error('hey! there are nans in the thing you''re trying to get a CI on...')
            end
            %     bsorted = sort(b, 1);
            % else
            %     bsorted = obj.nansort(b, 1);
            % end
            
            ci_l = bsorted(i_l, :);
            ci_u = bsorted(i_u, :);
        end
        
        % function sorted = nansort(obj, data, dim)
        %     num2process = size(data', dim);

        %     for ii = 1:num2process
        % end
        function [e_remapped, ix_remapped] = remap_boot_ecdf(data, trueX)
            [e, x] = ecdf(data);
            % get the last unique entry in x
            [~,~,J] = unique(x);
            jump = find([true; diff(J); true]);
            last = jump(2:end)-1;
            % remap the boot x to the full x array
            [~,ix_remapped] = ismember(x(last),trueX);
            e_remapped = e(last);
            % bootArray(ii, ix_remapped) = e_remapped;
        end
        
    end
end