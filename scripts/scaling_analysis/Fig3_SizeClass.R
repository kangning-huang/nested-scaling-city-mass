# =============================================================================
# Fig3 Sub-Analysis: Within-City Scaling Slope (δ) by City Size Class
# =============================================================================
# Purpose: Test whether larger cities have lower within-city scaling slopes (δ).
#
# Approach:
#   1. Load & filter H3 Resolution 6 neighborhood data (same pipeline as main Fig3)
#   2. Compute per-city δ via de-centering within each city
#   3. Classify cities into 3 size classes (Q25 / Q25-Q75 / Q75) by total population
#   4. Violin + box + jitter plot comparing δ across size classes
#
# Output: _Revision1/figures/Fig3_SizeClass.pdf / .png
# =============================================================================

rm(list = ls())
if (!interactive()) pdf(NULL)

library(pacman)
pacman::p_load(readr, dplyr, tibble, ggplot2, scales, cowplot)

# =============================================================================
# SETUP
# =============================================================================

project_root <- rprojroot::find_root(rprojroot::has_file("CLAUDE.md"))
data_dir     <- file.path(project_root, "_Revision1", "data")
figure_dir   <- file.path(project_root, "_Revision1", "figures")
dir.create(figure_dir, showWarnings = FALSE, recursive = TRUE)

data_file <- file.path(data_dir,
  "Fig3_Mass_Neighborhood_H3_Resolution6_2025-06-24.csv")

cat("=== Fig3 Size Class Sub-Analysis ===\n")
cat("Data:", data_file, "\n\n")

# =============================================================================
# STEP 1: LOAD & FILTER (mirrors main Fig3 R6 pipeline, v3 criteria)
# =============================================================================

raw <- readr::read_csv(data_file, show_col_types = FALSE) %>%
  dplyr::rename(
    mass      = total_built_mass_tons,
    pop       = population_2015,
    city_id   = ID_HDC_G0,
    country   = CTR_MN_ISO,
    city_name = UC_NM_MN
  ) %>%
  dplyr::filter(pop >= 1, mass > 0)

cat("After pop >= 1, mass > 0:", nrow(raw), "neighborhoods\n")

# --- City total population (derived from neighborhood sums) ---
city_pop <- raw %>%
  group_by(city_id) %>%
  summarise(city_total_pop = sum(pop), .groups = "drop")

# Filter 1: city total pop > 50,000
city_pop_filtered <- city_pop %>% filter(city_total_pop > 50000)
raw <- raw %>% filter(city_id %in% city_pop_filtered$city_id)
cat("After city pop > 50,000:", nrow(raw), "neighborhoods,",
    n_distinct(raw$city_id), "cities\n")

# Filter 2: cities with >= 10 qualifying neighborhoods
city_n_nbhd <- raw %>%
  group_by(city_id) %>%
  summarise(n_nbhd = n(), .groups = "drop") %>%
  filter(n_nbhd >= 10)

raw <- raw %>% filter(city_id %in% city_n_nbhd$city_id)
cat("After city >= 10 neighborhoods:", nrow(raw), "neighborhoods,",
    n_distinct(raw$city_id), "cities\n")

# Filter 3: countries with >= 5 qualifying cities
country_n_cities <- raw %>%
  group_by(country) %>%
  summarise(n_cities = n_distinct(city_id), .groups = "drop") %>%
  filter(n_cities >= 5)

raw <- raw %>% filter(country %in% country_n_cities$country)
cat("After country >= 5 cities:", nrow(raw), "neighborhoods,",
    n_distinct(raw$city_id), "cities,",
    n_distinct(raw$country), "countries\n\n")

# =============================================================================
# STEP 2: PER-CITY δ VIA DE-CENTERING
# =============================================================================

# De-center within each city
decentered <- raw %>%
  group_by(city_id) %>%
  mutate(
    log_pop_c  = log10(pop)  - mean(log10(pop)),
    log_mass_c = log10(mass) - mean(log10(mass))
  ) %>%
  ungroup()

# OLS per city -> extract slope = δ_city
# Require >= 10 neighborhoods per city (already guaranteed by Filter 2 above)
fit_city <- function(df) {
  mod <- lm(log_mass_c ~ log_pop_c, data = df)
  tibble(
    delta  = coef(mod)[2],
    se     = summary(mod)$coefficients[2, 2],
    r2     = summary(mod)$r.squared,
    n_hex  = nrow(df)
  )
}

cat("Computing per-city slopes...\n")
city_deltas <- decentered %>%
  group_by(city_id, city_name, country) %>%
  group_modify(~ fit_city(.x)) %>%
  ungroup()

