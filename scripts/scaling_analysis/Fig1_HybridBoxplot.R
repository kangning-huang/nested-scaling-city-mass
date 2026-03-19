# Fig1_HybridBoxplot.R
# Nature Cities R1 Revision
# Hybrid Figure 1: Current global boxplot (5 categories) + China-only Appliances & Vehicles
#
# Run from: _Revision1/scripts/
# Output:   _Revision1/figures/Fig1_HybridBoxplot_{date}.pdf

rm(list = ls())
if (!interactive()) pdf(NULL) # suppress Rplots.pdf

# ── 1. Packages ──────────────────────────────────────────────────────────────
library(pacman)
p_load(tidyverse, zoo, scales, maps, mapdata, patchwork)

# ── 2. Read Data ─────────────────────────────────────────────────────────────
master_mass_file <- "../../data/processed/MasterMass_ByClass20250616.csv"
hist_trend_file  <- "../../data/processed/HistTrend20240924.csv"
# Prefer local results file if available; otherwise proceed without China overlay
china_mass_file  <- "../results/mass_by_cat_2020.csv"

DF_MassByClass <- read.csv(master_mass_file, stringsAsFactors = FALSE)
DF_HistTrend   <- read.csv(hist_trend_file, stringsAsFactors = FALSE)
DF_China <- tryCatch(
  read.csv(china_mass_file, stringsAsFactors = FALSE, row.names = 1),
  error = function(e) {
    message("[Fig1] China overlay data not found at ", china_mass_file, ". Proceeding without China-only panel.")
    NULL
  }
)

required_updated_cols <- c("subway_mass_tonnes", "MobilityInfra_Updated", "total_built_mass_tons_updated")
missing_updated_cols <- setdiff(required_updated_cols, names(DF_MassByClass))
if (length(missing_updated_cols) > 0) {
  stop(
    paste(
      "Master mass file is missing required subway-updated columns:",
      paste(missing_updated_cols, collapse = ", ")
    )
  )
}

# ── 3. Wrangle Global Data → Long Format ────────────────────────────────────
DF_mass_long <- DF_MassByClass %>%
  mutate(human_mass_tons = population_2015 * 50 / 1000) %>%
  pivot_longer(
    cols = c(total_built_mass_tons_updated, BuildingMass_AverageTotal,
             MobilityInfra_Updated, total_dryBiomass_tons, human_mass_tons),
    names_to  = "MassType_raw",
    values_to = "MassValue"
  ) %>%
  mutate(
    MassType = case_when(
      MassType_raw == "total_built_mass_tons_updated" ~ "TotalBuilt",
      MassType_raw == "BuildingMass_AverageTotal"     ~ "Buildings",
      MassType_raw == "MobilityInfra_Updated"         ~ "MobilityInfra",
      MassType_raw == "total_dryBiomass_tons"         ~ "Vegetation",
      MassType_raw == "human_mass_tons"               ~ "Human",
      TRUE ~ MassType_raw
    )
  ) %>%
  select(ID_HDC_G0, UC_NM_MN, CTR_MN_ISO, CTR_MN_NM, GRGN_L1, GRGN_L2,
         population_2015, lat, lon, MassType, MassValue)

# ── 4. Extract China Appliances & Vehicles → Append ─────────────────────────
DF_china_long <- if (!is.null(DF_China)) {
  DF_China %>%
    dplyr::filter(population > 50000) %>%
    dplyr::select(ID_HDC_G0, UC_NM_MN, population, mass_appliances, mass_transportation) %>%
    tidyr::pivot_longer(
      cols = c(mass_appliances, mass_transportation),
      names_to  = "MassType_raw",
      values_to = "MassValue"
    ) %>%
    dplyr::mutate(
      MassType = dplyr::case_when(
        MassType_raw == "mass_appliances"     ~ "Appliances*",
        MassType_raw == "mass_transportation" ~ "Vehicles*"
      ),
      CTR_MN_ISO = "CHN",
      CTR_MN_NM  = "China",
      GRGN_L1    = "Asia",
      GRGN_L2    = "Eastern Asia",
      population_2015 = population,
      lat = NA_real_,
      lon = NA_real_
    ) %>%
    dplyr::select(ID_HDC_G0, UC_NM_MN, CTR_MN_ISO, CTR_MN_NM, GRGN_L1, GRGN_L2,
           population_2015, lat, lon, MassType, MassValue)
} else {
  NULL
}

