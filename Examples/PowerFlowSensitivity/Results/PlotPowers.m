% Plots the time-domain simulation data from '.mat' files
%
% These '.mat' files contain the saved 'out' variable data that is created when
% running 
%
% Author(s): Trager Joswig-Jones

% List all files in the given directory
result_dir = "Examples/PowerFlowSensitivity/Data";
files = dir(fullfile(result_dir, '*.mat'));

% fileNames = ["BaseCase.mat", "CaseA.mat", "CaseB.mat", "CaseA2.mat", "GFMCaseA.mat"];  % Custom ordering
% caseLabels = ["Base Case", "Case A", "Case B", "Case A-2", "Case A-3"];

% fileNames = ["CaseA.mat", "CaseA2.mat", "GFMCaseA.mat"];  % Remedial Action Custom Ordering
% caseLabels = ["Case A", "Case A-2", "Case A-3"];
% dflt_colors = get(gca, 'ColorOrder');
% caseColors = {dflt_colors(2, :), dflt_colors(4, :), dflt_colors(5, :)};
% caseLineStyles = {'--', '-.', '--'}; % {"-", "--", ":", "-.", "--"};
% caseLineWidths = {1.5, 1.5, 2};

fileNames = ["BaseCase.mat", "CaseA.mat", "CaseB.mat"];  % Active Power Sensitivity Case Ordering
caseLabels = ["Base Case", "Case A", "Case B"];
dflt_colors = get(gca, 'ColorOrder');
caseColors = {dflt_colors(1, :), dflt_colors(2, :), dflt_colors(3, :)};
caseLineStyles = {'-', '--', ':'}; % {"-", "--", ":", "-.", "--"};
caseLineWidths = {1.5, 1.5, 1.5};

% for i = 1:length(fileNames)
%     fileName = fileNames(i);
%     files(i).name = fileName;
% end

for i = length(files):-1:1
    fileNamesIdx = find(files(i).name == fileNames);
    if isempty(fileNamesIdx)
        files(i) = [];  % Remove file from plot data
    else
        files(i).name = fileNames(fileNamesIdx);  % Set name from case labels
    end
end

simout = [];
for file_i = 1:length(files)
    file = files(file_i);
    simdata = load(fullfile(result_dir, file.name));
    simout = [simout, simdata];
end

fig = figure(1);
figpos = [100 100 400 300];
fig.Position = figpos; theme(fig,"light");
% axs = plotPowers(simout, ["Scope10Data"], 1, ["V_d", "V_q"], ["Base Case", "Case A", "Case A-2", "Case B"], false, fig);
%plotPowers(simout, ["Scope10Data"], 5, ["\omega"], ["Base Case", "Case A", "Case A-2", "Case B"], false, fig);

% axs = plotPowers(simout, ["Scope10Data"], [1,5], ["$|V|$", "$\omega$"], ["Base Case", "Case A", "Case A-2", "Case B"], [true, false], fig);
axs = plotPowers(simout, ["Scope10Data"], [1,5], ["$|V|$ (pu)", "$\omega$ (pu)"], caseLabels, [true, false], fig, caseColors, caseLineStyles, caseLineWidths);
xlabel("time (s)")

xlim(axs(1), [0.9,3])
xlim(axs(2), [0.9,3])
ylim(axs(1), [0.8,1.2])
ylim(axs(2), [0.95,1.05])

pos1 = get(axs(2), 'Position');
pos1(2) = pos1(2) + 0.075;  % shift upward
set(axs(2), 'Position', pos1)
axs(1).XTickLabel = [];

% exportgraphics(fig,'loadstepsim.pdf','BackgroundColor','none','ContentType','vector');
exportgraphics(fig,'loadstepsim.png','BackgroundColor','none','Resolution',400);

% Vdq
%ylim(axs(1), [0.8,1.1])
%ylim(axs(2), [-0.1,0.1])


function axs = plotPowers(simdata, scopeNames, dataIdx, axisLabels, legendLabels, plotNorm, fig, colors, linestyles, linewidths)
arguments
    simdata 
    scopeNames
    dataIdx = 7;
    axisLabels = ["1", "2", "3"];
    legendLabels = [];
    plotNorm = false;
    fig = [];
    colors = get(gca, 'ColorOrder');
    linestyles = {"-", "--", ":", "-.", "--"};
    linewidths = {1.5, 1.5, 1.5, 1.5, 2};
end
    if isempty(fig)
        fig = figure();
    end
    for scopeName = scopeNames
        for i = 1:length(simdata)
            simout = simdata(i);
            axs = plotPower(fig, simout, scopeName, colors{i}, linestyles{i}, linewidths{i}, dataIdx, axisLabels, plotNorm);
        end
    end
    %ax = axes('Parent',fig);
    %subplot(2, 1, 1);
    legend(axs(1), legendLabels, 'location', 'northoutside', 'orientation', 'horizontal', 'NumColumns', 3);
end

function axs = plotPower(fig, simout, scopeName, color, linestyle, linewidth, dataIdx, axisLabels, plotNorm)
arguments
    fig 
    simout 
    scopeName 
    color = 'b'
    linestyle = '-'
    linewidth = 2
    dataIdx = 7
    axisLabels = '               '
    plotNorm = 0
end
    tvalues = simout.out.(scopeName){dataIdx(1)}.Values.Time;
    dataValues = [];
    for datai = 1:length(dataIdx)
        newDataValues = getData(simout,scopeName, dataIdx(datai), plotNorm(datai));
        dataValues = [dataValues, newDataValues];
    end

    valueShape = size(dataValues);
    nsubplots = valueShape(2);
    
    axs = [];
    %h = tiledlayout(nsubplots,1, 'TileSpacing', 'none', 'Padding', 'none');
    for j = 1:nsubplots
        values = dataValues(:, j);
        ax = subplot(nsubplots, 1, j);
        %ax = nexttile;
        axs = [axs, ax];
        plot(tvalues, values, linestyle, 'LineWidth', linewidth, 'Color', color);
        hold on;
        ylabel(axisLabels(j), 'Interpreter', 'latex')
    end
end

function dataValues = getData(simout,scopeName,dataIdx,plotNorm)
    dataValues = simout.out.(scopeName){dataIdx}.Values.Data;
    if size(dataValues, 1) == 1
        dataValues = reshape(dataValues,[length(dataValues), 1]);
    end
    if plotNorm
        dataValues = vecnorm(dataValues, 2, 2);
    end
end