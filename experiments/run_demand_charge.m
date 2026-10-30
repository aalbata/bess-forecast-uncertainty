function T = run_demand_charge(trials)
%RUN_DEMAND_CHARGE Day-ahead schedule B2 when the daily peak carries a demand charge.
%   T = RUN_DEMAND_CHARGE(trials) sets the peak weight of the objective equal to a daily demand
%   charge w (cost units per kW of daily peak import) and scores the bill, energy cost plus
%   w times the realized peak, under compound forecast error with the seeds of
%   RUN_SOURCE_MAGNITUDE. Rows with Level 0 and Trial 0 use exact forecasts.

P = bess_parameters();
D = design_day();
weights = [0.5 1 2 4];
levels = [10 20 30];
n = numel(weights)*(1 + numel(trials)*numel(levels));
cols = zeros(n, 9);
r = 0;
for w = weights
    Q = P;
    Q.peakWeight = w;
    [c, d] = schedule_deterministic(D.net, D.tar, Q);
    M = evaluate_schedule(c, d, D.net, D.tar, Q);
    r = r + 1;
    cols(r, :) = row(w, 0, 0, M);
    for q = trials(:)'
        Z = forecast_noise(RandStream('mt19937ar', 'Seed', P.seed.sourceMagnitude + q), P.N);
        for e = levels
            [Lf, PVf, EVf] = perturb_profiles(D, Z, e/100, "Compound");
            [c, d] = schedule_deterministic(Lf + EVf - PVf, D.tar, Q);
            M = evaluate_schedule(c, d, D.net, D.tar, Q);
            r = r + 1;
            cols(r, :) = row(w, e, q, M);
        end
    end
end
T = array2table(cols, 'VariableNames', {'DemandCharge', 'Level_pct', 'Trial', 'Peak_kW', ...
    'PeakReduction_pct', 'Cost', 'CostReduction_pct', 'Bill', 'BillReduction_pct'});
end

function v = row(w, e, q, M)
bill = M.cost + w*M.peak;
billB0 = M.costB0 + w*M.peakB0;
v = [w, e, q, M.peak, M.peakRed, M.cost, M.costRed, bill, 100*(billB0 - bill)/billB0];
end
