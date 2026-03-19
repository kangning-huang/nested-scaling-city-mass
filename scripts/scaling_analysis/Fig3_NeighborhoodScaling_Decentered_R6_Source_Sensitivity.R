# =============================================================================
# Fig3 Neighborhood Scaling - Decentered - R6 Per-Resolution - Source Sensitivity
# =============================================================================
# Tests robustness of R6 neighborhood-level scaling exponent (delta) to building
# volume data source choice: Esch2022, Li2022, Liu2024.
#
# Per-resolution filter at R6 (applied independently):
#   - pop >= 1, mass > 0
#   - City total pop > 50,000
#   - >= 10 neighborhoods per city
#   - >= 5 qualifying cities per country
#
# Analyses:
#   A. Baseline (equal-weighted average of 3 sources)
#   B. Individual sources (Esch2022, Li2022, Liu2024)
#   C. Random source selection (100 iterations)
#   D. Reliability-weighted average (R²-based region weights)
#
# Output: figures/Table_Decentered_R6_PerRes_Source_Sensitivity_*.csv
# =============================================================================

rm(list = ls())
if (!interactive()) pdf(NULL)

library(pacman)
pacman::p_load(readr, dplyr, tibble, tidyr, ggplot2, scales, patchwork)

set.seed(42)

# =============================================================================
# SETUP
# =============================================================================

rev_dir <- normalizePath(file.path(getwd(), ".."), mustWork = TRUE)
data_dir <- file.path(rev_dir, "data")
figure_dir <- file.path(rev_dir, "figures")
dir.create(figure_dir, showWarnings = FALSE, recursive = TRUE)

N_ITERATIONS <- 100

mass_file <- file.path(data_dir, "Fig3_Mass_Neighborhood_H3_Resolution6_2025-06-24.csv")
sources <- c("Esch2022", "Li2022", "Liu2024")

cat("=== Fig3 De-centered - R6 Per-Resolution Filter - Source Sensitivity ===\n\n")

# =============================================================================
# STEP 1: Load R6 data
# =============================================================================

cat("=== Loading Resolution 6 data ===\n")
df <- readr::read_csv(mass_file, show_col_types = FALSE)
cat("  Loaded:", nrow(df), "neighborhoods\n")

# Compute per-source total mass
for (src in sources) {
  bldg_col <- paste0("BuildingMass_Total_", src)
  total_col <- paste0("total_", src)
  df[[total_col]] <- df[[bldg_col]] + df$mobility_mass_tons
}

# =============================================================================
# REGION-SPECIFIC RELIABILITY WEIGHTS (R²-based)
# =============================================================================
# Same weights as R7 weighted source script. See that script for derivation.
# Weights proportional to published validation R² values, normalized per region.
# If only 1 or 2 sources have data > 0, weights are renormalized over available.
# =============================================================================

region_weights <- tribble(
  ~region,                    ~w_Esch2022, ~w_Li2022, ~w_Liu2024,
  "North America",            0.45,        0.72,      0.89,
  "Europe (W/C)",             0.40,        0.68,      0.86,
  "Europe (East)",            0.35,        0.68,      0.86,
  "East Asia (China)",        0.30,        0.49,      0.70,
  "East Asia (Japan/Korea)",  0.15,        0.55,      0.68,
  "South Asia",               0.25,        0.47,      0.20,
  "Southeast Asia",           0.55,        0.62,      0.19,
  "Central Asia",             0.45,        0.48,      0.20,
  "Middle East / N. Africa",  0.40,        0.55,      0.20,
  "Sub-Saharan Africa",       0.45,        0.63,      0.30,
  "Latin America",            0.55,        0.60,      0.26,
  "Oceania / Australia",      0.50,        0.70,      0.55,
  "Russia / North Asia",      0.30,        0.48,      0.51
)

# Normalize each row so weights sum to 1
region_weights <- region_weights %>%
  mutate(
    w_total = w_Esch2022 + w_Li2022 + w_Liu2024,
    w_Esch2022 = w_Esch2022 / w_total,
    w_Li2022 = w_Li2022 / w_total,
    w_Liu2024 = w_Liu2024 / w_total
  ) %>%
  select(-w_total)

