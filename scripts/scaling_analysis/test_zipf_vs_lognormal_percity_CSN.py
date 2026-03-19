"""
Per-City CSN Tests: Zipf (Power Law) vs Lognormal
==================================================
Runs Clauset-Shalizi-Newman MLE + Vuong likelihood ratio tests
per city for cities with enough neighborhoods.

Two datasets tested:
  A) Original data (Resolution ~6): cities with >= 50 neighborhoods
  B) Resolution 7 data (~0.11 km²): cities with >= 50 neighborhoods (more cities)

For each qualifying city, we:
  1. Fit power-law via MLE (find x_min, estimate α)
  2. Fit lognormal above x_min
  3. Vuong test: positive R → power law preferred

Output:
  figures/Table_PerCity_CSN_Results.csv
  figures/PerCity_CSN_Summary.pdf
"""

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scipy import stats
from scipy.special import erfc
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent
REVISION_DIR = SCRIPT_DIR.parent

# Prefer local, self-contained copies under _Revision1/data/processed
NBHD_ORIGINAL = REVISION_DIR / "data" / "processed" / \
    "mass_avg_Li2022_vs_Liu2024_H3_grids_world.csv"
NBHD_R7 = REVISION_DIR / "data" / "processed" / "h3_resolution7" / \
    "Fig3_Mass_Neighborhood_H3_Resolution7_2026-02-02.csv"

FIG_DIR = REVISION_DIR / "figures"
FIG_DIR.mkdir(parents=True, exist_ok=True)

MIN_NEIGHBORHOODS = 50   # Minimum for CSN to be reliable
MIN_TAIL = 20            # Minimum observations above x_min


# ---------------------------------------------------------------------------
# CSN functions (from original test_zipf_vs_lognormal.py)
# ---------------------------------------------------------------------------

def powerlaw_mle_alpha(data, xmin):
    """MLE estimate of power-law exponent for continuous data above xmin."""
    tail = data[data >= xmin]
    n = len(tail)
    if n < 2:
        return np.nan, np.nan
    alpha = 1 + n / np.sum(np.log(tail / xmin))
    se = (alpha - 1) / np.sqrt(n)
    return alpha, se


def powerlaw_ks(data, xmin):
    """KS distance between data and fitted power law above xmin."""
    tail = np.sort(data[data >= xmin])
    n = len(tail)
    if n < 2:
        return np.inf
    alpha, _ = powerlaw_mle_alpha(data, xmin)
    cdf_theory = 1 - (tail / xmin) ** (-(alpha - 1))
    cdf_empirical = np.arange(1, n + 1) / n
    return np.max(np.abs(cdf_theory - cdf_empirical))


def find_xmin(data, min_tail=MIN_TAIL, subsample=200):
    """Find optimal x_min by minimizing KS distance."""
    sorted_data = np.sort(np.unique(data))
    max_idx = int(0.9 * len(sorted_data))
    candidates = sorted_data[:max_idx]
    if len(candidates) > subsample:
        idx = np.linspace(0, len(candidates) - 1, subsample, dtype=int)
        candidates = candidates[idx]

    best_ks = np.inf
    best_xmin = sorted_data[0]
    best_alpha = np.nan

    for xmin in candidates:
        n_tail = np.sum(data >= xmin)
        if n_tail < min_tail:
            continue
        ks = powerlaw_ks(data, xmin)
        if ks < best_ks:
            best_ks = ks
            best_xmin = xmin
            best_alpha, _ = powerlaw_mle_alpha(data, xmin)

    return best_xmin, best_alpha, best_ks


def lognormal_mle(data, xmin):
    """MLE fit of lognormal to data above xmin."""
    tail = data[data >= xmin]
    log_tail = np.log(tail)
    mu = np.mean(log_tail)
    sigma = np.std(log_tail, ddof=1)
    return mu, sigma


