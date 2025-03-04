library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

# the goal of this script is to pull flow data from different sources and save into aws bucket. Pulling last 10 years of flow data

# Define aws bucket (klamath-sdm)


### WQX data pull -----
# raw flow data
wq_data_raw <- pins::board_s3(
  bucket = "klamath-sdm",
  access_key = Sys.getenv("aws_access_key_id"),
  secret_access_key = Sys.getenv("aws_secret_access_key"),
  session_token = Sys.getenv("aws_session_token"),
  region = "us-east-1",
  prefix = "water_quality/data-raw/")

huc_code <- "180102" # huc code for Klamath basin

#### flow data pull----
wqx_flow_data <- readWQPdata(huc = huc_code,                       
                         characteristicName = "Flow",
                         startDateLo = "2014-01-01",               
                         startDateHi = "2025-01-01") 
# gage data
# wqx_gage_data <- whatWQPsites(huc = huc_code) 


### USGS data pull -----

#### flow data pull----
usgs_gages <- c("11509500", "11510700", "11516530", "11520500", "11523000", "11530500", "11528700", "11530000", "11523200",
                "11525500", "11525655", "11525854", "11526250", "11526400", "11527000",
                "11519500", "11517000", "11517500", "11522500", "11501000", "11525670", "11521500", "11507500", "11502500",
                "11509340", "11509250", "11509105", "11504260", "11504290")

# Define the parameters
start_date <- "2014-01-01"
parameterCd <- "00060" # Flow parameter code
statCd <- "00003"       # Mean flow only

all_flow_data <- list()

for (gage in usgs_gages) {
  message(paste("Pulling data for gage:", gage))
  try({
    flow_data <- readNWISdv(
      siteNumbers = gage, 
      parameterCd = parameterCd, 
      statCd = statCd,  
      startDate = start_date) 
    
  
    all_flow_data[[gage]] <- flow_data
  }, silent = TRUE)
}

# Combine all gage data into one dataframe
usgs_flow_data <- bind_rows(all_flow_data)

usgs_flow_data <- usgs_flow_data |> 
  janitor::clean_names() |> 
  glimpse()


#### gage data pull----
# it has already been pulled on temperature data-pull and it has been stored on "klamath-sdm" bucket water_quality/data-raw/usgs_gage_data
# however it was specific to those gages that had temp data. We might want to check if we want to pull all klamath basin gages
# or if we pull in gage data specific to the parameter
huc_code <- "180102"
usgs_gage_data <- whatNWISsites(huc = "18010201")


##### save raw data into aws bucket water-quality/data-raw/
                             
### USGS 
# flow data
wq_data_raw |> pins::pin_write(usgs_flow_data,
                               type = "csv",
                               title = "usgs_flow")
### WQX
# flow data
wq_data_raw |> pins::pin_write(wqx_flow_data,
                               type = "csv",
                               title = "wqx_flow")
