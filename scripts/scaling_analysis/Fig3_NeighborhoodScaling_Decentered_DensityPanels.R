# =============================================================================
# Fig3_NeighborhoodScaling_Decentered_DensityPanels.R
#
# Variant of Fig3_NeighborhoodScaling_Decentered.R:
#   Panel A: Same de-centered scatter (unchanged)
#   Panel B: Density plots of slope (beta) — country-level vs city-level
#   Panel C: Density plots of intercept M0 — country-level vs city-level
#   + Companion statistics: F-test (variance) then t-test (mean)
#
# Based on Fig2 Panel A inset style (density/histogram with mean lines)
# =============================================================================

rm(list = ls())

if (!interactive()) pdf(NULL)

# =============================================================================
# 1. Packages
# =============================================================================
library(pacman)
pacman::p_load(
  sf, lme4, readr, dplyr, tibble, ggplot2, scales, viridis,
  cowplot, tidyr, ggrepel, ggspatial
)

# =============================================================================
# 2. Load TWO Data Sources
# =============================================================================

data_neighborhood_raw <- readr::read_csv(
  "../../data/processed/h3_resolution6/Fig3_Mass_Neighborhood_H3_Resolution6_2025-06-24.csv"
) %>%
  dplyr::rename(
    mass_building = BuildingMass_AverageTotal,
    mass_mobility = mobility_mass_tons,
    mass_avg = total_built_mass_tons,
    population = population_2015,
    city_id = ID_HDC_G0,
    country_iso = CTR_MN_ISO,
    country = CTR_MN_NM
  ) %>%
  dplyr::filter(population >= 1) %>%
  dplyr::filter(mass_avg > 0)

cat("Raw neighborhoods:", nrow(data_neighborhood_raw), "\n")

data_city_fig2 <- read.csv("../../data/processed/MasterMass_ByClass20250616.csv",
                           stringsAsFactors = FALSE) %>%
  dplyr::filter(total_built_mass_tons > 0)

cat("Raw cities (Figure 2 data):", nrow(data_city_fig2), "\n")

# =============================================================================
# 3. Filter Neighborhood Data
# =============================================================================

city_population_totals <- data_neighborhood_raw %>%
  dplyr::group_by(country_iso, city_id) %>%
  dplyr::summarize(total_population = sum(population), .groups = "drop") %>%
  dplyr::filter(total_population > 50000)

filtered_neighborhoods <- data_neighborhood_raw %>%
  dplyr::filter(city_id %in% city_population_totals$city_id)

city_neighborhood_counts <- filtered_neighborhoods %>%
  dplyr::group_by(country_iso, city_id) %>%
  dplyr::summarize(num_neighborhoods = n(), .groups = "drop") %>%
  dplyr::filter(num_neighborhoods >= 10)

filtered_neighborhoods <- filtered_neighborhoods %>%
  dplyr::filter(city_id %in% city_neighborhood_counts$city_id)

country_city_counts <- filtered_neighborhoods %>%
  dplyr::group_by(country_iso) %>%
  dplyr::summarize(num_cities = n_distinct(city_id)) %>%
  dplyr::filter(num_cities >= 5)

filtered_neighborhoods <- filtered_neighborhoods %>%
  dplyr::filter(country_iso %in% country_city_counts$country_iso)

filtered_neighborhoods <- filtered_neighborhoods %>%
  mutate(
    log_population = log10(population),
    log_mass_avg = log10(mass_avg)
  )

filtered_neighborhoods$Country <- factor(filtered_neighborhoods$country)
filtered_neighborhoods$Country_City <- factor(with(filtered_neighborhoods, paste(country, city_id, sep = "_")))

cat("\n=== Neighborhood Data (Filtered) ===\n")
cat("Neighborhoods:", nrow(filtered_neighborhoods), "\n")
cat("Cities:", n_distinct(filtered_neighborhoods$city_id), "\n")
cat("Countries:", n_distinct(filtered_neighborhoods$country), "\n")

