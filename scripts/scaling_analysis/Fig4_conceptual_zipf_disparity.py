#!/usr/bin/env python3
"""
Fig4_conceptual_zipf_disparity.py
==================================
Conceptual diagram showing how the disparity parameter (s) affects
the shape of generalized Zipf distributions.

Shows rank-size relationships for different s values to illustrate
the concept of "disparity" in neighborhood population distributions.
"""

import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path

# Output path
SCRIPT_DIR = Path(__file__).resolve().parent
REVISION_DIR = SCRIPT_DIR.parent
OUT_FIG = REVISION_DIR / "figures" / "Fig4_conceptual_disparity.png"
OUT_FIG_PDF = REVISION_DIR / "figures" / "Fig4_conceptual_disparity.pdf"

def zipf_distribution(n_neighborhoods, s, total_pop=1e6):
    """
    Generate a generalized Zipf distribution.

    Parameters
    ----------
    n_neighborhoods : int
        Number of neighborhoods
    s : float
        Disparity parameter (Zipf exponent)
    total_pop : float
        Total city population

    Returns
    -------
    ranks : array
        Rank indices (1, 2, 3, ...)
    sizes : array
        Population sizes for each rank
    """
    ranks = np.arange(1, n_neighborhoods + 1)
    weights = 1.0 / ranks ** s
    sizes = total_pop * weights / weights.sum()
    return ranks, sizes


def main():
    """Create conceptual diagram showing s effect on Zipf distributions."""

    # Parameters
    n_neighborhoods = 50
    total_pop = 1e6

    # Only show two extreme cases for clarity in small inset
    s_values = [0.5, 2.0]
    colors = ["#2ca02c", "#d62728"]  # green (low), red (high)
    linewidths = [3.0, 3.0]  # Thicker lines for visibility

    # Create figure optimized for inset
    fig, ax = plt.subplots(figsize=(4, 3))

    # Plot each s value
    for s, color, lw in zip(s_values, colors, linewidths):
        ranks, sizes = zipf_distribution(n_neighborhoods, s, total_pop)
        ax.plot(ranks, sizes, color=color, lw=lw, alpha=0.9)

    # Direct labels on the lines instead of legend
    ax.text(2, 2.5e5, 'Low s', fontsize=14, color='#2ca02c',
            fontweight='bold', ha='left', va='center')
    ax.text(2, 2e4, 'High s', fontsize=14, color='#d62728',
            fontweight='bold', ha='left', va='center')

    # Formatting - clean and minimal
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel("Rank", fontsize=16, fontweight='bold')
    ax.set_ylabel("Size", fontsize=16, fontweight='bold')

    # Clean background - no grid
    ax.set_facecolor('white')
    fig.patch.set_facecolor('white')

    # Thicker axis lines for visibility
    for spine in ax.spines.values():
        spine.set_linewidth(1.5)

    # Larger tick labels
    ax.tick_params(axis='both', which='major', labelsize=12, width=1.5, length=6)

    # Remove minor ticks for cleaner look
    ax.tick_params(axis='both', which='minor', length=0)

    plt.tight_layout()

    # Save
    OUT_FIG.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT_FIG, dpi=300, bbox_inches="tight", facecolor='white')
    fig.savefig(OUT_FIG_PDF, dpi=300, bbox_inches="tight", facecolor='white')
    print(f"Saved conceptual diagram (inset version):")
    print(f"  → {OUT_FIG}")
    print(f"  → {OUT_FIG_PDF}")

    plt.show()


if __name__ == "__main__":
    main()
