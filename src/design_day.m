function D = design_day()
%DESIGN_DAY Synthetic hot-season design day of the district.
%   The building load is scaled so that its daily maximum is 1000 kW; the scale factor is
%   returned in D.loadScale and reused for the weather-driven days.

P = bess_parameters();
t = (0:P.N - 1)'*P.dt;
T = 36.5 + 6.5*sin(2*pi*(t - 9)/24);
G = zeros(P.N, 1);
m = t >= 6 & t <= 18.5;
G(m) = 1000*sin(pi*(t(m) - 6)/12.5);
[~, rawLoad] = district_profiles(t, T, G, 1);
loadScale = 1000/max(rawLoad);
D = district_profiles(t, T, G, loadScale);
D.loadScale = loadScale;
end
