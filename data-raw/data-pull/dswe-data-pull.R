# DSWE Time Series Analysis using Google Earth Engine and R
# DSWE computed from Landsat spectral bands using the USGS DSWE algorithm

# Install required packages (run once)
# install.packages(c("rgee", "sf", "tidyverse", "lubridate"))

# Load libraries
library(rgee)
library(sf)
library(tidyverse)
library(lubridate)

# ============================================================================
# SETUP: Configure Python and authenticate (do this once)
# ============================================================================
# 1. Set Python path in .Renviron file:
#    usethis::edit_r_environ()
#    Add: RETICULATE_PYTHON="/Library/Frameworks/Python.framework/Versions/3.13/bin/python3"
#    Save and restart R
#
#   Helper functions:
#.  ee_install()
#   ee_check()
#
#   run the following script if ee_Authenticate is providing an SSL error:
#   py_run_file("data-raw/dswe/ee_auth.py")
#
# 1) Remove cached EE creds rgee is looking at
#   ee_clean_user_credentials(user = "maddeewiggins")

# 2) Authenticate with Earth Engine (do once):
#   ee_Authenticate(user = "maddeewiggins", quiet = FALSE)

# 3. Initialize with your Google Cloud project ID (do each session):
#  ee_Initialize(
#   user = "maddeewiggins",
#   project = "ee-maddeewiggins"
# )

# ============================================================================

# Initialize Earth Engine (replace with your project ID)
#project_id = "ee-fishfakts" # TODO update with project specific to klamath if necessary
project_id = "ee-maddeewiggins" # TODO update with project specific to klamath if necessary

ee_Initialize(project = project_id)

# ============================================================================
# MAIN FUNCTION: Extract DSWE Time Series for Any Bounding Box
# ============================================================================

source(here::here("data-raw", "dswe", "dswe_functions.R"))

# ============================================================================
# EXAMPLE USAGE
# ============================================================================

# Define your area of interest as bounding box
# Format: [west, south, east, north]
# we want refuges: Upper Klamath Lake, Lower Klamath Lake, Tule Lake, Klamath Marsh, Bear Valley, and Clear Lake
bbox_broad <- c(-122.136971,41.737336,-121.012918, 42.677414)
#upper_klamath_lake_bbox <- c(-122.138907,42.225167,-121.770893, 42.614644)
upper_klamath_lake_bbox <-c(-122.107301,42.214015,-121.787324,42.602368) # This box is slightly smaller
clear_lake_bbox <- c(-121.289207, 41.781010,-121.015256, 41.995292)
tule_lake_bbox <- c(-121.598288, 41.800411, -121.347044, 41.995232)
bear_valley_bbox <- c(-121.979966,42.034977,-121.889353,42.096687)
lower_klamath_sheepy_bbox <- c(-121.851156,41.883384,-121.591674,42.033576)
klamath_marsh_bbox <- c(-121.806202,42.827148,-121.517889,43.072530)


# Even though the date range is pulled for 2000-2026,
# due to filters in the function, the final date range is
# much smaller
start_date <- '2000-01-01'
end_date <- '2026-01-01'


upper_klamath_lake <- extract_dswe_timeseries(
  bbox = upper_klamath_lake_bbox,
  start_date = start_date, #'2016-10-01',
  end_date = end_date, #'2020-08-31',
  cloud_cover_threshold = 20,
  output_prefix = "data-raw/dswe/upper_klamath_lake",
  create_plots = TRUE,
  save_files = TRUE
)

clear_lake <- extract_dswe_timeseries(
  bbox = clear_lake_bbox,
  start_date = start_date, #'2016-10-01',
  end_date = end_date, #'2023-08-31',
  cloud_cover_threshold = 20,
  output_prefix = "data-raw/dswe/clear_lake",
  create_plots = TRUE,
  save_files = TRUE
)

tule_lake <- extract_dswe_timeseries(
  bbox = tule_lake_bbox,
  start_date = start_date, #'1995-10-01',
  end_date = end_date, #'1996-08-31',
  cloud_cover_threshold = 20,
  output_prefix = "data-raw/dswe/tule_lake",
  create_plots = TRUE,
  save_files = TRUE
)

bear_valley <- extract_dswe_timeseries(
  bbox = bear_valley_bbox,
  start_date = start_date, #'2016-10-01',
  end_date = end_date, #'2020-08-31',
  cloud_cover_threshold = 20,
  output_prefix = "data-raw/dswe/bear_valley",
  create_plots = TRUE,
  save_files = TRUE
)

lower_klamath_sheepy <- extract_dswe_timeseries(
  bbox = lower_klamath_sheepy_bbox,
  start_date = start_date, #'2016-10-01',
  end_date = end_date, #'2020-08-31',
  cloud_cover_threshold = 20,
  output_prefix = "data-raw/dswe/lower_klamath_sheepy",
  create_plots = TRUE,
  save_files = TRUE
)

