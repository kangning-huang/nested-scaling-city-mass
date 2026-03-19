# Nested Scaling of Urban Material Stocks

This repository contains the code and analysis pipeline for our manuscript on nested scaling relationships between population and built environment mass across cities and neighborhoods globally.

- **Status:** Under revision at *Nature Cities*
- **Preprint:** [arXiv:2507.03960](https://arxiv.org/abs/2507.03960)
- **Interactive explorer:** [https://kangning-huang.github.io/nested-scaling-city-mass/](https://kangning-huang.github.io/nested-scaling-city-mass/)
- **Repository:** [https://github.com/kangning-huang/nested-scaling-city-mass](https://github.com/kangning-huang/nested-scaling-city-mass)

## Key Findings

Urban material stocks (buildings, roads, pavement) scale **sublinearly** with population at two nested spatial scales:

| Scale | Exponent | 95% CI | N | Interpretation |
|-------|----------|--------|---|----------------|
| **City-level** | β = 0.900 | [0.890, 0.909] | 3,588 cities | A 1% increase in population is associated with only 0.9% more material stock |
| **Neighborhood-level** | δ = 0.713 | [0.712, 0.715] | 141,109 neighborhoods | Economies of scale are even stronger within cities |

The two exponents are statistically distinct (z = 39.1, p < 0.001), with confidence intervals that never overlap across any sensitivity specification. The result is robust to the choice of building volume dataset, material intensity assumptions, inclusion of underground infrastructure, spatial resolution, and grid positioning.

---

## System Requirements

### Software Dependencies

**Python** (tested on 3.10–3.12):

- pandas >= 1.5
- geopandas >= 0.12
- numpy >= 1.23
- scipy >= 1.10
- h3 >= 3.7
- tobler >= 0.9
- geemap >= 0.20
- earthengine-api >= 0.1.350
- rasterio >= 1.3
- exactextract >= 0.1
- statsmodels >= 0.14
- powerlaw >= 1.5
- matplotlib >= 3.6
- seaborn >= 0.12

**R** (tested on 4.3–4.4):

- tidyverse >= 2.0
- lme4 >= 1.1
- sf >= 1.0
- ggplot2 >= 3.4
- scales >= 1.2
- patchwork >= 1.1
- broom >= 1.0

**Node.js** (for the interactive website only; tested on 18–20):

- See `web/package.json` for frontend dependencies (React, MapLibre GL, deck.gl)

### Operating Systems

Tested on:

- macOS 14 (Sonoma) and macOS 15 (Sequoia), Apple Silicon (M1/M2/M3)
- Ubuntu 22.04 LTS (x86_64)

### Hardware Requirements

- No non-standard hardware required
- Minimum 8 GB RAM recommended for processing city-level data
- Google Earth Engine account required for data extraction stages (free for research use)

---

## Installation Guide

### Python Environment

```bash
python3 -m venv ~/.venvs/urban_scaling_env
source ~/.venvs/urban_scaling_env/bin/activate
pip install pandas geopandas numpy scipy h3 tobler geemap earthengine-api rasterio exactextract statsmodels powerlaw matplotlib seaborn
```

### R Packages

```r
install.packages(c("tidyverse", "lme4", "sf", "ggplot2", "scales", "patchwork", "broom"))
```

### Google Earth Engine

```bash
earthengine authenticate
# GEE Project ID: ee-knhuang
```

### Website (optional)

```bash
cd web && npm ci
```

**Typical install time:** ~5–10 minutes on a normal desktop computer with a broadband internet connection.

---

## Demo

### Quick Demo: Reproduce Main Scaling Figures

The fastest way to verify the software is to reproduce the main scaling analysis figures using the processed data included with the submission.

#### Instructions

```bash
# Activate environment
source ~/.venvs/urban_scaling_env/bin/activate

# City-level scaling (Figure 2)
cd scripts/scaling_analysis
Rscript Fig2_UniversalScaling_Decentered.R

# Neighborhood-level scaling (Figure 3)
Rscript Fig3_NeighborhoodScaling_Decentered.R

# Simulation analysis (Figure 4)
cd ../data_pipeline
python 06_estimate_neighborhood_zipf.py
python 07_simulate_scaling.py
python 10_generate_fig4.py
```

#### Expected Output

- **Figure 2:** A scatter plot of log(population) vs log(material stock) across 3,588 cities with OLS regression line showing β ≈ 0.900
- **Figure 3:** A scatter plot of log(population) vs log(material stock) across 141,109 neighborhoods with OLS regression line showing δ ≈ 0.713
- **Figure 4:** Multi-panel figure with Zipf exponent distributions, Monte Carlo simulation results, and observed vs simulated β comparison

**Expected run time:** ~2–5 minutes for all three figures on a normal desktop computer.

### GEE Extraction Demo

A minimal Google Earth Engine demo script is provided to demonstrate the data extraction workflow for a single city at H3 Resolution 6:

```bash
cd scripts/data_pipeline/gee_demo
python gee_sample_r6.py
```

---

## Instructions for Use

### Running on Your Own Data

To apply the analysis pipeline to different cities or regions:

1. **Define city boundaries** — upload city polygons as a GEE FeatureCollection
2. **Create H3 grids** — run `01_create_h3_grids.py` with your FeatureCollection
3. **Extract data** — run the batch extraction pipeline (Steps 03a–03c)
4. **Merge and calculate mass** — run Steps 04–05
5. **Run scaling analysis** — run the Fig2/Fig3 R scripts

### Reproduction Instructions

The full pipeline reproduces all quantitative results in the manuscript. See the [Reproducing Results](#reproducing-results) section below for complete step-by-step instructions covering the data processing pipeline, main figures, and all sensitivity analyses.

---

## Repository Structure

```
nested-scaling-city-mass/
├── scripts/
│   ├── build_SI_docx.py                     # Build Supplementary Information document
│   ├── data_pipeline/                       # Full data processing pipeline (GEE → mass → figures)
│   │   ├── 01_create_h3_grids.py            # Generate H3 hexagonal grids for cities
│   │   ├── 01b_create_h3_grids_nudged.py    # Shifted grids for MAUP sensitivity
│   │   ├── 02_extract_roads_neighborhood.py # Road extraction with exactextract
│   │   ├── 02b_extract_roads_clean.py       # Improved road extraction with lane widths
│   │   ├── 03_extract_volume_pavement.py    # Single-city extraction (synchronous)
│   │   ├── 03_run_extraction.py             # Dispatcher for extraction approaches
│   │   ├── 03a_submit_batch_exports.py      # GEE batch export submission
│   │   ├── 03a_submit_batch_exports_nudged.py # GEE batch export for nudged grids
│   │   ├── 03b_monitor_batch_tasks.py       # Monitor GEE task completion
│   │   ├── 03c_download_batch_results.py    # Download and merge GEE results
│   │   ├── 04_merge_building_road_data.py   # Merge building volume and road data
│   │   ├── 05_prep_global_mass_neighborhood.py # Convert volumes to material mass
│   │   ├── 06_estimate_neighborhood_zipf.py # Zipf exponent for city population distributions
│   │   ├── 07_simulate_scaling.py           # Monte Carlo: δ + Zipf s → β
│   │   ├── 08_compare_beta_boxplot.py       # Observed vs simulated β comparison
│   │   ├── 09_generate_fig3.Rmd             # Neighborhood scaling figure (R Markdown)
│   │   ├── 09b_compare_scaling_resolutions.R # Compare scaling across resolutions
│   │   ├── 09c_multiresolution_scaling_analysis.R # Multi-resolution analysis
│   │   ├── 10_generate_fig4.py              # Figure 4 assembly
│   │   ├── extract_santa_fe_gba_mi.py       # GBA building-level MI extraction for Santa Fe
│   │   ├── Fig1_DataPrep_GlobalMass_MergedMI_.Rmd  # City-level mass data preparation
│   │   ├── Fig1_DataPrep_HistTrend.Rmd      # Historical trend data preparation
│   │   ├── Fig1_DataPrep_SourceVariability.qmd # Source variability analysis (Quarto)
│   │   ├── Fig1_GlobalMass_Stats.Rmd        # Global mass statistics
│   │   ├── Fig1_GlobalMassboxplot_Assemble_MIUpdate.Rmd # Figure 1 assembly
│   │   ├── Fig2_UniversalScaling_MIUpdated.Rmd # City-level scaling (R Markdown)
│   │   ├── Fig3_NeighborhoodScaling_UpdateMI.Rmd # Neighborhood scaling (R Markdown)
│   │   ├── process_santa_fe.py              # Santa Fe city data pipeline
│   │   ├── validate_h3_hierarchical_consistency.py # Validate H3 grid hierarchy
│   │   ├── gee_demo/                        # Google Earth Engine demo
│   │   │   └── gee_sample_r6.py             # Demo extraction for single city at R6
│   │   ├── sensitivity/                     # Original mixed-effects sensitivity analyses
│   │   │   ├── 05_sensitivity_random_datasource.R  # Random data source selection
│   │   │   ├── 06_weighted_reliability_means.R     # Reliability-weighted averaging
│   │   │   ├── 07_MI_sensitivity_3tier.R           # Three-tier MI sensitivity
│   │   │   └── calculate_CI_exact_reproduction.py  # CI exact reproduction
│   │   └── utils/                           # Shared utilities
│   │       └── paths.py                     # Path configuration utilities
│   └── scaling_analysis/                    # Revised scaling analysis (de-centering approach)
│       ├── Fig1_GlobalMass_Stats.R          # Global mass summary statistics
│       ├── Fig1_HybridBoxplot.R             # Figure 1 hybrid boxplot
│       ├── Fig2_UniversalScaling_Decentered.R             # City-level scaling (main)
│       ├── Fig2_UniversalScaling_Decentered_MI_sensitivity.R    # City MI sensitivity
│       ├── Fig2_UniversalScaling_Decentered_Source_Sensitivity.R # City data source sensitivity
│       ├── Fig2_UniversalScaling_Decentered_Weighted_Source.R    # Reliability-weighted averaging
│       ├── Fig2_UniversalScaling_Decentered_WithSubwayMass.R    # City-level with subway mass
│       ├── Fig2_UniversalScaling_MixedEffects.R                 # Mixed-effects comparison
│       ├── Fig3_ExtendedData_CityLines.R                  # Extended Data: all city OLS lines
│       ├── Fig3_NeighborhoodScaling_Decentered.R                    # Neighborhood scaling (main)
│       ├── Fig3_NeighborhoodScaling_Decentered_DensityPanels.R      # Density panel visualization
│       ├── Fig3_NeighborhoodScaling_Decentered_Multiscale.R         # H3 R5/R6/R7 scaling
│       ├── Fig3_NeighborhoodScaling_Decentered_Multiscale_MI_sensitivity.R # Multiscale MI sensitivity
│       ├── Fig3_NeighborhoodScaling_Decentered_Multiscale_NoFilter.R      # Multiscale without filtering
│       ├── Fig3_NeighborhoodScaling_Decentered_Multiscale_R6Filter.R      # Multiscale with R6 filter
│       ├── Fig3_NeighborhoodScaling_Decentered_Multiscale_R6Filter_WithSubwayMass.R # R6 filter + subway
│       ├── Fig3_NeighborhoodScaling_Decentered_NudgeSensitivity.R   # Grid placement sensitivity
│       ├── Fig3_NeighborhoodScaling_Decentered_R6_Source_Sensitivity.R # R6 data source sensitivity
│       ├── Fig3_NeighborhoodScaling_Decentered_R7.R                 # Resolution 7 analysis
│       ├── Fig3_NeighborhoodScaling_Decentered_R7_MI_sensitivity.R  # R7 MI sensitivity
│       ├── Fig3_NeighborhoodScaling_Decentered_R7_NudgeSensitivity.R # R7 grid nudge
│       ├── Fig3_NeighborhoodScaling_Decentered_R7_Source_Sensitivity.R # R7 source sensitivity
│       ├── Fig3_NeighborhoodScaling_Decentered_R7_Weighted_Source.R    # R7 weighted source
│       ├── Fig3_NeighborhoodScaling_Decentered_R7_WithSubwayMass.R    # R7 with subway mass
│       ├── Fig3_NeighborhoodScaling_Decentered_Source_Sensitivity.R    # Neighborhood source sensitivity
│       ├── Fig3_NeighborhoodScaling_Original.R                  # Original (pre-decentering) analysis
│       ├── Fig3_NeighborhoodScaling_Original_Multiscale.R       # Original multiscale analysis
│       ├── Fig3_R7_city_candidates.R          # Per-city slope analysis (R7)
│       ├── Fig3_R7_city_candidates_v2.R       # Per-city slope analysis v2
│       ├── Fig3_SizeClass.R                   # City size class analysis
│       ├── Fig4_Simulation_Decentered.py      # Simulation with de-centered approach
│       ├── Fig4_conceptual_zipf_disparity.py  # Conceptual Zipf disparity figure
│       ├── Fig4_conceptual_zipf_separate.py   # Conceptual Zipf separate panels
│       ├── extract_subway_mass_by_hexagon.py  # Subway mass extraction per hexagon
│       ├── osm_subway_download.py             # Download subway networks from OSM
│       ├── export_pop_lt_1_neighborhoods.R    # Export neighborhoods with pop < 1
│       ├── test_lognormal_simulation.py       # Lognormal simulation tests
│       ├── test_rank_correlation.py           # Rank correspondence and permutation tests
│       ├── test_zipf_vs_lognormal.py          # Power-law vs lognormal (Clauset-Shalizi-Newman)
│       ├── test_zipf_vs_lognormal_percity_CSN.py # Per-city Zipf vs lognormal tests
│       ├── US_subset_scaling_Frantz_comparison.py # US subset comparison with Frantz et al.
│       └── web_prep/                          # Scripts to prepare data for the website
│           ├── compute_regressions.py         # OLS slopes with 95% CIs
│           ├── download_countries_geojson.py  # Country boundary GeoJSON
│           ├── pack_hex_to_zip.py             # Pack hexagon data to zip
│           ├── prep_city_aggregates.py        # City summaries per country
│           ├── prep_neighborhood_subsamples.py # Stratified subsamples for scatter plots
│           ├── split_city_hex_feeds.py        # Per-city H3 hex feeds
│           └── unzip_webdata.sh               # Unzip web data archives
├── config/                                    # Path configuration
│   ├── __init__.py
│   └── paths.py                               # Multi-environment path configuration
├── data/                                      # Data files (not tracked in git)
│   └── processed/
│       └── h3_resolution{N}/                  # Processed H3 hexagon data by resolution
├── tests/                                     # Pipeline validation tests
│   ├── run_pipeline_tests.py                  # Test runner
│   ├── test_extract_nyc_pois.py               # NYC POI extraction test
│   └── verify_poi_data.py                     # POI data verification
├── web/                                       # Interactive web explorer
│   ├── vite.config.js                         # Vite build configuration
│   ├── src/
│   │   ├── config.js                          # App configuration
│   │   ├── main.jsx                           # Application entry point
│   │   └── ui/
│   │       ├── App.jsx                        # Main application component
│   │       ├── CityPanel.jsx                  # City-level scatter panel
│   │       ├── MapView.jsx                    # MapLibre + deck.gl map
│   │       ├── NeighborhoodPanel.jsx          # Neighborhood scatter panel
│   │       ├── styles.css                     # Application styles
│   │       └── useTheme.js                    # Theme hook
│   └── public/webdata/                        # Static JSON data for the website
│       ├── cities_agg/                        # City-level aggregates by country
│       ├── hex/                               # Per-city H3 hexagon feeds
│       ├── regression/                        # OLS regression parameters
│       ├── scatter_samples/                   # Subsampled scatter plot data
│       └── index/                             # City metadata and search indices
└── .github/
    └── workflows/
        └── deploy.yml                         # GitHub Pages deployment
```

---

## Data Sources

All input datasets are publicly available. Data files are not tracked in this repository due to size constraints.

### Primary Datasets

| Dataset | Source | Resolution | Access | Usage |
|---------|--------|------------|--------|-------|
| **GHSL Urban Centres Database (UCDB)** | [EU JRC](https://ghsl.jrc.ec.europa.eu/ghs_stat_ucdb2015mt_r2019a.php) | City polygons | Free download; also hosted on GEE as `users/kh3657/GHS_STAT_UCDB2015` | Defines 3,588 city boundaries worldwide |
| **WorldPop** | [WorldPop](https://www.worldpop.org/) | 100 m raster | GEE: `WorldPop/GP/100m/pop/2015` | Population estimates (2015) per H3 hexagon |
| **Esch et al. 2022 (WSF3D)** | [DLR](https://geoservice.dlr.de/web/maps/eoc:wsf3d) | 90 m | GEE: `DLR/WSF3D/v1` | Building heights and volumes from TanDEM-X radar |
| **Li et al. 2022** | [Zenodo](https://doi.org/10.5281/zenodo.5825801) | 1 km | GEE: hosted as user asset | Building height/volume from random forest ensemble |
| **Liu et al. 2024 (GUS3D)** | [Figshare](https://doi.org/10.6084/m9.figshare.24901575) | 500 m | GEE: hosted as user asset | Building volume from XGBoost with 11 regional models |
| **GRIP Global Roads** | [GRIP](https://www.globio.info/download-grip-dataset) | Raster (various) | Local raster files | Road length by functional class (highway, primary, secondary, tertiary, local) |
| **GAIA/GISA Impervious Surface** | [GEE](https://developers.google.com/earth-engine/datasets) | 30 m | GEE: `Tsinghua/GAIA/v1` (2015 band) | Impervious surface extent for pavement area estimation |

### Material Intensity (MI) Reference Data

| Dataset | Source | Granularity | Usage |
|---------|--------|-------------|-------|
| **Heeren & Fishman 2019** | [Scientific Data](https://doi.org/10.1038/s41597-019-0021-x) | Global average + 4 regions | Baseline MI values for converting building volume → mass |
| **Haberl et al. 2024** | Manuscript SI | 5 world regions | Sensitivity analysis: region-specific MI |
| **Fishman et al. 2024 (RASMI)** | Manuscript SI | 32 world regions | Sensitivity analysis: fine-grained regional MI |
| **Rousseau et al. 2022** | [ES&T](https://doi.org/10.1021/acs.est.2c05255) | Per-material breakdown | Cross-validation of MI values |
| **Wiedenhofer et al. 2023** | [Scientific Data](https://doi.org/10.1038/s41597-023-02565-0) | Global raster (roads + rails) | Mobility infrastructure mass validation |

### Supplementary Datasets

| Dataset | Source | Usage |
|---------|--------|-------|
| **Elhacham et al. 2020** | [Nature](https://doi.org/10.1038/s41586-020-3010-5) SI | Historical trend of anthropogenic mass vs biomass (Fig 1) |
| **CPTOND-2025** | Chinese Public Transport Open Dataset | China subway network shapefiles for underground infrastructure sensitivity |
| **OpenStreetMap** | [Overpass API](https://overpass-turbo.eu/) | Global subway line extraction for non-China cities |
| **Mao et al. 2021** | Literature | Subway material intensity coefficients (~19,500 t/km tunnel, ~170,000 t/station) |

### How Raw Data Were Obtained

1. **City boundaries:** Downloaded from EU JRC GHSL portal as GeoPackage; uploaded to GEE as FeatureCollection.
2. **Building volumes:** Three independent datasets accessed as GEE Image assets. WSF3D is a public GEE dataset; Li2022 and Liu2024 were downloaded from their respective repositories and ingested as private GEE assets.
3. **Population:** Accessed directly from GEE's public `WorldPop` ImageCollection.
4. **Road data:** GRIP rasters downloaded from globio.info and stored locally for `exactextract` zonal statistics.
5. **Impervious surface:** Accessed directly from GEE's public GAIA dataset.
6. **Material intensity:** Extracted from published supplementary information tables (Excel/CSV). Baseline MI lookup hardcoded in `05_prep_global_mass_neighborhood.py`.
7. **Subway networks:** China networks from CPTOND-2025 (AMap API crawl); global networks from OSM Overpass queries via `osm_subway_download.py`.

---

## Complete Data Processing Pipeline

The pipeline transforms raw geospatial data into scaling analysis results in 6 stages.

### Stage 1: Create Spatial Framework

**Script:** `scripts/data_pipeline/01_create_h3_grids.py`

Generates H3 hexagonal grids at configurable resolution over all 3,588 GHSL urban centres. Each city is tessellated with Uber's H3 hierarchical hexagonal grid system.

```
Input:  GEE FeatureCollection 'users/kh3657/GHS_STAT_UCDB2015'
Output: data/processed/h3_resolution{N}/all_cities_h3_grids.gpkg
```

- **Resolution 5:** ~253 km² hexagons (coarse; 8,267 neighborhoods)
- **Resolution 6:** ~36 km² hexagons (primary analysis; 34,060 neighborhoods)
- **Resolution 7:** ~5 km² hexagons (fine; 248,797 neighborhoods)

For spatial sensitivity testing, `01b_create_h3_grids_nudged.py` creates shifted grids by translating city boundaries 1 km in each cardinal direction before tessellation.

### Stage 2a: Extract Road Data

**Script:** `scripts/data_pipeline/02_extract_roads_neighborhood.py`

Computes road length (km) within each H3 hexagon using `exactextract` zonal statistics on GRIP raster files. Roads are categorized by functional class (highway, primary, secondary, tertiary, local).

```
Input:  all_cities_h3_grids.gpkg + GRIP rasters (local)
Output: Fig3_Roads_Neighborhood_H3_Resolution{N}_{date}.csv
```

`02b_extract_roads_clean.py` is an improved version adding lane-based road widths, surface areas, and climate classifications.

### Stage 2b: Extract Building Volumes and Pavement

**Scripts:**
- `scripts/data_pipeline/03a_submit_batch_exports.py` — submit GEE batch export tasks
- `scripts/data_pipeline/03b_monitor_batch_tasks.py` — monitor task completion
- `scripts/data_pipeline/03c_download_batch_results.py` — download and merge results

For each H3 hexagon, extracts from GEE:
- **Building volume** (m³) from three independent datasets (Esch2022, Li2022, Liu2024)
- **Impervious surface area** (m²) from GAIA/GISA
- **Population** from WorldPop 100m

All three building volume sources are extracted simultaneously and stored as separate columns, allowing post-hoc source selection and sensitivity analysis.

```
Input:  all_cities_h3_grids.gpkg + GEE raster datasets
Output: Fig3_Volume_Pavement_Neighborhood_H3_Resolution{N}_{date}.csv
```

The synchronous single-city alternative is `03_extract_volume_pavement.py` (slower but simpler). `03_run_extraction.py` dispatches between the two approaches.

### Stage 3: Merge Building and Road Data

**Script:** `scripts/data_pipeline/04_merge_building_road_data.py`

Joins volume/pavement extraction output with road extraction output on `h3index`.

```
Input:  Volume/pavement CSV + Roads CSV
Output: Fig3_Merged_Neighborhood_H3_Resolution{N}_{date}.csv
```

### Stage 4: Calculate Material Stocks

**Neighborhood-level:** `scripts/data_pipeline/05_prep_global_mass_neighborhood.py`

Converts physical quantities to material mass (tonnes) using region-specific material intensity (MI) values:

| Component | Formula | MI Source |
|-----------|---------|-----------|
| **Building mass** | volume (m³) × MI (kg/m³) | Heeren & Fishman 2019, stratified by building class (RS/RM/RI) and world region |
| **Road mass** | road_length (km) × lane_width (m) × depth (m) × density (kg/m³) | Literature values by road class |
| **Pavement mass** | impervious_area (m²) × depth (m) × density (kg/m³) | Standard pavement MI |

Building class assignment uses the ratio of residential to non-residential floor space from GHSL data. MI lookup provides values for 5 world regions × 3 building classes.

```
Input:  Fig3_Merged_Neighborhood_H3_Resolution{N}_{date}.csv
Output: Fig3_Mass_Neighborhood_H3_Resolution{N}_{date}.csv
```

**City-level:** `scripts/data_pipeline/Fig1_DataPrep_GlobalMass_MergedMI_.Rmd` (R Markdown)

Equivalent process for city-level aggregates, also incorporating biomass estimates.

```
Input:  merged_building_road_otherpavement.csv + biomass_by_cities.csv
Output: MasterMass_ByClass20250616.csv (3,588 cities)
```

### Stage 5: Scaling Analysis

**Scripts:** `scripts/scaling_analysis/Fig2_UniversalScaling_Decentered.R` and `Fig3_NeighborhoodScaling_Decentered.R`

Following Bettencourt & Lobo (2016), we use within-group de-centering to remove country/city baseline differences before pooled OLS:

```r
# City-level: de-center by country mean
group_by(CTR_MN_NM) %>%
  mutate(log_pop_c = log10(pop) - mean(log10(pop)),
         log_mass_c = log10(mass) - mean(log10(mass)))

# Neighborhood-level: de-center by city mean
group_by(ID_HDC_G0) %>%
  mutate(log_pop_c = log10(pop) - mean(log10(pop)),
         log_mass_c = log10(mass) - mean(log10(mass)))

# OLS on pooled de-centered data
lm(log_mass_c ~ log_pop_c, data = pooled)
```

This is algebraically equivalent to the within-group fixed-effects estimator (Frisch-Waugh-Lovell theorem) and produces virtually identical results to the mixed-effects approach (see `Fig2_UniversalScaling_MixedEffects.R` for comparison).

### Stage 6: Figures and Simulation

| Script | Output |
|--------|--------|
| `Fig1_HybridBoxplot.R` | **Figure 1:** Global mass overview with hybrid boxplot |
| `Fig2_UniversalScaling_Decentered.R` | **Figure 2:** City-level scaling (pop vs mass scatter with OLS) |
| `Fig3_NeighborhoodScaling_Decentered.R` | **Figure 3:** Neighborhood-level scaling |
| `Fig3_NeighborhoodScaling_Decentered_DensityPanels.R` | **Figure 3 (density):** Neighborhood scaling with density panels |
| `Fig4_Simulation_Decentered.py` | **Figure 4:** Simulation with de-centered approach |
| `06_estimate_neighborhood_zipf.py` | Zipf exponent (s) for each city's population distribution |
| `07_simulate_scaling.py` | Monte Carlo simulation: neighborhood δ + Zipf s → predicted city β |
| `08_compare_beta_boxplot.py` | Observed vs simulated β comparison |
| `10_generate_fig4.py` | **Figure 4:** Assembly of Zipf, simulation, and comparison panels |
| `Fig4_conceptual_zipf_disparity.py` | Conceptual Zipf disparity illustration |
| `Fig4_conceptual_zipf_separate.py` | Conceptual Zipf separate panel illustration |

---

## Sensitivity Analyses

All sensitivity scripts are in `scripts/scaling_analysis/`. Each test shows that the sublinear finding (β < 1, δ < 1) is robust.

### Building Volume Data Source (Reviewer 1, Comment #1)

Tests whether the choice among three independent building volume datasets affects the scaling exponent.

| Script | What it tests |
|--------|---------------|
| `Fig2_UniversalScaling_Decentered_Source_Sensitivity.R` | City β with each source individually + random selection (100 iterations) |
| `Fig3_NeighborhoodScaling_Decentered_Source_Sensitivity.R` | Neighborhood δ with each source individually |
| `Fig3_NeighborhoodScaling_Decentered_R6_Source_Sensitivity.R` | R6 neighborhood source sensitivity |
| `Fig3_NeighborhoodScaling_Decentered_R7_Source_Sensitivity.R` | R7 neighborhood source sensitivity |
| `Fig2_UniversalScaling_Decentered_Weighted_Source.R` | Reliability-weighted averaging across sources |
| `Fig3_NeighborhoodScaling_Decentered_R7_Weighted_Source.R` | R7 weighted source averaging |

**Result:** City β range = 0.024 (0.892–0.916). All sublinear regardless of source.

### Material Intensity Assumptions (Reviewer 1 #2, Reviewer 3 #3)

Tests three MI frameworks: global average, Haberl 5-region, Fishman 32-region RASMI.

| Script | Level |
|--------|-------|
| `Fig2_UniversalScaling_Decentered_MI_sensitivity.R` | City-level |
| `Fig3_NeighborhoodScaling_Decentered_Multiscale_MI_sensitivity.R` | Neighborhood-level (multiscale) |
| `Fig3_NeighborhoodScaling_Decentered_R7_MI_sensitivity.R` | Neighborhood-level (R7) |

**Result:** β range = 0.004 (negligible). MI is multiplicative and absorbed by de-centering.

### Underground Infrastructure (Reviewer 1 #3, Reviewer 3 #5)

Tests whether omitting subway infrastructure biases the exponent.

| Script | Purpose |
|--------|---------|
| `extract_subway_mass_by_hexagon.py` | Extract subway mass from CPTOND-2025 (China) + OSM (global) |
| `osm_subway_download.py` | Download subway networks from OpenStreetMap |
| `Fig2_UniversalScaling_Decentered_WithSubwayMass.R` | City-level with subway mass added |
| `Fig3_NeighborhoodScaling_Decentered_Multiscale_R6Filter_WithSubwayMass.R` | Neighborhood-level (R6) with subway mass |
| `Fig3_NeighborhoodScaling_Decentered_R7_WithSubwayMass.R` | Neighborhood-level (R7) with subway mass |

**Result:** Δβ = +0.003, Δδ = +0.001. Underground infrastructure accounts for < 1% of total mass.

### Spatial Resolution and Grid Placement (Reviewer 1 #6, Reviewer 3 #4)

Tests sensitivity to H3 hexagon resolution and MAUP (Modifiable Areal Unit Problem).

| Script | What it tests |
|--------|---------------|
| `Fig3_NeighborhoodScaling_Decentered_Multiscale.R` | δ across H3 Resolutions 5, 6, 7 |
| `Fig3_NeighborhoodScaling_Decentered_Multiscale_R6Filter.R` | δ with R6 filter |
| `Fig3_NeighborhoodScaling_Decentered_Multiscale_NoFilter.R` | δ without neighborhood filtering |
| `Fig3_NeighborhoodScaling_Decentered_NudgeSensitivity.R` | δ with grid shifted 1 km N/S/E/W |
| `Fig3_NeighborhoodScaling_Decentered_R7_NudgeSensitivity.R` | R7 nudge sensitivity |

**Result:** δ decreases monotonically with finer resolution (0.826 → 0.751 → 0.713 for R5 → R6 → R7). Nudging produces max deviation of 0.003.

### Statistical Distribution Tests (Reviewer 1 #7)

| Script | What it tests |
|--------|---------------|
| `test_zipf_vs_lognormal.py` | Power-law vs lognormal vs truncated power-law (Clauset-Shalizi-Newman framework) |
| `test_zipf_vs_lognormal_percity_CSN.py` | Per-city Zipf vs lognormal tests |
| `test_lognormal_simulation.py` | Lognormal simulation tests |
| `test_rank_correlation.py` | Rank correspondence and permutation tests |

**Result:** Power law strongly preferred over lognormal (Vuong R = 28.9 for population, p < 0.001).

### Neighborhood Variability (Reviewer 1 #8)

| Script | Output |
|--------|--------|
| `Fig3_ExtendedData_CityLines.R` | Extended Data figure overlaying all 3,312 city OLS lines |
| `Fig3_R7_city_candidates.R` | Per-city slope analysis and candidate identification |
| `Fig3_R7_city_candidates_v2.R` | Per-city slope analysis v2 |

**Result:** 99.97% of cities (3,311/3,312) have positive scaling slopes.

### Additional Analyses

| Script | What it tests |
|--------|---------------|
| `Fig3_NeighborhoodScaling_Original.R` | Original (pre-decentering) neighborhood scaling |
| `Fig3_NeighborhoodScaling_Original_Multiscale.R` | Original multiscale analysis |
| `Fig3_SizeClass.R` | City size class analysis |
| `Fig2_UniversalScaling_MixedEffects.R` | Mixed-effects model comparison |
| `US_subset_scaling_Frantz_comparison.py` | US subset comparison with Frantz et al. |
| `export_pop_lt_1_neighborhoods.R` | Export neighborhoods with population < 1 |

---

## Filtering Criteria

All neighborhood analyses apply these filters:

1. **Population ≥ 1** per hexagon (excludes fractional/impossible values)
2. **City total population > 50,000**
3. **Cities with ≥ 10 qualifying neighborhoods** (ensures reliable per-city regression)
4. **Countries with ≥ 5 qualifying cities** (ensures reliable per-country statistics)

---

## Interactive Website

The [live explorer](https://kangning-huang.github.io/nested-scaling-city-mass/) provides:

- **Map view:** Navigate Global → Country → City. City view renders H3 R7 hexagons colored by population or built mass on a log scale.
- **City panel:** City-level scatter of log(pop) vs log(mass) with OLS regression and 95% CI.
- **Neighborhood panel:** Neighborhood-level scatter with density overlay option.

### Website Data Preparation

Scripts in `scripts/scaling_analysis/web_prep/` transform the analysis outputs into static JSON artifacts:

| Script | Output |
|--------|--------|
| `prep_city_aggregates.py` | City summaries per country |
| `prep_neighborhood_subsamples.py` | Stratified subsamples for scatter plots |
| `compute_regressions.py` | OLS slopes with 95% CIs and decentered anchors |
| `split_city_hex_feeds.py` | Per-city H3 hex feeds for map rendering |
| `download_countries_geojson.py` | Country boundary GeoJSON |
| `pack_hex_to_zip.py` | Pack hexagon data to zip archives |
| `unzip_webdata.sh` | Unzip web data archives |

### Website Stack

- **Frontend:** Vite + React + MapLibre GL + deck.gl (H3HexagonLayer)
- **Basemap:** MapTiler light basemap
- **Deployment:** GitHub Pages via `.github/workflows/deploy.yml`

### Local Development

```bash
cd web && npm ci
export VITE_MAPTILER_KEY=your_key  # free at maptiler.com
npm run dev
```

### Data Dictionary

| File | Fields |
|------|--------|
| `webdata/cities_agg/*.json` | `country_iso`, `city_id`, `city`, `pop_total`, `mass_total`, `lat`, `lon`, `log_pop`, `log_mass` |
| `webdata/scatter_samples/*.json` | `country_iso`, `city_id`, `log_pop`, `log_mass` |
| `webdata/regression/*.json` | `slope`, `slope_lo`, `slope_hi`, `x0`, `y0`, `n`, `r2` |
| `webdata/hex/city=ID.json` | `h3index`, `population_2015`, `total_built_mass_tons`, `city_id`, `country_iso` |

Regression lines use: `y = y0 + slope * (x - x0)`. All logs are base-10; population in persons; mass in metric tonnes.

---

## Reproducing Results

### Quick Start (figures only, requires processed data)

```bash
# City-level scaling (Figure 2)
cd scripts/scaling_analysis
Rscript Fig2_UniversalScaling_Decentered.R

# Neighborhood-level scaling (Figure 3)
Rscript Fig3_NeighborhoodScaling_Decentered.R

# Simulation analysis (Figure 4)
cd ../data_pipeline
python 10_generate_fig4.py
```

### Full Pipeline (requires GEE authentication and raw data)

```bash
cd scripts/data_pipeline

# Stage 1: Create H3 grids
python 01_create_h3_grids.py --resolution 6

# Stage 2a: Extract roads (requires local GRIP rasters)
python 02_extract_roads_neighborhood.py

# Stage 2b: Extract building volumes + pavement (GEE batch)
python 03a_submit_batch_exports.py
python 03b_monitor_batch_tasks.py --watch     # wait for completion
python 03c_download_batch_results.py

# Stage 3: Merge
python 04_merge_building_road_data.py

# Stage 4: Calculate mass
python 05_prep_global_mass_neighborhood.py

# Stage 5: Scaling analysis
cd ../scaling_analysis
Rscript Fig2_UniversalScaling_Decentered.R
Rscript Fig3_NeighborhoodScaling_Decentered.R

# Stage 6: Simulation
cd ../data_pipeline
python 06_estimate_neighborhood_zipf.py
python 07_simulate_scaling.py
python 10_generate_fig4.py
```

### Sensitivity Analyses

```bash
cd scripts/scaling_analysis

# Data source sensitivity
Rscript Fig2_UniversalScaling_Decentered_Source_Sensitivity.R
Rscript Fig3_NeighborhoodScaling_Decentered_Source_Sensitivity.R

# Material intensity sensitivity
Rscript Fig2_UniversalScaling_Decentered_MI_sensitivity.R

# Underground infrastructure
python extract_subway_mass_by_hexagon.py
Rscript Fig2_UniversalScaling_Decentered_WithSubwayMass.R

# Multiscale (H3 R5/R6/R7)
Rscript Fig3_NeighborhoodScaling_Decentered_Multiscale_R6Filter.R

# Grid nudge sensitivity
Rscript Fig3_NeighborhoodScaling_Decentered_NudgeSensitivity.R

# Zipf's law test
python test_zipf_vs_lognormal.py
python test_rank_correlation.py
```

---

## Citation

If you use this code or data, please cite:

> Huang, K. & Lu, M. (2025). Nested scaling laws of urban material stocks. *arXiv:2507.03960*. [https://arxiv.org/abs/2507.03960](https://arxiv.org/abs/2507.03960)

---

## License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE) for details. This is an [OSI-approved](https://opensource.org/licenses/) open source license that permits reuse, modification, and distribution for both academic and commercial purposes.
