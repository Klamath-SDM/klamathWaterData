library(tidyverse)
library(dplyr)
library(tidyr)
library(purrr)
library(pins)
library(rivermile)
library(sf)

# raw data will be pulled from S3 bucket. These data is originally retrieved on lake-level-data-pull.R

# setting up aws bucket
wq_data_board <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1")


# pulling raw data
water_level_data <- wq_data_board |>
  pins::pin_read("water_quality/data-raw/water_level_data") |>
  janitor::clean_names() |>
  glimpse()

water_level_data_raw_clean <- water_level_data |>
  mutate(gage_id = site_no,
         date = as.Date(date),
         mean_level = x_72275_00003) |>
  select(-c(x_72275_00003_cd,x_72275_00003)) |>
  pivot_longer(cols = c(mean_level),
               names_to = "statistic",
               values_to = "value",
               values_drop_na = TRUE) |>
  mutate(statistic = case_when(
    statistic == "mean_level" ~ "mean"),
    variable_name = "water level",
    unit = "feet") |>
  glimpse()

# GAGE data
water_level_gage_data <- wq_data_board |>
  pins::pin_read("water_quality/data-raw/water_level_gage_data") |>
  janitor::clean_names() |>
  mutate(station_nm = tools::toTitleCase(tolower(station_nm))) |>
  glimpse()

# JOIN - station data with temp data
all_usgs_water_level_raw <- water_level_data_raw_clean |> left_join(water_level_gage_data, by = "site_no") |>
  select(c(agency_cd.x, site_no, date, gage_id, statistic, value, variable_name,
           unit, station_nm, dec_lat_va, dec_long_va, huc_cd)) |>
  mutate(waterbody_name = "upper klamath lake") |>
  glimpse()

#### water data table ----
water_level_data <- all_usgs_water_level_raw |>
  mutate(gage_id = site_no,
         gage_name = tolower(station_nm),
         stream = waterbody_name) |>
  select(stream, gage_name, gage_id, variable_name, value, unit, statistic, date) |>
  rename(location = stream) |>
  glimpse()

#### monitoring site table ----
water_level_gage <- all_usgs_water_level_raw |>
  mutate(gage_name = tolower(station_nm),
         gage_id = site_no,
         agency = agency_cd.x,
         latitude = dec_lat_va,
         longitude = dec_long_va,
         river_mile = NA,
         huc8 = huc_cd,
         stream = waterbody_name) |>
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |>
  distinct() |>
  # st_as_sf(coords = c("longitude", "latitude"), crs = 4326) |>
  # gage_data_format(filter_streams = FALSE) |>
  rename(location = stream) |>
  glimpse()



### saves clean data to aws
wq_processed_data <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1", prefix = "water_quality/processed-data/")

# water level data
wq_processed_data |> pins::pin_write(water_level_data,
                                     type = "csv")

# gage data
wq_processed_data |> pins::pin_write(water_level_gage,
                                     type = "csv")

# save rda files
usethis::use_data(water_level_data, overwrite = TRUE)
usethis::use_data(water_level_gage, overwrite = TRUE)

