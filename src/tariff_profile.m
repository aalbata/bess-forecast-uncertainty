function c = tariff_profile(t)
%TARIFF_PROFILE Three-band time-of-use energy price at local times t (h).
%   Off-peak 00:00-06:00 and 22:00-24:00, mid-peak 06:00-17:00, peak 17:00-22:00.

P = bess_parameters();
c = P.tariff(1)*ones(size(t));
c(t >= 6 & t < 17) = P.tariff(2);
c(t >= 17 & t < 22) = P.tariff(3);
end
