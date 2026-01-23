# ------------------------------------------------------------
# Helpers (put these once in your script, above the main function)
# ------------------------------------------------------------

choose_aoi_mode <- function(bbox,
                            large_km2 = 600,        # threshold for "large AOI"
                            large_pixels = 1.5e6,   # threshold based on est pixels @30m
                            scale_small = 30,
                            scale_large = 60,
                            chunk_small = 40,
                            chunk_large = 15,
                            tile_small = 4,
                            tile_large = 8) {
  stopifnot(length(bbox) == 4)

  lon_min <- bbox[1]; lat_min <- bbox[2]
  lon_max <- bbox[3]; lat_max <- bbox[4]

  dlon <- abs(lon_max - lon_min)
  dlat <- abs(lat_max - lat_min)

  lat_mid <- (lat_min + lat_max) / 2
  km_per_deg_lat <- 111.32
  km_per_deg_lon <- 111.32 * cos(lat_mid * pi / 180)

  width_km  <- dlon * km_per_deg_lon
  height_km <- dlat * km_per_deg_lat
  area_km2  <- width_km * height_km

  px_area_km2 <- (scale_small / 1000)^2
  est_pixels  <- area_km2 / px_area_km2

  is_large <- (area_km2 >= large_km2) || (est_pixels >= large_pixels)

  list(
    is_large = is_large,
    area_km2 = area_km2,
    est_pixels_30m = est_pixels,
    scale = if (is_large) scale_large else scale_small,
    tileScale = if (is_large) tile_large else tile_small,
    bestEffort = is_large,
    chunk_size = if (is_large) chunk_large else chunk_small
  )
}

ee_fc_getinfo_chunked <- function(fc,
                                  chunk_size = 40,
                                  tries = 10,
                                  base_sleep = 2,
                                  pause = 0.5) {
  n <- fc$size()$getInfo()
  if (n == 0) return(list(features = list()))

  idx <- seq(0, n - 1)
  chunks <- split(idx, ceiling(seq_along(idx) / chunk_size))

  getinfo_retry <- function(obj) {
    for (i in seq_len(tries)) {
      res <- tryCatch(obj$getInfo(), error = identity)
      if (!inherits(res, "error")) return(res)

      msg <- conditionMessage(res)
      if (!grepl("Too many concurrent aggregations|HttpError 429|429", msg)) stop(res)

      Sys.sleep(base_sleep * (2^(i - 1)) + runif(1, 0, 0.5))
    }
    stop("EE throttling persisted after retries.")
  }

  out_features <- list()
  for (ch in chunks) {
    sub <- ee$FeatureCollection(fc$toList(length(ch), ch[[1]]))
    info <- getinfo_retry(sub)
    out_features <- c(out_features, info$features)
    Sys.sleep(pause)
  }

  list(features = out_features)
}


# ------------------------------------------------------------
# Main function (drop-in replacement)
# ------------------------------------------------------------

