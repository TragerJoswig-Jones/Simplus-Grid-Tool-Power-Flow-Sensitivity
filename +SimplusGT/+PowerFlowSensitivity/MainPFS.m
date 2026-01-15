%%% Calculates the power flow sensitivities for the specified power system
%   and plots these as heat maps.
%
% Sections modified from +Toolbox/Main.m
%
% Author(s): Trager Joswig-Jones

%%% Uncomment below if running directly from this file instead of
%%% PFSUserMain.m
% UserDataName = 'USER_IEEE_14Bus_Base';    % Base Case
% %UserDataName = 'USER_IEEE_14Bus_CaseA';   % Active power increase at sensitive bus
% %UserDataName = 'USER_IEEE_14Bus_CaseB';   % Active power increase at insensitive bus
% %UserDataName = 'USER_IEEE_14Bus_CaseA2';  % Reactive power change to improve stability
% %UserDataName = 'USER_IEEE_14BusGFMBase'; % Base case with GFM at bus 8
% %UserDataName = 'USER_IEEE_14BusGFMCaseA';   % Case A with GFM at bus 8
% 
% UserDataType = 1;  % 1 for excel, 0 for json file
% 
% 
% verbose = 0;
% saveplots = false;
% nocbar = false;
%%%

figscale=0.8;
figpos = figscale*[100 100 300 300];
colorbarwidth = figscale*[0 0 65 0];
if ~nocbar
    figpos = figpos + colorbarwidth;
end
axpos = [40 40 250 250];

[UserData,UserDataStruct] = SimplusGT.PowerFlowSensitivity.LoadUserData(UserDataName,UserDataType,verbose);

% ==================================================
% Load model data
% ==================================================
% ### Re-arrange basic settings
Fs = UserDataStruct.Basic.Fs;
Ts = 1/Fs;               % (s), sampling period
Fbase = UserDataStruct.Basic.Fbase; % (Hz), base frequency
Sbase = UserDataStruct.Basic.Sbase; % (VA), base power
Vbase = UserDataStruct.Basic.Vbase; % (V), base voltage
Ibase = Sbase/Vbase;     % (A), base current
Zbase = Vbase/Ibase;     % (Ohm), base impedance
Ybase = 1/Zbase;         % (S), base admittance
Wbase = Fbase*2*pi;      % (rad/s), base angular frequency
Advance = UserDataStruct.Advance;

% ### Re-arrange the bus netlist
[ListBus,NumBus] = SimplusGT.Toolbox.RearrangeListBusStruct(UserDataStruct);

bus = ListBus(:,1);      	% Bus Number..
bustype = ListBus(:,2);  % Bus type..
nbus = length(bus);   	% Number of buses

SlackBus = bustype == 1;
PVbus = bustype == 2;
PQbus = bustype == 3;

Vbus = SlackBus | PVbus;   VbusIdx = find(Vbus);
Pbus = PVbus | PQbus;   PbusIdx = find(Pbus);
Qbus = PQbus;   QbusIdx = find(Qbus);
ThetaBus = SlackBus;   ThetabusIdx = find(ThetaBus);

% ### Re-arrange the line netlist
[ListLine,~,~] = SimplusGT.Toolbox.RearrangeListLineStruct(UserDataStruct,ListBus);
FlagDcArea = find(ListBus(:,12)==2);        % Check dc area

NumBranches = size(ListLine,1);

% ### Re-arrange the apparatus netlist
NumApparatus = length(UserDataStruct.Apparatus);
ApparatusBus = cell(1,NumApparatus);
ApparatusType = cell(1,NumApparatus);
Para = cell(1,NumApparatus);
for i = 1:NumApparatus
    ApparatusBus{i} = UserDataStruct.Apparatus(i).BusNo;
    ApparatusType{i} = UserDataStruct.Apparatus(i).Type;
    Para{i} = UserDataStruct.Apparatus(i).Para;
end
clear('i');

apptype = cell2mat(ApparatusType);  % used later for identifying passive buses

% ==================================================
% Base Power flow analysis
% ==================================================
% ### Power flow analysis
fprintf('Do the power flow analysis...\n')
if ~isempty(FlagDcArea)
    UserDataStruct.Advance.PowerFlowAlgorithm = 1;
    fprintf(['Warning: Because the system has dc area(s), the Gauss-Seidel power flow method is always used.\n']);
