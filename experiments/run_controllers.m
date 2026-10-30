function T = run_controllers(trials)
%RUN_CONTROLLERS Scheduling strategies scored on random realized days.
%   T = RUN_CONTROLLERS(trials) draws, for trial q, P.nScenarios + 1 sets of perturbation
%   sequences from seed P.seed.controllers + q: the first P.nScenarios give the planning
%   scenarios and the last gives the realized day (all three sources perturbed). The same
%   sequences are reused at every amplitude in P.levels. Controllers:
%     B1    rule-based schedule acting on the realized net load
%     B2    day-ahead linear program on the scenario-mean (expected-value) forecast
%     SP    risk-neutral stochastic program over the scenarios (lambda = 0)
%     CVaR  stochastic program with CVaR term, alpha = 0.90, lambda = 4
%     WC    stochastic program with alpha = 0.95, lambda = 4; with 20 scenarios the CVaR term
%           equals the largest scenario peak (worst case)
%     RH    receding-horizon re-optimization every interval from the scenario-mean forecast
%     PI    day-ahead linear program on the realized profiles (perfect information)
%   In-sample columns evaluate the schedule on the planning scenarios.

P = bess_parameters();
D = design_day();
S = P.nScenarios;
ctrl = ["B1" "B2" "SP" "CVaR" "WC" "RH" "PI"];
Dr = D;
n = numel(trials)*numel(P.levels)*numel(ctrl);
Controller = strings(n, 1);
Level_pct = zeros(n, 1);
Trial = zeros(n, 1);
cols = zeros(n, 15);
r = 0;
for q = trials(:)'
    stream = RandStream('mt19937ar', 'Seed', P.seed.controllers + q);
    Zs = zeros(P.N, 3, S + 1);
    for s = 1:S + 1
        Zs(:, :, s) = forecast_noise(stream, P.N);
    end
    for e = P.levels
        [netS, netR, netMean] = scenario_set(D, Zs, e/100);
        for c = ctrl
            fallbacks = 0;
            switch c
                case "B1"
                    Dr.net = netR;
                    [ch, dis] = schedule_rule(Dr, P);
                case "B2"
                    [ch, dis] = schedule_deterministic(netMean, D.tar, P);
                case "SP"
                    [ch, dis] = schedule_cvar(netS, D.tar, P, 0.90, 0);
                case "CVaR"
                    [ch, dis] = schedule_cvar(netS, D.tar, P, 0.90, 4);
                case "WC"
                    [ch, dis] = schedule_cvar(netS, D.tar, P, 0.95, 4);
                case "RH"
                    [ch, dis, info] = schedule_mpc(netMean, netR, D.tar, P);
                    fallbacks = info.fallbacks;
                case "PI"
                    [ch, dis] = schedule_deterministic(netR, D.tar, P);
            end
            M = evaluate_schedule(ch, dis, netR, D.tar, P);
            peaks = max(netS - (dis - ch), [], 1);
            r = r + 1;
            Controller(r) = c;
            Level_pct(r) = e;
            Trial(r) = q;
            cols(r, :) = [M.peak, M.peakB0, M.peakRed, M.cost, M.costB0, M.costRed, M.throughput, ...
                M.finalSOC, M.feasible, M.simultaneous, M.curtailed, mean(peaks), max(peaks), ...
                cvar_upper(peaks, 0.90), fallbacks];
        end
    end
end
names = {'Peak_kW', 'PeakB0_kW', 'PeakReduction_pct', 'Cost', 'CostB0', 'CostReduction_pct', ...
    'Throughput_kWh', 'FinalSOC_pct', 'Feasible', 'Simultaneous_kW', 'Curtailed_kWh', ...
    'InSampleMeanPeak_kW', 'InSampleWorstPeak_kW', 'InSampleCVaR90_kW', 'Fallbacks'};
T = [table(Controller, Level_pct, Trial), array2table(cols, 'VariableNames', names)];
end
