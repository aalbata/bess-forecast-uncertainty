function Z = forecast_noise(stream, N)
%FORECAST_NOISE Smoothed, max-normalized perturbation sequences for load, PV and EV.
%   Z = FORECAST_NOISE(stream, N) draws three standard normal sequences of length N from the
%   random stream, smooths them with centered moving averages of 9, 9 and 7 intervals and
%   divides each by its largest absolute value. Columns 1 to 3 belong to load, PV and EV.

windows = [9 9 7];
Z = zeros(N, 3);
for j = 1:3
    z = smoothdata(randn(stream, N, 1), 'movmean', windows(j));
    Z(:, j) = z/(max(abs(z)) + eps);
end
end
