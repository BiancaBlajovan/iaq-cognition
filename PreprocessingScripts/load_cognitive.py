# load_cognitive.py
# Preprocessing pentru datele cognitive exportate din PsyToolkit
# Input:  TEST_10_DECEMBRIE_COMPLET.xlsx sau TEST_17_DECEMBRIE_COMPLET.xlsx
# Output: df_cognitive (un rand per participant)
#
# Instalare dependinte: pip install pandas numpy scipy openpyxl

import pandas as pd
import numpy as np
from scipy.stats import norm


# Confounderi din chestionarul pre-test (Survey Data sheet)
CONFOUNDERS = [
    "somn_ore",      # ore de somn noaptea anterioara
    "oboseala",      # scala 1-7
    "stres",         # scala 1-7
    "cafea_recent",  # da/nu
    "cafea_nr",      # cantitate
    "varsta",
    "sex",
]


def dprime(hit_rate, fa_rate, epsilon=0.01):
    """
    Calculeaza indicele de sensibilitate d' din Signal Detection Theory.

    d' = Phi^{-1}(hit_rate) - Phi^{-1}(false_alarm_rate)

    Parametri
    ---------
    hit_rate : float sau pd.Series
        Proportia de raspunsuri corecte la stimuli tinta.
    fa_rate : float sau pd.Series
        Proportia de false alarme (raspuns la stimuli non-tinta).
    epsilon : float
        Valoare de clipping pentru a evita Phi^{-1}(0) = -inf
        si Phi^{-1}(1) = +inf. Default 0.01.

    Returneaza
    ----------
    float sau pd.Series cu valorile d'.
    """
    hr = np.clip(hit_rate, epsilon, 1 - epsilon)
    fa = np.clip(fa_rate,  epsilon, 1 - epsilon)
    return norm.ppf(hr) - norm.ppf(fa)


def load_cognitive(xlsx_path, verbose=True):
    """
    Incarca, curata si imbina datele cognitive din fisierul XLSX procesat.

    Parametri
    ---------
    xlsx_path : str
        Calea catre fisierul TEST_*_COMPLET.xlsx.
    verbose : bool
        Daca True, printeaza un sumar al pasilor.

    Returneaza
    ----------
    df : pd.DataFrame
        Un rand per participant, cu scoruri cognitive + confounderi.
        Contine coloana Nback_dprime_recalc calculata din hit/FA rate.
    """

    if verbose:
        print(f"[load_cognitive] {xlsx_path}")

    # ── Pas 1: citeste sheet-urile relevante ─────────────────────────────────
    xl = pd.ExcelFile(xlsx_path)

    if verbose:
        print(f"  Sheet-uri disponibile: {xl.sheet_names}")

    cog    = pd.read_excel(xlsx_path, sheet_name="Complete Data")
    survey = pd.read_excel(xlsx_path, sheet_name="Survey Data")

    if verbose:
        print(f"  Complete Data: {len(cog)} participanti, {len(cog.columns)} coloane")
        print(f"  Survey Data:   {len(survey)} participanti")

    # ── Pas 2: merge scoruri + confounderi pe participant_id ─────────────────
    conf_available = [c for c in CONFOUNDERS if c in survey.columns]
    df = cog.merge(
        survey[["participant_id"] + conf_available],
        on="participant_id",
        how="left",
        suffixes=("", "_survey")
    )

    if verbose:
        print(f"  Confounderi adaugati: {conf_available}")

    # ── Pas 3: recalculare d' din hit rate si false alarm rate ───────────────
    if {"Nback_1_hit_rate", "Nback_1_fa_rate"}.issubset(df.columns):
        df["Nback_dprime_recalc"] = dprime(
            df["Nback_1_hit_rate"],
            df["Nback_1_fa_rate"]
        )
        if verbose:
            valid = df["Nback_dprime_recalc"].notna().sum()
            print(f"  d' recalculat pentru {valid} participanti")
            print(f"  d' mean = {df['Nback_dprime_recalc'].mean():.3f}, "
                  f"sd = {df['Nback_dprime_recalc'].std():.3f}")
    else:
        if verbose:
            print("  ATENTIE: coloanele Nback_1_hit_rate / Nback_1_fa_rate "
                  "nu exista in acest fisier — d' nu a putut fi recalculat.")

    n_before = len(df)

    # ── Pas 4a: excludere RT imposibile ─────────────────────────────────────
    if "RT_simple_median" in df.columns:
        df = df[df["RT_simple_median"].between(100, 1200)]
        n_rt = n_before - len(df)
        if verbose:
            print(f"  Exclusi RT out of range [100, 1200 ms]: {n_rt} participanti")

    # ── Pas 4b: excludere N-back sub sansa ──────────────────────────────────
    n_before2 = len(df)
    if "Nback_overall_accuracy" in df.columns:
        df = df[df["Nback_overall_accuracy"] >= 0.25]
        n_nback = n_before2 - len(df)
        if verbose:
            print(f"  Exclusi N-back accuracy < 0.25: {n_nback} participanti")

    if verbose:
        print(f"  Participanti ramasi: {len(df)}")

    # ── Pas 5: sumar variabile cheie ─────────────────────────────────────────
    if verbose:
        key_vars = [
            "RT_simple_median", "RT_choice_median",
            "Stroop_interference_RT",
            "Nback_dprime_recalc", "Nback_overall_accuracy"
        ]
        key_vars = [v for v in key_vars if v in df.columns]
        print("\n  Sumar variabile cognitive:")
        print(df[key_vars].describe().round(3).to_string())
        print()

    return df


# ── Rulare directa ────────────────────────────────────────────────────────────
if __name__ == "__main__":

    sessions = {
        "Session A — Dec 8 (Dyson ON)":
            "TEST_10_DECEMBRIE_COMPLET.xlsx",
        "Session B — Dec 15 (No purifier)":
            "TEST_17_DECEMBRIE_COMPLET.xlsx",
    }

    dfs = {}
    for label, path in sessions.items():
        print(f"\n{'='*60}")
        print(f"{label}")
        print('='*60)
        try:
            df = load_cognitive(path)
            dfs[label] = df
        except FileNotFoundError:
            print(f"  EROARE: fisierul '{path}' nu a fost gasit.")
            print(f"  Asigura-te ca rulezi scriptul din acelasi folder cu XLSX-urile.")

    # Comparatie rapida intre sesiuni
    if len(dfs) == 2:
        labels = list(dfs.keys())
        df_a = dfs[labels[0]]
        df_b = dfs[labels[1]]

        compare_vars = [
            "RT_simple_median", "RT_choice_median",
            "Stroop_interference_RT",
            "Nback_dprime_recalc", "Nback_overall_accuracy"
        ]

        print(f"\n{'='*60}")
        print("Comparatie medii intre sesiuni")
        print('='*60)
        print(f"  {'Variabila':<30} {'Session A':>12} {'Session B':>12}")
        print(f"  {'-'*56}")
        for var in compare_vars:
            if var in df_a.columns and var in df_b.columns:
                m_a = df_a[var].mean()
                m_b = df_b[var].mean()
                print(f"  {var:<30} {m_a:>12.3f} {m_b:>12.3f}")
