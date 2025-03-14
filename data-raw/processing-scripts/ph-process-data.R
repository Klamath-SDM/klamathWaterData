library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)
library(rivermile)
library(sf)

#notes and questions: 
# WQX - There is one site that does not seem to be located on a stream “QVIR-SRES (Shackleford at Reservation)”. Waterbody_name function did not work 
# OREGONDEQ data entries taht did not work for waterbody_name are located on a weird spot
# USBR_WQX are on a Prairie Canal

# USGS dies not have mean pH data. For now we just have max and min
# USGS - there are two sites at "Klamath Straits, leavinh waterbody_name as NA for now till we decide if we want to keep them

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
  janitor::clean_names() |> 
  filter(monitoring_location_type_name %in% c("River/Stream", "Lake", "Stream",
                                              "Reservoir", "Lake, Reservoir, Impoundment",
                                              "Spring", "Estuary")) |>
  glimpse()

# JOIN - station data with pH data
all_wqx_ph_data <- wqx_data_raw |> left_join(wqx_gage_raw, 
                             by = c("monitoring_location_identifier", "organization_formal_name", "organization_identifier")) |> 
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

wqx_ph_data <- all_wqx_ph_data |> 
  filter(!str_detect(monitoring_location_identifier, "^USGS"), # Keep NAs & remove "USGS"
         (is.na(activity_media_subdivision_name) | activity_media_subdivision_name == "Surface Water" )) |> 
  glimpse()
  
all_wqx_ph_data_clean <- wqx_ph_data |> 
mutate(waterbody_name = case_when(
  monitoring_location_name == "Townsends Gulch" ~ "Scott River",
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
  str_detect(monitoring_location_name, "UPPER KLAMATH LAKE") ~ "Upper Klamath Lake", 
  monitoring_location_identifier %in% c("KLAMATHTRIBES_WQX-KL0010", "KLAMATHTRIBES_WQX-KL0011") ~ "Agency Lake",
    TRUE ~ waterbody_name)) |> 
    glimpse()
  #TODO continue to clean locations that do not have explicit name
# resoruce: https://www.waterqualitydata.us/provider/STORET/

all_wqx_ph_data_clean |>  # check
  select(waterbody_name, monitoring_location_name, monitoring_location_identifier) |> 
  distinct() |>  #TODO figure out why we still have well data
  view()

#### water data table ----
ph_wqx <- all_wqx_ph_data_clean |> 
  mutate(gage_id = monitoring_location_identifier,
         gage_name = monitoring_location_name,
         variable_name = characteristic_name,
         value = result_measure_value,
         unit = result_measure_measure_unit_code,
         statistic = statistical_base_code, # check if we want to add this manually
         date = activity_start_date,
         stream = waterbody_name) |> 
  select(stream, gage_name, gage_id, variable_name, value, unit, statistic, date) |> 
  glimpse()


#### monitoring site table ----
gage_ph_wqx_clean <- all_wqx_ph_data_clean |> 
  mutate(gage_name = monitoring_location_name,
         gage_id = monitoring_location_identifier,
         agency = organization_formal_name,
         latitude = latitude_measure,
         longitude = longitude_measure,
         river_mile = NA, #10784
         huc8 = huc_eight_digit_code,
         stream = waterbody_name) |> 
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |>
  distinct() |> 
  gage_data_format(filter_streams = FALSE) |> glimpse()

gage_ph_wqx <- rivermile::find_nearest_river_miles(gage_ph_wqx_clean) |> 
  mutate(longitude = st_coordinates(gage_ph_wqx_clean)[, 1],
    latitude = st_coordinates(gage_ph_wqx_clean)[, 2]) |> 
  st_drop_geometry() |> 
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |> 
  glimpse()

#### saves clean data to aws ----
wq_processed_data <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1", prefix = "water_quality/processed-data/")

# pH data
wq_processed_data |> pins::pin_write(ph_wqx,
                                     type = "csv",
                                     title = "ph_processed_data_usgs")

# gage data 
wq_processed_data |> pins::pin_write(gage_ph_wqx,
                                     type = "csv",
                                     title = "gage_ph_processed_data")