# --- ISO -> Region mapping (same as R7 script) ---
iso_to_region <- c(
  "USA" = "North America", "CAN" = "North America",
  "DEU" = "Europe (W/C)", "FRA" = "Europe (W/C)", "GBR" = "Europe (W/C)",
  "NLD" = "Europe (W/C)", "BEL" = "Europe (W/C)", "AUT" = "Europe (W/C)",
  "CHE" = "Europe (W/C)", "LUX" = "Europe (W/C)", "IRL" = "Europe (W/C)",
  "ESP" = "Europe (W/C)", "ITA" = "Europe (W/C)", "PRT" = "Europe (W/C)",
  "GRC" = "Europe (W/C)", "DNK" = "Europe (W/C)", "SWE" = "Europe (W/C)",
  "NOR" = "Europe (W/C)", "FIN" = "Europe (W/C)", "MLT" = "Europe (W/C)",
  "CYP" = "Europe (W/C)", "SVN" = "Europe (W/C)", "HRV" = "Europe (W/C)",
  "EST" = "Europe (W/C)", "LVA" = "Europe (W/C)", "LTU" = "Europe (W/C)",
  "POL" = "Europe (W/C)", "CZE" = "Europe (W/C)", "SVK" = "Europe (W/C)",
  "ISR" = "Europe (W/C)", "JEY" = "Europe (W/C)",
  "ROU" = "Europe (East)", "BGR" = "Europe (East)", "HUN" = "Europe (East)",
  "SRB" = "Europe (East)", "BIH" = "Europe (East)", "ALB" = "Europe (East)",
  "MKD" = "Europe (East)", "MDA" = "Europe (East)", "UKR" = "Europe (East)",
  "BLR" = "Europe (East)", "MNE" = "Europe (East)", "XKO" = "Europe (East)",
  "GEO" = "Europe (East)", "ARM" = "Europe (East)", "AZE" = "Europe (East)",
  "CHN" = "East Asia (China)", "TWN" = "East Asia (China)",
  "JPN" = "East Asia (Japan/Korea)", "KOR" = "East Asia (Japan/Korea)",
  "PRK" = "East Asia (Japan/Korea)",
  "IND" = "South Asia", "PAK" = "South Asia", "BGD" = "South Asia",
  "LKA" = "South Asia", "NPL" = "South Asia", "AFG" = "South Asia",
  "BTN" = "South Asia",
  "THA" = "Southeast Asia", "VNM" = "Southeast Asia", "IDN" = "Southeast Asia",
  "PHL" = "Southeast Asia", "MYS" = "Southeast Asia", "MMR" = "Southeast Asia",
  "SGP" = "Southeast Asia", "KHM" = "Southeast Asia", "LAO" = "Southeast Asia",
  "TLS" = "Southeast Asia", "BRN" = "Southeast Asia",
  "KAZ" = "Central Asia", "UZB" = "Central Asia", "TKM" = "Central Asia",
  "KGZ" = "Central Asia", "TJK" = "Central Asia", "MNG" = "Central Asia",
  "SAU" = "Middle East / N. Africa", "IRN" = "Middle East / N. Africa",
  "IRQ" = "Middle East / N. Africa", "EGY" = "Middle East / N. Africa",
  "MAR" = "Middle East / N. Africa", "TUN" = "Middle East / N. Africa",
  "DZA" = "Middle East / N. Africa", "LBY" = "Middle East / N. Africa",
  "ARE" = "Middle East / N. Africa", "KWT" = "Middle East / N. Africa",
  "QAT" = "Middle East / N. Africa", "BHR" = "Middle East / N. Africa",
  "OMN" = "Middle East / N. Africa", "JOR" = "Middle East / N. Africa",
  "LBN" = "Middle East / N. Africa", "SYR" = "Middle East / N. Africa",
  "YEM" = "Middle East / N. Africa", "PSE" = "Middle East / N. Africa",
  "TUR" = "Middle East / N. Africa", "SDN" = "Middle East / N. Africa",
  "ESH" = "Middle East / N. Africa", "MRT" = "Middle East / N. Africa",
  "NGA" = "Sub-Saharan Africa", "KEN" = "Sub-Saharan Africa",
  "ZAF" = "Sub-Saharan Africa", "GHA" = "Sub-Saharan Africa",
  "TZA" = "Sub-Saharan Africa", "ETH" = "Sub-Saharan Africa",
  "AGO" = "Sub-Saharan Africa", "CMR" = "Sub-Saharan Africa",
  "COD" = "Sub-Saharan Africa", "COG" = "Sub-Saharan Africa",
  "CIV" = "Sub-Saharan Africa", "SEN" = "Sub-Saharan Africa",
  "MLI" = "Sub-Saharan Africa", "BFA" = "Sub-Saharan Africa",
  "NER" = "Sub-Saharan Africa", "TCD" = "Sub-Saharan Africa",
  "CAF" = "Sub-Saharan Africa", "BEN" = "Sub-Saharan Africa",
  "TGO" = "Sub-Saharan Africa", "GIN" = "Sub-Saharan Africa",
  "SLE" = "Sub-Saharan Africa", "LBR" = "Sub-Saharan Africa",
  "GAB" = "Sub-Saharan Africa", "SOM" = "Sub-Saharan Africa",
  "MDG" = "Sub-Saharan Africa", "MOZ" = "Sub-Saharan Africa",
  "ZMB" = "Sub-Saharan Africa", "ZWE" = "Sub-Saharan Africa",
  "MWI" = "Sub-Saharan Africa", "RWA" = "Sub-Saharan Africa",
  "BDI" = "Sub-Saharan Africa", "UGA" = "Sub-Saharan Africa",
  "NAM" = "Sub-Saharan Africa", "MUS" = "Sub-Saharan Africa",
  "GMB" = "Sub-Saharan Africa", "GNB" = "Sub-Saharan Africa",
  "GNQ" = "Sub-Saharan Africa", "ERI" = "Sub-Saharan Africa",
  "SSD" = "Sub-Saharan Africa", "LSO" = "Sub-Saharan Africa",
  "SWZ" = "Sub-Saharan Africa", "BWA" = "Sub-Saharan Africa",
  "COM" = "Sub-Saharan Africa",
  "BRA" = "Latin America", "MEX" = "Latin America", "ARG" = "Latin America",
  "COL" = "Latin America", "PER" = "Latin America", "CHL" = "Latin America",
  "VEN" = "Latin America", "ECU" = "Latin America", "BOL" = "Latin America",
  "PRY" = "Latin America", "URY" = "Latin America", "SUR" = "Latin America",
  "GUY" = "Latin America", "GTM" = "Latin America", "HND" = "Latin America",
  "SLV" = "Latin America", "NIC" = "Latin America", "CRI" = "Latin America",
  "PAN" = "Latin America", "CUB" = "Latin America", "DOM" = "Latin America",
  "HTI" = "Latin America", "JAM" = "Latin America", "TTO" = "Latin America",
  "BHS" = "Latin America", "BRB" = "Latin America", "CUW" = "Latin America",
  "PRI" = "Latin America", "BLZ" = "Latin America",
  "AUS" = "Oceania / Australia", "NZL" = "Oceania / Australia",
  "RUS" = "Russia / North Asia"
)

