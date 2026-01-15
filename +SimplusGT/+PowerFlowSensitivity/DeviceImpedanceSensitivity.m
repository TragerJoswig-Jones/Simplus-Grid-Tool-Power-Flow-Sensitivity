%% Plot grid data
%
% Modified from '+Modal/AppModalAnalysis.m'
%
% Original Author(s): Yue Zhu
%
% Modified by Trager Joswig-Jones

function [Result] = DeviceImpedanceSensitivity(ModeSelect, N_Apparatus, ApparatusType, Para, ApparatusBus, ApparatusInputStr, ApparatusOutputStr, ...
    GsysSsStateStr, GminSS, GsysDSS, GmDSS_Cell, ApparatusPowerFlow, ListBus, ApparatusSel, Ts, eps_, CalcIMR) 
arguments
    ModeSelect
    N_Apparatus
    ApparatusType
    Para
    ApparatusBus
    ApparatusInputStr
    ApparatusOutputStr
    GsysSsStateStr
    GminSS
    GsysDSS
    GmDSS_Cell
    ApparatusPowerFlow
    ListBus
    ApparatusSel
    Ts
    eps_ = 1e-5
    CalcIMR = false
end
%DEVICEIMPEDANCESENSITIVITY Summary of this function goes here
%   Detailed explanation goes here

% calculation of residues and device impedance values, at the selected mode
[MdMode,ResidueAll,ZmValAll]=...
    SimplusGT.Modal.SSCal(GminSS, N_Apparatus, ApparatusType, ModeSelect, GmDSS_Cell, ApparatusInputStr, ApparatusOutputStr);

SelIndex = 1;
ApparatusSelL12 = 0;
ApparatusIndex = 1;
for k = 1:N_Apparatus
    if ApparatusType{k} ~= 100 %not a floating bus)
        ApparatusSelL12(SelIndex) = k;
        SelIndex = SelIndex +1;
        ApparatusIndex = ApparatusIndex +1;
    else % floating bus, infinite bus...
    end        
end
ModeSelNum = length(ModeSelect);
ModeSelAll=ModeSelect;

