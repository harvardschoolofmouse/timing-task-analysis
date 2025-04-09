function reversePlotOrder(ax, ordering)
    %
    %   Reorders the plots in ax. If no ax specified, uses gca. Ordering:
    %   'reverse' or 'random' (default reverse). Or put in the order you
    %   want!
    %
    if nargin < 1 || isempty(ax)
        ax = gca;
    end
    if nargin < 2
        ordering = 'reverse';
    end
    h = get(ax,'Children');
    if isnumeric(ordering)
        idx = ordering;
    elseif strcmpi(ordering, 'reverse')
        idx = fliplr(1:numel(h));
    elseif strcmpi(ordering, 'random')
        idx = randperm(numel(h));
    end
    set(ax,'Children', h(idx))
end