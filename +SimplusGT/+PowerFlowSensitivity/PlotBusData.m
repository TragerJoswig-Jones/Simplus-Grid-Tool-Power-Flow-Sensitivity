%% Plot grid data
%
% Modified from 'PlotGridStrength.m' function
%
% Original Author(s): Yitong Li
%
% Modified by Trager Joswig-Jones

function PlotBusData(ApparatusType,ListLine,BusData,ax,BusDataLabel,LogData,redmax,LineData,clims,hidecolorbar,bustype)
    arguments
        ApparatusType
        ListLine
        BusData = SimplusGT.Toolbox.BusStrength(ApparatusType,ListLine);
        ax = []
        BusDataLabel = "Value"
        LogData = false  
        redmax = true
        LineData = false  %TODO: Define a seperate variable for indicating if heatmap is to plot the LineData and make this pass in Data to be visualized as the edge colors
        clims = []
        hidecolorbar = false
        bustype = []
    end
    if isempty(ax)
        ax = gca;
    end
    
    mutualLines = ListLine(:, 1) ~= ListLine(:, 2);
    if ~LineData
        BusData = reshape(BusData,1,length(ApparatusType));
    else
        NumBr = size(ListLine,1);
        BusData = reshape(BusData,1, NumBr);
        BusData = BusData(mutualLines);
        NumMutualBr = sum(mutualLines);

        % % Handle multiple lines between two buses not being in the graph
        % EdgeNodes = ListLine(ListLine(:, 1) ~= ListLine(:, 2), 1:2);
        % [~, w] = unique( EdgeNodes, 'stable', 'rows');
        % duplicate_indices = setdiff( 1:numel(BusData), w );
        % for idx = duplicate_indices
        %     duplicates = sum(EdgeNodes == EdgeNodes(idx, :),2) == 2;
        %     BusData(duplicates) = max(BusData(duplicates));
        % end
        % BusData = BusData(w);
        
        % TODO: Seperate bus data from line data for self lines
        %BusData = BusData(ListLine(:, 1) == ListLine(:, 2));
    end

    % Calculate Ybus
    %Ybus = SimplusGT.PowerFlow.YbusCalc(ListLine); 
    %[~,Data,GraphFigure] = SimplusGT.Toolbox.PlotLayoutGraph(Ybus);
    [vbus,ibus,fbus] = SimplusGT.Toolbox.BusTypeVIF(ApparatusType);
    slackbus = [1];

    fr = ListLine(mutualLines, 1); to = ListLine(mutualLines, 2); nbus = max(to);
    if LineData
        weights = BusData;
    else
        weights = ListLine(mutualLines, 4);
    end
    Data = graph(fr,to,weights,nbus);
    GraphFigure = plot(ax,Data); grid on; hold on;
    % Set graph node and edge styles
    highlight(GraphFigure,Data,'EdgeColor',[0,0,0],'LineWidth',1.1);       % Change all edges to black by default
    highlight(GraphFigure,Data,'NodeColor',[0,0,0]);                    	% Change all nodes to black by default
    highlight(GraphFigure,Data,'MarkerSize',4.5);
    highlight(GraphFigure,Data,'NodeFontSize',9);
    highlight(GraphFigure,Data,'NodeFontWeight','bold');


    if ~isempty(bustype)  % Use powerflow bus types to align with model specifications
        vbus = []; ibus = []; fbus = []; slackbus = [];
        for i = 1:nbus
            if ApparatusType{i} ~= 100
                if bustype(i) == 2
                    vbus(end+1) = i;  
                elseif bustype(i) == 3
                    ibus(end+1) = i;
                else
                    slackbus(end+1) = i;
                end
            else
                fbus(end+1) = i;
            end
        end
    end

    highlight(GraphFigure,vbus,'NodeColor','blue');
    highlight(GraphFigure,ibus,'NodeColor','green'); 
    highlight(GraphFigure,slackbus,'NodeColor','black');
    highlight(GraphFigure,fbus,'NodeColor',[0.7,0.7,0.7]);   	% gray
    
    x = GraphFigure.XData';
    y = GraphFigure.YData';
    if LineData
        xLine = zeros(NumMutualBr, 1);
        yLine = zeros(NumMutualBr, 1);
        [~,edgeCoords] = layoutcoords(Data);
        for edgeIdx = 1:length(edgeCoords)
            edgeCenter = mean(edgeCoords{edgeIdx}(floor(end/2):floor(end/2)+1, :), 1);
            xLine(edgeIdx) = edgeCenter(1);
            yLine(edgeIdx) = edgeCenter(2);
        end
        edgeNodes = Data.Edges.EndNodes;
        % frNodes = edgeNodes(:, 1);
        % toNodes = edgeNodes(:, 2);
        % xFr = x(frNodes);
        % xTo = x(toNodes);
        % yFr = y(frNodes);
        % yTo = y(toNodes);
        % xLine = (xFr + xTo) / 2;
        % yLine = (yFr + yTo) / 2;
        x = xLine;
        y = yLine;
        
        % Color edeges according to the BusData values
        nc = 1000;
        cm = hsv(nc); %cool(nc); % jet(nc);
        basenc = ceil(nc * 6/10);
        nc = floor(nc * 3.5/10); % Only use this range of the cm
        DataMax = max(BusData); DataMin = min(BusData);
       
        for edgei = 1:length(edgeNodes)
            edgenodes = Data.Edges.EndNodes(edgei, :);
            cidx = basenc + ceil((nc - 1) * (BusData(edgei) - DataMin) / (DataMax - DataMin)) + 1;
            edgecolor = cm(cidx, :);
            highlight(GraphFigure,edgenodes(1), edgenodes(2),'EdgeColor',edgecolor);
        end
    end
    if LogData
        z = log10(BusData)';
    else
        z = BusData';
    end

    SimplusGT.PowerFlowSensitivity.PlotHeatMap(x,y,z,ax,redmax,clims,hidecolorbar);
    uistack(GraphFigure,'top');

    if ~hidecolorbar
        h = colorbar;
        if LogData
            h.Label.String = sprintf("log_{10}(Bus %s)", BusDataLabel);
        else
            h.Label.String = sprintf("(Bus %s)", BusDataLabel);
        end
    end
end