if CalcIMR
    for modei=1:ModeSelNum
        Residue_ = ResidueAll{modei};
        ZmVal_ = ZmValAll{modei};

        % Calculate the impedance margin ratio (IMR)
        SigmaMag = abs(real(MdMode(ModeSelAll(modei))))*2*pi; % MdMode is in the unite of Hz, so needs to be changed to rad.
        count=1;
        for k=1:length(ApparatusType)
            Residue = Residue_{k}; % [Residue_(k).dd Residue_(k).dq; Residue_(k).qd, Residue_(k).qq];
            ZmVal = ZmVal_{k}; % [ZmVal_(k).dd ZmVal_(k).dq; ZmVal_(k).qd, ZmVal_(k).qq];

            IMR{modei}.SigmaMag = SigmaMag;
            IMR{modei}.ResidueNorm = norm(Residue,"fro");
            IMR{modei}.IM(count) = SigmaMag / norm(Residue,"fro"); 
                
    
            if ApparatusType{k} <= 89 % Ac apparatus
                IMR{modei}.Type(count) = ApparatusType{k};
                % conj(sum(dot(A,B'))) = A(1,1)*B(1,1) + A(1,2)*B(2,1) + A(2,1)*B(1,2) + A(2,2)*B(2,2)

                IMRVal = SigmaMag/abs( -1 * conj(sum( dot(Residue,ZmVal' )) ) ) ;
                %IMRVal = SigmaMag/(SimplusGT.Frobenius_norm_dq(Residue_(k))*SimplusGT.Frobenius_norm_dq(ZmVal_(k)));
                IMR{modei}.IMRVal(count) = IMRVal;
                count = count+1;
    
            elseif ApparatusType{k} >= 1000 && ApparatusType{k} <= 1089 % Dc apparatus
                IMR{modei}.Type(count) = ApparatusType{k};
                IMR{modei}.IMRVal(count) = SigmaMag/abs( -1 * conj(sum( dot(Residue,ZmVal' )) ) ) ;
                count = count+1;
            elseif ApparatusType{k} >= 2000 && ApparatusType{k} <= 2009 % Interlink apparatus
                IMR{modei}.Type(count) = ApparatusType{k};
                IMR{modei}.IMRVal(count) = SigmaMag/abs( -1 * conj(sum( dot(Residue,ZmVal' )) ) ) ;
                count = count+1;
            elseif  ApparatusType{k} == 90 || ApparatusType{k} == 1090   % infinite bus: let IMR=inf
                IMR{modei}.Type(count) = ApparatusType{k};
                IMR{modei}.IMRVal(count)=inf;
                count = count+1;
            else    % floating bus, do nothing
                IMR{modei}.Type(count) = NaN;
                IMR{modei}.IMRVal(count)=NaN;
                count = count+1;
            end
        end
    end
end


% Calculate the device impedance sensitivity
for ModeSel = 1:length(ModeSelect)
    Mode_Hz = MdMode(ModeSelAll(ModeSel));
    ZmVal = ZmValAll{ModeSel};
    Residue = ResidueAll{ModeSel};

    % ### Evaluate sensitivities
    ApparatusSelNum=length(ApparatusSel);
    Mode_rad = Mode_Hz*2*pi;
    for ApparatusCount = 1:ApparatusSelNum
        ApparatusSelL3 =ApparatusSel(ApparatusCount);
        ZmValOrig = ZmVal{ApparatusSelL3};  
        %ZmValOrig = [ZmVal(ApparatusCount).dd ZmVal(ApparatusCount).dq; ZmVal(ApparatusCount).qd, ZmVal(ApparatusCount).qq];
        if CalcIMR
            Result(ModeSel).ModeResult(ApparatusCount).IM = IMR{ModeSel}.IM(ApparatusSelL3);
            Result(ModeSel).ModeResult(ApparatusCount).IMR = IMR{ModeSel}.IMRVal(ApparatusSelL3);
        end
    
        %perturb the powerflow variables one by one.
        app_pf = ApparatusPowerFlow{ApparatusSelL3};
        num_pf_vars = length(app_pf);
        pf_names = ['P', 'Q', 'V', "xi", 'w'];
        for k=1:num_pf_vars
            
            pf_new = app_pf;
            PfSel = app_pf(k);
    
            delta_pf = eps_*(1+abs(PfSel));
            PfPerturb = PfSel + delta_pf; % add perturabation
    
            pf_new(k) = PfPerturb;
            [~,GmDSS_Cell_New,~,~,~,~,~,~,~] ...
            = SimplusGT.Toolbox.ApparatusModelCreate(ApparatusBus{ApparatusSelL3},ApparatusType{ApparatusSelL3},...
                                pf_new,Para{ApparatusSelL3},Ts,ListBus);  % Create a new model with new power flow solution values?
            
            %ZmValNew_ = SimplusGT.Modal.ApparatusImpedanceCal(GmDSS_Cell_New, Mode_rad);
            %ZmValNew = [ZmValNew_.dd ZmValNew_.dq; ZmValNew_.qd, ZmValNew_.qq];

            ZmValNew_ = SimplusGT.Modal.ApparatusImpedanceCal(GmDSS_Cell_New, Mode_rad, ApparatusType{ApparatusSelL3});
            ZmValNew = ZmValNew_;

            Result(ModeSel).ModeResult(ApparatusCount).PfResult(k).PfName = pf_names(k);
    
            Result(ModeSel).ModeResult(ApparatusCount).PfResult(k).Z_mag = norm(ZmValOrig,"fro");
            Result(ModeSel).ModeResult(ApparatusCount).PfResult(k).Z_mag_new = norm(ZmValNew,"fro");
            if ~isempty(ZmValOrig)
                DeltaZ = (ZmValNew- ZmValOrig)/(delta_pf);
            else
                DeltaZ = zeros(2,2);
            end
            Result(ModeSel).ModeResult(ApparatusCount).PfResult(k).DeltaZ = DeltaZ;
        end
    end
end

