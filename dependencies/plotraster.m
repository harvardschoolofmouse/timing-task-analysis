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