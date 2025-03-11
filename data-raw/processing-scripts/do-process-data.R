library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

#notes and questions: 
# for waterbody_names that contain some language like "northfork, southfork, etc" 
# (for example: South Fork Sprague River, South Fork Sprague River, South Russian Creek) do we want to keep names like that or unify to just main stream name?

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
         waterbody_name = str_to_title(waterbody_name)) # testing function

# check for naming assigned 
all_wqx_do_data |> 
  select(waterbody_name, monitoring_location_name, monitoring_location_identifier) |> 
  distinct() |> 
  view()

# check
missing_names_wqx <- all_wqx_do_data |>
  filter(is.na(waterbody_name)) |> 
  view()

table(missing_names_wqx$monitoring_location_name)
