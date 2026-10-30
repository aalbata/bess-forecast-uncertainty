function T = run_battery_size(trials)
%RUN_BATTERY_SIZE Day-ahead schedule B2 for other battery energy and power ratings.
%   T = RUN_BATTERY_SIZE(trials) repeats the source-specific design at amplitudes 10, 20 and
%   30% for every combination of energy capacity and power limit, with the seeds of
%   RUN_SOURCE_MAGNITUDE. Rows with Source "None" and Trial 0 are exact-forecast schedules.

P = bess_parameters();
D = design_day();
energies = [250 500 750 1000];
powers = [125 250 500];
levels = [10 20 30];
Z = cell(numel(trials), 1);
for i = 1:numel(trials)
    Z{i} = forecast_noise(RandStream('mt19937ar', 'Seed', P.seed.sourceMagnitude + trials(i)), P.N);
end
n = numel(energies)*numel(powers)*(1 + numel(trials)*numel(P.sources)*numel(levels));
Source = strings(n, 1);
cols = zeros(n, 10);
r = 0;
for E = energies
    for Pm = powers
        Q = P;
        Q.E = E;
        Q.Pmax = Pm;
        [c, d] = schedule_deterministic(D.net, D.tar, Q);
        M = evaluate_schedule(c, d, D.net, D.tar, Q);
        r = r + 1;
        Source(r) = "None";
        cols(r, :) = [E, Pm, 0, 0, M.peak, M.peakRed, M.costRed, M.throughput, M.curtailed, M.feasible];
        for i = 1:numel(trials)
            for s = P.sources
                for e = levels
                    [Lf, PVf, EVf] = perturb_profiles(D, Z{i}, e/100, s);
                    [c, d] = schedule_deterministic(Lf + EVf - PVf, D.tar, Q);
                    M = evaluate_schedule(c, d, D.net, D.tar, Q);
                    r = r + 1;
                    Source(r) = s;
                    cols(r, :) = [E, Pm, e, trials(i), M.peak, M.peakRed, M.costRed, M.throughput, ...
                        M.curtailed, M.feasible];
                end
            end
        end
    end
end
T = [table(Source), array2table(cols, 'VariableNames', {'Energy_kWh', 'Power_kW', 'Level_pct', ...
    'Trial', 'Peak_kW', 'PeakReduction_pct', 'CostReduction_pct', 'Throughput_kWh', ...
    'Curtailed_kWh', 'Feasible'})];
T = T(:, [2 3 1 4:end]);
end