def vuong_pl_vs_ln(data, xmin):
    """
    Vuong likelihood ratio test: power law vs lognormal above xmin.
    Returns (R, p): R > 0 favors power law.
    """
    tail = data[data >= xmin]
    n = len(tail)
    if n < 10:
        return np.nan, np.nan

    alpha, _ = powerlaw_mle_alpha(data, xmin)
    mu_ln, sigma_ln = lognormal_mle(data, xmin)

    # Per-observation log-likelihood ratio
    ll_pl = np.log(alpha - 1) - np.log(xmin) - alpha * np.log(tail / xmin)
    ll_ln = stats.lognorm.logpdf(tail, s=sigma_ln, scale=np.exp(mu_ln))

    lr = ll_pl - ll_ln
    mean_lr = np.mean(lr)
    std_lr = np.std(lr, ddof=1)

    if std_lr == 0:
        return 0.0, 1.0

    R = mean_lr * np.sqrt(n) / std_lr
    p = erfc(abs(R) / np.sqrt(2))
    return R, p


# ---------------------------------------------------------------------------
# Per-city CSN test
# ---------------------------------------------------------------------------

def run_percity_csn(df, city_col, pop_col, label, min_nbhds=MIN_NEIGHBORHOODS):
    """Run CSN power-law vs lognormal test for each qualifying city."""
    results = []
    cities_tested = 0
    cities_skipped_xmin = 0

    city_counts = df[df[pop_col] > 0].groupby(city_col).size()
    qualifying = city_counts[city_counts >= min_nbhds].index
    print(f"\n  {label}: {len(qualifying)} cities with >= {min_nbhds} neighborhoods")

    for city_id in qualifying:
        pops = df.loc[df[city_col] == city_id, pop_col].values
        pops = pops[pops > 0].astype(float)

        if len(pops) < min_nbhds:
            continue

        # Find x_min
        try:
            xmin, alpha, ks = find_xmin(pops, min_tail=MIN_TAIL)
        except:
            cities_skipped_xmin += 1
            continue

        n_tail = np.sum(pops >= xmin)
        if n_tail < MIN_TAIL or np.isnan(alpha):
            cities_skipped_xmin += 1
            continue

        # Vuong test
        R, p = vuong_pl_vs_ln(pops, xmin)
        if np.isnan(R):
            cities_skipped_xmin += 1
            continue

        cities_tested += 1

        # Also compute rank-size s for reference
        sorted_pops = np.sort(pops)[::-1]
        ranks = np.arange(1, len(pops) + 1)
        s_ranksize = -np.polyfit(np.log(ranks), np.log(sorted_pops), 1)[0]

        if p < 0.05:
            preferred = "power_law" if R > 0 else "lognormal"
        else:
            preferred = "inconclusive"

        results.append({
            "city_id": city_id,
            "n_neighborhoods": len(pops),
            "city_population": pops.sum(),
            "xmin": xmin,
            "alpha_mle": alpha,
            "n_tail": n_tail,
            "ks_distance": ks,
            "vuong_R": R,
            "vuong_p": p,
            "preferred": preferred,
            "s_ranksize": s_ranksize,
            "dataset": label,
        })

    print(f"    Cities tested: {cities_tested}")
    print(f"    Cities skipped (insufficient tail): {cities_skipped_xmin}")

    return pd.DataFrame(results)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    all_results = []

    # --- Dataset A: Original data ---
    print("=" * 60)
    print("Dataset A: Original neighbourhood data")
    print("=" * 60)
    df_orig = pd.read_csv(NBHD_ORIGINAL, usecols=["city_id", "population"])
    res_orig = run_percity_csn(df_orig, "city_id", "population",
                                "Original (Fig4 data)")
    all_results.append(res_orig)

    # --- Dataset B: Resolution 7 ---
    print("\n" + "=" * 60)
    print("Dataset B: Resolution 7 neighbourhoods")
    print("=" * 60)
    df_r7 = pd.read_csv(NBHD_R7, usecols=["ID_HDC_G0", "population_2015"])
    # Apply basic filters: pop > 0, city pop > 50k
    df_r7 = df_r7[df_r7["population_2015"] > 0].copy()
    city_pop_r7 = df_r7.groupby("ID_HDC_G0")["population_2015"].sum()
    big_cities = city_pop_r7[city_pop_r7 > 50000].index
    df_r7 = df_r7[df_r7["ID_HDC_G0"].isin(big_cities)].copy()
    print(f"  After pop>50k filter: {len(df_r7)} neighborhoods, "
          f"{df_r7['ID_HDC_G0'].nunique()} cities")

    res_r7 = run_percity_csn(df_r7, "ID_HDC_G0", "population_2015",
                              "Resolution 7")
    all_results.append(res_r7)

    # --- Combine and summarize ---
    combined = pd.concat(all_results, ignore_index=True)
    combined.to_csv(FIG_DIR / "Table_PerCity_CSN_Results.csv", index=False)
    print(f"\nSaved: {FIG_DIR / 'Table_PerCity_CSN_Results.csv'}")

    # --- Print summaries ---
    for label in combined["dataset"].unique():
        sub = combined[combined["dataset"] == label]
        n = len(sub)
        n_pl = (sub["preferred"] == "power_law").sum()
        n_ln = (sub["preferred"] == "lognormal").sum()
        n_inc = (sub["preferred"] == "inconclusive").sum()

        print(f"\n{'='*60}")
        print(f"SUMMARY: {label}")
        print(f"{'='*60}")
        print(f"  Cities tested:          {n}")
        print(f"  Power law preferred:    {n_pl} ({100*n_pl/n:.1f}%)")
        print(f"  Lognormal preferred:    {n_ln} ({100*n_ln/n:.1f}%)")
        print(f"  Inconclusive (p≥0.05):  {n_inc} ({100*n_inc/n:.1f}%)")
        print(f"  Vuong R: mean={sub['vuong_R'].mean():.2f}, "
              f"median={sub['vuong_R'].median():.2f}")
        print(f"  s (rank-size): mean={sub['s_ranksize'].mean():.3f}, "
              f"median={sub['s_ranksize'].median():.3f}")
        print(f"  α (MLE): mean={sub['alpha_mle'].mean():.3f}, "
              f"median={sub['alpha_mle'].median():.3f}")

    # --- Figure ---
    fig, axes = plt.subplots(2, 2, figsize=(12, 9))

    for row, label in enumerate(combined["dataset"].unique()):
        sub = combined[combined["dataset"] == label]

        # Left: Histogram of Vuong R
        ax = axes[row, 0]
        colors = ["#e74c3c" if r > 0 else "#2980b9" for r in sub["vuong_R"]]
        ax.hist(sub["vuong_R"], bins=30, color="steelblue", edgecolor="black",
                linewidth=0.5, alpha=0.8)
        ax.axvline(0, color="black", linestyle="--", linewidth=1)
        ax.axvline(sub["vuong_R"].median(), color="orange", linestyle="--",
                   linewidth=1.5, label=f'Median R = {sub["vuong_R"].median():.2f}')
        n_pl = (sub["preferred"] == "power_law").sum()
        n_ln = (sub["preferred"] == "lognormal").sum()
        n_inc = (sub["preferred"] == "inconclusive").sum()
        ax.set_xlabel("Vuong R (>0 = power law preferred)")
        ax.set_ylabel("Number of cities")
        ax.set_title(f"{label} (N={len(sub)})")
        ax.legend(fontsize=8)
        # Annotation
        ax.text(0.03, 0.95,
                f"PL: {n_pl} ({100*n_pl/len(sub):.0f}%)\n"
                f"LN: {n_ln} ({100*n_ln/len(sub):.0f}%)\n"
                f"Inc: {n_inc} ({100*n_inc/len(sub):.0f}%)",
                transform=ax.transAxes, va="top", fontsize=9,
                bbox=dict(boxstyle="round,pad=0.3", facecolor="wheat", alpha=0.8))

        # Right: Vuong R vs number of neighborhoods
        ax = axes[row, 1]
        ax.scatter(sub["n_neighborhoods"], sub["vuong_R"],
                   s=15, alpha=0.5, color="steelblue", edgecolors="none")
        ax.axhline(0, color="black", linestyle="--", linewidth=1)
        ax.set_xlabel("Number of neighborhoods")
        ax.set_ylabel("Vuong R")
        ax.set_title(f"{label}: R vs city size")

    plt.tight_layout()
    out = FIG_DIR / "PerCity_CSN_Summary.pdf"
    fig.savefig(out, dpi=300, bbox_inches="tight")
    out_png = FIG_DIR / "PerCity_CSN_Summary.png"
    fig.savefig(out_png, dpi=200, bbox_inches="tight")
    plt.close()
    print(f"\nSaved: {out}")
    print(f"Saved: {out_png}")


if __name__ == "__main__":
    main()
