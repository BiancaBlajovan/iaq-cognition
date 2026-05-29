# HEPA Purification and Cognitive Performance in University Classrooms
## Data and Analysis Repository

This repository contains the anonymised dataset and analysis scripts for the study:

> **Air Quality Improvement and Cognitive Performance:
> A Multi-Sensor IoT Classroom Study**
> B.-L. Blajovan, C. Stângaciu, D. Stanescu, R. Bogdan, M. Marcu
> Politehnica University of Timișoara, Romania
> Submitted to ICSTCC 2025

---

## Study Overview

A quasi-experimental within-subjects crossover study examining whether
operating a HEPA air purifier (Dyson TP09, HEPA H13) during a 90-minute
university laboratory session improves cognitive performance relative to
a no-purifier control session.

- **Design:** Fixed AB order (Dyson ON → No purifier), 6 cohorts
- **Sessions:** November–December 2024, Politehnica University of Timișoara
- **Participants:** N = 138 sessions, 67 matched pairs
- **IAQ monitoring:** Airify multi-sensor platform (continuous, 1-min intervals)
- **Cognitive battery:** PsyToolkit — Simple RT, Choice RT, Stroop, N-back (1/2/3-back)

---

## Repository Structure

```
├── README.md
├── data/
│   ├── merged_corrected_anonymised.csv   # Main dataset (138 rows × 97 cols)
│   ├── table_paired_results.csv          # Paired t-test results (8 outcomes)
│   └── table_correlations.csv            # IAQ–cognition correlations
├── scripts/
│   ├── analyze_iaq_cognition_corrected.R # Main statistical analysis (R)
│   ├── load_airify.py                    # IAQ data preprocessing (Python)
│   └── load_cognitive.py                 # Cognitive data preprocessing (Python)
```

---

## Data Description

### `merged_corrected_anonymised.csv`

One row per session (138 rows total). Key columns:

| Column | Description |
|--------|-------------|
| `participant_id` | Anonymous UUID per participant |
| `condition` | `dyson_on` or `no_purifier` |
| `grup` | Cohort (1.1–1.6) |
| `sex`, `varsta`, `an_studiu` | Demographics |
| `somn_ore`, `oboseala`, `stres` | Pre-test confounders |
| `RT_simple_median` | Simple reaction time (ms) |
| `RT_choice_median` | Choice reaction time (ms) |
| `Stroop_interference_RT` | Stroop interference score (ms) |
| `Nback_1_dprime_recalc` | N-back 1-back d' (Signal Detection Theory) |
| `Nback_2_dprime_recalc` | N-back 2-back d' |
| `Nback_3_dprime_recalc` | N-back 3-back d' |
| `iaq_CO2_ppm_mean` | Mean CO₂ during session (ppm) |
| `iaq_PM25_ugm3_mean` | Mean PM₂.₅ during session (µg/m³) |
| `iaq_NO2_ugm3_mean` | Mean NO₂ during session (µg/m³) |
| `iaq_t_celsius_mean` | Mean temperature (°C) |

> **Note:** Columns `nume`, `prenume`, and `matricol` have been removed
> to comply with GDPR. The `participant_id` UUID is sufficient for
> within-subject matching.

### `table_paired_results.csv`

Summary of paired t-tests (67 matched pairs) for all 8 cognitive outcomes.
Includes mean, SD, t-statistic, degrees of freedom, p-value, and Cohen's d.

### `table_correlations.csv`

Pearson correlations between IAQ variables and cognitive outcomes
across all sessions (n = 131 for most variables).

---

## Requirements

### R (statistical analysis)
```r
install.packages(c("tidyverse", "effectsize", "ggpubr"))
```
Tested with R 4.3+.

### Python (preprocessing)
```bash
pip install pandas numpy scipy openpyxl
```
Tested with Python 3.10+.

---

## How to Run

### Statistical analysis (R)
1. Clone this repository
2. Open RStudio and set working directory to the `data/` folder
3. Open `scripts/analyze_iaq_cognition_corrected.R`
4. Press **Source** — outputs saved to `figures/`

### Preprocessing (Python)
The Python scripts are provided for transparency. The preprocessed output
is already included in `merged_corrected_anonymised.csv`.

```bash
# IAQ preprocessing
python scripts/load_airify.py

# Cognitive data preprocessing
python scripts/load_cognitive.py
```

---

## Key Results

| Outcome | Dyson ON | No purifier | p | Cohen's d |
|---------|----------|-------------|---|-----------|
| Simple RT (ms) | 281.0 ± 34.2 | 289.9 ± 43.6 | 0.019 | −0.294 |
| N-back d' 3-back | 2.93 ± 2.63 | 1.90 ± 3.48 | 0.011 | +0.525 |

Full results in `data/table_paired_results.csv`.

---

## IAQ Conditions

| Parameter | Dyson ON | No purifier |
|-----------|----------|-------------|
| PM₂.₅ (µg/m³) | 7.2 | 14.1 |
| NO₂ (µg/m³) | 112 | 152 |
| CO₂ (ppm)* | 1467 | 2403 |

*CO₂ comparison valid for Group B only (sensor saturation in Groups C–F
during no-purifier sessions).

---

## Citation

If you use this dataset or code, please cite:

```
B.-L. Blajovan, C. Stângaciu, D. Stanescu, R. Bogdan, and M. Marcu,
"Air Quality Improvement and Cognitive Performance:
A Multi-Sensor IoT Classroom Study,"
in Proc. ICSTCC 2025, Timișoara, Romania.
```

DOI: *to be assigned upon publication*

---

## License

Data: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
Code: [MIT License](https://opensource.org/licenses/MIT)
