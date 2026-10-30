function [Pch, Pdis, info] = schedule_cvar(netS, tar, P, alpha, lambda)
%SCHEDULE_CVAR Scenario-based day-ahead linear program with a CVaR term on scenario peaks.
%   [Pch, Pdis, info] = SCHEDULE_CVAR(netS, tar, P, alpha, lambda) chooses one battery schedule
%   for all columns of the scenario matrix netS (N x S). The objective is the expected energy
%   cost, plus P.peakWeight times the expected scenario peak, plus lambda times the CVaR at
%   level alpha of the scenario peaks, plus P.cycleWeight times battery throughput. With
%   lambda = 0 the schedule is the risk-neutral stochastic program. With alpha >= 1 - 1/S the
%   CVaR equals the largest scenario peak. The CVaR uses the Rockafellar-Uryasev
%   representation with auxiliary variables eta and u. Decision vector: charging power (N),
%   discharging power (N), scenario peaks (S), eta (1), u (S).

persistent key A Aeq lb ub opts
[N, S] = size(netS);
newKey = [N S P.dt P.E P.Pmax P.s0 P.smin P.smax P.etaC P.etaD P.peakCap];
if isempty(key) || ~isequal(key, newKey)
    [A, Aeq, lb, ub] = build(N, S, P);
    opts = optimoptions('linprog', 'Display', 'none', 'Algorithm', 'dual-simplex-highs');
    key = newKey;
end
f = [P.dt*tar(:) + P.cycleWeight*P.dt; -P.dt*tar(:) + P.cycleWeight*P.dt; ...
    repmat(P.peakWeight/S, S, 1); lambda; repmat(lambda/((1 - alpha)*S), S, 1)];
bs = zeros(2*N + 1, S);
bs(1:2:2*N, :) = netS;
bs(2:2:2*N, :) = -netS;
b = [bs(:); repmat([P.smax - P.s0; P.s0 - P.smin], N, 1)];
[x, ~, flag, out] = linprog(f, A, b, Aeq, 0, lb, ub, opts);
if flag <= 0
    error('schedule_cvar:solver', 'Linear program failed: %s', out.message);
end
Pch = x(1:N);
Pdis = x(N + 1:2*N);
peaks = max(netS - (Pdis - Pch), [], 1);
info.scenarioPeaks = peaks;
info.worst = max(peaks);
info.cvar = cvar_upper(peaks, alpha);
info.meanPeak = mean(peaks);
info.exitflag = flag;
end

function [A, Aeq, lb, ub] = build(N, S, P)
nv = 2*N + 2*S + 1;
iEta = 2*N + S + 1;
k = (1:N)';
cC = P.dt*P.etaC/P.E;
cD = -P.dt/(P.etaD*P.E);
I = [];
J = [];
V = [];
for s = 1:S
    base = (s - 1)*(2*N + 1);
    rowEx = base + 2*k - 1;
    rowPk = base + 2*k;
    rowCv = base + 2*N + 1;
    I = [I; rowEx; rowEx; rowPk; rowPk; rowPk; rowCv; rowCv; rowCv]; %#ok<AGROW>
    J = [J; k; N + k; k; N + k; repmat(2*N + s, N, 1); 2*N + s; iEta; iEta + s]; %#ok<AGROW>
    V = [V; -ones(N, 1); ones(N, 1); ones(N, 1); -ones(N, 1); -ones(N, 1); 1; -1; -1]; %#ok<AGROW>
end
base = S*(2*N + 1);
[kk, jj] = find(tril(ones(N)));
rowUp = base + 2*kk - 1;
rowLo = base + 2*kk;
m = numel(jj);
I = [I; rowUp; rowUp; rowLo; rowLo];
J = [J; jj; N + jj; jj; N + jj];
V = [V; repmat(cC, m, 1); repmat(cD, m, 1); repmat(-cC, m, 1); repmat(-cD, m, 1)];
A = sparse(I, J, V, base + 2*N, nv);
Aeq = sparse(ones(1, 2*N), 1:2*N, [repmat(cC, 1, N), repmat(cD, 1, N)], 1, nv);
lb = zeros(nv, 1);
ub = [P.Pmax*ones(2*N, 1); P.peakCap*ones(S, 1); P.peakCap; inf(S, 1)];
end
