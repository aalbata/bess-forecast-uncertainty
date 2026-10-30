function reproduce(mode)
%REPRODUCE Rebuild the results, summary tables and figures of the study.
%   REPRODUCE or REPRODUCE('fast') runs the tests and rebuilds the summary tables in
%   results/summary and the figures in output/figures from the shipped trial-level results.
%   REPRODUCE('full') also reruns every experiment from the shipped PVGIS data before
%   rebuilding the summaries and figures. REPRODUCE('download') downloads the PVGIS data again
%   and then performs the full run. See README.md for run times.

if nargin < 1
    mode = 'fast';
end
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'src'), fullfile(root, 'experiments'), fullfile(root, 'analysis'), ...
    fullfile(root, 'figures'), fullfile(root, 'tests'), fullfile(root, 'data'));
run_tests();
if any(strcmp(mode, {'full', 'download'}))
    if strcmp(mode, 'download')
        fetch_pvgis(root);
    end
    P = bess_parameters();
    R = fullfile(root, 'results');
    N = run_nominal();
    writetable(N.summary, fullfile(R, 'nominal_summary.csv'));
    writetable(N.profiles, fullfile(R, 'nominal_profiles.csv'));
    writetable(N.soc, fullfile(R, 'nominal_soc.csv'));
    writetable(N.facts, fullfile(R, 'nominal_facts.csv'));
    writetable(run_timing_shift(), fullfile(R, 'timing_shift.csv'));
    writetable(run_source_magnitude(1:P.trials.sourceMagnitude), fullfile(R, 'source_magnitude_trials.csv'));
    writetable(run_controllers(1:P.trials.controllers), fullfile(R, 'controllers_trials.csv'));
    writetable(run_risk_sweep(1:P.trials.riskSweep), fullfile(R, 'risk_sweep_trials.csv'));
    writetable(run_scenario_count(1:P.trials.scenarioCount), fullfile(R, 'scenario_count_trials.csv'));
    writetable(run_mpc_sources(1:P.trials.mpcSources), fullfile(R, 'mpc_sources_trials.csv'));
    writetable(run_battery_size(1:P.trials.batterySize), fullfile(R, 'battery_size_trials.csv'));
    writetable(run_demand_charge(1:P.trials.demandCharge), fullfile(R, 'demand_charge_trials.csv'));
    [days, summary] = run_weather_year(root, 1:365, 1:P.trials.weatherYear);
    writetable(days, fullfile(R, 'weather_year_days.csv'));
    writetable(summary, fullfile(R, 'weather_year_summary.csv'));
elseif ~strcmp(mode, 'fast')
    error('reproduce:mode', 'Mode must be ''fast'', ''full'' or ''download''.');
end
summarize_results(root);
make_figures(root);
fprintf('Summary tables in results/summary, figures in output/figures.\n');
end