DF_mass_hybrid <- bind_rows(DF_mass_long, DF_china_long)

# ── 5. Factor Ordering ──────────────────────────────────────────────────────
ordered_levels <- c("Human", "Vehicles*", "Appliances*", "Vegetation",
                    "MobilityInfra", "Buildings", "TotalBuilt")

DF_mass_hybrid <- DF_mass_hybrid %>%
  filter(MassValue > 0, population_2015 > 0) %>%
  mutate(MassType = factor(MassType, levels = ordered_levels))

# ── 6. Compute Ratio Labels ─────────────────────────────────────────────────
ratio_df <- DF_mass_hybrid %>%
  mutate(MassBaseline = population_2015 * 50 / 1000,
         Ratio = MassValue / MassBaseline) %>%
  group_by(MassType) %>%
  summarise(medianRatio = round(median(Ratio, na.rm = TRUE)),
            .groups = "drop") %>%
  mutate(MassType = factor(MassType, levels = ordered_levels)) %>%
  arrange(MassType)

cat("Median ratios (Xx vs human body mass):\n")
print(ratio_df)

# Y-position for ratio text: 2nd percentile of each category
y_positions <- DF_mass_hybrid %>%
  group_by(MassType) %>%
  summarise(y = quantile(MassValue, 0.02, na.rm = TRUE), .groups = "drop") %>%
  mutate(MassType = factor(MassType, levels = ordered_levels)) %>%
  arrange(MassType)

y_positions$label <- paste0(ratio_df$medianRatio, "x")

# ── 7. Panel a: Historical Trend (verbatim) ─────────────────────────────────
DF_HistTrend_long <- DF_HistTrend %>%
  pivot_longer(cols = c("PerCapBuiltMass", "PerCapBiomass"),
               names_to = "MassType", values_to = "PerCapMass")

Fig.Trend <- ggplot(DF_HistTrend_long,
                    aes(x = Year, y = PerCapMass, color = MassType, linetype = MassType)) +
  geom_line(size = 0.75) +
  geom_hline(yintercept = 1000, linetype = 3, size = 0.3, color = "gray") +
  geom_hline(yintercept = 10,   linetype = 3, size = 0.3, color = "gray") +
  geom_hline(yintercept = 300,  linetype = 3, size = 0.3, color = "gray") +
  geom_hline(yintercept = 100,  linetype = 3, size = 0.3, color = "gray") +
  geom_hline(yintercept = 30,   linetype = 3, size = 0.3, color = "gray") +
  geom_point(data = DF_HistTrend_long %>%
               filter(MassType == "PerCapBuiltMass" & Year %in% c(1900, 2023)),
             aes(x = Year, y = PerCapMass), pch = 21, color = "black", size = 3) +
  annotate("text", x = 1925, y = 350, label = "Vegetation",  color = "black", hjust = -0.2, size = 3) +
  annotate("text", x = 1925, y = 25,  label = "Built stock", color = "black", hjust = -0.2, size = 3) +
  annotate("text", x = 1905, y = 35,  label = "22t/cap; 430x",     color = "black", hjust = 0, size = 3) +
  annotate("text", x = 2023, y = 300, label = "205t/cap; 4090x ",  color = "black", hjust = 1,   size = 3) +
  scale_y_continuous(trans = "log10",
                     limits = c(10, 1030),
                     breaks = c(10, 30, 100, 300, 1000),
                     name = "Per capita mass (t/cap)") +
  scale_x_continuous(limits = c(1900, 2025),
                     breaks = c(1900, 1920, 1940, 1960, 1980, 2000, 2020),
                     name = NULL) +
  theme_bw() +
  theme(axis.ticks = element_line(colour = "black", size = 0.1),
        axis.line = element_line(colour = "black", size = 0),
        text = element_text(size = 10),
        axis.text.x = element_text(angle = 360, hjust = 0.5, vjust = 0),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.background = element_blank(),
        legend.position = "none") +
  scale_color_manual(values = c("PerCapBuiltMass" = "#8da0cb",
                                "PerCapBiomass"   = "#66c2a5")) +
  scale_linetype_manual(values = c("PerCapBuiltMass" = "solid",
                                   "PerCapBiomass"   = "longdash"))

