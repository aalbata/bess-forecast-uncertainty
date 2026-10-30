function T = run_risk_sweep(trials)
%RUN_RISK_SWEEP CVaR confidence level and risk weight swept with common random numbers.
%   T = RUN_RISK_SWEEP(trials) uses amplitude 20% and, for trial q, the scenario set and
%   realized day drawn from seed P.seed.riskSweep + q (as in RUN_CONTROLLERS). Every
%   combination of alpha and lambda is solved on the same scenarios and scored on the same
%   realized day. With lambda = 0 the program does not depend on alpha and is solved once.

P = bess_parameters();
D = design_day();
S = P.nScenarios;
e = 0.20;
alphas = [0.80 0.90 0.95];
lambdas = [0 0.5 1 2 4 8 16];
n = numel(trials)*numel(alphas)*numel(lambdas);
cols = zeros(n, 13);
r = 0;
for q = trials(:)'
    stream = RandStream('mt19937ar', 'Seed', P.seed.riskSweep + q);
    Zs = zeros(P.N, 3, S + 1);
    for s = 1:S + 1
        Zs(:, :, s) = forecast_noise(stream, P.N);
    end
    [netS, netR] = scenario_set(D, Zs, e);
    [ch0, dis0] = schedule_cvar(netS, D.tar, P, 0.90, 0);
    for a = alphas
        for lam = lambdas
            if lam == 0
                ch = ch0; dis = dis0;
            else
                [ch, dis] = schedule_cvar(netS, D.tar, P, a, lam);
            end
            M = evaluate_schedule(ch, dis, netR, D.tar, P);
            peaks = max(netS - (dis - ch), [], 1);
            r = r + 1;
            cols(r, :) = [a, lam, q, M.peak, M.peakB0, M.peakRed, M.costRed, M.throughput, ...
                M.feasible, mean(peaks), max(peaks), cvar_upper(peaks, a), cvar_upper(peaks, 0.90)];
        end
    end
end
T = array2table(cols, 'VariableNames', {'Alpha', 'Lambda', 'Trial', 'Peak_kW', 'PeakB0_kW', ...
    'PeakReduction_pct', 'CostReduction_pct', 'Throughput_kWh', 'Feasible', ...
    'InSampleMeanPeak_kW', 'InSampleWorstPeak_kW', 'InSampleCVaRAlpha_kW', 'InSampleCVaR90_kW'});
end