end
switch UserDataStruct.Advance.PowerFlowAlgorithm
    case 1  % Gauss-Seidel 
        [PowerFlowBase] = SimplusGT.PowerFlow.PowerFlowGS(ListBus,ListLine,Wbase);
    case 2  % Newton-Raphson
       	[PowerFlowBase] = SimplusGT.PowerFlow.PowerFlowNR(ListBus,ListLine,Wbase);
    otherwise
        error(['Error: Wrong setting for power flow algorithm.']);
end

% Move load flow (PLi and QLi) to bus admittance matrix
[ListBusNew,ListLineNew,PowerFlowNewBase] = SimplusGT.PowerFlow.Load2SelfBranch(ListBus,ListLine,PowerFlowBase);

% For print
ListPowerFlowBase = SimplusGT.PowerFlow.Rearrange(PowerFlowBase);
ListPowerFlowBaseNew = SimplusGT.PowerFlow.Rearrange(PowerFlowNewBase);

if verbose
fprintf('Print power flow result:\n')
fprintf('The format below is "| bus | P | Q | V | angle | omega |". P and Q are in load convention.\n')
ListPowerFlowBase
end

% ==================================================
% Create apparatus state space models
% ==================================================

% ### Get the model of lines
fprintf('Get the descriptor state space model of network lines...\n')

[YbusObj,YbusDSS,~] = SimplusGT.Toolbox.YbusCalcDss(ListBus,ListLineNew,Wbase);
[~,lsw] = size(YbusDSS.B);
ZbusObj = SimplusGT.ObjSwitchInOut(YbusObj,lsw);
[ZbusStateStr,ZbusInputStr,ZbusOutputStr] = ZbusObj.GetString(ZbusObj);

% ### Get the models of bus apparatuses
fprintf('Get the descriptor state space model of bus apparatuses...\n')
ObjGmCell = cell(1,nbus);
GmDssCell = cell(1,nbus);
ApparatusPara = cell(1,nbus);
ApparatusEqui = cell(1,nbus);
ApparatusDiscreDamping = cell(1,nbus);
OtherInputs = cell(1,nbus);
ApparatusStateStr = cell(1,nbus);
ApparatusInputStr = cell(1,nbus);
ApparatusOutputStr = cell(1,nbus);
ApparatusPowerFlow = cell(1,nbus);

for i = 1:NumApparatus
    if length(ApparatusBus{i}) == 1
     	ApparatusPowerFlow{i} = PowerFlowNewBase{ApparatusBus{i}};
    elseif length(ApparatusBus{i}) == 2
        ApparatusPowerFlow{i} = [PowerFlowNewBase{ApparatusBus{i}(1)},PowerFlowNewBase{ApparatusBus{i}(2)}];
    else
        error(['Error']);
    end
    [ObjGmCell{i},GmDssCell{i},ApparatusPara{i},ApparatusEqui{i},ApparatusDiscreDamping{i},OtherInputs{i},ApparatusStateStr{i},ApparatusInputStr{i},ApparatusOutputStr{i}] = ...
        SimplusGT.Toolbox.ApparatusModelCreate(ApparatusBus{i},ApparatusType{i},ApparatusPowerFlow{i},Para{i},Ts,ListBus);
    
    % The following data is not used in the script, but will be used in
    % simulations. Do not delete!
    x_e{i} = ApparatusEqui{i}{1};
    u_e{i} = ApparatusEqui{i}{2};
end
clear('i');

% ### Get the appended model of all apparatuses
fprintf('Get the appended descriptor state space model of all apparatuses...\n')
GmObj = SimplusGT.Toolbox.ApparatusModelLink(ObjGmCell);

% ### Get the model of whole system
fprintf('Get the descriptor state space model of whole system...\n')
[GsysObj,GsysDSS,Port_v,Port_i,BusPort_v,BusPort_i] = ...
    SimplusGT.Toolbox.ConnectGmZbus(GmObj,ZbusObj,NumBus);

