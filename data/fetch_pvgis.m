function file = fetch_pvgis(root)
%FETCH_PVGIS Download hourly PVGIS irradiance and temperature for Abu Dhabi, 2022 to 2023.
%   file = FETCH_PVGIS(root) queries the PVGIS 5.3 hourly series service of the European
%   Commission Joint Research Centre for latitude 24.4539 N, longitude 54.3773 E, a fixed
%   plane tilted 24 degrees facing south, and saves the JSON response in root/data.

url = ['https://re.jrc.ec.europa.eu/api/v5_3/seriescalc?lat=24.4539&lon=54.3773' ...
    '&startyear=2022&endyear=2023&angle=24&aspect=0&outputformat=json'];
file = fullfile(root, 'data', 'pvgis_abu_dhabi_2022_2023.json');
websave(file, url, weboptions('Timeout', 120, 'ContentType', 'text'));
end