# ── 8. Panel b: Global Map (verbatim) ───────────────────────────────────────
DF_MassLong_filtered <- DF_mass_long %>%
  filter(MassType == "TotalBuilt")

worldDF <- map_data("world")

mp <- ggplot() +
  geom_polygon(data = worldDF, aes(x = long, y = lat, group = group),
               fill = "gray97", color = "darkgray") +
  theme_bw() +
  theme(axis.ticks = element_line(colour = "black", size = 0.1),
        axis.line = element_line(colour = "black", size = 0),
        text = element_text(size = 10),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.background = element_rect(fill = "#DAE7EB", color = NA))

global_map <- mp +
  scale_x_continuous(name = NULL,
                     breaks = seq(-180, 180, 60),
                     labels = paste0(seq(-180, 180, 60), "\u00B0"),
                     expand = c(0.01, 0.01)) +
  scale_y_continuous(name = NULL,
                     breaks = seq(-90, 90, 30),
                     labels = paste0(seq(-90, 90, 30), "\u00B0"),
                     expand = c(0.01, 0.01),
                     position = "left") +
  coord_quickmap(ylim = c(-90, 90), xlim = c(-180, 180)) +
  geom_point(data = DF_MassLong_filtered, aes(x = lon, y = lat),
             shape = 21, size = 1, stroke = 0.3, color = "black", fill = NA,
             alpha = 0.8, show.legend = FALSE)

# ── 9. Panel d: Top100 Bar Chart (verbatim) ─────────────────────────────────
df_mass_bar <- DF_mass_long %>%
  filter(MassType == "TotalBuilt") %>%
  filter(!is.na(MassValue) & MassValue > 0)

total_mass     <- sum(df_mass_bar$MassValue, na.rm = TRUE)
top100_mass    <- df_mass_bar %>% arrange(desc(MassValue)) %>% slice(1:100) %>%
  summarise(s = sum(MassValue, na.rm = TRUE)) %>% pull(s)
rest_mass      <- total_mass - top100_mass
top100_mass_prop <- top100_mass / total_mass
rest_mass_prop   <- rest_mass / total_mass

df_pop_bar <- df_mass_bar %>% filter(!is.na(population_2015) & population_2015 > 0)
total_pop    <- sum(df_pop_bar$population_2015, na.rm = TRUE)
top100_pop   <- df_pop_bar %>% arrange(desc(population_2015)) %>% slice(1:100) %>%
  summarise(s = sum(population_2015, na.rm = TRUE)) %>% pull(s)
rest_pop     <- total_pop - top100_pop
top100_pop_prop <- top100_pop / total_pop
rest_pop_prop   <- rest_pop / total_pop

plot_data <- data.frame(
  Measure    = c("Built Structure", "Built Structure", "Population", "Population"),
  Category   = c("top100", "rest", "top100", "rest"),
  Proportion = c(top100_mass_prop, rest_mass_prop, top100_pop_prop, rest_pop_prop)
)
plot_data$Measure <- factor(plot_data$Measure, levels = c("Built Structure", "Population"))
plot_data <- plot_data %>%
  mutate(Fill = ifelse(
    Measure == "Built Structure",
    ifelse(Category == "top100", "#8da0cb", scales::alpha("#8da0cb", 0.3)),
    ifelse(Category == "top100", "darkgray", "lightgray")
  ))

Fig.top100 <- ggplot(plot_data, aes(x = Measure, y = Proportion, fill = Fill)) +
  geom_bar(stat = "identity", width = 0.65) +
  geom_text(aes(label = paste0(Category, "\n", round(Proportion * 100, 0), "%")),
            position = position_stack(vjust = 0.5),
            color = "black", size = 3.5) +
  scale_y_continuous(labels = percent_format(), limits = c(0, 1.05), expand = c(0.005, 0.005)) +
  scale_fill_identity() +
  labs(x = NULL, y = NULL) +
  theme_bw() +
  theme(panel.grid      = element_blank(),
        legend.position = "none",
        axis.text.y     = element_blank(),
        axis.ticks      = element_blank(),
        plot.background = element_blank(),
        text = element_text(size = 10),
        axis.text.x     = element_text(angle = 340, hjust = 0.5, vjust = 1),
        panel.border    = element_rect(color = "black", fill = NA, size = 0.2))

