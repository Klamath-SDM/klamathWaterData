library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)

# the goal of this script is to pull temperature data from different sources and save into aws bucket 

# Define aws bucket (klamath-sdm)


### WQX data pull -----
wq_data_raw <- pins::board_s3(
  bucket = "klamath-sdm",
  access_key = Sys.getenv("aws_access_key_id"),
  secret_access_key = Sys.getenv("aws_secret_access_key"),
  session_token = Sys.getenv("aws_session_token"),
  region = "us-east-1",
  prefix = "water_quality/data-raw/")

## Pulling last 10 years of temp data - Filtering to monitoring location types: River/Stream, Lake, Stream, "Lake, Reservoir, Impoundment", Reservoir, spring, estuary
huc_code <- "180102" # huc code for Klamath basin

wqx_temp_data <- readWQPdata(huc = huc_code,                       
                         characteristicName = "Temperature, water",
                         startDateLo = "2014-01-01",               
                         startDateHi = Sys.Date()) |> 
  janitor::clean_names() 

station_metadata <- whatWQPsites(huc = huc_code) |> 
  janitor::clean_names() 

# join station data with temp data
wqx_temp <- wqx_temp_data |> left_join(station_metadata) |> 
  glimpse()


### USGS data pull ---- TODO create a loop to pull from all gages of interest

# klamath_fl <- dataRetrieval::readNWISdv(11507500, "00010", statCd = c("00001", "00002", "00003")) 
# site_info <- readNWISsite("11507500")




# save raw data into aws bucket water-quality/data-raw/

wq_data_raw |> pins::pin_write(wqx_temp,
                               type = "csv",
                               title = "wqx_temperature")
