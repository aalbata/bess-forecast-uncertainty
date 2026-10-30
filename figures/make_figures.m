function make_figures(root, figs)
%MAKE_FIGURES Vector figures of the manuscript from the result and summary files.
%   MAKE_FIGURES(root) writes PDF figures to root/output/figures. Single-column figures are
%   3.5 in wide and double-column figures 7.2 in wide; text is set in Times New Roman, 7 pt.
%   MAKE_FIGURES(root, figs) draws only the listed figures ("design", "montecarlo", "sources",
%   "timing", "controllers", "risk", "weather", "battery", "demand").

if nargin < 2
    figs = ["design" "montecarlo" "sources" "timing" "controllers" "risk" "weather" "battery" "demand"];
end

R = fullfile(root, 'results');
S = fullfile(R, 'summary');
O = fullfile(root, 'output', 'figures');
if ~isfolder(O), mkdir(O); end
P = bess_parameters();
src = ["Load" "PV" "EV" "Compound"];
srcColor = [0 114 178; 230 159 0; 0 158 115; 0 0 0]/255;
srcMarker = {'o', 's', '^', 'd'};
ctl = ["B1" "B2" "SP" "CVaR" "WC" "RH" "PI"];
ctlColor = [153 153 153; 0 114 178; 86 180 233; 213 94 0; 204 121 167; 0 158 115; 0 0 0]/255;
ctlMarker = {'x', 'o', 'd', 's', '^', 'v', 'none'};
ctlStyle = {'--', '-', '-', '-', '-', '-', ':'};
aMarker = {'o', 's', '^'};
nom = readtable(fullfile(R, 'nominal_summary.csv'), 'TextType', 'string');
nomB2 = nom.PeakReduction_pct(nom.Controller == "B2");
nomCost = nom.CostReduction_pct(nom.Controller == "B2");

