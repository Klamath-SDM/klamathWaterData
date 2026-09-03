# Pull and process geospatial data on diversions and diversion screens in the Klamath Basin
# See data-raw/data-exploration/screening-keno/fish-screening-exploration.Rmd for more exploration
# on these data

library(tidyverse)
library(leaflet)
library(janitor)

# These data were provided by Bob Pagliuco via Danielle Hereford (BOR, dhereford@usbr.gov)
lpkx_dir <- here::here("data-raw", "screening-diversion-keno-data")

# .lpkx files are zipped ArcGIS Layer Package files; extract the archive to a temp
# dir and read the first shapefile found inside
extract_lpkx_layer <- function(lpkx_name) {
  lpkx_path <- file.path(lpkx_dir, lpkx_name)
  out_dir <- file.path(tempdir(), tools::file_path_sans_ext(lpkx_name))
  archive_extract(lpkx_path, dir = out_dir)

  shp <- list.files(out_dir, pattern = "\\.shp$", recursive = TRUE, full.names = TRUE)
  st_read(shp[1], quiet = TRUE)
}

# Data were prepared separately for upstream and downstream of Keno Dam and do not
# have the same format, naming etc., requiring wrangling work
screen_ds <- extract_lpkx_layer("K3RP_FinalScreening_DSofKENO.lpkx") |> clean_names()
screen_us <- extract_lpkx_layer("K3RP_FinalScreening_USofKENO.lpkx") |> clean_names()

# reproject both layers from their source CRS to WGS84 (EPSG:4326) for consistent
# lat/long output
ds_wgs84 <- st_transform(screen_ds, 4326)
us_wgs84 <- st_transform(screen_us, 4326)

# downstream-of-Keno layer: pull point coordinates out of the geometry column into
# plain latitude/longitude fields, then select and rename to a common schema.
# size_score = size of the diversion relative to the stream it draws from;
# benefit_score = number of fish species (anadromous + resident native) affected;
# total_score = combination of the individual scores, used to assign a priority tier
ds_clean <- ds_wgs84 |>
  st_drop_geometry() |>
  bind_cols(st_coordinates(ds_wgs84) |> as_tibble() |> rename(longitude = X, latitude = Y)) |>
  transmute(
    stream = stream_grp,
    total_volume_cfs = rate_cfs,
    screen,
    size_score,
    benefit_score = ben_score,
    total_score = tot_score,
    notes,
    latitude,
    longitude)

# upstream-of-Keno layer: same target schema as ds_clean, but this layer doesn't
# carry a stream name (all points are on the Klamath River) and uses different
# source column names for volume
us_clean <- us_wgs84 |>
  st_drop_geometry() |>
  bind_cols(st_coordinates(us_wgs84) |> as_tibble() |> rename(longitude = X, latitude = Y)) |>
  transmute(
    stream = "Klamath River",
    total_volume_cfs = total_cfs,
    screen,
    size_score,
    benefit_score = ben_score,
    total_score = tot_score,
    notes,
    latitude,
    longitude)

# combine both reaches into a single dataset with a shared schema
keno_diversion_screening <- bind_rows(ds_clean, us_clean) |>
  # lower case all character columns for consistency
  mutate(across(where(is.character), str_to_lower))

glimpse(keno_diversion_screening)

# save clean data
usethis::use_data(keno_diversion_screening,   overwrite = TRUE)
