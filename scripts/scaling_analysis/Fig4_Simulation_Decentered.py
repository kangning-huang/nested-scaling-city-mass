#!/usr/bin/env python3
"""
Fig4_Simulation_Decentered.py
=============================
Figure 4: Emergence of sub-linear city-level scaling (β < 1) from
generalized Zipf (power-law) neighbourhood population distributions.

Uses deterministic Zipf ranking (weights = 1/rank^s) consistent with
the original simulation framework. The CSN statistical test (R1#7)
confirms that neighbourhood populations follow power-law distributions
significantly better than lognormal (Vuong R=18.2, p<0.001). The
generalized Zipf distribution with empirically estimated s captures
this power-law disparity.

Three panels
------------
A  (top-left)     : Histogram of per-city Zipf exponent s
B  (bottom-left)  : Boxplot – observed vs simulated country-level β
C  (right, spans) : β(s) curve with IQR uncertainty band

Usage
-----
    python Fig4_Simulation_Decentered.py

Outputs
-------
    _Revision1/data/zipf_s_estimates_resolution6.csv
    _Revision1/figures/Fig4_combined_decentered.pdf
    _Revision1/figures/Fig4_combined_decentered.png
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
from pathlib import Path
from multiprocessing import Pool, cpu_count
import sys

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent          # 0.CleanProject_GlobalScaling
REVISION_DIR = SCRIPT_DIR.parent                  # _Revision1

# Prefer local, self-contained processed data copies
NBHD_DATA = REVISION_DIR / "data" / "processed" / \
    "mass_avg_Li2022_vs_Liu2024_H3_grids_world.csv"
CITY_DATA = REVISION_DIR / "data" / "processed" / "MasterMass_ByClass20250616.csv"

OUT_S_CSV   = REVISION_DIR / "data" / "zipf_s_estimates.csv"
OUT_FIG_PDF = REVISION_DIR / "figures" / "Fig4_combined_decentered.pdf"
OUT_FIG_PNG = REVISION_DIR / "figures" / "Fig4_combined_decentered.png"

# ---------------------------------------------------------------------------
# Key parameters
# ---------------------------------------------------------------------------
DELTA = 0.751          # Neighbourhood-level scaling exponent (from Fig3)
BETA_OBSERVED = 0.899  # City-level scaling exponent (from Fig2)

# Minimum cells for rank-size regression
MIN_CELLS = 5


# ===================================================================
# Step 1 — Per-city Zipf exponent s (rank-size regression)
# ===================================================================

def estimate_zipf_s(values, min_cells=5):
    """
    Estimate generalized Zipf exponent s via rank-size regression:
        log(size) = const − s · log(rank)

    Returns s (positive) and the number of valid cells.
    """
    vals = np.asarray(values, dtype=float)
    vals = vals[vals > 0]
    n = len(vals)
    if n < min_cells:
        return np.nan, n
    sorted_vals = np.sort(vals)[::-1]
    ranks = np.arange(1, n + 1)
    slope, _ = np.polyfit(np.log(ranks), np.log(sorted_vals), 1)
    return -slope, n


def estimate_per_city_s(df, city_col="city_id", pop_col="population"):
    """Estimate Zipf s for each city and return a DataFrame."""
    records = []
    for city_id, grp in df.groupby(city_col):
        pops = grp[pop_col].values
        s, n_cells = estimate_zipf_s(pops)
        if np.isnan(s) or s <= 0:
            continue
        records.append({
            "city_id": city_id,
            "n_neighborhoods": n_cells,
            "city_population": pops.sum(),
            "s_estimate": s,
        })
    return pd.DataFrame(records)


# ===================================================================
# Step 2 — Simulation: β(s) via deterministic Zipf ranking
# ===================================================================

def simulate_beta_zipf(delta, s, n_cities=3000,
                       mean_neigh_size=8000, seed=42):
    """
    Simulate city-level β using deterministic Zipf ranking.

    For each city:
        1. Draw city pop P_c log-uniformly in [5e4, 2e7]
        2. K = max(5, P_c / mean_neigh_size) neighbourhoods
        3. weights = 1 / rank^s  (generalized Zipf)
        4. n_i = P_c * weight_i / Σweights
        5. City mass M = Σ n_i^δ
    OLS on log10(M) vs log10(P_c) → β
    """
    rng = np.random.default_rng(seed)
    city_pops = 10 ** rng.uniform(np.log10(5e4), np.log10(2e7), size=n_cities)
    city_masses = np.empty(n_cities)

    for i, Pc in enumerate(city_pops):
        n_cells = max(5, int(Pc / mean_neigh_size))
        ranks = np.arange(1, n_cells + 1)
        weights = 1.0 / ranks ** s
        neigh_pops = Pc * weights / weights.sum()
        city_masses[i] = (neigh_pops ** delta).sum()

    beta = np.polyfit(np.log10(city_pops), np.log10(city_masses), 1)[0]
    return beta


def _sweep_worker(args):
    """Worker for parallel β(s) sweep with country-level variation."""
    (s_val, delta, s_std, n_countries, total_cities,
     mean_neigh_size, seed) = args

    rng = np.random.default_rng(seed)

    # Distribute cities across countries (Dirichlet for realistic sizes)
    min_per_country = 3
    remaining = total_cities - n_countries * min_per_country
    alpha_dir = np.ones(n_countries) * 0.1
    country_weights = rng.dirichlet(alpha_dir)
    additional = (country_weights * remaining).astype(int)
    cities_per_country = min_per_country + additional
    cities_per_country[-1] += total_cities - cities_per_country.sum()

    # Generate all city populations
    all_city_pops = 10 ** rng.uniform(
        np.log10(5e4), np.log10(2e7), size=total_cities)

    # Per-country β
    betas = []
    idx = 0
    for nc in cities_per_country:
        if nc < 5:
            idx += nc
            continue
        cpops = all_city_pops[idx:idx + nc]
        idx += nc
        cmasses = []
        for Pc in cpops:
            s_city = max(sys.float_info.min, rng.normal(s_val, s_std))
            n_cells = max(5, int(Pc / mean_neigh_size))
            ranks = np.arange(1, n_cells + 1)
            w = 1.0 / ranks ** s_city
            neigh_pops = Pc * w / w.sum()
            cmasses.append((neigh_pops ** delta).sum())
        try:
            beta = np.polyfit(np.log10(cpops), np.log10(cmasses), 1)[0]
            betas.append(beta)
        except (np.linalg.LinAlgError, ValueError):
            continue
    return betas


def sweep_beta_vs_s(delta, s_values, s_std=0.59,
                    n_countries=200, total_cities=3000,
                    mean_neigh_size=8000, n_iterations=5,
                    n_processes=None):
    """
    For each s, simulate country-level β values across iterations.
    Returns mean, p25, p75 of per-country β at each s.
    """
    if n_processes is None:
        n_processes = min(cpu_count(), 8)

    tasks = []
    for s_val in s_values:
        for it in range(n_iterations):
            seed = int(s_val * 1e6) + it * 1000
            tasks.append((s_val, delta, s_std, n_countries, total_cities,
                          mean_neigh_size, seed))

    with Pool(processes=n_processes) as pool:
        results = pool.map(_sweep_worker, tasks)

    means = np.empty(len(s_values))
    p25 = np.empty(len(s_values))
    p75 = np.empty(len(s_values))
    for i in range(len(s_values)):
        all_betas = []
        for it in range(n_iterations):
            all_betas.extend(results[i * n_iterations + it])
        all_betas = np.array(all_betas)
        means[i] = np.mean(all_betas)
        p25[i] = np.percentile(all_betas, 25)
        p75[i] = np.percentile(all_betas, 75)
    return means, p25, p75


# ===================================================================
# Step 3 — Observed country-level β
# ===================================================================

def observed_country_betas(city_df, pop_col="population_2015",
                           mass_col="total_built_mass_tons",
                           country_col="CTR_MN_NM",
                           min_pop=50_000, min_cities=5):
    """OLS β per country from city-level data (observed)."""
    df = city_df.dropna(subset=[pop_col, mass_col]).copy()
    df = df[df[pop_col] > min_pop]
    betas = {}
    for country, grp in df.groupby(country_col):
        if len(grp) < min_cities:
            continue
        x = np.log10(grp[pop_col].values)
        y = np.log10(grp[mass_col].values)
        beta = np.polyfit(x, y, 1)[0]
        betas[country] = beta
    return betas


def simulated_country_betas(delta, s_mean, s_std,
                            n_countries=75, total_cities=3000,
                            mean_neigh_size=8000,
                            n_iterations=5, seed=42):
    """Simulate country-level β using Zipf ranking with s uncertainty."""
    tasks = [(s_mean, delta, s_std, n_countries, total_cities,
              mean_neigh_size, seed + it * 1000)
             for it in range(n_iterations)]

    n_processes = min(cpu_count(), 8)
    with Pool(processes=n_processes) as pool:
        results = pool.map(_sweep_worker, tasks)

    all_betas = []
    for r in results:
        all_betas.extend(r)
    return np.array(all_betas)


# ===================================================================
# Step 4 — Three-panel figure
# ===================================================================

def make_figure(s_df, obs_betas_dict, sim_betas,
                s_sweep, beta_mean, beta_p25, beta_p75,
                s_observed):
    """Create the combined 3-panel figure."""

    fig_height = 6
    fig = plt.figure(figsize=(fig_height * 1.7, fig_height))
    gs = GridSpec(2, 2, width_ratios=[1, 2], height_ratios=[1, 1],
                  hspace=0.35, wspace=0.30)
    ax_a = fig.add_subplot(gs[0, 0])
    ax_b = fig.add_subplot(gs[1, 0])
    ax_c = fig.add_subplot(gs[:, 1])

    # --- Panel A: s histogram ---
    s_vals = s_df["s_estimate"].values
    ax_a.hist(s_vals, bins=40, edgecolor="black", color="lightgrey",
              linewidth=0.5)
    mean_s = np.mean(s_vals)
    ax_a.axvline(mean_s, color="orange", ls="--", lw=1.5,
                 label=f"Mean = {mean_s:.2f}")
    ax_a.set_xlabel("Across-neighborhood Disparity (s)")
    ax_a.set_ylabel("Number of cities")
    ax_a.set_xlim(0, 3)
    ax_a.legend(fontsize=8, loc="upper right")
    ax_a.set_title("A", fontweight="bold", loc="left", fontsize=12)

    # --- Panel B: Observed vs Simulated boxplot ---
    obs_vals = np.array(list(obs_betas_dict.values()))
    data_bp = [obs_vals, sim_betas]
    labels_bp = ["Observed", "Simulated"]
    bp = ax_b.boxplot(data_bp, tick_labels=labels_bp, patch_artist=True,
                      boxprops=dict(facecolor="none", edgecolor="black"),
                      medianprops=dict(color="black"),
                      showfliers=False)
    for i, (d, col, alph) in enumerate(zip(
            data_bp, ["orange", "steelblue"], [0.5, 0.05])):
        x_jitter = np.random.default_rng(0).normal(i + 1, 0.04, len(d))
        ax_b.scatter(x_jitter, d, alpha=alph, color=col, s=12, zorder=3)
    ax_b.set_ylabel("Scaling exponent β")
    ax_b.set_ylim(0.6, 1.1)
    ax_b.set_title("B", fontweight="bold", loc="left", fontsize=12)

    # --- Panel C: β(s) curve ---
    ax_c.fill_between(s_sweep, beta_p25, beta_p75,
                      color="steelblue", alpha=0.25, label="IQR (25–75%)")
    ax_c.plot(s_sweep, beta_mean, color="steelblue", lw=2,
              label="Theoretical β")
    # Reference lines
    ax_c.axhline(DELTA, color="orange", ls="--", lw=2,
                 label=f"δ = {DELTA}")
    ax_c.axhline(1.0, color="orange", ls="--", lw=2, alpha=0.7,
                 label="β = 1 (linear)")
    # Observed point
    ax_c.scatter(s_observed, BETA_OBSERVED, color="orange", s=100,
                 zorder=5, label="Observed")
    ax_c.text(s_observed - 0.08, BETA_OBSERVED,
              f"  (s={s_observed:.2f}, β={BETA_OBSERVED})",
              fontsize=9, ha="right", va="bottom")
    ax_c.set_xlabel("Across-neighborhood Disparity (s)")
    ax_c.set_ylabel("Across-city Scaling Coef β")
    ax_c.set_xscale("log", base=2)
    # y-limits with padding
    y_range = 1.0 - DELTA
    ax_c.set_ylim(DELTA - 0.07 * y_range, 1.0 + 0.07 * y_range)
    ax_c.legend(fontsize=7, loc="upper right",
                bbox_to_anchor=(1, 0.9))
    ax_c.set_title("C", fontweight="bold", loc="left", fontsize=12)

    return fig


# ===================================================================
# Main
# ===================================================================

def main():
    print("=" * 60)
    print("Fig4: Generalized Zipf simulation (rank-size)")
    print("=" * 60)

    # ------------------------------------------------------------------
    # Load neighbourhood data
    # ------------------------------------------------------------------
    print("\n[1/5] Loading neighbourhood data …")
    nbhd = pd.read_csv(NBHD_DATA, usecols=["city_id", "population"])
    n_raw = len(nbhd)
    n_cities = nbhd["city_id"].nunique()
    print(f"  {n_raw:,} neighbourhoods, {n_cities} cities")

    # ------------------------------------------------------------------
    # Step 1: Per-city s
    # ------------------------------------------------------------------
    print("\n[2/5] Estimating per-city Zipf s (rank-size) …")
    s_df = estimate_per_city_s(nbhd, city_col="city_id", pop_col="population")
    s_df = s_df.dropna(subset=["s_estimate"])
    s_mean = s_df["s_estimate"].mean()
    s_median = s_df["s_estimate"].median()
    s_std = s_df["s_estimate"].std()
    print(f"  {len(s_df)} cities with valid s")
    print(f"  s: mean={s_mean:.3f}, median={s_median:.3f}, std={s_std:.3f}")

    OUT_S_CSV.parent.mkdir(parents=True, exist_ok=True)
    s_df.to_csv(OUT_S_CSV, index=False)
    print(f"  Saved → {OUT_S_CSV}")

    # ------------------------------------------------------------------
    # Step 2: β(s) sweep
    # ------------------------------------------------------------------
    print("\n[3/5] Sweeping β vs s (Zipf ranking, country-level IQR) …")
    s_sweep = np.logspace(np.log10(0.33), np.log10(4.0), 50)
    beta_mean_arr, beta_p25, beta_p75 = sweep_beta_vs_s(
        DELTA, s_sweep, s_std=s_std,
        n_countries=200, total_cities=3000,
        mean_neigh_size=8000, n_iterations=5)
    print(f"  β range: {beta_mean_arr.min():.3f} – {beta_mean_arr.max():.3f}")

    # ------------------------------------------------------------------
    # Step 3: Observed & simulated country-level β
    # ------------------------------------------------------------------
    print("\n[4/5] Computing observed & simulated country-level β …")
    city_df = pd.read_csv(CITY_DATA)
    obs_betas = observed_country_betas(city_df)
    print(f"  Observed: {len(obs_betas)} countries")

    sim_betas = simulated_country_betas(
        DELTA, s_mean, s_std,
        n_countries=len(obs_betas), total_cities=3000,
        n_iterations=5, seed=42)
    print(f"  Simulated: {len(sim_betas)} country-level β values")
    print(f"  Simulated β: mean={sim_betas.mean():.3f}, "
          f"median={np.median(sim_betas):.3f}")

    # ------------------------------------------------------------------
    # Step 4: Figure
    # ------------------------------------------------------------------
    print("\n[5/5] Creating figure …")
    fig = make_figure(s_df, obs_betas, sim_betas,
                      s_sweep, beta_mean_arr, beta_p25, beta_p75,
                      s_mean)

    OUT_FIG_PDF.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT_FIG_PDF, dpi=300, bbox_inches="tight")
    fig.savefig(OUT_FIG_PNG, dpi=300, bbox_inches="tight")
    print(f"  Saved → {OUT_FIG_PDF}")
    print(f"  Saved → {OUT_FIG_PNG}")
    plt.close(fig)

    # ------------------------------------------------------------------
    # Verification
    # ------------------------------------------------------------------
    print("\n" + "=" * 60)
    print("Verification")
    print("=" * 60)
    print(f"  Per-city s: mean={s_mean:.3f}, median={s_median:.3f}, std={s_std:.3f}")
    obs_arr = np.array(list(obs_betas.values()))
    print(f"  Observed country β: mean={obs_arr.mean():.3f}, "
          f"median={np.median(obs_arr):.3f}")
    print(f"  Simulated country β: mean={sim_betas.mean():.3f}, "
          f"median={np.median(sim_betas):.3f}")
    # Spot check
    beta_at_s = simulate_beta_zipf(DELTA, s_mean, seed=0)
    print(f"  β(s={s_mean:.2f}) = {beta_at_s:.3f}  (observed β={BETA_OBSERVED})")
    print("Done.\n")


if __name__ == "__main__":
    main()
