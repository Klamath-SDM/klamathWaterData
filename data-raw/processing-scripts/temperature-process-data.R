library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)
library(rivermile)
library(sf)

# raw data will be pulled from S3 bucket. These data is originally retrieved on temperature-data-pull.R

# setting up aws bucket
wq_data_board <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1")

source(here::here('data-raw', 'processing-scripts', 'utils.R'))


### WQX ----
# pulling raw data
# TEMPERATURE data
wqx_data_raw <- wq_data_board |> 
  pins::pin_read("water_quality/data-raw/wqx_temp_data") |> 
  janitor::clean_names() |> 
  filter(statistical_base_code %in% c("Mean", "Maximum", "Minimum")) |>  # filtering to stats of interest
  glimpse()


# GAGE data
wqx_gage_raw <- wq_data_board |> 
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
missing_names_wqx <- all_wqx_temp_data |>
  filter(is.na(waterbody_name))

table(missing_names_wqx$monitoring_location_name) # only 8 names that did not catch on function. This a source for checking those names https://www.waterqualitydata.us/provider/STORET/HVTEPA_WQX/
 #test comparing original vs new names to aviod wrong designation (when two rivers/streams are mentioned on the name)

# check for naming assigned 
all_wqx_temp_data |> 
  select(waterbody_name, monitoring_location_name, monitoring_location_identifier) |> 
  distinct() |> 
  view()

