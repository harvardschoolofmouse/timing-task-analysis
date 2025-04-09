% load_sObj_sloshing_zzt_FX.m
% 
% 	This method will let us quickly pull in the best files for doing zigzag timeshift analysis. It will also update the sObj.iv.path_
% 
function [sObj, sloshing_obj, zzt] = load_sObj_sloshing_zzt_FX(sObj, getsloshing, getzzt)
    if nargin < 1
        getSObj = [];
        getsloshing=true;
        getzzt = true;
    elseif nargin < 2
        getsloshing=true;
        getzzt = true;
    elseif nargin < 3
        getzzt = true;
    end
    % get sObj
    disp('*** Be sure you''re in the folder with the saved objs!')
    
    dirFiles = dir;
    
    if isempty(sObj) || (islogical(sObj) && sObj==true)
        % get sObj
        sObjpos = find(contains({dirFiles.name},'REVISED'));
        if isempty(sObjpos)
	        sObjpos = find(contains({dirFiles.name},'sObj_Corrected'));
	        if isempty(sObjpos)
		        sObjpos = find(contains({dirFiles.name},'snpObj'));
		        if isempty(sObjpos)
			        sObjpos = find(contains({dirFiles.name},'statObj'));
		        end
	        end
        end
        sObj = load(correctPathOS([dirFiles(sObjpos).folder, '\' dirFiles(sObjpos).name]));
        sObjfield = fieldnames(sObj);
        eval(['sObj = sObj.' sObjfield{1} ';']);
        sObj.iv.path_ = pwd;
    end
    
    if getsloshing
        % get sloshing_obj
        sObjpos = find(contains({dirFiles.name},'SloshingModel_'));
        if isempty(sObjpos)
	        sloshing_obj = CLASS_sloshing_model_obj(sObj);
        else
	        sloshing_obj = load(correctPathOS([dirFiles(sObjpos).folder, '\' dirFiles(sObjpos).name]));
	        sObjfield = fieldnames(sloshing_obj);
	        eval(['sloshing_obj = sloshing_obj.' sObjfield{1} ';']);
        end
    else
        sloshing_obj = [];
    end
    
    if getzzt
        % get zzt
        sObjpos = find(contains({dirFiles.name},'ZigZagTimeWindowsObj_'));
        if ~isempty(sObjpos)
	        zzt = load(correctPathOS([dirFiles(sObjpos).folder, '\' dirFiles(sObjpos).name]));
	        sObjfield = fieldnames(zzt);
	        eval(['zzt = zzt.' sObjfield{1} ';']);
        else
	        zzt = CLASS_ZigZagTimeWindows(sObj);
        end
        
        % gather pavlovian trials:
        pavlov_trials = sObj.getflickswrtj;
        zzt.LTA.pavlov_trials = pavlov_trials;
    else
        zzt = [];
    end
    
    
end