klamath_marsh <- extract_dswe_timeseries(
  bbox = klamath_marsh_bbox,
  start_date = start_date, #'2016-10-01',
  end_date = end_date, #'2020-08-31',
  cloud_cover_threshold = 20,
  output_prefix = "data-raw/dswe/klamath_marsh",
  create_plots = TRUE,
  save_files = TRUE
)

# summary table for primary review with Jim
dswe_monthly <- bind_rows(tule_lake$monthly |>
                             mutate(area = "Tule Lake"),
                           clear_lake$monthly |>
                             mutate(area = "Clear Lake"),
                           bear_valley$monthly |>
                             mutate(area = "Bear Valley"),
                           lower_klamath_sheepy$monthly |>
                             mutate(area = "Lower Klamath Sheepy"),
                          klamath_marsh$monthly |>
                            mutate(area = "Klamath Marsh"),
                          upper_klamath_lake$monthly |>
                            mutate(area = "Upper Klamath Lake")) |>
  mutate(Year = year(year_month),
         month = month(year_month)) |>
  left_join(tibble("month" = 1:12,
                   "Month" = month.abb),
            by = "month") |>
  select(area,
         year = Year, month = Month,
         mean_total_water = mean_water,
         `sd_total_water` = sd_water,
         mean_class1,
         mean_class2,
         mean_class3,
         n = n_obs) |>
  mutate(across(mean_total_water:mean_class3, \(x) x * 100),
         across(mean_total_water:mean_class3, \(x) round(x, 3)))

write_csv(dswe_monthly, "data-raw/dswe/dswe_monthly_summary_all.csv")

# save data
usethis::use_data(dswe_monthly, overwrite = TRUE)

# Access results
# ts_df <- results1$timeseries
# monthly_stats <- results1$monthly
# summary <- results1$summary

month_levels <- c("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")

dswe_monthly |>
  mutate(
    month = factor(month, levels = month_levels),
    ymin = mean_total_water - sd_total_water,
    ymax = mean_total_water + sd_total_water
  ) |>
  ggplot(aes(x = month, y = mean_total_water, group = year)) +
  geom_line(aes(color = year), linewidth = 0.6, alpha = 0.7) +
  geom_point(aes(color = year), size = 1.3, alpha = 0.8) +
  geom_errorbar(
    aes(ymin = ymin, ymax = ymax, color = year),
    width = 0.15,
    na.rm = TRUE,
    alpha = 0.5
  ) +
  facet_wrap(~ area) +
  labs(
    x = "Month",
    y = "Mean total water (%)",
    color = "Year",
    title = "Monthly water extent by area with year-to-year variation",
    subtitle = "Each line is a year; error bars are mean ± SD (omitted when SD is NA / n = 1)"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggplot2::ggsave("data-raw/dswe/all_areas_timeseries.png", plot = get_last_plot(), width = 12, height = 6, dpi = 300)

# get metadata ------------------------------------------------------------

upper_klamath_lake_metadata <- get_landsat_metadata(
  bbox = upper_klamath_lake_bbox,
  start_date = '1984-01-01',
  end_date = '2024-12-31',
  cloud_cover_threshold = 50  # Set higher to see all images
)

clear_lake_metadata <- get_landsat_metadata(
  bbox = clear_lake_bbox,
  start_date = '1984-01-01',
  end_date = '2024-12-31',
  cloud_cover_threshold = 50  # Set higher to see all images
)

tule_lake_metadata <- get_landsat_metadata(
  bbox = tule_lake_bbox,
  start_date = '1984-01-01',
  end_date = '2024-12-31',
  cloud_cover_threshold = 50  # Set higher to see all images
)

bear_valley_metadata <- get_landsat_metadata(
  bbox = bear_valley_bbox,
  start_date = '1984-01-01',
  end_date = '2024-12-31',
  cloud_cover_threshold = 50  # Set higher to see all images
)

lower_klamath_sheepy_metadata <- get_landsat_metadata(
  bbox = lower_klamath_sheepy_bbox,
  start_date = '1984-01-01',
  end_date = '2024-12-31',
  cloud_cover_threshold = 50  # Set higher to see all images
)

klamath_marsh_metadata <- get_landsat_metadata(
  bbox = klamath_marsh_bbox,
  start_date = '1984-01-01',
  end_date = '2024-12-31',
  cloud_cover_threshold = 50  # Set higher to see all images
)

# Access results
upper_klamath_lake_metadata$date_range
clear_lake_metadata$date_range
tule_lake_metadata$date_range
bear_valley_metadata$date_range
lower_klamath_sheepy_metadata$date_range
klamath_marsh_metadata$date_range