# fix "HOBO at Confluence of Klamath and Trinity Rivers" - this is on Klamath River
# fixing stream names manually
all_wqx_temp_data_clean <- all_wqx_temp_data |> 
  mutate(waterbody_name = case_when(
    monitoring_location_name %in% c("HOBO at Confluence of Klamath and Trinity Rivers", "CDR and Nutrients at Saints Rest Bar") ~ "Klamath River",
    monitoring_location_name %in% c("CDR at Red Rock", "CDR at South Boundary", 
                                    "HOBO  A at TR_NORTON", "HOBO at North Boundary", 
                                    "HOBO at South Boundary", "HOBO B  at TR_NORTON") ~ "Trinity River",
    monitoring_location_identifier == "323-02-I|Paradise|R6|Fremont-Winema|Paisley" ~ "Paradise Creek",
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

all_wqx_temp_data_clean |> 
  select(waterbody_name, monitoring_location_name, monitoring_location_identifier, provider_name, organization_identifier) |>
  distinct() |>
  view()


  #### water data table ----
temperature_wqx <- all_wqx_temp_data_clean |> 
  mutate(gage_id = monitoring_location_identifier,
         gage_name = monitoring_location_name,
         variable_name = characteristic_name,
         value = result_measure_value,
         unit = result_measure_measure_unit_code,
         statistic = statistical_base_code,
         date = activity_start_date,
         stream = waterbody_name) |> 
  select(stream, gage_name, gage_id, variable_name, value, unit, statistic, date) |> 
  glimpse()

  #### monitoring site table ----
gage_temperature_wqx_clean <- all_wqx_temp_data_clean |> 
  mutate(gage_name = monitoring_location_name,
         gage_id = monitoring_location_identifier,
         agency = organization_formal_name,
         latitude = latitude_measure,
         longitude = longitude_measure,
         river_mile = NA,
         huc8 = huc_eight_digit_code,
         stream = waterbody_name) |> 
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |> 
  distinct() |>
  gage_data_format(filter_streams = FALSE) |>
  glimpse()

#note that all NPSWRD_WQX gages do not have lat/long so they are getting filtered out

gage_temperature_wqx <- rivermile::find_nearest_river_miles(gage_temperature_wqx_clean) |> 
  mutate(longitude = st_coordinates(gage_temperature_wqx_clean)[, 1],
         latitude = st_coordinates(gage_temperature_wqx_clean)[, 2]) |> 
  st_drop_geometry() |> 
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |> 
  glimpse()

#### saves clean data to aws ----
wq_processed_data <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1", prefix = "water_quality/processed-data/")

# temp data
wq_processed_data |> pins::pin_write(temperature_wqx,
                                     type = "csv",
                                     title = "temperature_processed_data_usgs")

# gage data 
wq_processed_data |> pins::pin_write(gage_temperature_wqx,
                                     type = "csv",
                                     title = "gage_processed_data")


### USGS ----

# pulling raw data
# TEMPERATURE data
usgs_data_raw <- wq_data_board |> 
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
usgs_gage_raw <- wq_data_board |> 
  pins::pin_read("water_quality/data-raw/usgs_temp_gage_data") |> 
  janitor::clean_names() |> 
  mutate(station_nm = tools::toTitleCase(tolower(station_nm))) |> 
  glimpse()
  
# JOIN - station data with temp data
all_usgs_temp_data_raw <- usgs_data_raw_clean |> left_join(usgs_gage_raw, by = "site_no") |> 
  select(c(agency_cd.x, site_no, date, gage_id, statistic, value, variable_name, 
           unit, station_nm, dec_lat_va, dec_long_va, huc_cd)) |> 
  glimpse()

#cleaning data
all_usgs_temp_data_raw <- all_usgs_temp_data_raw |> 
  mutate(waterbody_name = extract_waterbody(station_nm)) # testing function

all_usgs_temp_data_raw |> 
  select(station_nm, waterbody_name) |> distinct() |> View()

unique(all_usgs_temp_data_raw$waterbody_name)

# water_names that did not work with the function
all_usgs_temp_data_raw |> 
  filter(is.na(waterbody_name)) |> 
  select(site_no , station_nm, waterbody_name) |>
  distinct() |> 
  mutate(site_no = as.character(site_no)) |> 
  view()

# fixing names
all_usgs_temp_data_raw_clean <- all_usgs_temp_data_raw |> 
  mutate(waterbody_name = case_when(station_nm %in% c("Upper Klamath Lake at Howard Bay, or", "Mid-Trench - Lower   -  Mdtl",
                                                      "Mid-Trench - Upper   - Mdtu", "Mid-North - Lower  - Mdnl", 
                                                      "Mid-North - Upper  - Mdnu", "Rattlesnake Point  -  Rpt") ~ "Upper Klamath Lake",
                                    station_nm == "Shoalwater Bay - Shb" ~ "Shoalwater Bay",
                                    T ~ waterbody_name)) |> 
           glimpse()

all_usgs_temp_data_raw_clean |> 
  select(site_no , station_nm, waterbody_name) |> # there are two gages remaining that I am on sure on how no name
  distinct() |> 
  view()
         

#### water data table ----
temperature_usgs <- all_usgs_temp_data_raw |> 
  mutate(gage_id = site_no,
         gage_name = station_nm,
         stream = waterbody_name) |> 
  select(stream, gage_name, gage_id, variable_name, value, unit, statistic, date) |> 
  glimpse()

#### monitoring site table ----
gage_temperature_usgs_clean <- all_usgs_temp_data_raw |> 
  mutate(gage_name = station_nm,
         gage_id = site_no,
         agency = agency_cd.x,
         latitude = dec_lat_va,
         longitude = dec_long_va,
         river_mile = NA,
         huc8 = huc_cd,
         stream = waterbody_name
         ) |> 
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |> 
  distinct() |> 
  gage_data_format(filter_streams = FALSE) |>
  glimpse()

gage_temperature_usgs <- rivermile::find_nearest_river_miles(gage_temperature_usgs_clean) |> 
  mutate(longitude = st_coordinates(gage_temperature_usgs_clean)[, 1],
         latitude = st_coordinates(gage_temperature_usgs_clean)[, 2]) |> 
  st_drop_geometry() |> 
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |> 
  glimpse()

### saves clean data to aws 

# temp data
wq_processed_data |> pins::pin_write(temperature_usgs,
                               type = "csv",
                               title = "temperature_processed_data_usgs")

# gage data 
wq_processed_data |> pins::pin_write(gage_temperature_usgs,
                                     type = "csv",
                                     title = "temperature_gage_processed_data")
