function [Z] = normalize_0_1(vec, OMITNAN)
    if nargin < 2, OMITNAN = false;end
    if OMITNAN
        a = vec - nanmin(vec);
	    Z = a ./ nanmax(a);
    else
	    a = vec - min(vec);
	    Z = a ./ max(a);
    end
end