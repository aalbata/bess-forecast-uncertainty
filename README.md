# Forecast errors and battery peak shaving in an urban district

MATLAB code, weather data and trial-level results for the article

> Forecast error source and timing govern the peak-shaving value of battery storage in urban districts
> Asif Nawaz, Ali Al Bataineh, Irfan Ahmed, Munther Gdeisat and Nguyen Hai

The study schedules a 500 kWh / 250 kW battery energy storage system (BESS) for an urban district with building load, rooftop photovoltaic (PV) generation and electric vehicle (EV) charging, and measures how forecast errors in each source change the peak reduction and the energy-cost reduction of the schedule. It compares a day-ahead linear program, a risk-neutral stochastic program, conditional value-at-risk (CVaR) and worst-case scenario programs, receding-horizon re-optimization and a perfect-information bound, on a synthetic design day and on 365 weather-driven days of 2023 in Abu Dhabi.

## Requirements

- MATLAB R2026b (developed and run on Windows 11, Intel Core Ultra 7 155U, 16 GB memory)
- Optimization Toolbox (`linprog`, dual simplex of HiGHS)
- Statistics and Machine Learning Toolbox (`tinv`, `signrank`, `regress`, `prctile`)

No other software is needed. The weather data are included in `data/`.

## Quick start

```matlab
reproduce          % tests, summary tables and figures from the shipped results (about two minutes)
reproduce('full')  % rerun every experiment, then rebuild summaries and figures
reproduce('download')  % download the PVGIS data again, then run as 'full'
```

`reproduce` first runs `tests/run_tests.m`, which checks the design-day controllers against reference values, checks the solvers against reference trials, and checks the band invariance of the energy cost.

The full run solves 1,818,383 linear programs (each receding-horizon day solves 96). On the machine above it took about 13 hours of MATLAB process time, run as blocks of trials in seven to eight parallel processes. The experiment functions accept a trial range (for example `run_controllers(1:200)`), so blocks of trials can run in separate MATLAB processes; concatenating the blocks in trial order gives the same files as one run.

## Main results

| Quantity | Value |
|---|---|
| Design day, exact forecasts: peak reduction / cost reduction of B2 | 16.35% / 1.52% |
| Arbitrage value of one full battery cycle (cost units) | 88.97 |
| Compound error, amplitude 5% / 20% / 30%: mean peak reduction of B2 | 14.49% / 9.31% / 5.78% |
| Compound error, amplitude 5% / 30%: mean cost reduction of B2 | 1.517% / 1.405% |
| Loss of peak reduction at 20%: load / EV / PV / compound (pp) | 6.88 / 1.23 / 0.36 / 7.04 |
| PV forecast 30 min late: peak reduction | 12.12% |
| Random days at 20%: mean peak reduction PI / B2 / SP / CVaR / WC / RH | 18.13 / 10.83 / 10.66 / 10.08 / 10.06 / 12.13% |
| Weather year: mean daily peak reduction of B2 with exact forecasts | 18.6% |
| Weather year, 20%: mean daily loss load / EV / PV (pp) | 7.92 / 1.51 / 0.27 |
| Days of 2023 on which load error is the most damaging source | 365 of 365 |

pp = percentage points. Peak and cost reductions are relative to operation without storage on the same day.

## Repository layout

| Path | Content |
|---|---|
| `reproduce.m` | entry point |
| `src/` | district model, forecast errors, schedules (`schedule_rule`, `schedule_deterministic`, `schedule_cvar`, `schedule_mpc`), evaluation and statistics helpers |
| `experiments/` | one function per experiment (`run_nominal`, `run_source_magnitude`, `run_timing_shift`, `run_controllers`, `run_risk_sweep`, `run_scenario_count`, `run_mpc_sources`, `run_battery_size`, `run_demand_charge`, `run_weather_year`) |
| `analysis/summarize_results.m` | summary tables in `results/summary/` |
| `figures/make_figures.m` | figures in `output/figures/` |
| `data/` | PVGIS hourly data for Abu Dhabi, 2022 to 2023, and `fetch_pvgis.m` |
| `results/` | trial-level results (CSV) |
| `tests/run_tests.m` | regression and consistency tests |

