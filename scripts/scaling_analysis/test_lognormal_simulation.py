"""
Test: Can the Figure 4 simulation work with lognormal distributions?
====================================================================
Per-city R² comparison showed lognormal fits within-city neighborhood
populations better than Zipf (95% of cities). This script tests whether
the emergence mechanism (β < 1 from neighbourhood disparity) works
with lognormal draws parameterized by σ (std of log-values).

Steps:
  1. Estimate per-city σ (std of log-population across neighborhoods)
  2. Simulate β(σ) curve using lognormal neighborhood populations
  3. Check whether observed (σ, β) falls on the theoretical curve
  4. Compare with the Zipf-based simulation

Output:
  Console summary + test figure
"""

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scipy import stats
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent
REVISION_DIR = SCRIPT_DIR.parent

NBHD_DATA = PROJECT_ROOT / "data" / "processed" / \
    "mass_avg_Li2022_vs_Liu2024_H3_grids_world.csv"
CITY_DATA = PROJECT_ROOT / "data" / "processed" / "MasterMass_ByClass20250616.csv"

FIG_DIR = REVISION_DIR / "figures"
FIG_DIR.mkdir(parents=True, exist_ok=True)

DELTA = 0.751
BETA_OBSERVED = 0.899
MIN_CELLS = 5


# ---------------------------------------------------------------------------
# Step 1: Estimate per-city σ (lognormal disparity parameter)
# ---------------------------------------------------------------------------

def estimate_per_city_sigma(df, city_col="city_id", pop_col="population",
                            min_cells=MIN_CELLS):
    """
    For each city, compute σ = std(log(pop)) across neighborhoods.
    This is the lognormal disparity parameter.
    """
    records = []
    for city_id, grp in df.groupby(city_col):
        pops = grp[pop_col].values
        pops = pops[pops > 0]
        n = len(pops)
        if n < min_cells:
            continue
        log_pops = np.log(pops)
        sigma = np.std(log_pops, ddof=1)
        mu = np.mean(log_pops)
        records.append({
            "city_id": city_id,
            "n_neighborhoods": n,
            "city_population": pops.sum(),
            "sigma": sigma,
            "mu": mu,
        })
    return pd.DataFrame(records)


# ---------------------------------------------------------------------------
# Step 2: Simulate β(σ) using lognormal neighborhood populations
# ---------------------------------------------------------------------------

def simulate_beta_lognormal(delta, sigma, n_cities=3000,
                            mean_neigh_size=8000, seed=42):
    """
    Simulate city-level scaling exponent β using lognormal neighborhoods.

    For each city:
      1. Determine K = P_city / mean_neigh_size neighborhoods
      2. Draw K values from LogNormal(0, σ²)
      3. Rescale so they sum to P_city
      4. City mass M = Σ n_i^δ

    OLS on log10(M) vs log10(P) across cities → β
    """
    rng = np.random.default_rng(seed)

    # City populations: uniform in log-space
    city_pops = 10 ** rng.uniform(np.log10(5e4), np.log10(2e7), size=n_cities)
    city_masses = np.empty(n_cities)

    for i, Pc in enumerate(city_pops):
        K = max(5, int(Pc / mean_neigh_size))

        # Draw from lognormal with given σ
        raw = rng.lognormal(mean=0, sigma=sigma, size=K)

        # Rescale to sum to city population
        neigh_pops = Pc * raw / raw.sum()

        # City mass = sum of neighborhood masses
        city_masses[i] = (neigh_pops ** delta).sum()

    # OLS in log-space
    log_pop = np.log10(city_pops)
    log_mass = np.log10(city_masses)
    beta = np.polyfit(log_pop, log_mass, 1)[0]
    return beta


