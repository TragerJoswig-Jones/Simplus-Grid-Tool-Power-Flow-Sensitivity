%% Readme
%
% This script starts the Main and Test power flow sensitivities scripts.
% The MainPFS.m script generates heatmaps of bus power injection sensitivity
% metrics.
% The TestPFS.m script compares calculated eigenvalue sensitivity value 
% using our method to the actual eigenvalue sensitivity values found by 
% perturbing a power flow value and recalculating the eigenvalues.
%
% To run dynamical simulations of these systems run the UserMain.m file to
% load in the IEEE 14 bus system data for the desured case and then open 
% the IEEE_14bus.slx simulink file in the Examples/PowerFlowSensitivity 
% directory.
%
% More manuals related to Simplus-GT are available in the "Documentations" folder.

%% Clear matlab
clear all; clc; 
close all; 

%%%%%%%%%%%%%%%%%%%%%%%%%
%% Select system data case
%%%%%%%%%%%%%%%%%%%%%%%%%
% UserDataName = 'UserData';      % Default 4-bus system

UserDataName = 'USER_IEEE_14Bus_Base';
% UserDataName = 'USER_IEEE_14Bus_CaseA';
%UserDataName = 'USER_IEEE_14Bus_GFMBase';

%% Change the current folder of matlab
cd(fileparts(mfilename('fullpath')));

%% Set user data type and script options
% If user data is in excel format, please set 1. If it is in json format,
% please set 0.
UserDataType = 1;

verbose = 0;
saveplots = false;
nocbar = false;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Calculate power flow sensitivities and plot heat maps
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
SimplusGT.PowerFlowSensitivity.MainPFS();  


%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Run PFS calculation test
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initialize power flow perturbation vectors
dPG = zeros(nbus,1);
dPL = zeros(nbus,1);
dQG = zeros(nbus,1);
dQL = zeros(nbus,1);
dP = zeros(nbus,1);
dQ = zeros(nbus,1);
dV = zeros(nbus,1);
dTh = zeros(nbus,1);

%%%%%%%%%%%%%%%%%%%%%%%%%
% Set perturbation value
%%%%%%%%%%%%%%%%%%%%%%%%%
%dPG(2) = 1;  % Increase real power injected by device at bus 2
%dQG(2) = 1;
dPG(8) = 1;  
%dQG(8) = 1;

SimplusGT.PowerFlowSensitivity.TestPFS();  