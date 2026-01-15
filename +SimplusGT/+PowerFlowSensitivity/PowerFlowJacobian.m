% Calculate Newton-Raphson Jacobian
% Portions from '+PowerFlow/PowerFlowNR.m'
%
% Author(s): Trager Joswig-Jones

function J = PowerFlowJacobian(ListBus,ListLine,ListPowerFlow, V0, del0, w0)

% Sbase = 1;               	% Base, which is set to 1 currently
% [Pi,Qi] = SimplusGT.PowerFlow.LoadFlow(nbus,V,del,Sbase,Y,ListLine,ListBus);              % Calling Loadflow.m..
% 
% for i = 1:nbus
%     PowerFlow{i} = [-Pi(i) -Qi(i) V(i) del(i) w0];
% end

Y = SimplusGT.PowerFlow.YbusCalc(ListLine); 	% Calling ybusppg.m to get Y-Bus Matrix..
busd = ListBus;      	% Calling busdatas..

bus = busd(:,1);      	% Bus Number..
nbus = length(bus);   	% Number of buses

type = busd(:,2);      	% Type of Bus 1-Slack, 2-PV, 3-PQ..
V = V0; %busd(:,3);        	% Specified Voltage..
del = del0; %busd(:,4);     	% Voltage Angle..
Pg = busd(:,5);     	% PGi..
Qg = busd(:,6);     	% QGi..
Pl = busd(:,7);         % PLi..
Ql = busd(:,8);         % QLi..
Qmin = busd(:,9);       % Minimum Reactive Power Limit..
Qmax = busd(:,10);      % Maximum Reactive Power Limit..

%P = Pg - Pl;         	% Pi = PGi - PLi..
%Q = Qg - Ql;          	% Qi = QGi - QLi..
%Psp = P;              	% P Specified..
%Qsp = Q;             	% Q Specified..
G = real(Y);          	% Conductance matrix..
B = imag(Y);         	% Susceptance matrix..

P = ListPowerFlow(:, 2);
Q = ListPowerFlow(:, 3);
V = ListPowerFlow(:, 4);
xi = ListPowerFlow(:, 5);
w = ListPowerFlow(:, 6);

pv = find(type == 2 | type == 1);   % PV Buses..
pq = find(type == 3);               % PQ Buses..
npv = length(pv);                   % No. of PV buses..
npq = length(pq);                   % No. of PQ buses..

% Jacobian
% J1 - Derivative of Real Power Injections with Angles..
J1 = zeros(nbus-1,nbus-1);
for i = 1:(nbus-1)
    m = i+1;
    for k = 1:(nbus-1)
        n = k+1;
        if n == m
            for n = 1:nbus
                J1(i,k) = J1(i,k) + V(m)* V(n)*(-G(m,n)*sin(del(m)-del(n)) + B(m,n)*cos(del(m)-del(n)));
            end
            J1(i,k) = J1(i,k) - V(m)^2*B(m,m);
        else
            J1(i,k) = V(m)* V(n)*(G(m,n)*sin(del(m)-del(n)) - B(m,n)*cos(del(m)-del(n)));
        end
    end
end

% J2 - Derivative of Real Power Injections with V..
J2 = zeros(nbus-1,npq);
for i = 1:(nbus-1)
    m = i+1;
    for k = 1:npq
        n = pq(k);
        if n == m
            for n = 1:nbus
                J2(i,k) = J2(i,k) + V(n)*(G(m,n)*cos(del(m)-del(n)) + B(m,n)*sin(del(m)-del(n)));
            end
            J2(i,k) = J2(i,k) + V(m)*G(m,m);
        else
            J2(i,k) = V(m)*(G(m,n)*cos(del(m)-del(n)) + B(m,n)*sin(del(m)-del(n)));
        end
    end
end

% J3 - Derivative of Reactive Power Injections with Angles..
J3 = zeros(npq,nbus-1);
for i = 1:npq
    m = pq(i);
    for k = 1:(nbus-1)
        n = k+1;
        if n == m
            for n = 1:nbus
                J3(i,k) = J3(i,k) + V(m)* V(n)*(G(m,n)*cos(del(m)-del(n)) + B(m,n)*sin(del(m)-del(n)));
            end
            J3(i,k) = J3(i,k) - V(m)^2*G(m,m);
        else
            J3(i,k) = V(m)* V(n)*(-G(m,n)*cos(del(m)-del(n)) - B(m,n)*sin(del(m)-del(n)));
        end
    end
end

% J4 - Derivative of Reactive Power Injections with V..
J4 = zeros(npq,npq);
for i = 1:npq
    m = pq(i);
    for k = 1:npq
        n = pq(k);
        if n == m
            for n = 1:nbus
                J4(i,k) = J4(i,k) + V(n)*(G(m,n)*sin(del(m)-del(n)) - B(m,n)*cos(del(m)-del(n)));
            end
            J4(i,k) = J4(i,k) - V(m)*B(m,m);
        else
            J4(i,k) = V(m)*(G(m,n)*sin(del(m)-del(n)) - B(m,n)*cos(del(m)-del(n)));
        end
    end
end

J = [J1 J2; J3 J4];     % Jacobian Matrix..
end