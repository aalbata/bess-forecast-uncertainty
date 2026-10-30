function R = run_nominal()
%RUN_NOMINAL Controllers B0, B1 and B2 on the design day with exact forecasts.
%   R.summary: one row per controller. R.profiles: interval data of the design day.
%   R.soc: state of charge at the 97 interval boundaries. R.facts: scalar descriptors,
%   including the pure-arbitrage optimum and its closed-form value.

P = bess_parameters();
D = design_day();
z = zeros(P.N, 1);
M0 = evaluate_schedule(z, z, D.net, D.tar, P);
[c1, d1] = schedule_rule(D, P);
M1 = evaluate_schedule(c1, d1, D.net, D.tar, P);
[c2, d2] = schedule_deterministic(D.net, D.tar, P);
M2 = evaluate_schedule(c2, d2, D.net, D.tar, P);

Q = P;
Q.peakWeight = 0;
Q.cycleWeight = 0;
[ca, da] = schedule_deterministic(D.net, D.tar, Q);
Ma = evaluate_schedule(ca, da, D.net, D.tar, P);
closedForm = (P.smax - P.smin)*P.E*(P.etaD*P.tariff(3) - P.tariff(1)/P.etaC);

Ms = {M0, M1, M2};
Controller = ["B0"; "B1"; "B2"];
Energy_kWh = cellfun(@(m) m.energy, Ms)';
Peak_kW = cellfun(@(m) m.peak, Ms)';
PeakReduction_pct = cellfun(@(m) m.peakRed, Ms)';
Cost = cellfun(@(m) m.cost, Ms)';
CostReduction_pct = cellfun(@(m) m.costRed, Ms)';
Throughput_kWh = cellfun(@(m) m.throughput, Ms)';
FinalSOC_pct = [NaN; M1.finalSOC; M2.finalSOC];
PeakTime_h = cellfun(@(m) D.t(m.peakIndex), Ms)';
Feasible = cellfun(@(m) m.feasible, Ms)';
R.summary = table(Controller, Energy_kWh, Peak_kW, PeakReduction_pct, Cost, CostReduction_pct, ...
    Throughput_kWh, FinalSOC_pct, PeakTime_h, Feasible);

R.profiles = table(D.t, D.T, D.G, D.L, D.PV, D.EV, D.net, D.tar, M0.grid, M1.grid, M2.grid, ...
    c2, d2, 'VariableNames', {'Time_h', 'Temperature_C', 'Irradiance_Wm2', 'Load_kW', 'PV_kW', ...
    'EV_kW', 'Net_kW', 'Price', 'GridB0_kW', 'GridB1_kW', 'GridB2_kW', 'ChargeB2_kW', 'DischargeB2_kW'});
R.soc = table((0:P.N)'*P.dt, M1.soc, M2.soc, 'VariableNames', {'Time_h', 'SOC_B1', 'SOC_B2'});

[~, kL] = max(D.L);
[~, kPV] = max(D.PV);
[~, kEV] = max(D.EV);
[~, kN] = max(D.net);
Key = ["load_scale"; "load_max_kW"; "load_max_time_h"; "pv_max_kW"; "pv_max_time_h"; ...
    "ev_max_kW"; "ev_max_time_h"; "net_max_kW"; "net_max_time_h"; "net_min_kW"; ...
    "load_energy_kWh"; "pv_energy_kWh"; "ev_energy_kWh"; "temperature_max_C"; ...
    "arbitrage_lp_saving"; "arbitrage_closed_form"; "b2_saving"; "b2_simultaneous_kW"; ...
    "b2_curtailed_kWh"; "b2_soc_min"; "b2_soc_max"];
Value = [D.loadScale; max(D.L); D.t(kL); max(D.PV); D.t(kPV); max(D.EV); D.t(kEV); ...
    max(D.net); D.t(kN); min(D.net); sum(D.L)*P.dt; sum(D.PV)*P.dt; sum(D.EV)*P.dt; max(D.T); ...
    Ma.costB0 - Ma.cost; closedForm; M2.costB0 - M2.cost; M2.simultaneous; M2.curtailed; ...
    min(M2.soc); max(M2.soc)];
R.facts = table(Key, Value);
end
