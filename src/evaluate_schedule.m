function M = evaluate_schedule(Pch, Pdis, netR, tar, P)
%EVALUATE_SCHEDULE Realized grid import, cost and battery state of a schedule applied open loop.
%   M = EVALUATE_SCHEDULE(Pch, Pdis, netR, tar, P) applies the planned charging and discharging
%   powers to the realized net load netR. Discharge in excess of the net load is curtailed
%   (no export) and the state of charge follows the planned powers. Peak and cost reductions
%   are relative to operation without storage (B0) on the same realized day.

pb = Pdis(:) - Pch(:);
netR = netR(:);
grid = max(netR - pb, 0);
g0 = max(netR, 0);
soc = P.s0 + [0; cumsum(P.dt/P.E*(P.etaC*Pch(:) - Pdis(:)/P.etaD))];
[M.peak, M.peakIndex] = max(grid);
M.energy = sum(grid)*P.dt;
M.cost = sum(grid.*tar(:))*P.dt;
M.peakB0 = max(g0);
M.costB0 = sum(g0.*tar(:))*P.dt;
M.peakRed = 100*(M.peakB0 - M.peak)/M.peakB0;
M.costRed = 100*(M.costB0 - M.cost)/M.costB0;
M.throughput = sum(abs(pb))*P.dt;
M.finalSOC = 100*soc(end);
M.feasible = all(soc >= P.smin - 1e-8 & soc <= P.smax + 1e-8) && all(abs(pb) <= P.Pmax + 1e-8) ...
    && abs(soc(end) - P.s0) <= 0.01 + 1e-8;
M.simultaneous = max(min(Pch(:), Pdis(:)));
M.curtailed = sum(max(pb - netR, 0))*P.dt;
M.grid = grid;
M.soc = soc;
end