% ### Whole-system admittance model
YsysObj = SimplusGT.ObjTruncate(GsysObj,Port_i,Port_v);
[~,YsysDSS] = YsysObj.GetDSS(YsysObj);
ObjYsysSs = SimplusGT.ObjDss2Ss(YsysObj);
[~,YsysSs] = ObjYsysSs.GetSS(ObjYsysSs); 

% ### Convert to SS system
GminSSObj = SimplusGT.ObjDss2Ss(GsysObj);
[~,GsysSsFull] = GminSSObj.GetSS(GminSSObj);
[GminStateStr,~,~]=GminSSObj.GetString(GminSSObj);

% ### Chech if the system is proper
if verbose
fprintf('Checking if the whole system is proper:\n')
end
if isproper(GsysDSS)
    if verbose
    fprintf('Proper!\n');
    fprintf('Calculating the minimum realization of the system model for later use...\n')
    end
    % GminSS = minreal(GsysDSS);
    GminSS = SimplusGT.dss2ss(GsysDSS);
    % This "minreal" function only changes the element sequence of state
    % vectors, but does not change the element sequence of input and output
    % vectors.
    InverseOn = 0;
else
    error('Error: System is improper, which has more zeros than poles.')
end
if SimplusGT.is_dss(GminSS)
    error(['Error: Minimum realization is in descriptor state space (dss) form.']);
end

AppSel = [1:NumApparatus];

% Select which model to use for eigenvalue calculations
GsysSS = GsysSsFull; %GminSS;  

% ==================================================
% Calculate modes
% ==================================================
pole_sys = pole(GsysDSS);

[PhiMat,EigVec] = eigenshuffle(GsysSS.A);
EigVec = EigVec(find(real(EigVec) ~= inf));
EigVecHz = EigVec/2/pi;
Mode=EigVec;

Phi = PhiMat;
D = diag(EigVec);
D = D/(2*pi);
Psi=inv(Phi); 

maxrealeig = max(real(EigVecHz));
if maxrealeig > 1e-4
    warning("System is unstable: max(L) = %0.4f", maxrealeig)
end

FigN = 1;
fig = figure(FigN);
subplot(1,2,1);
scatter(real(pole_sys),imag(pole_sys),'x','LineWidth',1.5); hold on; grid on;
%scatter(real(Mode),imag(Mode),'x','LineWidth',1.5); hold on; grid on;
xlabel('Real Part (Hz)');
ylabel('Imaginary Part (Hz)');
title(sprintf("Eigenvalues (n = %i)", length(Mode)))

% ==================================================
%% Calculate the system power flow sensitivities
% ==================================================
fprintf('Calculating device power flow sensitivities...\n')

% Select the modes of interest manually
%ModeSelect = [7, 9, 12, 39, 41];

% Automatically set modes of interest
eps_ = 1e-5;

min_real_abs_val = 0.1;
max_real_val = -100;

mode_unique_tol = 1e-4;
omega_nom_tol = 1e-1;
only_real_tol = 1e-7;
max_im_val = 1000;

ModeSelectAll = 1:length(Mode);
ModeSelect =  ModeSelectAll( (abs(real(Mode)) > min_real_abs_val) & (real(Mode) > max_real_val) );

% Find the eigenvalues within the specified ranges (max_real_val, -min_real_abs_val) & min_real_abs_val, inf)
% Also check uniqueness of the eigenvalue and pop non-unique values
% Takes only the eigenvalue with real imaginary part for pairs
ModeUnique = zeros(size(ModeSelect));
ModePair = zeros(size(ModeSelect));
for modei = length(ModeSelect):-1:1
    ModeUnique(modei) = sum(abs(Mode - Mode(ModeSelect(modei))) < mode_unique_tol) == 1;
    ModePair(modei) = sum(abs(real(Mode - Mode(ModeSelect(modei)))) < mode_unique_tol) > 1;
    if ~ModeUnique(modei)
        if verbose > 0
            warning("Mode %d is not unique", ModeSelect(modei))
        end
        ModeSelect(modei) = [];
    elseif ModePair(modei) && (imag(Mode(ModeSelect(modei))) < 0)  % remove negative imag part pair eigenvalue
        ModeSelect(modei) = [];
    % elseif (abs(imag(Mode(ModeSelect(modei))) - Wbase) < omega_nom_tol) % ignore nominal frequency oscillatory eigenvalues
    %     ModeSelect(modei) = [];
    elseif (abs(imag(Mode(ModeSelect(modei)))) < only_real_tol) % ignore purely real eigenvalues. These values often have incorrect eigenvalue sensitivities calculated
        ModeSelect(modei) = [];
    elseif (abs(imag(Mode(ModeSelect(modei)))) > max_im_val)  % ignore modes with large imaginary terms
        ModeSelect(modei) = [];
    end