cat("Cities with valid δ:", nrow(city_deltas), "\n")
cat("  Mean δ:", round(mean(city_deltas$delta), 4), "\n")
cat("  Median δ:", round(median(city_deltas$delta), 4), "\n\n")

# =============================================================================
# STEP 3: CLASSIFY CITIES BY SIZE CLASS
# =============================================================================

city_deltas <- city_deltas %>%
  left_join(city_pop_filtered, by = "city_id") %>%
  mutate(
    q25 = quantile(city_total_pop, 0.25),
    q75 = quantile(city_total_pop, 0.75),
    size_class = case_when(
      city_total_pop <  q25 ~ "Small\n(<Q25)",
      city_total_pop <= q75 ~ "Medium\n(Q25-Q75)",
      TRUE                  ~ "Large\n(>Q75)"
    ),
    size_class = factor(size_class, levels = c("Small\n(<Q25)", "Medium\n(Q25-Q75)", "Large\n(>Q75)"))
  )

# Print class boundaries and counts
cat("Size class thresholds:\n")
cat(sprintf("  Q25: %s people\n", format(round(city_deltas$q25[1]), big.mark = ",")))
cat(sprintf("  Q75: %s people\n", format(round(city_deltas$q75[1]), big.mark = ",")))
cat("\nN cities per size class:\n")
print(table(city_deltas$size_class))

# Summary stats per class
class_summary <- city_deltas %>%
  group_by(size_class) %>%
  summarise(
    n       = n(),
    mean_d  = mean(delta),
    median_d = median(delta),
    sd_d    = sd(delta),
    q25_d   = quantile(delta, 0.25),
    q75_d   = quantile(delta, 0.75),
    .groups = "drop"
  )

cat("\nSummary δ per size class:\n")
print(as.data.frame(class_summary), row.names = FALSE)

# =============================================================================
# STEP 4: PLOT
# =============================================================================

# Color palette: cool blue to warm orange
size_colors <- c(
  "Small\n(<Q25)"    = "#2166ac",
  "Medium\n(Q25-Q75)" = "#74add1",
  "Large\n(>Q75)"   = "#d6604d"
)

# N label positions (below violin bottom)
n_labels <- city_deltas %>%
  group_by(size_class) %>%
  summarise(n = n(), y_pos = min(delta) - 0.05, .groups = "drop")

p <- ggplot(city_deltas, aes(x = size_class, y = delta, fill = size_class)) +
  # Violin
  geom_violin(alpha = 0.35, trim = TRUE, color = NA) +
  # Jitter (behind box)
  geom_jitter(aes(color = size_class), width = 0.12, alpha = 0.20,
              size = 0.8, show.legend = FALSE) +
  # Boxplot (no outliers — shown by jitter)
  geom_boxplot(width = 0.18, outlier.shape = NA, lwd = 0.5,
               fill = "white", alpha = 0.7) +
  # Reference: linear scaling (δ = 1)
  geom_hline(yintercept = 1, linetype = "dashed", color = "grey50", linewidth = 0.6) +
  # Reference: benchmark δ ≈ 0.751
  geom_hline(yintercept = 0.751, linetype = "dotted", color = "#666666", linewidth = 0.6) +
  # Mean diamond
  stat_summary(fun = mean, geom = "point", shape = 18, size = 3.5,
               color = "black", show.legend = FALSE) +
  # N per class
  geom_text(data = n_labels,
            aes(x = size_class, y = y_pos, label = paste0("n = ", n)),
            inherit.aes = FALSE, size = 3, color = "grey30") +
  # Annotations for reference lines
  annotate("text", x = 0.55, y = 1.01, label = "delta = 1 (linear)",
           hjust = 0, size = 2.8, color = "grey50", fontface = "italic") +
  annotate("text", x = 0.55, y = 0.761, label = "delta = 0.751 (global mean)",
           hjust = 0, size = 2.8, color = "#666666", fontface = "italic") +
  scale_fill_manual(values = size_colors) +
  scale_color_manual(values = size_colors) +
  labs(
    x     = "City Size Class (by total population)",
    y     = expression(delta ~ "(within-city scaling slope)"),
    title = "Within-city scaling slope by city size",
    subtitle = paste0("H3 Resolution 6 | N = ", nrow(city_deltas), " cities | per-city OLS on de-centered data")
  ) +
  theme_classic(base_size = 12) +
  theme(
    legend.position  = "none",
    plot.title       = element_text(size = 13, face = "bold"),
    plot.subtitle    = element_text(size = 9,  color = "grey40"),
    axis.text        = element_text(size = 11),
    axis.title       = element_text(size = 11),
    panel.grid.major.y = element_line(color = "grey92", linewidth = 0.4)
  )

