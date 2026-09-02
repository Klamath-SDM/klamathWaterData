library(tidyverse)
library(leaflet)
library(janitor)

lpkx_dir <- here::here("data-raw", "screening-diversion-keno-data")

extract_lpkx_layer <- function(lpkx_name) {
  lpkx_path <- file.path(lpkx_dir, lpkx_name)
  out_dir <- file.path(tempdir(), tools::file_path_sans_ext(lpkx_name))
  archive_extract(lpkx_path, dir = out_dir)

  shp <- list.files(out_dir, pattern = "\\.shp$", recursive = TRUE, full.names = TRUE)
  st_read(shp[1], quiet = TRUE)
}

screen_ds <- extract_lpkx_layer("K3RP_FinalScreening_DSofKENO.lpkx") |> clean_names()
screen_us <- extract_lpkx_layer("K3RP_FinalScreening_USofKENO.lpkx") |> clean_names()

ds_wgs84 <- st_transform(screen_ds, 4326)
us_wgs84 <- st_transform(screen_us, 4326)


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

keno_diversion_screening <- bind_rows(ds_clean, us_clean)

glimpse(keno_diversion_screening)

# save clean data
usethis::use_data(keno_diversion_screening,   overwrite = TRUE)
