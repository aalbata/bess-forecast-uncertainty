function c = cvar_upper(x, alpha)
%CVAR_UPPER Conditional value-at-risk of the upper tail of equally weighted samples.
%   c = CVAR_UPPER(x, alpha) is the mean of the largest (1 - alpha) fraction of the samples x,
%   with the boundary sample weighted fractionally, which equals
%   min over eta of eta + sum(max(x - eta, 0))/((1 - alpha)*numel(x)).

x = sort(x(:), 'descend');
n = numel(x);
m = (1 - alpha)*n;
w = min(max(m - (0:n - 1)', 0), 1);
c = sum(w.*x)/m;
end
