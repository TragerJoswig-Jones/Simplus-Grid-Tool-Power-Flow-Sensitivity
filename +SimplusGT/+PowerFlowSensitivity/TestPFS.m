%% Calculates the power flow sensitivities for the specified power system and compares them to the actual eigenvalue sensitivities for a perturbation to the power injection parameter.
%
% Sections modified from +Toolbox/Main.m
%
% Author(s): Trager Joswig-Jones

%%% Uncomment below if running directly from this file instead of
%%% PFSUserMain.m
% UserDataName = 'USER_IEEE_14Bus_Base';    % Base Case
% %UserDataName = 'USER_IEEE_14BusGFMBase'; 
% 
% UserDataType = 1;  % 1 for excel, 0 for json file
%
% verbose = 2;
%%%

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
BaseEigVec = EigVec;

Phi = PhiMat;
D = diag(EigVec);
D = D/(2*pi);  %TODO: Check if this is used anywhere
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
    % elseif (abs(imag(Mode(ModeSelect(modei)))) < only_real_tol) % ignore purely real eigenvalues. These values often have incorrect eigenvalue sensitivities calculated
    %     ModeSelect(modei) = [];
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

bus_type = ListBus(:,2);
bus = ListBus(:,1);      	% Bus Number..
nbus = length(bus);   	% Number of buses

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Prepare perturbation values
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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

% Plot predicted eigenvalues
FigN = 1;
figure(FigN);
pole_marker = 'o';
scatter(real(EigVec(ModeSelect)+dLambda*eps_),imag(EigVec(ModeSelect)+dLambda*eps_), 'Marker',pole_marker,'LineWidth',1.5); hold on; grid on;


%% Compare to actual power flow
LOAD_SHIFT_TO_BUS = 1:nbus; %[1,2,3,4];  
GEN_SHIFT_TO_BUS = 1:nbus; %cell2mat(ApparatusBus); %[1,2,3,4];  %TODO: Replace this will only gen buses

V_IDX = 3;
Th_IDX = 4;
PG_IDX = 5;
QG_IDX = 6;
PL_IDX = 7;
QL_IDX = 8;

p_shift_norm = eps_;  % TODO: Replaced with eps_
% Push power flow perturbations to power flow data list
LOAD_SHIFTS = dPL.';
GEN_SHIFTS = -dPg.';    %TODO: Use dPG or dPg (load flow corrected)? Must use dPg for indirect paramter changes (V at PQ bus)
QLOAD_SHIFTS = dQL.';    %TODO: Should these (dPg, dQg) be negative? Sign flip between these and dV, dTh due to load form
QGEN_SHIFTS = -dQg.';  %TODO: Use dQG or dQg (load flow corrected)?
V_SHIFTS = dV.';
Th_SHIFTS = dTh.';

LOAD_GEN_SHIFTS = [LOAD_SHIFTS GEN_SHIFTS];
ListBusShift = ListBus;

ListBusShift(LOAD_SHIFT_TO_BUS,PL_IDX) = ListBusShift(LOAD_SHIFT_TO_BUS,PL_IDX) + eps_ * LOAD_SHIFTS';
ListBusShift(GEN_SHIFT_TO_BUS,PG_IDX) = ListBusShift(GEN_SHIFT_TO_BUS,PG_IDX) + eps_ * GEN_SHIFTS';  %TODO: Minus or plus here? 

ListBusShift(LOAD_SHIFT_TO_BUS,QL_IDX) = ListBusShift(LOAD_SHIFT_TO_BUS,QL_IDX) + eps_ * QLOAD_SHIFTS';
ListBusShift(GEN_SHIFT_TO_BUS,QG_IDX) = ListBusShift(GEN_SHIFT_TO_BUS,QG_IDX) + eps_ * QGEN_SHIFTS';

ListBusShift(LOAD_SHIFT_TO_BUS,V_IDX) = ListBusShift(LOAD_SHIFT_TO_BUS,V_IDX) + eps_ * V_SHIFTS';
ListBusShift(GEN_SHIFT_TO_BUS,Th_IDX) = ListBusShift(GEN_SHIFT_TO_BUS,Th_IDX) + eps_ * Th_SHIFTS';

V1 = ListPowerFlowBase(:, 4) + eps_ * V_SHIFTS'; 
del1 = ListPowerFlowBase(:, 5) + eps_ * Th_SHIFTS'; 
[PowerFlow] = SimplusGT.PowerFlow.PowerFlowNR_Hotstart(ListBusShift,ListLine,V1,del1,Wbase);
[ListBusNew,ListLineNew,PowerFlowNew] = SimplusGT.PowerFlow.Load2SelfBranch(ListBusShift,ListLine,PowerFlow);

ListPowerFlowNew = SimplusGT.PowerFlow.Rearrange(PowerFlowNew);

