function P = bess_parameters()
%BESS_PARAMETERS Battery, tariff, scheduling and experiment parameters of the benchmark.
%   P = BESS_PARAMETERS() returns a structure used by every function in the package.

P.dt = 0.25;              % interval length (h)
P.N = 96;                 % intervals per day
P.E = 500;                % battery energy capacity (kWh)
P.Pmax = 250;             % charge and discharge power limit (kW)
P.s0 = 0.50;              % initial and terminal state of charge
P.smin = 0.20;            % lower state-of-charge limit
P.smax = 0.90;            % upper state-of-charge limit
P.etaC = 0.95;            % charging efficiency
P.etaD = 0.95;            % discharging efficiency
P.peakWeight = 2;         % lambda_p, cost units per kW of daily peak import
P.cycleWeight = 0.002;    % lambda_c, cost units per kWh of battery throughput
P.peakCap = 2000;         % upper bound on peak variables (kW)
P.tariff = [0.30 0.40 0.60];   % off-peak, mid-peak and peak energy prices (cost units/kWh)
P.utcOffset = 4;          % local time minus UTC (h), Gulf Standard Time

P.levels = [5 10 15 20 25 30];             % perturbation amplitudes e (%)
P.sources = ["Load" "PV" "EV" "Compound"];
P.nScenarios = 20;                         % planning scenarios of the scenario-based schedules
P.mpcStep = 1;                             % re-optimization period of the rolling schedule (intervals)
P.mpcRhoWindow = 9;                        % error-persistence window of the rolling schedule (intervals)
P.mpcTailWeight = 2;                       % weight of the remaining-horizon peak in the rolling schedule

P.trials.sourceMagnitude = 1000;           % trials per source and amplitude on the design day
P.trials.controllers = 1000;               % random realized days per amplitude
P.trials.riskSweep = 500;
P.trials.mpcSources = 300;
P.trials.batterySize = 300;
P.trials.demandCharge = 500;
P.trials.weatherYear = 100;                % trials per day, source and amplitude
P.trials.scenarioCount = 300;

P.seed.sourceMagnitude = 1000000;
P.seed.controllers = 2000000;
P.seed.riskSweep = 3000000;
P.seed.weatherYear = 4000000;
P.seed.bootstrap = 5000000;
P.seed.scenarioCount = 6000000;
end
