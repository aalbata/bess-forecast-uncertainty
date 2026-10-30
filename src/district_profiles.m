function [D, rawLoad] = district_profiles(t, T, G, loadScale)
%DISTRICT_PROFILES Building load, PV and EV profiles of the district for one day.
%   [D, rawLoad] = DISTRICT_PROFILES(t, T, G, loadScale) evaluates the district model at the
%   interval start times t (h, local time) for air temperature T (degC) and plane-of-array
%   irradiance G (W/m2). The building load is the unscaled load rawLoad multiplied by
%   loadScale (kW per model unit). D contains t, T, G, L, PV, EV, net and the tariff tar.

t = t(:);
T = T(:);
G = G(:);
residential = 150 + 70*exp(-((t - 7.5)/1.5).^2) + 170*exp(-((t - 20)/2.5).^2) + 8*max(T - 30, 0);
commercial = 80 + 260*exp(-((t - 13)/4).^4) + 10*max(T - 30, 0);
base = 100 + 20*sin(2*pi*(t - 8)/24);
rawLoad = residential + commercial + base;

D.t = t;
D.T = T;
D.G = G;
D.L = rawLoad*loadScale;
D.PV = min(max(500*(G/1000).*(1 - 0.004*((T + 0.025*G) - 25)), 0), 500);
D.EV = min(150*exp(-((t - 19)/2.2).^2) + 35*exp(-((t - 12)/2.5).^2), 200);
D.tar = tariff_profile(t);
D.net = D.L + D.EV - D.PV;
end
