library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

#notes and questions: 
# WQX - There is one site that does not seem to be located on a stream “QVIR-SRES (Shackleford at Reservation)”. Waterbody_name function did not work 

# raw data will be pulled from S3 bucket. These data is originally retrieved on ph-data-pull.R

# setting up aws bucket
wq_data_board <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1")


source(here::here('data-raw', 'processing-scripts', 'utils.R'))

### WQX ----
# pulling raw data
# pH data
wqx_data_raw <- wq_data_board |> 
  pins::pin_read("water_quality/data-raw/wqx_ph_data") |> 
  janitor::clean_names() |> 
  glimpse()

# GAGE data
wqx_gage_raw <- wq_data_board |> 
  pins::pin_read("water_quality/data-raw/wqx_gage_data") |> 
  filter(monitoring_location_type_name %in% c("River/Stream", "Lake", "Stream",
                                              "Reservoir", "Lake, Reservoir, Impoundment",
                                              "Spring", "Estuary")) |>
  janitor::clean_names() |> 
  glimpse()

# JOIN - station data with flow data
all_wqx_ph_data <- wqx_data_raw |> left_join(wqx_gage_raw) |> 
  glimpse()


#cleaning data
all_wqx_ph_data <- all_wqx_ph_data |> 
  mutate(waterbody_name = extract_waterbody(monitoring_location_name),
         waterbody_name = str_to_title(waterbody_name)) # testing function

# check for naming assigned 
all_wqx_ph_data |> 
  select(waterbody_name, monitoring_location_name, monitoring_location_identifier) |> 
  distinct() |> 
  view()

all_wqx_ph_data_clean <- all_wqx_ph_data |> 
mutate(waterbody_name = case_when(
  monitoring_location_name == "Townsends Gulch" ~ "Scott River",
  TRUE ~ waterbody_name))

#### water data table ----
ph_wqx <- all_wqx_ph_data_clean |> 
  mutate(gage_id = monitoring_location_identifier,
         gage_name = monitoring_location_name,
         variable_name = characteristic_name,
         value = result_measure_value,
         unit = result_measure_measure_unit_code,
         statistic = statistical_base_code,
         date = activity_start_date) |> 
  select(waterbody_name, gage_name, gage_id, variable_name, value, unit, statistic, date) |> 
  glimpse()

#### monitoring site table ----
gage_ph_wqx <- all_wqx_ph_data_clean |> 
  mutate(gage_name = monitoring_location_name,
         gage_id = monitoring_location_identifier,
         agency = organization_formal_name,
         latitude = latitude_measure,
         longitude = longitude_measure,
         river_mile = NA,
         huc8 = huc_eight_digit_code,
         stream = waterbody_name) |> 
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |> 
  glimpse()

#### saves clean data to aws ----
wq_processed_data <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1", prefix = "water_quality/processed-data/")

# temp data
wq_processed_data |> pins::pin_write(ph_wqx,
                                     type = "csv",
                                     title = "ph_processed_data_usgs")

# gage data 
wq_processed_data |> pins::pin_write(gage_ph_wqx,
                                     type = "csv",
                                     title = "gage_ph_processed_data")


### USGS ----