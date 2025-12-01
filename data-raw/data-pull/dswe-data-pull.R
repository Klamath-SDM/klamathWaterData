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
# 2. Authenticate with Earth Engine (do once):
#    ee_Authenticate()
#
#   note - have had to run the script below to get it working (for now)
#   library(reticulate)
#   # Disable SSL and authenticate directly in Python
#   py_run_string("
#   import ssl
#   ssl._create_default_https_context = ssl._create_unverified_context

#   import ee
#   ee.Authenticate(force=True)
#   ")
#
# 3. Initialize with your Google Cloud project ID (do each session):
#    ee_Initialize(project = "your-project-id")
# ============================================================================

# Initialize Earth Engine (replace with your project ID)
ee_Initialize(project = "ee-fishfakts")

# Define your area of interest as bounding box
# Format: [west, south, east, north]
bbox <- c(-121.832973, 41.883542, -121.589818, 42.002614)

# Create AOI geometry from bounding box
aoi <- ee$Geometry$Rectangle(bbox)

# Define time range
start_date <- '2020-01-01'
end_date <- '2023-12-31'

# ============================================================================
# DSWE Algorithm Implementation
# ============================================================================
# Based on Jones (2019) USGS algorithm
# Computes spectral indices and applies decision rules to classify water

calculate_dswe <- function(image) {
  # Scale optical bands (Landsat Collection 2 scaling factors)
  optical <- image$select('SR_B.')$multiply(0.0000275)$add(-0.2)

  # For Landsat 8/9: Blue=B2, Green=B3, Red=B4, NIR=B5, SWIR1=B6, SWIR2=B7
  blue <- optical$select('SR_B2')
  green <- optical$select('SR_B3')
  nir <- optical$select('SR_B5')
  swir1 <- optical$select('SR_B6')
  swir2 <- optical$select('SR_B7')

  # Calculate spectral indices
  # Modified Normalized Difference Wetness Index
  mndwi <- green$subtract(swir1)$divide(green$add(swir1))$rename('mndwi')

  # Multi-band Spectral Relationship Visible
  mbsrv <- green$add(swir1)$rename('mbsrv')

  # Multi-band Spectral Relationship Near-Infrared
  mbsrn <- nir$add(swir1)$rename('mbsrn')

  # Normalized Difference Vegetation Index
  ndvi <- nir$subtract(blue)$divide(nir$add(blue))$rename('ndvi')

  # Automated Water Extent Shadow
  awesh <- blue$add(green$multiply(2.5))$subtract(nir$multiply(1.5))$
    subtract(swir1$multiply(0.25))$subtract(swir2$multiply(0.25))$rename('awesh')

  # DSWE Classification Tests
  # Test 1: MNDWI > 0.124
  test1 <- mndwi$gt(0.124)

  # Test 2: MBSRV > MBSRN
  test2 <- mbsrv$gt(mbsrn)

  # Test 3: AWESH > 0
  test3 <- awesh$gt(0)

  # Test 4: MNDWI > -0.44 AND SWIR1 < 0.09 AND NIR < 0.15 AND NDVI < 0.7
  test4 <- mndwi$gt(-0.44)$And(swir1$lt(0.09))$And(nir$lt(0.15))$And(ndvi$lt(0.7))

  # Test 5: MNDWI > -0.5 AND SWIR1 < 0.3 AND SWIR2 < 0.1 AND NIR < 0.25
  test5 <- mndwi$gt(-0.5)$And(swir1$lt(0.3))$And(swir2$lt(0.1))$And(nir$lt(0.25))

  # Apply DSWE classification rules
  # Class 0: Not water
  # Class 1: High confidence water
  # Class 2: Moderate confidence water
  # Class 3: Potential wetland (partial surface water)
  dswe <- ee$Image(0)$
    where(test1, 1)$
    where(test1$And(test2)$And(test3), 1)$
    where(test5, 2)$
    where(test1$And(test2$Not())$And(test3), 3)$
    rename('dswe')

  # Mask clouds using QA_PIXEL band
  qa <- image$select('QA_PIXEL')
  cloud_mask <- qa$bitwiseAnd(31)$eq(0)  # Clear pixels only

  # Copy all properties from source image
  return(dswe$updateMask(cloud_mask)$copyProperties(image))
}

# ============================================================================
# Load and Process Landsat Data
# ============================================================================

cat("Loading Landsat imagery...\n")

# Load Landsat 8 Collection 2 data
landsat8 <- ee$ImageCollection('LANDSAT/LC08/C02/T1_L2')$
  filterBounds(aoi)$
  filterDate(start_date, end_date)$
  filter(ee$Filter$lt('CLOUD_COVER', 20))

# Load Landsat 9 Collection 2 data
landsat9 <- ee$ImageCollection('LANDSAT/LC09/C02/T1_L2')$
  filterBounds(aoi)$
  filterDate(start_date, end_date)$
  filter(ee$Filter$lt('CLOUD_COVER', 20))

# Merge collections
landsat <- landsat8$merge(landsat9)

# Get collection size
n_images <- landsat$size()$getInfo()
cat("Found", n_images, "Landsat scenes\n")