# --- Map neighborhoods to regions and compute weighted mass ---
df$world_region <- iso_to_region[df$CTR_MN_ISO]
df$world_region[is.na(df$world_region)] <- "UNMAPPED"

df <- df %>%
  left_join(region_weights, by = c("world_region" = "region"))

# Unmapped regions get equal weights
df$w_Esch2022[is.na(df$w_Esch2022)] <- 1/3
df$w_Li2022[is.na(df$w_Li2022)] <- 1/3
df$w_Liu2024[is.na(df$w_Liu2024)] <- 1/3

# Weighted building mass: only sources with data > 0 contribute
# Replace NAs with 0 so they are treated as "no data" rather than propagating NA
df <- df %>%
  mutate(
    m_esch = coalesce(BuildingMass_Total_Esch2022, 0),
    m_li   = coalesce(BuildingMass_Total_Li2022, 0),
    m_liu  = coalesce(BuildingMass_Total_Liu2024, 0),
    has_esch = as.numeric(m_esch > 0),
    has_li   = as.numeric(m_li > 0),
    has_liu  = as.numeric(m_liu > 0),
    weighted_num = (w_Esch2022 * m_esch * has_esch +
                    w_Li2022   * m_li   * has_li +
                    w_Liu2024  * m_liu  * has_liu),
    weighted_den = (w_Esch2022 * has_esch +
                    w_Li2022   * has_li +
                    w_Liu2024  * has_liu),
    weighted_bldg_mass = ifelse(weighted_den > 0, weighted_num / weighted_den, 0),
    total_weighted = weighted_bldg_mass + mobility_mass_tons
  )

