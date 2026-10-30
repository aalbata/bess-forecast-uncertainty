function [m, lo, hi, sd] = mean_ci(x)
%MEAN_CI Sample mean with a two-sided 95% Student-t confidence interval.
%   [m, lo, hi, sd] = MEAN_CI(x) returns the mean, the interval limits and the standard
%   deviation of the finite values of x.

x = x(isfinite(x));
n = numel(x);
m = mean(x);
sd = std(x);
h = tinv(0.975, n - 1)*sd/sqrt(n);
lo = m - h;
hi = m + h;
end
