function run_tests()
%RUN_TESTS Regression and consistency tests of the benchmark implementation.
%   Checks the design-day controllers against the reference values of the benchmark, checks
%   that the solvers reproduce reference Monte Carlo and CVaR trials, and checks the band
%   invariance of the energy cost (Proposition 1) on random schedules.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'));
P = bess_parameters();
D = design_day();
z = zeros(P.N, 1);

M0 = evaluate_schedule(z, z, D.net, D.tar, P);
[c1, d1] = schedule_rule(D, P);
M1 = evaluate_schedule(c1, d1, D.net, D.tar, P);
[c2, d2] = schedule_deterministic(D.net, D.tar, P);
M2 = evaluate_schedule(c2, d2, D.net, D.tar, P);
check(M0.energy, 13436.8379734705, 1e-6, 'B0 energy');
check(M0.peak, 932.28709325456, 1e-6, 'B0 peak');
check(M0.cost, 5865.86019908425, 1e-6, 'B0 cost');
check(M1.peak, 892.511083815051, 1e-6, 'B1 peak');
check(M1.cost, 5798.74862013688, 1e-6, 'B1 cost');
check(M2.peak, 779.886739684189, 1e-6, 'B2 peak');
check(M2.cost, 5776.88651487372, 1e-6, 'B2 cost');
check(M2.throughput, 700.921052631579, 1e-6, 'B2 throughput');

% Reference Monte Carlo trials: global Mersenne Twister seed 1503, sequential draws, 5% error.
rng(1503, 'twister');
ref = [15.562057596404 15.8026747386988];
for q = 1:2
    Z = forecast_noise(RandStream.getGlobalStream, P.N);
    [Lf, PVf, EVf] = perturb_profiles(D, Z, 0.05, "Compound");
    [c, d] = schedule_deterministic(Lf + EVf - PVf, D.tar, P);
    M = evaluate_schedule(c, d, D.net, D.tar, P);
    check(M.peakRed, ref(q), 1e-9, sprintf('reference Monte Carlo trial %d', q));
end

% Reference scenario trial: seed 717001, 20 scenarios and one realization, 20% error.
stream = RandStream('mt19937ar', 'Seed', 717001);
Zs = zeros(P.N, 3, 21);
for s = 1:21
    Zs(:, :, s) = forecast_noise(stream, P.N);
end
[netS, netR, netMean] = scenario_set(D, Zs, 0.20);
[c, d] = schedule_deterministic(netMean, D.tar, P);
M = evaluate_schedule(c, d, netR, D.tar, P);
check(M.peakRed, 12.1193627743594, 1e-9, 'reference expected-value trial');
[c, d] = schedule_cvar(netS, D.tar, P, 0.9, 4);
M = evaluate_schedule(c, d, netR, D.tar, P);
check(M.peakRed, 9.55418285801433, 1e-9, 'reference CVaR trial');

% Proposition 1: cost reduction depends only on band-level energies when nothing is curtailed.
stream = RandStream('mt19937ar', 'Seed', 7);
for r = 1:20
    ch = 100*rand(stream, P.N, 1);
    dis = 100*rand(stream, P.N, 1);
    netA = D.net + 50*randn(stream, P.N, 1);
    MA = evaluate_schedule(ch, dis, netA, D.tar, P);
    pred = sum(D.tar.*(dis - ch))*P.dt;
    check(MA.costB0 - MA.cost, pred, 1e-6, 'band invariance');
end
fprintf('All tests passed.\n');
end

function check(value, expected, tol, name)
if abs(value - expected) > tol
    error('run_tests:fail', '%s: %.12g differs from %.12g', name, value, expected);
end
end
