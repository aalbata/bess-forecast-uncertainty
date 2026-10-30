function summarize_results(root, parts)
%SUMMARIZE_RESULTS Summary statistics of every experiment from the trial-level result files.
%   SUMMARIZE_RESULTS(root) reads the CSV files in root/results and writes the summary tables
%   used by the figures and the manuscript to root/results/summary. Confidence intervals of
%   means are Student-t intervals; intervals of tail statistics and of differences in tail
%   statistics are percentile bootstrap intervals with fixed seeds; paired differences use
%   the Wilcoxon signed-rank test. SUMMARIZE_RESULTS(root, parts) summarizes only the listed
%   experiments ("source", "controllers", "risk", "scenarios", "mpc", "battery", "demand", "weather").

if nargin < 2
    parts = ["source" "controllers" "risk" "scenarios" "mpc" "battery" "demand" "weather"];
end
P = bess_parameters();
R = fullfile(root, 'results');
O = fullfile(R, 'summary');
if ~isfolder(O), mkdir(O); end
nominal = readtable(fullfile(R, 'nominal_summary.csv'), 'TextType', 'string');
nomB2 = nominal.PeakReduction_pct(nominal.Controller == "B2");

%% Source-specific error on the design day
if any(parts == "source")
T = readtable(fullfile(R, 'source_magnitude_trials.csv'), 'TextType', 'string');
T.Loss_pp = nomB2 - T.PeakReduction_pct;
C = {};
for s = P.sources
    for e = P.levels
        m = T.Source == s & T.Level_pct == e;
        x = T.PeakReduction_pct(m);
        c = T.CostReduction_pct(m);
        [mx, lo, hi, sd] = mean_ci(x);
        [mc, clo, chi, csd] = mean_ci(c);
        C(end + 1, :) = {s, e, numel(x), mx, sd, lo, hi, median(x), prctile(x, 5), prctile(x, 95), ...
            nomB2 - mx, mc, csd, clo, chi, mean(T.nMAE_Load_pct(m)), mean(T.nMAE_PV_pct(m)), ...
            mean(T.nMAE_EV_pct(m)), mean(T.nMAE_Net_pct(m)), mean(T.Throughput_kWh(m)), ...
            sum(T.Feasible(m)), max(T.Simultaneous_kW(m)), max(T.Curtailed_kWh(m)), ...
            sum(c < max(c) - 1e-9)}; %#ok<AGROW>
    end
end
write(C, {'Source', 'Level_pct', 'N', 'MeanPeakReduction_pct', 'SDPeakReduction_pct', 'CI95Low', ...
    'CI95High', 'MedianPeakReduction_pct', 'P05PeakReduction_pct', 'P95PeakReduction_pct', 'MeanLoss_pp', ...
    'MeanCostReduction_pct', 'SDCostReduction_pct', 'CostCI95Low', 'CostCI95High', 'MeanNMAELoad_pct', ...
    'MeanNMAEPV_pct', 'MeanNMAEEV_pct', 'MeanNMAENet_pct', 'MeanThroughput_kWh', 'FeasibleTrials', ...
    'MaxSimultaneous_kW', 'MaxCurtailed_kWh', 'TrialsBelowMaxCostReduction'}, fullfile(O, 'source_magnitude_summary.csv'));

pairs = ["Compound" "Load"; "Load" "EV"; "Load" "PV"; "EV" "PV"];
C = {};
for e = P.levels
    for p = 1:size(pairs, 1)
        a = sortrows(T(T.Source == pairs(p, 1) & T.Level_pct == e, :), 'Trial');
        b = sortrows(T(T.Source == pairs(p, 2) & T.Level_pct == e, :), 'Trial');
        d = a.PeakReduction_pct - b.PeakReduction_pct;
        [md, lo, hi] = mean_ci(d);
        C(end + 1, :) = {pairs(p, 1), pairs(p, 2), e, numel(d), md, lo, hi, signrank(d), sum(d < 0)}; %#ok<AGROW>
    end
end
write(C, {'SourceA', 'SourceB', 'Level_pct', 'N', 'MeanDifference_pp', 'CI95Low', 'CI95High', ...
    'WilcoxonP', 'TrialsAWorse'}, fullfile(O, 'source_paired.csv'));