# =============================================================================
# 4. Filter Figure 2 City Data
# =============================================================================

city_counts_fig2 <- table(data_city_fig2$CTR_MN_NM)
valid_countries_fig2 <- names(city_counts_fig2[city_counts_fig2 >= 5])

filtered_cities_fig2 <- data_city_fig2 %>%
  dplyr::filter(CTR_MN_NM %in% valid_countries_fig2) %>%
  mutate(
    log_population = log10(population_2015),
    log_mass = log10(total_built_mass_tons)
  )

cat("\n=== City Data (Figure 2, Filtered) ===\n")
cat("Cities:", nrow(filtered_cities_fig2), "\n")
cat("Countries:", length(valid_countries_fig2), "\n")

# =============================================================================
# 5. Panel A: De-center Neighborhoods by CITY
# =============================================================================

decentered_neighborhoods <- filtered_neighborhoods %>%
  group_by(Country_City) %>%
  mutate(
    city_mean_log_pop = mean(log_population),
    city_mean_log_mass = mean(log_mass_avg),
    log_pop_centered = log_population - city_mean_log_pop,
    log_mass_centered = log_mass_avg - city_mean_log_mass
  ) %>%
  ungroup()

mod_city_level <- lm(log_mass_centered ~ log_pop_centered, data = decentered_neighborhoods)
summary_city <- summary(mod_city_level)

delta <- coef(mod_city_level)[2]
se_delta <- summary_city$coefficients[2, 2]
r2_city_level <- summary_city$r.squared
n_neighborhoods <- nrow(decentered_neighborhoods)

cat("\n=== City-level De-centered OLS (delta) ===\n")
cat("Delta (slope):", round(delta, 4), "\n")
cat("95% CI: [", round(delta - 1.96 * se_delta, 4), ",", round(delta + 1.96 * se_delta, 4), "]\n")

# =============================================================================
# 6. Country-level Beta (hardcoded from Figure 2)
# =============================================================================

beta <- 0.90

# =============================================================================
# 7. Per-City Slopes and M0
# =============================================================================

city_slopes <- decentered_neighborhoods %>%
  group_by(Country_City, country, city_id, UC_NM_MN) %>%
  filter(n() >= 10) %>%
  group_modify(~ {
    mod <- lm(log_mass_centered ~ log_pop_centered, data = .x)
    tibble(Slope = coef(mod)[2], n_neighborhoods = nrow(.x))
  }) %>%
  ungroup()

city_stats <- city_slopes

# =============================================================================
# 8. Per-Country Slopes and M0 (from Figure 2 city data)
# =============================================================================

decentered_cities_fig2 <- filtered_cities_fig2 %>%
  group_by(CTR_MN_NM) %>%
  mutate(
    country_mean_log_pop = mean(log_population),
    country_mean_log_mass = mean(log_mass),
    log_pop_centered = log_population - country_mean_log_pop,
    log_mass_centered = log_mass - country_mean_log_mass
  ) %>%
  ungroup()

country_slopes <- decentered_cities_fig2 %>%
  group_by(CTR_MN_NM) %>%
  filter(n() >= 5) %>%
  group_modify(~ {
    mod <- lm(log_mass_centered ~ log_pop_centered, data = .x)
    tibble(Slope = coef(mod)[2], n_cities = nrow(.x))
  }) %>%
  ungroup()

country_stats <- country_slopes %>%
  rename(Country = CTR_MN_NM)

cat("\n=== Country-level Stats ===\n")
cat("Countries:", nrow(country_stats), "\n")
cat("Cities:", nrow(city_stats), "\n")

# =============================================================================
# 9. Panel A: De-centered Scatter with NY Inset (unchanged)
# =============================================================================

decentered_neighborhoods <- decentered_neighborhoods %>%
  mutate(is_newyork = (UC_NM_MN == "New York"))