def simulate_beta_lognormal_with_uncertainty(delta, sigma, sigma_std,
                                              n_countries=200,
                                              n_iterations=10, seed=42):
    """
    Like simulate_beta_lognormal but with per-city σ drawn from
    N(sigma, sigma_std²), then group into countries for β distribution.
    """
    rng = np.random.default_rng(seed)
    all_country_betas = []

    for it in range(n_iterations):
        n_cities = 3000
        city_pops = 10 ** rng.uniform(np.log10(5e4), np.log10(2e7), size=n_cities)
        city_masses = np.empty(n_cities)

        for i, Pc in enumerate(city_pops):
            K = max(5, int(Pc / 8000))
            # Per-city σ drawn from normal
            sig_i = max(0.1, rng.normal(sigma, sigma_std))
            raw = rng.lognormal(mean=0, sigma=sig_i, size=K)
            neigh_pops = Pc * raw / raw.sum()
            city_masses[i] = (neigh_pops ** delta).sum()

        # Assign to countries
        country_ids = rng.integers(0, n_countries, size=n_cities)
        log_pop = np.log10(city_pops)
        log_mass = np.log10(city_masses)

        for c in range(n_countries):
            mask = country_ids == c
            if mask.sum() >= 5:
                beta_c = np.polyfit(log_pop[mask], log_mass[mask], 1)[0]
                all_country_betas.append(beta_c)

    all_country_betas = np.array(all_country_betas)
    return (np.mean(all_country_betas), np.std(all_country_betas),
            np.median(all_country_betas), all_country_betas)


# ---------------------------------------------------------------------------
# Step 3: Zipf simulation for comparison (from Fig4)
# ---------------------------------------------------------------------------

