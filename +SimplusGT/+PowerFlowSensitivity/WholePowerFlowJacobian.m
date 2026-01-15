%% Calculate the Whole Newton-Raphson Jacobian of the Power Flow Equations.
% Modified from '+PowerFlow/PowerFlowNR.m'
%
% Author(s): Trager Joswig-Jones

function J = WholePowerFlowJacobian(ListBus,ListLine,ListPowerFlow)

Y = SimplusGT.PowerFlow.YbusCalc(ListLine); 	% Calling ybusppg.m to get Y-Bus Matrix..
busd = ListBus;      	% Calling busdatas..

bus = busd(:,1);      	% Bus Number..
nbus = length(bus);   	% Number of buses

type = busd(:,2);      	% Type of Bus 1-Slack, 2-PV, 3-PQ..

G = real(Y);          	% Conductance matrix..
B = imag(Y);         	% Susceptance matrix..

P = ListPowerFlow(:, 2);
Q = ListPowerFlow(:, 3);
V = ListPowerFlow(:, 4);
del = ListPowerFlow(:, 5);
w = ListPowerFlow(:, 6);

pv = find(type == 2 | type == 1);   % PV Buses..
pq = find(type == 3);               % PQ Buses..
npv = length(pv);                   % No. of PV buses..
npq = length(pq);                   % No. of PQ buses..

% Jacobian
% J1 - Derivative of Real Power Injections with Angles..
J1 = zeros(nbus,nbus);
for i = 1:(nbus)
    m = i;
    for k = 1:(nbus)
        n = k;
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
J2 = zeros(nbus,nbus);
for i = 1:(nbus)
    m = i;
    for k = 1:(nbus)
        n = k;
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
J3 = zeros(nbus,nbus);
for i = 1:(nbus)
    m = i;
    for k = 1:(nbus)
        n = k;
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
J4 = zeros(nbus,nbus);
for i = 1:(nbus)
    m = i;
    for k = 1:(nbus)
        n = k;
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