sf_cities <- sf::read_sf("../../data/processed/h3_resolution6/all_cities_h3_grids_resolution6.gpkg") %>%
  dplyr::rename(hex_id = h3index)

sf_newyork <- sf_cities %>% dplyr::filter(UC_NM_MN == "New York")
data_newyork <- decentered_neighborhoods %>% filter(is_newyork, population > 10)
sf_newyork <- sf_newyork %>% left_join(data_newyork, by = c("hex_id" = "h3index"))

ny_boundary <- st_union(sf_newyork)
max_hex <- sf_newyork %>% filter(log_population == max(log_population, na.rm = TRUE))

map_inset <- ggplot() +
  # Add Carto basemap
  annotation_map_tile(
    type = "cartolight",
    zoom = 12
  ) +
  geom_sf(data = sf_newyork, aes(fill = pmax(log_population, 3)), color = NA, alpha = 0.6) +
  geom_sf(data = ny_boundary, color = "#fc8d62", fill = NA, linewidth = 1) +
  geom_sf(data = max_hex, color = "#bf0000", fill = NA, linewidth = 1) +
  scale_fill_viridis_c(option = "viridis", guide = "none") +
  labs(title = "New York") +
  theme_void() +
  theme(legend.position = "none", plot.title = element_text(size = 10))

scatter_plot <- ggplot(decentered_neighborhoods,
                       aes(x = log_pop_centered, y = log_mass_centered)) +
  geom_point(alpha = 0.03, color = "#8da0cb") +
  geom_point(data = data_newyork,
             aes(x = log_pop_centered, y = log_mass_centered,
                 color = pmax(log_population, 3))) +
  geom_abline(slope = delta, intercept = 0, color = "#bf0000", alpha = 0.7, lwd = 0.75) +
  geom_abline(slope = beta, intercept = 0, color = "#fc8d62", alpha = 0.7, lwd = 0.75) +
  geom_abline(slope = 1, intercept = 0, color = "black", linetype = "dashed", lwd = 0.75) +
  scale_color_viridis_c(option = "viridis", guide = "none") +
  coord_cartesian(xlim = c(-5, 3), ylim = c(-4.5, 2)) +
  labs(
    x = "Log population (deviation from city mean)",
    y = "Log mass (deviation from city mean)"
  ) +
  theme_bw() +
  theme(
    legend.position = "none",
    text = element_text(size = 12),
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor.y = element_blank()
  ) +
  annotate("text", x = -4.8, y = 1.7,
           label = sprintf("Delta*log[10](M[ij]) == %.2f * Delta*log[10](N[ij])", round(beta, 2)),
           color = "#fc8d62", parse = TRUE, hjust = 0, size = 3.5) +
  annotate("text", x = -4.8, y = 1.3,
           label = sprintf("Delta*log[10](M[ijk]) == %.2f * Delta*log[10](N[ijk])", round(delta, 2)),
           color = "#bf0000", parse = TRUE, hjust = 0, size = 3.5)

panel_A <- ggdraw() +
  draw_plot(scatter_plot) +
  draw_plot(map_inset, x = 0.6, y = 0.15, width = 0.35, height = 0.35)

# =============================================================================
# 10. Panels B & C: Slope Density — Country-level (B) and City-level (C)
#     Stacked with shared x-axis (facet-like layout)
# =============================================================================

# Compute means and 95% CIs for means
mean_slope_country <- mean(country_stats$Slope, na.rm = TRUE)
se_slope_country <- sd(country_stats$Slope, na.rm = TRUE) / sqrt(nrow(country_stats))
ci_country <- mean_slope_country + c(-1, 1) * 1.96 * se_slope_country

mean_slope_city <- mean(city_stats$Slope, na.rm = TRUE)
se_slope_city <- sd(city_stats$Slope, na.rm = TRUE) / sqrt(nrow(city_stats))
ci_city <- mean_slope_city + c(-1, 1) * 1.96 * se_slope_city