def simulate_beta_zipf(delta, s, n_cities=3000,
                       mean_neigh_size=8000, seed=42):
    """Deterministic Zipf ranking simulation."""
    rng = np.random.default_rng(seed)
    city_pops = 10 ** rng.uniform(np.log10(5e4), np.log10(2e7), size=n_cities)
    city_masses = np.empty(n_cities)
    for i, Pc in enumerate(city_pops):
        K = max(5, int(Pc / mean_neigh_size))
        ranks = np.arange(1, K + 1)
        weights = 1.0 / ranks ** s
        neigh_pops = Pc * weights / weights.sum()
        city_masses[i] = (neigh_pops ** delta).sum()
    log_pop = np.log10(city_pops)
    log_mass = np.log10(city_masses)
    return np.polyfit(log_pop, log_mass, 1)[0]


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    # --- Load data and estimate per-city σ ---
    print("Loading neighbourhood data...")
    df = pd.read_csv(NBHD_DATA, usecols=["city_id", "population"])
    sigma_df = estimate_per_city_sigma(df)
    print(f"  {len(sigma_df)} cities with σ estimates")

    print(f"\n  Per-city σ distribution:")
    print(f"    mean  = {sigma_df['sigma'].mean():.3f}")
    print(f"    median = {sigma_df['sigma'].median():.3f}")
    print(f"    std   = {sigma_df['sigma'].std():.3f}")
    print(f"    range = [{sigma_df['sigma'].min():.3f}, {sigma_df['sigma'].max():.3f}]")

    sigma_mean = sigma_df["sigma"].mean()
    sigma_std = sigma_df["sigma"].std()

    # --- Simulate β(σ) curve ---
    print(f"\nSimulating β(σ) curve (lognormal)...")
    sigma_grid = np.linspace(0.1, 3.0, 40)
    beta_lognormal = [simulate_beta_lognormal(DELTA, sig) for sig in sigma_grid]

    # Simulate β at observed σ with uncertainty
    print(f"Simulating β at observed σ={sigma_mean:.3f} with uncertainty...")
    mean_b, std_b, med_b, country_betas = simulate_beta_lognormal_with_uncertainty(
        DELTA, sigma_mean, sigma_std, n_countries=200, n_iterations=10, seed=42
    )
    print(f"  Simulated country β: mean={mean_b:.3f}, std={std_b:.3f}")

    # --- For comparison: Zipf β(s) curve ---
    print(f"\nSimulating β(s) curve (Zipf) for comparison...")
    s_grid = np.linspace(0.3, 3.0, 40)
    beta_zipf = [simulate_beta_zipf(DELTA, s) for s in s_grid]

    # --- Load observed β ---
    city_master = pd.read_csv(CITY_DATA)
    city_master = city_master[city_master["population_2015"] > 50000].copy()
    country_counts = city_master.groupby("CTR_MN_NM").size()
    valid_countries = country_counts[country_counts >= 5].index
    city_master = city_master[city_master["CTR_MN_NM"].isin(valid_countries)]

    observed_betas = []
    for country, grp in city_master.groupby("CTR_MN_NM"):
        pop = grp["population_2015"].values
        mass = grp["total_built_mass_tons"].values
        mask = (pop > 0) & (mass > 0)
        if mask.sum() >= 5:
            beta_c = np.polyfit(np.log10(pop[mask]), np.log10(mass[mask]), 1)[0]
            observed_betas.append(beta_c)
    observed_beta_mean = np.mean(observed_betas)
    print(f"\n  Observed country β: mean={observed_beta_mean:.3f} (N={len(observed_betas)})")

    # --- β(σ) with IQR uncertainty band ---
    print(f"\nComputing IQR bands for β(σ)...")
    beta_means_unc = []
    beta_q25 = []
    beta_q75 = []
    for sig in sigma_grid:
        _, _, _, cb = simulate_beta_lognormal_with_uncertainty(
            DELTA, sig, sigma_std, n_countries=200, n_iterations=5, seed=42
        )
        beta_means_unc.append(np.mean(cb))
        beta_q25.append(np.percentile(cb, 25))
        beta_q75.append(np.percentile(cb, 75))

    # --- Figure ---
    fig, axes = plt.subplots(1, 2, figsize=(13, 5))

    # Panel A: β(σ) lognormal curve
    ax = axes[0]
    ax.fill_between(sigma_grid, beta_q25, beta_q75,
                    alpha=0.2, color="steelblue", label="IQR (country-level)")
    ax.plot(sigma_grid, beta_lognormal, "-", color="steelblue", linewidth=2,
            label="β(σ) lognormal")
    ax.axhline(DELTA, color="grey", linestyle=":", linewidth=1,
               label=f"δ = {DELTA}")
    ax.axhline(1.0, color="grey", linestyle="--", linewidth=1, label="β = 1")
    ax.plot(sigma_mean, BETA_OBSERVED, "o", color="red", markersize=10, zorder=5,
            label=f"Observed (σ={sigma_mean:.2f}, β={BETA_OBSERVED})")
    ax.set_xlabel("Lognormal disparity σ")
    ax.set_ylabel("City-level scaling exponent β")
    ax.set_title("Lognormal simulation")
    ax.legend(fontsize=8, loc="upper right")
    ax.set_ylim(0.7, 1.05)
    ax.text(-0.1, 1.06, "A", transform=ax.transAxes,
            fontsize=14, fontweight="bold", va="top")

    # Panel B: Compare Zipf vs Lognormal β curves
    ax = axes[1]
    ax.plot(sigma_grid, beta_lognormal, "-", color="steelblue", linewidth=2,
            label="Lognormal β(σ)")
    ax.plot(s_grid, beta_zipf, "-", color="darkorange", linewidth=2,
            label="Zipf β(s)")
    ax.axhline(DELTA, color="grey", linestyle=":", linewidth=1)
    ax.axhline(1.0, color="grey", linestyle="--", linewidth=1)
    ax.set_xlabel("Disparity parameter (σ or s)")
    ax.set_ylabel("City-level scaling exponent β")
    ax.set_title("Lognormal vs Zipf comparison")
    ax.legend(fontsize=9)
    ax.set_ylim(0.7, 1.05)
    ax.text(-0.1, 1.06, "B", transform=ax.transAxes,
            fontsize=14, fontweight="bold", va="top")

    plt.tight_layout()
    out = FIG_DIR / "Test_Lognormal_Simulation.png"
    fig.savefig(out, dpi=200, bbox_inches="tight")
    plt.close()
    print(f"\n  Saved: {out}")

    # --- Key summary ---
    # Find what σ gives β = BETA_OBSERVED
    beta_arr = np.array(beta_lognormal)
    # Interpolate
    from numpy import interp
    # β decreases with σ, so flip for monotonic interp
    sigma_at_observed = interp(BETA_OBSERVED, beta_arr[::-1], sigma_grid[::-1])
    print(f"\n{'='*60}")
    print(f"KEY RESULTS")
    print(f"{'='*60}")
    print(f"  Observed β = {BETA_OBSERVED}")
    print(f"  Observed mean σ = {sigma_mean:.3f}")
    print(f"  σ needed to produce β={BETA_OBSERVED}: {sigma_at_observed:.3f}")
    print(f"  β at observed σ={sigma_mean:.3f}: {simulate_beta_lognormal(DELTA, sigma_mean):.4f}")
    print(f"  Simulated country β (with uncertainty): mean={mean_b:.3f}")
    print(f"  Observed country β: mean={observed_beta_mean:.3f}")


if __name__ == "__main__":
    main()