# =============================================================================
# SAVE OUTPUTS
# =============================================================================

ggsave(file.path(figure_dir, "Fig3_SizeClass.pdf"), p, width = 7, height = 5.5)
ggsave(file.path(figure_dir, "Fig3_SizeClass.png"), p, width = 7, height = 5.5, dpi = 300)

# Save city-level data with size class for downstream use
readr::write_csv(city_deltas %>% select(-q25, -q75),
                 file.path(figure_dir, "Table_Fig3_SizeClass_CityDeltas.csv"))

cat("\nOutputs saved:\n")
cat("  Figures:", file.path(figure_dir, "Fig3_SizeClass.pdf"), "\n")
cat("            ", file.path(figure_dir, "Fig3_SizeClass.png"), "\n")
cat("  Data:    ", file.path(figure_dir, "Table_Fig3_SizeClass_CityDeltas.csv"), "\n")

# =============================================================================
# VERIFICATION
# =============================================================================

cat("\n=== VERIFICATION ===\n")
cat(sprintf("Overall mean δ: %.4f (expected ~0.751)\n", mean(city_deltas$delta)))
cat(sprintf("N per class — Small: %d, Medium: %d, Large: %d\n",
            sum(city_deltas$size_class == "Small\n(<Q25)"),
            sum(city_deltas$size_class == "Medium\n(Q25-Q75)"),
            sum(city_deltas$size_class == "Large\n(>Q75)")))
cat(sprintf("Expected split — ~25%% / ~50%% / ~25%% by quartile design\n"))

cat("\nMean δ per class:\n")
for (i in seq_len(nrow(class_summary))) {
  cat(sprintf("  %-22s: %.4f (median %.4f)\n",
              as.character(class_summary$size_class[i]),
              class_summary$mean_d[i],
              class_summary$median_d[i]))
}
cat("\n=== DONE ===\n")

# =============================================================================
# BONUS: TOP 50 vs BOTTOM 50 CITIES
# =============================================================================

cat("\n=== TOP 50 vs BOTTOM 50 CITIES ===\n")

top50 <- city_deltas %>%
  arrange(desc(city_total_pop)) %>%
  slice_head(n = 50) %>%
  mutate(group = "Top 50\n(largest)")

bot50 <- city_deltas %>%
  arrange(city_total_pop) %>%
  slice_head(n = 50) %>%
  mutate(group = "Bottom 50\n(smallest)")

extreme50 <- bind_rows(top50, bot50) %>%
  mutate(group = factor(group, levels = c("Bottom 50\n(smallest)", "Top 50\n(largest)")))

# Print stats
for (g in levels(extreme50$group)) {
  sub <- extreme50 %>% filter(group == g)
  cat(sprintf(
    "%s: pop range [%s, %s], mean delta=%.4f, median=%.4f, sd=%.4f\n",
    gsub("\n", " ", g),
    format(round(min(sub$city_total_pop)), big.mark = ","),
    format(round(max(sub$city_total_pop)), big.mark = ","),
    mean(sub$delta), median(sub$delta), sd(sub$delta)
  ))
}

# Wilcoxon rank-sum test (non-parametric, avoids normality assumption)
wtest <- wilcox.test(
  extreme50$delta[extreme50$group == "Top 50\n(largest)"],
  extreme50$delta[extreme50$group == "Bottom 50\n(smallest)"]
)
cat(sprintf("\nWilcoxon test: W = %.0f, p = %.4f\n", wtest$statistic, wtest$p.value))

# --- Plot ---
extreme_colors <- c("Bottom 50\n(smallest)" = "#2166ac", "Top 50\n(largest)" = "#d6604d")

# City name labels for extreme points
label_top <- extreme50 %>%
  group_by(group) %>%
  slice_min(delta, n = 3) %>%
  bind_rows(extreme50 %>% group_by(group) %>% slice_max(delta, n = 2)) %>%
  ungroup() %>%
  mutate(label = paste0(substr(city_name, 1, 15)))