## Result files and columns

All powers are in kW, energies in kWh, costs in cost units, reductions in percent of the value without storage on the same day, and times in local hours (UTC+4 for the weather-driven days).

| File | One row per | Main columns |
|---|---|---|
| `nominal_summary.csv` | controller B0, B1, B2 on the design day | `Peak_kW`, `PeakReduction_pct`, `Cost`, `CostReduction_pct`, `Throughput_kWh`, `FinalSOC_pct`, `PeakTime_h`, `Feasible` |
| `nominal_profiles.csv` | 15-min interval of the design day | temperature, irradiance, load, PV, EV, net load, price, grid import of B0, B1, B2, B2 charging and discharging power |
| `nominal_soc.csv` | interval boundary | state of charge of B1 and B2 |
| `nominal_facts.csv` | scalar | profile maxima and times, arbitrage optimum and closed-form value |
| `timing_shift.csv` | source and time shift | `Shift_min` (positive: forecast late), `PeakReduction_pct`, `nMAE_Net_pct`, `MaxAbsError_kW` |
| `source_magnitude_trials.csv` | source, amplitude and trial (B2) | `Source`, `Level_pct` (amplitude e), `Trial`, peak and cost results, `nMAE_*_pct` (energy-weighted normalized mean absolute error), `ErrorAtB0Peak_kW`, `ForecastPeakTime_h`, `RealisedPeakTime_h` |
| `mpc_sources_trials.csv` | source, amplitude and trial (RH) | as above for the receding-horizon schedule; `Fallbacks` counts failed re-solves |
| `controllers_trials.csv` | controller, amplitude and random realized day | `Controller` (B1, B2, SP, CVaR, WC, RH, PI), peak, cost and throughput results, `PeakB0_kW`, `CostB0`, in-sample peaks on the planning scenarios |
| `risk_sweep_trials.csv` | alpha, lambda and realized day | `Alpha`, `Lambda`, realized and in-sample peaks |
| `scenario_count_trials.csv` | program, number of planning scenarios and realized day | `Controller` (B2, SP, CVaR), `Scenarios` (10, 20, 50, 100), realized and in-sample peaks |
| `battery_size_trials.csv` | battery, source, amplitude and trial | `Energy_kWh`, `Power_kW`, `Source` (`None` for exact forecasts), results |
| `demand_charge_trials.csv` | demand charge, amplitude and trial | `DemandCharge` (cost units per kW of daily peak), `Bill`, `BillReduction_pct` |
| `weather_year_days.csv` | day of 2023 | weather and load descriptors, B0 and B2 results with exact forecasts |
| `weather_year_summary.csv` | day, source and amplitude | mean, standard deviation and percentiles of B2 peak reduction over the trials |
| `summary/*.csv` | | statistics used in the article (means, 95% confidence intervals, paired differences, Wilcoxon p-values, bootstrap intervals) |

## Data

`data/pvgis_abu_dhabi_2022_2023.json` contains hourly plane-of-array irradiance (24 degree tilt, facing south) and 2-m air temperature for latitude 24.4539 N, longitude 54.3773 E, from PVGIS 5.3 of the European Commission Joint Research Centre (radiation database PVGIS-SARAH3, temperature from ERA5). The Joint Research Centre states that PVGIS information is free and that there are no restrictions on its use, and asks users to acknowledge PVGIS of the European Commission Joint Research Centre and to cite https://joint-research-centre.ec.europa.eu/photovoltaic-geographical-information-system-pvgis_en.

## License

MIT License, see `LICENSE`. The PVGIS data remain subject to the conditions of their provider.
