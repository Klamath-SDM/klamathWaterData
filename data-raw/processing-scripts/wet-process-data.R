library(tidyverse)
library(terra)

# Refuge bounding boxes: c(xmin, ymin, xmax, ymax)
upper_klamath_lake_bbox    <- c(-122.107301, 42.214015, -121.787324, 42.602368)
clear_lake_bbox            <- c(-121.289207, 41.781010, -121.015256, 41.995292)
tule_lake_bbox             <- c(-121.598288, 41.800411, -121.347044, 41.995232)
bear_valley_bbox           <- c(-121.979966, 42.034977, -121.889353, 42.096687)
lower_klamath_sheepy_bbox  <- c(-121.851156, 41.883384, -121.591674, 42.033576)
klamath_marsh_bbox         <- c(-121.806202, 42.827148, -121.517889, 43.072530)

refuge_bboxes <- list(
  upper_klamath_lake   = upper_klamath_lake_bbox,
  clear_lake           = clear_lake_bbox,
  tule_lake            = tule_lake_bbox,
  bear_valley          = bear_valley_bbox,
  lower_klamath_sheepy = lower_klamath_sheepy_bbox,
  klamath_marsh        = klamath_marsh_bbox
)

# -------------------------------------------------------------------------
# File inventory
# -------------------------------------------------------------------------
data_dir <- here::here("data-raw", "intermountain-west-data")

tif_files <- list.files(data_dir, pattern = "\\.tif$", full.names = TRUE)

month_lookup <- c(
  JAN = 1, FEB = 2, MAR = 3, APR = 4, MAY = 5, JUN = 6,
  JUL = 7, AUG = 8, SEP = 9, OCT = 10, NOV = 11, DEC = 12
)

file_meta <- tibble(path = tif_files) |>
  mutate(
    filename   = basename(path) |> str_remove("\\.tif$"),
    type       = case_when(
      str_starts(filename, "SurfaceWater") ~ "SurfaceWater",
      str_starts(filename, "Hydroperiod")  ~ "Hydroperiod"
    ),
    rest       = str_remove(filename, type),
    month_chr  = str_extract(rest, "[A-Z]{3}$"),
    era_str    = str_remove(rest, "[A-Z]{3}$"),
    month_num  = month_lookup[month_chr],
    is_decadal = str_detect(era_str, "-"),
    era_start  = as.integer(str_extract(era_str, "^[0-9]{4}"))
  )

# -------------------------------------------------------------------------
# Extract per-refuge statistics from each raster
# -------------------------------------------------------------------------
extract_refuge_stats <- function(path, refuge_name, bbox) {
  r <- rast(path)

  # bbox is c(xmin, ymin, xmax, ymax); terra::ext() expects xmin, xmax, ymin, ymax
  refuge_ext <- ext(bbox[1], bbox[3], bbox[2], bbox[4])

  r_crop <- tryCatch(
    crop(r, refuge_ext),
    error = function(e) NULL
  )

  if (is.null(r_crop)) {
    return(tibble(
      refuge     = refuge_name,
      mean_val   = NA_real_,
      median_val = NA_real_,
      sd_val     = NA_real_,
      pct_wet    = NA_real_,
      n_pixels   = NA_integer_
    ))
  }

  vals <- values(r_crop, na.rm = TRUE)

  tibble(
    refuge     = refuge_name,
    mean_val   = mean(vals),
    median_val = median(vals),
    sd_val     = sd(vals),
    pct_wet    = mean(vals > 0),
    n_pixels   = length(vals)
  )
}

message("Processing ", nrow(file_meta), " rasters across ", length(refuge_bboxes), " refuges...")

wet_data <- file_meta |>
  mutate(
    refuge_stats = map(path, function(p) {
      imap_dfr(refuge_bboxes, ~ extract_refuge_stats(p, .y, .x))
    })
  ) |>
  unnest(refuge_stats) |>
  select(refuge, type, era_str, is_decadal, era_start, month_chr, month_num,
         mean_val, median_val, sd_val, pct_wet, n_pixels)

# -------------------------------------------------------------------------
# Split into SurfaceWater and Hydroperiod datasets
# -------------------------------------------------------------------------
wet_surface_water <- wet_data |> filter(type == "SurfaceWater")
wet_hydroperiod   <- wet_data |> filter(type == "Hydroperiod")

# -------------------------------------------------------------------------
# Save processed data
# -------------------------------------------------------------------------
usethis::use_data(wet_surface_water, overwrite = TRUE)
usethis::use_data(wet_hydroperiod,   overwrite = TRUE)