end

if isempty(ModeSelect)
    error('Error: No modes selected.');
end

selectedModes = Mode(ModeSelect);

FigN = 1;
fig = figure(FigN); theme(fig,"light");
subplot(1,2,2)
scatter(real(Mode),imag(Mode),'x','LineWidth',1.5); hold on; grid on;
scatter(real(Mode(ModeSelect)),imag(Mode(ModeSelect)),'x','LineWidth',1.5); hold on; grid on;
xlabel('Real Part (Hz)');
ylabel('Imaginary Part (Hz)');
title(sprintf("Selected Eigenvalues (n = %i)", length(ModeSelect)))
axis([max_real_val*1.1,max(real(Mode(ModeSelect))),-max_im_val*1.1,max_im_val*1.1]);

% Get the device impedance sensitivities
[AppPfSenseResults] = SimplusGT.PowerFlowSensitivity.DeviceImpedanceSensitivity(ModeSelect, NumApparatus, ...
    ApparatusType, Para, ApparatusBus, ApparatusInputStr, ApparatusOutputStr, ...
    GminStateStr, GsysSS, GsysDSS, GmDssCell, ApparatusPowerFlow, ListBus, AppSel, Ts, eps_, true);

%% Plot IMR for comparison
IMRvals = zeros(NumApparatus, length(ModeSelect));
for i = 1:NumApparatus
    for j = 1:length(ModeSelect)
        IMRvals(i,j) = AppPfSenseResults(j).ModeResult(i).IMR;
    end
end 

MinIMRvals = min(IMRvals, [], 2);
MinIMRvals(isnan(MinIMRvals)) = max(MinIMRvals) + 1;  % Copy maximum values to passive buses for plotting

% Plot heatmap
FigN = 100;
fig = figure(FigN); theme(fig,"light");
%set(gca, 'Units', 'pixels', 'Position', axpos);
fig.Position = figpos + colorbarwidth + colorbarwidth;  % Make IMR plot slightly wider
SimplusGT.PowerFlowSensitivity.PlotBusData(ApparatusType,ListLineNew,MinIMRvals,gca,"IMR",true,false,false,[],false);
set(gca,'linewidth',1, 'box','off');
set(gca().XAxis, "Visible", 'off'); set(gca().YAxis, "Visible", 'off');
if saveplots
exportgraphics(gca,'IMR.pdf','BackgroundColor','none','Resolution',400);
end
% ==================================================
% Calculate power flow propogations and eigenvalue sensitivities
% ==================================================
V0 = ListPowerFlowBase(:, 4);
del0 = ListPowerFlowBase(:, 5);
w0 = Wbase;
Y = SimplusGT.PowerFlow.YbusCalc(ListLine); 
G = real(Y);          	% Conductance matrix..
B = imag(Y);         	% Susceptance matrix..
J = SimplusGT.PowerFlowSensitivity.PowerFlowJacobian(ListBus,ListLine,ListPowerFlowBase,V0,del0,w0);

wJ = SimplusGT.PowerFlowSensitivity.WholePowerFlowJacobian(ListBus,ListLine,ListPowerFlowBase);

bus_type = ListBus(:,2);
bus = ListBus(:,1);      	% Bus Number..
nbus = length(bus);   	% Number of buses

% Initialize power flow perturbation vectors
dPG = zeros(nbus,1);
dPL = zeros(nbus,1);
dQG = zeros(nbus,1);
dQL = zeros(nbus,1);
dP = zeros(nbus,1);
dQ = zeros(nbus,1);
dV = zeros(nbus,1);
dTh = zeros(nbus,1);

