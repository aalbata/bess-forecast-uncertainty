function T = run_timing_shift()
%RUN_TIMING_SHIFT Day-ahead schedule B2 when one forecast is shifted in time.
%   The forecast of the selected source (or of all three, Net) is the reference profile
%   shifted circularly by -180 to +180 min in 15-min steps, with no change of shape or
%   amplitude. Each schedule is scored on the design day. Positive shifts make the forecast late.

P = bess_parameters();
D = design_day();
shifts = (-12:12)';
sources = ["Load" "PV" "EV" "Net"];
n = numel(shifts)*numel(sources);
Source = strings(n, 1);
Shift_min = zeros(n, 1);
cols = zeros(n, 6);
r = 0;
for s = sources
    for h = shifts'
        Lf = D.L;
        PVf = D.PV;
        EVf = D.EV;
        if s == "Load" || s == "Net", Lf = circshift(D.L, h); end
        if s == "PV" || s == "Net", PVf = circshift(D.PV, h); end
        if s == "EV" || s == "Net", EVf = circshift(D.EV, h); end
        netF = Lf + EVf - PVf;
        [c, d] = schedule_deterministic(netF, D.tar, P);
        M = evaluate_schedule(c, d, D.net, D.tar, P);
        r = r + 1;
        Source(r) = s;
        Shift_min(r) = 15*h;
        cols(r, :) = [M.peak, M.peakRed, M.costRed, 100*sum(abs(netF - D.net))/sum(D.net), ...
            max(abs(netF - D.net)), D.t(M.peakIndex)];
    end
end
T = [table(Source, Shift_min), array2table(cols, 'VariableNames', {'Peak_kW', ...
    'PeakReduction_pct', 'CostReduction_pct', 'nMAE_Net_pct', 'MaxAbsError_kW', 'RealisedPeakTime_h'})];
end
