function W = weather_days(file, year)
%WEATHER_DAYS Daily 15-min temperature and irradiance profiles in local time from PVGIS data.
%   W = WEATHER_DAYS(file, year) reads the hourly PVGIS series in the JSON file (timestamps in
%   UTC), converts them to local time (UTC + P.utcOffset h), and interpolates air temperature
%   T2m and plane-of-array irradiance G(i) linearly to the interval start times of every local
%   calendar day of the given year. W.T and W.G are N x days matrices; W.date lists the days.

P = bess_parameters();
d = jsondecode(fileread(file));
h = d.outputs.hourly;
stamp = datetime(string({h.time}'), 'InputFormat', 'yyyyMMdd:HHmm', 'TimeZone', 'UTC');
tLocal = stamp + hours(P.utcOffset);
tLocal.TimeZone = '';
T2m = [h.T2m]';
Gi = [h.G_i_]';
days = (datetime(year, 1, 1):datetime(year, 12, 31))';
grid = days' + minutes((0:P.N - 1)'*P.dt*60);
x = datenum(tLocal);
q = datenum(grid(:));
W.date = days;
W.T = reshape(interp1(x, T2m, q, 'linear'), P.N, numel(days));
W.G = reshape(max(interp1(x, Gi, q, 'linear'), 0), P.N, numel(days));
W.source = d.inputs.meteo_data;
if any(isnan(W.T(:))) || any(isnan(W.G(:)))
    error('weather_days:coverage', 'The PVGIS file does not cover every local day of %d.', year);
end
end