C = {};
nmaeCol = containers.Map({'Load', 'PV', 'EV', 'Compound'}, {'nMAE_Load_pct', 'nMAE_PV_pct', 'nMAE_EV_pct', 'nMAE_Net_pct'});
for s = P.sources
    m = T.Source == s;
    x = T.(nmaeCol(char(s)))(m);
    y = T.Loss_pp(m);
    [b, bint, ~, ~, st] = regress(y, [ones(numel(x), 1) x]);
    rhoErr = corr(y, abs(T.ErrorAtB0Peak_kW(m)), 'Type', 'Spearman');
    rhoTime = corr(y, abs(T.ForecastPeakTime_h(m) - 19), 'Type', 'Spearman');
    C(end + 1, :) = {s, sum(m), b(2), bint(2, 1), bint(2, 2), b(1), st(1), rhoErr, rhoTime, ...
        mean(T.(nmaeCol(char(s)))(m)./T.Level_pct(m))}; %#ok<AGROW>
end
write(C, {'Source', 'N', 'SlopeLossPerNMAE', 'SlopeCI95Low', 'SlopeCI95High', 'Intercept_pp', 'R2', ...
    'SpearmanLossVsAbsErrorAtPeak', 'SpearmanLossVsForecastPeakTimeError', 'NMAEPerUnitAmplitude'}, ...
    fullfile(O, 'source_sensitivity.csv'));

Dd = design_day();
gPI = nominal.Peak_kW(nominal.Controller == "B2");
supErr = zeros(height(T), 1);
for q = unique(T.Trial)'
    Z = forecast_noise(RandStream('mt19937ar', 'Seed', P.seed.sourceMagnitude + q), P.N);
    for i = find(T.Trial == q)'
        [Lf, PVf, EVf] = perturb_profiles(Dd, Z, T.Level_pct(i)/100, T.Source(i));
        supErr(i) = max(abs(Lf + EVf - PVf - Dd.net));
    end
end
neg = find(T.PeakReduction_pct < 0);
chargeAtPeak = false(numel(neg), 1);
for j = 1:numel(neg)
    i = neg(j);
    Z = forecast_noise(RandStream('mt19937ar', 'Seed', P.seed.sourceMagnitude + T.Trial(i)), P.N);
    [Lf, PVf, EVf] = perturb_profiles(Dd, Z, T.Level_pct(i)/100, T.Source(i));
    [c, d] = schedule_deterministic(Lf + EVf - PVf, Dd.tar, P);
    Mn = evaluate_schedule(c, d, Dd.net, Dd.tar, P);
    chargeAtPeak(j) = c(Mn.peakIndex) > 1e-6;
end
C = {};
for s = P.sources
    for e = P.levels
        m = T.Source(neg) == s & T.Level_pct(neg) == e;
        C(end + 1, :) = {s, e, sum(T.Source == s & T.Level_pct == e), sum(m), sum(chargeAtPeak(m))}; %#ok<AGROW>
    end
end
write(C, {'Source', 'Level_pct', 'N', 'TrialsPeakAboveB0', 'TrialsChargingAtRealisedPeak'}, ...
    fullfile(O, 'peak_above_b0.csv'));
excess = T.Peak_kW - gPI;
C = {};
for s = [P.sources "All"]
    m = T.Source == s | s == "All";
    C(end + 1, :) = {s, sum(m), sum(excess(m) <= 2*supErr(m) + 1e-6), 100*mean(excess(m) <= 2*supErr(m) + 1e-6), ...
        sum(excess(m) <= supErr(m) + 1e-6), mean(supErr(m)), mean(excess(m)), max(excess(m)./(2*supErr(m)))}; %#ok<AGROW>
end
write(C, {'Source', 'N', 'TrialsWithinBound', 'ShareWithinBound_pct', 'TrialsWithinHalfBound', ...
    'MeanSupNormError_kW', 'MeanPeakExcessOverPI_kW', 'MaxExcessOverBound'}, fullfile(O, 'peak_bound.csv'));

c20 = T(T.Source == "Compound", :);
[b, bint, ~, ~, st] = regress(c20.PeakReduction_pct, [ones(height(c20), 1) c20.Level_pct]);
[bc, bcint, ~, ~, stc] = regress(c20.CostReduction_pct, [ones(height(c20), 1) c20.Level_pct]);
x5 = c20.PeakReduction_pct(c20.Level_pct == 5);
x20 = c20.PeakReduction_pct(c20.Level_pct == 20);
y5 = c20.CostReduction_pct(c20.Level_pct == 5);
y20 = c20.CostReduction_pct(c20.Level_pct == 20);
write({b(2), bint(2, 1), bint(2, 2), st(1), bc(2), bcint(2, 1), bcint(2, 2), stc(1), ...
    (mean(x5) - mean(x20))/std(x5 - x20), (mean(y5) - mean(y20))/std(y5 - y20)}, ...
    {'PeakSlope_ppPerPct', 'PeakSlopeCI95Low', 'PeakSlopeCI95High', 'PeakR2', 'CostSlope_ppPerPct', ...
    'CostSlopeCI95Low', 'CostSlopeCI95High', 'CostR2', 'PairedEffectPeak5vs20', 'PairedEffectCost5vs20'}, ...
    fullfile(O, 'compound_trend.csv'));

