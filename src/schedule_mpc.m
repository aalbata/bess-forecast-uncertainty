function [Pch, Pdis, info] = schedule_mpc(netF, netR, tar, P)
%SCHEDULE_MPC Receding-horizon re-optimization with forecast-error persistence (controller RH).
%   [Pch, Pdis, info] = SCHEDULE_MPC(netF, netR, tar, P) re-optimizes the schedule every
%   P.mpcStep intervals over the rest of the day from the current state of charge. Before each
%   solve the net-load forecast netF of interval j is corrected by the most recent observed
%   error netR - netF multiplied by rho(h) = max(0, 1 - h/w), with w = P.mpcRhoWindow, the
%   autocorrelation at lag h of a w-interval moving-average error, where h counts intervals
%   from the last observation (w = 0 disables the correction). Each solve minimizes energy
%   cost, plus P.peakWeight times the daily peak (bounded below by the largest import already
%   realized), plus P.mpcTailWeight times the peak of the remaining horizon, plus
%   P.cycleWeight times throughput, under the constraints of SCHEDULE_DETERMINISTIC.
%   info.fallbacks counts solves that failed and kept the previous plan.

N = numel(netF);
Pch = zeros(N, 1);
Pdis = zeros(N, 1);
planCh = zeros(N, 1);
planDis = zeros(N, 1);
s = P.s0;
peakSoFar = 0;
fallbacks = 0;
for k0 = 1:P.mpcStep:N
    idx = (k0:N)';
    H = numel(idx);
    fc = netF(idx);
    if k0 > 1 && P.mpcRhoWindow > 0
        err = netR(k0 - 1) - netF(k0 - 1);
        fc = fc + err*max(0, 1 - (1:H)'/P.mpcRhoWindow);
    end
    [ch, dis, ok] = horizon_lp(fc, tar(idx), s, peakSoFar, P);
    if ok
        planCh(idx) = ch;
        planDis(idx) = dis;
    elseif k0 == 1
        error('schedule_mpc:solver', 'Initial linear program failed.');
    else
        fallbacks = fallbacks + 1;
    end
    for j = idx(1:min(P.mpcStep, H))'
        Pch(j) = planCh(j);
        Pdis(j) = planDis(j);
        s = s + P.dt/P.E*(P.etaC*Pch(j) - Pdis(j)/P.etaD);
        peakSoFar = max(peakSoFar, max(netR(j) - (Pdis(j) - Pch(j)), 0));
    end
end
info.fallbacks = fallbacks;
end

function [ch, dis, ok] = horizon_lp(fc, tar, s, peakSoFar, P)
% Decision vector: charging power (H), discharging power (H), daily peak, horizon peak.
persistent key cache opts
newKey = [P.N P.dt P.E P.Pmax P.s0 P.smin P.smax P.etaC P.etaD P.peakCap];
if isempty(key) || ~isequal(key, newKey)
    cache = cell(P.N, 1);
    opts = optimoptions('linprog', 'Display', 'none', 'Algorithm', 'dual-simplex-highs');
    key = newKey;
end
H = numel(fc);
if isempty(cache{H})
    cache{H} = build(H, P);
end
M = cache{H};
f = [P.dt*tar(:) + P.cycleWeight*P.dt; -P.dt*tar(:) + P.cycleWeight*P.dt; P.peakWeight; P.mpcTailWeight];
b = [-fc(:); fc(:); 0; repmat([P.smax - s; s - P.smin], H, 1)];
lb = [zeros(2*H, 1); peakSoFar; 0];
ub = [P.Pmax*ones(2*H, 1); max(P.peakCap, peakSoFar); P.peakCap];
[x, ~, flag] = linprog(f, M.A, b, M.Aeq, P.s0 - s, lb, ub, opts);
ok = flag > 0;
if ok
    ch = x(1:H);
    dis = x(H + 1:2*H);
else
    ch = [];
    dis = [];
end
end

function M = build(H, P)
nv = 2*H + 2;
k = (1:H)';
cC = P.dt*P.etaC/P.E;
cD = -P.dt/(P.etaD*P.E);
[kk, jj] = find(tril(ones(H)));
m = numel(jj);
rowUp = 2*H + 1 + 2*kk - 1;
rowLo = 2*H + 1 + 2*kk;
I = [k; k; k; H + k; H + k; 2*H + 1; 2*H + 1; rowUp; rowUp; rowLo; rowLo];
J = [k; H + k; repmat(nv, H, 1); k; H + k; nv; nv - 1; jj; H + jj; jj; H + jj];
V = [ones(H, 1); -ones(H, 1); -ones(H, 1); -ones(H, 1); ones(H, 1); 1; -1; ...
    repmat(cC, m, 1); repmat(cD, m, 1); repmat(-cC, m, 1); repmat(-cD, m, 1)];
M.A = sparse(I, J, V, 4*H + 1, nv);
M.Aeq = sparse(ones(1, 2*H), 1:2*H, [repmat(cC, 1, H), repmat(cD, 1, H)], 1, nv);
end