%% Calculate generator active power injection sensitivities
fprintf('Calculating active power injection sensitivities...\n')
iGenBus = 1;
PassiveBuses = apptype == 100;
BusIdxs = 1:nbus;
DeviceIdxs = BusIdxs(~PassiveBuses); PDeviceIdxs = BusIdxs(~PassiveBuses & Pbus.');
NumDevices = length(DeviceIdxs);  NumPDevices = length(PDeviceIdxs);
PiSens = zeros(NumPDevices,length(ModeSelect));
for i = 1:NumPDevices
    iDevice = PDeviceIdxs(i);
    dPG = zeros(nbus,1);
    iGenBus = ApparatusBus{iDevice};
    
    % Shift active power generation from slack bus to other buses 
    %dPG(iGenBus) = -1;  % This line is not needed for the power flow sense
    dPG(iGenBus) = 1;

    dP = -dPG + dPL;  % injected power delta
    dQ = -dQG + dQL;
    
    dM = [dPG, dPL, dQG, dQL, dV, dTh];

    % Calculate power flow perturbations
    [dPi,dQi,dVi,dThi,dwi] = SimplusGT.PowerFlowSensitivity.PowerFlowSensitivity(dP,dQ,dV,dTh,ListBus,ListLine,ListPowerFlowBase);
    dPg = (dPi - dPL);
    dQg = (dQi - dQL);
    
    PfSens = {dPg, dQg, dVi, dThi, dwi};
    nvars = length(PfSens);  % number of power flow parameters
    
    if verbose > 1
        % convert to a list for viewing
        lpf = length(PfSens);
        ListPfSens = zeros(nbus,nvars+1);
        ListPfSens(:,1) = [1:nbus];
        for k = 1:lpf
            ListPfSens(:,k+1) = PfSens{k};
        end
        clear('k')
        fprintf('Print power flow sensitivity result:\n')
        fprintf('dPG, dPL, dQG, dQL, dV, dTh')
        dM
        fprintf('The format below is "| bus | P | Q | V | angle | omega |". P and Q are in load convention.\n')
        ListPfSens
    end
    
    % Calculate the eigenvalue sensitivity
    dLambda = SimplusGT.PowerFlowSensitivity.CalcEigSensitivity(YsysSs, AppPfSenseResults, ModeSelect, PfSens, Phi, Psi);
    if verbose > 2
        for ModeSelIdx = 1:length(ModeSelect)
            Dlambda = dLambda(ModeSelIdx);
            fprintf("Lambda: %f + %f j, dLambda: %f + %f j \n", [real(Mode(ModeSelect(ModeSelIdx))), imag(Mode(ModeSelect(ModeSelIdx))), real(Dlambda), imag(Dlambda)])
        end
    end

    PiSens(i, :) = dLambda;
end

PiSensNorm = PiSens ./ abs(real(Mode(ModeSelect))).';

PiSensAllBus = zeros(nbus, length(ModeSelect));  % Include zeros for passive buses
PiSensAllBus(PDeviceIdxs,:) = PiSensNorm;

% Find each device's maximum sensitivity from the selected modes
PiSensMaxToSens = max(real(PiSens), [], 2);  % Increasing power generated at bus i
PiSensMaxFrSens = max(-real(PiSens), [], 2);  % Decreasing power geneerated at bus i

PiSensMaxSensAllBus = max(abs(real(PiSensAllBus)), [], 2);
PiSensMaxToSensAllBus = max(real(PiSensAllBus), [], 2);
PiSensMaxFrSensAllBus = max(-real(PiSensAllBus), [], 2);

% Plot heatmap
clims = [0, max(PiSensMaxSensAllBus)];
clims = [0, 0.7]; % Manually set lims to align between cases

FigN = FigN + 1; fig = figure(FigN); theme(fig,"light"); fig.Position = figpos;
SimplusGT.PowerFlowSensitivity.PlotBusData(ApparatusType,ListLineNew,PiSensMaxToSensAllBus,gca,"Active Power Injection Increase",false,true,false,clims,nocbar);
set(gca,'linewidth',1, 'box','off');
set(gca().XAxis, "Visible", 'off'); set(gca().YAxis, "Visible", 'off');
if saveplots
exportgraphics(gca,'PtoSens.pdf','BackgroundColor','none','Resolution',400);
end

FigN = FigN + 1; fig = figure(FigN); theme(fig,"light"); fig.Position = figpos;
SimplusGT.PowerFlowSensitivity.PlotBusData(ApparatusType,ListLineNew,PiSensMaxFrSensAllBus,gca,"Active Power Injection Decrease",false,true,false,clims,nocbar);
set(gca,'linewidth',1, 'box','off');
set(gca().XAxis, "Visible", 'off'); set(gca().YAxis, "Visible", 'off');
if saveplots
exportgraphics(gca,'PfrSens.pdf','BackgroundColor','none','Resolution',400);
end

FigN = FigN + 1; fig = figure(FigN); theme(fig,"light"); fig.Position = figpos;
SimplusGT.PowerFlowSensitivity.PlotBusData(ApparatusType,ListLineNew,PiSensMaxSensAllBus,gca,"Active Power Injection Absolute Sensitivity",false,true,false,clims,nocbar);
set(gca,'linewidth',1, 'box','off');
set(gca().XAxis, "Visible", 'off'); set(gca().YAxis, "Visible", 'off');
if saveplots
exportgraphics(gca,'AbsPSens.pdf','BackgroundColor','none','Resolution',400);
end

% Plot heatmap with cbar
if nocbar
    FigN = FigN + 1; fig = figure(FigN); theme(fig,"light"); fig.Position = figpos+colorbarwidth;
    SimplusGT.PowerFlowSensitivity.PlotBusData(ApparatusType,ListLineNew,PiSensMaxSensAllBus,gca,"",false,true,false,clims,false);
    set(gca,'linewidth',1, 'box','off');
    set(gca().XAxis, "Visible", 'off'); set(gca().YAxis, "Visible", 'off');
    if saveplots
    exportgraphics(gca,'PSensScale.pdf','BackgroundColor','none','Resolution',400);
    end
end

dPG = zeros(nbus,1);
dPL = zeros(nbus,1);
dQG = zeros(nbus,1);
dQL = zeros(nbus,1);
dP = zeros(nbus,1);
dQ = zeros(nbus,1);
dV = zeros(nbus,1);
dTh = zeros(nbus,1);

%% Calculate generator reactive power injection sensitivities 
fprintf('Calculating reactive power injection sensitivities...\n')
iGenBus = 1;
PassiveBuses = apptype == 100;
BusIdxs = 1:nbus;
DeviceIdxs = BusIdxs(~PassiveBuses); QDeviceIdxs = BusIdxs(~PassiveBuses & Qbus.');
NumDevices = length(DeviceIdxs); NumQDevices = length(QDeviceIdxs);
QiSens = zeros(NumQDevices,length(ModeSelect));
for j = 1:NumQDevices
    jDevice = QDeviceIdxs(j);
    dQG = zeros(nbus,1);
    jGenBus = ApparatusBus{jDevice};
    % Shift reactive power generation from slack bus to other buses 
    dQG(jGenBus) = 1;

    dP = -dPG + dPL;  % injected power delta
    dQ = -dQG + dQL;
    
    dM = [dPG, dPL, dQG, dQL, dV, dTh];

    % Calculate power flow perturbations
    [dPi,dQi,dVi,dThi,dwi] = SimplusGT.PowerFlowSensitivity.PowerFlowSensitivity(dP,dQ,dV,dTh,ListBus,ListLine,ListPowerFlowBase);
    dPg = (dPi - dPL);
    dQg = (dQi - dQL);
    
    PfSens = {dPg, dQg, dVi, dThi, dwi};
    nvars = length(PfSens);  % number of power flow parameters
    
    if verbose > 1
        % convert to a list for viewing
        lpf = length(PfSens);
        ListPfSens = zeros(nbus,nvars+1);
        ListPfSens(:,1) = [1:nbus];
        for k = 1:lpf
            ListPfSens(:,k+1) = PfSens{k};
        end
        clear('k')
        fprintf('Print power flow sensitivity result:\n')
        fprintf('dPG, dPL, dQG, dQL, dV, dTh')
        dM
        fprintf('The format below is "| bus | P | Q | V | angle | omega |". P and Q are in load convention.\n')
        ListPfSens
    end
    
    % Calculate the eigenvalue sensitivity
    dLambda = SimplusGT.PowerFlowSensitivity.CalcEigSensitivity(YsysSs, AppPfSenseResults, ModeSelect, PfSens, Phi, Psi);
    if verbose > 2
        for ModeSelIdx = 1:length(ModeSelect)
            Dlambda = dLambda(ModeSelIdx);
            fprintf("Lambda: %f + %f j, dLambda: %f + %f j \n", [real(Mode(ModeSelect(ModeSelIdx))), imag(Mode(ModeSelect(ModeSelIdx))), real(Dlambda), imag(Dlambda)])
        end
    end

    QiSens(j, :) = dLambda;
end

QiSensNorm = QiSens ./ abs(real(Mode(ModeSelect))).';

QiSensAllBus = zeros(nbus, length(ModeSelect));  % Include zeros for passive buses
QiSensAllBus(QDeviceIdxs,:) = QiSensNorm;

% Find each device's maximum sensitivity from the selected modes
QiSensMaxToSens = max(real(QiSensNorm), [], 2);  % Increasing power generated at bus i
QiSensMaxFrSens = max(-real(QiSensNorm), [], 2);  % Decreasing power geneerated at bus i
QiSensMaxSensAllBus = max(abs(real(QiSensAllBus)), [], 2);
QiSensMaxToSensAllBus = max((real(QiSensAllBus)), [], 2);
QiSensMaxFrSensAllBus = max(-(real(QiSensAllBus)), [], 2);

% Plot heatmap
clims = [0, max(QiSensMaxSensAllBus)];
clims = [0, 4];

FigN = FigN + 1; fig = figure(FigN); theme(fig,"light"); fig.Position = figpos;
SimplusGT.PowerFlowSensitivity.PlotBusData(ApparatusType,ListLineNew,QiSensMaxToSensAllBus,gca,"Reactive Power Injection Increase",false,true,false,clims,nocbar);
set(gca,'linewidth',1, 'box','off');
set(gca().XAxis, "Visible", 'off'); set(gca().YAxis, "Visible", 'off');
if saveplots
exportgraphics(gca,'QtoSens.pdf','BackgroundColor','none','BackgroundColor','none','Resolution',400);
end

FigN = FigN + 1; fig = figure(FigN); theme(fig,"light"); fig.Position = figpos;
SimplusGT.PowerFlowSensitivity.PlotBusData(ApparatusType,ListLineNew,QiSensMaxFrSensAllBus,gca,"Reactive Power Injection Decrease",false,true,false,clims,nocbar);
set(gca,'linewidth',1, 'box','off');
set(gca().XAxis, "Visible", 'off'); set(gca().YAxis, "Visible", 'off');
if saveplots
exportgraphics(gca,'QfrSens.pdf','BackgroundColor','none','BackgroundColor','none','Resolution',400);
end

FigN = FigN + 1; fig = figure(FigN); theme(fig,"light"); fig.Position = figpos;
SimplusGT.PowerFlowSensitivity.PlotBusData(ApparatusType,ListLineNew,QiSensMaxSensAllBus,gca,"Reactive Power Injection Sensitivity",false,true,false,clims,nocbar);
set(gca,'linewidth',1, 'box','off');
set(gca().XAxis, "Visible", 'off'); set(gca().YAxis, "Visible", 'off');
if saveplots
exportgraphics(gca,'AbsQSens.pdf','BackgroundColor','none','BackgroundColor','none','Resolution',400);
end

% Plot heatmap with cbar
if nocbar
    FigN = FigN + 1; fig = figure(FigN); theme(fig,"light"); fig.Position = figpos+colorbarwidth;
    SimplusGT.PowerFlowSensitivity.PlotBusData(ApparatusType,ListLineNew,QiSensMaxSensAllBus,gca,"",false,true,false,clims,false);
    set(gca,'linewidth',1, 'box','off');
    set(gca().XAxis, "Visible", 'off'); set(gca().YAxis, "Visible", 'off');
    if saveplots
    exportgraphics(gca,'QSensScale.pdf','BackgroundColor','none','BackgroundColor','none','Resolution',400);;
    end
end

%%
fprintf('\n')
fprintf('==================================\n')
fprintf('End: Run Successfully.\n')
fprintf('==================================\n')