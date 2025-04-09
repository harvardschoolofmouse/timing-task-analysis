classdef CLASS_ZigZagTimeWindows < handle
	% 
	% 	Made for CLASS_photometry_roadmapv1_4.m to do regression models and plots.
	% 
	% 	Created 	5/27/24	ahamilos
	% 	Modified 	ahamilos    4/9/2025       versionCode = 'v2.0.1'
	% 
	% 
	properties
		iv
		LTA
		analysis
	end

	%-------------------------------------------------------
	%		Methods: Initialization
	%-------------------------------------------------------
	methods
		function obj = CLASS_ZigZagTimeWindows(sObj, Mode)
			% 
			% 	Mode options: peaks (uses peaks); mean
			% 
            if ~isfield(sObj.GLM,'trials_by_block')
                gettimeshiftvariables_FX
            end
			if isfield(sObj.GLM,'trials_by_block')
				obj.getTrialsByBlock(sObj);
			else
				warning('need to specify trials_by_block field of sObj.GLM. Format is cell with ranges, eg {1:121, 122:230...}. Do so, then run obj.getTrialsByBlock')
			end
			if isfield(sObj.GLM,'reward_windows_by_block') || isfield(sObj.GLM,'block_legend')
				obj.getBlockLegend(sObj);
			else
				warning('need to specify reward_windows_by_block field of sObj.GLM. Format is a cell with strings, eg {"3.3-7s", "7-12s..."}. You can use this to specify whatever was special about the block (ie cold be stim params. Do so, then run obj.getBlockLegend')
			end
			if ~isfield(sObj.iv, 'sessionCode'), sObj.getSeshName;end
			% 
			% before we do anything else, you need to fix the block windows and such if not done yet
			%
			if ~isfield(sObj.GLM, 'CED_MBI_block_agreement') || ~(strcmpi(sObj.GLM.CED_MBI_block_agreement, 'perfect match') || strcmpi(sObj.GLM.CED_MBI_block_agreement,'same number of blocks, but trial numbers didnt agree. we used CED for trial starts') || strcmpi(sObj.GLM.CED_MBI_block_agreement,'CED had more blocks than MBI, so we found starts closest \nto MBI and killed the extras. we then \nused CED for trial starts'))
				[sObj,f] = auto_detect_extra_events(sObj, true);
				disp('saving resvised sObj with corrected rewarded trials and CED blocks, all using CED!')
				sObj.save;
			end

			if nargin < 2, Mode = 'peaks';end
			% hardcoded for now.....
			obj.LTA.RPEwin_xshift = 0;
			obj.LTA.smoothing = 100;
			obj.LTA.RPEwin = 500;

			obj.iv.runID = randi(100000);
			obj.iv.versionCode = ['CLASS_ZigZagTimeWindows | obj created: ' datestr(now)];
			obj.iv.Mode = Mode;

			obj.getIV(sObj);

			obj.switchMode(Mode, sObj)
			
			% warning('obj not saved by default')
			% disp(sprintf(['	ZigZagTimeWindowsObj created. Try out these fxns!',...
				% '\n obj.plot % will plot the dual DA/trial and DA/rewno plots',...
				% '\n ax = obj.plot(''block-LTAs'', sObj, 1:19, ''first'', 50) % plots first 50 trials within each block as LTAs. Can also do ''last'' or ''all''',...
				% '\n obj.switchMode(Mode, sObj) % Mode can be peaks or mean, this will switch it']))
		end
		function switchMode(obj, Mode, sObj, sloshing_obj)
			% 
			% 	Mode options: peaks (uses peaks)
			%					peaks-normalize
			%					mean
			%					mean-normalize
			% 
			if isfield(obj.LTA, 'moveControlMode')
				try
					if nargin < 4, load_sObj_sloshing_zzt, end
					obj.gatherMovementControls;
				catch
					error('The move controls mode couldnt be switched!! Check what happened and make sure this matches!')
				end
			end
			obj.LTA.Mode =Mode;
			if strcmpi(Mode, 'peaks')
				obj.LTA.usemean = false;
				obj.LTA.usepeaks = true;
				obj.LTA.Normalize  = false;
			elseif strcmpi(Mode, 'peaks-normalize')
				obj.LTA.usemean = false;
				obj.LTA.usepeaks = true;
				obj.LTA.Normalize  = true;
			elseif strcmpi(Mode, 'mean')
				obj.LTA.usemean = true;
				obj.LTA.usepeaks = false;
				obj.LTA.Normalize  = false;
			elseif strcmpi(Mode, 'mean-normalize')
				obj.LTA.usemean = true;
				obj.LTA.usepeaks = false;
				obj.LTA.Normalize  = true;
			end
			% do business
			if ~isfield(obj.LTA,'ntrials')
				obj.getRPEInfo(sObj);
			else
				obj.redoLTA;
			end
		end
		function save(obj)
			ID = obj.iv.runID;
			savefilename = ['ZigZagTimeWindowsObj_' obj.iv.sessionCode '_' datestr(now, 'YYYYmmDD_HH_MM') '_runIDno' num2str(ID)];
			obj.iv.savedFileName_zigzag = correctPathOS([pwd, '\' , savefilename, '.mat']);
            try
    			save([savefilename, '.mat'], 'obj', '-v7.3');
            catch
                warning('file name looks too long. truncating')
                save([savefilename(1:50), '.mat'], 'obj', '-v7.3');
            end
			obj.writeProvenance;	
		end
		function writeProvenance(obj)
			ID = obj.iv.runID;
			
            Time = datestr(now, 'YYYYmmDD_HH_MM');
            fileID = fopen(['ZigZagTimeWindows_provenance_runID' num2str(ID) '__' Time '.txt'],'w');
			fprintf(fileID,...
				sprintf([...
                ['obj = CLASS_ZigZagTimeWindows(sObj, ' obj.iv.Mode ')'],...
				'\n\nsessionCode:	' obj.unwrap_Cellstr(obj.iv.sessionCode),... 
				'\n\noriginal sObj:	' obj.unwrap_Cellstr(obj.iv.filename_),...
				'\nPath:	' obj.unwrap_Cellstr(obj.iv.path_),...
			 	])...
			 	);
                fclose(fileID);
			
			disp(['>> Wrote provenance file to: ' correctPathOS([pwd '/' ['provenance_runID' num2str(ID) '__' Time]])])
		end
		function Str = setUserDataStandards(obj, Caller, f)		
			Str = sprintf([Caller,...
			'\n\nCLASS_ZigZagTimeWindows obj',...
			'\n\nsessionCode:	' obj.iv.sessionCode,... 
			'\n\noriginal sObj:	' obj.iv.filename_,...
			'\nPath:	' obj.unwrap_Cellstr(obj.iv.path_),...
		    ]);
		    set(f, 'userdata', Str);
		end
		function str = unwrap_Cellstr(obj, C)	
			if iscell(C)
                str = {};
				for iC = 1:numel(C)
					if isnumeric(C{iC}) || islogical(C{iC})
						if numel(C{iC} > 1)
							str{end+1} = num2str(C{iC});
							str{end} = ['[', str{end}, ']'];
						else
							str{end+1} = num2str(C{iC});
						end
					elseif iscell(C{iC})
						str{end+1} = obj.unwrap_Cellstr(C{iC});
					else
						str{end+1} = C{iC};
					end
					if iC ~= numel(C)
						str{end+1} = ', ';
					end
	            end
	            str = cell2mat(str);
            elseif isnumeric(C) || islogical(C)
            	str = mat2str(C);
        	elseif isstruct(C)
        		fn = fieldnames(C);
        		str = {};
        		for ifield = 1:numel(fn)
        			str{ifield} = [correctPathOS([fn{ifield},': ' eval(['obj.unwrap_Cellstr(C.', fn{ifield} ');'])], 'mac'), '\n'];
    			end
    			str = cell2mat(str);
        	else
        		str = correctPathOS(C, 'mac');
    		end
            
            if iscell(C)
	            str = ['{' str '}'];
            elseif isnumeric(C) || islogical(C)
            	str = ['[' str ']'];
            end
            str = sprintf(str);
		end
		function getTrialsByBlock(obj, sObj);
			% either pass in the sObj or a cell of strings for sObj
			if iscell(sObj)
				obj.LTA.trials_by_block = sObj;
			else
				obj.LTA.trials_by_block = sObj.GLM.trials_by_block;
			end
		end
		function getBlockLegend(obj, sObj);
			% either pass in the sObj or a cell of strings for sObj
			if iscell(sObj)
				obj.LTA.block_legend = sObj;
			elseif isfield(sObj.GLM,'reward_windows_by_block')
				obj.LTA.block_legend = sObj.GLM.reward_windows_by_block;
			elseif isfield(sObj.GLM,'block_legend')
				obj.LTA.block_legend = sObj.GLM.block_legend;
			end
        end

      
            
		function getRPEInfo(obj, sObj)
			if strcmpi(obj.iv.signalname, 'EMG') || strcmpi(obj.iv.signalname, 'X')
			    sObj.GLM.gfit = sObj.GLM.gfit(1:2:end);
			end
			sObj.getBinnedTimeseries(sObj.GLM.gfit, 'singletrial', [], 30000);
			smoothedLTA = cellfun(@(x) v3x_smooth(x,obj.LTA.smoothing), sObj.ts.BinnedData.LTA, 'uniformoutput', 0)';

			trials_in_each_bin = sObj.ts.BinParams.trials_in_each_bin;
			lick_time = [sObj.ts.BinParams.s.CLTA_Max]';

			LTA_timestamps_s = sObj.ts.Plot.LTA.xticks.s;

			ntrials = numel(sObj.GLM.flick_s_wrtc);
			next_trial = cell2mat(sObj.ts.BinParams.trials_in_each_bin)+1;
			lick_time_next_trial = sObj.GLM.flick_s_wrtc(next_trial);
			lick_time_next_trial(next_trial == sObj.iv.num_trials+1) = nan;
			log_lick_time_next_trial = log(lick_time_next_trial);
			delta_lick_time = lick_time_next_trial - lick_time;

          

			rewards_so_far = nan(ntrials,1);
			rewards_counter = 0;
			rewarded = zeros(ntrials, 1);
			for i=1:ntrials
			    rewards_so_far(i) = rewards_counter;
			    if ismember(i, sObj.GLM.rewardedTrials)
			        rewards_counter = rewards_counter+1;
			        % 4. tag each trial by rewarded or unrewarded
			        rewarded(i) = 1;
			    end
			end
			rewarded = logical(rewarded);%unrewarded = ~rewarded;


			
			obj.LTA.rewarded = rewarded;
			obj.LTA.rewards_so_far = rewards_so_far;
			obj.LTA.smoothedLTA = smoothedLTA;
			obj.LTA.ntrials = ntrials;
			obj.LTA.trials_in_each_bin = trials_in_each_bin;
			obj.LTA.lick_time = lick_time;
			obj.LTA.LTA_timestamps_s = LTA_timestamps_s;


			obj.LTA.next_trial = next_trial;
			obj.LTA.lick_time_next_trial = lick_time_next_trial;
			obj.LTA.log_lick_time_next_trial = log_lick_time_next_trial;
			obj.LTA.delta_lick_time = delta_lick_time;
			obj.LTA.flick_s_wrtc = sObj.GLM.flick_s_wrtc;

			obj.redoLTA()
		end			
		function redoLTA(obj)
			ntrials = obj.LTA.ntrials;
			trials_in_each_bin = obj.LTA.trials_in_each_bin;
			lick_time = obj.LTA.lick_time;
			LTA_timestamps_s = obj.LTA.LTA_timestamps_s;

			smoothedLTA = obj.LTA.smoothedLTA;
			RPEwin_xshift = obj.LTA.RPEwin_xshift;
			smoothing = obj.LTA.smoothing;
			RPEwin = obj.LTA.RPEwin;

			lick_time_next_trial = obj.LTA.next_trial;
			next_trial = obj.LTA.lick_time_next_trial;
			flick_s_wrtc = obj.LTA.flick_s_wrtc;
			rewarded=obj.LTA.rewarded;
			rewards_so_far = obj.LTA.rewards_so_far;

			

			xzero = find(LTA_timestamps_s == 0);
			window_start_pos = xzero + RPEwin_xshift;

			mins = cell2mat(cellfun(@(x) min(x(window_start_pos:window_start_pos+RPEwin)), smoothedLTA, 'uniformoutput', 0));
			maxs = cell2mat(cellfun(@(x) max(x(window_start_pos:window_start_pos+RPEwin)), smoothedLTA, 'uniformoutput', 0));
			% prep mean/median signals
			means = cell2mat(cellfun(@(x) mean(x(window_start_pos:window_start_pos+RPEwin)), smoothedLTA, 'uniformoutput', 0));
			medians = cell2mat(cellfun(@(x) median(x(window_start_pos:window_start_pos+RPEwin)), smoothedLTA, 'uniformoutput', 0));

			if isfield(obj.LTA, 'tdt')
				smoothedLTA_tdt = obj.LTA.tdt.smoothedLTA;
				mins_tdt = cell2mat(cellfun(@(x) min(x(window_start_pos:window_start_pos+RPEwin)), smoothedLTA_tdt, 'uniformoutput', 0));
				maxs_tdt = cell2mat(cellfun(@(x) max(x(window_start_pos:window_start_pos+RPEwin)), smoothedLTA_tdt, 'uniformoutput', 0));
				% prep mean/median signals
				means_tdt = cell2mat(cellfun(@(x) mean(x(window_start_pos:window_start_pos+RPEwin)), smoothedLTA_tdt, 'uniformoutput', 0));
				medians_tdt = cell2mat(cellfun(@(x) median(x(window_start_pos:window_start_pos+RPEwin)), smoothedLTA_tdt, 'uniformoutput', 0));
	    	end
			
			% map this back to the trial order so we can predict behavior on next trial
			
			shuffled_lick_time_next_trial = lick_time_next_trial(randperm(numel(lick_time_next_trial)));
			shuffled_lick_time_next_trial(next_trial == ntrials+1) = nan;
			shuffled_delta_lick_time = shuffled_lick_time_next_trial - lick_time;


			% assign RPE to each trial: (note this means RAILS signal)
			RPE = nan(numel(lick_time_next_trial),1);
			RPE_tdt = nan(numel(lick_time_next_trial),1);
			
			if obj.LTA.usepeaks
			    % warning('using peaks for RPE, not rails')
			    RPE = maxs;

			    max_session_trial_order = nan(numel(flick_s_wrtc),1);
			    max_session_trial_order(cell2mat(trials_in_each_bin)) = maxs;
			    SIGNAL_session_trial_order = max_session_trial_order;

			    if isfield(obj.LTA, 'tdt')
			    	% disp('====== warning, using MIN for tdt, as excursion at VLS tends to be negative========')
			    	RPE_tdt = maxs_tdt;
			    	max_session_trial_order_tdt = nan(numel(flick_s_wrtc),1);
				    max_session_trial_order_tdt(cell2mat(trials_in_each_bin)) = maxs_tdt;
				    tdt_session_trial_order = max_session_trial_order_tdt;
			    end

			    Title = [obj.iv.sessionCode  'peaks'];
			   
			elseif obj.LTA.usemean
			    % warning('using mean for RPE, not rails')
			    RPE = means;

			    mean_session_trial_order = nan(numel(flick_s_wrtc),1);
			    mean_session_trial_order(cell2mat(trials_in_each_bin)) = means;

			    if isfield(obj.LTA, 'tdt')
			    	RPE_tdt = means_tdt;
			    	mean_session_trial_order_tdt = nan(numel(flick_s_wrtc),1);
			    	mean_session_trial_order_tdt(cell2mat(trials_in_each_bin)) = means_tdt;
			    	tdt_session_trial_order = mean_session_trial_order_tdt;
			    end

			    SIGNAL_session_trial_order = mean_session_trial_order;
			    Title = [obj.iv.sessionCode ' mean'];
			end
			if obj.LTA.Normalize
			    % warning('normalizing')
			    RPE = RPE-nanmin(RPE);
			    RPE = RPE/nanmax(RPE);
			    SIGNAL_session_trial_order = SIGNAL_session_trial_order-nanmin(SIGNAL_session_trial_order);
			    SIGNAL_session_trial_order = SIGNAL_session_trial_order/nanmin(SIGNAL_session_trial_order);

			    if isfield(obj.LTA, 'tdt')
			    	RPE_tdt = RPE_tdt-nanmin(RPE_tdt);
				    RPE_tdt = RPE_tdt/nanmax(RPE_tdt);
				    tdt_session_trial_order = tdt_session_trial_order-nanmin(tdt_session_trial_order);
				    tdt_session_trial_order = tdt_session_trial_order/nanmin(tdt_session_trial_order);
			    end
			end

			RPE_session_trial_order = nan(numel(flick_s_wrtc),1);
			RPE_session_trial_order(cell2mat(trials_in_each_bin)) = RPE;

			max_session_trial_order = nan(numel(flick_s_wrtc),1);
			max_session_trial_order(cell2mat(trials_in_each_bin)) = maxs;

			median_session_trial_order = nan(numel(flick_s_wrtc),1);
			median_session_trial_order(cell2mat(trials_in_each_bin)) = medians;

			mean_session_trial_order = nan(numel(flick_s_wrtc),1);
			mean_session_trial_order(cell2mat(trials_in_each_bin)) = means;

			lick_time_session_trial_order = flick_s_wrtc;


			trials_rewarded = find(rewarded==1);
			lick_time_rewarded = lick_time_session_trial_order(rewarded);
			rewards_so_far_rewarded = rewards_so_far(rewarded);
			rewarded_RPE = RPE_session_trial_order(rewarded);



			
			obj.LTA.RPEwin_xshift = RPEwin_xshift;
			obj.LTA.xzero = xzero;
			obj.LTA.shuffled_lick_time_next_trial = shuffled_lick_time_next_trial;
			obj.LTA.shuffled_delta_lick_time = shuffled_delta_lick_time;

			obj.LTA.window_start_pos = window_start_pos;
			obj.LTA.smoothing = smoothing;
			obj.LTA.RPEwin = RPEwin;

			obj.LTA.SIGNAL_session_trial_order = SIGNAL_session_trial_order;
			if isfield(obj.LTA, 'tdt')
				obj.LTA.tdt_session_trial_order = tdt_session_trial_order;
			end
			obj.LTA.lick_time_session_trial_order = lick_time_session_trial_order;
			obj.LTA.trials_rewarded = trials_rewarded;
			obj.LTA.lick_time_rewarded = lick_time_rewarded;
			obj.LTA.rewards_so_far_rewarded = rewards_so_far_rewarded;
			obj.LTA.rewarded_RPE = rewarded_RPE;
            obj.LTA.max_session_trial_order = max_session_trial_order;
			obj.LTA.median_session_trial_order = median_session_trial_order;
			obj.LTA.mean_session_trial_order = mean_session_trial_order;
			
			obj.LTA.mins = mins;
			obj.LTA.maxs = maxs;
			obj.LTA.means = means;
			obj.LTA.medians = medians;
		end
		function getIV(obj, sObj)
			obj.iv.sessionCode = sObj.iv.sessionCode;
			obj.iv.mousename_ = sObj.iv.mousename_;
			obj.iv.signalname_ = sObj.iv.signalname_;
			obj.iv.setStyle = sObj.iv.setStyle; 
			obj.iv.date = sObj.iv.date; 
			obj.iv.exptype_ = sObj.iv.exptype_; 
			obj.iv.rxnwin_ = sObj.iv.rxnwin_; 
			obj.iv.total_time_ = sObj.iv.total_time_; 
			obj.iv.num_trials = sObj.iv.num_trials; 
			obj.iv.signalname = sObj.iv.signalname;
			obj.iv.signaltype_ = sObj.iv.signaltype_;
			obj.iv.daynum_ = sObj.iv.daynum_;
			obj.iv.filename_ = sObj.iv.filename_;
			obj.iv.path_ = sObj.iv.path_;
			obj.iv.exclusion_criteria_version_ = sObj.iv.exclusion_criteria_version_;
			obj.iv.excludedtrials_ = sObj.iv.excludedtrials_;
			obj.iv.exclusions_struct = sObj.iv.exclusions_struct;
		end
		function [ax,f] = plot(obj, Mode, sObj, nbins, TrialMode, n, ax, Normalize_0_1)
			% 
			% 	Mode = 'block-LTAs'
			%			'RPE-trial-order'
			%			'RPE-trial-order-tdt'
			%			'RPE-reward-order'
			%			'RPE-trial-and-reward-orders'
			%			'raster+hxg'
			% 
			% 	 TrialMode = 'all', 'first', 'last'; where n is the number to plot first or last from each block
			% 
			if nargin < 2, Mode = 'RPE-trial-and-reward-orders';end
			if nargin < 3, sObj = []; end
			if nargin < 4, nbins =1:19; end
			if nargin < 5, TrialMode = 'all';end
			if nargin < 6, n = nan;end
			if nargin < 7, ax=[];end
			if nargin < 8, Normalize_0_1 = false;end
			Caller = ['obj.plot(' Mode ', sObj, nbins=[' num2str(nbins) '], TrialMode=' TrialMode ', n=' num2str(n)  ', axused=' , num2str(~isempty(ax)) ', Normalize_0_1=' num2str(Normalize_0_1) ')'];

			if ~(obj.LTA.RPEwin_xshift==0) || ~(obj.LTA.RPEwin == 500)
				warning(['RPEwin_xshift=' num2str(obj.LTA.RPEwin_xshift) ' | RPEwin=' num2str(obj.LTA.RPEwin)])
			end
			if strcmpi(Mode, 'block-LTAs')
				if isempty(ax)
					[f,ax] = makeStandardFigure(numel(obj.LTA.trials_by_block), [1,numel(obj.LTA.trials_by_block)]);
				end
				for ii =1:numel(obj.LTA.trials_by_block)
					if strcmpi(TrialMode, 'all')
					    sObj.getBinnedTimeseries(sObj.GLM.gfit, 'custom', [0,1000,2000,2001,2500,3000,3333,3334,4000:1000:17000], 30000, obj.LTA.trials_by_block{ii});
				    elseif strcmpi(TrialMode, 'first')
				    	sObj.getBinnedTimeseries(sObj.GLM.gfit, 'custom', [0,1000,2000,2001,2500,3000,3333,3334,4000:1000:17000], 30000, obj.LTA.trials_by_block{ii}(1:n));
			    	elseif strcmpi(TrialMode, 'last')
		    			sObj.getBinnedTimeseries(sObj.GLM.gfit, 'custom', [0,1000,2000,2001,2500,3000,3333,3334,4000:1000:17000], 30000, obj.LTA.trials_by_block{ii}(end-n:end));
	    			else
		    			error('undefined TrialMode')
	    			end
				    sObj.plot('LTA', nbins, ax(ii), 100, 'last-to-first', true);xlim(ax(ii),[-2,7]);
				    title(ax(ii), sprintf(['BLOCK ' num2str(ii) ': ' obj.LTA.block_legend{ii} '\n' num2str(obj.LTA.trials_by_block{ii}(1)) ':' num2str(obj.LTA.trials_by_block{ii}(end))]));
				    if ii ==1, yy = get(ax(1),'ylim'); end
				    ylim(ax(ii), yy);
				    xlim(ax(ii), [-2,7]);
				    set(ax(ii), 'fontsize', 10);
				    if ii ~= numel(obj.LTA.trials_by_block),  legend(ax(ii),'hide'); end
				end
				set(f, 'name', obj.iv.sessionCode)
			elseif strcmpi(Mode, 'RPE-trial-order') || strcmpi(Mode, 'RPE-trial-order-tdt')
				if isempty(ax)
					[f,ax] = makeStandardFigure(1,[1,1]);
				end
				
				if strcmpi(Mode, 'RPE-trial-order-tdt')
					disp('======= Plotting ABS tdt ========')
					% tdt dataset
					if ~isfield(obj.LTA, 'tdt_session_trial_order')
						error(sprintf(['this is not a tdt-compatible dataset. need to collect tdt from sloshing_obj. Run:\n'...
							'sloshing_obj = CLASS_sloshing_model_obj(sObj);\n'...
	            			'zzt.LTA.tdt.tdt_LTA = sloshing_obj.LTA.tdt.tdt_LTA;\n'...
	            			'sObj.getBinnedTimeseries(sObj.GLM.tdt, ''singletrial'', [], 30000);\n'...
            				'smoothed_LTA_tdt = cellfun(@(x) abs(v3x_smooth(x,zzt.LTA.smoothing)), sObj.ts.BinnedData.LTA, ''uniformoutput'', 0);\n'...
	            			'zzt.LTA.tdt.smoothedLTA = smoothed_LTA_tdt;\n'...
	            			'zzt.redoLTA;']))
					end
					if Normalize_0_1, nbbr = normalize_0_1(obj.LTA.tdt_session_trial_order(obj.LTA.rewarded), true);nbbnr = normalize_0_1(obj.LTA.tdt_session_trial_order(~obj.LTA.rewarded), true);
			    		else, nbbr = obj.LTA.tdt_session_trial_order(obj.LTA.rewarded); nbbnr = obj.LTA.tdt_session_trial_order(~obj.LTA.rewarded);end
				else
					disp('======= Plotting gfit ========')
					if Normalize_0_1, nbbr = normalize_0_1(obj.LTA.SIGNAL_session_trial_order(obj.LTA.rewarded), true);nbbnr = normalize_0_1(obj.LTA.SIGNAL_session_trial_order(~obj.LTA.rewarded), true);
				    		else, nbbr = obj.LTA.SIGNAL_session_trial_order(obj.LTA.rewarded); nbbnr = obj.LTA.SIGNAL_session_trial_order(~obj.LTA.rewarded);end
		    	end
		    	nbb = nan(obj.LTA.ntrials, 1);
		    	nbb(obj.LTA.rewarded) = nbbr;
		    	nbb(~obj.LTA.rewarded) = nbbnr;
				
				for ii=1:obj.LTA.ntrials
				    if obj.LTA.rewarded(ii)
				        plot(ax,ii, nbb(ii),'r.', 'markersize', 20, 'handlevisibility', 'off')
				    else
				        plot(ax,ii, nbb(ii),'k.','markersize', 20, 'handlevisibility', 'off')
				    end
				end
				% plot the running average
				% rtix = find(obj.LTA.rewarded);
				% nrtix = find(~obj.LTA.rewarded);
				% killrix = find(isnan(nbbr));
				% killnrix = find(isnan(nbbnr));
				% rtix(killrix) = [];
				% nrtix(killnrix) = [];
				% plot(ax,rtix, movmean(nbbr(~isnan(nbbr)), 20),'r-', 'linewidth', 2, 'displayname', 'rewarded')
				% plot(ax,nrtix, movmean(nbbnr(~isnan(nbbnr)), 20),'k-', 'linewidth', 2, 'displayname', 'unrewarded')

				% fill missing
				rtix = find(obj.LTA.rewarded);
				nrtix = find(~obj.LTA.rewarded);
				killrix = find(isnan(nbbr));
				killnrix = find(isnan(nbbnr));
				rtix(killrix) = [];
				nrtix(killnrix) = [];
				ntrialstoaverageover = 20;
				nbbrmov = movmean(nbbr(~isnan(nbbr)), ntrialstoaverageover);
				nbbnrmov = movmean(nbbnr(~isnan(nbbnr)), ntrialstoaverageover);

				nbbr_filled = nan(size(obj.LTA.rewarded));
				nbbnr_filled = nan(size(obj.LTA.rewarded));
				nbbr_filled(rtix) = nbbrmov;
				nbbnr_filled(nrtix) = nbbnrmov;
				nbbr_filled = fillmissing(nbbr_filled, 'linear');
				nbbnr_filled = fillmissing(nbbnr_filled, 'linear');
				% kill edges
				if rtix(1)>1
					nbbr_filled(1:rtix(1)-1) = nan;
				end
				if rtix(end)<numel(obj.LTA.rewarded)
					nbbr_filled(rtix(end)+1:end) = nan;
				end
				if nrtix(1)>1
					nbbnr_filled(1:nrtix(1)-1) = nan;
				end
				if nrtix(end)<numel(obj.LTA.rewarded)
					nbbnr_filled(nrtix(end)+1:end) = nan;
				end
				plot(ax,1:numel(obj.LTA.rewarded), nbbr_filled,'r-', 'linewidth', 2, 'displayname', ['rewarded aved ' num2str(ntrialstoaverageover)])
				plot(ax,1:numel(obj.LTA.rewarded), nbbnr_filled,'k-', 'linewidth', 2, 'displayname', ['unrewarded aved ' num2str(ntrialstoaverageover)])

				% plot all rewards unsmoothed
				plot(ax,rtix, nbbr(~isnan(nbbr)),'r-', 'linewidth', 0.1, 'displayname', 'rewarded unsmoothed')
				plot(ax,nrtix, nbbnr(~isnan(nbbnr)),'k-', 'linewidth', 0.1, 'displayname', 'unrewarded unsmoothed')
				
				
				for ii = 1:numel(obj.LTA.trials_by_block)
				    xline(ax, obj.LTA.trials_by_block{ii}(1), '--', 'handlevisibility', 'off')
				    % xline(ax(1), obj.GLM.trials_by_block{ii}(end), '--', 'handlevisibility', 'off')
				end
				xlim(ax, [1,numel(obj.LTA.SIGNAL_session_trial_order)])
				xlabel(ax,'trial #')
				ylabel(ax,obj.LTA.Mode)
                if exist('f', 'var')
    				set(f, 'name', [obj.iv.sessionCode ' ' obj.LTA.Mode])
                end
			elseif strcmpi(Mode, 'RPE-reward-order')
				if isempty(ax)
					[f,ax] = makeStandardFigure(1,[1,1]);
				end
				

				if Normalize_0_1, nbbr = normalize_0_1(obj.LTA.SIGNAL_session_trial_order(obj.LTA.rewarded), true);nbbnr = normalize_0_1(obj.LTA.SIGNAL_session_trial_order(~obj.LTA.rewarded), true);
			    		else, nbbr = obj.LTA.SIGNAL_session_trial_order(obj.LTA.rewarded); nbbnr = obj.LTA.SIGNAL_session_trial_order(~obj.LTA.rewarded);end
		    	nbb = nan(obj.LTA.ntrials, 1);
		    	nbb(obj.LTA.rewarded) = nbbr;
		    	nbb(~obj.LTA.rewarded) = nbbnr;
				for ii=1:obj.LTA.ntrials
				    if obj.LTA.rewarded(ii)
				        plot(ax,obj.LTA.rewards_so_far(ii), nbb(ii),'r.', 'markersize', 20, 'handlevisibility', 'off')
				    else
				        plot(ax,obj.LTA.rewards_so_far(ii), nbb(ii),'k.', 'markersize', 20, 'handlevisibility', 'off')
				    end
                end
				for ii = 1:numel(obj.LTA.trials_by_block)
				    xline(ax, obj.LTA.trials_by_block{ii}(1), '--', 'handlevisibility', 'off')
				end
				xlim(ax, [1,max(obj.LTA.rewards_so_far)])
				xlabel(ax,'reward #')
				ylabel(ax,obj.LTA.Mode)
                if exist('f', 'var')
    				set(f, 'name', [obj.iv.sessionCode, ' ' obj.LTA.Mode])
                end
                % find the bounds
                for ii = 1:numel(obj.LTA.trials_by_block)
                    try
                    	xline(ax, obj.LTA.rewards_so_far(obj.LTA.trials_by_block{ii}(1)), '--', 'handlevisibility', 'off')
                    catch
                        disp('looks like we cut off a block. ignoring')
                    end
            	end
			elseif strcmpi(Mode, 'RPE-trial-and-reward-orders')
				[f,ax] = makeStandardFigure(2,[1,2]);
				obj.plot('RPE-trial-order', [], [], [], [], ax(1),Normalize_0_1);
				for ii = 1:numel(obj.LTA.trials_by_block)
				    xline(ax(1), obj.LTA.trials_by_block{ii}(1), '--', 'handlevisibility', 'off')
				end
				xlim(ax(1), [1,numel(obj.LTA.SIGNAL_session_trial_order)])
				obj.plot('RPE-reward-order', [], [], [], [], ax(2),Normalize_0_1);
				set(f, 'name', obj.iv.sessionCode)

			elseif strcmpi(Mode, 'raster+hxg')
				[f1, f2] = obj.movingAverageLickTimes('median', 50, 'excluderxn', true, 'SmoothWithinBlock', true, 'PlotBoundLines', true)
				[f3,ax]=obj.histogramByBlock('nfromEnd', 20, 'ExcludeRxn', true, 'binWidth_s', 1, 'ExcludeNoLicks', true);
				f=[f1,f2,f3];
			end	

			if exist('f', 'var')
    			obj.setUserDataStandards([Caller get(f, 'userdata')], f);
            end
		end
		function gatherMovementControls(obj, sloshing_obj)
			sloshing_obj.resetLTA(0, 500);
			trialOrder = cell2mat(obj.LTA.trials_in_each_bin);
			% gather movement control data
			if isfield(sloshing_obj.LTA, 'X')	
				obj.LTA.X_session_trial_order = nan(size(obj.LTA.SIGNAL_session_trial_order));
				if strcmpi(obj.iv.Mode, 'peaks')
					obj.LTA.X_session_trial_order(trialOrder) = sloshing_obj.LTA.X.maxs;
				elseif strcmpi(obj.iv.Mode, 'mean')
					obj.LTA.X_session_trial_order(trialOrder) = sloshing_obj.LTA.X.means;
				else
					error('Mode undefined?')
				end				
			end

			if isfield(sloshing_obj.LTA, 'tdt')	
				obj.LTA.tdt_session_trial_order = nan(size(obj.LTA.SIGNAL_session_trial_order));
				if strcmpi(obj.iv.Mode, 'peaks')
					obj.LTA.tdt_session_trial_order(trialOrder) = sloshing_obj.LTA.tdt.maxs;
				elseif strcmpi(obj.iv.Mode, 'mean')
					obj.LTA.tdt_session_trial_order(trialOrder) = sloshing_obj.LTA.tdt.means;
				else
					error('Mode undefined?')
				end				
			end

			if isfield(sloshing_obj.LTA, 'EMG')	
				obj.LTA.EMG_session_trial_order = nan(size(obj.LTA.SIGNAL_session_trial_order));
				if strcmpi(obj.iv.Mode, 'peaks')
					obj.LTA.EMG_session_trial_order(trialOrder) = sloshing_obj.LTA.EMG.maxs;
				elseif strcmpi(obj.iv.Mode, 'mean')
					obj.LTA.EMG_session_trial_order(trialOrder) = sloshing_obj.LTA.EMG.means;
				else
					error('Mode undefined?')
				end				
			end
			obj.LTA.moveControlMode = obj.iv.Mode;
		end
		function getBleachingEnvelope(obj, sObj)
			if ~isfield(obj.LTA, 'F0')
				[dFF, F0] = sObj.normalizedMultiBaselineDFF(5000, 10, sObj.GLM.rawF,false,15);
				obj.LTA.F0 = F0;
				obj.LTA.F0_params = {'nmultibaseline', 5000, 10, 'killstd15'};
				obj.save;
				[f, ax] = makeStandardFigure();
				plot(ax, F0);
				title(ax, 'bleaching envelope, F0')
				f.Name = obj.iv.sessionCode;
			end
		end
		function [r2s, mdls, f,modelNames, fbeta] = fitModel(obj, ModelID, packet)
			% 
			% 	packet used to put in cobj data from the zzt composite where we set cut off trials and processed correlations a bit differently
			%	#Bleaching_models_full_nest
			% 	
			if nargin < 3, packet = [];end
			if isempty(packet)
				movmedian_kernel = 25;
			else
				movmedian_kernel = packet.smoothing_setpoint;
				warning('rbf -- is this used correctly?')
			end
			if nargin < 2, ModelID = 'plot-3';end
			% 
			% 	ModelID: 'nested-3' -- uses Ploy's original 3 predictors in nested fashion: time in sesh, lick time, rew # and interactions
			% 
			fbeta = [];

			trials_so_far_R = normalize_0_1(find(obj.LTA.rewarded==1), true);
			trials_so_far_NoR = normalize_0_1(find(obj.LTA.rewarded==0), true);
			lick_time_R = normalize_0_1(obj.LTA.lick_time_session_trial_order(obj.LTA.rewarded), true);
			rewards_so_far_R = normalize_0_1(obj.LTA.rewards_so_far(obj.LTA.rewarded), true);
			rewards_so_far_NoR = normalize_0_1(obj.LTA.rewards_so_far(~obj.LTA.rewarded), true);
			DA_R = obj.LTA.SIGNAL_session_trial_order(obj.LTA.rewarded);
			DA_NoR = obj.LTA.SIGNAL_session_trial_order(~obj.LTA.rewarded);

			

			for ii = 1:numel(obj.LTA.trials_by_block)
				time_in_block(obj.LTA.trials_by_block{ii}) = 1:numel(obj.LTA.trials_by_block{ii});
			end
			time_in_block_R = normalize_0_1(time_in_block(obj.LTA.rewarded)', true);


			% find rew blocks
			rew_in_block_R = normalize_0_1([time_in_block_R(2:end) - time_in_block_R(1:end-1);nan], true);
			blockbounds = [0;find(rew_in_block_R < 0); numel(rew_in_block_R)];
			% for ii = 1:numel(obj.LTA.trials_by_block)
			% 	rew_in_block_R(blockbounds(ii)+1:blockbounds(ii+1)) = 1:numel(rew_in_block_R(blockbounds(ii)+1:blockbounds(ii+1)));
			% end

			% RPE_predict1 = table(trials_so_far_R, DA_R);
			% RPE_predict2 = table(trials_so_far_R, rewards_so_far_R, DA_R);
			% RPE_predict34 = table(trials_so_far_R, rewards_so_far_R, lick_time_R, DA_R);

			RPE_predict1 = table(lick_time_R, DA_R);
			RPE_predict2 = table(lick_time_R,trials_so_far_R, DA_R);
			RPE_predict34 = table(lick_time_R, trials_so_far_R, rewards_so_far_R, DA_R);

			RPE_predictTrialsSoFar = table(trials_so_far_R, DA_R);
			RPE_predict_time_ONLY_R = RPE_predictTrialsSoFar;
			RPE_predictTrialsSoFar_NoR = table(trials_so_far_NoR, DA_NoR);
			RPE_predict_time_ONLY_NoR = RPE_predictTrialsSoFar_NoR;

			RPE_predictTrialsSoFar_RewSoFar = table(rewards_so_far_R, trials_so_far_R, DA_R);
			RPE_predictTrialsSoFar_RewSoFar_NoR = table(rewards_so_far_NoR, trials_so_far_NoR, DA_NoR);

			RPE_predictRSF = table(rewards_so_far_R, DA_R);
			RPE_predictRSF_NoR = table(rewards_so_far_NoR, DA_NoR);

			RPE_rew_ONLY_R = RPE_predictRSF;
			RPE_rew_ONLY_NoR = RPE_predictRSF_NoR;

			RPE_predict_TIB = table(time_in_block_R, DA_R);
			RPE_predict_RIB = table(rew_in_block_R, DA_R);

			RPE_predict34TIB = table(lick_time_R, trials_so_far_R, rewards_so_far_R, time_in_block_R,DA_R);
			RPE_predict34RIB = table(lick_time_R, trials_so_far_R, rewards_so_far_R, rew_in_block_R,DA_R);
			RPE_predict34TRIB = table(lick_time_R, trials_so_far_R, rewards_so_far_R, time_in_block_R,rew_in_block_R,DA_R);

			RPE_predictTIBRSF = table(time_in_block_R,rewards_so_far_R, DA_R);
			RPE_predictRIBTSF = table(rew_in_block_R, trials_so_far_R, DA_R);



			% if the model includes move controls, grab them:
			if contains(ModelID, 'moveControls') 
				if ~isfield(obj.LTA, 'moveControlMode')
					load_sObj_sloshing_zzt
					obj.gatherMovementControls(sloshing_obj);
				end
				RPE_predictMoveControls_R = table(DA_R);
				RPE_predictMoveControls_NoR = table(DA_NoR);
				if isfield(obj.LTA, 'tdt_session_trial_order')
					tdt_R = normalize_0_1(obj.LTA.tdt_session_trial_order(obj.LTA.rewarded));
					tdt_NoR = normalize_0_1(obj.LTA.tdt_session_trial_order(~obj.LTA.rewarded));
					% layer these on to the existing models
					RPE_predictMoveControls_R = addvars(RPE_predictMoveControls_R, tdt_R, 'Before', 'DA_R');
					RPE_predictTrialsSoFar = addvars(RPE_predictTrialsSoFar, tdt_R, 'Before', 'DA_R');
					RPE_predictRSF = addvars(RPE_predictRSF, tdt_R, 'Before', 'DA_R');
					RPE_predictTrialsSoFar_RewSoFar = addvars(RPE_predictTrialsSoFar_RewSoFar, tdt_R, 'Before', 'DA_R');

					RPE_predictMoveControls_NoR = addvars(RPE_predictMoveControls_NoR, tdt_NoR, 'Before', 'DA_NoR');
					RPE_predictTrialsSoFar_NoR = addvars(RPE_predictTrialsSoFar_NoR, tdt_NoR, 'Before', 'DA_NoR');
					RPE_predictRSF_NoR = addvars(RPE_predictRSF_NoR, tdt_NoR, 'Before', 'DA_NoR');
					RPE_predictTrialsSoFar_RewSoFar_NoR = addvars(RPE_predictTrialsSoFar_RewSoFar_NoR, tdt_NoR, 'Before', 'DA_NoR');
				end
				if ~contains(ModelID, 'tdtnotXEMG')
					if isfield(obj.LTA, 'X_session_trial_order')
						X_R = normalize_0_1(obj.LTA.X_session_trial_order(obj.LTA.rewarded), true);
						X_NoR = normalize_0_1(obj.LTA.X_session_trial_order(~obj.LTA.rewarded), true);

						% layer these on to the existing models
						RPE_predictMoveControls_R = addvars(RPE_predictMoveControls_R, X_R, 'Before', 'DA_R');
						RPE_predictTrialsSoFar = addvars(RPE_predictTrialsSoFar, X_R, 'Before', 'DA_R');
						RPE_predictRSF = addvars(RPE_predictRSF, X_R, 'Before', 'DA_R');
						RPE_predictTrialsSoFar_RewSoFar = addvars(RPE_predictTrialsSoFar_RewSoFar, X_R, 'Before', 'DA_R');

						RPE_predictMoveControls_NoR = addvars(RPE_predictMoveControls_NoR, X_NoR, 'Before', 'DA_NoR');
						RPE_predictTrialsSoFar_NoR = addvars(RPE_predictTrialsSoFar_NoR, X_NoR, 'Before', 'DA_NoR');
						RPE_predictRSF_NoR = addvars(RPE_predictRSF_NoR, X_NoR, 'Before', 'DA_NoR');
						RPE_predictTrialsSoFar_RewSoFar_NoR = addvars(RPE_predictTrialsSoFar_RewSoFar_NoR, X_NoR, 'Before', 'DA_NoR');
					end
					if isfield(obj.LTA, 'EMG_session_trial_order')
						EMG_R = normalize_0_1(obj.LTA.EMG_session_trial_order(obj.LTA.rewarded), true);
						EMG_NoR = normalize_0_1(obj.LTA.EMG_session_trial_order(~obj.LTA.rewarded), true);

						% layer
						RPE_predictMoveControls_R = addvars(RPE_predictMoveControls_R, EMG_R, 'Before', 'DA_R');
						RPE_predictTrialsSoFar = addvars(RPE_predictTrialsSoFar, EMG_R, 'Before', 'DA_R');
						RPE_predictRSF = addvars(RPE_predictRSF, EMG_R, 'Before', 'DA_R');
						RPE_predictTrialsSoFar_RewSoFar = addvars(RPE_predictTrialsSoFar_RewSoFar, EMG_R, 'Before', 'DA_R');

						RPE_predictMoveControls_NoR = addvars(RPE_predictMoveControls_NoR, EMG_NoR, 'Before', 'DA_NoR');
						RPE_predictTrialsSoFar_NoR = addvars(RPE_predictTrialsSoFar_NoR, EMG_NoR, 'Before', 'DA_NoR');
						RPE_predictRSF_NoR = addvars(RPE_predictRSF_NoR, EMG_NoR, 'Before', 'DA_NoR');
						RPE_predictTrialsSoFar_RewSoFar_NoR = addvars(RPE_predictTrialsSoFar_RewSoFar_NoR, EMG_NoR, 'Before', 'DA_NoR');
					end
				end

				RPE_predictMoveControls_ONLY_R = RPE_predictMoveControls_R;
				RPE_predictMoveControls_ONLY_NoR = RPE_predictMoveControls_NoR;

				RPE_predict_time_move_ONLY_R = RPE_predictTrialsSoFar;
				RPE_predict_time_move_ONLY_NoR = RPE_predictTrialsSoFar_NoR;

				RPE_predict_rew_move_ONLY_R = RPE_predictRSF;
				RPE_predict_rew_move_ONLY_NoR = RPE_predictRSF_NoR;


				RPE_predict_rew_time_move_ONLY_R = RPE_predictTrialsSoFar_RewSoFar;
				RPE_predict_rew_time_move_ONLY_NoR = RPE_predictTrialsSoFar_RewSoFar_NoR;

				if contains(ModelID, 'licktime')
					Lt_R = normalize_0_1(obj.LTA.lick_time_session_trial_order(obj.LTA.rewarded), true);
					Lt_NoR = normalize_0_1(obj.LTA.lick_time_session_trial_order(~obj.LTA.rewarded), true);
					RPE_predict_ltONLY_R = table(Lt_R, DA_R);
					RPE_predict_ltONLY_NoR = table(Lt_NoR, DA_NoR);


					

					% layer in licktime
					RPE_predictMoveControls_R = addvars(RPE_predictMoveControls_R, Lt_R, 'Before', 'DA_R');
					RPE_predictTrialsSoFar = addvars(RPE_predictTrialsSoFar, Lt_R, 'Before', 'DA_R');
					RPE_predictRSF = addvars(RPE_predictRSF, Lt_R, 'Before', 'DA_R');
					RPE_predictTrialsSoFar_RewSoFar = addvars(RPE_predictTrialsSoFar_RewSoFar, Lt_R, 'Before', 'DA_R');

					RPE_predictMoveControls_NoR = addvars(RPE_predictMoveControls_NoR, Lt_NoR, 'Before', 'DA_NoR');
					RPE_predictTrialsSoFar_NoR = addvars(RPE_predictTrialsSoFar_NoR, Lt_NoR, 'Before', 'DA_NoR');
					RPE_predictRSF_NoR = addvars(RPE_predictRSF_NoR, Lt_NoR, 'Before', 'DA_NoR');
					RPE_predictTrialsSoFar_RewSoFar_NoR = addvars(RPE_predictTrialsSoFar_RewSoFar_NoR, Lt_NoR, 'Before', 'DA_NoR');


					RPE_predict_lt_move_only_R = RPE_predictMoveControls_R;
					RPE_predict_lt_move_only_NoR = RPE_predictMoveControls_NoR;


					RPE_predict_rew_time_move_lt_ONLY_R = RPE_predictTrialsSoFar_RewSoFar;
					RPE_predict_rew_time_move_lt_ONLY_NoR = RPE_predictTrialsSoFar_RewSoFar_NoR;
				end
			end
			if contains(ModelID, 'med_nonan')
				nonan_lt_idx = find(~isnan(obj.LTA.lick_time_session_trial_order));
				lt_nonan = obj.LTA.lick_time_session_trial_order(nonan_lt_idx);
				running_median_lick_time = nan(size(obj.LTA.lick_time_session_trial_order));
				warning('rbf -- is this using the proper kernel?')
				disp(['setpoint kernel=' num2str(movmedian_kernel)])
				running_median_lick_time(nonan_lt_idx) = movmedian(lt_nonan, movmedian_kernel);


				med_nonan_R = normalize_0_1(running_median_lick_time(obj.LTA.rewarded), true);
				med_nonan_NoR = normalize_0_1(running_median_lick_time(~obj.LTA.rewarded), true);

				RPE_predictMED_R = table(med_nonan_R, DA_R);
				RPE_predictMED_NoR = table(med_nonan_NoR, DA_NoR);

				RPE_predictMED_rewsofar_R = table(med_nonan_R, rewards_so_far_R, DA_R);
				RPE_predictMED_rewsofar_NoR = table(med_nonan_NoR, rewards_so_far_NoR, DA_NoR);

				% layer in med_nonan
				if contains(ModelID, 'moveControls') 
					RPE_predictMoveControls_R = addvars(RPE_predictMoveControls_R, med_nonan_R, 'Before', 'DA_R');
					RPE_predictMoveControls_NoR = addvars(RPE_predictMoveControls_NoR, med_nonan_NoR, 'Before', 'DA_NoR');

					RPE_predictMED_move_only_R = addvars(RPE_predictMoveControls_ONLY_R, med_nonan_R, 'Before', 'DA_R');
					RPE_predictMED_move_only_NoR = addvars(RPE_predictMoveControls_ONLY_NoR, med_nonan_NoR, 'Before', 'DA_NoR');

					RPE_predict_med_time_move_ONLY_R = addvars(RPE_predict_time_move_ONLY_R, med_nonan_R, 'Before', 'DA_R');
					RPE_predict_med_time_move_ONLY_NoR = addvars(RPE_predict_time_move_ONLY_NoR, med_nonan_NoR, 'Before', 'DA_NoR');
					
					RPE_predict_med_rew_move_ONLY_R = addvars(RPE_predict_rew_move_ONLY_R, med_nonan_R, 'Before', 'DA_R');
					RPE_predict_med_rew_move_ONLY_NoR = addvars(RPE_predict_rew_move_ONLY_NoR, med_nonan_NoR, 'Before', 'DA_NoR');
				end
				RPE_predictTrialsSoFar = addvars(RPE_predictTrialsSoFar, med_nonan_R, 'Before', 'DA_R');
				RPE_predictRSF = addvars(RPE_predictRSF, med_nonan_R, 'Before', 'DA_R');
				RPE_predictTrialsSoFar_RewSoFar = addvars(RPE_predictTrialsSoFar_RewSoFar, med_nonan_R, 'Before', 'DA_R');
				
				RPE_predictTrialsSoFar_NoR = addvars(RPE_predictTrialsSoFar_NoR, med_nonan_NoR, 'Before', 'DA_NoR');
				RPE_predictRSF_NoR = addvars(RPE_predictRSF_NoR, med_nonan_NoR, 'Before', 'DA_NoR');
				RPE_predictTrialsSoFar_RewSoFar_NoR = addvars(RPE_predictTrialsSoFar_RewSoFar_NoR, med_nonan_NoR, 'Before', 'DA_NoR');


				RPE_predict_med_rew_time_move_ONLY_R = addvars(RPE_predict_rew_time_move_ONLY_R, med_nonan_R, 'Before', 'DA_R');
				RPE_predict_med_rew_time_move_ONLY_NoR = addvars(RPE_predict_rew_time_move_ONLY_NoR, med_nonan_NoR, 'Before', 'DA_NoR');

				if contains(ModelID, 'licktime')
					RPE_predict_med_rew_time_move_lt_ONLY_R = addvars(RPE_predict_rew_time_move_lt_ONLY_R, med_nonan_R, 'Before', 'DA_R');
					RPE_predict_med_rew_time_move_lt_ONLY_NoR = addvars(RPE_predict_rew_time_move_lt_ONLY_NoR, med_nonan_NoR, 'Before', 'DA_NoR');
				end
				
			end
			if contains(ModelID, 'F0')
				% 
				% 	Gather the bleaching envelope predictor
				% 
				if ~isfield(obj.LTA, 'F0')
					error(' we need to gather the bleaching envelope first. use obj.getBleachingEnvelope')
				end
				F0_R = normalize_0_1(obj.LTA.F0(obj.LTA.rewarded)', true);
				F0_NoR = normalize_0_1(obj.LTA.F0(~obj.LTA.rewarded)', true);
				RPE_F0only_R = table(F0_R, DA_R);
				RPE_F0only_NoR = table(F0_NoR, DA_NoR);

				RPE_predict_move_bleach_ONLY_R = addvars(RPE_predictMoveControls_ONLY_R, F0_R, 'Before', 'DA_R');
				RPE_predict_move_bleach_ONLY_NoR = addvars(RPE_predictMoveControls_ONLY_NoR, F0_NoR, 'Before', 'DA_NoR');


				RPE_predict_time_move_bleach_ONLY_R = addvars(RPE_predict_time_move_ONLY_R, F0_R, 'Before', 'DA_R');
				RPE_predict_time_move_bleach_ONLY_NoR = addvars(RPE_predict_time_move_ONLY_NoR, F0_NoR, 'Before', 'DA_NoR');

				RPE_predict_rew_move_bleach_ONLY_R = addvars(RPE_predict_rew_move_ONLY_R, F0_R, 'Before', 'DA_R');
				RPE_predict_rew_move_bleach_ONLY_NoR = addvars(RPE_predict_rew_move_ONLY_NoR, F0_NoR, 'Before', 'DA_NoR');


				RPE_predict_med_time_move_bleach_ONLY_R = addvars(RPE_predict_med_time_move_ONLY_R, F0_R, 'Before', 'DA_R');
				RPE_predict_med_time_move_bleach_ONLY_NoR = addvars(RPE_predict_med_time_move_ONLY_NoR, F0_NoR, 'Before', 'DA_NoR');


				RPE_predict_med_rew_move_bleach_ONLY_R = addvars(RPE_predict_med_rew_move_ONLY_R, F0_R, 'Before', 'DA_R');
				RPE_predict_med_rew_move_bleach_ONLY_NoR = addvars(RPE_predict_med_rew_move_ONLY_NoR, F0_NoR, 'Before', 'DA_NoR');


				

				% layer in F0:
				if contains(ModelID, 'moveControls') 
					RPE_predictMoveControls_R = addvars(RPE_predictMoveControls_R, F0_R, 'Before', 'DA_R');
					RPE_predictMoveControls_NoR = addvars(RPE_predictMoveControls_NoR, F0_NoR, 'Before', 'DA_NoR');


					RPE_predictMED_move_bleach_R = addvars(RPE_predictMED_move_only_R, F0_R, 'Before', 'DA_R');
					RPE_predictMED_move_bleach_NoR = addvars(RPE_predictMED_move_only_NoR, F0_NoR, 'Before', 'DA_NoR');

					RPE_predict_time_move_bleach_R = addvars(RPE_predictMED_move_only_R, F0_R, 'Before', 'DA_R');
					RPE_predict_time_move_bleach_NoR = addvars(RPE_predictMED_move_only_NoR, F0_NoR, 'Before', 'DA_NoR');
				end
				RPE_predictTrialsSoFar = addvars(RPE_predictTrialsSoFar, F0_R, 'Before', 'DA_R');
				RPE_predictRSF = addvars(RPE_predictRSF, F0_R, 'Before', 'DA_R');
				RPE_predictTrialsSoFar_RewSoFar = addvars(RPE_predictTrialsSoFar_RewSoFar, F0_R, 'Before', 'DA_R');
				if exist('RPE_predict_lt_move_only_R', 'var')
					RPE_predict_lt_move_bleach_only_R = addvars(RPE_predict_lt_move_only_R, F0_R, 'Before', 'DA_R');
					RPE_predict_lt_move_bleach_only_NoR = addvars(RPE_predict_lt_move_only_NoR, F0_NoR, 'Before', 'DA_NoR');
				end
				
				RPE_predictTrialsSoFar_NoR = addvars(RPE_predictTrialsSoFar_NoR, F0_NoR, 'Before', 'DA_NoR');
				RPE_predictRSF_NoR = addvars(RPE_predictRSF_NoR, F0_NoR, 'Before', 'DA_NoR');
				RPE_predictTrialsSoFar_RewSoFar_NoR = addvars(RPE_predictTrialsSoFar_RewSoFar_NoR, F0_NoR, 'Before', 'DA_NoR');


				RPE_predict_rew_time_move_bleach_ONLY_R = addvars(RPE_predict_rew_time_move_ONLY_R, F0_R, 'Before', 'DA_R');
				RPE_predict_rew_time_move_bleach_ONLY_NoR = addvars(RPE_predict_rew_time_move_ONLY_NoR, F0_NoR, 'Before', 'DA_NoR');

				RPE_predict_med_rew_time_move_bleach_ONLY_R = addvars(RPE_predict_med_rew_time_move_ONLY_R, F0_R, 'Before', 'DA_R');
				RPE_predict_med_rew_time_move_bleach_ONLY_NoR = addvars(RPE_predict_med_rew_time_move_ONLY_NoR, F0_NoR, 'Before', 'DA_NoR');

				if contains(ModelID, 'licktime')
					RPE_predict_med_rew_time_move_lt_bleach_R = RPE_predictTrialsSoFar_RewSoFar;
					RPE_predict_med_rew_time_move_lt_bleach_NoR = RPE_predictTrialsSoFar_RewSoFar_NoR;
				end
				
			end

			r2s = 0;
			if strcmpi(ModelID, 'nested-3')	
				disp('Model 1: LICK TIME--------------------------------------------')
				mdls{1} = fitglm(RPE_predict1);
				r2s(1) = mdls{1}.Rsquared.Ordinary;
				disp(mdls{1})
				disp(' ')
				disp('Model 2: LICK TIME + TRIALS SO FAR--------------------------------------------')
				mdls{2} = fitglm(RPE_predict2);
				r2s(2) = mdls{2}.Rsquared.Ordinary;
				disp(mdls{2})
				disp(' ')
				disp('Model 3: LICK TIME + TRAILS + REWARDS SO FAR--------------------------------------------')
				mdls{3} = fitglm(RPE_predict34);
				disp(mdls{3})
				r2s(3) = mdls{3}.Rsquared.Ordinary
				modelNames = {'lt', 'lt+trials', 'lt+trials+rews'};
			elseif strcmpi(ModelID, 'trialsSoFar')	
				disp('Model 1: TRIALS SO FAR--------------------------------------------')
				[f,ax] = obj.plot;%('RPE-reward-order')
				mdls = fitglm(RPE_predictTrialsSoFar);
				disp(mdls)
				r2s = mdls.Rsquared.Ordinary;
				disp(['Rsq: ' num2str(r2s)])
				[yfit, ~] = predict(mdls, trials_so_far_R); 
				plot(ax(1),trials_so_far_R,yfit,'o','Color','[0.4660 0.6740 0.1880]', 'DisplayName', 'time in block')
				plot(ax(2),rewards_so_far_R,yfit,'o','Color','[0.4660 0.6740 0.1880]', 'DisplayName', 'time in block')
				legend(ax(2),'show')
				modelNames = {'trials'};
			elseif strcmpi(ModelID, 'compareTimeVsRewardsSoFar') || strcmpi(ModelID, 'compareTimeVsRewardsSoFar_F0') || strcmpi(ModelID, 'compareTimeVsRewardsSoFar_med_nonan') || strcmpi(ModelID, 'compareTimeVsRewardsSoFar_med_nonan_F0')
				% disp('Model 1: TRIALS SO FAR--------------------------------------------')
				modelNames = {'trials--R', 'nrewardssofar--R', 'trials+rews--R','trials--NoR', 'nrewardssofar--NoR', 'trials+rews--NoR'};
				% disp('Model 1: TRIALS SO FAR--------------------------------------------')
				mdls{1} = fitglm(RPE_predictTrialsSoFar);
				r2s(1) = mdls{1}.Rsquared.Ordinary;
				[yfit{1}, ~] = predict(mdls{1}, cell2mat(table2cell(RPE_predictTrialsSoFar(:,1:end-1)))); 

				% disp('Model 2: REWARDS SO FAR--------------------------------------------')
				mdls{2} = fitglm(RPE_predictRSF);
				r2s(2) = mdls{2}.Rsquared.Ordinary;
				[yfit{2}, ~] = predict(mdls{2}, cell2mat(table2cell(RPE_predictRSF(:,1:end-1)))); 

				% disp('Model 3: TRAILS + REWARDS SO FAR--------------------------------------------')
				mdls{3} = fitglm(RPE_predictTrialsSoFar_RewSoFar);
				r2s(3) = mdls{3}.Rsquared.Ordinary;
				[yfit{3}, ~] = predict(mdls{3}, cell2mat(table2cell(RPE_predictTrialsSoFar_RewSoFar(:,1:end-1)))); 


				% disp('Model 4: TRIALS SO FAR EARLY--------------------------------------------')
				mdls{4} = fitglm(RPE_predictTrialsSoFar_NoR);
				r2s(4) = mdls{4}.Rsquared.Ordinary;
				[yfit{4}, ~] = predict(mdls{4}, cell2mat(table2cell(RPE_predictTrialsSoFar_NoR(:,1:end-1)))); 

				% disp('Model 2: REWARDS SO FAR--------------------------------------------')
				mdls{5} = fitglm(RPE_predictRSF_NoR);
				r2s(5) = mdls{5}.Rsquared.Ordinary;
				[yfit{5}, ~] = predict(mdls{5}, cell2mat(table2cell(RPE_predictRSF_NoR(:,1:end-1)))); 

				% disp('Model 3: TRAILS + REWARDS SO FAR--------------------------------------------')
				mdls{6} = fitglm(RPE_predictTrialsSoFar_RewSoFar_NoR);
				r2s(6) = mdls{6}.Rsquared.Ordinary;
				[yfit{6}, ~] = predict(mdls{6}, cell2mat(table2cell(RPE_predictTrialsSoFar_RewSoFar_NoR(:,1:end-1)))); 

				[ax,f] = plot(obj, 'RPE-trial-and-reward-orders', [], [], [], [], [], false);
				set(f, 'position', [0.0384    0.2637    0.4041    0.5906])
				C = linspecer(6);
				tsf = find(obj.LTA.rewarded==1);
				tsfnr = find(obj.LTA.rewarded==0);
				rsf = obj.LTA.rewards_so_far(obj.LTA.rewarded);
				rsfnr = obj.LTA.rewards_so_far(~obj.LTA.rewarded);
				for ii = 1:3
					plot(ax(1),tsf,yfit{ii},'o','Color',C(ii,:), 'DisplayName', [modelNames{ii} ' Rsq ' num2str(round(r2s(ii),2))])
					plot(ax(2),rsf,yfit{ii},'o','Color',C(ii,:), 'DisplayName', [modelNames{ii} ' Rsq ' num2str(round(r2s(ii),2))])
					% plot(ax(1),tsf,rescale_from_normalized_0_1(yfit{ii}, DA_R, true),'o','Color',C(ii,:), 'DisplayName', [modelNames{ii} ' Rsq ' num2str(round(r2s(ii),2))])
					% plot(ax(2),rsf,rescale_from_normalized_0_1(yfit{ii}, DA_R, true),'o','Color',C(ii,:), 'DisplayName', [modelNames{ii} ' Rsq ' num2str(round(r2s(ii),2))])
				end
				for ii = 4:6
					% plot(ax(1),tsfnr,rescale_from_normalized_0_1(yfit{ii}, DA_NoR,true),'o','Color',C(ii,:), 'DisplayName', [modelNames{ii} ' Rsq ' num2str(round(r2s(ii),2))])
					% plot(ax(2),rsfnr,rescale_from_normalized_0_1(yfit{ii}, DA_NoR, true),'o','Color',C(ii,:), 'DisplayName', [modelNames{ii} ' Rsq ' num2str(round(r2s(ii),2))])
					plot(ax(1),tsfnr,yfit{ii},'o','Color',C(ii,:), 'DisplayName', [modelNames{ii} ' Rsq ' num2str(round(r2s(ii),2))])
					plot(ax(2),rsfnr,yfit{ii},'o','Color',C(ii,:), 'DisplayName', [modelNames{ii} ' Rsq ' num2str(round(r2s(ii),2))])
				end
				legend(ax(2),'show')

				[f2, ax2] = makeStandardFigure(6, [2, 3]);
				for ii = 1:6
					PlotParamsText = ['ModelID', modelNames{ii}];
					obj.plotCoeff(mdls{ii}, PlotParamsText, modelNames{ii}, ax2(ii));
				end
				mm = -1000;
				nn = 1000;
				for ii = 1:3
					lm = get(ax2(ii), 'ylim');
					mm = max([lm(2); mm]);
                    nn = min([lm(1); nn]);
				end
				for ii=1:3, ylim(ax2(ii), [nn, mm]), end
				mm = -1000;
				nn = 1000;
				for ii = 4:6
					lm = get(ax2(ii), 'ylim');
					mm = max([lm(2); mm]);
                    nn = min([lm(1); nn]);
				end
				for ii=4:6, ylim(ax2(ii), [nn, mm]), end
				set(f2, 'position', [0.4464    0.2627    0.5377    0.5896])
				fbeta=f2;
			elseif contains(ModelID, 'allbleachingandtimemodels_med_nonan_moveControls_licktime_F0')
				allbleachingandtimemodels_RUNNER
			elseif contains(ModelID, 'allbleachingandtimemodels_med_nonan_moveControls_licktime')
				allbleachingandtimemodels_RUNNER_noF0
			elseif contains(ModelID, 'compareTimeVsRewardsSoFar_moveControls')
				% disp('Model 1: Move Controls--------------------------------------------')
				modelNo = 1;
				if contains(ModelID, 'licktime'), modelNames{modelNo} = 'move-lt--R'; else, modelNames{modelNo} = 'move--R'; end
				mdls{modelNo} = fitglm(RPE_predictMoveControls_R);
				r2s(modelNo) = mdls{modelNo}.Rsquared.Ordinary;
				[yfit{modelNo}, ~] = predict(mdls{modelNo}, cell2mat(table2cell(RPE_predictMoveControls_R(:,1:end-1)))); 

				% disp('Model 2: TRIALS SO FAR--------------------------------------------')
				modelNo = 2;
				if contains(ModelID, 'licktime'), modelNames{modelNo} = 'move-lt-trials--R'; else, modelNames{modelNo} = 'move-trials--R'; end
				mdls{modelNo} = fitglm(RPE_predictTrialsSoFar);
				r2s(modelNo) = mdls{modelNo}.Rsquared.Ordinary;
				[yfit{modelNo}, ~] = predict(mdls{modelNo}, cell2mat(table2cell(RPE_predictTrialsSoFar(:,1:end-1)))); 

				% disp('Model 3: REWARDS SO FAR--------------------------------------------')
				modelNo = 3;
				if contains(ModelID, 'licktime'), modelNames{modelNo} = 'move-lt-nrew--R'; else, modelNames{modelNo} = 'move-nrew--R'; end
				mdls{modelNo} = fitglm(RPE_predictRSF);
				r2s(modelNo) = mdls{modelNo}.Rsquared.Ordinary;
				[yfit{modelNo}, ~] = predict(mdls{modelNo}, cell2mat(table2cell(RPE_predictRSF(:,1:end-1)))); 

				% disp('Model 4: TRAILS + REWARDS SO FAR--------------------------------------------')
				modelNo = 4;
				if contains(ModelID, 'licktime'), modelNames{modelNo} = 'move-lt-trials-nrew--R'; else, modelNames{modelNo} = 'move-trials-nrew--R'; end
				mdls{modelNo} = fitglm(RPE_predictTrialsSoFar_RewSoFar);
				r2s(modelNo) = mdls{modelNo}.Rsquared.Ordinary;
				[yfit{modelNo}, ~] = predict(mdls{modelNo}, cell2mat(table2cell(RPE_predictTrialsSoFar_RewSoFar(:,1:end-1)))); 

				% disp('Model 5: Move controls No Rew--------------------------------------------')
				modelNo = 5;
				if contains(ModelID, 'licktime'), modelNames{modelNo} = 'move-lt-NoR'; else, modelNames{modelNo} = 'move-NoR'; end
				mdls{modelNo} = fitglm(RPE_predictMoveControls_NoR);
				r2s(modelNo) = mdls{modelNo}.Rsquared.Ordinary;
				[yfit{modelNo}, ~] = predict(mdls{modelNo}, cell2mat(table2cell(RPE_predictMoveControls_NoR(:,1:end-1)))); 

				% disp('Model 5: TRIALS No Rew--------------------------------------------')
				modelNo = 6;
				if contains(ModelID, 'licktime'), modelNames{modelNo} = 'move-lt-trials--NoR'; else, modelNames{modelNo} = 'move-trials--NoR'; end
				mdls{modelNo} = fitglm(RPE_predictTrialsSoFar_NoR);
				r2s(modelNo) = mdls{modelNo}.Rsquared.Ordinary;
				[yfit{modelNo}, ~] = predict(mdls{modelNo}, cell2mat(table2cell(RPE_predictTrialsSoFar_NoR(:,1:end-1)))); 

				% disp('Model 7: REWARDS SO FAR--------------------------------------------')
				modelNo = 7;
                if contains(ModelID, 'licktime'), modelNames{modelNo} = 'move-lt-nrew--NoR'; else, modelNames{modelNo} = 'move-nrew--NoR'; end
				mdls{modelNo} = fitglm(RPE_predictRSF_NoR);
				r2s(modelNo) = mdls{modelNo}.Rsquared.Ordinary;
				[yfit{modelNo}, ~] = predict(mdls{modelNo}, cell2mat(table2cell(RPE_predictRSF_NoR(:,1:end-1)))); 

				% disp('Model 8: TRAILS + REWARDS SO FAR--------------------------------------------')
				modelNo = 8;
				if contains(ModelID, 'licktime'), modelNames{modelNo} = 'move-lt-trials-nrew--NoR'; else, modelNames{modelNo} = 'move-trials-nrew--NoRR'; end
				mdls{modelNo} = fitglm(RPE_predictTrialsSoFar_RewSoFar_NoR);
				r2s(modelNo) = mdls{modelNo}.Rsquared.Ordinary;
				[yfit{modelNo}, ~] = predict(mdls{modelNo}, cell2mat(table2cell(RPE_predictTrialsSoFar_RewSoFar_NoR(:,1:end-1)))); 

				[ax,f] = obj.plot;
				C = linspecer(8);
				tsf = find(obj.LTA.rewarded==1);
				tsfnr = find(obj.LTA.rewarded==0);
				rsf = obj.LTA.rewards_so_far(obj.LTA.rewarded);
				rsfnr = obj.LTA.rewards_so_far(~obj.LTA.rewarded);
				for ii = 1:4
					plot(ax(1),tsf,yfit{ii},'o','Color',C(ii,:), 'DisplayName', [modelNames{ii} ' Rsq ' num2str(round(r2s(ii),2))])
					plot(ax(2),rsf,yfit{ii},'o','Color',C(ii,:), 'DisplayName', [modelNames{ii} ' Rsq ' num2str(round(r2s(ii),2))])
				end
				for ii = 5:8
					plot(ax(1),tsfnr,yfit{ii},'o','Color',C(ii,:), 'DisplayName', [modelNames{ii} ' Rsq ' num2str(round(r2s(ii),2))])
					plot(ax(2),rsfnr,yfit{ii},'o','Color',C(ii,:), 'DisplayName', [modelNames{ii} ' Rsq ' num2str(round(r2s(ii),2))])
				end
				legend(ax(2),'show')

				[f2, ax2] = makeStandardFigure(8, [2, 4]);
				for ii = 1:8
					PlotParamsText = ['ModelID', modelNames{ii}];
					obj.plotCoeff(mdls{ii}, PlotParamsText, modelNames{ii}, ax2(ii));
				end
				mm = -1000;
				nn = 1000;
				for ii = 1:4
					lm = get(ax2(ii), 'ylim');
					mm = max([lm(2); mm]);
                    nn = min([lm(1); nn]);
				end
				for ii=1:4, ylim(ax2(ii), [nn, mm]), end
				mm = -1000;
				nn = 1000;
				for ii = 5:8
					lm = get(ax2(ii), 'ylim');
					mm = max([lm(2); mm]);
                    nn = min([lm(1); nn]);
				end
				for ii=5:8, ylim(ax2(ii), [nn, mm]), end
				set(f, 'position', [0.0384    0.2637    0.4041    0.5906])
				set(f2, 'position', [0.4464    0.2627    0.5377    0.5896])
				fbeta=f2;
			elseif strcmpi(ModelID, 'rewardsSoFar')	
				disp('Model 1: REWARDS SO FAR--------------------------------------------')
				[f,ax] = obj.plot;%('RPE-reward-order')
				mdls{3} = fitglm(RPE_predictRSF);
				disp(mdls{3})
				r2s(3) = mdls{3}.Rsquared.Ordinary;
				disp(['Rsq: ' num2str(r2s(3))])
				[yfit, ~] = predict(mdls{3}, rewards_so_far_R); 
				plot(ax(1),trials_so_far_R,yfit,'o','Color','[0.4660 0.6740 0.1880]', 'DisplayName', 'time in block')
				plot(ax(2),rewards_so_far_R,yfit,'o','Color','[0.4660 0.6740 0.1880]', 'DisplayName', 'time in block')
				legend(ax(2),'show')
				modelNames = {'rews'};
			elseif strcmpi(ModelID, '3-interactions')
				disp('Model 4: TRIALS + REWARDS SO FAR + FLICK TIME + INTERACTIONS--------------------------------------------')
				mdls{1} = fitglm(RPE_predict34, 'interactions');
				mdls{1}
				r2s(1) = mdls{1}.Rsquared.Ordinary
				modelNames = {'interactions'};
			elseif strcmpi(ModelID, 'nested-TRIB')	
				disp('Model 1: LICK TIME + TRAILS + REWARDS SO FAR + TIME IN BLOCK--------------------------------------------')
				mdls{1} = fitglm(RPE_predict34TIB);
				r2s(1) = mdls{1}.Rsquared.Ordinary;
				disp(mdls{1})
				disp(' ')
				disp('Model 2: LICK TIME + TRAILS + REWARDS SO FAR + REWARDS IN BLOCK--------------------------------------------')
				mdls{2} = fitglm(RPE_predict34RIB);
				r2s(2) = mdls{2}.Rsquared.Ordinary;
				disp(mdls{2})
				disp(' ')
				disp('Model 3: LICK TIME + TRAILS + REWARDS SO FAR + TIME IN BLOCK + REWARDS IN BLOCK--------------------------------------------')
				mdls{3} = fitglm(RPE_predict34TRIB);
				disp(mdls{3})
				r2s(3) = mdls{3}.Rsquared.Ordinary
				modelNames = {'lt+trials+rews+tinblock', 'lt+trials+rews+rinblock', 'lt+trials+rews+tinblock+rinblock'};
			elseif strcmpi(ModelID, 'timeInBlock')
				[ax,f] = obj.plot;
				disp('Model: TIME IN BLOCK--------------------------------------------')
				mdls{1} = fitglm(RPE_predict_TIB);
				r2s(1) = mdls{1}.Rsquared.Ordinary;
				disp(mdls{1} )
				disp(['Rsq: ' num2str(r2s(1))])
				[yfit, ~] = predict(mdls{1}, time_in_block_R); 
				plot(ax(1),trials_so_far_R,yfit,'o','Color','[0.4660 0.6740 0.1880]', 'DisplayName', 'time in block')
				plot(ax(2),rewards_so_far_R,yfit,'o','Color','[0.4660 0.6740 0.1880]', 'DisplayName', 'time in block')
				legend(ax(2),'show')
				modelNames = {'tinblock'};
			elseif strcmpi(ModelID, 'rewardsInBlock')
				[ax,f] = obj.plot;
				disp('Model: REWARDS IN BLOCK--------------------------------------------')
				mdls{1} = fitglm(RPE_predict_RIB);
				r2s(1) = mdls{1}.Rsquared.Ordinary;
				disp(mdls{1} )
				disp(['Rsq: ' num2str(r2s(1))])
				[yfit, ~] = predict(mdls{1}, rew_in_block_R); 
				plot(ax(1),trials_so_far_R,yfit,'o','Color','[0.4660 0.6740 0.1880]', 'DisplayName', 'rewards in block')
				plot(ax(2),rewards_so_far_R,yfit,'o','Color','[0.4660 0.6740 0.1880]', 'DisplayName', 'rewards in block')
				legend(ax(2),'show')
				modelNames = {'rinblock'};
			elseif strcmpi(ModelID, 'rewardsSoFar_TimeInBlock')
				[ax,f] = obj.plot;
				disp('Model: REWARDS SO FAR + TIME IN BLOCK--------------------------------------------')
				mdls{1} = fitglm(RPE_predictTIBRSF);
				r2s(1) = mdls{1}.Rsquared.Ordinary;
				disp(mdls{1} )
				disp(['Rsq: ' num2str(r2s(1))])
				[yfit, ~] = predict(mdls{1}, [time_in_block_R,rewards_so_far_R]); 
				plot(ax(1),trials_so_far_R,yfit,'o','Color','[0.4660 0.6740 0.1880]', 'DisplayName', ['Time in Block + Rewards so Far'])
				plot(ax(2),rewards_so_far_R,yfit,'o','Color','[0.4660 0.6740 0.1880]', 'DisplayName', ['Time in Block + Rewards so Far'])
				legend(ax(2),'show')
				modelNames = {'tinblock+rinblock'};
			elseif strcmpi(ModelID, 'timeSoFar_RewardsInBlock')
				[ax,f] = obj.plot;
				disp('Model: TIME SO FAR + REWARDS IN BLOCK--------------------------------------------')
				mdls{1} = fitglm(RPE_predictRIBTSF);
				r2s(1) = mdls{1}.Rsquared.Ordinary;
				disp(mdls{1} )
				disp(['Rsq: ' num2str(r2s(1))])
				[yfit, ~] = predict(mdls{1}, [rew_in_block_R, trials_so_far_R]); 
				plot(ax(1),trials_so_far_R,yfit,'o','Color','[0.4660 0.6740 0.1880]', 'DisplayName', ['Rewards in Block + Time so Far'])
				plot(ax(2),rewards_so_far_R,yfit,'o','Color','[0.4660 0.6740 0.1880]', 'DisplayName', ['Rewards in Block + Time so Far'])
				legend(ax(2),'show')
				modelNames = {'trials+rinblock'};
			elseif strcmpi(ModelID, 'plot-3')
				[ax,f] = obj.plot;
				% trial no
				mdls{1} = fitglm(RPE_predict1);
				[yfit, ~] = predict(mdls{1}, lick_time_R); 
				plot(ax(1),trials_so_far_R,yfit,'o','Color','[0.4660 0.6740 0.1880]', 'DisplayName', 'session time')
				plot(ax(2),rewards_so_far_R,yfit,'o','Color','[0.4660 0.6740 0.1880]', 'DisplayName', 'session time')
				% +rewards so far
				mdls{2} = fitglm(RPE_predict2);
				[yfit, ~] = predict(mdls{2}, [lick_time_R trials_so_far_R]);
				plot(ax(1),trials_so_far_R,yfit,'o', 'Color', 'c', 'DisplayName', 'session time + rewards received')
				plot(ax(2),rewards_so_far_R,yfit,'o', 'Color', 'c', 'DisplayName', 'session time + rewards received')
				% +flick time
				mdls{3} = fitglm(RPE_predict34);
				[yfit, ~] = predict(mdls{3}, [lick_time_R trials_so_far_R rewards_so_far_R]);
				plot(ax(1),trials_so_far_R,yfit, 'o', 'Color', 'b','DisplayName', 'session time + rewards received + lick time')
				plot(ax(2),rewards_so_far_R,yfit, 'o', 'Color', 'b','DisplayName', 'session time + rewards received + lick time')
				for ii = 1:2
				    legend(ax(ii),'lick time', 'lick time + session time', 'lick time + session time + rewards received');
				end
				modelNames = {'ni'};
			elseif strcmpi(ModelID, 'plot-5')
				[ax,f] = obj.plot;
				% trial no
				mdls{1} = fitglm(RPE_predict1);
				[yfit, ~] = predict(mdls{1}, lick_time_R); 
				plot(ax(1),trials_so_far_R,yfit,'o','Color','[0.4660 0.6740 0.1880]', 'DisplayName', 'lick time')
				plot(ax(2),rewards_so_far_R,yfit,'o','Color','[0.4660 0.6740 0.1880]', 'DisplayName', 'lick time')
				% +rewards so far
				mdls{2} = fitglm(RPE_predict2);
				[yfit, ~] = predict(mdls{2}, [lick_time_R trials_so_far_R]);
				plot(ax(1),trials_so_far_R,yfit,'o', 'Color', 'c', 'DisplayName', 'lick time + session time')
				plot(ax(2),rewards_so_far_R,yfit,'o', 'Color', 'c', 'DisplayName', 'lick time + session time')
				% +flick time
				mdls{3} = fitglm(RPE_predict34);
				[yfit, ~] = predict(mdls{3}, [lick_time_R trials_so_far_R rewards_so_far_R]);
				plot(ax(1),trials_so_far_R,yfit, 'o', 'Color', 'b','DisplayName', 'lick time + session time + rewards received')
				plot(ax(2),rewards_so_far_R,yfit, 'o', 'Color', 'b','DisplayName', 'lick time + session time + rewards received')
				% +TIB
				mdls{4} = fitglm(RPE_predict34TIB);
				[yfit, ~] = predict(mdls{4}, [lick_time_R trials_so_far_R rewards_so_far_R time_in_block_R]);
				plot(ax(1),trials_so_far_R,yfit, 'o', 'Color', [0.3660 0.0740 0.5880],'DisplayName', 'lick time + session time + rewards received + time in block')
				plot(ax(2),rewards_so_far_R,yfit, 'o', 'Color', [0.3660 0.0740 0.5880],'DisplayName', 'lick time + session time + rewards received + time in block')
				% +RIB
				mdls{5} = fitglm(RPE_predict34TRIB);
				[yfit, ~] = predict(mdls{5}, [lick_time_R trials_so_far_R rewards_so_far_R time_in_block_R,rew_in_block_R]);
				plot(ax(1),trials_so_far_R,yfit, 'o', 'Color', [0.5660 0.0740 0.5880],'DisplayName', 'lick time + session time + rewards received + time in block + rewards in block')
				plot(ax(2),rewards_so_far_R,yfit, 'o', 'Color', [0.5660 0.0740 0.5880],'DisplayName', 'lick time + session time + rewards received + time in block + rewards in block')
				for ii = 2
				    legend(ax(ii),'show')%'lick time', 'lick time + session time', 'lick time + session time + rewards received');
				end
				disp(mdls{5})
				disp(num2str(mdls{5}.Rsquared.Ordinary))
				modelNames = {'ni'};
			end
			if exist('f', 'var')
				Caller = ['[r2s, mdls] = obj.fitModel(' ModelID ')\nRsqs: ' mat2str(r2s),...
					'\nmovmediankernel = ' num2str(movmedian_kernel)];
				obj.setUserDataStandards(Caller, f);
				set(f, 'name', [obj.iv.sessionCode ' | modelID: ' ModelID ' | Rsq: ' num2str(r2s(end))]);
			else
				f=[];
			end
		end
		function align_RPE_to_blockchange(obj)
            warning('this method designed to designate late as anywhere in the ITI (for og zigzag paradigm before we fixed the late window, 7-19-24)')
			% 
			% 	We will align our RPE signals to each block change
			% 
			rxnBound = 0.5;
			ntrials = numel(obj.LTA.flick_s_wrtc);
	
            obj.analysis = [];
			obj.analysis.trials_wrt_change = (-1*ntrials:ntrials-1)';
			obj.analysis.firstTrialInNewBlock = 0;


			% get data for each block
			for ii = 1:numel(obj.LTA.trials_by_block)
				% 
				%	Get the bounds for this block 	
				% 
				trialsInBlock = obj.LTA.trials_by_block{ii};
				if ii~=1
					trialsInPreviousBlock = obj.LTA.trials_by_block{ii-1};
				else
					trialsInPreviousBlock = [];
				end
				AllTrialsToGrab = [trialsInPreviousBlock,trialsInBlock];

				blockbounds = strsplit(obj.LTA.block_legend{ii}, '-');
				block_rew_min = str2double(blockbounds{1});
				block_rew_max = strsplit(blockbounds{2}, 's');
				block_rew_max = str2double(block_rew_max{1});
				obj.analysis.blockwindows(ii).trialMin = min(trialsInBlock);
				obj.analysis.blockwindows(ii).trialMax = max(trialsInBlock);
				obj.analysis.blockwindows(ii).rxnmin = 0;
				obj.analysis.blockwindows(ii).rxnmax = rxnBound;
				obj.analysis.blockwindows(ii).rewmin = block_rew_min;
				obj.analysis.blockwindows(ii).rewmax = block_rew_max;

			
				licktimes = nan(size(obj.LTA.flick_s_wrtc));
				licktimes(AllTrialsToGrab) = obj.LTA.flick_s_wrtc(AllTrialsToGrab);
				rxn_inBlock = licktimes < rxnBound;
				early_inBlock = licktimes >= rxnBound & licktimes < block_rew_min;
				rewarded_inBlock = licktimes >= block_rew_min & licktimes < block_rew_max;
				late_inBlock = licktimes >= block_rew_max;


				obj.analysis.trialTypesInShift(ii).all = trialsInBlock;
				obj.analysis.trialTypesInShift(ii).rxn = rxn_inBlock;
				obj.analysis.trialTypesInShift(ii).early = early_inBlock;
				obj.analysis.trialTypesInShift(ii).rewarded = rewarded_inBlock;
				obj.analysis.trialTypesInShift(ii).late = late_inBlock;

				SIGNAL_session_trial_order_in_block = nan(ntrials, 1);
				SIGNAL_session_trial_order_in_block(trialsInBlock) = obj.LTA.SIGNAL_session_trial_order(trialsInBlock);

				obj.analysis.SIGNALS_in_session_trial_order(ii).all = SIGNAL_session_trial_order_in_block;
				obj.analysis.SIGNALS_in_session_trial_order(ii).rxn = nan(ntrials, 1);
				obj.analysis.SIGNALS_in_session_trial_order(ii).rxn(rxn_inBlock) = SIGNAL_session_trial_order_in_block(rxn_inBlock);
				obj.analysis.SIGNALS_in_session_trial_order(ii).early = nan(ntrials, 1);
				obj.analysis.SIGNALS_in_session_trial_order(ii).early(early_inBlock) = SIGNAL_session_trial_order_in_block(early_inBlock);
				obj.analysis.SIGNALS_in_session_trial_order(ii).rewarded = nan(ntrials, 1);
				obj.analysis.SIGNALS_in_session_trial_order(ii).rewarded(rewarded_inBlock) = SIGNAL_session_trial_order_in_block(rewarded_inBlock);
				obj.analysis.SIGNALS_in_session_trial_order(ii).late = nan(ntrials, 1);
				obj.analysis.SIGNALS_in_session_trial_order(ii).late(late_inBlock) = SIGNAL_session_trial_order_in_block(late_inBlock);
			end
			[obj.analysis.blockwindows.latemax] = deal(max([obj.analysis.blockwindows.rewmax]));


			% get data for the shift -- left side
			for ii = 1:numel(obj.LTA.trials_by_block)-1
				shift = ntrials-obj.analysis.blockwindows(ii).trialMax+1;

				obj.analysis.SIGNALS_aligned_to_block_change(ii).all = nan(ntrials*2,1); 
				obj.analysis.SIGNALS_aligned_to_block_change(ii).all(shift:shift+ntrials-1) = obj.analysis.SIGNALS_in_session_trial_order(ii).all;
				obj.analysis.SIGNALS_aligned_to_block_change(ii).rxn = nan(ntrials*2,1); 
				obj.analysis.SIGNALS_aligned_to_block_change(ii).rxn(shift:shift+ntrials-1) = obj.analysis.SIGNALS_in_session_trial_order(ii).rxn;
				obj.analysis.SIGNALS_aligned_to_block_change(ii).early = nan(ntrials*2,1); 
				obj.analysis.SIGNALS_aligned_to_block_change(ii).early(shift:shift+ntrials-1) = obj.analysis.SIGNALS_in_session_trial_order(ii).early;
				obj.analysis.SIGNALS_aligned_to_block_change(ii).rewarded = nan(ntrials*2,1); 
				obj.analysis.SIGNALS_aligned_to_block_change(ii).rewarded(shift:shift+ntrials-1) = obj.analysis.SIGNALS_in_session_trial_order(ii).rewarded;
				obj.analysis.SIGNALS_aligned_to_block_change(ii).late = nan(ntrials*2,1); 
				obj.analysis.SIGNALS_aligned_to_block_change(ii).late(shift:shift+ntrials-1) = obj.analysis.SIGNALS_in_session_trial_order(ii).late;
				

				% remove nans either side
				obj.analysis.SIGNALS_aligned_SCRUNCHED(ii).all = nan(ntrials*2,1); 
				left_of_change = obj.analysis.SIGNALS_aligned_to_block_change(ii).all(1:ntrials);
                if ~isempty(left_of_change(~isnan(left_of_change)))
    				obj.analysis.SIGNALS_aligned_SCRUNCHED(ii).all(ntrials-sum(~isnan(left_of_change))+1:ntrials) = left_of_change(~isnan(left_of_change));
                end

				obj.analysis.SIGNALS_aligned_SCRUNCHED(ii).rxn = nan(ntrials*2,1); 
				left_of_change = obj.analysis.SIGNALS_aligned_to_block_change(ii).rxn(1:ntrials);
                if ~isempty(left_of_change(~isnan(left_of_change)))
    				obj.analysis.SIGNALS_aligned_SCRUNCHED(ii).rxn(ntrials-sum(~isnan(left_of_change))+1:ntrials) = left_of_change(~isnan(left_of_change));
                end

				obj.analysis.SIGNALS_aligned_SCRUNCHED(ii).early = nan(ntrials*2,1); 
				left_of_change = obj.analysis.SIGNALS_aligned_to_block_change(ii).early(1:ntrials);
                if ~isempty(left_of_change(~isnan(left_of_change)))
    				obj.analysis.SIGNALS_aligned_SCRUNCHED(ii).early(ntrials-sum(~isnan(left_of_change))+1:ntrials) = left_of_change(~isnan(left_of_change));
                end

				obj.analysis.SIGNALS_aligned_SCRUNCHED(ii).rewarded = nan(ntrials*2,1); 
				left_of_change = obj.analysis.SIGNALS_aligned_to_block_change(ii).rewarded(1:ntrials);
                if ~isempty(left_of_change(~isnan(left_of_change)))
    				obj.analysis.SIGNALS_aligned_SCRUNCHED(ii).rewarded(ntrials-sum(~isnan(left_of_change))+1:ntrials) = left_of_change(~isnan(left_of_change));
                end

				obj.analysis.SIGNALS_aligned_SCRUNCHED(ii).late = nan(ntrials*2,1); 
				left_of_change = obj.analysis.SIGNALS_aligned_to_block_change(ii).late(1:ntrials);
                if ~isempty(left_of_change(~isnan(left_of_change)))
    				obj.analysis.SIGNALS_aligned_SCRUNCHED(ii).late(ntrials-sum(~isnan(left_of_change))+1:ntrials) = left_of_change(~isnan(left_of_change));
                end
			end

			% get data for each shift -- right side
			for ii = 2:numel(obj.LTA.trials_by_block)
				shift = ntrials-obj.analysis.blockwindows(ii).trialMin+2;

				blockshift = ii-1;
				

				% obj.analysis.SIGNALS_aligned_to_block_change(blockshift).all(shift:shift+ntrials-1) = nansum([obj.analysis.SIGNALS_aligned_to_block_change(blockshift).all(shift:shift+ntrials-1), obj.analysis.SIGNALS_in_session_trial_order(ii).all],1);
				% obj.analysis.SIGNALS_aligned_to_block_change(blockshift).rxn(shift:shift+ntrials-1) = obj.analysis.SIGNALS_in_session_trial_order(ii).rxn;
				% obj.analysis.SIGNALS_aligned_to_block_change(blockshift).early(shift:shift+ntrials-1) = obj.analysis.SIGNALS_in_session_trial_order(ii).early;
				% obj.analysis.SIGNALS_aligned_to_block_change(blockshift).rewarded(shift:shift+ntrials-1) = obj.analysis.SIGNALS_in_session_trial_order(ii).rewarded;
				% obj.analysis.SIGNALS_aligned_to_block_change(blockshift).late(shift:shift+ntrials-1) = obj.analysis.SIGNALS_in_session_trial_order(ii).late;
				ix = obj.analysis.blockwindows(ii).trialMin:obj.analysis.blockwindows(ii).trialMax;
				nn = numel(ix);
				obj.analysis.SIGNALS_aligned_to_block_change(blockshift).all(ntrials+1:ntrials+nn) = obj.analysis.SIGNALS_in_session_trial_order(ii).all(ix);
				obj.analysis.SIGNALS_aligned_to_block_change(blockshift).rxn(ntrials+1:ntrials+nn) = obj.analysis.SIGNALS_in_session_trial_order(ii).rxn(ix);
				obj.analysis.SIGNALS_aligned_to_block_change(blockshift).early(ntrials+1:ntrials+nn) = obj.analysis.SIGNALS_in_session_trial_order(ii).early(ix);
				obj.analysis.SIGNALS_aligned_to_block_change(blockshift).rewarded(ntrials+1:ntrials+nn) = obj.analysis.SIGNALS_in_session_trial_order(ii).rewarded(ix);
				obj.analysis.SIGNALS_aligned_to_block_change(blockshift).late(ntrials+1:ntrials+nn) = obj.analysis.SIGNALS_in_session_trial_order(ii).late(ix);
				

				% remove nans either side
				right_of_change = obj.analysis.SIGNALS_aligned_to_block_change(blockshift).all(ntrials+1:end);
                if ~isempty(right_of_change(~isnan(right_of_change)))
    				obj.analysis.SIGNALS_aligned_SCRUNCHED(blockshift).all(ntrials+1:ntrials+sum(~isnan(right_of_change))) = right_of_change(~isnan(right_of_change));
                end

				right_of_change = obj.analysis.SIGNALS_aligned_to_block_change(blockshift).rxn(ntrials+1:end);
                if ~isempty(right_of_change(~isnan(right_of_change)))
    				obj.analysis.SIGNALS_aligned_SCRUNCHED(blockshift).rxn(ntrials+1:ntrials+sum(~isnan(right_of_change))) = right_of_change(~isnan(right_of_change));
                end

				right_of_change = obj.analysis.SIGNALS_aligned_to_block_change(blockshift).early(ntrials+1:end);
                if ~isempty(right_of_change(~isnan(right_of_change)))
    				obj.analysis.SIGNALS_aligned_SCRUNCHED(blockshift).early(ntrials+1:ntrials+sum(~isnan(right_of_change))) = right_of_change(~isnan(right_of_change));
                end

				right_of_change = obj.analysis.SIGNALS_aligned_to_block_change(blockshift).rewarded(ntrials+1:end);
                if ~isempty(right_of_change(~isnan(right_of_change)))
    				obj.analysis.SIGNALS_aligned_SCRUNCHED(blockshift).rewarded(ntrials+1:ntrials+sum(~isnan(right_of_change))) = right_of_change(~isnan(right_of_change));
                end

				right_of_change = obj.analysis.SIGNALS_aligned_to_block_change(blockshift).late(ntrials+1:end);
                if ~isempty(right_of_change(~isnan(right_of_change)))
    				obj.analysis.SIGNALS_aligned_SCRUNCHED(blockshift).late(ntrials+1:ntrials+sum(~isnan(right_of_change))) = right_of_change(~isnan(right_of_change));	
                end
			end
		end
		function [ax, f] = poolAlignedSignals(obj, Mode,leftBlocks)

            warning('debug this!')
			if nargin < 2, Mode = 'rew';end
			if nargin < 3
				leftBlocks = 1:length(obj.analysis.SIGNALS_aligned_SCRUNCHED);
			end
			Caller = ['[ax,f] = obj.poolAlignedSignals(' Mode ',leftBlocks=' mat2str(leftBlocks) ')'];
			obj.analysis.poolingMethod = ['byLeftBlocks = ' num2str(leftBlocks)];
			obj.analysis.pooledScrunched = nan(size(obj.analysis.SIGNALS_aligned_SCRUNCHED(leftBlocks(1)).all));
			obj.analysis.pooledSignalCounts = zeros(size(obj.analysis.pooledScrunched));

			% do running average
			for ii = 1:numel(leftBlocks)
				s1 = obj.analysis.pooledScrunched;
				if contains(Mode, 'rew')
	                s2 = obj.analysis.SIGNALS_aligned_SCRUNCHED(leftBlocks(ii)).rewarded;
                elseif strcmpi(Mode, 'rxn')
                	s2 = obj.analysis.SIGNALS_aligned_SCRUNCHED(leftBlocks(ii)).rxn;
            	elseif strcmpi(Mode, 'early')
                	s2 = obj.analysis.SIGNALS_aligned_SCRUNCHED(leftBlocks(ii)).early;
            	elseif strcmpi(Mode, 'late')
                	s2 = obj.analysis.SIGNALS_aligned_SCRUNCHED(leftBlocks(ii)).late;
                elseif strcmpi(Mode, 'all')
                	s2 = obj.analysis.SIGNALS_aligned_SCRUNCHED(leftBlocks(ii)).all;
                end
                Nprev = obj.analysis.pooledSignalCounts;
                Nnow = Nprev+ ~isnan(s2);

                Norms1 = (s1.*Nprev)./Nnow;
                Norms2 = s2./Nnow;

                obj.analysis.pooledScrunched = nansum([s1,s2],2);

            	obj.analysis.pooledSignalCounts = Nnow;
        	end

        	x = obj.analysis.trials_wrt_change;
        	[f,ax] = makeStandardFigure();
        	Str = setUserDataStandards(obj, Caller, f);
        	plot(ax, x, obj.analysis.pooledScrunched, 'linewidth', 4)
            xx(1) = find(obj.analysis.pooledScrunched~=0, 1, 'first');
            xx(2) = find(obj.analysis.pooledScrunched~=0, 1, 'last');
            xlim(ax, x(xx))
            xline(ax, 0, '--')
            xlabel('events wrt block change')
            ylabel(['mean ' obj.iv.Mode])
            title(['nblock changes = ' num2str(numel(leftBlocks))])
		end
		function [ax,f, Signal, x] = plot_Aligned_To_BlockChange(obj, Mode, Block, ax)
			Caller = ['[ax,f] = obj.plot_Aligned_To_BlockChange(Mode=' Mode ', Block' num2str(Block) ')'];
			% 
			%			 (default is scrunched, omitting nans)
			% 	Mode:	'all' -- plots all licks pooled together ('all-expanded' plots all including nans to keep trial order exact)
			%			'reward' or 'rew' -- plots only rewarded trials ('rew-expanded')
			%			'rxn'
			%			'rxn+ear;y'
			%			'early'
			%			'late'
			%			'unrewarded'
			%			'grid' -- will make a grid on same scale
			% 
			%	Block: plots the changes, numbered by the left block (ie Block=1 would plot change 1->2)
			% 
			if nargin < 4, ax = [];end
			

			if contains(Mode, 'grid')
				if contains(Mode, 'expanded'), addOn='-expanded';else, addOn='';end
				[f, ax] = makeStandardFigure(5, [1,5]);
				Str = setUserDataStandards(obj, Caller, f);
				set(f, 'name', [obj.iv.sessionCode ' | ' Mode ], 'position', [0.0007    0.3666    0.9967    0.4277])
				obj.plot_Aligned_To_BlockChange(['all' addOn], Block, ax(1));
				obj.plot_Aligned_To_BlockChange(['rxn' addOn], Block, ax(2));
				obj.plot_Aligned_To_BlockChange(['early' addOn], Block, ax(3));
				obj.plot_Aligned_To_BlockChange(['rew' addOn], Block, ax(4));
				obj.plot_Aligned_To_BlockChange(['late' addOn], Block, ax(5));
				yy = [0,0];
				xx = [0,0];
				for ii = 1:5
					yyb = get(ax(ii), 'ylim');
					yy(1) = min([yy(1), yyb(1)]);
					yy(2) = max([yy(2), yyb(2)]);
					xxb = get(ax(ii), 'xlim');
					xx(1) = min([xx(1), xxb(1)]);
					xx(2) = max([xx(2), xxb(2)]);
				end
				for ii=1:5
					ylim(ax(ii), yy)
					if contains(Mode, 'expanded')
						xlim(ax(ii), xx)
					end
					if ii>1
						ylabel(ax(ii), '');
					end
				end
			else
				if isempty(ax)
					[f,ax] = makeStandardFigure;
					Str = setUserDataStandards(obj, Caller, f);
					set(f, 'name', [obj.iv.sessionCode ' | ' Mode ])
				end
				x = obj.analysis.trials_wrt_change;
				if contains(Mode,'expanded') || strcmpi(Mode, 'unrewarded') || strcmpi(Mode, 'rxn+early') 
					struct2DrawFrom = obj.analysis.SIGNALS_aligned_to_block_change;
				else
					struct2DrawFrom = obj.analysis.SIGNALS_aligned_SCRUNCHED;
				end

				if contains(Mode, 'all')
					Signal = struct2DrawFrom(Block).all;
					Color = [0.8, 0.2, 0.2];
				elseif contains(Mode, 'rxn')
					if strcmpi(Mode, 'rxn+early')
						error('NIY')
					else
						Signal = struct2DrawFrom(Block).rxn;
					end
					Color = [0., 0.2, 1];
				elseif contains(Mode, 'early')
					Signal = struct2DrawFrom.early;
					Color = [0, 0, 0.8];
				elseif contains(Mode, 'rew') && ~strcmpi(Mode, 'unrewarded')
					Signal = struct2DrawFrom(Block).rewarded;
					Color = [1, 0, 0];
				elseif contains(Mode, 'late')
					Signal = struct2DrawFrom(Block).late;
					Color = [0.6, 0, 0];
				elseif contains(Mode, 'unrewarded')
					error('NIY')
					Color = [0, 0, 0];
				end

				leftix = 1:find(x==-1);
				rightix = find(x==0):numel(x);
				plot(ax, x(leftix), Signal(leftix), 'o', 'color', Color, 'DisplayName', Mode, 'linewidth', 3, 'markerfacecolor', 'k')
				plot(ax, x(rightix), Signal(rightix), 'o', 'color', Color, 'DisplayName', Mode, 'linewidth', 3)
				xline(ax, 0, 'k--')
				title(ax,sprintf([Mode '\nb' num2str(Block) ': ' num2str(obj.analysis.blockwindows(Block).rewmin) '-' num2str(obj.analysis.blockwindows(Block).rewmax) 's | b' num2str(Block+1) ': ' num2str(obj.analysis.blockwindows(Block+1).rewmin) '-' num2str(obj.analysis.blockwindows(Block+1).rewmax) 's']))
				
				if contains(Mode, 'expanded')
					xlabel(ax,'trials wrt block change')
				else
					xlabel(ax,'events wrt block change')
				end
				ylabel(ax, obj.iv.Mode)
			end
		end
		function [earlybound, latebound, trialNo, inNumbers] = blockDurationParser(obj)
			% 
			% 	converts the legend into actual time windows and makes plotting stuff
			% 
			earlybound = nan(size(obj.LTA.flick_s_wrtc));
			latebound = nan(size(obj.LTA.flick_s_wrtc));
			trialNo = 1:numel(obj.LTA.flick_s_wrtc);
			inNumbers = cell(numel(obj.LTA.block_legend),1);
			for ii = 1:numel(obj.LTA.block_legend)
				strs = strsplit(obj.LTA.block_legend{ii}, '-');
				eb = str2double(strs{1});
				strs = strsplit(strs{end}, 's');
				lb = str2double(strs{1});
				earlybound(obj.LTA.trials_by_block{ii}) = eb;
				latebound(obj.LTA.trials_by_block{ii}) = lb;
				inNumbers{ii}(1) = eb;
				inNumbers{ii}(2) = lb;
			end
			if sum(isnan(earlybound))>0 || sum(isnan(latebound))>0
                if sum(isnan(earlybound))==1 && find(isnan(earlybound)) && sum(isnan(latebound))==1 && find(isnan(latebound)) == numel(earlybound)
                    % ignore
                else
                    warning('had nans in the early or late bounds. this likely could mean the block assignment automation has an error somewhere')
                end
            end
		end
		function [f1,f, nlt_good_trial_idx,nlt_no_nans] = movingAverageLickTimes(obj, Mode, ntrials_kernel, varargin)
			% 
			% 	Plots a raster with a moving ave or median of the lick times. 
			%	if we want to jump at block changes we will need to apply that as a Tag method later
			% 
			% 	Mode:	median | mean -- will take a running ave
			% 
			% 	Tags: 'ExcludeRxn', true -- excludes rxns (this is default)
			% 	
			if nargin < 2, Mode = 'mean'; end
			if nargin < 3, ntrials_kernel = 40; end
			p = inputParser;
            addParameter(p, 'ExcludeRxn', true, @islogical); 
            addParameter(p, 'SmoothWithinBlock', true, @islogical); 
            addParameter(p, 'PlotBoundLines', true, @islogical); 
            addParameter(p, 'PlotRunningSTD', true, @islogical); 
            addParameter(p, 'ratiobuilderresult', []); 
            addParameter(p, 'TrialLimits', []); % can choose which trials to include
            addParameter(p, 'ExcludeITI_14', false, @islogical);  % this is to exclude ITI licks in qinxin late window task
            addParameter(p, 'IncludeOtherOutcomes', false, @islogical);  % this option lets you include earlies in the smoothing...maybe you dont want
            addParameter(p, 'IncludeOtherOutcomes_Smoothing', 10, @isnumeric); % this is the smoothing on the earlys and rews combined
            addParameter(p, 'XCorrMode', 0, @isnumeric); % if 0, does not shift the RPE. If non zero, shifts the idx of the RPE to find optimal r
            addParameter(p, 'ExcludePavlovianTrials', true, @isnumeric); % I think we want to keep these
            parse(p, varargin{:});
            ExcludeRxn          = p.Results.ExcludeRxn;
            SmoothWithinBlock   = p.Results.SmoothWithinBlock;
            PlotBoundLines   	= p.Results.PlotBoundLines;
            PlotRunningSTD   	= p.Results.PlotRunningSTD;
            ratiobuilderresult	= p.Results.ratiobuilderresult;
            TrialLimits			= p.Results.TrialLimits; % allows you to not fit for whole sesh for effect ratio
            ExcludeITI_14		= p.Results.ExcludeITI_14;
            IncludeOtherOutcomes= p.Results.IncludeOtherOutcomes;
            IncludeOtherOutcomes_Smoothing= p.Results.IncludeOtherOutcomes_Smoothing;
            XCorrMode			= p.Results.XCorrMode;
            ExcludePavlovianTrials			= p.Results.ExcludePavlovianTrials;


            if isempty(TrialLimits), TrialLimits = 1:numel(obj.LTA.flick_s_wrtc);end
            flicks_all = obj.LTA.flick_s_wrtc;
            flicks = flicks_all;
            if ExcludeRxn
            	flicks(flicks < 0.5) = nan;
        	end
        	if ExcludeITI_14
        		flicks(flicks >= 14) = nan;
    		end

    		% let's check for any pavlovian trials:
            if ExcludePavlovianTrials
    		    try
	    		    pavlov_trials = obj.LTA.pavlov_trials;
	    		    if ~isempty(pavlov_trials)
	    			    % disp('	')
	    			    % disp('	**** Detected pavlovian trials and excluded them from median but not DA:')
	    			    % disp(['	' 	num2str(pavlov_trials')])
				    end
	    		    % if there are any, we want to keep in the DA signal but exclude from the median analysis
	    		    flicks(pavlov_trials) = nan;
	    		    excludedPav = true;
    		    catch
    			    warning('couldnt get pavlov_trials because you didnt set up zzt for it! run the following: ')
    			    disp('	1. open sObj with its folder open')
    			    disp('	sObj.iv.path_ = pwd;')
    			    disp('	pavlov_trials = sObj.getflickswrtj;')
				    disp('	zzt.LTA.pavlov_trials = pavlov_trials;')
				    excludedPav = false;
                end
            else
            	excludedPav = false;
            end

			% let's keep an nlt without any nans
			nlt_good_trial_idx = find(~isnan(flicks));
			nlt_no_nans = flicks(~isnan(flicks));



        	if strcmpi(Mode, 'mean')
        		if ~SmoothWithinBlock
	        		SmoothedLickTimes = smooth(flicks,ntrials_kernel);
	        		nlt_no_nans = smooth(nlt_no_nans,ntrials_kernel);
        		else
        			warning('rbf')
        			SmoothedLickTimes = nan(size(flicks));
        			for iblock = 1:numel(obj.LTA.trials_by_block)
        				SmoothedLickTimes(obj.LTA.trials_by_block{iblock}) = smooth(flicks(obj.LTA.trials_by_block{iblock}),ntrials_kernel);
    				end
    			end
    		elseif strcmpi(Mode, 'median')
				if ~SmoothWithinBlock
    				SmoothedLickTimes = movmedian(flicks,ntrials_kernel, 'omitnan');
    				SmoothedStd = movstd(flicks,round(ntrials_kernel/2), 'omitnan');

    				nlt_no_nans = movmedian(nlt_no_nans,ntrials_kernel);
    				nlt_no_nans_std = movstd(nlt_no_nans,round(ntrials_kernel/2), 'omitnan');
    			else
        			SmoothedLickTimes = nan(size(flicks));
        			SmoothedStd = nan(size(flicks));

        			nlt_no_nans_ph = [];
					nlt_no_nans_std = [];
        			for iblock = 1:numel(obj.LTA.trials_by_block)
        				SmoothedLickTimes(obj.LTA.trials_by_block{iblock}) = movmedian(flicks(obj.LTA.trials_by_block{iblock}),ntrials_kernel, 'omitnan');
        				SmoothedStd(obj.LTA.trials_by_block{iblock}) = movstd(flicks(obj.LTA.trials_by_block{iblock}),round(ntrials_kernel/2), 'omitnan');

        				nltthisblock = flicks(obj.LTA.trials_by_block{iblock});
        				nltthisblock = nltthisblock(~isnan(nltthisblock));
        				nlt_no_nans_ph(end+1:end+numel(nltthisblock)) = movmedian(nltthisblock,ntrials_kernel, 'omitnan');
        				nlt_no_nans_std(end+1:end+numel(nltthisblock)) = movstd(nltthisblock,round(ntrials_kernel/2), 'omitnan');
    				end
    				nlt_no_nans = nlt_no_nans_ph;
					nlt_no_nans_std = nlt_no_nans_std;
    			end
    		end

            SmoothedLickTimes = SmoothedLickTimes(TrialLimits);
            SmoothedStd = SmoothedStd(TrialLimits);
        	[earlybound, latebound, trialNo] = obj.blockDurationParser; % gets the cyan lines
            trialNo = trialNo(TrialLimits);
			%flicks_no_rxns(flicks_no_rxns<0.5) = nan;
			[f,ax] = makeStandardFigure(1,[1,1]);
			plot(ax, flicks_all(TrialLimits), trialNo, 'k.', 'markersize', 30)
			if PlotBoundLines
				plot(ax, earlybound(TrialLimits), trialNo, 'c-', 'linewidth', 4, 'markersize', 20)
				plot(ax, latebound(TrialLimits), trialNo, 'c-', 'linewidth', 4, 'markersize', 20)
			end
			plot(ax, flicks_all(obj.LTA.trials_rewarded), obj.LTA.trials_rewarded, 'c.', 'markersize', 20)
			plot(ax, SmoothedLickTimes, trialNo, 'r-', 'linewidth', 3)
			plot(ax, SmoothedLickTimes+SmoothedStd, trialNo, 'r--', 'linewidth', 1)
			plot(ax, SmoothedLickTimes-SmoothedStd, trialNo, 'r--', 'linewidth', 1)
			set(ax, 'ydir', 'reverse')
			ylim(ax, [TrialLimits(1), TrialLimits(end)])

			set(f, 'name', [obj.iv.sessionCode ' | movingAverageLickTimes | ' Mode ' | ' num2str(ntrials_kernel) ' | ExcludeRxn ' num2str(ExcludeRxn) ' | SmoothWithinBlock ' num2str(SmoothWithinBlock)])
			f1=f;


            PlotParamsText = ['obj.movingAverageLickTimes(obj, Mode, ntrials_kernel, varargin)',...
            	'\n\n(smoothing method) Mode=' Mode,...
            	'\nntrials_kernel=' num2str(ntrials_kernel),...
            	'\nntrials_kernel_std=' num2str(round(ntrials_kernel/2)),...
            	'\nExcludeRxn=' num2str(ExcludeRxn),...
            	'\nSmoothWithinBlock=' num2str(SmoothWithinBlock),...
            	'\nTrialLimits=' num2str(TrialLimits),...
            	'\nExcludeITI_14=' num2str(ExcludeITI_14),...
            	'\nexcludedPav (means pav used for DA but not lick time)=' num2str(excludedPav),...
            	];
            
            Str = obj.setUserDataStandards(PlotParamsText, f);
            set(f, 'position', [ 0.2930    0.2077    0.2097    0.5896]);
            xlim(ax,[0,14]);

            if ~isempty(ratiobuilderresult)
            	allRPE = ratiobuilderresult.ratio_builder_vars.rpe;
            	allRPE(allRPE==0) = nan;
            	if IncludeOtherOutcomes
            		RPE = ratiobuilderresult.ratio_builder_vars.rpe;
            		RPE(RPE==0) = nan;
            		RPE_interpolated = RPE;

				    % I think we need to back-fill the edges, we dont want this to continue
				    % being linearly interpolated
				    if isnan(RPE_interpolated(1))
				        nanfrontidx = find(~isnan(RPE_interpolated), 1, 'first');
				        RPE_interpolated(1:nanfrontidx) = RPE_interpolated(nanfrontidx);
				    end
				    if isnan(RPE_interpolated(end))
				        nanendidx = find(~isnan(RPE_interpolated), 1, 'last');
				        RPE_interpolated(nanendidx:end) = RPE_interpolated(nanendidx);
				    end    
				    RPE_interpolated = fillmissing(RPE_interpolated,'linear','SamplePoints',1:numel(RPE_interpolated));

            		RPE = gausssmooth(RPE_interpolated, IncludeOtherOutcomes_Smoothing, 'gauss')%ratiobuilderresult.smoothing, 'gauss');
        		else
					RPE = ratiobuilderresult.ratio_builder_vars.rpe_rew_interpolated;
    			end

				% normalize the stuff
				try
					SmoothedLickTimes = SmoothedLickTimes(TrialLimits);
					rpe_rew_interpolated = RPE(TrialLimits);
					nR_minus_E_rpe = ratiobuilderresult.ratio_builder_vars.rpe_rew_interpolated(TrialLimits)-ratiobuilderresult.ratio_builder_vars.rpe_early_interpolated(TrialLimits);
				catch
					SmoothedLickTimes = SmoothedLickTimes;
					rpe_rew_interpolated = RPE;
					nR_minus_E_rpe = ratiobuilderresult.ratio_builder_vars.rpe_rew_interpolated-ratiobuilderresult.ratio_builder_vars.rpe_early_interpolated;
                end

                % I think if nr_rpe is less than nlt it's because there
                % werent enough rewarded times. so we can truncate
                % triallimits maybe

				nlt = normalize_0_1(SmoothedLickTimes);
				MovMedian = SmoothedLickTimes;
				MovMedian_no_nans = nlt_no_nans;
				nlt_no_nans = normalize_0_1(nlt_no_nans);
				nr_rpe = normalize_0_1(rpe_rew_interpolated);
				nR_minus_E_rpe = normalize_0_1(nR_minus_E_rpe);
                if numel(nlt) > numel(nr_rpe)
                    % warning('looks like there were trials at end of sesh with no lick. checking this out')
                    % assert(sum(isnan(flicks_all(numel(nr_rpe)+1:end))) == numel(nlt) - numel(nr_rpe))
                    % try making sure they're all nan:
                    assert(sum(~isnan(flicks_all(numel(nr_rpe)+1:end))) == 0) %warning(' check this! we expect all indicies greater than numel nr_rpe to be nan for flicks_all')
                    if numel(nr_rpe) < TrialLimits(end)
                        nr_rpe(end+1:end+TrialLimits(end)-numel(nr_rpe)) = nan;
                    end
                    % nr_rpe(nr_rpe==0) = nan; % ? not sure..I think this is an interpolation issue -- eg ?this prevents us from getting artifactual correlation from exclusions? But also kills the lowest value
                    % I suppose append nr_rpe with nan?
                    % warning('we are cutting off end of the RPE at max trial with a flick. I think this is ok because all cut off trials from normalized lick times had no actual licks, these nans got interpolated in movmed or something with nonexistant lick times (AH)')
                end
                % if xcorr mode, we should shift the idx of the rpe
                if XCorrMode
                	% negative moves RPE left, + moves right. We generally wanna move right
                	xmovedRPE = nr_rpe;
                	if XCorrMode < 0
                		nr_rpe = [xmovedRPE(abs(XCorrMode) + 1:end), ones(1,abs(XCorrMode))*xmovedRPE(end)];
                		allRPE = [allRPE(abs(XCorrMode) + 1:end), ones(1,abs(XCorrMode))*allRPE(end)];
            		elseif XCorrMode>0
            			nr_rpe = [ones(1,XCorrMode)*xmovedRPE(1),xmovedRPE(1:end-XCorrMode)];
            			allRPE = [ones(1,XCorrMode)*allRPE(1),allRPE(1:end-XCorrMode)];
            		end
        		end
    			% get the correlation coeff
                if max(TrialLimits)>numel(nr_rpe)
                    [r_rpe_lt, pr] = corrcoef(nlt(TrialLimits(1):numel(nr_rpe)),nr_rpe); %
				    [r_rpe_r_minus_e_lt, pre] = corrcoef(nlt(TrialLimits(1):numel(nR_minus_E_rpe)),nR_minus_E_rpe);%
                else
                    % try omitting the nans...this isnt very helpful?
                    nrrrr = nr_rpe(TrialLimits);
                    [r_rpe_lt, pr] = corrcoef(nlt(~isnan(nrrrr)'&~isnan(nlt)),nrrrr(~isnan(nrrrr)'&~isnan(nlt))); %
                    if numel(nR_minus_E_rpe) < TrialLimits(end)
                        nR_minus_E_rpe(end+1:end+TrialLimits(end)-numel(nR_minus_E_rpe)) = nan;
                    end
                    % nR_minus_E_rpe(nR_minus_E_rpe==0) = nan; % this prevents us from getting artifactual correlation from exclusions? But also kills the lowest value
                    nlllll = nR_minus_E_rpe(TrialLimits);
				    [r_rpe_r_minus_e_lt, pre] = corrcoef(nlt(~isnan(nlllll)'&~isnan(nlt)),nlllll(~isnan(nlllll)'&~isnan(nlt)));%
                end

				
				% [r_rpe_lt, pr] = corrcoef(nlt(1:numel(nr_rpe)),nr_rpe); %
				% [r_rpe_r_minus_e_lt, pre] = corrcoef(nlt(1:numel(nR_minus_E_rpe)),nR_minus_E_rpe);%
                % 

				[f,ax] = makeStandardFigure(1,[1,1]);
				plot(ax, nlt, trialNo, 'k-', 'linewidth', 3, 'displayname', 'running lick time')
				set(ax, 'ydir', 'reverse')
				ylim(ax, [TrialLimits(1), TrialLimits(end)])
				yyaxis right
                try 
    				plot(ax, nr_rpe(TrialLimits), TrialLimits, '-', 'color', [0,0.5,0], 'linewidth', 3, 'DisplayName', sprintf(['R RPE XCorrMode=' num2str(XCorrMode) ':\nr=' num2str(round(r_rpe_lt(2),2)), '|p=' num2str(round(pr(2),2))]))
                catch
                    plot(ax, nr_rpe(TrialLimits(1):end), TrialLimits(1:numel(nr_rpe)), '-', 'color', [0,0.5,0], 'linewidth', 3, 'DisplayName', sprintf(['R RPE XCorrMode=' num2str(XCorrMode) ':\nr=' num2str(round(r_rpe_lt(2),2)), '|p=' num2str(round(pr(2),2))]))
                end
				% plot(ax, nR_minus_E_rpe, trialNo(1:numel(nR_minus_E_rpe)), '-', 'color', [0.5,0,0], 'linewidth', 3,'DisplayName', ['R-E RPE r=' num2str(round(r_rpe_r_minus_e_lt(2),2)), '|p=' num2str(round(pre(2),2))])
				set(ax, 'ydir', 'reverse')
				ylim(ax, [TrialLimits(1), TrialLimits(end)])
                legend(ax, 'show')


				set(f, 'name', [obj.iv.sessionCode ' | movingAverageLickTimes | ' Mode ' | ' num2str(ntrials_kernel) ' | ExcludeRxn ' num2str(ExcludeRxn) ' | SmoothWithinBlock ' num2str(SmoothWithinBlock), ' | ratiobuilderresult used'])



	            PlotParamsText = ['obj.movingAverageLickTimes(obj, Mode, ntrials_kernel, varargin)',...
	            	'\n\n(smoothing method) Mode=' Mode,...
	            	'\nntrials_kernel=' num2str(ntrials_kernel),...
	            	'\nExcludeRxn=' num2str(ExcludeRxn),...
	            	'\nSmoothWithinBlock=' num2str(SmoothWithinBlock),...
	            	'\nTrialLimits=' num2str(TrialLimits),...
	            	'\nExcludeITI_14=' num2str(ExcludeITI_14),...
	            	'\nIncludeOtherOutcomes=' num2str(IncludeOtherOutcomes),...
	            	'\nIncludeOtherOutcomes_Smoothing=' num2str(IncludeOtherOutcomes_Smoothing),...
	            	'\nXCorrMode=' num2str(XCorrMode),...
	            	'\nexcludedPav (means pav used for DA but not lick time)=' num2str(excludedPav),...
	            	'\nratiobuilderresult used',...
	            	'\n to replicate this, open the original sObj, generate sloshing_obj, and run:',...
	            	'\n 	[fs, result] = ratiobuilder2_function(sObj, sloshing_obj, usepeaks, smoothing, usetdt);',...
	            	'\nresult.usepeaks = ' num2str(ratiobuilderresult.usepeaks),...
	            	'\nresult.smoothing = ' num2str(ratiobuilderresult.smoothing),...
	            	'\nresult.usetdt = ' num2str(ratiobuilderresult.usetdt),...
	            	'\n\nPearson Correlations:',...
	            	'\n 	interpolated rewarded RPE (0,1) x running lick time 	r=' num2str(r_rpe_lt(2)) ' | p=' num2str(pr(2)),...
	            	'\n 	interpolated rewarded RPE-early RPE (0,1) x running lick time 	r=' num2str(r_rpe_r_minus_e_lt(2)) ' | p=' num2str(pre(2)),... 
	            	];
	            
	            Str = obj.setUserDataStandards(PlotParamsText, f);
	            set(f, 'position', [ 0.4930    0.2077    0.2097    0.5896]);
	            xlim(ax,[0,1]);
			end
			% store for later
			obj.analysis.movingAverageLickTimes = [];
			obj.analysis.movingAverageLickTimes.params.Mode = Mode;
			obj.analysis.movingAverageLickTimes.params.ntrials_kernel = ntrials_kernel;
			obj.analysis.movingAverageLickTimes.params.ExcludeRxn = ExcludeRxn;
			obj.analysis.movingAverageLickTimes.params.SmoothWithinBlock = SmoothWithinBlock;
			obj.analysis.movingAverageLickTimes.params.TrialLimits = TrialLimits;
			obj.analysis.movingAverageLickTimes.params.ExcludeITI_14 = ExcludeITI_14;
			obj.analysis.movingAverageLickTimes.params.IncludeOtherOutcomes = IncludeOtherOutcomes;
			obj.analysis.movingAverageLickTimes.params.IncludeOtherOutcomes_Smoothing = IncludeOtherOutcomes_Smoothing;
			obj.analysis.movingAverageLickTimes.params.XCorrMode = XCorrMode;
			obj.analysis.movingAverageLickTimes.params.excludedPav = excludedPav;
            if ~isempty(ratiobuilderresult)
			    obj.analysis.movingAverageLickTimes.params.usepeaks = ratiobuilderresult.usepeaks;
			    obj.analysis.movingAverageLickTimes.params.smoothing = ratiobuilderresult.smoothing;
			    obj.analysis.movingAverageLickTimes.params.usetdt = ratiobuilderresult.usetdt;
            
			    obj.analysis.movingAverageLickTimes.data.nlt = nlt;
			    obj.analysis.movingAverageLickTimes.data.MovMedian = MovMedian;
			    obj.analysis.movingAverageLickTimes.data.MovMedian_no_nans = MovMedian_no_nans;
			    obj.analysis.movingAverageLickTimes.data.del = ratiobuilderresult.ratio_builder_vars.del;
			    obj.analysis.movingAverageLickTimes.data.usetdt = ratiobuilderresult.usetdt;
			    obj.analysis.movingAverageLickTimes.data.nr_rpe = nr_rpe;
			    obj.analysis.movingAverageLickTimes.data.allOutcomeSignals = allRPE;
			    unrewarded_idx = ones(size(ratiobuilderresult.ratio_builder_vars.rpe_rew));
			    unrewarded_idx(ratiobuilderresult.ratio_builder_vars.rpe_rew_idx) = 0;
			    unrewarded_idx = logical(unrewarded_idx);
                obj.analysis.movingAverageLickTimes.data.unrewarded_rpe = nan(size(ratiobuilderresult.ratio_builder_vars.rpe_rew));
			    obj.analysis.movingAverageLickTimes.data.unrewarded_rpe(unrewarded_idx) = allRPE(unrewarded_idx);
			    obj.analysis.movingAverageLickTimes.data.rpe_rew_interpolated = rpe_rew_interpolated;
			    obj.analysis.movingAverageLickTimes.data.rpe_rew = ratiobuilderresult.ratio_builder_vars.rpe_rew;
    
			    obj.analysis.movingAverageLickTimes.data.mins = ratiobuilderresult.ratio_builder_vars.mins;
		        obj.analysis.movingAverageLickTimes.data.maxs = ratiobuilderresult.ratio_builder_vars.maxs;
		        obj.analysis.movingAverageLickTimes.data.means = ratiobuilderresult.ratio_builder_vars.means;
    
		        obj.analysis.movingAverageLickTimes.data.nlt_good_trial_idx = nlt_good_trial_idx;
			    obj.analysis.movingAverageLickTimes.data.nlt_no_nans = nlt_no_nans;
    
			    obj.analysis.movingAverageLickTimes.results.RPE.r = r_rpe_lt(2);
			    obj.analysis.movingAverageLickTimes.results.RPE.p = pr(2);
			    obj.analysis.movingAverageLickTimes.results.RPEminusEARLY.r= r_rpe_r_minus_e_lt(2);
			    obj.analysis.movingAverageLickTimes.results.RPEminusEARLY.p= pre(2);
            end
		end
		function [mdl,fs, t, ix] = predictRunningMedianLickTime(obj, varargin)
			
			% 
			% 	obj.predictRunningMedianLickTime('recycle', true,...
			%			'ntrialsback', 10,...
			%			'medianSmoothing', 10,...
			%			'ExcludeRxn', true,...
			%			'ratiobuilderresult', result,...
			%			'TrialLimits', 1:obj.iv.num_trials,...
			%			'Predictors', 'DA',...
			%			'fitIntercept', false,...
			%			'DAsmoothing', 1,...
			%			'y_signal', 'delmed',... or use med
			%			'XCorrMode', 0,...
            %			'PredictorToPlot', 'nrewardssofar',...
            %			'sObj', [],...
            %			'sloshing_obj', [],...
            %			'add_in_predictors', []
			%			'verbose', true)
			% 
			% 	The idea is to use DA signal and trial outcomes to predict the running median
			%	FIRST MUST USE movingAverageLickTimes if using recycle mode
			% 
			p = inputParser;
			addParameter(p, 'recycle', true, @islogical); % reuses the data stored in analysis from movingAverageLickTimes
            addParameter(p, 'ntrialsback', 10, @isnumeric); 
            addParameter(p, 'medianSmoothing', 50, @isnumeric); % effectively sets the number of trials to init because median is smoothed
            addParameter(p, 'ExcludeRxn', true, @islogical); 
            addParameter(p, 'ratiobuilderresult', []); 
            addParameter(p, 'TrialLimits', [], @isnumeric); % can choose which trials to include
            addParameter(p, 'Predictors', {'DA'}, @iscell); % see list
            addParameter(p, 'y_signal', 'med_nonan', @ischar); %med, delmed, med_nonan, delmed_nonan, 
            addParameter(p, 'fitIntercept', false, @islogical); % DA or outcome
            addParameter(p, 'DAsmoothing', 1, @isnumeric); % DA or outcome
            addParameter(p, 'XCorrMode', 0, @isnumeric); % DA or outcome
            addParameter(p, 'PredictorToPlot', 'nrewardssofar', @ischar); % DA or outcome
            addParameter(p, 'sObj', []); % DA or outcome
            addParameter(p, 'sloshing_obj', []); % DA or outcome
            addParameter(p, 'add_in_predictors', []); % a table of predictors from prior run of model -- recycle to add in tdt data
            addParameter(p, 'custom_y_signal', []); % allows you to put in any signal of your choosing. The name will be given to y_signal field. default should be [];
            addParameter(p, 'verbose', true, @islogical);
            parse(p, varargin{:});
            recycle          		= p.Results.recycle;
            ntrialsback          	= p.Results.ntrialsback;
            medianSmoothing   		= p.Results.medianSmoothing;
            ExcludeRxn   			= p.Results.ExcludeRxn;
            ratiobuilderresult		= p.Results.ratiobuilderresult;
            TrialLimits				= p.Results.TrialLimits; 
            Predictors				= p.Results.Predictors; 
           	fitIntercept			= p.Results.fitIntercept; 
           	DAsmoothing				= p.Results.DAsmoothing; 
            y_signal				= p.Results.y_signal; 
            XCorrMode				= p.Results.XCorrMode;
            PredictorToPlot			= p.Results.PredictorToPlot;
            sObj					= p.Results.sObj;
            sloshing_obj			= p.Results.sloshing_obj;
            add_in_predictors		= p.Results.add_in_predictors;
            custom_y_signal			= p.Results.custom_y_signal;
            verbose					= p.Results.verbose;
            if verbose, obj.displayPossiblePredictors_predictRunningMedianLickTime, end

            % start by getting the data in the analysis field
            ExcludeITI_14 = false;
        	IncludeOtherOutcomes= false;
			IncludeOtherOutcomes_Smoothing=nan;
			Mode = 'median';
            if ~recycle
				[f,f1] = obj.movingAverageLickTimes(Mode, medianSmoothing,...
					'ExcludeRxn', ExcludeRxn,...
					'SmoothWithinBlock', true,...
				 	'PlotBoundLines', true,...
			 	 	'PlotRunningSTD', false,...
					'ratiobuilderresult', ratiobuilderresult,... 
					'TrialLimits', TrialLimits,...
					'ExcludeITI_14', ExcludeITI_14,...
					'IncludeOtherOutcomes', IncludeOtherOutcomes,...
					'IncludeOtherOutcomes_Smoothing', IncludeOtherOutcomes_Smoothing,...
					'XCorrMode', XCorrMode);
				close([f, f1])
			end
			%
			% 	Find indicies within TrialLimits that we should exclude
			% 
			% 
			nlt_good_trial_idx = obj.analysis.movingAverageLickTimes.data.nlt_good_trial_idx;
			nlt_no_nans = obj.analysis.movingAverageLickTimes.data.nlt_no_nans;
			nlt = obj.analysis.movingAverageLickTimes.data.nlt;
			ntrials = numel(nlt);
            if numel(obj.analysis.movingAverageLickTimes.data.del) < TrialLimits(end)
                obj.analysis.movingAverageLickTimes.data.del(end+1:end+TrialLimits(end)-numel(obj.analysis.movingAverageLickTimes.data.del)) = nan;
            end
			del = obj.analysis.movingAverageLickTimes.data.del(TrialLimits);
            del(del == 0) = nan;
			usetdt = obj.analysis.movingAverageLickTimes.data.usetdt;
			nr_rpe = obj.analysis.movingAverageLickTimes.data.nr_rpe;
            if numel(obj.analysis.movingAverageLickTimes.data.allOutcomeSignals) < TrialLimits(end)
                obj.analysis.movingAverageLickTimes.data.allOutcomeSignals(end+1:end+TrialLimits(end)-numel(obj.analysis.movingAverageLickTimes.data.allOutcomeSignals)) = nan;
            end
			allOutcomeSignals = obj.analysis.movingAverageLickTimes.data.allOutcomeSignals(TrialLimits);
            rpe_rew_interpolated = obj.analysis.movingAverageLickTimes.data.rpe_rew_interpolated;
            rpe_rew = obj.analysis.movingAverageLickTimes.data.rpe_rew;
            unrewarded_rpe = obj.analysis.movingAverageLickTimes.data.unrewarded_rpe;

            %these are in trial order
            mins = obj.analysis.movingAverageLickTimes.data.mins;
			maxs = obj.analysis.movingAverageLickTimes.data.maxs;
			means = obj.analysis.movingAverageLickTimes.data.means;
			
			% get tdt
			% [fs, result_tdt] = ratiobuilder2_function(sObj, sloshing_obj, result.usepeaks, result.smoothing, true);
			% close(fs);
			% allRPE_tdt = result_tdt.ratio_builder_vars.rpe;
        	% allRPE_tdt(allRPE_tdt==0) = nan;

			% get the design matrix t and dependent variable, yy
			fetchPredictorsHelper_zzt

			

            if contains(y_signal, 'nonan')
                % try removing all nans from the table...
                kill = zeros(size(ix))';
                if size(isnan(t{:, 1}),2) ~= size(kill, 2)
                    kill=kill';
                end
                for ii = [1,3:size(t, 2)]
                    kill = kill + isnan(t{:, ii});
                end
                ix = ix(~kill);
                t = t(~kill, :);
                for ii = [1,3:size(t, 2)]
                    t{:,ii} = normalize_0_1(t{:,ii});
                end
                if ~sum(contains(Predictors, 'custom'))
	                plottedPredictor_p = nan(obj.iv.num_trials,1);
	                plottedPredictor_p(ix) = plottedPredictor(~kill);
	                plottedPredictor = normalize_0_1(plottedPredictor_p(ix));
                end
                % we need to keep track of real trial idx to make this work in residual models. pass ix out
            end
            % if we have predictors from a past run, add those here. 
			if ~isempty(add_in_predictors)
				if length(add_in_predictors.(1)) ~= obj.iv.num_trials
					error('we need to revise the input to take add in predictors on session scale. then we can select idx and rekill as needed')
                end
				add_in_predictors = add_in_predictors(ix, :); % this takes the same trials as the existing model from add in predictors
				t = [t, add_in_predictors];
				names = add_in_predictors.Properties.VariableNames;
		        modelspec = cell2mat([modelspec, cellfun(@(x) ['+',x],names(1:end), 'uniformoutput',0)]);
                
		        kill = zeros(size(ix));
                for ii = [1,3:size(t, 2)]
                    kill = kill + isnan(t{:, ii});
                end
                ix = ix(~kill);
                t = t(~kill, :);
                for ii = [1,3:size(t, 2)]
                    t{:,ii} = normalize_0_1(t{:,ii});
                end
                if ~sum(contains(Predictors, 'custom'))
	                plottedPredictor_p = nan(obj.iv.num_trials,1);
	                plottedPredictor_p(ix) = plottedPredictor(~kill);
	                plottedPredictor = normalize_0_1(plottedPredictor_p(ix));
                else
                	plottedPredictor = normalize_0_1(plottedPredictor(ix));
            	end
            end
            % reality check predictors
            [ff,ax2] = makeStandardFigure;
            % try
            %     plot(ax2,ix,t.allDA1,'-', 'color', [0,0.5,0],'linewidth',3, 'displayname', 'allDA1')
            %     plot(ax2,ix,t.LONTA1,'--', 'color', [0,0.5,0],'linewidth',3, 'displayname', 'LONTA1')
            %     plot(ax2,ix,t.allDA1_tdt,'r-','linewidth',2, 'displayname', 'allDA1_tdt')
            %     plot(ax2,ix,t.tdtLONTA1_tdt, 'r--','linewidth',2,'displayname', 'tdtLONTA1_tdt')
            % catch
            for ii = 3:size(t,2)
                plot(ax2,ix,t{:,ii},'--', 'linewidth',3, 'displayname', t.Properties.VariableNames{ii})
            end
            % end
            legend(ax2,'Interpreter','none')
            title(ax2, 'reality check your predictors')
			
			if verbose
				mdl = fitglm(t,modelspec,'Distribution','normal','intercept',false)
			else
				mdl = fitglm(t,modelspec,'Distribution','normal','intercept',false);
			end
            rsq = mdl.Rsquared.Ordinary;
            if verbose, disp(['Rsq = ' num2str(rsq)]),end
            yfit = mdl.Fitted.Response;


            coefficients_as_string = ['	name	estimate	tStat	p\n'];
			for ii = 1:numel(mdl.Coefficients.Properties.RowNames)
				a = mdl.Coefficients.Variables;
				coefficients_as_string = [coefficients_as_string, '	' mdl.Coefficients.Properties.RowNames{ii}, '	' mat2str(a(ii,:)), '\n'];
			end

            PlotParamsText = ['obj.predictRunningMedianLickTime(varargin) | using driftPlot and plotCoeffDrift',...
            	'\n\nModel Data:',...
            	'\n' modelspec,...
            	'\nrsq=' num2str(rsq),...
            	'\ncoefficients:',...
            	'\n' coefficients_as_string,...
            	'\n\nPredictors =' obj.unwrap_Cellstr(Predictors),...
				'\ny_signal=' num2str(y_signal),...
            	'\n\nrecycle =' num2str(recycle),...
            	'\nntrialsback=' num2str(ntrialsback),...
            	'\nmedianSmoothing=' num2str(medianSmoothing),...
            	'\nExcludeRxn=' num2str(ExcludeRxn),...
            	'\nratiobuilderresult=used',...
            	'\nTrialLimits=' num2str(TrialLimits),...
            	'\nfitIntercept=' num2str(fitIntercept),...
            	'\nDAsmoothing=' num2str(DAsmoothing),...
            	'\nXCorrMode=' num2str(XCorrMode),...
            	'\nPredictorToPlot=' PredictorToPlot,...
            	'\nsObj used?=' num2str(isempty(sObj)),...
            	'\nsloshing_obj used?=' num2str(isempty(sloshing_obj)),...
            	'\nadd_in_predictors used?=' num2str(isempty(add_in_predictors)),...
            	'\ncustom_y_signal used?=' num2str(isempty(custom_y_signal)),...
            	'\n',...
            	'\n Params of movingAverageLickTimes:',...
            	'\nExcludeITI_14=' num2str(ExcludeITI_14),...
            	'\nIncludeOtherOutcomes=' num2str(IncludeOtherOutcomes),...
            	'\nIncludeOtherOutcomes_Smoothing=' num2str(IncludeOtherOutcomes_Smoothing),...
            	'\nXCorrMode=' num2str(XCorrMode),...
            	'\nexcludedPav (means pav used for DA but not lick time)=' num2str(obj.analysis.movingAverageLickTimes.params.excludedPav),...
            	'\nratiobuilderresult used',...
            	'\n to replicate this, open the original sObj, generate sloshing_obj, and run:',...
            	'\n 	[fs, result] = ratiobuilder2_function(sObj, sloshing_obj, usepeaks, smoothing, usetdt);',...
            	'\nresult.usepeaks = ' num2str(ratiobuilderresult.usepeaks),...
            	'\nresult.smoothing = ' num2str(ratiobuilderresult.smoothing),...
            	'\nresult.usetdt = ' num2str(ratiobuilderresult.usetdt),...
            	'\n\nPearson Correlations:',...
            	'\n 	interpolated rewarded RPE (0,1) x running lick time 	r=' num2str(obj.analysis.movingAverageLickTimes.results.RPE.r) ' | p=' num2str(obj.analysis.movingAverageLickTimes.results.RPE.p),...
            	'\n 	interpolated rewarded RPE-early RPE (0,1) x running lick time 	r=' num2str(obj.analysis.movingAverageLickTimes.results.RPEminusEARLY.r) ' | p=' num2str(obj.analysis.movingAverageLickTimes.results.RPEminusEARLY.p),... 
            	];
        	obj.setUserDataStandards(PlotParamsText, ff);
            set(ff, 'name', [obj.iv.sessionCode ' | realityCheck | Rsq=' num2str(round(rsq,2)), ' | ' modelspec])


        	% if predicting del-median, we can now simulate
        	if strcmpi(y_signal, 'delmed')
	            % now we need to simulate the updates for each trial...
	            fitMedian = nan(numel(yfit),1);
	            fitMedian(1:ntrialsback) = nlt(ntrialsback);
	            if sum(~isnan(fitMedian) == 0)
	                ixx = find(~isnan(nlt), 1, 'first');
	                disp(['there was no data to initialize. moving forward to first measured lick median time, which was at trial ' num2str(ixx)])
	                fitMedian(ixx) = nlt(ixx);
	                starttrialsim = ixx;
	            else 
	                starttrialsim = 1;
	            end
	            for ii = starttrialsim:numel(yfit)
	                trial = ii+ntrialsback;
	                fitMedian(trial,1) = yfit(ii) + fitMedian(trial-1,1);
	            end
	            % get simulation rsq
	            y = nlt(starttrialsim+ntrialsback:end-1);
	            yfit_sim = fitMedian(starttrialsim+ntrialsback:end);
	            incl = find(~isnan(y));
				ESS = sum((yfit_sim(incl) - mean(y(incl))).^2);
	 			RSS = sum((yfit_sim(incl) - y(incl)).^2);
	 			Rsq_sim = ESS/(RSS+ESS); 
	 			disp(['simulation Rsq=' num2str(Rsq_sim)])
            else
            	fitMedian = [];
                Rsq_sim = rsq;
        	end

        	if strcmpi(y_signal, 'delmed_nonan')
        		nlt = nan(ntrials,1);
        		nlt(ix) = t{:,1};
    		end

        	[f,ax] = obj.driftPlot(t{:,1}, plottedPredictor, ix, TrialLimits, yfit, fitMedian, PlotParamsText, medianSmoothing, Mode,modelName,Rsq_sim, y_signal,PredictorToPlot);
        	[f2, ax2] = obj.plotCoeffDrift(mdl,PlotParamsText, modelspec);
        	fs = [f, f2, ff];
        	
        	if strcmpi(y_signal, 'med_nonan') || strcmpi(y_signal, 'delmed_nonan')
            	if XCorrMode ~= 0
            		error('XCorrMode isn''t working because we pulled an unchanged vector of nlt_no_nans from the plotting fxn. you will have to go back and figure out how to shift the xcorr again in this function to make this work. Not implemented yet for no-nan dependent variables!')
        		end
    		end
		end
		function displayPossiblePredictors_predictRunningMedianLickTime(obj)
			fprintf(['zzt.predictRunningMedianLickTime:',...
				'\n9/18/24: We''re now not fitting on trials with no lick (we will still interpolate rewarded_DA though)',...
				'\n\nthe following predictors can be used:',...
				'\n-oc_1r: reward is 1, zero otherwise',...
				'\n-allDA or alltdt: uses all peak LTA data for all trials, set smoothing in input',...
				'\n-rewarded_DA or rewarded_tdt: only looks at rewarded trials and is pre-smoothed according to the ratiobuilderresult',...
				'\n-oc_early&rew: includes early and rew predictors. Eventually would be good to have late, too',...
				'\n-nrewardssofar: not hx dependent, generally. it should just look at rewards so far in sesh',...
				'\n-minDA: takes trough DA after lick, set smoothing in input',...
				'\n-maxDA: takes peak DA after lick, set smoothing in input',...
				'\n-meanDA: takes mean DA after lick, set smoothing in input',...
				'\n-LONTA or tdtLONTA : peak DA at lamp ON, all trials irrespective of lick',...
				'\n-surpriseLONTA: peak DA after lampOff only on trials where didnt lick before ITI start',...
				'\n-LONTA_rewDA: takes sum of rewarded peak DA (presmoothed by ratiobuilderresult) and LONTA, all trials (set smoothing by input)',...
				'\n-LONTA_allDA: takes sum of all peak DA (set smoothing by input) and LONTA, all trials (set smoothing by input)',...
				'\n\n NB: so far, LONTA and allDA working best for oktoberfest, about 0.4 Rsq'
				]);

			fprintf(['\n\nWe can predict either:',...
				'\n-(recommended) med_nonan: the running median, but excluding any trials with no data (no-lick)\n 	Note this will just fit the median, no simulation',...
				'\n-delmed_nonan -- method in place but havent''t found right predictor yet or configuration to work',...
				'\n-delmed: change in the running median on each trial (might be best not to smooth).\n 	Note this will simulate from the fit the simulated median',...
				'\n-med: the running median\n 	Note this will just fit the median, no simulation',...
				'\n-custom signal: can input residual signal from a past model -- see run_satiation_vs_calibration_models.m for example syntax',...
				'\n-rewarded_DA_nonan -- will predict the rewarded_DA signal',...
				]);
		end
		function [f,ax] = driftPlot(obj, yy, plottedPredictor, trialNo, TrialLimits, yfit, simFit, PlotParamsText,medianSmoothing, Mode,modelName,rsq, y_signal,PredictorToPlot)
			[f,ax] = makeStandardFigure;
			plot(ax, yy, trialNo, 'k-', 'linewidth', 3, 'displayname', 'nlt')
			set(ax, 'ydir', 'reverse')
			ylim(ax, [TrialLimits(1), TrialLimits(end)])
            if ~isempty(yfit)
            	plot(ax, yfit, trialNo, '-', 'color', [0.8,0,0], 'linewidth', 3, 'DisplayName', sprintf(['yfit ' num2str(modelName)]))
        	end
            if ~isempty(simFit)
            	plot(ax, simFit(trialNo), trialNo, '-', 'color', [0.5,0,0], 'linewidth', 3, 'DisplayName', sprintf(['Simulation ' num2str(modelName)]))
            	% plot(ax, simFit, 1:numel(simFit), '-', 'color', [0.5,0,0], 'linewidth', 3, 'DisplayName', sprintf(['Simulation ' num2str(modelName)]))
        	end
			yyaxis right
			plot(ax, plottedPredictor, trialNo, '-', 'color', [0,0.5,0], 'linewidth', 3, 'DisplayName', sprintf([PredictorToPlot ' XCorrMode=' num2str(obj.analysis.movingAverageLickTimes.params.XCorrMode)]))
            

			% plot(ax, nR_minus_E_rpe, trialNo(1:numel(nR_minus_E_rpe)), '-', 'color', [0.5,0,0], 'linewidth', 3,'DisplayName', ['R-E RPE r=' num2str(round(r_rpe_r_minus_e_lt(2),2)), '|p=' num2str(round(pre(2),2))])
			set(ax, 'ydir', 'reverse')
			ylim(ax, [1, TrialLimits(end)])
            legend(ax, 'show')

			set(f, 'name', [obj.iv.sessionCode ' | driftPlot | Rsq=' num2str(round(rsq,2)), ' | ' modelName])
            Str = obj.setUserDataStandards(PlotParamsText, f);
            set(f, 'position', [ 0.4930    0.2077    0.2097    0.5896]);
            xlim(ax,[0,1]);
            legend(ax, 'interpreter', 'none')
		end
		function [f,ax]=plotCoeffDrift(obj,Models, PlotParamsText, ModelName, ax)
			if nargin < 5
	            [f,ax] = makeStandardFigure;
            else
            	f = ax.Parent;
            end
            if nargin < 4
            	ModelName = 'unknown model id';
        	end
            if numel(Models)>1
                mdl = Models(1);
            else
                mdl=Models;
            end
			Theta_Names = mdl.Coefficients.Properties.RowNames;
            [meanTh, ~, ~, CImin, CImax, rsq] = obj.getCompositeTheta_Drift(Models);
            
            for ii = 1:numel(Theta_Names)
                plot(ax,ii, meanTh(ii), 'r.', 'markersize', 20, 'displayname', Theta_Names{ii});
                plotCIbar(ax,ii,meanTh(ii),[CImin(ii),CImax(ii)],[]);
            end
            plot(ax, [0,numel(meanTh)+1],[0,0], 'k-', 'linewidth', 4, 'handlevisibility', 'off'); 
            xticks(ax,1:numel(meanTh));
            xticklabels(ax, Theta_Names);
            ylabel(ax,'beta')
            set(ax, 'XDir', 'reverse')
            xlim(ax,[0,numel(meanTh)+1]);
            xline(ax,0, 'k--', 'LineWidth', 3)
            set(f, 'position', [0.7030    0.2077    0.2321    0.5896])
            set(f, 'name', [obj.iv.sessionCode ' | plotCoeffDrift | Rsq=' num2str(round(rsq,2)), ' | '  ModelName])
            set(ax, 'TickLabelInterpreter', 'none')
            obj.setUserDataStandards(PlotParamsText, f);
        end
        function [f,ax]=plotCoeff(obj,Models, PlotParamsText, ModelName, ax, CIcolor)
        	if nargin < 6, CIcolor = 'k';end
			if nargin < 5
	            [f,ax] = makeStandardFigure;
            else
            	f = ax.Parent;
            end
            if nargin < 4
            	ModelName = 'unknown model id';
        	end
            if numel(Models)>1
                mdl = Models(1);
            else
                mdl=Models;
            end
			Theta_Names = mdl.Coefficients.Properties.RowNames;
            [meanTh, ~, ~, CImin, CImax, rsq] = obj.getCompositeTheta_Drift(Models);
            
            for ii = 1:numel(Theta_Names)
                plot(ax,ii, meanTh(ii), 'r.', 'markersize', 20, 'displayname', Theta_Names{ii});
                plotCIbar(ax,ii,meanTh(ii),[CImin(ii),CImax(ii)],[], CIcolor);
            end
            plot(ax, [0,numel(meanTh)+1],[0,0], 'k-', 'linewidth', 4, 'handlevisibility', 'off'); 
            xticks(ax,1:numel(meanTh));
            xticklabels(ax, Theta_Names);
            ylabel(ax,'beta')
            set(ax, 'XDir', 'reverse')
            xlim(ax,[0,numel(meanTh)+1]);
            xline(ax,0, 'k--', 'LineWidth', 3)
            set(f, 'position', [0.7030    0.2077    0.2321    0.5896])
            set(f, 'name', [obj.iv.sessionCode ' | plotCoeff | Rsq=' num2str(round(rsq,2)), ' | '  ModelName])
            set(ax, 'TickLabelInterpreter', 'none')
            obj.setUserDataStandards(PlotParamsText, f);
        end
        function [meanTh, propagated_se_th, mdf, CImin, CImax, rsq] = getCompositeTheta_Drift(obj, Models)
            % 
            %   Models is cell array with each of the models
            %       Where model is the field with the results of the fit. 
            % 
            % extract the thetas
            ths = {};
            se_ths = {};
            dfs = [];
            if numel(Models)==1
            	B = Models.Coefficients.Estimate;
	            STATS.se = Models.Coefficients.SE;
	            STATS.dfe = Models.DFE;

                ths{1} = B;
                se_ths{1} = STATS.se;
                dfs(1) = STATS.dfe;
                ths = cell2mat(ths)';
	            se_ths = cell2mat(se_ths)';
	            
	            meanTh = ths;
	            propagated_se_th = se_ths;
	            mdf = dfs;
	            CIs = coefCI(Models);
	            CImin = CIs(:,1);
	            CImax = CIs(:,2);
	            NN = nan;
	            rsq(1) = Models.Rsquared.Ordinary;
        	else
	            for imodel = 1:numel(Models)
	                ths{imodel,1} = Models(imodel).B;
	                se_ths{imodel,1} = Models(imodel).STATS.se;
	                dfs(imodel,1) = Models(imodel).STATS.dfe;
	                rsq(imodel) = Models(imodel).Rsquared.Ordinary;
	            end
                ths = cell2mat(ths)';
	            se_ths = cell2mat(se_ths)';
	            N = numel(Models);
	            NN = N.*ones(1, size(ths, 2));
	            
	            
	            meanTh = 1/N .* nansum(ths, 1);
	            propagated_se_th = 1/N .* sqrt(nansum(se_ths.^2, 1));
	            mdf = sum(dfs).*ones(1, size(meanTh,2));
	            % 
	            %   Now, calculate the CI = b +/- t(0.025, n(m-1))*se
	            % 
	            for nn = 1:size(meanTh, 2)
	                CImin(nn) = meanTh(nn) - abs(tinv(.025,numel(NN(nn))*(mdf(nn) - 1))).*propagated_se_th(nn);
	                CImax(nn) = meanTh(nn) + abs(tinv(.025,numel(NN(nn))*(mdf(nn) - 1))).*propagated_se_th(nn);
	            end
            end

            
            % note: theta in rows here, cols are min and 
            obj.analysis.flush.meanTh = meanTh;
            obj.analysis.flush.propagated_se_th = propagated_se_th;
            obj.analysis.flush.mdf = mdf;
            obj.analysis.flush.N = NN;
            obj.analysis.flush.CImin = CImin;
            obj.analysis.flush.CImax = CImax;
        end
		function [f,ax] = histogramByBlock(obj, varargin)
			% 
			% obj.histogramByBlock(('nfromEnd', 20, 'ExcludeRxn', true, 'binWidth_s', 1)
			% 
			p = inputParser;
            addParameter(p, 'nfromEnd', 20, @isnumeric);
            addParameter(p, 'ExcludeRxn', true, @islogical); 
            addParameter(p, 'binWidth_s', 1, @isnumeric); 
            addParameter(p, 'ExcludeNoLicks', true, @islogical); 
            addParameter(p, 'OwnBin333', false, @islogical); 
            parse(p, varargin{:});
            nfromEnd 			= p.Results.nfromEnd;
            ExcludeRxn          = p.Results.ExcludeRxn;
            binWidth_s 			= p.Results.binWidth_s;
            ExcludeNoLicks		= p.Results.ExcludeNoLicks;
            OwnBin333			= p.Results.OwnBin333;

			if nargin < 2, nfromEnd=30;end
			if nargin < 3, ExcludeRxn=true;end
			nPartitions = numel(obj.LTA.trials_by_block);
			if OwnBin333
				BinEdges = sort([0:binWidth_s:17, 3.333]);
			else
				BinEdges = 0:binWidth_s:17;
			end
			trialNos = obj.LTA.trials_by_block;

			flicks = obj.LTA.flick_s_wrtc;
			if ExcludeRxn
				flicks(flicks<0.5) = nan;
			end
		
			flicks_by_partitions = cellfun(@(x) flicks(x), obj.LTA.trials_by_block, 'uniformoutput', false);
			if ExcludeNoLicks
				flicks_by_partitions = cellfun(@(x) x(~isnan(x)), flicks_by_partitions, 'uniformoutput', false);
            end
            try
    			flicks_by_partitions = cellfun(@(x) x(end-nfromEnd:end), flicks_by_partitions, 'uniformoutput', false);
            catch
                warning('looks like we didnt have many licks in the last block. We usually just take the last 20 in the block...so we''ll just use them all')
                flicks_by_partitions{end} = flicks_by_partitions{end};
            end
			[~, ~, ~, inNumbers] = blockDurationParser(obj);


			[f, ax] = makeStandardFigure(nPartitions, [nPartitions,1]);
			for ii = 1:nPartitions
			    h = prettyHxg(ax(ii), flicks_by_partitions{ii}, [num2str(trialNos{ii}(1)) ':' num2str(trialNos{ii}(end))   ' | Block ' num2str(ii), ': n=' num2str(numel(flicks_by_partitions{ii}))], [0.1,0.7,0.3], BinEdges, []);
			    set(h, 'displaystyle', 'bar', 'facecolor', [0.2,0.2,0.2], 'edgecolor', [0.2,0.2,0.2])
			    if ExcludeRxn, 
			    	xlim(ax(ii),[0.5,14]);
			    else 
			    	xlim(ax(ii),[0,14])
		    	end
			    % legend(ax(ii), 'show','Location', 'best')
			    xline(ax(ii),inNumbers{ii}(1), 'c', 'linewidth', 3, 'handlevisibility', 'off')
			    xline(ax(ii),inNumbers{ii}(2), 'c', 'linewidth', 3, 'handlevisibility', 'off')
			end

			PlotParamsText = ['obj.histogramByBlock',...
            	'\n\nbinWidth_s=' num2str(binWidth_s),...
            	'\nExcludeRxn=' num2str(ExcludeRxn),...
            	'\nnfromEnd=' num2str(nfromEnd),...
            	'\nExcludeNoLicks=' num2str(ExcludeNoLicks),...
            	'\nOwnBin333=' num2str(OwnBin333),...
            	];
            
            Str = obj.setUserDataStandards(PlotParamsText, f);
            set(f, 'position', [0.5033    0.1935    0.1759    0.6039]);
            set(f, 'name', ['obj.histogramByBlock | nfromEnd=' num2str(nfromEnd) ',ExcludeRxn=' num2str(ExcludeRxn)])

		end
	end
end


