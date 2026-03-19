#!/usr/bin/env python3
"""
Fig4_conceptual_zipf_separate.py
=================================
Generate separate conceptual diagrams for low s and high s.
"""

import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path

# Output paths
SCRIPT_DIR = Path(__file__).resolve().parent
REVISION_DIR = SCRIPT_DIR.parent
OUT_LOW_PNG = REVISION_DIR / "figures" / "Fig4_conceptual_disparity_low_s.png"
OUT_LOW_PDF = REVISION_DIR / "figures" / "Fig4_conceptual_disparity_low_s.pdf"
OUT_HIGH_PNG = REVISION_DIR / "figures" / "Fig4_conceptual_disparity_high_s.png"
OUT_HIGH_PDF = REVISION_DIR / "figures" / "Fig4_conceptual_disparity_high_s.pdf"


def zipf_distribution(n_neighborhoods, s, total_pop=1e6):
    """Generate a generalized Zipf distribution."""
    ranks = np.arange(1, n_neighborhoods + 1)
    weights = 1.0 / ranks ** s
    sizes = total_pop * weights / weights.sum()
    return ranks, sizes


def create_single_curve(s_value, color, label, out_png, out_pdf):
    """Create a clean diagram with a single Zipf curve."""

    # Parameters
    n_neighborhoods = 50
    total_pop = 1e6

    # Create figure optimized for inset
    fig, ax = plt.subplots(figsize=(4, 3))

    # Plot the curve
    ranks, sizes = zipf_distribution(n_neighborhoods, s_value, total_pop)
    ax.plot(ranks, sizes, color=color, lw=3.0, alpha=0.9)

    # Direct label on the line
    ax.text(2, 5e4, label, fontsize=14, color=color,
            fontweight='bold', ha='left', va='center')

    # Formatting - clean and minimal
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel("Rank", fontsize=16, fontweight='bold')
    ax.set_ylabel("Size", fontsize=16, fontweight='bold')

    # Clean background
    ax.set_facecolor('white')
    fig.patch.set_facecolor('white')

    # Thicker axis lines for visibility
    for spine in ax.spines.values():
        spine.set_linewidth(1.5)

    # Larger tick labels
    ax.tick_params(axis='both', which='major', labelsize=12, width=1.5, length=6)
    ax.tick_params(axis='both', which='minor', length=0)

    plt.tight_layout()

    # Save
    out_png.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_png, dpi=300, bbox_inches="tight", facecolor='white')
    fig.savefig(out_pdf, dpi=300, bbox_inches="tight", facecolor='white')

    plt.close(fig)

    return out_png, out_pdf


def main():
    """Generate both low s and high s versions."""

    print("Generating separate conceptual diagrams...")

    # Low s version
    print("\n[1/2] Creating LOW s version...")
    png1, pdf1 = create_single_curve(
        s_value=0.5,
        color='#2ca02c',  # green
        label='Low s',
        out_png=OUT_LOW_PNG,
        out_pdf=OUT_LOW_PDF
    )
    print(f"  → {png1}")
    print(f"  → {pdf1}")

    # High s version
    print("\n[2/2] Creating HIGH s version...")
    png2, pdf2 = create_single_curve(
        s_value=2.0,
        color='#d62728',  # red
        label='High s',
        out_png=OUT_HIGH_PNG,
        out_pdf=OUT_HIGH_PDF
    )
    print(f"  → {png2}")
    print(f"  → {pdf2}")

    print("\nDone! Generated 2 versions (PNG + PDF for each).")


if __name__ == "__main__":
    main()
