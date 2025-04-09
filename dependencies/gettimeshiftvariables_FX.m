% gettimeshiftvariables_FX.m
% 
% Instructions!
%   1. Go to the sObj folder for the session you want to process. 
%   2. Open the sObj (might have to run sObj = obj;
%   3. Run the code -- this will SAVE the revised sObj to the original
%   folder (so be sure you're in the right folder!!)
%   4. After doing all this, your sObj is ready to make a ZZTobj
% 
% goals:
%   Idea is to take any zigzag timeshift session and automatically
%   recognize the block changes and report the data needed to process zzt
%   objs
% 
% eg    obj.GLM.trials_by_block = {1:192, 193:341, 374:594,595:714};
%       obj.GLM.reward_windows_by_block = {'3.333-7s', '7-12s','2-3.333s','3.333-7s’};
%
% ultimately will make a function of zztobj
if ~isfield(sObj.GLM,'ZZTprepFLAG')
    disp('=======================')
    disp([' For session ' sObj.iv.filename_ '...'])
    seshNo = sObj.iv.daynum_;
    if contains(seshNo, 'rj') 
        seshNo = seshNo(1:end-2);
    end
    if contains(seshNo, 'j') 
        seshNo = seshNo(1:end-1);
    end
    if contains(seshNo, 'stim') 
        seshNo = seshNo(1:end-4);
    end

    % check if MBI file is in the folder already
    dirFiles = dir;
    cednames = {dirFiles(3:end).name};
    cednames = cednames(contains(cednames,'.mat'));
    s7spos =  find((contains(cednames,['_' seshNo '_']) | contains(cednames,['_' seshNo '.'])) & ~contains(cednames, 'optolog') & ~contains(cednames, '201') & ~contains(cednames, '202') & ~contains(cednames, '_pre_and_'));
    CEDfilename = cednames{s7spos};

    matNames = {dirFiles(3:end).name};
    matNames = matNames(contains(matNames,'.mat'));
    

    MBIpos =  find(~ismember(matNames,CEDfilename) & contains(matNames,['_' seshNo '_']) & ~contains(matNames, 'optolog') & (contains(matNames, '201') | contains(matNames, '202') | contains(matNames, '_pre_and_')));
    MBIfilename_init = matNames(MBIpos);
    if numel(MBIfilename_init) > 0
        if numel(MBIfilename_init) > 1
            warning('rbf found multiple MBI files? make sure they are sorted correctly')
            disp(MBIfilename_init)
        end
        % start by getting the date tag so we do in order
        date_tags = cellfun(@(x) strsplit(x, '202'), MBIfilename_init, 'UniformOutput', 0);
        date_tags = cellfun(@(x) ['202' x{end}], date_tags, 'UniformOutput', 0);
        [~,ix] = sort(date_tags);

        MBIfilename = {};
        MBIpath = {};

        for dd = 1:numel(MBIfilename_init)
            fileix = ix(dd);
            MBIfilename{fileix} = MBIfilename_init{dd};
            MBIpath{fileix} = pwd;
        end
    else
        [MBIfilename, MBIpath] = uigetfile('*.mat', 'Select MBI file for this session');
        MBIfilename = {MBIfilename};
        MBIpath = {MBIpath};
        retdir = pwd;
        cd(MBIpath{1})
        % ask user if there's additional files...
        while true
            disp(['Previous file: ' MBIfilename{end}])
            ButtonName = questdlg('Any additional MBI files for this session? (pick them in order!)', 'More files?', ...
                'No');
            if strcmp(ButtonName, 'No')
                break
            elseif strcmp(ButtonName, 'Yes')
                [fn, p] = uigetfile('*.mat', 'Select next MBI file for this session');
                if sum(fn)
                    MBIfilename{end+1} = fn;
                    MBIpath{end+1} = p;
                else
                    disp('  decided not to add another file!')
                    break
                end
            else
                disp('  decided not to add another file!')
                break        
            end
        end
        cd(retdir)
    end
    %%
    reward_left_by_trial = [];
    reward_right_by_trial = [];
    last_pre_train = [];
    ntrialslastsesh = 0;
    pretraining_trials = [];
    for ii = 1:numel(MBIpath)
        disp(['loading MBI file ' MBIfilename{ii}, ' (' num2str(ii) '/' num2str(numel(MBIpath)) ')'])
        MBI = load(correctPathOS([MBIpath{ii}, '\' MBIfilename{ii}]));
        MBI = MBI.obj;
        param_data = MBI.ParamValues';
        param_names = MBI.ParamNames';
        
        % we are looking for params that indicate the reward window
        reward_window_left_idx = find(contains(param_names, 'INTERVAL_MIN'));
        reward_window_right_idx = find(contains(param_names, 'INTERVAL_MAX'));
        pretraining_flag_idx = find(contains(param_names, 'ENFORCE_NO_LICK'));
        
        params_by_trial = {MBI.Trials.Parameters};
        
        
        rlbt= cell2mat(cellfun(@(x) x(reward_window_left_idx), params_by_trial, 'UniformOutput',0)');
        reward_left_by_trial(end+1:end+numel(rlbt),1) = rlbt; 
        rrbt = cell2mat(cellfun(@(x) x(reward_window_right_idx), params_by_trial, 'UniformOutput',0)');
        reward_right_by_trial(end+1:end+numel(rrbt),1) = rrbt; 
        ptt = find(~cell2mat(cellfun(@(x) x(pretraining_flag_idx), params_by_trial, 'UniformOutput',0)')) + ntrialslastsesh;
        pretraining_trials(end+1:end+numel(ptt),1) = ptt;
        
        % rather than kill pretraining, we'll just subtract the highest pretraining
        % trial from the trial number before proceeding at the end
        if ~isempty(pretraining_trials)
            last_pre_train(ii) = max(pretraining_trials);   
        else
            last_pre_train = 0;
        end
        if ii>1 && last_pre_train(ii) ~= last_pre_train(ii-1)
            warning('hey! looks like there''s pretraining in the second+ file(s). Check this because AH didn''t write to deal with this yet')
        end
        ntrialslastsesh = ntrialslastsesh+length(params_by_trial);
    end
    last_pre_train = last_pre_train(1);

    % now we need to do the business of defining blocks
    block_starts_by_left_side = [find([0;reward_left_by_trial(2:end) - reward_left_by_trial(1:end-1)] ~= 0)];
    block_starts_by_right_side = [find([0;reward_right_by_trial(2:end) - reward_right_by_trial(1:end-1)] ~= 0)];
    assert(sum(ismember(block_starts_by_left_side, block_starts_by_right_side)) == length(block_starts_by_left_side))
    assert(sum(ismember(block_starts_by_left_side, block_starts_by_right_side)) == length(block_starts_by_right_side))
    block_starts = block_starts_by_left_side;

    block_ends_by_left_side = [find(reward_left_by_trial(2:end) - reward_left_by_trial(1:end-1) ~= 0); numel(reward_right_by_trial)];
    block_ends_by_right_side = [find(reward_right_by_trial(2:end) - reward_right_by_trial(1:end-1) ~= 0); numel(reward_right_by_trial)];
    assert(sum(ismember(block_ends_by_left_side, block_ends_by_right_side)) == length(block_ends_by_left_side))
    assert(sum(ismember(block_ends_by_left_side, block_ends_by_right_side)) == length(block_ends_by_right_side))
    block_ends = block_ends_by_left_side;

    % get now in CED trial numbers:
    block_starts = num2cell([1;block_starts - last_pre_train]);
    block_ends = num2cell(block_ends - last_pre_train);
    trials_by_block = cellfun(@(x,y) x:y, block_starts, block_ends, 'uniformoutput',0);
        
    % finally, get the legend data
    reward_left_by_block = reward_left_by_trial(cell2mat(block_starts) + last_pre_train);
    reward_right_by_block = reward_right_by_trial(cell2mat(block_starts) + last_pre_train);
    for ii = 1:length(block_starts)
        reward_windows_by_block{ii} = [num2str(reward_left_by_block(ii)/1000) '-' num2str(reward_right_by_block(ii)/1000) 's'];
    end

    %% last step: prepare for zztobj

    sObj.GLM.trials_by_block = trials_by_block;
    sObj.GLM.reward_windows_by_block = reward_windows_by_block;
    sObj.extractRewardedTrials;
    sObj.GLM.ZZTprepFLAG = 'automatically figured out timeshift blocks with gettimeshiftvariablesTEST.m -- this is determining block changes from MBI, assuming the 90s gap between blocks';

    %% save revised sObj to its home folder
    % check folder ID:
    currentFolderName = strsplit(pwd, '\');
    currentFolderName = strsplit(currentFolderName{end}, '/');
    HOSTfoldername = strsplit(sObj.iv.path_, '\');
    HOSTfoldername = strsplit(HOSTfoldername{end}, '/');
    if ~strcmp(currentFolderName, HOSTfoldername)
        error(['DID NOT SAVE!! doesn''t look like we''re in the right folder. we should be in ' sObj.iv.path_ ' Move to the correct folder and run sObj.save to complete this process.'])
    end
    sObj.iv.MBIfilename = MBIfilename;
    sObj.iv.MBIpath = MBIpath;
    sObj.save;
else
    disp('already done!')
end