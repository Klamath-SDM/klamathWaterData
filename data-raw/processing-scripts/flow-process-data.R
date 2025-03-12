library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

#notes and questions: 
#	WQX There is one site that does not seem to be located on a stream “QVIR-SRES (Shackleford at Reservation)”. Waterbody_name function did not work 
#	USGS some flow sites are in canals. Do we want to keep them?
# raw data will be pulled from S3 bucket. These data is originally retrieved on flow-data-pull.R

# setting up aws bucket
wq_data_board <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1")


source(here::here('data-raw', 'processing-scripts', 'utils.R'))


### WQX ----
# pulling raw data
# FLOW data
wqx_data_raw <- wq_data_board |> 
  pins::pin_read("water_quality/data-raw/wqx_flow_data") |> 
  janitor::clean_names() |> 
  glimpse()

# GAGE data
wqx_gage_raw <- wq_data_board |> 
  pins::pin_read("water_quality/data-raw/wqx_gage_data") |> 
  janitor::clean_names() |> 
  glimpse()

# JOIN - station data with flow data
all_wqx_flow_data <- wqx_data_raw |> left_join(wqx_gage_raw) |> 
  glimpse()


#cleaning data
all_wqx_flow_data <- all_wqx_flow_data |> 
  mutate(waterbody_name = extract_waterbody(monitoring_location_name),
         waterbody_name = str_to_title(waterbody_name)) # testing function

# check for naming assigned 
all_wqx_flow_data |> 
  select(waterbody_name, monitoring_location_name, monitoring_location_identifier) |> 
  distinct() |> 
  view()

# check
missing_names_wqx <- all_wqx_flow_data |>
  filter(is.na(waterbody_name)) |> 
  view()

table(missing_names_wqx$monitoring_location_name) # only 2 names that did not catch on function. This a source for checking those names https://www.waterqualitydata.us/provider/STORET/QVIR/

# fixing names that did not get transformed with the function
all_wqx_flow_data_clean <- all_wqx_flow_data |> 
mutate(waterbody_name = case_when(
  monitoring_location_name == "Townsends Gulch" ~ "Scott River",
  TRUE ~ waterbody_name))

# QVIR-SRES (Shackleford at Reservation) does not seem to be located on a stream (https://www.google.com/maps/place/41%C2%B021'13.0%22N+122%C2%B034'58.8%22W/@41.3542763,-122.587643,2087m/data=!3m1!1e3!4m4!3m3!8m2!3d41.3536!4d-122.583?authuser=0&entry=ttu&g_ep=EgoyMDI1MDIyNi4xIKXMDSoASAFQAw%3D%3D)
all_wqx_flow_data_clean |> 
  select(waterbody_name, monitoring_location_name, monitoring_location_identifier) |> 
  distinct() |> 
  view()

#### Flow data table ----
flow_wqx <- all_wqx_flow_data_clean |> 
  mutate(gage_id = monitoring_location_identifier,
         gage_name = monitoring_location_name,
         variable_name = characteristic_name,
         value = result_measure_value,
         unit = result_measure_measure_unit_code,
         statistic = "mean",
         date = activity_start_date) |> 
  select(waterbody_name, gage_name, gage_id, variable_name, value, unit, statistic, date) |> 
  glimpse()

#### monitoring site table ----
wqx_gage_raw <- wq_data_board |> 
  pins::pin_read("water_quality/data-raw/wqx_gage_data") |> 
  janitor::clean_names() |> 
  rename(gage_id = monitoring_location_identifier) |> 
  glimpse()

gage_flow_wqx <- flow_wqx |> left_join(wqx_gage_raw, by = "gage_id") |> 
  mutate(gage_name = monitoring_location_name,
         agency = organization_formal_name,
         latitude = latitude_measure,
         longitude = longitude_measure,
         river_mile = NA,
         huc8 = huc_eight_digit_code,
         stream = waterbody_name) |> 
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |> 
  distinct() |>
  glimpse()

#### saves clean data to aws ----
# open processed-data folder
wq_processed_data <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1", prefix = "water_quality/processed-data/")

# save data
# monitoring data - flow
wq_processed_data |> pins::pin_write(flow_wqx,
                                     type = "csv",
                                     title = "flow_processed_data_wqx")
# gage data - flow
wq_processed_data |> pins::pin_write(gage_flow_wqx,
                                     type = "csv",
                                     title = "gage_flow_processed_data_wqx")





### USGS ----
# pulling raw data
# FLOW data
usgs_data_raw <- wq_data_board |> 
  pins::pin_read("water_quality/data-raw/usgs_flow_data") |> 
  janitor::clean_names() |>
  glimpse()

usgs_data_raw_clean <- usgs_data_raw |> 
  mutate(gage_id = site_no,
         date = as.Date(date),
         variable_name = "flow",
         value = x_00060_00003,
         unit = "cfs",
         statistic = "mean") |>
  select(date, agency_cd, gage_id, variable_name, value, unit, site_no, statistic)

# since stream names are in the gage data, we are pulling in it in and binding 
usgs_gage_raw <- wq_data_board |>
  pins::pin_read("water_quality/data-raw/usgs_gage_flow_data") |>  #pulling gage data
  janitor::clean_names() |>
  # select(site_no, station_nm) |>
  glimpse()


#### water data table ----
flow_processed_data_usgs <- usgs_data_raw_clean |> left_join(usgs_gage_raw, by = "site_no") |> 
  mutate(waterbody_name = extract_waterbody(station_nm)) |> # function
  mutate(waterbody_name = tools::toTitleCase(tolower(waterbody_name)),
         gage_name = station_nm) |>
  glimpse()

flow_processed_data_usgs |>  #checking function
  select(gage_name, waterbody_name) |> distinct() |> view() 

# fixing names
flow_processed_data_usgs_clean <- flow_processed_data_usgs |> 
  mutate(waterbody_name = case_when(gage_name %in% c("INDIAN C NR DOUGLAS CITY CA", "INDIAN C NR HAPPY CAMP CA") ~ "Indian Creek",
                                    T ~ waterbody_name)) |> 
  glimpse()

flow_usgs <- flow_processed_data_usgs_clean |> 
  select(waterbody_name, gage_name, gage_id, variable_name, value, unit, statistic, date) |>
  glimpse()

flow_processed_data_usgs_clean |>  #check
  select(gage_name, waterbody_name) |> distinct() |> view() 

flow_usgs <- flow_processed_data_usgs_clean |> 
  mutate(gage_id = site_no,
         gage_name = station_nm,
         stream = waterbody_name) |> 
  select(stream, gage_name, gage_id, variable_name, value, unit, statistic, date) |> 
  glimpse()

#### monitoring site table ----
gage_flow_usgs <- flow_processed_data_usgs_clean |> 
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
  glimpse()




# save data
wq_processed_data |> pins::pin_write(flow_usgs,
                                     type = "csv",
                                     title = "flow_processed_data_usgs")

wq_processed_data |> pins::pin_write(gage_flow_usgs,
                                     type = "csv",
                                     title = "gage_flow_processed_data_usgs")

