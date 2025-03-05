library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

# the goal of this script is to pull pH data from different sources and save into aws bucket. Pulling last 10 years data

# Define aws bucket (klamath-sdm)
wq_data_raw <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1", prefix = "water_quality/data-raw/")


### WQX data pull -----
#### ph data pull----
huc_code <- "180102" # huc code for Klamath basin

# DO data
wqx_ph_data <- readWQPdata(huc = huc_code,                       
                           characteristicName = "pH",
                           startDateLo = "2014-01-01",               
                           startDateHi = "2025-01-01") 


##### save raw data into aws bucket water-quality/data-raw/
### WQX
# pH data
wq_data_raw |> pins::pin_write(wqx_ph_data,
                               type = "csv",
                               title = "wqx_ph")