end

%% Controllers on random realized days
if any(parts == "controllers")
seed = P.seed.bootstrap + 1000;
T = readtable(fullfile(R, 'controllers_trials.csv'), 'TextType', 'string');
ctrl = ["B1" "B2" "SP" "CVaR" "WC" "RH" "PI"];
C = {};
D = {};
for e = P.levels
    base = sortrows(T(T.Controller == "B2" & T.Level_pct == e, :), 'Trial');
    perfect = sortrows(T(T.Controller == "PI" & T.Level_pct == e, :), 'Trial');
    for c = ctrl
        A = sortrows(T(T.Controller == c & T.Level_pct == e, :), 'Trial');
        [mx, lo, hi, sd] = mean_ci(A.PeakReduction_pct);
        [mc, clo, chi] = mean_ci(A.CostReduction_pct);
        seed = seed + 1;
        [tlo, thi] = bootstrap_ci(@(x) cvar_upper(x, 0.90), seed, A.Peak_kW);
        C(end + 1, :) = {c, e, height(A), mx, sd, lo, hi, mc, clo, chi, mean(A.Throughput_kWh), ...
            sum(A.Feasible), prctile(A.Peak_kW, 95), cvar_upper(A.Peak_kW, 0.90), tlo, thi, ...
            mean(A.InSampleWorstPeak_kW), mean(A.InSampleCVaR90_kW), mean(perfect.PeakReduction_pct - A.PeakReduction_pct), ...
            sum(A.Fallbacks), max(A.Simultaneous_kW), max(A.Curtailed_kWh)}; %#ok<AGROW>
        if c ~= "B2"
            d = A.PeakReduction_pct - base.PeakReduction_pct;
            [md, dlo, dhi] = mean_ci(d);
            seed = seed + 1;
            [qlo, qhi] = bootstrap_ci(@(x, y) cvar_upper(x, 0.90) - cvar_upper(y, 0.90), seed, A.Peak_kW, base.Peak_kW);
            D(end + 1, :) = {c, e, numel(d), md, dlo, dhi, signrank(d), sum(d > 0), ...
                cvar_upper(A.Peak_kW, 0.90) - cvar_upper(base.Peak_kW, 0.90), qlo, qhi}; %#ok<AGROW>
        end
    end
end
write(C, {'Controller', 'Level_pct', 'N', 'MeanPeakReduction_pct', 'SDPeakReduction_pct', 'CI95Low', ...
    'CI95High', 'MeanCostReduction_pct', 'CostCI95Low', 'CostCI95High', 'MeanThroughput_kWh', ...
    'FeasibleTrials', 'P95Peak_kW', 'CVaR90Peak_kW', 'CVaR90CI95Low', 'CVaR90CI95High', ...
    'MeanInSampleWorstPeak_kW', 'MeanInSampleCVaR90_kW', 'MeanRegretVsPI_pp', 'Fallbacks', ...
    'MaxSimultaneous_kW', 'MaxCurtailed_kWh'}, fullfile(O, 'controllers_summary.csv'));
write(D, {'Controller', 'Level_pct', 'N', 'MeanDifferenceVsB2_pp', 'CI95Low', 'CI95High', 'WilcoxonP', ...
    'TrialsBetterThanB2', 'CVaR90PeakDifference_kW', 'CVaR90DiffCI95Low', 'CVaR90DiffCI95High'}, ...
    fullfile(O, 'controllers_paired.csv'));

end

