# Fig1_GlobalMass_Stats.R
# Revision 1 version of scripts/Fig1_GlobalMass_Stats.Rmd
# Uses total_built_mass_tons_updated (includes subway mass added 2026-03-02)

library(pacman)
p_load(tidyverse, scales)

# --- Input ---
DF_MassLong <- read.csv("../../data/processed/MasterMass_ByClass20250616.csv",
                        stringsAsFactors = FALSE) %>%
  filter(population_2015 > 50000)

cat("N cities (pop > 50,000):", nrow(DF_MassLong), "\n\n")

# --- Summary stats ---
total_built_mass_summary <- DF_MassLong %>%
  summarise(
    Total_Built_Mass_Tons  = sum(total_built_mass_tons_updated, na.rm = TRUE),
    Number_of_Cities       = n(),
    Mean_Built_Mass        = mean(total_built_mass_tons_updated, na.rm = TRUE),
    Median_Built_Mass      = median(total_built_mass_tons_updated, na.rm = TRUE)
  )

print(total_built_mass_summary)
cat("Total built mass (Gt):", total_built_mass_summary$Total_Built_Mass_Tons / 1e9, "\n\n")

# --- Top 100 cities by mass ---
df_top100 <- DF_MassLong %>%
  arrange(desc(total_built_mass_tons_updated)) %>%
  mutate(
    TotalMass   = sum(total_built_mass_tons_updated, na.rm = TRUE),
    CumMass     = cumsum(total_built_mass_tons_updated),
    CumMassProp = CumMass / TotalMass,
    CityRank    = row_number()
  )

mass_top100 <- df_top100$CumMassProp[100]
mass_top10  <- df_top100$CumMassProp[10]

cat("The top 100 cities account for", round(mass_top100 * 100, 1), "% of total urban mass.\n")
cat("The top  10 cities account for", round(mass_top10  * 100, 1), "% of total urban mass.\n\n")

# --- Top 100 by population ---
df_top100_popu <- DF_MassLong %>%
  arrange(desc(population_2015)) %>%
  mutate(
    TotalPopu   = sum(population_2015, na.rm = TRUE),
    CumPopu     = cumsum(population_2015),
    CumPopuProp = CumPopu / TotalPopu,
    CityRank    = row_number()
  )

popu_top100 <- df_top100_popu$CumPopuProp[100]
cat("The top 100 most populous cities host", round(popu_top100 * 100, 1), "% of total urban population.\n\n")

# --- Equivalent smallest cities ---
top100_mass <- DF_MassLong %>%
  arrange(desc(total_built_mass_tons_updated)) %>%
  slice(1:100) %>%
  summarise(TotalTop100 = sum(total_built_mass_tons_updated, na.rm = TRUE)) %>%
  pull(TotalTop100)

cat("Combined mass of the top 100 cities:", top100_mass / 1e9, "Gt\n")

df_smallest <- DF_MassLong %>%
  arrange(total_built_mass_tons_updated) %>%
  mutate(CumMass = cumsum(total_built_mass_tons_updated))

n_smallest <- which(df_smallest$CumMass >= top100_mass)[1]
pct_smallest <- round(n_smallest / nrow(DF_MassLong) * 100)

cat("The combined mass of the top 100 cities equals the cumulative mass of the smallest",
    n_smallest, "cities (", pct_smallest, "% of all cities).\n\n")

# --- Per-capita comparison: top 100 populous vs. rest ---
top100_pop_cities <- df_top100_popu %>% slice(1:100)
rest_cities       <- df_top100_popu %>% slice(101:n())

pc_top100 <- sum(top100_pop_cities$total_built_mass_tons_updated) /
             sum(top100_pop_cities$population_2015)
pc_rest   <- sum(rest_cities$total_built_mass_tons_updated) /
             sum(rest_cities$population_2015)
pct_diff  <- (pc_top100 - pc_rest) / pc_rest * 100

cat("Per-capita built mass — top-100-pop cities:", round(pc_top100), "t/cap\n")
cat("Per-capita built mass — rest of world:     ", round(pc_rest),   "t/cap\n")
cat("Difference:", round(pct_diff, 1), "% (top-100-pop cities vs. rest)\n\n")

# --- Distribution plot ---
DF_MassLong %>%
  ggplot(aes(x = total_built_mass_tons_updated)) +
  geom_histogram(bins = 50, color = "black", fill = "lightgray") +
  scale_x_log10(labels = scales::comma) +
  labs(x = "Total Built Mass (tonnes, with subway)", y = "Count",
       title = "Distribution of Total Built Mass Across Cities (Revision 1)")
