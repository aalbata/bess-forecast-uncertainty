function [Lf, PVf, EVf] = perturb_profiles(D, Z, e, source)
%PERTURB_PROFILES Forecast profiles with multiplicative error on the selected source.
%   [Lf, PVf, EVf] = PERTURB_PROFILES(D, Z, e, source) multiplies the reference profiles in D by
%   1 + e*Z(:,j) for the sources selected by source ("Load", "PV", "EV" or "Compound") and
%   truncates the result at zero. Unselected sources keep their reference profiles.

Lf = D.L;
PVf = D.PV;
EVf = D.EV;
if source == "Load" || source == "Compound"
    Lf = max(0, D.L.*(1 + e*Z(:, 1)));
end
if source == "PV" || source == "Compound"
    PVf = max(0, D.PV.*(1 + e*Z(:, 2)));
end
if source == "EV" || source == "Compound"
    EVf = max(0, D.EV.*(1 + e*Z(:, 3)));
end
end