# =============================================================================
# STEP 2: Apply per-resolution filter at R6
# =============================================================================

cat("\n=== Applying per-resolution filter at R6 ===\n")

d6 <- df %>%
  filter(population_2015 >= 1, total_built_mass_tons > 0)

# Cities with total pop > 50,000
city_pop <- d6 %>%
  group_by(CTR_MN_ISO, ID_HDC_G0) %>%
  summarize(total_pop = sum(population_2015), .groups = "drop") %>%
  filter(total_pop > 50000)
d6 <- d6 %>% filter(ID_HDC_G0 %in% city_pop$ID_HDC_G0)

# Cities with >= 10 neighborhoods
city_nbhd <- d6 %>%
  group_by(CTR_MN_ISO, ID_HDC_G0) %>%
  summarize(n_nbhd = n(), .groups = "drop") %>%
  filter(n_nbhd >= 10)
d6 <- d6 %>% filter(ID_HDC_G0 %in% city_nbhd$ID_HDC_G0)

# Countries with >= 5 qualifying cities
country_city <- d6 %>%
  group_by(CTR_MN_ISO) %>%
  summarize(num_cities = n_distinct(ID_HDC_G0)) %>%
  filter(num_cities >= 5)
d6 <- d6 %>% filter(CTR_MN_ISO %in% country_city$CTR_MN_ISO)

r6_city_ids <- unique(d6$ID_HDC_G0)
r6_country_isos <- unique(d6$CTR_MN_ISO)
cat("R6 per-resolution filter:", length(r6_city_ids), "cities,",
    length(r6_country_isos), "countries\n\n")

# =============================================================================
# DE-CENTERED OLS FUNCTION
# =============================================================================

run_decentered_nbhd <- function(df, mass_col) {
  d <- df %>%
    filter(population_2015 >= 1, .data[[mass_col]] > 0) %>%
    filter(ID_HDC_G0 %in% r6_city_ids,
           CTR_MN_ISO %in% r6_country_isos) %>%
    mutate(
      log_pop = log10(population_2015),
      log_mass = log10(.data[[mass_col]]),
      Country_City = paste(CTR_MN_NM, ID_HDC_G0, sep = "_")
    )

  dc <- d %>%
    group_by(Country_City) %>%
    filter(n() >= 2) %>%
    mutate(
      log_pop_centered = log_pop - mean(log_pop),
      log_mass_centered = log_mass - mean(log_mass)
    ) %>%
    ungroup()

  mod <- lm(log_mass_centered ~ log_pop_centered, data = dc)
  s <- summary(mod)
  delta <- coef(mod)[2]
  se <- s$coefficients[2, 2]

  list(
    delta = delta, se = se, r2 = s$r.squared,
    ci_low = delta - 1.96 * se, ci_high = delta + 1.96 * se,
    n_neighborhoods = nrow(dc),
    n_cities = n_distinct(dc$ID_HDC_G0),
    n_countries = n_distinct(dc$CTR_MN_NM)
  )
}