p2 <- ggplot(extreme50, aes(x = group, y = delta, fill = group)) +
  geom_violin(alpha = 0.35, trim = TRUE, color = NA) +
  geom_jitter(aes(color = group), width = 0.12, alpha = 0.40,
              size = 1.2, show.legend = FALSE) +
  geom_boxplot(width = 0.18, outlier.shape = NA, lwd = 0.6,
               fill = "white", alpha = 0.8) +
  geom_hline(yintercept = 1,     linetype = "dashed", color = "grey50", linewidth = 0.6) +
  geom_hline(yintercept = 0.751, linetype = "dotted", color = "#666666", linewidth = 0.6) +
  stat_summary(fun = mean, geom = "point", shape = 18, size = 4,
               color = "black", show.legend = FALSE) +
  # p-value annotation
  annotate("text", x = 1.5, y = max(extreme50$delta) + 0.05,
           label = sprintf("Wilcoxon p = %.3f", wtest$p.value),
           size = 3.2, color = "grey30") +
  annotate("segment", x = 1, xend = 2,
           y = max(extreme50$delta) + 0.02, yend = max(extreme50$delta) + 0.02,
           color = "grey50", linewidth = 0.5) +
  scale_fill_manual(values = extreme_colors) +
  scale_color_manual(values = extreme_colors) +
  labs(
    x     = NULL,
    y     = expression(delta ~ "(within-city scaling slope)"),
    title = "Top 50 vs. Bottom 50 Cities by Population",
    subtitle = paste0(
      "Bottom 50 pop range: ",
      format(round(min(bot50$city_total_pop)), big.mark = ","), " - ",
      format(round(max(bot50$city_total_pop)), big.mark = ","),
      "  |  Top 50 pop range: ",
      format(round(min(top50$city_total_pop)), big.mark = ","), " - ",
      format(round(max(top50$city_total_pop)), big.mark = ",")
    )
  ) +
  theme_classic(base_size = 12) +
  theme(
    legend.position    = "none",
    plot.title         = element_text(size = 13, face = "bold"),
    plot.subtitle      = element_text(size = 8,  color = "grey40"),
    axis.text          = element_text(size = 12),
    axis.title.y       = element_text(size = 11),
    panel.grid.major.y = element_line(color = "grey92", linewidth = 0.4)
  )

ggsave(file.path(figure_dir, "Fig3_SizeClass_Top50vsBot50.pdf"), p2, width = 5.5, height = 5.5)
ggsave(file.path(figure_dir, "Fig3_SizeClass_Top50vsBot50.png"), p2, width = 5.5, height = 5.5, dpi = 300)

# Save the extreme-50 data
readr::write_csv(
  extreme50 %>% select(city_id, city_name, country, city_total_pop, delta, se, r2, n_hex, group),
  file.path(figure_dir, "Table_Fig3_Top50vsBot50_CityDeltas.csv")
)

cat("Saved: Fig3_SizeClass_Top50vsBot50.pdf / .png\n")
cat("=== ALL DONE ===\n")

# =============================================================================
# BONUS 2: DELTA BY WORLD REGION
# =============================================================================
# 35 qualifying countries mapped to 8 regions.
# East Asia is singled out per hypothesis that δ is lower there.
# =============================================================================

cat("\n=== DELTA BY WORLD REGION ===\n")

region_map <- c(
  CHN = "East Asia",   JPN = "East Asia",   KOR = "East Asia",   TWN = "East Asia",
  BGD = "South Asia",  IND = "South Asia",  PAK = "South Asia",
  IDN = "SE Asia",     MYS = "SE Asia",     PHL = "SE Asia",     VNM = "SE Asia",
  BEL = "Europe",      DEU = "Europe",      ESP = "Europe",      FRA = "Europe",
  GBR = "Europe",      ITA = "Europe",      NLD = "Europe",      POL = "Europe",
  UKR = "Europe",      RUS = "Europe",
  CAN = "N. America",  MEX = "N. America",  USA = "N. America",
  ARG = "Lat. America",BRA = "Lat. America",COL = "Lat. America",VEN = "Lat. America",
  EGY = "Middle East", IRN = "Middle East", SAU = "Middle East", TUR = "Middle East",
  NGA = "Africa",      ZAF = "Africa",
  AUS = "Oceania"
)

# Order by median δ (computed below) so plot is sorted
city_region <- city_deltas %>%
  mutate(region = region_map[country]) %>%
  filter(!is.na(region))

# Compute median per region for ordering
region_order <- city_region %>%
  group_by(region) %>%
  summarise(med = median(delta), n = n(), .groups = "drop") %>%
  arrange(med)

city_region <- city_region %>%
  mutate(region = factor(region, levels = region_order$region))

