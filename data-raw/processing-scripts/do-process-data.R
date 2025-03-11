library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

#notes and questions: 
# there are 4 NPS locations that dont seem to be at a stream. They are comment out below 
# raw data will be pulled from S3 bucket. These data is originally retrieved on do-data-pull.R

# setting up aws bucket
wq_data_board <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1")


source(here::here('data-raw', 'processing-scripts', 'utils.R'))

### WQX ----
# pulling raw data
# DO data
wqx_data_raw <- wq_data_board |> 
  pins::pin_read("water_quality/data-raw/wqx_do_data") |> 
  janitor::clean_names() |> 
  filter(statistical_base_code %in% c("Mean", "Maximum", "Minimum")) |> 
  glimpse()

# GAGE data
wqx_gage_raw <- wq_data_board |> 
  pins::pin_read("water_quality/data-raw/wqx_gage_data") |> 
  janitor::clean_names() |> 
  filter(monitoring_location_type_name %in% c("River/Stream", "Lake", "Stream",
                                              "Reservoir", "Lake, Reservoir, Impoundment",
                                              "Spring", "Estuary")) |>
  glimpse()

# JOIN - station data with flow data
all_wqx_do_data <- wqx_data_raw |> left_join(wqx_gage_raw) |> 
  glimpse()

#cleaning data
all_wqx_do_data <- all_wqx_do_data |> 
  mutate(waterbody_name = extract_waterbody(monitoring_location_name),
         waterbody_name = str_to_title(waterbody_name)) # testing function - it does now work for these few cases

# check for naming assigned  - only two organizations ("Hoopa Valley Tribe (Tribal)", "National Park Service Water Resources Division")
all_wqx_do_data |> 
  select(waterbody_name, monitoring_location_name, monitoring_location_identifier) |> 
  distinct() |> 
  view()

all_wqx_do_data_clean <- all_wqx_do_data |> 
  mutate(waterbody_name = case_when(
    monitoring_location_name == "CDR and Nutrients at Saints Rest Bar" ~ "Klamath River",
    monitoring_location_name %in% c("CDR at Red Rock", "CDR at South Boundary") ~ "Trinity River",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ01" ~ "Cavern Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ02" ~ "Sun Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ03" ~ "Sun Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ05" ~ "Wheeler Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ06" ~ "Munson Creek",
    # monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ07" ~ "?",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ09" ~ "Lost Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ10" ~ "Middle Fork Annie Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ13" ~ "Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ14" ~ "Annie Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ17" ~ "Sand Creek",
    # monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ21" ~ " ?Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ22" ~ "Annie Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ26" ~ "Munson Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ29" ~ "Sand Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ30" ~ "Sun Creek",
    # monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ31" ~ "? Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ33" ~ "Sand Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ34" ~ "Munson Creek",
    # monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ37" ~ "? Creek",
    TRUE ~ waterbody_name)) |> 
  glimpse()

all_wqx_do_data_clean |> 
  select(waterbody_name, monitoring_location_name, monitoring_location_identifier) |> 
  distinct() |> 
  view()

# check
missing_names_wqx <- all_wqx_do_data_clean |>
  filter(is.na(waterbody_name)) |> 
  view()

#### water data table ----
do_wqx <- all_wqx_do_data_clean |> 
  mutate(gage_id = monitoring_location_identifier,
         gage_name = monitoring_location_name,
         variable_name = characteristic_name,
         value = as.numeric(result_measure_value),
         unit = result_measure_measure_unit_code,
         statistic = statistical_base_code,
         date = as.Date(activity_start_date)) |> 
  select(waterbody_name, gage_name, gage_id, variable_name, value, unit, statistic, date) |> 
  glimpse()

#### monitoring site table ----
gage_do_wqx <- all_wqx_do_data_clean |> 
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
wq_processed_data |> pins::pin_write(do_wqx,
                                     type = "csv",
                                     title = "do_processed_data_usgs")

# gage data 
wq_processed_data |> pins::pin_write(gage_do_wqx,
                                     type = "csv",
                                     title = "gage_processed_data")