# Apply DSWE algorithm to all images
cat("Computing DSWE for all images...\n")
dswe_collection <- landsat$map(calculate_dswe)

# ============================================================================
# Extract Time Series Data
# ============================================================================

# Function to extract DSWE statistics for each image
extract_dswe_stats <- function(image) {
  # Get the DATE_ACQUIRED property (format: "YYYY-MM-DD")
  date_str <- image$get('DATE_ACQUIRED')

  dswe_band <- image$select('dswe')

  # Calculate total pixel count
  total_pixels <- dswe_band$reduceRegion(
    reducer = ee$Reducer$count(),
    geometry = aoi,
    scale = 30,
    maxPixels = 1e9
  )$get('dswe')

  # Calculate water percentage (classes 1, 2, 3)
  water_mask <- dswe_band$gte(1)$And(dswe_band$lte(3))
  water_percent <- water_mask$reduceRegion(
    reducer = ee$Reducer$mean(),
    geometry = aoi,
    scale = 30,
    maxPixels = 1e9
  )$get('dswe')

  # High confidence water only (class 1)
  high_conf_mask <- dswe_band$eq(1)
  high_conf_percent <- high_conf_mask$reduceRegion(
    reducer = ee$Reducer$mean(),
    geometry = aoi,
    scale = 30,
    maxPixels = 1e9
  )$get('dswe')

  # Moderate confidence water (class 2)
  mod_conf_mask <- dswe_band$eq(2)
  mod_conf_percent <- mod_conf_mask$reduceRegion(
    reducer = ee$Reducer$mean(),
    geometry = aoi,
    scale = 30,
    maxPixels = 1e9
  )$get('dswe')

  # Wetland (class 3)
  wetland_mask <- dswe_band$eq(3)
  wetland_percent <- wetland_mask$reduceRegion(
    reducer = ee$Reducer$mean(),
    geometry = aoi,
    scale = 30,
    maxPixels = 1e9
  )$get('dswe')

  return(ee$Feature(NULL, list(
    'date' = date_str,
    'total_pixels' = total_pixels,
    'water_percent' = water_percent,
    'high_conf_water' = high_conf_percent,
    'mod_conf_water' = mod_conf_percent,
    'wetland_percent' = wetland_percent
  )))
}

# Apply extraction to all DSWE images
cat("Extracting time series data...\n")
time_series <- dswe_collection$map(extract_dswe_stats)

# Convert to R data frame
cat("Downloading results from Earth Engine...\n")
ts_info <- time_series$getInfo()

# Parse results into a data frame
parse_feature <- function(feat) {
  props <- feat$properties

  # DATE_ACQUIRED is a string like "2020-01-15"
  date_str <- props$date

  if (is.null(date_str) || length(date_str) == 0) {
    return(NULL)
  }

  data.frame(
    date = as.Date(date_str),
    total_pixels = ifelse(is.null(props$total_pixels), NA, props$total_pixels),
    water_percent = ifelse(is.null(props$water_percent), NA, props$water_percent),
    high_conf_water = ifelse(is.null(props$high_conf_water), NA, props$high_conf_water),
    mod_conf_water = ifelse(is.null(props$mod_conf_water), NA, props$mod_conf_water),
    wetland_percent = ifelse(is.null(props$wetland_percent), NA, props$wetland_percent),
    stringsAsFactors = FALSE
  )
}

ts_df <- bind_rows(lapply(ts_info$features, parse_feature)) %>%
  filter(!is.null(date)) %>%
  arrange(date) %>%
  filter(!is.na(water_percent))

cat("\nData extraction complete!\n")
cat("Total observations:", nrow(ts_df), "\n")

# ============================================================================
# Visualizations
# ============================================================================

# Plot 1: Overall time series with all water classes
ggplot(ts_df, aes(x = date)) +
  geom_line(aes(y = water_percent * 100, color = "All Water"), linewidth = 0.8) +
  geom_line(aes(y = high_conf_water * 100, color = "High Confidence"),
            linewidth = 0.8, linetype = "dashed") +
  geom_line(aes(y = wetland_percent * 100, color = "Wetland"),
            linewidth = 0.6, linetype = "dotted") +
  geom_point(aes(y = water_percent * 100), color = "blue", size = 1.5, alpha = 0.4) +
  scale_color_manual(values = c(
    "All Water" = "blue",
    "High Confidence" = "darkblue",
    "Wetland" = "cyan4"
  )) +
  labs(
    title = "Dynamic Surface Water Extent Time Series",
    subtitle = sprintf("Bounding Box: %.3f, %.3f to %.3f, %.3f",
                       bbox[1], bbox[2], bbox[3], bbox[4]),
    x = "Date",
    y = "Water Coverage (%)",
    color = "DSWE Class",
    caption = "Source: Landsat Collection 2, USGS DSWE Algorithm (Jones, 2019)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    legend.position = "bottom"
  )

ggsave("dswe_timeseries.png", width = 12, height = 6, dpi = 300)