%% Risk sweep
if any(parts == "risk")
seed = P.seed.bootstrap + 2000;
T = readtable(fullfile(R, 'risk_sweep_trials.csv'));
C = {};
alphas = unique(T.Alpha)';
lambdas = unique(T.Lambda)';
for a = alphas
    base = sortrows(T(T.Alpha == a & T.Lambda == 0, :), 'Trial');
    for lam = lambdas
        A = sortrows(T(T.Alpha == a & T.Lambda == lam, :), 'Trial');
        [mx, lo, hi] = mean_ci(A.PeakReduction_pct);
        d = A.PeakReduction_pct - base.PeakReduction_pct;
        [md, dlo, dhi] = mean_ci(d);
        seed = seed + 1;
        [qlo, qhi] = bootstrap_ci(@(x, y) cvar_upper(x, 0.90) - cvar_upper(y, 0.90), seed, A.Peak_kW, base.Peak_kW);
        C(end + 1, :) = {a, lam, height(A), mx, lo, hi, mean(A.CostReduction_pct), mean(A.Throughput_kWh), ...
            mean(A.InSampleMeanPeak_kW), mean(A.InSampleWorstPeak_kW), mean(A.InSampleCVaRAlpha_kW), ...
            mean(A.InSampleCVaR90_kW), cvar_upper(A.Peak_kW, 0.90), prctile(A.Peak_kW, 95), md, dlo, dhi, ...
            cvar_upper(A.Peak_kW, 0.90) - cvar_upper(base.Peak_kW, 0.90), qlo, qhi, sum(A.Feasible)}; %#ok<AGROW>
    end
end
write(C, {'Alpha', 'Lambda', 'N', 'MeanPeakReduction_pct', 'CI95Low', 'CI95High', 'MeanCostReduction_pct', ...
    'MeanThroughput_kWh', 'MeanInSampleMeanPeak_kW', 'MeanInSampleWorstPeak_kW', 'MeanInSampleCVaRAlpha_kW', ...
    'MeanInSampleCVaR90_kW', 'OutOfSampleCVaR90Peak_kW', 'OutOfSampleP95Peak_kW', 'MeanDifferenceVsLambda0_pp', ...
    'DiffCI95Low', 'DiffCI95High', 'CVaR90DifferenceVsLambda0_kW', 'CVaR90DiffCI95Low', 'CVaR90DiffCI95High', ...
    'FeasibleTrials'}, fullfile(O, 'risk_sweep_summary.csv'));

end

%% Number of planning scenarios
if any(parts == "scenarios")
seed = P.seed.bootstrap + 3000;
T = readtable(fullfile(R, 'scenario_count_trials.csv'), 'TextType', 'string');
C = {};
for S = unique(T.Scenarios)'
    base = sortrows(T(T.Controller == "B2" & T.Scenarios == S, :), 'Trial');
    for c = ["B2" "SP" "CVaR"]
        A = sortrows(T(T.Controller == c & T.Scenarios == S, :), 'Trial');
        [mx, lo, hi] = mean_ci(A.PeakReduction_pct);
        [md, dlo, dhi] = mean_ci(A.PeakReduction_pct - base.PeakReduction_pct);
        seed = seed + 1;
        [qlo, qhi] = bootstrap_ci(@(x, y) cvar_upper(x, 0.90) - cvar_upper(y, 0.90), seed, A.Peak_kW, base.Peak_kW);
        C(end + 1, :) = {c, S, height(A), mx, lo, hi, mean(A.InSampleCVaR90_kW), cvar_upper(A.Peak_kW, 0.90), ...
            md, dlo, dhi, cvar_upper(A.Peak_kW, 0.90) - cvar_upper(base.Peak_kW, 0.90), qlo, qhi, sum(A.Feasible)}; %#ok<AGROW>
    end
end
write(C, {'Controller', 'Scenarios', 'N', 'MeanPeakReduction_pct', 'CI95Low', 'CI95High', ...
    'MeanInSampleCVaR90_kW', 'OutOfSampleCVaR90Peak_kW', 'MeanDifferenceVsB2_pp', 'DiffCI95Low', 'DiffCI95High', ...
    'CVaR90DifferenceVsB2_kW', 'CVaR90DiffCI95Low', 'CVaR90DiffCI95High', 'FeasibleTrials'}, ...
    fullfile(O, 'scenario_count_summary.csv'));

end

