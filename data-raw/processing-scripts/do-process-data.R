library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

#notes and questions: 
# wqx - there are 4 NPS locations that dont seem to be at a stream. They are comment out below 
# USGS - there are two sites at "Klamath Straits, leavinf waterbody_name as NA for now till we decide if we want to keep them
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
         date = as.Date(activity_start_date),
         stream = waterbody_name) |> 
  select(stream, gage_name, gage_id, variable_name, value, unit, statistic, date) |> 
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

### USGS ----

# pulling raw data
# DO data
usgs_data_raw <- wq_data_board |> 
  pins::pin_read("water_quality/data-raw/usgs_do_data") |> 
  janitor::clean_names() |>
  glimpse()

# checking units
parameter_info <- readNWISpCode("00300")
print(parameter_info)

# cleaing data
usgs_data_raw_clean <- usgs_data_raw |> 
  mutate(date = as.Date(date),
         max_do = x_00300_00001,
         min_do = x_00300_00002,
         mean_do = x_00300_00003) |>
  select(-c(x_00300_00001, x_00300_00001_cd, x_00300_00002, x_00300_00002_cd, x_00300_00003, x_00300_00003_cd, date_time, tz_cd)) |>
  pivot_longer(cols = c(max_do, min_do, mean_do),
               names_to = "statistic",
               values_to = "value",
               values_drop_na = TRUE) |> 
  mutate(statistic = case_when(
    statistic == "max_do" ~ "maximum",
    statistic == "min_do" ~ "minimum",
    statistic == "mean_do" ~ "mean"),
    variable_name = "dissolved oxygen",
    unit = "mg/L") |> 
  select(agency_cd, gage_id, date, value, statistic, variable_name, unit, site_no) |> 
  glimpse()

# GAGE data
usgs_gage_raw <- wq_data_board |> 
  pins::pin_read("water_quality/data-raw/usgs_gage_do_data") |> 
  janitor::clean_names() |> 
  mutate(station_nm = tools::toTitleCase(tolower(station_nm))) |> 
  glimpse()

# JOIN - station data with temp data
all_usgs_do_raw <- usgs_data_raw_clean |> left_join(usgs_gage_raw, by = "site_no") |> 
  select(c(agency_cd.x, site_no, date, gage_id, statistic, value, variable_name, 
           unit, station_nm, dec_lat_va, dec_long_va, huc_cd)) |> 
  glimpse()

#cleaning data
all_usgs_do_raw <- all_usgs_do_raw |> 
  mutate(waterbody_name = extract_waterbody(station_nm)) # testing function

all_usgs_do_raw |> 
  select(station_nm, waterbody_name) |> distinct() |> View()

# water_names that did not work with the function
all_usgs_do_raw |> 
  filter(is.na(waterbody_name)) |> 
  select(site_no , station_nm, waterbody_name) |>
  distinct() |> 
  mutate(site_no = as.character(site_no)) |> 
  view()

# fixing names
all_usgs_do_raw_clean <- all_usgs_do_raw |> 
  mutate(waterbody_name = case_when(station_nm %in% c("Upper Klamath Lake at Howard Bay, or", "Mid-Trench - Lower   -  Mdtl",
                                                      "Mid-Trench - Upper   - Mdtu", "Mid-North - Lower  - Mdnl", 
                                                      "Mid-North - Upper  - Mdnu", "Rattlesnake Point  -  Rpt", 
                                                      "Upper Klamath Lake - Rattlesnake Point Fish Cage", 
                                                      "Upper Klamath Lake - Mid-North Fish Cage - Mdnfc", "Fish Banks West - Fbw") ~ "Upper Klamath Lake",
                                    station_nm == "Shoalwater Bay - Shb" ~ "Shoalwater Bay",
                                    T ~ waterbody_name)) |> 
  glimpse()

all_usgs_do_raw_clean |> 
  select(station_nm, waterbody_name) |> distinct() |> View()

#### water data table ----
do_usgs <- all_usgs_do_raw_clean |> 
  mutate(gage_id = site_no,
         gage_name = station_nm,
         stream = waterbody_name) |> 
  select(stream, gage_name, gage_id, variable_name, value, unit, statistic, date) |> 
  glimpse()

#### monitoring site table ----
gage_do_usgs <- all_usgs_do_raw_clean |> 
  mutate(gage_name = station_nm,
         gage_id = site_no,
         agency = agency_cd.x,
         latitude = dec_lat_va,
         longitude = dec_long_va,
         river_mile = NA,
         huc8 = huc_cd,
         stream = waterbody_name) |> 
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |> 
  glimpse()

### saves clean data to aws 

# temp data
wq_processed_data |> pins::pin_write(do_usgs,
                                     type = "csv",
                                     title = "do_processed_data_usgs")

# gage data 
wq_processed_data |> pins::pin_write(gage_do_usgs,
                                     type = "csv",
                                     title = "do_gage_processed_data")