# Plot 2: Stacked area chart of water classes
ts_long <- ts_df %>%
  select(date, high_conf_water, mod_conf_water, wetland_percent) %>%
  pivot_longer(cols = -date, names_to = "class", values_to = "percent") %>%
  mutate(class = factor(class,
                        levels = c("high_conf_water", "mod_conf_water", "wetland_percent"),
                        labels = c("High Confidence", "Moderate Confidence", "Wetland")))

ggplot(ts_long, aes(x = date, y = percent * 100, fill = class)) +
  geom_area(alpha = 0.7) +
  scale_fill_manual(values = c(
    "High Confidence" = "darkblue",
    "Moderate Confidence" = "steelblue",
    "Wetland" = "lightblue"
  )) +
  labs(
    title = "Water Extent by Confidence Class",
    x = "Date",
    y = "Coverage (%)",
    fill = "DSWE Class"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave("dswe_stacked.png", width = 12, height = 6, dpi = 300)

# ============================================================================
# Temporal Aggregations
# ============================================================================

# Monthly statistics
monthly_stats <- ts_df %>%
  mutate(year_month = floor_date(date, "month")) %>%
  group_by(year_month) %>%
  summarise(
    mean_water = mean(water_percent, na.rm = TRUE),
    mean_high_conf = mean(high_conf_water, na.rm = TRUE),
    sd_water = sd(water_percent, na.rm = TRUE),
    n_obs = n(),
    .groups = 'drop'
  )

# Plot monthly aggregation
ggplot(monthly_stats, aes(x = year_month, y = mean_water * 100)) +
  geom_line(color = "blue", linewidth = 1) +
  geom_ribbon(aes(ymin = pmax(0, (mean_water - sd_water) * 100),
                  ymax = (mean_water + sd_water) * 100),
              alpha = 0.2, fill = "blue") +
  labs(
    title = "Monthly Dynamic Surface Water Extent",
    subtitle = "Mean ± Standard Deviation",
    x = "Month",
    y = "Water Coverage (%)"
  ) +
  theme_minimal()

ggsave("dswe_monthly.png", width = 12, height = 6, dpi = 300)

# Seasonal analysis
ts_df_seasonal <- ts_df %>%
  mutate(
    year = year(date),
    month = month(date),
    season = case_when(
      month %in% c(12, 1, 2) ~ "Winter",
      month %in% c(3, 4, 5) ~ "Spring",
      month %in% c(6, 7, 8) ~ "Summer",
      month %in% c(9, 10, 11) ~ "Fall"
    )
  )

seasonal_stats <- ts_df_seasonal %>%
  group_by(season) %>%
  summarise(
    mean_water = mean(water_percent, na.rm = TRUE),
    sd_water = sd(water_percent, na.rm = TRUE),
    n = n(),
    .groups = 'drop'
  )

# Plot seasonal patterns
ggplot(seasonal_stats, aes(x = factor(season, levels = c("Winter", "Spring", "Summer", "Fall")),
                           y = mean_water * 100)) +
  geom_col(fill = "steelblue") +
  geom_errorbar(aes(ymin = pmax(0, (mean_water - sd_water) * 100),
                    ymax = (mean_water + sd_water) * 100),
                width = 0.2) +
  labs(
    title = "Seasonal Water Extent Patterns",
    x = "Season",
    y = "Mean Water Coverage (%)"
  ) +
  theme_minimal()

ggsave("dswe_seasonal.png", width = 10, height = 6, dpi = 300)

# ============================================================================
# Summary Statistics
# ============================================================================

# Overall summary
summary_stats <- ts_df %>%
  summarise(
    n_observations = n(),
    date_range_start = min(date),
    date_range_end = max(date),
    mean_water = mean(water_percent, na.rm = TRUE) * 100,
    median_water = median(water_percent, na.rm = TRUE) * 100,
    sd_water = sd(water_percent, na.rm = TRUE) * 100,
    min_water = min(water_percent, na.rm = TRUE) * 100,
    max_water = max(water_percent, na.rm = TRUE) * 100,
    mean_high_conf = mean(high_conf_water, na.rm = TRUE) * 100,
    mean_wetland = mean(wetland_percent, na.rm = TRUE) * 100
  )

print(summary_stats)

# ============================================================================
# Save Results
# ============================================================================

write_csv(ts_df, "dswe_timeseries.csv")
write_csv(monthly_stats, "dswe_monthly_stats.csv")
write_csv(seasonal_stats, "dswe_seasonal_stats.csv")
write_csv(summary_stats, "dswe_summary_stats.csv")

cat("\nAnalysis complete!\n")
cat("Files saved:\n")
cat("  - dswe_timeseries.csv (raw time series)\n")
cat("  - dswe_monthly_stats.csv (monthly aggregations)\n")
cat("  - dswe_seasonal_stats.csv (seasonal patterns)\n")
cat("  - dswe_summary_stats.csv (overall statistics)\n")
cat("  - dswe_timeseries.png (main plot)\n")
cat("  - dswe_stacked.png (stacked area chart)\n")
cat("  - dswe_monthly.png (monthly plot)\n")
cat("  - dswe_seasonal.png (seasonal plot)\n")
