function [Pch, Pdis, info] = schedule_deterministic(netF, tar, P)
%SCHEDULE_DETERMINISTIC Day-ahead linear program on a single net-load forecast (controller B2).
%   [Pch, Pdis, info] = SCHEDULE_DETERMINISTIC(netF, tar, P) minimizes energy cost plus
%   P.peakWeight times the planned peak import plus P.cycleWeight times battery throughput,
%   subject to power, state-of-charge, terminal state-of-charge and no-export constraints.
%   Decision vector: charging power (N), discharging power (N), planned peak (1).

persistent key A Aeq lb ub opts
N = numel(netF);
newKey = [N P.dt P.E P.Pmax P.s0 P.smin P.smax P.etaC P.etaD P.peakCap];
if isempty(key) || ~isequal(key, newKey)
    [A, Aeq, lb, ub] = build(N, P);
    opts = optimoptions('linprog', 'Display', 'none', 'Algorithm', 'dual-simplex-highs');
    key = newKey;
end
f = [P.dt*tar(:) + P.cycleWeight*P.dt; -P.dt*tar(:) + P.cycleWeight*P.dt; P.peakWeight];
b = [-netF(:); netF(:); repmat([P.smax - P.s0; P.s0 - P.smin], N, 1)];
[x, ~, flag, out] = linprog(f, A, b, Aeq, 0, lb, ub, opts);
if flag <= 0
    error('schedule_deterministic:solver', 'Linear program failed: %s', out.message);
end
Pch = x(1:N);
Pdis = x(N + 1:2*N);
info.plannedPeak = x(end);
info.exitflag = flag;
end

function [A, Aeq, lb, ub] = build(N, P)
nv = 2*N + 1;
k = (1:N)';
cC = P.dt*P.etaC/P.E;
cD = -P.dt/(P.etaD*P.E);
% Peak rows: Pch - Pdis - Ppk <= -netF; no-export rows: -Pch + Pdis <= netF.
iPk = [k; k; k];
jPk = [k; N + k; repmat(nv, N, 1)];
vPk = [ones(N, 1); -ones(N, 1); -ones(N, 1)];
iEx = N + [k; k];
jEx = [k; N + k];
vEx = [-ones(N, 1); ones(N, 1)];
% State-of-charge rows, upper and lower limit alternating for each interval.
[kk, jj] = find(tril(ones(N)));
rowUp = 2*N + 2*kk - 1;
rowLo = 2*N + 2*kk;
iSoc = [rowUp; rowUp; rowLo; rowLo];
jSoc = [jj; N + jj; jj; N + jj];
vSoc = [repmat(cC, numel(jj), 1); repmat(cD, numel(jj), 1); repmat(-cC, numel(jj), 1); repmat(-cD, numel(jj), 1)];
A = sparse([iPk; iEx; iSoc], [jPk; jEx; jSoc], [vPk; vEx; vSoc], 4*N, nv);
Aeq = sparse(ones(1, 2*N), 1:2*N, [repmat(cC, 1, N), repmat(cD, 1, N)], 1, nv);
lb = zeros(nv, 1);
ub = [P.Pmax*ones(2*N, 1); P.peakCap];
end