ListPowerFlowShift = ListPowerFlowNew - ListPowerFlowBaseNew; % vs ListdRhoDrho prediction

ActualListPfSens = ListPowerFlowShift*1/eps_;
ActualListPfSens


% Calculate eigenvalues for shifted power flow

% ### Get the models of bus apparatuses
%fprintf('Get the descriptor state space model of bus apparatuses...\n')
ApparatusPowerFlow = cell(1,nbus);
x_e = cell(1,nbus);
x_u = cell(1,nbus);
for i = 1:NumApparatus
    if length(ApparatusBus{i}) == 1
 	    ApparatusPowerFlow{i} = PowerFlowNew{ApparatusBus{i}};
    elseif length(ApparatusBus{i}) == 2
        ApparatusPowerFlow{i} = [PowerFlowNew{ApparatusBus{i}(1)},PowerFlowNew{ApparatusBus{i}(2)}];
    else
        error(['Error']);
    end
    
    % The following data may not used in the script, but will be used in
    % simulations. So, do not delete!
    [ObjGmCell{i},GmDssCell{i},ApparatusPara{i},ApparatusEqui{i},ApparatusDiscreDamping{i},OtherInputs{i},ApparatusStateStr{i},ApparatusInputStr{i},ApparatusOutputStr{i}] = ...
        SimplusGT.Toolbox.ApparatusModelCreate(ApparatusBus{i},ApparatusType{i},ApparatusPowerFlow{i},Para{i},Ts,ListBusNew);
    x_e{i} = ApparatusEqui{i}{1};
    u_e{i} = ApparatusEqui{i}{2};
end
clear('i');

% ### Get the appended model of all apparatuses
%fprintf('Get the appended descriptor state space model of all apparatuses...\n')
ObjGm = SimplusGT.Toolbox.ApparatusModelLink(ObjGmCell);

% ### Get the model of whole system
%fprintf('Get the descriptor state space model of whole system...\n')
[ObjGsysDss,GsysDss,PortV,PortI,PortBusV,PortBusI] = ...
    SimplusGT.Toolbox.ConnectGmZbus(ObjGm,ZbusObj,NumBus);

% ### Whole-system admittance model
ObjYsysDss = SimplusGT.ObjTruncate(ObjGsysDss,PortI,PortV);
[~,YsysDss] = ObjYsysDss.GetDSS(ObjYsysDss); 
ObjYsysSs = SimplusGT.ObjDss2Ss(ObjYsysDss);
[~,YsysSs] = ObjYsysSs.GetSS(ObjYsysSs); 

ObjGsysSs = SimplusGT.ObjDss2Ss(ObjGsysDss);
[~,GsysSs] = ObjGsysSs.GetSS(ObjGsysSs);

% ### Check stability
fprintf('\n')
fprintf('Calculate pole/zero...\n')
[PhiMat,EigVec] = eigenshuffle(GsysSs.A);
EigVec = EigVec(find(real(EigVec) ~= inf));
EigVecHz = EigVec/2/pi;

FigN = 1;
figure(FigN);
pole_marker = '+';
scatter(real(EigVec),imag(EigVec), 'Marker',pole_marker,'LineWidth',1.5); hold on; grid on;
xlabel('Real Part (rad)');
ylabel('Imaginary Part (rad)');
title('pole map');
axis([-80,20,-150,150]);

disp("Results: ");
fprintf("Lambda \t\t\t\t Actual DL \t\t\t Calculated DL \t\t Error \n")
for ModeSelIdx = 1:length(ModeSelect)
    eig_idx = ModeSelect(ModeSelIdx);
    actual_dlambda = (EigVec(eig_idx) - BaseEigVec(eig_idx)) * 1/eps_;
    calc_dlambda = dLambda(ModeSelIdx);
    err = actual_dlambda - calc_dlambda;
    lambda = Mode(eig_idx);
    if sign(imag(lambda)) < 0; lambda_imag_sign = '-'; else lambda_imag_sign = '+'; end
    if sign(imag(actual_dlambda)) < 0; actual_imag_sign = '-'; else actual_imag_sign = '+'; end
    if sign(imag(calc_dlambda)) < 0; calc_imag_sign = '-'; else calc_imag_sign = '+'; end
    if sign(imag(err)) < 0; error_imag_sign = '-'; else error_imag_sign = '+'; end

    fprintf('%.3f %c %.3f j \t %.3f %c %.3f j \t %.3f %c %.3f j \t %.3f %c %.3f j \n', ...
        real(lambda), lambda_imag_sign, abs(imag(lambda)), ...
        real(actual_dlambda), actual_imag_sign, abs(imag(actual_dlambda)),...
        real(calc_dlambda), calc_imag_sign, abs(imag(calc_dlambda)),...
        real(err), error_imag_sign, abs(imag(err)))
end