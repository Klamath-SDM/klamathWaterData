library(tidyverse)
library(terra)
library(sf)

# -------------------------------------------------------------------------
# Refuge bounding boxes
#
# Bounding boxes are derived from the authoritative refuge boundaries in
# rivermile::klamath_refuges (a 6-feature sf polygon layer, EPSG:4326),
# each buffered by 0.5 miles before taking the bounding box. This replaces
# the hand-picked bboxes previously hardcoded here. The refuge/orgname
# lookup below maps this package's existing refuge labels onto
# klamath_refuges$orgname; "lower_klamath_sheepy" maps to the single
# "lower klamath national wildlife refuge" polygon, which is the only
# lower Klamath / Sheepy Ridge unit present in klamath_refuges.
#
# WET rasters are in EPSG:4326 (decimal degrees), so refuge polygons are
# buffered in a projected CRS (EPSG:32610, UTM Zone 10N — meters, and
# appropriate for the Klamath Basin's longitude range) and transformed
# back to EPSG:4326 before computing the bbox used to crop() the rasters.
#
# NOTE: bear_valley is expected to come out all-NA / zero-pixel in both
# wet_surface_water and wet_hydroperiod. Verified via visual QC (raster
# vs. refuge boundary overlay, checked across multiple products/eras) that
# the source WET rasters have no detected water anywhere inside the actual
# Bear Valley NWR boundary — this refuge is small and mostly upland/forest,
# below the product's mapping resolution/threshold. The previous
# hand-drawn bbox for this refuge happened to clip the edge of an unrelated
# stream feature just northeast of the refuge, which produced a handful of
# nonzero pixels that were never really inside the refuge; the
# rivermile-derived bbox is tighter and excludes that spillover, so the
# all-NA result here is more correct, not a regression.
# -------------------------------------------------------------------------

REFUGE_BUFFER_MILES <- 0.5
REFUGE_BUFFER_METERS <- REFUGE_BUFFER_MILES * 1609.344
BUFFER_CRS <- 32610 # UTM Zone 10N

refuge_lookup <- tribble(
  ~refuge,                ~orgname,
  "upper_klamath_lake",   "upper klamath national wildlife refuge",
  "clear_lake",           "clear lake national wildlife refuge",
  "tule_lake",            "tule lake national wildlife refuge",
  "bear_valley",          "bear valley national wildlife refuge",
  "lower_klamath_sheepy", "lower klamath national wildlife refuge",
  "klamath_marsh",        "klamath marsh national wildlife refuge"
)

refuge_boundaries_buffered <- rivermile::klamath_refuges |>
  inner_join(refuge_lookup, by = "orgname") |>
  st_transform(BUFFER_CRS) |>
  st_buffer(REFUGE_BUFFER_METERS) |>
  st_transform(4326)

refuge_bboxes <- refuge_boundaries_buffered |>
  split(refuge_boundaries_buffered$refuge) |>
  map(~ as.numeric(st_bbox(.x))) # c(xmin, ymin, xmax, ymax)

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
