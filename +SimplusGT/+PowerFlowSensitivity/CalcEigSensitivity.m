% Original Author(s): Trager Joswig-Jones
function [dLambda] = CalcEigSensitivity(YsysSs, AppPfSenseResults, ModeSelect, PfSens, Phi, Psi)
%CALCEIGSENSITIVITY Summary of this function goes here
%   Detailed explanation goes here
arguments
    YsysSs
    AppPfSenseResults
    ModeSelect
    PfSens
    Phi = eigenshuffle(YsysSs.A)
    Psi = inv(Phi)
end
%% Calculate the eigenvalue sensitivity for each specified mode
dLambda = zeros(length(ModeSelect),1);
for ModeSelIdx = 1:length(ModeSelect)
    AppPfSenseResult = AppPfSenseResults(ModeSelIdx).ModeResult;

    DZ = [];
    for i = 1:length(AppPfSenseResult)  % Iterate over the devices
        AppDZ = zeros(2,2);  %TODO: Only considering AC devices here
        for k = 1:length(PfSens)  % Iterate over the PF parameters
            Dpf = PfSens{k}(i);  
            if isempty(AppPfSenseResult(i).PfResult(k).DeltaZ)
                AppDZ = AppDZ + zeros(2,2);
            else
                AppDZ = AppDZ + AppPfSenseResult(i).PfResult(k).DeltaZ * Dpf;  % TODO: multiply by a power flow vector here or just use diffs?
            end
        end
        DZ = blkdiag(DZ, AppDZ);
    end
    
    dZdP = DZ;
    Res = YsysSs.C(:,:) * Phi(:,ModeSelect(ModeSelIdx)) * Psi(ModeSelect(ModeSelIdx),:) * YsysSs.B(:,:);
    Dlambda = -1*conj(sum(dot(dZdP,Res')));  % Inner product / Frobinious

    dLambda(ModeSelIdx,1) = Dlambda;
end
end

