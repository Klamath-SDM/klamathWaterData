library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

# raw data will be pulled from S3 bucket. These data is originally retrieved on temperature-data-pull.R

# setting up aws bucket
wq_data_raw <- pins::board_s3(
  bucket = "klamath-sdm",
  access_key = Sys.getenv("aws_access_key_id"),
  secret_access_key = Sys.getenv("aws_secret_access_key"),
  session_token = Sys.getenv("aws_session_token"),
  region = "us-east-1")

source(here::here('data-raw', 'processing-scripts', 'utils.R'))


### WQX ----
# pulling raw data
# TEMPERATURE data
wqx_data_raw <- aws_board |> 
  pins::pin_read("water_quality/data-raw/wqx_temp_data") |> 
  janitor::clean_names() |> 
  filter(statistical_base_code %in% c("Mean", "Maximum", "Minimum")) |>  # filtering to stats of interest
  glimpse()


# GAGE data
wqx_gage_raw <- aws_board |> 
  pins::pin_read("water_quality/data-raw/wqx_gage_data") |> 
  janitor::clean_names() |> 
  filter(monitoring_location_type_name %in% c("River/Stream", "Lake", "Stream",
                                              "Reservoir", "Lake, Reservoir, Impoundment",  
                                              "Spring", "Estuary")) |> 
  glimpse()

# JOIN - station data with temp data
all_wqx_temp_data <- wqx_data_raw |> left_join(wqx_gage_raw) |> 
  glimpse()

#cleaning data
all_wqx_temp_data <- all_wqx_temp_data |> 
  mutate(waterbody_name = extract_waterbody(monitoring_location_name)) # testing function

# check
sum(is.na(all_wqx_temp_data$monitoring_location_name))

sum(is.na(all_wqx_temp_data$waterbody_name)) # lots of na introduced

missing_names_wqx <- all_wqx_temp_data |> 
  filter(is.na(waterbody_name)) 

table(missing_names_wqx$monitoring_location_name) # only 8 names that did not catch on function. This a source for checking those names https://www.waterqualitydata.us/provider/STORET/HVTEPA_WQX/


# WATER QUALITY TABLE
temperature_wxq <- all_wqx_temp_data |> 
  mutate(gage_id = monitoring_location_identifier,
         gage_name = monitoring_location_name,
         variable_name = characteristic_name,
         value = result_measure_value,
         unit = result_measure_measure_unit_code,
         statistic = statistical_base_code,
         date = activity_start_date) |> 
  select(waterbody_name, gage_name, gage_id, variable_name, value, unit, statistic, date) |> 
  glimpse()

# SITE TABLE


### USGS ----
# pulling raw data
# TEMPERATURE data
usgs_data_raw <- wq_data_raw |> 
  pins::pin_read("water_quality/data-raw/usgs_temp_data") |> 
  janitor::clean_names() |>
  glimpse()

usgs_data_raw_clean <- usgs_data_raw |> 
  mutate(gage_id = site_no,
         date = as.Date(date),
         max_temp = x_00010_00001,
         min_temp = x_00010_00002,
         mean_temp = x_00010_00003) |>
  select(-c(x_00010_00001, x_00010_00001_cd, x_00010_00002, x_00010_00002_cd, x_00010_00003, x_00010_00003_cd, date_time, tz_cd)) |>
  pivot_longer(cols = c(max_temp, min_temp, mean_temp),
               names_to = "statistic",
               values_to = "value",
               values_drop_na = TRUE) |> 
  mutate(statistic = case_when(
    statistic == "max_temp" ~ "maximum",
    statistic == "min_temp" ~ "minimum",
    statistic == "mean_temp" ~ "mean"),
    variable_name = "temperature",
    unit = "celsius") |> 
  glimpse()

# GAGE data
usgs_gage_raw <- wq_data_raw |> 
  pins::pin_read("water_quality/data-raw/usgs_gage_data") |> 
  janitor::clean_names() |> 
  glimpse()
  
# JOIN - station data with temp data
all_usgs_temp_data <- usgs_data_raw_clean |> left_join(usgs_gage_raw, by = "site_no") |> 
  select(c(agency_cd.x, site_no, date, gage_id, statistic, value, variable_name, unit, station_nm, dec_lat_va, dec_long_va)) |> 
  glimpse()

#cleaning data
all_usgs_temp_data_test <- all_usgs_temp_data |> 
  mutate(waterbody_name = extract_waterbody(station_nm)) # testing function

unique(all_usgs_temp_data_test$waterbody_name)
sum(is.na(all_usgs_temp_data_test$waterbody_name))

# water_names that did not work with the function
usgs_fix_needed <- all_usgs_temp_data_test |> 
  filter(is.na(waterbody_name)) |> 
  view()