%% Receding horizon under source-specific error, paired with the day-ahead schedule
if any(parts == "mpc")
T = readtable(fullfile(R, 'mpc_sources_trials.csv'), 'TextType', 'string');
S = readtable(fullfile(R, 'source_magnitude_trials.csv'), 'TextType', 'string');
C = {};
for s = P.sources
    for e = P.levels
        A = sortrows(T(T.Source == s & T.Level_pct == e, :), 'Trial');
        B = sortrows(S(S.Source == s & S.Level_pct == e & ismember(S.Trial, A.Trial), :), 'Trial');
        [mx, lo, hi] = mean_ci(A.PeakReduction_pct);
        d = A.PeakReduction_pct - B.PeakReduction_pct;
        [md, dlo, dhi] = mean_ci(d);
        C(end + 1, :) = {s, e, height(A), mean(B.PeakReduction_pct), mx, lo, hi, md, dlo, dhi, ...
            signrank(d), sum(d > 1e-9), (mx - mean(B.PeakReduction_pct))/(nomB2 - mean(B.PeakReduction_pct)), ...
            mean(A.CostReduction_pct), sum(A.Feasible), sum(A.Fallbacks)}; %#ok<AGROW>
    end
end
write(C, {'Source', 'Level_pct', 'N', 'MeanDayAhead_pct', 'MeanRH_pct', 'CI95Low', 'CI95High', ...
    'MeanDifference_pp', 'DiffCI95Low', 'DiffCI95High', 'WilcoxonP', 'TrialsRHBetter', ...
    'RecoveredShareOfLoss', 'MeanCostReductionRH_pct', 'FeasibleTrials', 'Fallbacks'}, ...
    fullfile(O, 'mpc_sources_summary.csv'));

end

%% Battery size
if any(parts == "battery")
T = readtable(fullfile(R, 'battery_size_trials.csv'), 'TextType', 'string');
C = {};
for E = unique(T.Energy_kWh)'
    for Pm = unique(T.Power_kW)'
        nom = T(T.Energy_kWh == E & T.Power_kW == Pm & T.Source == "None", :);
        for s = P.sources
            for e = unique(T.Level_pct(T.Level_pct > 0))'
                m = T.Energy_kWh == E & T.Power_kW == Pm & T.Source == s & T.Level_pct == e;
                [mx, lo, hi] = mean_ci(T.PeakReduction_pct(m));
                C(end + 1, :) = {E, Pm, s, e, sum(m), nom.PeakReduction_pct, nom.CostReduction_pct, mx, lo, hi, ...
                    nom.PeakReduction_pct - mx, mean(T.CostReduction_pct(m)), max(T.Curtailed_kWh(m)), sum(T.Feasible(m))}; %#ok<AGROW>
            end
        end
    end
end
write(C, {'Energy_kWh', 'Power_kW', 'Source', 'Level_pct', 'N', 'NominalPeakReduction_pct', ...
    'NominalCostReduction_pct', 'MeanPeakReduction_pct', 'CI95Low', 'CI95High', 'MeanLoss_pp', ...
    'MeanCostReduction_pct', 'MaxCurtailed_kWh', 'FeasibleTrials'}, fullfile(O, 'battery_size_summary.csv'));

end

%% Demand charge
if any(parts == "demand")
T = readtable(fullfile(R, 'demand_charge_trials.csv'));
C = {};
for w = unique(T.DemandCharge)'
    nom = T(T.DemandCharge == w & T.Level_pct == 0, :);
    C(end + 1, :) = {w, 0, 1, nom.BillReduction_pct, NaN, NaN, nom.PeakReduction_pct, nom.CostReduction_pct}; %#ok<AGROW>
    for e = unique(T.Level_pct(T.Level_pct > 0))'
        m = T.DemandCharge == w & T.Level_pct == e;
        [mb, lo, hi] = mean_ci(T.BillReduction_pct(m));
        C(end + 1, :) = {w, e, sum(m), mb, lo, hi, mean(T.PeakReduction_pct(m)), mean(T.CostReduction_pct(m))}; %#ok<AGROW>
    end
end
write(C, {'DemandCharge', 'Level_pct', 'N', 'MeanBillReduction_pct', 'CI95Low', 'CI95High', ...
    'MeanPeakReduction_pct', 'MeanCostReduction_pct'}, fullfile(O, 'demand_charge_summary.csv'));

end