# =============================================================================
# STEP 3: Run analyses
# =============================================================================

# A. Baseline
cat("--- Baseline ---\n")
res_baseline <- run_decentered_nbhd(df, "total_built_mass_tons")
cat(sprintf("  delta = %.4f [%.4f, %.4f], R2 = %.4f, N = %d, cities = %d, countries = %d\n",
            res_baseline$delta, res_baseline$ci_low, res_baseline$ci_high,
            res_baseline$r2, res_baseline$n_neighborhoods,
            res_baseline$n_cities, res_baseline$n_countries))

# B. Individual sources
cat("--- Individual sources ---\n")
res_sources <- list()
for (src in sources) {
  total_col <- paste0("total_", src)
  res_sources[[src]] <- run_decentered_nbhd(df, total_col)
  cat(sprintf("  %-12s delta = %.4f [%.4f, %.4f], R2 = %.4f, N = %d, cities = %d, countries = %d\n",
              src, res_sources[[src]]$delta,
              res_sources[[src]]$ci_low, res_sources[[src]]$ci_high,
              res_sources[[src]]$r2, res_sources[[src]]$n_neighborhoods,
              res_sources[[src]]$n_cities, res_sources[[src]]$n_countries))
}

# C. Random source selection
cat(sprintf("--- Random (%d iterations) ---\n", N_ITERATIONS))

work_df <- df %>%
  filter(population_2015 >= 1, total_built_mass_tons > 0,
         ID_HDC_G0 %in% r6_city_ids, CTR_MN_ISO %in% r6_country_isos) %>%
  mutate(Country_City = paste(CTR_MN_NM, ID_HDC_G0, sep = "_"))

bldg_matrix <- as.matrix(work_df[, paste0("BuildingMass_Total_", sources)])
mobility <- work_df$mobility_mass_tons

# Pre-compute which sources are available (> 0) per neighborhood
available_mask <- bldg_matrix > 0  # logical matrix: N x 3

iter_results <- vector("list", N_ITERATIONS)
for (iter in seq_len(N_ITERATIONS)) {
  # For each neighborhood, randomly pick one source from those with data
  source_idx <- integer(nrow(work_df))
  for (i in seq_len(nrow(work_df))) {
    avail <- which(available_mask[i, ])
    if (length(avail) == 0L) {
      source_idx[i] <- NA_integer_
    } else if (length(avail) == 1L) {
      source_idx[i] <- avail
    } else {
      source_idx[i] <- sample(avail, 1L)
    }
  }
  random_bldg <- bldg_matrix[cbind(seq_len(nrow(work_df)), source_idx)]
  random_bldg[is.na(source_idx)] <- 0
  random_total <- random_bldg + mobility

  tmp <- work_df
  tmp$random_total <- random_total

  d <- tmp %>%
    filter(random_total > 0) %>%
    mutate(log_pop = log10(population_2015), log_mass = log10(random_total))

  dc <- d %>%
    group_by(Country_City) %>%
    filter(n() >= 2) %>%
    mutate(
      log_pop_centered = log_pop - mean(log_pop),
      log_mass_centered = log_mass - mean(log_mass)
    ) %>%
    ungroup()

  mod <- lm(log_mass_centered ~ log_pop_centered, data = dc)
  s <- summary(mod)

  iter_results[[iter]] <- tibble(
    iteration = iter,
    delta = coef(mod)[2],
    se = s$coefficients[2, 2],
    r2 = s$r.squared,
    n_neighborhoods = nrow(dc)
  )
}

iter_df <- bind_rows(iter_results)

cat(sprintf("  Delta: mean = %.4f, sd = %.4f, 95%% range = [%.4f, %.4f]\n",
            mean(iter_df$delta), sd(iter_df$delta),
            quantile(iter_df$delta, 0.025), quantile(iter_df$delta, 0.975)))