extract_dswe_timeseries <- function(
    bbox,
    start_date = "2020-01-01",
    end_date = "2023-12-31",
    cloud_cover_threshold = 20,
    output_prefix = "dswe",
    create_plots = TRUE,
    save_files = TRUE,
    # Auto “large AOI mode” controls:
    auto_large_aoi = TRUE,
    large_km2 = 600,
    large_pixels = 1.5e6,
    scale_small = 30,
    scale_large = 60,
    chunk_small = 40,
    chunk_large = 15,
    tile_small = 4,
    tile_large = 8
) {
  # packages used later
  if (!requireNamespace("dplyr", quietly = TRUE)) stop("Install dplyr")
  if (!requireNamespace("tidyr", quietly = TRUE)) stop("Install tidyr")
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2")
  if (!requireNamespace("readr", quietly = TRUE)) stop("Install readr")
  if (!requireNamespace("lubridate", quietly = TRUE)) stop("Install lubridate")

  `%>%` <- dplyr::`%>%`

  cat("============================================================\n")
  cat("DSWE Time Series Extraction\n")
  cat("============================================================\n")
  cat("Bounding box:", paste(bbox, collapse = ", "), "\n")
  cat("Requested date range:", start_date, "to", end_date, "\n")
  cat("Cloud cover threshold:", cloud_cover_threshold, "%\n\n")

  # AOI
  aoi <- ee$Geometry$Rectangle(bbox)

  # ---------------------------------------------------------------------------
  # Auto “large AOI mode” selection
  # ---------------------------------------------------------------------------
  mode <- list(
    is_large = FALSE,
    area_km2 = NA_real_,
    est_pixels_30m = NA_real_,
    scale = scale_small,
    tileScale = tile_small,
    bestEffort = FALSE,
    chunk_size = chunk_small
  )

  if (auto_large_aoi) {
    mode <- choose_aoi_mode(
      bbox = bbox,
      large_km2 = large_km2,
      large_pixels = large_pixels,
      scale_small = scale_small,
      scale_large = scale_large,
      chunk_small = chunk_small,
      chunk_large = chunk_large,
      tile_small = tile_small,
      tile_large = tile_large
    )

    cat(sprintf("AOI approx area: %.1f km^2; est pixels @30m: %.0f\n",
                mode$area_km2, mode$est_pixels_30m))
    cat("Large AOI mode:", ifelse(mode$is_large, "ON", "OFF"), "\n")
    cat("Using scale:", mode$scale,
        "| tileScale:", mode$tileScale,
        "| chunk_size:", mode$chunk_size,
        "| bestEffort:", mode$bestEffort, "\n\n")
  }

  # ---------------------------------------------------------------------------
  # DSWE Algorithm
  # ---------------------------------------------------------------------------
  calculate_dswe <- function(image) {
    # Scale optical bands (Landsat C2 L2 scaling factors)
    optical <- image$select("SR_B.")$multiply(0.0000275)$add(-0.2)

    # Landsat 8/9 mapping: Blue=B2, Green=B3, Red=B4, NIR=B5, SWIR1=B6, SWIR2=B7
    blue <- optical$select("SR_B2")
    green <- optical$select("SR_B3")
    nir <- optical$select("SR_B5")
    swir1 <- optical$select("SR_B6")
    swir2 <- optical$select("SR_B7")

    # Indices
    mndwi <- green$subtract(swir1)$divide(green$add(swir1))$rename("mndwi")
    mbsrv <- green$add(swir1)$rename("mbsrv")
    mbsrn <- nir$add(swir1)$rename("mbsrn")
    ndvi  <- nir$subtract(blue)$divide(nir$add(blue))$rename("ndvi")
    awesh <- blue$add(green$multiply(2.5))$
      subtract(nir$multiply(1.5))$
      subtract(swir1$multiply(0.25))$
      subtract(swir2$multiply(0.25))$
      rename("awesh")

    # DSWE tests
    test1 <- mndwi$gt(0.124)
    test2 <- mbsrv$gt(mbsrn)
    test3 <- awesh$gt(0)
    test4 <- mndwi$gt(-0.44)$And(swir1$lt(0.09))$And(nir$lt(0.15))$And(ndvi$lt(0.7))
    test5 <- mndwi$gt(-0.5)$And(swir1$lt(0.3))$And(swir2$lt(0.1))$And(nir$lt(0.25))

    # DSWE classes
    dswe <- ee$Image(0)$
      where(test1, 1)$
      where(test1$And(test2)$And(test3), 1)$
      where(test5, 2)$
      where(test1$And(test2$Not())$And(test3), 3)$
      rename("dswe")

    # Cloud mask from QA_PIXEL (keep clear)
    qa <- image$select("QA_PIXEL")
    cloud_mask <- qa$bitwiseAnd(31)$eq(0)

    dswe$updateMask(cloud_mask)$copyProperties(image, image$propertyNames())
  }

  # ---------------------------------------------------------------------------
  # Load & Filter Landsat
  # ---------------------------------------------------------------------------
  cat("Loading Landsat imagery...\n")

  landsat8 <- ee$ImageCollection("LANDSAT/LC08/C02/T1_L2")$
    filterBounds(aoi)$
    filterDate(start_date, end_date)$
    filter(ee$Filter$lt("CLOUD_COVER", cloud_cover_threshold))

  landsat9 <- ee$ImageCollection("LANDSAT/LC09/C02/T1_L2")$
    filterBounds(aoi)$
    filterDate(start_date, end_date)$
    filter(ee$Filter$lt("CLOUD_COVER", cloud_cover_threshold))

  landsat <- landsat8$merge(landsat9)

  n_images <- landsat$size()$getInfo()
  cat("Found", n_images, "Landsat scenes\n")

  if (n_images == 0) {
    stop("No images found for the specified parameters (bbox/date/cloud threshold).")
  }

  # Helpful: what’s actually available after filters
  avail_min <- ee$Date(landsat$aggregate_min("system:time_start"))$format("YYYY-MM-dd")$getInfo()
  avail_max <- ee$Date(landsat$aggregate_max("system:time_start"))$format("YYYY-MM-dd")$getInfo()
  cat("Available imagery (after filters):", avail_min, "to", avail_max, "\n\n")

  # Apply DSWE
  cat("Computing DSWE for all images...\n")
  dswe_collection <- landsat$map(calculate_dswe)

  # ---------------------------------------------------------------------------
  # Extract Time Series (robust: ONE reduceRegion per image)
  # ---------------------------------------------------------------------------
  extract_dswe_stats <- function(image) {
    # robust date
    date_str <- ee$Date(image$get("system:time_start"))$format("YYYY-MM-dd")

    dswe <- image$select("dswe")

    # 0/1 mask bands
    water <- dswe$gte(1)$And(dswe$lte(3))$rename("water")
    c1 <- dswe$eq(1)$rename("class1")
    c2 <- dswe$eq(2)$rename("class2")
    c3 <- dswe$eq(3)$rename("class3")

    # valid pixel counter: constant 1 masked to valid dswe pixels
    valid <- ee$Image$constant(1)$updateMask(dswe$mask())$rename("valid")

    stacked <- ee$Image$cat(list(water, c1, c2, c3, valid))

    # mean -> percent; sum(valid) -> total pixels (in one call)
    reducer <- ee$Reducer$mean()$combine(
      reducer2 = ee$Reducer$sum(),
      sharedInputs = TRUE
    )

    stats <- stacked$reduceRegion(
      reducer = reducer,
      geometry = aoi,
      scale = mode$scale,
      maxPixels = 1e9,
      tileScale = mode$tileScale,
      bestEffort = mode$bestEffort
    )

    ee$Feature(NULL, list(
      date = date_str,
      total_pixels = stats$get("valid_sum"),
      water_percent = stats$get("water_mean"),
      class1_percent = stats$get("class1_mean"),
      class2_percent = stats$get("class2_mean"),
      class3_percent = stats$get("class3_mean")
    ))
  }

  cat("Extracting time series data...\n")
  time_series <- dswe_collection$map(extract_dswe_stats)

  # ---------------------------------------------------------------------------
  # Download results (chunked)
  # ---------------------------------------------------------------------------
  cat("Downloading results from Earth Engine...\n")
  ts_info <- ee_fc_getinfo_chunked(
    time_series,
    chunk_size = mode$chunk_size,
    tries = if (mode$is_large) 12 else 10,
    base_sleep = if (mode$is_large) 2 else 1,
    pause = if (mode$is_large) 1.0 else 0.4
  )

  # ---------------------------------------------------------------------------
  # Parse into R data frame
  # ---------------------------------------------------------------------------
  parse_feature <- function(feat) {
    props <- feat$properties
    date_str <- props$date
    if (is.null(date_str) || length(date_str) == 0) return(NULL)

    data.frame(
      date = as.Date(date_str),
      total_pixels = if (is.null(props$total_pixels)) NA else as.numeric(props$total_pixels),
      water_percent = if (is.null(props$water_percent)) NA else as.numeric(props$water_percent),
      class1_percent = if (is.null(props$class1_percent)) NA else as.numeric(props$class1_percent),
      class2_percent = if (is.null(props$class2_percent)) NA else as.numeric(props$class2_percent),
      class3_percent = if (is.null(props$class3_percent)) NA else as.numeric(props$class3_percent),
      stringsAsFactors = FALSE
    )
  }

  ts_df <- dplyr::bind_rows(lapply(ts_info$features, parse_feature)) %>%
    dplyr::filter(!is.na(date)) %>%
    dplyr::arrange(date) %>%
    dplyr::filter(!is.na(water_percent))

  cat("\nData extraction complete!\n")
  cat("Total observations (valid rows):", nrow(ts_df), "\n\n")

  if (nrow(ts_df) == 0) {
    warning("No valid data extracted! (All rows were NA after masking/reduction.)")
    return(NULL)
  }

  # ---------------------------------------------------------------------------
  # Visualizations
  # ---------------------------------------------------------------------------
  if (create_plots && nrow(ts_df) > 0) {
    cat("Creating visualizations...\n")

    p1 <- ggplot2::ggplot(ts_df, ggplot2::aes(x = date)) +
      ggplot2::geom_line(ggplot2::aes(y = class1_percent * 100, color = "Class 1: High Confidence"), linewidth = 0.8) +
      ggplot2::geom_line(ggplot2::aes(y = class2_percent * 100, color = "Class 2: Moderate Confidence"), linewidth = 0.8) +
      ggplot2::geom_line(ggplot2::aes(y = class3_percent * 100, color = "Class 3: Partial Surface Water"), linewidth = 0.8) +
      ggplot2::scale_color_manual(values = c(
        "Class 1: High Confidence" = "darkblue",
        "Class 2: Moderate Confidence" = "steelblue",
        "Class 3: Partial Surface Water" = "cyan3"
      )) +
      ggplot2::labs(
        title = "Dynamic Surface Water Extent by DSWE Class",
        subtitle = sprintf("Bounding Box: %.3f, %.3f to %.3f, %.3f | scale=%sm",
                           bbox[1], bbox[2], bbox[3], bbox[4], mode$scale),
        x = "Date",
        y = "Water Coverage (%)",
        color = "DSWE Class",
        caption = "Source: Landsat Collection 2, USGS DSWE Algorithm (Jones, 2019)"
      ) +
      ggplot2::theme_minimal() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(size = 14, face = "bold"),
        legend.position = "bottom"
      )

    if (save_files) {
      ggplot2::ggsave(paste0(output_prefix, "_timeseries.png"), p1, width = 12, height = 6, dpi = 300)
    }
    print(p1)

    ts_long <- ts_df %>%
      dplyr::select(date, class1_percent, class2_percent, class3_percent) %>%
      tidyr::pivot_longer(cols = -date, names_to = "class", values_to = "percent") %>%
      dplyr::mutate(class = factor(class,
                                   levels = c("class1_percent", "class2_percent", "class3_percent"),
                                   labels = c("Class 1: High Confidence",
                                              "Class 2: Moderate Confidence",
                                              "Class 3: Partial Surface Water")))

    p2 <- ggplot2::ggplot(ts_long, ggplot2::aes(x = date, y = percent * 100, fill = class)) +
      ggplot2::geom_area(alpha = 0.7) +
      ggplot2::scale_fill_manual(values = c(
        "Class 1: High Confidence" = "darkblue",
        "Class 2: Moderate Confidence" = "steelblue",
        "Class 3: Partial Surface Water" = "lightblue"
      )) +
      ggplot2::labs(
        title = "Water Extent by DSWE Class",
        x = "Date",
        y = "Coverage (%)",
        fill = "DSWE Class"
      ) +
      ggplot2::theme_minimal() +
      ggplot2::theme(legend.position = "bottom")

    if (save_files) {
      ggplot2::ggsave(paste0(output_prefix, "_stacked.png"), p2, width = 12, height = 6, dpi = 300)
    }
    print(p2)
  }

  # ---------------------------------------------------------------------------
  # Temporal Aggregations
  # ---------------------------------------------------------------------------
  monthly_stats <- ts_df %>%
    dplyr::mutate(year_month = lubridate::floor_date(date, "month")) %>%
    dplyr::group_by(year_month) %>%
    dplyr::summarise(
      mean_water = mean(water_percent, na.rm = TRUE),
      mean_class1 = mean(class1_percent, na.rm = TRUE),
      mean_class2 = mean(class2_percent, na.rm = TRUE),
      mean_class3 = mean(class3_percent, na.rm = TRUE),
      sd_water = sd(water_percent, na.rm = TRUE),
      n_obs = dplyr::n(),
      .groups = "drop"
    )

  ts_df_seasonal <- ts_df %>%
    dplyr::mutate(
      year = lubridate::year(date),
      month = lubridate::month(date),
      season = dplyr::case_when(
        month %in% c(12, 1, 2) ~ "Winter",
        month %in% c(3, 4, 5) ~ "Spring",
        month %in% c(6, 7, 8) ~ "Summer",
        month %in% c(9, 10, 11) ~ "Fall"
      )
    )

  seasonal_stats <- ts_df_seasonal %>%
    dplyr::group_by(season) %>%
    dplyr::summarise(
      mean_water = mean(water_percent, na.rm = TRUE),
      sd_water = sd(water_percent, na.rm = TRUE),
      n = dplyr::n(),
      .groups = "drop"
    )

  summary_stats <- ts_df %>%
    dplyr::summarise(
      n_observations = dplyr::n(),
      date_range_start = min(date),
      date_range_end = max(date),
      mean_water = mean(water_percent, na.rm = TRUE) * 100,
      median_water = stats::median(water_percent, na.rm = TRUE) * 100,
      sd_water = stats::sd(water_percent, na.rm = TRUE) * 100,
      min_water = min(water_percent, na.rm = TRUE) * 100,
      max_water = max(water_percent, na.rm = TRUE) * 100,
      mean_class1 = mean(class1_percent, na.rm = TRUE) * 100,
      mean_class2 = mean(class2_percent, na.rm = TRUE) * 100,
      mean_class3 = mean(class3_percent, na.rm = TRUE) * 100
    )

  cat("\nSummary Statistics:\n")
  print(summary_stats)

  # ---------------------------------------------------------------------------
  # Save Results
  # ---------------------------------------------------------------------------
  if (save_files) {
    cat("\nSaving results...\n")
    readr::write_csv(ts_df, paste0(output_prefix, "_timeseries.csv"))
    readr::write_csv(monthly_stats, paste0(output_prefix, "_monthly_stats.csv"))
    readr::write_csv(seasonal_stats, paste0(output_prefix, "_seasonal_stats.csv"))
    readr::write_csv(summary_stats, paste0(output_prefix, "_summary_stats.csv"))

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

  # Return results (+ mode info so you can see what it chose)
  return(list(
    timeseries = ts_df,
    monthly = monthly_stats,
    seasonal = seasonal_stats,
    summary = summary_stats,
    mode = mode,
    imagery_available = list(min = avail_min, max = avail_max, n_images = n_images)
  ))
}

# Metadata
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
