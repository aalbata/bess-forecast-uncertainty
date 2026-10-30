function [lo, hi] = bootstrap_ci(fun, seed, varargin)
%BOOTSTRAP_CI Percentile 95% bootstrap interval of a statistic of paired samples.
%   [lo, hi] = BOOTSTRAP_CI(fun, seed, x1, x2, ...) resamples the rows of the equally long
%   column vectors x1, x2, ... jointly 2000 times with the random stream of the given seed and
%   returns the 2.5 and 97.5 percentiles of fun(x1(i), x2(i), ...).

B = 2000;
stream = RandStream('mt19937ar', 'Seed', seed);
n = numel(varargin{1});
v = zeros(B, 1);
for b = 1:B
    i = randi(stream, n, n, 1);
    args = cellfun(@(x) x(i), varargin, 'UniformOutput', false);
    v(b) = fun(args{:});
end
lo = prctile(v, 2.5);
hi = prctile(v, 97.5);
end
