function T = run_scenario_count(trials)
%RUN_SCENARIO_COUNT Scenario programs with 10 to 100 planning scenarios at amplitude 20%.
%   T = RUN_SCENARIO_COUNT(trials) draws, for trial q, one realized day followed by 100
%   planning scenarios from seed P.seed.scenarioCount + q, and solves B2 on the scenario-mean
%   forecast, the risk-neutral stochastic program (SP) and the CVaR program (alpha 0.90,
%   lambda 4) with the first S scenarios, S = 10, 20, 50, 100. The scenario sets are nested and
%   every schedule is scored on the same realized day.

P = bess_parameters();
D = design_day();
counts = [10 20 50 100];
ctrl = ["B2" "SP" "CVaR"];
e = 0.20;
n = numel(trials)*numel(counts)*numel(ctrl);
Controller = strings(n, 1);
cols = zeros(n, 9);
r = 0;
for q = trials(:)'
    stream = RandStream('mt19937ar', 'Seed', P.seed.scenarioCount + q);
    Zr = forecast_noise(stream, P.N);
    Zs = zeros(P.N, 3, max(counts));
    for s = 1:max(counts)
        Zs(:, :, s) = forecast_noise(stream, P.N);
    end
    for S = counts
        [netS, netR, netMean] = scenario_set(D, cat(3, Zs(:, :, 1:S), Zr), e);
        for c = ctrl
            switch c
                case "B2"
                    [ch, dis] = schedule_deterministic(netMean, D.tar, P);
                case "SP"
                    [ch, dis] = schedule_cvar(netS, D.tar, P, 0.90, 0);
                case "CVaR"
                    [ch, dis] = schedule_cvar(netS, D.tar, P, 0.90, 4);
            end
            M = evaluate_schedule(ch, dis, netR, D.tar, P);
            peaks = max(netS - (dis - ch), [], 1);
            r = r + 1;
            Controller(r) = c;
            cols(r, :) = [S, q, M.peak, M.peakB0, M.peakRed, M.costRed, M.feasible, mean(peaks), cvar_upper(peaks, 0.90)];
        end
    end
end
T = [table(Controller), array2table(cols, 'VariableNames', {'Scenarios', 'Trial', 'Peak_kW', 'PeakB0_kW', ...
    'PeakReduction_pct', 'CostReduction_pct', 'Feasible', 'InSampleMeanPeak_kW', 'InSampleCVaR90_kW'})];
end
