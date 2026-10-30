function T = run_mpc_sources(trials)
%RUN_MPC_SOURCES Receding-horizon schedule RH under source-specific forecast error.
%   T = RUN_MPC_SOURCES(trials) repeats the design of RUN_SOURCE_MAGNITUDE with the rolling
%   schedule SCHEDULE_MPC in place of the day-ahead schedule. The seeds are those of
%   RUN_SOURCE_MAGNITUDE, so rows with equal source, amplitude and trial are paired.

P = bess_parameters();
D = design_day();
nS = numel(P.sources);
nE = numel(P.levels);
n = numel(trials)*nS*nE;
Source = strings(n, 1);
Level_pct = zeros(n, 1);
Trial = zeros(n, 1);
cols = zeros(n, 7);
r = 0;
for q = trials(:)'
    Z = forecast_noise(RandStream('mt19937ar', 'Seed', P.seed.sourceMagnitude + q), P.N);
    for s = P.sources
        for e = P.levels
            [Lf, PVf, EVf] = perturb_profiles(D, Z, e/100, s);
            [c, d, info] = schedule_mpc(Lf + EVf - PVf, D.net, D.tar, P);
            M = evaluate_schedule(c, d, D.net, D.tar, P);
            r = r + 1;
            Source(r) = s;
            Level_pct(r) = e;
            Trial(r) = q;
            cols(r, :) = [M.peak, M.peakRed, M.costRed, M.throughput, M.finalSOC, M.feasible, info.fallbacks];
        end
    end
end
T = [table(Source, Level_pct, Trial), array2table(cols, 'VariableNames', {'Peak_kW', ...
    'PeakReduction_pct', 'CostReduction_pct', 'Throughput_kWh', 'FinalSOC_pct', 'Feasible', 'Fallbacks'})];
end
