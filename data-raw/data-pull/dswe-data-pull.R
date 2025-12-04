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

# ============================================================================
# MAIN FUNCTION: Extract DSWE Time Series for Any Bounding Box
# ============================================================================

extract_dswe_timeseries <- function(bbox,
                                    start_date = '2020-01-01',
                                    end_date = '2023-12-31',
                                    cloud_cover_threshold = 20,
                                    output_prefix = "dswe",
                                    create_plots = TRUE,
                                    save_files = TRUE) {

  cat("============================================================\n")
  cat("DSWE Time Series Extraction\n")
  cat("============================================================\n")
  cat("Bounding box:", paste(bbox, collapse = ", "), "\n")
  cat("Date range:", start_date, "to", end_date, "\n")
  cat("Cloud cover threshold:", cloud_cover_threshold, "%\n\n")

  # Create AOI geometry from bounding box
  aoi <- ee$Geometry$Rectangle(bbox)

  # ============================================================================
  # DSWE Algorithm Implementation
  # ============================================================================

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
    mndwi <- green$subtract(swir1)$divide(green$add(swir1))$rename('mndwi')
    mbsrv <- green$add(swir1)$rename('mbsrv')
    mbsrn <- nir$add(swir1)$rename('mbsrn')
    ndvi <- nir$subtract(blue)$divide(nir$add(blue))$rename('ndvi')
    awesh <- blue$add(green$multiply(2.5))$subtract(nir$multiply(1.5))$
      subtract(swir1$multiply(0.25))$subtract(swir2$multiply(0.25))$rename('awesh')

    # DSWE Classification Tests
    test1 <- mndwi$gt(0.124)
    test2 <- mbsrv$gt(mbsrn)
    test3 <- awesh$gt(0)
    test4 <- mndwi$gt(-0.44)$And(swir1$lt(0.09))$And(nir$lt(0.15))$And(ndvi$lt(0.7))
    test5 <- mndwi$gt(-0.5)$And(swir1$lt(0.3))$And(swir2$lt(0.1))$And(nir$lt(0.25))

    # Apply DSWE classification rules
    dswe <- ee$Image(0)$
      where(test1, 1)$
      where(test1$And(test2)$And(test3), 1)$
      where(test5, 2)$
      where(test1$And(test2$Not())$And(test3), 3)$
      rename('dswe')

    # Mask clouds using QA_PIXEL band
    qa <- image$select('QA_PIXEL')
    cloud_mask <- qa$bitwiseAnd(31)$eq(0)

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
    filter(ee$Filter$lt('CLOUD_COVER', cloud_cover_threshold))

  # Load Landsat 9 Collection 2 data
  landsat9 <- ee$ImageCollection('LANDSAT/LC09/C02/T1_L2')$
    filterBounds(aoi)$
    filterDate(start_date, end_date)$
    filter(ee$Filter$lt('CLOUD_COVER', cloud_cover_threshold))

  # Merge collections
  landsat <- landsat8$merge(landsat9)

  # Get collection size
  n_images <- landsat$size()$getInfo()
  cat("Found", n_images, "Landsat scenes\n")

  if (n_images == 0) {
    stop("No images found for the specified parameters!")
  }

  # Apply DSWE algorithm to all images
  cat("Computing DSWE for all images...\n")
  dswe_collection <- landsat$map(calculate_dswe)

  # ============================================================================
  # Extract Time Series Data
  # ============================================================================

  # Function to extract DSWE statistics for each image
  extract_dswe_stats <- function(image) {
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

    # Class 1: High confidence water
    class1_mask <- dswe_band$eq(1)
    class1_percent <- class1_mask$reduceRegion(
      reducer = ee$Reducer$mean(),
      geometry = aoi,
      scale = 30,
      maxPixels = 1e9
    )$get('dswe')

    # Class 2: Moderate confidence water
    class2_mask <- dswe_band$eq(2)
    class2_percent <- class2_mask$reduceRegion(
      reducer = ee$Reducer$mean(),
      geometry = aoi,
      scale = 30,
      maxPixels = 1e9
    )$get('dswe')

    # Class 3: Partial surface water
    class3_mask <- dswe_band$eq(3)
    class3_percent <- class3_mask$reduceRegion(
      reducer = ee$Reducer$mean(),
      geometry = aoi,
      scale = 30,
      maxPixels = 1e9
    )$get('dswe')

    return(ee$Feature(NULL, list(
      'date' = date_str,
      'total_pixels' = total_pixels,
      'water_percent' = water_percent,
      'class1_percent' = class1_percent,
      'class2_percent' = class2_percent,
      'class3_percent' = class3_percent
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
    date_str <- props$date

    if (is.null(date_str) || length(date_str) == 0) {
      return(NULL)
    }

    data.frame(
      date = as.Date(date_str),
      total_pixels = ifelse(is.null(props$total_pixels), NA, props$total_pixels),
      water_percent = ifelse(is.null(props$water_percent), NA, props$water_percent),
      class1_percent = ifelse(is.null(props$class1_percent), NA, props$class1_percent),
      class2_percent = ifelse(is.null(props$class2_percent), NA, props$class2_percent),
      class3_percent = ifelse(is.null(props$class3_percent), NA, props$class3_percent),
      stringsAsFactors = FALSE
    )
  }

  ts_df <- bind_rows(lapply(ts_info$features, parse_feature)) %>%
    filter(!is.null(date)) %>%
    arrange(date) %>%
    filter(!is.na(water_percent))

  cat("\nData extraction complete!\n")
  cat("Total observations:", nrow(ts_df), "\n\n")

  # ============================================================================
  # Create Visualizations
  # ============================================================================

  if (create_plots && nrow(ts_df) > 0) {
    cat("Creating visualizations...\n")

    # Plot 1: Time series showing all three DSWE classes
    p1 <- ggplot(ts_df, aes(x = date)) +
      geom_line(aes(y = class1_percent * 100, color = "Class 1: High Confidence"),
                linewidth = 0.8) +
      geom_line(aes(y = class2_percent * 100, color = "Class 2: Moderate Confidence"),
                linewidth = 0.8) +
      geom_line(aes(y = class3_percent * 100, color = "Class 3: Partial Surface Water"),
                linewidth = 0.8) +
      scale_color_manual(values = c(
        "Class 1: High Confidence" = "darkblue",
        "Class 2: Moderate Confidence" = "steelblue",
        "Class 3: Partial Surface Water" = "cyan3"
      )) +
      labs(
        title = "Dynamic Surface Water Extent by DSWE Class",
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

    if (save_files) {
      ggsave(paste0(output_prefix, "_timeseries.png"), p1, width = 12, height = 6, dpi = 300)
    }
    print(p1)

    # Plot 2: Stacked area chart of water classes
    ts_long <- ts_df %>%
      select(date, class1_percent, class2_percent, class3_percent) %>%
      pivot_longer(cols = -date, names_to = "class", values_to = "percent") %>%
      mutate(class = factor(class,
                            levels = c("class1_percent", "class2_percent", "class3_percent"),
                            labels = c("Class 1: High Confidence",
                                       "Class 2: Moderate Confidence",
                                       "Class 3: Partial Surface Water")))

    p2 <- ggplot(ts_long, aes(x = date, y = percent * 100, fill = class)) +
      geom_area(alpha = 0.7) +
      scale_fill_manual(values = c(
        "Class 1: High Confidence" = "darkblue",
        "Class 2: Moderate Confidence" = "steelblue",
        "Class 3: Partial Surface Water" = "lightblue"
      )) +
      labs(
        title = "Water Extent by DSWE Class",
        x = "Date",
        y = "Coverage (%)",
        fill = "DSWE Class"
      ) +
      theme_minimal() +
      theme(legend.position = "bottom")

    if (save_files) {
      ggsave(paste0(output_prefix, "_stacked.png"), p2, width = 12, height = 6, dpi = 300)
    }
    print(p2)
  }

  # ============================================================================
  # Temporal Aggregations
  # ============================================================================

  if (nrow(ts_df) > 0) {
    # Monthly statistics
    monthly_stats <- ts_df %>%
      mutate(year_month = floor_date(date, "month")) %>%
      group_by(year_month) %>%
      summarise(
        mean_water = mean(water_percent, na.rm = TRUE),
        mean_class1 = mean(class1_percent, na.rm = TRUE),
        mean_class2 = mean(class2_percent, na.rm = TRUE),
        mean_class3 = mean(class3_percent, na.rm = TRUE),
        sd_water = sd(water_percent, na.rm = TRUE),
        n_obs = n(),
        .groups = 'drop'
      )

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
        mean_class1 = mean(class1_percent, na.rm = TRUE) * 100,
        mean_class2 = mean(class2_percent, na.rm = TRUE) * 100,
        mean_class3 = mean(class3_percent, na.rm = TRUE) * 100
      )

    cat("\nSummary Statistics:\n")
    print(summary_stats)

    # ============================================================================
    # Save Results
    # ============================================================================

    if (save_files) {
      cat("\nSaving results...\n")
      write_csv(ts_df, paste0(output_prefix, "_timeseries.csv"))
      write_csv(monthly_stats, paste0(output_prefix, "_monthly_stats.csv"))
      write_csv(seasonal_stats, paste0(output_prefix, "_seasonal_stats.csv"))
      write_csv(summary_stats, paste0(output_prefix, "_summary_stats.csv"))

      cat("Files saved:\n")
      cat("  -", paste0(output_prefix, "_timeseries.csv"), "(raw time series)\n")
      cat("  -", paste0(output_prefix, "_monthly_stats.csv"), "(monthly aggregations)\n")
      cat("  -", paste0(output_prefix, "_seasonal_stats.csv"), "(seasonal patterns)\n")
      cat("  -", paste0(output_prefix, "_summary_stats.csv"), "(overall statistics)\n")
      if (create_plots) {
        cat("  -", paste0(output_prefix, "_timeseries.png"), "(main plot)\n")
        cat("  -", paste0(output_prefix, "_stacked.png"), "(stacked area chart)\n")
      }
    }

    # Return results
    return(list(
      timeseries = ts_df,
      monthly = monthly_stats,
      seasonal = seasonal_stats,
      summary = summary_stats
    ))
  } else {
    warning("No valid data extracted!")
    return(NULL)
  }
}

# ============================================================================
# EXAMPLE USAGE
# ============================================================================

# Define your area of interest as bounding box
# Format: [west, south, east, north]
# we want refuges: Upper Klamath Lake, Lower Klamath Lake, Tule Lake, Klamath Marsh, Bear Valley, and Clear Lake
bbox_broad <- c(-122.136971,41.737336,-121.012918, 42.677414)
upper_klamath_lake_bbox <- c(-122.138907,42.225167,-121.770893, 42.614644)
clear_lake_bbox <- c(-121.289207, 41.781010,-121.015256, 41.995292)
tule_lake_bbox <- c(-121.598288, 41.800411, -121.347044, 41.995232)
bear_valley_bbox <- c(-121.979966,42.034977,-121.889353,42.096687)
lower_klamath_sheepy_bbox <- c(-121.851156,41.883384,-121.591674,42.033576)
klamath_marsh_bbox <- c(-121.806202,42.827148,-121.517889,43.072530)


upper_klamath_lake <- extract_dswe_timeseries(
  bbox = upper_klamath_lake_bbox,
  start_date = '2016-10-01',
  end_date = '2020-08-31',
  cloud_cover_threshold = 20,
  output_prefix = "data-raw/dswe/upper_klamath_lake",
  create_plots = TRUE,
  save_files = TRUE
)


clear_lake <- extract_dswe_timeseries(
  bbox = clear_lake_bbox,
  start_date = '2016-10-01',
  end_date = '2020-08-31',
  cloud_cover_threshold = 20,
  output_prefix = "data-raw/dswe/clear_lake",
  create_plots = TRUE,
  save_files = TRUE
)

tule_lake <- extract_dswe_timeseries(
  bbox = tule_lake_bbox,
  start_date = '1995-10-01',
  end_date = '1996-08-31',
  cloud_cover_threshold = 20,
  output_prefix = "data-raw/dswe/tule_lake",
  create_plots = TRUE,
  save_files = TRUE
)

bear_valley <- extract_dswe_timeseries(
  bbox = bear_valley_bbox,
  start_date = '2016-10-01',
  end_date = '2020-08-31',
  cloud_cover_threshold = 20,
  output_prefix = "data-raw/dswe/bear_valley",
  create_plots = TRUE,
  save_files = TRUE
)

lower_klamath_sheepy <- extract_dswe_timeseries(
  bbox = lower_klamath_sheepy_bbox,
  start_date = '2016-10-01',
  end_date = '2020-08-31',
  cloud_cover_threshold = 20,
  output_prefix = "data-raw/dswe/lower_klamath_sheepy",
  create_plots = TRUE,
  save_files = TRUE
)

klamath_marsh <- extract_dswe_timeseries(
  bbox = klamath_marsh_bbox,
  start_date = '2016-10-01',
  end_date = '2020-08-31',
  cloud_cover_threshold = 20,
  output_prefix = "data-raw/dswe/klamath_marsh",
  create_plots = TRUE,
  save_files = TRUE
)

# summary table for primary review with Jim
monthly_table <- bind_rows(tule_lake$monthly |>
                             mutate(area = "Tule Lake"),
                           clear_lake$monthly |>
                             mutate(area = "Clear Lake"),
                           bear_valley$monthly |>
                             mutate(area = "Bear Valley"),
                           lower_klamath_sheepy$monthly |>
                             mutate(area = "Lower Klamath Sheepy")) |>
  mutate(Year = year(year_month),
         month = month(year_month)) |>
  left_join(tibble("month" = 1:12,
                   "Month" = month.abb),
            by = "month") |>
  select(Area = area,
         Year, Month, `Mean Total Water` = mean_water,
         `SD Total Water` = sd_water,
         `Mean Class 1` = mean_class1,
         `Mean Class 2` = mean_class2,
         `Mean Class 3` = mean_class3,
         `n` = n_obs) |>
  mutate(across(`Mean Total Water`:`Mean Class 3`, \(x) x * 100),
         across(`Mean Total Water`:`Mean Class 3`, \(x) round(x, 3)))

write_csv(monthly_table, "data-raw/dswe/monthly_summary_all.csv")

# Access results
# ts_df <- results1$timeseries
# monthly_stats <- results1$monthly
# summary <- results1$summary


# get metadata ------------------------------------------------------------

# Function to get metadata on available Landsat data
get_landsat_metadata <- function(bbox,
                                 start_date = '1984-01-01',
                                 end_date = Sys.Date(),
                                 cloud_cover_threshold = 100) {

  cat("============================================================\n")
  cat("Landsat Data Availability Metadata\n")
  cat("============================================================\n")
  cat("Bounding box:", paste(bbox, collapse = ", "), "\n")
  cat("Date range:", start_date, "to", end_date, "\n\n")

  # Create AOI
  aoi <- ee$Geometry$Rectangle(bbox)

  # Load all Landsat collections
  landsat4 <- ee$ImageCollection('LANDSAT/LT04/C02/T1_L2')$
    filterBounds(aoi)$
    filterDate(start_date, end_date)$
    filter(ee$Filter$lt('CLOUD_COVER', cloud_cover_threshold))

  landsat5 <- ee$ImageCollection('LANDSAT/LT05/C02/T1_L2')$
    filterBounds(aoi)$
    filterDate(start_date, end_date)$
    filter(ee$Filter$lt('CLOUD_COVER', cloud_cover_threshold))

  landsat7 <- ee$ImageCollection('LANDSAT/LE07/C02/T1_L2')$
    filterBounds(aoi)$
    filterDate(start_date, end_date)$
    filter(ee$Filter$lt('CLOUD_COVER', cloud_cover_threshold))

  landsat8 <- ee$ImageCollection('LANDSAT/LC08/C02/T1_L2')$
    filterBounds(aoi)$
    filterDate(start_date, end_date)$
    filter(ee$Filter$lt('CLOUD_COVER', cloud_cover_threshold))

  landsat9 <- ee$ImageCollection('LANDSAT/LC09/C02/T1_L2')$
    filterBounds(aoi)$
    filterDate(start_date, end_date)$
    filter(ee$Filter$lt('CLOUD_COVER', cloud_cover_threshold))

  # Get counts
  n4 <- landsat4$size()$getInfo()
  n5 <- landsat5$size()$getInfo()
  n7 <- landsat7$size()$getInfo()
  n8 <- landsat8$size()$getInfo()
  n9 <- landsat9$size()$getInfo()

  cat("Images available by satellite:\n")
  cat("  Landsat 4 (1982-1993):", n4, "images\n")
  cat("  Landsat 5 (1984-2012):", n5, "images\n")
  cat("  Landsat 7 (1999-present):", n7, "images\n")
  cat("  Landsat 8 (2013-present):", n8, "images\n")
  cat("  Landsat 9 (2021-present):", n9, "images\n")
  cat("  Total:", n4 + n5 + n7 + n8 + n9, "images\n\n")

  # Merge all collections
  all_landsat <- landsat4$merge(landsat5)$merge(landsat7)$merge(landsat8)$merge(landsat9)

  # Get date range
  if (all_landsat$size()$getInfo() > 0) {
    dates <- all_landsat$aggregate_array('DATE_ACQUIRED')$getInfo()
    dates_parsed <- as.Date(unlist(dates))

    cat("Date coverage:\n")
    cat("  First image:", as.character(min(dates_parsed)), "\n")
    cat("  Last image:", as.character(max(dates_parsed)), "\n")
    cat("  Time span:", round(as.numeric(difftime(max(dates_parsed), min(dates_parsed), units = "days")) / 365.25, 1), "years\n\n")

    # Images by year
    years_df <- data.frame(date = dates_parsed) %>%
      mutate(year = year(date)) %>%
      count(year) %>%
      rename(n_images = n)

    cat("Images per year:\n")
    print(years_df)

    # Plot images per year
    p <- ggplot(years_df, aes(x = year, y = n_images)) +
      geom_col(fill = "steelblue") +
      geom_text(aes(label = n_images), vjust = -0.5, size = 3) +
      labs(
        title = "Landsat Image Availability by Year",
        subtitle = sprintf("Bounding Box: %.3f, %.3f to %.3f, %.3f",
                           bbox[1], bbox[2], bbox[3], bbox[4]),
        x = "Year",
        y = "Number of Images",
        caption = paste0("Cloud cover < ", cloud_cover_threshold, "%")
      ) +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))

    print(p)

    # Get WRS path/row info
    first_img <- ee$Image(all_landsat$first())
    path <- first_img$get('WRS_PATH')$getInfo()
    row <- first_img$get('WRS_ROW')$getInfo()

    cat("\nLandsat WRS-2 Path/Row:\n")
    cat("  Path:", path, "\n")
    cat("  Row:", row, "\n")
    cat("  (This identifies which Landsat scene covers your area)\n\n")

    # Return summary
    return(list(
      total_images = n4 + n5 + n7 + n8 + n9,
      by_satellite = data.frame(
        satellite = c("Landsat 4", "Landsat 5", "Landsat 7", "Landsat 8", "Landsat 9"),
        n_images = c(n4, n5, n7, n8, n9)
      ),
      by_year = years_df,
      date_range = c(min(dates_parsed), max(dates_parsed)),
      wrs_path = path,
      wrs_row = row
    ))

  } else {
    cat("No images found for this bounding box!\n")
    return(NULL)
  }
}

# get metadata

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

