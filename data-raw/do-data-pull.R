library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

# the goal of this script is to pull dissolved oxygen data from different sources and save into aws bucket. Pulling last 10 years of data

# Define aws bucket (klamath-sdm)
wq_data_raw <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1", prefix = "water_quality/data-raw/")


### WQX data pull -----
#### do data pull----
huc_code <- "180102" # huc code for Klamath basin

# DO data
wqx_do_data <- readWQPdata(huc = huc_code,                       
                             characteristicName = "Dissolved oxygen (DO)",
                             startDateLo = "2014-01-01",               
                             startDateHi = "2025-01-01") 

# gage data has already been pulled in temp data pull script

### USGS data pull -----
# Define the parameters
start_date <- "2014-01-01"
parameterCd <- "00300" # DO parameter code

#TODO figure out what gages we want to pull data from

##### save raw data into aws bucket water-quality/data-raw/
### WQX
# do data
wq_data_raw |> pins::pin_write(wqx_do_data,
                               type = "csv",
                               title = "wqx_do")

### USGS 
# do data


# wq_data_raw |> pins::pin_write(usgs_do_data,
#                                type = "csv",
#                                title = "usgs_do")
# # gage do data
# wq_data_raw |> pins::pin_write(usgs_gage_do_data,
#                                type = "csv",
#                                title = "usgs_gage_do")

