function T = run_source_magnitude(trials)
%RUN_SOURCE_MAGNITUDE Day-ahead schedule B2 under source-specific forecast error.
%   T = RUN_SOURCE_MAGNITUDE(trials) perturbs the load, PV or EV forecast alone, or all three
%   (Compound), at every amplitude in P.levels, schedules B2 on the forecast and scores the
%   schedule on the design day. Trial q draws one set of perturbation sequences from seed
%   P.seed.sourceMagnitude + q and reuses it for every source and amplitude (common random
%   numbers). nMAE columns are energy-weighted normalized mean absolute errors (%).

P = bess_parameters();
D = design_day();
[~, kPeak] = max(D.net);
nS = numel(P.sources);
nE = numel(P.levels);
n = numel(trials)*nS*nE;
Source = strings(n, 1);
Level_pct = zeros(n, 1);
Trial = zeros(n, 1);
cols = zeros(n, 16);
r = 0;
for q = trials(:)'
    Z = forecast_noise(RandStream('mt19937ar', 'Seed', P.seed.sourceMagnitude + q), P.N);
    for s = P.sources
        for e = P.levels
            [Lf, PVf, EVf] = perturb_profiles(D, Z, e/100, s);
            netF = Lf + EVf - PVf;
            [c, d] = schedule_deterministic(netF, D.tar, P);
            M = evaluate_schedule(c, d, D.net, D.tar, P);
            [~, kF] = max(netF);
            r = r + 1;
            Source(r) = s;
            Level_pct(r) = e;
            Trial(r) = q;
            cols(r, :) = [M.peak, M.peakRed, M.cost, M.costRed, M.throughput, M.finalSOC, M.feasible, ...
                M.simultaneous, M.curtailed, nmae(Lf, D.L), nmae(PVf, D.PV), nmae(EVf, D.EV), ...
                nmae(netF, D.net), netF(kPeak) - D.net(kPeak), D.t(kF), D.t(M.peakIndex)];
        end
    end
end
names = {'Peak_kW', 'PeakReduction_pct', 'Cost', 'CostReduction_pct', 'Throughput_kWh', ...
    'FinalSOC_pct', 'Feasible', 'Simultaneous_kW', 'Curtailed_kWh', 'nMAE_Load_pct', ...
    'nMAE_PV_pct', 'nMAE_EV_pct', 'nMAE_Net_pct', 'ErrorAtB0Peak_kW', 'ForecastPeakTime_h', ...
    'RealisedPeakTime_h'};
T = [table(Source, Level_pct, Trial), array2table(cols, 'VariableNames', names)];
end

function v = nmae(f, x)
v = 100*sum(abs(f - x))/sum(abs(x));
end