# Run F-test and Welch's t-test upfront (needed for Panel B annotation)
f_test_slope <- var.test(country_stats$Slope, city_stats$Slope)
equal_var_slope <- f_test_slope$p.value > 0.05
t_test_slope <- t.test(country_stats$Slope, city_stats$Slope, var.equal = equal_var_slope)

# Shared x-axis range (add margin for text annotations)
x_range <- range(c(country_stats$Slope, city_stats$Slope), na.rm = TRUE)
x_limits <- c(x_range[1] - 0.05, x_range[2] + 0.15)

# Common theme for both panels (match Fig2: size 12 base text)
theme_density <- theme_bw() +
  theme(
    text = element_text(size = 12),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank()
  )

# Panel B: Country-level slopes (x-axis label = beta)
panel_B_density <- ggplot(country_stats, aes(x = Slope)) +
  geom_density(fill = "#fc8d62", color = "#fc8d62", alpha = 0.35, linewidth = 0.6) +
  # Own mean (solid)
  geom_vline(xintercept = mean_slope_country, color = "#fc8d62", linetype = "solid", linewidth = 0.8) +
  # City-level mean reference (dashed dark red)
  geom_vline(xintercept = mean_slope_city, color = "#bf0000", linetype = "dashed", linewidth = 0.6) +
  # Linear scaling reference
  geom_vline(xintercept = 1, color = "black", linetype = "dashed", linewidth = 0.5) +
  scale_x_continuous(limits = x_limits) +
  # Stats annotation (upper left)
  annotate("text", x = x_limits[1] + 0.02, y = Inf, vjust = 1.3, hjust = 0,
           label = sprintf("bar(beta) == %.3f~~group('[', list(%.3f, %.3f), ']')~~(n == %d)",
                           mean_slope_country, ci_country[1], ci_country[2], nrow(country_stats)),
           color = "#fc8d62", parse = TRUE, size = 3.5) +
  annotate("text", x = x_limits[1] + 0.02, y = Inf, vjust = 3.0, hjust = 0,
           label = sprintf("F == %.2f~~(p == %.1e)", f_test_slope$statistic, f_test_slope$p.value),
           parse = TRUE, size = 3, color = "grey30") +
  annotate("text", x = x_limits[1] + 0.02, y = Inf, vjust = 4.5, hjust = 0,
           label = sprintf("Welch~t == %.2f~~(p == %.1e)", t_test_slope$statistic, t_test_slope$p.value),
           parse = TRUE, size = 3, color = "grey30") +
  labs(x = expression("Scaling exponent " * beta ~ "(country-level)"), y = "Density") +
  theme_density +
  theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())

# Panel C: City-level slopes (x-axis label = delta)
panel_C_density <- ggplot(city_stats, aes(x = Slope)) +
  geom_density(fill = "#bf0000", color = "#bf0000", alpha = 0.35, linewidth = 0.6) +
  # Own mean (solid)
  geom_vline(xintercept = mean_slope_city, color = "#bf0000", linetype = "solid", linewidth = 0.8) +
  # Country-level mean reference (dashed orange)
  geom_vline(xintercept = mean_slope_country, color = "#fc8d62", linetype = "dashed", linewidth = 0.6) +
  # Linear scaling reference
  geom_vline(xintercept = 1, color = "black", linetype = "dashed", linewidth = 0.5) +
  scale_x_continuous(limits = x_limits) +
  annotate("text", x = x_limits[1] + 0.02, y = Inf, vjust = 1.3, hjust = 0,
           label = sprintf("bar(delta) == %.3f~~group('[', list(%.3f, %.3f), ']')~~(n == %d)",
                           mean_slope_city, ci_city[1], ci_city[2], nrow(city_stats)),
           color = "#bf0000", parse = TRUE, size = 3.5) +
  labs(x = expression("Scaling exponent " * delta ~ "(city-level)"), y = "Density") +
  theme_density

