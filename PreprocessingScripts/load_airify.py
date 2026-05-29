# load_airify.py
# Preprocessing pentru datele de mediu exportate de Airify
# Input:  airify_deviceData_8Dec.csv sau airify_deviceData_15Dec_modified.csv
# Output: (summary_df, n_readings)
#
# Instalare dependinte: pip install pandas numpy

import pandas as pd
import numpy as np


# Coloanele *_Processed contin valorile calibrate (MLR/RF Ionascu et al. 2021)
IAQ_COLS = {
    "CO2_Processed":  "CO2_ppm",
    "PM1_Processed":  "PM1_ugm3",
    "PM25_Processed": "PM25_ugm3",
    "PM10_Processed": "PM10_ugm3",
    "NO2_Processed":  "NO2_ugm3",
    "CO_Processed":   "CO_ugm3",
}


def flag_outliers(series, k=3.0):
    """
    Returneaza un boolean Series — True acolo unde valoarea e outlier.
    Criteriu IQR conservator (k=3): elimina doar aberatii clare,
    nu varfurile reale de CO2 din aglomeratie.
    """
    q1 = series.quantile(0.25)
    q3 = series.quantile(0.75)
    iqr = q3 - q1
    return (series < q1 - k * iqr) | (series > q3 + k * iqr)


def load_airify(csv_path, k_iqr=3.0, verbose=True):
    """
    Incarca, curata si sumarizeaza datele Airify.

    Parametri
    ---------
    csv_path : str
        Calea catre fisierul CSV exportat de Airify (98 coloane).
    k_iqr : float
        Pragul IQR pentru outlier removal (default 3.0 = conservator).
    verbose : bool
        Daca True, printeaza un sumar al pasilor de curatare.

    Returneaza
    ----------
    summary : pd.DataFrame
        Tabel cu mean, sd, min, max pentru fiecare parametru IAQ.
        Indexat pe numele parametrilor (CO2_ppm, PM25_ugm3 etc.)
    n_readings : int
        Numarul de inregistrari ramase dupa curatare.
    df_clean : pd.DataFrame
        Dataframe complet curatat (pentru time-series plots).
    """

    # ── Pas 1: citire si sortare cronologica ─────────────────────────────────
    df = pd.read_csv(csv_path, parse_dates=["timestamp"])
    df = df.sort_values("timestamp").reset_index(drop=True)
    n_raw = len(df)

    if verbose:
        print(f"[load_airify] {csv_path}")
        print(f"  Citit: {n_raw} inregistrari, {len(df.columns)} coloane")
        print(f"  Interval: {df['timestamp'].iloc[0]} → {df['timestamp'].iloc[-1]}")

    # ── Pas 2: conversii de unitati ──────────────────────────────────────────
    # Airify stocheaza t si rh ca intregi * 100
    df["t_celsius"] = df["t"]  / 100.0
    df["rh_pct"]    = df["rh"] / 100.0

    # Redenumeste coloanele *_Processed in nume lizibile
    df = df.rename(columns=IAQ_COLS)

    # ── Pas 3: filtru fizic (valori imposibile) ───────────────────────────────
    n_before = len(df)
    df = df[df["CO2_ppm"].between(400, 6000)]
    df = df[df["PM25_ugm3"] >= 0]
    df = df[df["t_celsius"].between(10, 40)]
    df = df[df["rh_pct"].between(0, 100)]
    n_physical = n_before - len(df)

    if verbose:
        print(f"  Excluse filtru fizic: {n_physical} inregistrari")

    # ── Pas 4: IQR outlier removal ───────────────────────────────────────────
    n_before = len(df)
    for col in ["CO2_ppm", "PM25_ugm3", "NO2_ugm3"]:
        if col in df.columns:
            df = df[~flag_outliers(df[col], k=k_iqr)]
    n_iqr = n_before - len(df)

    if verbose:
        print(f"  Excluse IQR (k={k_iqr}): {n_iqr} inregistrari")
        print(f"  Ramas: {len(df)} inregistrari curate")

    # ── Pas 5: sumar statistic ───────────────────────────────────────────────
    summary_cols = list(IAQ_COLS.values()) + ["t_celsius", "rh_pct"]
    summary_cols = [c for c in summary_cols if c in df.columns]

    summary = (
        df[summary_cols]
        .agg(["mean", "std", "min", "max"])
        .T
        .rename(columns={"std": "sd"})
    )
    summary = summary.round(3)

    if verbose:
        print("\n  Sumar IAQ (valori calibrate):")
        print(summary.to_string())
        print()

    return summary, len(df), df


# ── Rulare directa ────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import sys

    sessions = {
        "Session A — Dec 8 (Dyson ON)":
            "airify_deviceData_8Dec.csv",
        "Session B — Dec 15 (No purifier)":
            "airify_deviceData_15Dec_modified.csv",
    }

    results = {}
    for label, path in sessions.items():
        print(f"\n{'='*60}")
        print(f"{label}")
        print('='*60)
        try:
            summary, n, df_clean = load_airify(path)
            results[label] = (summary, n)
        except FileNotFoundError:
            print(f"  EROARE: fisierul '{path}' nu a fost gasit.")
            print(f"  Asigura-te ca rulezi scriptul din acelasi folder cu CSV-urile.")

    # Comparatie intre sesiuni
    if len(results) == 2:
        print(f"\n{'='*60}")
        print("Comparatie sesiuni (% reducere A→B)")
        print('='*60)
        labels = list(results.keys())
        s_a = results[labels[0]][0]
        s_b = results[labels[1]][0]
        for param in s_a.index:
            if param in s_b.index:
                mean_a = s_a.loc[param, "mean"]
                mean_b = s_b.loc[param, "mean"]
                if mean_a != 0:
                    pct = (mean_b - mean_a) / mean_a * 100
                    print(f"  {param:<15} {mean_a:>8.2f} → {mean_b:>8.2f}  ({pct:+.1f}%)")
