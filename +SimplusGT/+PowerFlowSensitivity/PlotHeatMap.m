% Plot heat map based on a layout graph and its x, y, z data.
%
% Author(s): Yitong, Yue Zhu
%
% Modified by Trager Joswig-Jones

function PlotHeatMap(x,y,z,ax,redmax, clims, hidecb)
arguments
    x 
    y 
    z 
    ax = []
    redmax = true
    clims = []
    hidecb = false
end
    if isempty(ax)
        ax = gca;
    end
    Center = [(max(x)+min(x))/2, (max(y)+min(y))/2];
    Delta = max(max(x)-min(x),max(y)-min(y))/2;

    [xDelta,yDelta] = meshgrid(linspace(-Delta*1.2,Delta*1.2,500));
    xmesh = xDelta + Center(1);
    ymesh = yDelta + Center(2);
    
    % Extend data to have whitespace at the corners
    whiteval = (1 - redmax) * max(z);
    x = [x; xmesh(1); xmesh(1); xmesh(end); xmesh(end)];
    y = [y; ymesh(1); ymesh(end); ymesh(1); ymesh(end)];
    z = [z; whiteval; whiteval; whiteval; whiteval];
    % Extend data to have whitespace around the edges
    x = [x; (xmesh(1)+xmesh(end))/2; (xmesh(1)+xmesh(end))/2;  xmesh(1); xmesh(end)];
    y = [y; ymesh(1); ymesh(end); (ymesh(1)+ymesh(end))/2; (ymesh(1)+ymesh(end))/2];
    z = [z; whiteval; whiteval; whiteval; whiteval];

    % Interpolant
    if unique(x) == 1
        x = [x; x(1)+Delta*0.01; x(1)-Delta*0.01];
        y = [y; y(1); y(1)];
        z = [z; z(1); z(1)];
    end
    if unique(y) == 1
        x = [x; x(1); x(1)];
        y = [y; y(1)+Delta*0.01; y(1)-Delta*0.01];
        z = [z; z(1); z(1)];
    end
    % if true  %TEST: No boundaries on the values given
    %     x = [x; x(1); x(1)];
    %     y = [y; y(1); y(1)];
    %     z = [z; z(1); z(1)];
    % end
    F = scatteredInterpolant(x,y,z);
    F.Method = 'natural';
    %F.Method = 'linear';
    %F.ExtrapolationMethod = 'boundary';
    zmesh = F(xmesh,ymesh);

    % Plot
    cf = contourf(ax,xmesh,ymesh,zmesh,150,'LineColor','none');      % Color map
    
    % Set color bar
    if ~hidecb
    colorbar;                                       % Color bar
    end
    if ~isempty(clims)
        clim(clims);
    end
    
    % red - yellow - green - white
    c1 = [200, 0, 0]/255;
    c2 = [255, 192, 0]/255;
    c3 = [255, 255, 89]/255;
    % More green
    % c4 = [68, 252, 152]/255;
    % c5 = [147, 255, 196]/255;
    % Balanced
    c4 = [147, 255, 196]/255;
    c5 = [169, 252, 207]/255;
    % Default
    % c4 = [147, 255, 196]/255;
    % c5 = [213, 249, 243]/255;
    c6 = [255,255,255]/255;

    colors = {c1, c2, c3, c4, c5, c6};
    if redmax
        colors = flip(colors);
    end
    
    c1 = colors{1};
    c2 = colors{2};
    c3 = colors{3};
    c4 = colors{4};
    c5 = colors{5};
    c6 = colors{6};

    for i=1:3
         g1=linspace(c1(i),c2(i),200);
         g2=linspace(c2(i),c3(i),300);
         g3=linspace(c3(i),c4(i),200);
         g4=linspace(c4(i),c5(i),200);
         g5=linspace(c5(i),c6(i),500);
        gx(:,i)=[g1,g2,g3,g4,g5]';
    end

    colormap(gx);
    
    % % Limit the graph z data
    % if min(z) < max(z)
    %     climt = [min(z), max(z)];
    % else
    %     climt = [max(z)*0.9, max(z)*1.1];
    % end
    % clim(climt);

end