# D. Reliability-weighted average
cat("--- Reliability-Weighted Average ---\n")
res_weighted <- run_decentered_nbhd(df, "total_weighted")
cat(sprintf("  delta = %.4f [%.4f, %.4f], R2 = %.4f, N = %d, cities = %d, countries = %d\n",
            res_weighted$delta, res_weighted$ci_low, res_weighted$ci_high,
            res_weighted$r2, res_weighted$n_neighborhoods,
            res_weighted$n_cities, res_weighted$n_countries))

# =============================================================================
# SUMMARY TABLE
# =============================================================================

summary_rows <- list()

summary_rows[[1]] <- tibble(
  Resolution = 6, Hex_km2 = 36.13,
  Approach = "Baseline (Average)", Delta = res_baseline$delta,
  SE = res_baseline$se, CI_low = res_baseline$ci_low,
  CI_high = res_baseline$ci_high, R2 = res_baseline$r2,
  N_neighborhoods = res_baseline$n_neighborhoods,
  N_cities = res_baseline$n_cities, N_countries = res_baseline$n_countries)

for (i in seq_along(sources)) {
  src <- sources[i]
  r <- res_sources[[src]]
  summary_rows[[i + 1]] <- tibble(
    Resolution = 6, Hex_km2 = 36.13,
    Approach = src, Delta = r$delta, SE = r$se,
    CI_low = r$ci_low, CI_high = r$ci_high, R2 = r$r2,
    N_neighborhoods = r$n_neighborhoods,
    N_cities = r$n_cities, N_countries = r$n_countries)
}

summary_rows[[5]] <- tibble(
  Resolution = 6, Hex_km2 = 36.13,
  Approach = "Random (mean)", Delta = mean(iter_df$delta),
  SE = sd(iter_df$delta),
  CI_low = quantile(iter_df$delta, 0.025),
  CI_high = quantile(iter_df$delta, 0.975),
  R2 = mean(iter_df$r2),
  N_neighborhoods = round(mean(iter_df$n_neighborhoods)),
  N_cities = res_baseline$n_cities,
  N_countries = res_baseline$n_countries)

summary_rows[[6]] <- tibble(
  Resolution = 6, Hex_km2 = 36.13,
  Approach = "Reliability-Weighted", Delta = res_weighted$delta,
  SE = res_weighted$se, CI_low = res_weighted$ci_low,
  CI_high = res_weighted$ci_high, R2 = res_weighted$r2,
  N_neighborhoods = res_weighted$n_neighborhoods,
  N_cities = res_weighted$n_cities, N_countries = res_weighted$n_countries)

summary_df <- bind_rows(summary_rows)

cat("\n=== SUMMARY TABLE ===\n")
print(as.data.frame(summary_df), row.names = FALSE)

outfile_long <- file.path(figure_dir,
  paste0("Table_Decentered_R6_PerRes_Source_Sensitivity_Long_", Sys.Date(), ".csv"))
write_csv(summary_df, outfile_long)
cat("\nSaved:", outfile_long, "\n")

# =============================================================================
# ROBUSTNESS ASSESSMENT
# =============================================================================

source_deltas <- sapply(res_sources, function(r) unname(r$delta))
source_range <- diff(range(source_deltas))

cat("\n========================================\n")
cat("R6 PER-RESOLUTION FILTER SOURCE SENSITIVITY\n")
cat("========================================\n")
cat(sprintf("  Cities: %d, Countries: %d\n", length(r6_city_ids), length(r6_country_isos)))
cat(sprintf("  Baseline delta: %.4f\n", res_baseline$delta))
cat(sprintf("  Individual sources: Esch=%.4f, Li=%.4f, Liu=%.4f\n",
            source_deltas[["Esch2022"]], source_deltas[["Li2022"]], source_deltas[["Liu2024"]]))
cat(sprintf("  Source range: %.4f (%.2f%% of mean)\n",
            source_range, source_range / mean(source_deltas) * 100))
cat(sprintf("  Random mean: %.4f, sd: %.4f\n", mean(iter_df$delta), sd(iter_df$delta)))
cat(sprintf("  All sublinear: %s\n",
            ifelse(all(source_deltas < 1) & res_baseline$delta < 1, "YES", "NO")))
cat("========================================\n")
