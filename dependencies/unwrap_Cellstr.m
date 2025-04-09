function str = unwrap_Cellstr(C)	
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