# Print summary
region_summary <- city_region %>%
  group_by(region) %>%
  summarise(
    n        = n(),
    mean_d   = mean(delta),
    median_d = median(delta),
    sd_d     = sd(delta),
    .groups  = "drop"
  ) %>%
  arrange(median_d)

cat("\nSummary δ by region (sorted by median):\n")
print(as.data.frame(region_summary), row.names = FALSE)

# Kruskal-Wallis test across regions
kw <- kruskal.test(delta ~ region, data = city_region)
cat(sprintf("\nKruskal-Wallis: chi2 = %.2f, df = %d, p = %.4f\n",
            kw$statistic, kw$parameter, kw$p.value))

# Pairwise Wilcoxon vs East Asia (the hypothesis of interest)
cat("\nPairwise Wilcoxon vs East Asia (BH-adjusted):\n")
ea_delta <- city_region$delta[city_region$region == "East Asia"]
other_regions <- setdiff(levels(city_region$region), "East Asia")
pw_results <- lapply(other_regions, function(r) {
  other_delta <- city_region$delta[city_region$region == r]
  wt <- wilcox.test(ea_delta, other_delta)
  tibble(region = r, W = wt$statistic, p_raw = wt$p.value)
}) %>% bind_rows() %>%
  mutate(p_adj = p.adjust(p_raw, method = "BH")) %>%
  arrange(p_raw)
print(as.data.frame(pw_results %>% mutate(across(where(is.numeric), ~round(.x, 4)))),
      row.names = FALSE)

# --- Region color palette (East Asia highlighted) ---
region_levels <- levels(city_region$region)
region_colors <- setNames(
  rep("#aaaaaa", length(region_levels)),
  region_levels
)
region_colors["East Asia"] <- "#d6604d"  # warm red — highlighted

# N labels per region
region_n <- city_region %>%
  group_by(region) %>%
  summarise(n = n(), y_pos = min(delta) - 0.07, .groups = "drop")

p3 <- ggplot(city_region, aes(x = region, y = delta,
                               fill = region, color = region)) +
  geom_violin(alpha = 0.30, trim = TRUE, color = NA) +
  geom_jitter(width = 0.15, alpha = 0.25, size = 0.8, show.legend = FALSE) +
  geom_boxplot(width = 0.2, outlier.shape = NA, lwd = 0.5,
               fill = "white", alpha = 0.8, color = "grey30") +
  geom_hline(yintercept = 1,     linetype = "dashed", color = "grey50", linewidth = 0.5) +
  geom_hline(yintercept = 0.751, linetype = "dotted", color = "#666666", linewidth = 0.5) +
  stat_summary(fun = mean, geom = "point", shape = 18, size = 3,
               color = "black", show.legend = FALSE) +
  geom_text(data = region_n,
            aes(x = region, y = y_pos, label = paste0("n=", n)),
            inherit.aes = FALSE, size = 2.5, color = "grey40") +
  scale_fill_manual(values = region_colors) +
  scale_color_manual(values = region_colors) +
  annotate("text",
           x    = length(region_levels) + 0.4,
           y    = 0.755,
           label = sprintf("KW p = %.3f", kw$p.value),
           hjust = 1, size = 2.8, color = "grey40") +
  labs(
    x     = NULL,
    y     = expression(delta ~ "(within-city scaling slope)"),
    title = "Within-city scaling slope by world region",
    subtitle = paste0("H3 Resolution 6 | N = ", nrow(city_region), " cities | 35 countries | sorted by median delta")
  ) +
  theme_classic(base_size = 11) +
  theme(
    legend.position    = "none",
    plot.title         = element_text(size = 12, face = "bold"),
    plot.subtitle      = element_text(size = 8,  color = "grey40"),
    axis.text.x        = element_text(size = 10, angle = 30, hjust = 1),
    axis.text.y        = element_text(size = 10),
    axis.title.y       = element_text(size = 10),
    panel.grid.major.y = element_line(color = "grey92", linewidth = 0.4)
  )

ggsave(file.path(figure_dir, "Fig3_SizeClass_ByRegion.pdf"), p3, width = 9, height = 5.5)
ggsave(file.path(figure_dir, "Fig3_SizeClass_ByRegion.png"), p3, width = 9, height = 5.5, dpi = 300)

readr::write_csv(
  city_region %>% select(city_id, city_name, country, region, city_total_pop, delta, se, r2, n_hex),
  file.path(figure_dir, "Table_Fig3_ByRegion_CityDeltas.csv")
)

cat("Saved: Fig3_SizeClass_ByRegion.pdf / .png\n")
cat("=== TRULY ALL DONE ===\n")
