function [netS, netR, netMean, R] = scenario_set(D, Zs, e)
%SCENARIO_SET Planning scenarios and realized day from perturbation sequences.
%   [netS, netR, netMean, R] = SCENARIO_SET(D, Zs, e) perturbs load, PV and EV of the
%   reference day D with amplitude e. Pages 1 to S of Zs (N x 3 x S+1) give the planning
%   scenarios netS (N x S) and page S+1 gives the realized day netR. netMean is the net load
%   of the scenario-mean load, PV and EV profiles (expected-value forecast) and R contains
%   the realized load, PV and EV profiles.

S = size(Zs, 3) - 1;
Ls = max(0, D.L.*(1 + e*squeeze(Zs(:, 1, 1:S))));
Ps = max(0, D.PV.*(1 + e*squeeze(Zs(:, 2, 1:S))));
Es = max(0, D.EV.*(1 + e*squeeze(Zs(:, 3, 1:S))));
netS = Ls + Es - Ps;
netMean = mean(Ls, 2) + mean(Es, 2) - mean(Ps, 2);
R.L = max(0, D.L.*(1 + e*Zs(:, 1, S + 1)));
R.PV = max(0, D.PV.*(1 + e*Zs(:, 2, S + 1)));
R.EV = max(0, D.EV.*(1 + e*Zs(:, 3, S + 1)));
netR = R.L + R.EV - R.PV;
end
