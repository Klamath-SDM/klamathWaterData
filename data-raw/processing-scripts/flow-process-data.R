library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

# raw data will be pulled from S3 bucket. These data is originally retrieved on temperature-data-pull.R

# setting up aws bucket
wq_data_board <- pins::board_s3(
  bucket = "klamath-sdm",
  access_key = Sys.getenv("aws_access_key_id"),
  secret_access_key = Sys.getenv("aws_secret_access_key"),
  session_token = Sys.getenv("aws_session_token"),
  region = "us-east-1")

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

#### water data table ----
flow_processed_data_wqx <- all_wqx_flow_data_clean |> 
  mutate(gage_id = monitoring_location_identifier,
         gage_name = monitoring_location_name,
         variable_name = characteristic_name,
         value = result_measure_value,
         unit = result_measure_measure_unit_code,
         statistic = "mean",
         date = activity_start_date) |> 
  select(waterbody_name, gage_name, gage_id, variable_name, value, unit, statistic, date) |> 
  glimpse()

#### saves clean data to aws ----

# call right folder in the bucket
wq_processed_data<- pins::board_s3(
  bucket = "klamath-sdm",
  access_key = Sys.getenv("aws_access_key_id"),
  secret_access_key = Sys.getenv("aws_secret_access_key"),
  session_token = Sys.getenv("aws_session_token"),
  region = "us-east-1",
  prefix = "water_quality/processed-data/")
# save data
wq_processed_data |> pins::pin_write(flow_processed_data_wqx,
                                     type = "csv",
                                     title = "flow_processed_data_wqx")


### USGS ----
# pulling raw data
# FLOW data
usgs_data_raw <- wq_data_board |> 
  pins::pin_read("water_quality/data-raw/usgs_flow_data") |> 
  janitor::clean_names() |>
  glimpse()