### USGS ----
# pulling raw data
# pH data
usgs_data_raw <- wq_data_board |> 
  pins::pin_read("water_quality/data-raw/usgs_ph_data") |> 
  janitor::clean_names() |>
  glimpse()

usgs_data_raw_clean <- usgs_data_raw |> 
  mutate(gage_id = site_no,
         date = as.Date(date),
         max_ph = x_00400_00001 ,
         min_ph = x_00400_00002,
         # mean_ph = x_00010_00003 # no mean available
         ) |> 
  select(-c(x_00400_00001 , x_00400_00001_cd, x_00400_00002, x_00400_00002_cd, date_time, tz_cd)) |>
  pivot_longer(cols = c(max_ph, min_ph),
               names_to = "statistic",
               values_to = "value",
               values_drop_na = TRUE) |> 
  mutate(statistic = case_when(
    statistic == "max_ph" ~ "maximum",
    statistic == "min_ph" ~ "minimum",
    # statistic == "mean_temp" ~ "mean"
    ),
    variable_name = "pH",
    unit = "std unit") |> # pH standard unit
  select(agency_cd, gage_id, date, value, statistic, variable_name, unit, site_no) |> 
  glimpse()


# GAGE data
usgs_gage_raw <- wq_data_board |> 
  pins::pin_read("water_quality/data-raw/usgs_gage_ph_data") |> 
  janitor::clean_names() |> 
  mutate(station_nm = tools::toTitleCase(tolower(station_nm))) |> 
  glimpse()

# JOIN - station data with temp data
all_usgs_ph_data_raw <- usgs_data_raw_clean |> left_join(usgs_gage_raw, by = "site_no") |> 
  select(c(agency_cd.x, site_no, date, gage_id, statistic, value, variable_name, 
           unit, station_nm, dec_lat_va, dec_long_va, huc_cd)) |> 
  glimpse()

#cleaning data
all_usgs_ph_data_raw <- all_usgs_ph_data_raw |> 
  mutate(waterbody_name = extract_waterbody(station_nm)) # testing function

all_usgs_ph_data_raw |> 
  select(station_nm, waterbody_name) |> distinct() |> View()

all_usgs_ph_data_raw <- all_usgs_ph_data_raw |> 
mutate(waterbody_name = case_when(station_nm %in% c("Upper Klamath Lake at Howard Bay, or", "Mid-Trench - Lower   -  Mdtl",
                                                    "Mid-Trench - Upper   - Mdtu", "Mid-North - Lower  - Mdnl", 
                                                    "Mid-North - Upper  - Mdnu", "Rattlesnake Point  -  Rpt",
                                                    "Fish Banks West - Fbw") ~ "Upper Klamath Lake",
                                  station_nm == "Shoalwater Bay - Shb" ~ "Shoalwater Bay",
                                  T ~ waterbody_name)) |> 
  glimpse()

#### water data table ----
ph_usgs <- all_usgs_ph_data_raw |> 
  mutate(gage_id = site_no,
         gage_name = station_nm) |> 
  select(waterbody_name, gage_name, gage_id, variable_name, value, unit, statistic, date) |> 
  glimpse()

#### monitoring site table ----
gage_ph_usgs_clean <- all_usgs_ph_data_raw |> 
  mutate(gage_name = station_nm,
         gage_id = site_no,
         agency = agency_cd.x,
         latitude = dec_lat_va,
         longitude = dec_long_va,
         river_mile = NA,
         huc8 = huc_cd,
         stream = waterbody_name) |> 
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |> 
  distinct() |> 
  gage_data_format(filter_streams = FALSE) |> 
  glimpse()

gage_ph_usgs <- rivermile::find_nearest_river_miles(gage_ph_usgs_clean) |>
  mutate(longitude = st_coordinates(gage_ph_usgs_clean)[, 1],
         latitude = st_coordinates(gage_ph_usgs_clean)[, 2]) |>
  st_drop_geometry() |>
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |> 
  glimpse()


### saves clean data to aws 

# temp data
wq_processed_data |> pins::pin_write(ph_usgs,
                                     type = "csv",
                                     title = "ph_processed_data_usgs")

# gage data 
wq_processed_data |> pins::pin_write(gage_ph_usgs,
                                     type = "csv",
                                     title = "ph_gage_processed_data")