%% Design day
if any(figs == "design")
pr = readtable(fullfile(R, 'nominal_profiles.csv'));
so = readtable(fullfile(R, 'nominal_soc.csv'));
f = newfig(7.2, 2.25);
t = tiledlayout(f, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(t);
band(ax, [0 1400]);
plot(ax, pr.Time_h, pr.Load_kW, '-', 'Color', srcColor(1, :), 'LineWidth', 0.9, 'DisplayName', 'Building load');
plot(ax, pr.Time_h, pr.PV_kW, '-', 'Color', srcColor(2, :), 'LineWidth', 0.9, 'DisplayName', 'PV');
plot(ax, pr.Time_h, pr.EV_kW, '-', 'Color', srcColor(3, :), 'LineWidth', 0.9, 'DisplayName', 'EV');
plot(ax, pr.Time_h, pr.Net_kW, '-', 'Color', [0 0 0], 'LineWidth', 1.1, 'DisplayName', 'Net load');
finish(ax, 'Power (kW)', '(a)', [0 1300]);
legend(ax, 'Location', 'north', 'Box', 'off', 'FontSize', 6, 'NumColumns', 2);
ax = nexttile(t);
band(ax, [0 1400]);
plot(ax, pr.Time_h, pr.GridB0_kW, '-', 'Color', [0 0 0], 'LineWidth', 0.7, 'DisplayName', 'B0');
plot(ax, pr.Time_h, pr.GridB1_kW, '--', 'Color', ctlColor(1, :), 'LineWidth', 0.9, 'DisplayName', 'B1');
plot(ax, pr.Time_h, pr.GridB2_kW, '-', 'Color', ctlColor(2, :), 'LineWidth', 1.1, 'DisplayName', 'B2');
finish(ax, 'Grid import (kW)', '(b)', [300 1050]);
legend(ax, 'Location', 'north', 'Box', 'off', 'FontSize', 6, 'NumColumns', 3);
ax = nexttile(t);
band(ax, [0 100]);
stairs(ax, so.Time_h, 100*so.SOC_B1, '--', 'Color', ctlColor(1, :), 'LineWidth', 0.9, 'DisplayName', 'B1');
stairs(ax, so.Time_h, 100*so.SOC_B2, '-', 'Color', ctlColor(2, :), 'LineWidth', 1.1, 'DisplayName', 'B2');
yline(ax, [100*P.smin 100*P.smax], ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.6, 'HandleVisibility', 'off');
finish(ax, 'State of charge (%)', '(c)', [0 100]);
legend(ax, 'Location', 'south', 'Box', 'off', 'FontSize', 6, 'NumColumns', 2);
save_pdf(f, fullfile(O, 'fig_design_day.pdf'));

end

%% Monte Carlo, compound error
if any(figs == "montecarlo")
T = readtable(fullfile(R, 'source_magnitude_trials.csv'), 'TextType', 'string');
C = T(T.Source == "Compound", :);
f = newfig(3.5, 3.4);
t = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(t);
hold(ax, 'on');
boxchart(ax, C.Level_pct, C.PeakReduction_pct, 'BoxWidth', 0.6, 'MarkerStyle', '.', 'MarkerSize', 3, ...
    'BoxFaceColor', srcColor(1, :), 'MarkerColor', [0.5 0.5 0.5], 'LineWidth', 0.6);
yline(ax, nomB2, '--', 'Color', [0 0 0], 'LineWidth', 0.7);
text(ax, 31.5, nomB2, 'exact forecast', 'FontSize', 6, 'FontName', 'Times New Roman', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom');
style(ax);
ylabel(ax, 'Peak reduction (%)');
xlim(ax, [2 33]);
xticks(ax, P.levels);
xticklabels(ax, []);
panel(ax, '(a)');
ax = nexttile(t);
hold(ax, 'on');
boxchart(ax, C.Level_pct, C.CostReduction_pct, 'BoxWidth', 0.6, 'MarkerStyle', '.', 'MarkerSize', 3, ...
    'BoxFaceColor', srcColor(2, :), 'MarkerColor', [0.5 0.5 0.5], 'LineWidth', 0.6);
yline(ax, nomCost, '--', 'Color', [0 0 0], 'LineWidth', 0.7);
style(ax);
ylabel(ax, 'Cost reduction (%)');
xlabel(ax, 'Forecast error amplitude e (%)');
xlim(ax, [2 33]);
xticks(ax, P.levels);
panel(ax, '(b)');
save_pdf(f, fullfile(O, 'fig_monte_carlo.pdf'));

end

%% Source-specific error and rolling re-optimization
if any(figs == "sources")
G = readtable(fullfile(S, 'source_magnitude_summary.csv'), 'TextType', 'string');
H = readtable(fullfile(S, 'mpc_sources_summary.csv'), 'TextType', 'string');
f = newfig(3.5, 3.6);
t = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(t);
hold(ax, 'on');
yline(ax, nomB2, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.6, 'HandleVisibility', 'off');
for i = 1:4
    g = sortrows(G(G.Source == src(i), :), 'Level_pct');
    errorbar(ax, g.Level_pct + (i - 2.5)*0.25, g.MeanPeakReduction_pct, g.MeanPeakReduction_pct - g.CI95Low, ...
        g.CI95High - g.MeanPeakReduction_pct, ['-' srcMarker{i}], 'Color', srcColor(i, :), 'MarkerSize', 3.5, ...
        'MarkerFaceColor', srcColor(i, :), 'LineWidth', 0.9, 'CapSize', 2, 'DisplayName', label_source(src(i)));
end
style(ax);
ylabel(ax, 'Mean peak reduction (%)');
xlim(ax, [3 32]);
xticks(ax, P.levels);
xticklabels(ax, []);
legend(ax, 'Location', 'southwest', 'Box', 'off', 'FontSize', 6, 'NumColumns', 2);
panel(ax, '(a)');
ax = nexttile(t);
hold(ax, 'on');
yline(ax, 0, '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5, 'HandleVisibility', 'off');
for i = 1:4
    h = sortrows(H(H.Source == src(i), :), 'Level_pct');
    errorbar(ax, h.Level_pct + (i - 2.5)*0.25, h.MeanDifference_pp, h.MeanDifference_pp - h.DiffCI95Low, ...
        h.DiffCI95High - h.MeanDifference_pp, ['-' srcMarker{i}], 'Color', srcColor(i, :), 'MarkerSize', 3.5, ...
        'MarkerFaceColor', 'w', 'LineWidth', 0.9, 'CapSize', 2, 'DisplayName', label_source(src(i)));
end
style(ax);
ylabel(ax, {'RH minus day-ahead', 'peak reduction (pp)'});
xlabel(ax, 'Forecast error amplitude e (%)');
xlim(ax, [3 32]);
xticks(ax, P.levels);
panel(ax, '(b)');
save_pdf(f, fullfile(O, 'fig_sources.pdf'));

end

%% Timing shift
if any(figs == "timing")
T = readtable(fullfile(R, 'timing_shift.csv'), 'TextType', 'string');
lab = ["Load" "PV" "EV" "Net"];
f = newfig(3.5, 2.3);
ax = axes(f);
hold(ax, 'on');
yline(ax, nomB2, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.6, 'HandleVisibility', 'off');
for i = 1:4
    g = sortrows(T(T.Source == lab(i), :), 'Shift_min');
    plot(ax, g.Shift_min, g.PeakReduction_pct, ['-' srcMarker{i}], 'Color', srcColor(i, :), 'MarkerSize', 3, ...
        'MarkerFaceColor', srcColor(i, :), 'LineWidth', 0.9, 'DisplayName', label_shift(lab(i)));
end
style(ax);
xlim(ax, [-185 185]);
xticks(ax, -180:60:180);
xlabel(ax, 'Forecast time shift (min), positive when the forecast is late');
ylabel(ax, 'Peak reduction (%)');
ylim(ax, [0 22]);
yticks(ax, 0:5:20);
legend(ax, 'Location', 'north', 'Box', 'off', 'FontSize', 6, 'NumColumns', 2);
save_pdf(f, fullfile(O, 'fig_timing_shift.pdf'));

end

%% Controllers on random realized days
if any(figs == "controllers")
K = readtable(fullfile(S, 'controllers_summary.csv'), 'TextType', 'string');
f = newfig(7.2, 2.5);
t = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(t);
hold(ax, 'on');
for i = 1:numel(ctl)
    g = sortrows(K(K.Controller == ctl(i), :), 'Level_pct');
    errorbar(ax, g.Level_pct + (i - 4)*0.2, g.MeanPeakReduction_pct, g.MeanPeakReduction_pct - g.CI95Low, ...
        g.CI95High - g.MeanPeakReduction_pct, ctlStyle{i}, 'Marker', ctlMarker{i}, 'Color', ctlColor(i, :), ...
        'MarkerSize', 3.5, 'MarkerFaceColor', 'w', 'LineWidth', 0.9, 'CapSize', 2, 'DisplayName', ctl(i));
end
style(ax);
xlim(ax, [3 32]);
xticks(ax, P.levels);
xlabel(ax, 'Forecast error amplitude e (%)');
ylabel(ax, 'Mean peak reduction (%)');
legend(ax, 'Location', 'eastoutside', 'Box', 'off', 'FontSize', 6);
panel(ax, '(a)');
Kd = readtable(fullfile(S, 'controllers_paired.csv'), 'TextType', 'string');
ax = nexttile(t);
hold(ax, 'on');
yline(ax, 0, '-', 'Color', ctlColor(2, :), 'LineWidth', 0.9, 'HandleVisibility', 'off');
for i = find(ismember(ctl, ["SP" "CVaR" "WC" "RH"]))
    g = sortrows(Kd(Kd.Controller == ctl(i), :), 'Level_pct');
    errorbar(ax, g.Level_pct + (i - 4)*0.2, g.CVaR90PeakDifference_kW, g.CVaR90PeakDifference_kW - g.CVaR90DiffCI95Low, ...
        g.CVaR90DiffCI95High - g.CVaR90PeakDifference_kW, ctlStyle{i}, 'Marker', ctlMarker{i}, 'Color', ctlColor(i, :), ...
        'MarkerSize', 3.5, 'MarkerFaceColor', 'w', 'LineWidth', 0.9, 'CapSize', 2, 'HandleVisibility', 'off');
end
style(ax);
xlim(ax, [3 32]);
xticks(ax, P.levels);
xlabel(ax, 'Forecast error amplitude e (%)');
ylabel(ax, {'Mean of worst 10% of realized', 'peaks minus that of B2 (kW)'});
panel(ax, '(b)');
save_pdf(f, fullfile(O, 'fig_controllers.pdf'));

end

%% Risk sweep
if any(figs == "risk")
W = readtable(fullfile(S, 'risk_sweep_summary.csv'));
alphas = unique(W.Alpha)';
aColor = [86 180 233; 213 94 0; 204 121 167]/255;
lam = unique(W.Lambda)';
xpos = 1:numel(lam);
f = newfig(3.5, 3.6);
t = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(t);
hold(ax, 'on');
for i = 1:numel(alphas)
    g = sortrows(W(W.Alpha == alphas(i), :), 'Lambda');
    plot(ax, xpos, g.MeanInSampleCVaR90_kW, ['-' aMarker{i}], 'Color', aColor(i, :), 'MarkerSize', 3.5, ...
        'MarkerFaceColor', aColor(i, :), 'LineWidth', 0.9, 'DisplayName', sprintf('\\alpha = %.2f', alphas(i)));
    plot(ax, xpos, g.OutOfSampleCVaR90Peak_kW, ['--' aMarker{i}], 'Color', aColor(i, :), 'MarkerSize', 3.5, ...
        'MarkerFaceColor', 'w', 'LineWidth', 0.9, 'HandleVisibility', 'off');
end
style(ax);
xlim(ax, [0.7 numel(lam) + 0.3]);
xticks(ax, xpos);
xticklabels(ax, []);
ylabel(ax, {'Mean of worst 10%', 'of peaks (kW)'});
legend(ax, 'Location', 'east', 'Box', 'off', 'FontSize', 6, 'NumColumns', 1);
g = sortrows(W(W.Alpha == alphas(2), :), 'Lambda');
text(ax, 2, g.OutOfSampleCVaR90Peak_kW(2) + 4, 'realized days (dashed)', 'FontName', 'Times New Roman', ...
    'FontSize', 6, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
text(ax, 2.6, g.MeanInSampleCVaR90_kW(2) - 9, 'planning scenarios (solid)', 'FontName', 'Times New Roman', ...
    'FontSize', 6, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');
panel(ax, '(a)');
ax = nexttile(t);
hold(ax, 'on');
yline(ax, 0, '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5, 'HandleVisibility', 'off');
for i = 1:numel(alphas)
    g = sortrows(W(W.Alpha == alphas(i), :), 'Lambda');
    errorbar(ax, xpos + (i - 2)*0.08, g.MeanDifferenceVsLambda0_pp, g.MeanDifferenceVsLambda0_pp - g.DiffCI95Low, ...
        g.DiffCI95High - g.MeanDifferenceVsLambda0_pp, ['-' aMarker{i}], 'Color', aColor(i, :), 'MarkerSize', 3.5, ...
        'MarkerFaceColor', aColor(i, :), 'LineWidth', 0.9, 'CapSize', 2, 'DisplayName', sprintf('\\alpha = %.2f', alphas(i)));
end
style(ax);
xlim(ax, [0.7 numel(lam) + 0.3]);
xticks(ax, xpos);
xticklabels(ax, compose('%g', lam));
xlabel(ax, 'Risk weight \lambda');
ylabel(ax, {'Change in mean peak', 'reduction from \lambda = 0 (pp)'});
ylim(ax, [-0.8 0.12]);
legend(ax, 'Location', 'southwest', 'Box', 'off', 'FontSize', 6);
panel(ax, '(b)');
save_pdf(f, fullfile(O, 'fig_risk_sweep.pdf'));

end

%% Weather year
if any(figs == "weather")
Dy = readtable(fullfile(R, 'weather_year_days.csv'), 'TextType', 'string');
Mo = readtable(fullfile(S, 'weather_year_monthly.csv'), 'TextType', 'string');
Sy = readtable(fullfile(R, 'weather_year_summary.csv'), 'TextType', 'string');
f = newfig(7.2, 2.4);
t = tiledlayout(f, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(t);
hold(ax, 'on');
d = datetime(Dy.Date, 'InputFormat', 'yyyy-MM-dd');
plot(ax, d, Dy.PeakB0_kW, '.', 'Color', [0 0 0], 'MarkerSize', 4, 'DisplayName', 'B0');
plot(ax, d, Dy.PeakB2_kW, '.', 'Color', ctlColor(2, :), 'MarkerSize', 4, 'DisplayName', 'B2, exact forecast');
style(ax);
xlim(ax, [datetime(2023, 1, 1) datetime(2023, 12, 31)]);
xticks(ax, datetime(2023, [1 4 7 10], 1));
ax.XAxis.TickLabelFormat = 'MMM';

ax.XAxis.SecondaryLabel.Visible = 'off';
xlabel(ax, 'Day of 2023');
ylabel(ax, 'Daily peak import (kW)');
ylim(ax, [550 950]);
legend(ax, 'Location', 'northwest', 'Box', 'off', 'FontSize', 6);
text(ax, 0.98, 0.98, '(a)', 'Units', 'normalized', 'FontName', 'Times New Roman', 'FontSize', 7, ...
    'VerticalAlignment', 'top', 'HorizontalAlignment', 'right');
ax = nexttile(t);
hold(ax, 'on');
for i = 1:4
    g = sortrows(Mo(Mo.Source == src(i) & Mo.Level_pct == 20, :), 'Month');
    plot(ax, g.Month, g.MeanLoss_pp, ['-' srcMarker{i}], 'Color', srcColor(i, :), 'MarkerSize', 3.5, ...
        'MarkerFaceColor', srcColor(i, :), 'LineWidth', 0.9, 'DisplayName', label_source(src(i)));
end
style(ax);
xlim(ax, [0.5 12.5]);
ylim(ax, [0 10.5]);
xticks(ax, 1:12);
xticklabels(ax, {'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'});
xlabel(ax, 'Month of 2023');
ylabel(ax, 'Mean loss of peak reduction (pp)');
legend(ax, 'Location', 'east', 'Box', 'off', 'FontSize', 6);
panel(ax, '(b)');
ax = nexttile(t);
hold(ax, 'on');
base = Dy.PeakReductionB2_pct;
for i = 1:4
    g = sortrows(Sy(Sy.Source == src(i) & Sy.Level_pct == 20, :), 'Day');
    boxchart(ax, i*ones(height(g), 1), base - g.MeanPeakReduction_pct, 'BoxFaceColor', srcColor(i, :), ...
        'MarkerColor', srcColor(i, :), 'MarkerStyle', '.', 'MarkerSize', 4, 'LineWidth', 0.6, 'BoxWidth', 0.6);
end
style(ax);
xlim(ax, [0.4 4.6]);
xticks(ax, 1:4);
xticklabels(ax, {'Load', 'PV', 'EV', 'Compound'});
ax.XTickLabelRotation = 0;
xlabel(ax, 'Forecast perturbed');
ylabel(ax, 'Daily mean loss (pp)');
panel(ax, '(c)');
save_pdf(f, fullfile(O, 'fig_weather_year.pdf'));

end

%% Battery size (appendix)
if any(figs == "battery")
B = readtable(fullfile(S, 'battery_size_summary.csv'), 'TextType', 'string');
powers = unique(B.Power_kW)';
f = newfig(7.2, 2.3);
t = tiledlayout(f, 1, numel(powers), 'TileSpacing', 'compact', 'Padding', 'compact');
for j = 1:numel(powers)
    ax = nexttile(t);
    hold(ax, 'on');
    for i = 1:4
        g = sortrows(B(B.Power_kW == powers(j) & B.Source == src(i) & B.Level_pct == 20, :), 'Energy_kWh');
        plot(ax, g.Energy_kWh, g.MeanLoss_pp, ['-' srcMarker{i}], 'Color', srcColor(i, :), 'MarkerSize', 3.5, ...
            'MarkerFaceColor', srcColor(i, :), 'LineWidth', 0.9, 'DisplayName', label_source(src(i)));
    end
    style(ax);
    xticks(ax, unique(B.Energy_kWh)');
    xlim(ax, [200 1050]);
    xlabel(ax, 'Battery energy capacity (kWh)');
    if j == 1
        ylabel(ax, 'Mean loss of peak reduction (pp)');
        legend(ax, 'Location', 'northwest', 'Box', 'off', 'FontSize', 6);
    end
    title(ax, sprintf('Power limit %d kW', powers(j)), 'FontWeight', 'normal', 'FontSize', 7);
    panel(ax, sprintf('(%c)', 'a' + j - 1));
end
linkaxes(findobj(t.Children, 'Type', 'axes'), 'y');
save_pdf(f, fullfile(O, 'fig_battery_size.pdf'));

end

%% Demand charge (appendix)
if any(figs == "demand")
Q = readtable(fullfile(S, 'demand_charge_summary.csv'));
w = unique(Q.DemandCharge)';
wColor = [86 180 233; 0 114 178; 213 94 0; 0 0 0]/255;
wMarker = {'o', 's', '^', 'd'};
f = newfig(3.5, 2.3);
ax = axes(f);
hold(ax, 'on');
for i = 1:numel(w)
    g = sortrows(Q(Q.DemandCharge == w(i), :), 'Level_pct');
    plot(ax, g.Level_pct, g.MeanBillReduction_pct, ['-' wMarker{i}], 'Color', wColor(i, :), ...
        'MarkerSize', 3.5, 'MarkerFaceColor', wColor(i, :), 'LineWidth', 0.9, ...
        'DisplayName', sprintf('w = %g per kW', w(i)));
end
g = sortrows(Q(Q.DemandCharge == w(1), :), 'Level_pct');
plot(ax, g.Level_pct, g.MeanCostReduction_pct, ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.9, ...
    'DisplayName', 'Energy cost only');
style(ax);
xticks(ax, unique(Q.Level_pct)');
xlim(ax, [-1 31]);
xlabel(ax, 'Forecast error amplitude e (%)');
ylabel(ax, 'Mean bill reduction (%)');
legend(ax, 'Location', 'northeast', 'Box', 'off', 'FontSize', 6);
save_pdf(f, fullfile(O, 'fig_demand_charge.pdf'));
end
end

function f = newfig(w, h)
f = figure('Visible', 'off', 'Units', 'inches', 'Position', [0 0 w h], 'Color', 'w');
end

function band(ax, yl)
hold(ax, 'on');
patch(ax, [17 22 22 17], [yl(1) yl(1) yl(2) yl(2)], [0.92 0.92 0.92], 'EdgeColor', 'none', ...
    'HandleVisibility', 'off');
end

function finish(ax, ylab, tag, yl)
style(ax);
xlim(ax, [0 24]);
ylim(ax, yl);
xticks(ax, 0:6:24);
xticklabels(ax, compose('%02d:00', 0:6:24));
xlabel(ax, 'Local time (HH:MM)');
ylabel(ax, ylab);
panel(ax, tag);
end

function style(ax)
set(ax, 'FontName', 'Times New Roman', 'FontSize', 7, 'LineWidth', 0.5, 'TickDir', 'out', 'Box', 'off', ...
    'XGrid', 'on', 'YGrid', 'on', 'GridAlpha', 0.12, 'Layer', 'top', 'TickLength', [0.015 0.015]);
end

function panel(ax, tag)
text(ax, 0.02, 0.98, tag, 'Units', 'normalized', 'FontName', 'Times New Roman', 'FontSize', 7, ...
    'VerticalAlignment', 'top', 'HorizontalAlignment', 'left', 'BackgroundColor', 'none');
end

function s = label_source(s)
if s == "Compound", s = "Compound"; else, s = s + " only"; end
end

function s = label_shift(s)
if s == "Net", s = "All sources"; else, s = s + " forecast"; end
end

function save_pdf(f, file)
exportgraphics(f, file, 'ContentType', 'vector', 'BackgroundColor', 'white');
close(f);
end
