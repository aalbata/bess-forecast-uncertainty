function [Days, Summary] = run_weather_year(root, days, trials)
%RUN_WEATHER_YEAR Source-specific forecast error on 365 weather-driven days of 2023.
%   [Days, Summary] = RUN_WEATHER_YEAR(root, days, trials) builds each local day of 2023 in
%   Abu Dhabi from PVGIS temperature and irradiance, with the building-load scale of the design
%   day. For every day it solves B2 with exact forecasts and then with load, PV, EV or compound
%   forecast error at amplitudes 10, 20 and 30%. Trial q uses seed P.seed.weatherYear + q on
%   every day. Days holds one row per day; Summary holds per-day statistics over the trials
%   for every source and amplitude.

P = bess_parameters();
W = weather_days(fullfile(root, 'data', 'pvgis_abu_dhabi_2022_2023.json'), 2023);
D0 = design_day();
t = (0:P.N - 1)'*P.dt;
levels = [10 20 30];
Z = cell(numel(trials), 1);
for i = 1:numel(trials)
    Z{i} = forecast_noise(RandStream('mt19937ar', 'Seed', P.seed.weatherYear + trials(i)), P.N);
end
nD = numel(days);
dcols = zeros(nD, 15);
Date = strings(nD, 1);
nR = nD*numel(P.sources)*numel(levels);
sSource = strings(nR, 1);
scols = zeros(nR, 14);
r = 0;
for i = 1:nD
    k = days(i);
    D = district_profiles(t, W.T(:, k), W.G(:, k), D0.loadScale);
    [c, d] = schedule_deterministic(D.net, D.tar, P);
    M = evaluate_schedule(c, d, D.net, D.tar, P);
    [~, kN] = max(D.net);
    Date(i) = string(W.date(k), 'yyyy-MM-dd');
    dcols(i, :) = [k, month(W.date(k)), max(D.T), mean(D.T), sum(D.PV)*P.dt, max(D.L), max(D.net), ...
        D.t(kN), min(D.net), M.peakB0, M.peak, M.peakRed, M.costRed, M.curtailed, M.feasible];
    for s = P.sources
        for e = levels
            pr = zeros(numel(trials), 1);
            cr = pr;
            cu = pr;
            fe = pr;
            for j = 1:numel(trials)
                [Lf, PVf, EVf] = perturb_profiles(D, Z{j}, e/100, s);
                [c, d] = schedule_deterministic(Lf + EVf - PVf, D.tar, P);
                Mq = evaluate_schedule(c, d, D.net, D.tar, P);
                pr(j) = Mq.peakRed;
                cr(j) = Mq.costRed;
                cu(j) = Mq.curtailed;
                fe(j) = Mq.feasible;
            end
            r = r + 1;
            sSource(r) = s;
            scols(r, :) = [k, e, numel(trials), mean(pr), std(pr), min(pr), prctile(pr, 5), ...
                median(pr), prctile(pr, 95), max(pr), mean(cr), std(cr), sum(cu > 1e-9), sum(fe)];
        end
    end
end
Days = [table(Date), array2table(dcols, 'VariableNames', {'Day', 'Month', 'TemperatureMax_C', ...
    'TemperatureMean_C', 'PVEnergy_kWh', 'LoadMax_kW', 'NetMax_kW', 'NetPeakTime_h', 'NetMin_kW', ...
    'PeakB0_kW', 'PeakB2_kW', 'PeakReductionB2_pct', 'CostReductionB2_pct', 'CurtailedB2_kWh', ...
    'FeasibleB2'})];
Days = Days(:, [2 1 3:end]);
Summary = [table(sSource, 'VariableNames', {'Source'}), array2table(scols, 'VariableNames', {'Day', ...
    'Level_pct', 'N', 'MeanPeakReduction_pct', 'SDPeakReduction_pct', 'MinPeakReduction_pct', ...
    'P05PeakReduction_pct', 'MedianPeakReduction_pct', 'P95PeakReduction_pct', ...
    'MaxPeakReduction_pct', 'MeanCostReduction_pct', 'SDCostReduction_pct', 'CurtailedTrials', ...
    'FeasibleTrials'})];
Summary = Summary(:, [2 1 3:end]);
end