# ── 10. Panel c: HYBRID Boxplot (7 categories) ──────────────────────────────
set.seed(123)

annotation_df_left <- data.frame(
  y = c(1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10),
  label = c("1 kilotonne", "10 kilotonne", "100 kilotonne",
            "1 megatonne", "10 megatonne", "100 megatonne",
            "1 gigatonne", "10 gigatonne"),
  side = rep("right", 8)
)

color_map <- c(
  "Human"         = "lightgray",
  "Vehicles*"     = "#f3c8b8",
  "Appliances*"   = "#f7ddd3",
  "Vegetation"    = "#66c2a5",
  "MobilityInfra" = "#8da0cb",
  "Buildings"     = "#8da0cb",
  "TotalBuilt"    = "#8da0cb"
)

Fig.Box <- DF_mass_hybrid %>%
  ggplot() +
  geom_jitter(aes(x = MassType, y = MassValue, fill = MassType),
              size = 0.8, pch = 21, width = 0.2, stroke = 0.3, alpha = 0.6) +
  geom_boxplot(aes(x = MassType, y = MassValue, fill = MassType),
               width = 0.6, alpha = 0.6, outlier.shape = NA, lwd = 0.3, fatten = 1.2) +
  geom_hline(yintercept = 5628.294, linetype = 2, size = 0.3, color = "red") +
  geom_hline(yintercept = 1e3,  linetype = 3, size = 0.3, color = "gray") +
  geom_hline(yintercept = 1e4,  linetype = 3, size = 0.3, color = "gray") +
  geom_hline(yintercept = 1e5,  linetype = 3, size = 0.3, color = "gray") +
  geom_hline(yintercept = 1e6,  linetype = 3, size = 0.3, color = "gray") +
  geom_hline(yintercept = 1e7,  linetype = 3, size = 0.3, color = "gray") +
  geom_hline(yintercept = 1e8,  linetype = 3, size = 0.3, color = "gray") +
  geom_hline(yintercept = 1e9,  linetype = 3, size = 0.3, color = "gray") +
  geom_hline(yintercept = 1e10, linetype = 3, size = 0.3, color = "gray") +
  scale_y_log10(name = "Mass of urban components per city (tonnes)",
                limits = c(300, 10^10.3),
                breaks = c(1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10),
                labels = scales::trans_format("log10", scales::math_format(10^.x)),
                expand = c(0, 0)) +
  scale_x_discrete(name = NULL, expand = expansion(mult = c(0.1, 0.3))) +
  scale_fill_manual(values = color_map) +
  theme_bw() +
  theme(axis.ticks = element_line(colour = "black", size = 0.1),
        axis.line = element_line(colour = "black", size = 0),
        text = element_text(size = 10),
        axis.text.x = element_text(angle = 340, hjust = 0.5, vjust = 1),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.background = element_blank(),
        legend.position = "none") +
  geom_text(data = y_positions,
            aes(x = MassType, y = y, label = label),
            size = 3, fontface = "bold", vjust = 4) +
  geom_text(data = subset(annotation_df_left, side == "right"),
            aes(x = Inf, y = y, label = label),
            hjust = 1.1, vjust = 0.5,
            size = 2.5, color = "gray30",
            fontface = "italic",
            check_overlap = TRUE) +
  annotate("text", x = 1, y = 500,
           label = "* China only\n   (n = 1,120)",
           size = 2.5, fontface = "italic", color = "gray40",
           hjust = 0, vjust = 1)

# ── 11. Assemble and Save ───────────────────────────────────────────────────
left_side <- Fig.Trend / global_map

combined_plot <- left_side | Fig.Box | Fig.top100
combined_plot <- combined_plot + plot_layout(widths = c(5, 8, 3))

current_date <- Sys.Date()

ggsave(
  filename = paste0("../figures/Fig1_HybridBoxplot_", current_date, ".pdf"),
  plot = combined_plot,
  device = "pdf",
  width = 26,
  height = 11,
  units = "cm",
  dpi = 300
)

cat("\nFigure saved to: _Revision1/figures/Fig1_HybridBoxplot_", as.character(current_date), ".pdf\n")
