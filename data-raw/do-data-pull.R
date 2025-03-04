library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

# the goal of this script is to pull dissolved oxygen data from different sources and save into aws bucket. Pulling last 10 years of temp data

# Define aws bucket (klamath-sdm)
wq_data_raw <- pins::board_s3(
  bucket = "klamath-sdm",
  access_key = Sys.getenv("aws_access_key_id"),
  secret_access_key = Sys.getenv("aws_secret_access_key"),
  session_token = Sys.getenv("aws_session_token"),
  region = "us-east-1",
  prefix = "water_quality/data-raw/")


### WQX data pull -----
#### do data pull----
huc_code <- "180102" # huc code for Klamath basin

# DO data
wqx_do_data <- readWQPdata(huc = huc_code,                       
                             characteristicName = "Dissolved oxygen",
                             startDateLo = "2014-01-01",               
                             startDateHi = "2025-01-01") 
# gage data
# wqx_gage_data <- whatWQPsites(huc = huc_code) - already done at temp-data pull


### USGS data pull -----



# save do data to aws