# Stack B and C with shared x-axis
density_panels <- cowplot::plot_grid(panel_B_density, panel_C_density,
                                     nrow = 2, align = 'v', axis = 'lr',
                                     labels = c("B", "C"),
                                     rel_heights = c(1, 1.1))  # slightly taller for bottom axis

# =============================================================================
# 11. Assemble Final Figure
# =============================================================================

combined_plot <- plot_grid(panel_A, density_panels,
                           labels = c("A", ""),
                           ncol = 2, nrow = 1,
                           rel_widths = c(1.6, 1))

# =============================================================================
# 14. Save Figure
# =============================================================================

current_date <- Sys.Date()
output_filename_pdf <- paste0("../figures/Fig3_Decentered_DensityPanels_", current_date, ".pdf")
output_filename_png <- paste0("../figures/Fig3_Decentered_DensityPanels_", current_date, ".png")

# Save PDF
ggsave(output_filename_pdf,
       combined_plot,
       device = "pdf",
       width = 30,
       height = 12,
       units = "cm",
       dpi = 300)

cat("\nPDF saved to:", output_filename_pdf, "\n")

# Save PNG
ggsave(output_filename_png,
       combined_plot,
       device = "png",
       width = 30,
       height = 12,
       units = "cm",
       dpi = 300)

cat("PNG saved to:", output_filename_png, "\n")

# =============================================================================
# 15. Companion Statistics: F-test and t-test for Slope (beta)
# =============================================================================

cat("\n")
cat("================================================================\n")
cat("COMPANION STATISTICS: Scaling Exponent (beta)\n")
cat("================================================================\n")

cat(sprintf("  Country-level: N = %d, mean = %.4f, sd = %.4f\n",
            nrow(country_stats), mean_slope_country, sd(country_stats$Slope, na.rm = TRUE)))
cat(sprintf("  City-level:    N = %d, mean = %.4f, sd = %.4f\n",
            nrow(city_stats), mean_slope_city, sd(city_stats$Slope, na.rm = TRUE)))

# F-test for equality of variances
f_test_slope <- var.test(country_stats$Slope, city_stats$Slope)
cat(sprintf("\n  F-test (H0: equal variances):\n"))
cat(sprintf("    F = %.4f, df1 = %d, df2 = %d\n",
            f_test_slope$statistic, f_test_slope$parameter[1], f_test_slope$parameter[2]))
cat(sprintf("    p-value = %.4e\n", f_test_slope$p.value))
cat(sprintf("    Var(country) / Var(city) = %.4f\n", f_test_slope$estimate))
equal_var_slope <- f_test_slope$p.value > 0.05
cat(sprintf("    Conclusion: %s\n",
            ifelse(equal_var_slope, "Cannot reject equal variances (p > 0.05)",
                   "Reject equal variances (p <= 0.05) -> use Welch's t-test")))

# t-test for difference in means
t_test_slope <- t.test(country_stats$Slope, city_stats$Slope,
                        var.equal = equal_var_slope)
cat(sprintf("\n  %s t-test (H0: equal means):\n",
            ifelse(equal_var_slope, "Student's", "Welch's")))
cat(sprintf("    t = %.4f, df = %.2f\n", t_test_slope$statistic, t_test_slope$parameter))
cat(sprintf("    p-value = %.4e\n", t_test_slope$p.value))
cat(sprintf("    95%% CI for difference: [%.4f, %.4f]\n",
            t_test_slope$conf.int[1], t_test_slope$conf.int[2]))
cat(sprintf("    Mean difference (country - city): %.4f\n",
            mean_slope_country - mean_slope_city))
cat(sprintf("    Conclusion: %s\n",
            ifelse(t_test_slope$p.value <= 0.05,
                   "Significant difference in means (p <= 0.05)",
                   "No significant difference in means (p > 0.05)")))
cat("================================================================\n")