%% Weather year
if any(parts == "weather")
Dy = readtable(fullfile(R, 'weather_year_days.csv'), 'TextType', 'string');
Sy = readtable(fullfile(R, 'weather_year_summary.csv'), 'TextType', 'string');
Sy = join(Sy, Dy(:, {'Day', 'Month', 'PeakReductionB2_pct'}), 'Keys', 'Day');
Sy.MeanLoss_pp = Sy.PeakReductionB2_pct - Sy.MeanPeakReduction_pct;
C = {};
M = {};
K = {};
for e = unique(Sy.Level_pct)'
    L = sortrows(Sy(Sy.Source == "Load" & Sy.Level_pct == e, :), 'Day');
    V = sortrows(Sy(Sy.Source == "PV" & Sy.Level_pct == e, :), 'Day');
    Ev = sortrows(Sy(Sy.Source == "EV" & Sy.Level_pct == e, :), 'Day');
    loss = [L.MeanLoss_pp V.MeanLoss_pp Ev.MeanLoss_pp];
    [~, worst] = max(loss, [], 2);
    K(end + 1, :) = {e, height(L), sum(worst == 1), sum(worst == 2), sum(worst == 3), ...
        sum(L.MeanLoss_pp > V.MeanLoss_pp), sum(L.MeanLoss_pp > Ev.MeanLoss_pp)}; %#ok<AGROW>
    for s = P.sources
        A = sortrows(Sy(Sy.Source == s & Sy.Level_pct == e, :), 'Day');
        [ml, lo, hi, sd] = mean_ci(A.MeanLoss_pp);
        C(end + 1, :) = {s, e, height(A), mean(A.MeanPeakReduction_pct), ml, sd, lo, hi, min(A.MeanLoss_pp), ...
            max(A.MeanLoss_pp), mean(A.MeanCostReduction_pct), sum(A.FeasibleTrials), sum(A.CurtailedTrials)}; %#ok<AGROW>
        for mo = 1:12
            mm = A.Month == mo;
            M(end + 1, :) = {s, e, mo, sum(mm), mean(A.MeanLoss_pp(mm)), mean(A.MeanPeakReduction_pct(mm))}; %#ok<AGROW>
        end
    end
end
write(K, {'Level_pct', 'Days', 'DaysLoadWorst', 'DaysPVWorst', 'DaysEVWorst', 'DaysLoadAbovePV', ...
    'DaysLoadAboveEV'}, fullfile(O, 'weather_year_ranking.csv'));
write(C, {'Source', 'Level_pct', 'Days', 'MeanPeakReduction_pct', 'MeanLoss_pp', 'SDLossAcrossDays_pp', ...
    'CI95Low', 'CI95High', 'MinDayLoss_pp', 'MaxDayLoss_pp', 'MeanCostReduction_pct', 'FeasibleTrials', ...
    'CurtailedTrials'}, fullfile(O, 'weather_year_aggregate.csv'));
write(M, {'Source', 'Level_pct', 'Month', 'Days', 'MeanLoss_pp', 'MeanPeakReduction_pct'}, ...
    fullfile(O, 'weather_year_monthly.csv'));
[mp, plo, phi, psd] = mean_ci(Dy.PeakReductionB2_pct);
[mc, clo, chi, csd] = mean_ci(Dy.CostReductionB2_pct);
write({height(Dy), mp, psd, plo, phi, min(Dy.PeakReductionB2_pct), max(Dy.PeakReductionB2_pct), mc, csd, ...
    clo, chi, min(Dy.CostReductionB2_pct), max(Dy.CostReductionB2_pct), min(Dy.PeakB0_kW), max(Dy.PeakB0_kW), ...
    mean(Dy.PeakB0_kW), sum(Dy.NetPeakTime_h >= 17 & Dy.NetPeakTime_h < 22), min(Dy.NetPeakTime_h), ...
    max(Dy.NetPeakTime_h), sum(Dy.FeasibleB2), sum(Dy.CurtailedB2_kWh > 1e-9), min(Dy.TemperatureMax_C), ...
    max(Dy.TemperatureMax_C), min(Dy.NetMin_kW)}, {'Days', 'MeanPeakReductionB2_pct', 'SDPeakReductionB2_pct', ...
    'CI95Low', 'CI95High', 'MinPeakReductionB2_pct', 'MaxPeakReductionB2_pct', 'MeanCostReductionB2_pct', ...
    'SDCostReductionB2_pct', 'CostCI95Low', 'CostCI95High', 'MinCostReductionB2_pct', 'MaxCostReductionB2_pct', ...
    'MinPeakB0_kW', 'MaxPeakB0_kW', 'MeanPeakB0_kW', 'DaysNetPeakInPeakBand', 'EarliestNetPeakTime_h', ...
    'LatestNetPeakTime_h', 'FeasibleDays', 'DaysWithCurtailment', 'MinDailyMaxTemperature_C', ...
    'MaxDailyMaxTemperature_C', 'MinNetLoad_kW'}, fullfile(O, 'weather_year_nominal.csv'));
end
end

function write(C, names, file)
writetable(cell2table(C, 'VariableNames', names), file);
end
