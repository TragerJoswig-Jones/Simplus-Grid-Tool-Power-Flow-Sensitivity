%% Calculates the sensitivity of the power flow to perturbations in power flow parameters
%
% Author(s): Trager Joswig-Jones

function [dP,dQ,dV,dTh,dw] = PowerFlowSensitivity(dP_,dQ_,dV_,dTh_,ListBus,ListLine,ListPowerFlowBase)
%PowerFlowSensitivity calculates the power flow sensitivities to a change
%in a power flow parameter by calling the helper function below after
%calculating the whole jacobian.
%   Takes in the parameter perturbations (dP_, dQ_, dV_, dTh_) and a list of
%   bus types (Slack: 1, PV: 2, PQ: 3) and returns the power flow
%   sensitivities to that parameter perturbation
J = SimplusGT.PowerFlowSensitivity.WholePowerFlowJacobian(ListBus,ListLine,ListPowerFlowBase); 
J = -J; % Negative due to load power convention used by Simplus-GT when storing power flows...
bustype = ListBus(:, 2);
[dP,dQ,dV,dTh,dw] = power_flow_sensitivity(dP_, dQ_, dV_, dTh_, J, bustype);
end

function [dP,dQ,dV,dTh,dw] = power_flow_sensitivity(dP_,dQ_,dV_,dTh_,J,bustype)
%power_flow_sensitivity calculates the power flow sensitivities to a change
%in a power flow parameter
%   Takes in the parameter perturbations (dP_, dQ_, dV_, dTh_) and a list of
%   bus types (Slack: 1, PV: 2, PQ: 3) and returns the power flow
%   sensitivities to that parameter perturbation
nbus = length(bustype);

Slackbus = bustype == 1;
PVbus = bustype == 2;
PQbus = bustype == 3;

NotSlackIdx = ~Slackbus;
NotPVIdx = ~PVbus;

PbarIdx = PVbus | PQbus;
QbarIdx = PQbus;
VbarIdx = PVbus | Slackbus;
ThbarIdx = Slackbus;

PtildeIdx = ~PbarIdx;
QtildeIdx = ~QbarIdx;
VtildeIdx = ~VbarIdx;
ThtildeIdx = ~ThbarIdx;

J_bar_tilde = J([PbarIdx; QbarIdx], [ThtildeIdx; VtildeIdx]);
J_bar_bar = J([PbarIdx; QbarIdx], [ThbarIdx, VbarIdx]);
J_tilde_dot = J([PtildeIdx; QtildeIdx], :);
J_dot_tilde = J(:, [VtildeIdx; ThtildeIdx]);

dPbar_ = dP_(PbarIdx);
dQbar_ = dQ_(QbarIdx);
dVbar_ = dV_(VbarIdx);
dThbar_ = dTh_(ThbarIdx);
dPtilde_ = dP_(PtildeIdx);
dQtilde_ = dQ_(QtildeIdx);
dVtilde_ = dV_(VtildeIdx);
dThtilde_ = dTh_(ThtildeIdx);

% dVThtilde to dVThbar
J_bar_tilde_inv = inv(J_bar_tilde);
dVThbar_ = [dThbar_; dVbar_];
dVThtilde_fr_dVThbar = -J_bar_tilde_inv * J_bar_bar * dVThbar_;

% dPQbar to dVThtilde
dPQbar_ = [dPbar_; dQbar_];
dVThtilde_fr_dPQbar = J_bar_tilde_inv * dPQbar_;

% dPQtilde from dVThtilde & dVThbar
dVThtilde = (dVThtilde_fr_dVThbar + dVThtilde_fr_dPQbar);
dVTh_ = zeros(2*nbus,1);
dVTh_([ThtildeIdx; VtildeIdx], :) = dVThtilde;
dVTh_([ThbarIdx; VbarIdx], :) = dVThbar_; %[dThbar_; dVbar_];
dPQtilde = J_tilde_dot * dVTh_;

% dPQ from dVThtilde
dVThtilde_ = [dThtilde_; dVtilde_];
dPQ_fr_dVThtilde = J_dot_tilde * dVThtilde_;

% approximate dVTh from dPQtilde
%Jpinv = pinv(J_tilde_dot); 
% dPQtilde_ = [dPtilde_; dQtilde_];
% dVTh_fr_dPQtilde = Jpinv * dPQtilde_;
Jpinv = pinv(J); 
dPQtilde_ = [dPtilde_; dQtilde_];
dPQ_ = zeros(2*nbus,1);
dPQ_([PtildeIdx; QtildeIdx], :) = dPQtilde_;
dVTh_fr_dPQtilde = Jpinv * dPQ_;

% % Calculate dVTh and slack bus dP/Q from dPQtilde 
% AllIdx = boolean(ones(nbus,1));
% % NSPQIdx = [NotSlackIdx; NotSlackIdx];  % Eliminate slack P equation
% NSPQIdx = [AllIdx; NotSlackIdx];  % Eliminate slack Q equation
% NSVThIdx = [NotSlackIdx; AllIdx];  % Eliminate slack Theta variable
% J2 = J(NSPQIdx, NSVThIdx);
% dVTh2 = inv(J2) * dPQ_(NSPQIdx);
% dVTh2_ = zeros(2*nbus,1);
% dVTh2_(NSVThIdx, :) = dVTh2;
% dPQ2 = J * dVTh2_;


% combine the perturbations
dVTh = dVTh_fr_dPQtilde;
dPQ = dPQ_fr_dVThtilde;

dVTh([ThtildeIdx, VtildeIdx]) = dVTh([ThtildeIdx, VtildeIdx]) + dVThtilde + dVThtilde_;
dPQ([PtildeIdx, QtildeIdx]) = dPQ([PtildeIdx, QtildeIdx]) + dPQtilde + dPQtilde_;

dVTh([ThbarIdx, VbarIdx]) = dVTh([ThbarIdx, VbarIdx]) + dVThbar_;
dPQ([PbarIdx, QbarIdx]) = dPQ([PbarIdx, QbarIdx]) + dPQbar_;

dTh = dVTh(1:nbus, :);
dV = dVTh(nbus+1:end, :);
dP = dPQ(1:nbus, :);
dQ = dPQ(nbus+1:end, :);
dw = zeros(nbus, 1);
end

