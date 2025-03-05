library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)
library(paws)

# the goal of this script is to pull temperature data from different sources and save into aws bucket. Pulling last 10 years of temp data

# Define aws bucket (klamath-sdm)


### WQX data pull -----
# raw temperature data in aws bucket
wq_data_raw <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1", prefix = "water_quality/data-raw/")

huc_code <- "180102" # huc code for Klamath basin

#### temperature data ----
wqx_temp_data <- readWQPdata(huc = huc_code,                       
                         characteristicName = "Temperature, water",
                         startDateLo = "2014-01-01",               
                         startDateHi = "2025-01-01") 
####  gage data ----
wqx_gage_data <- whatWQPsites(huc = huc_code)  # this gage data pull can serve other parameters since it covers all sites with this huc code (Klamath basin)



### USGS data pull -----

#### temperature data ----
usgs_gages <- c(
  "11507500", "11510700", "11530500", "11523000", "11509500", "11509370", 
  "420741121554001", "420451121510000", "420448121503100", "420853121505500", 
  "420853121505501", "11526400", "11530000", "422042121513100", 
  "421935121551200", "422305121553800", "422305121553803", 
  "422444121580400", "422622122004000", "422622122004003", 
  "422719121571400", "11504290", "420037121334100", "420036121333700", 
  "420833121402000", "421010121271200", "421015121471800", 
  "415954121312100", "11501000", "11502500", "11504115", 
  "11511990", "11507501", "421401121480900", "11491470", 
  "11491450", "11492550")

# Define the parameters
start_date <- "2014-01-01"
parameter_code <- "00010"  # Temperature parameter code
stat_codes <- c("00001", "00002", "00003")  # Min, Max, Mean code

# empty list to store dataframes
all_data <- list()

# Loop through each gage and pull the data
for (gage in usgs_gages) {
  message(paste("Pulling data for gage:", gage))
  try({
    temp_data <- readNWISdv(
      siteNumbers = gage, 
      parameterCd = parameter_code, 
      statCd = stat_codes, 
      startDate = start_date
    ) 
    
    temp_data <- temp_data |> 
      mutate(gage_id = gage)
  
    all_data[[gage]] <- temp_data
  }, silent = TRUE)
}

# Combine all gage data into one dataframe
usgs_temp_data <- bind_rows(all_data)

#### gage data ----
usgs_temp_gage_data <- readNWISsite(usgs_gages)

##### save raw data into aws bucket water-quality/data-raw/

### WQX
# temp data
wq_data_raw |> pins::pin_write(wqx_temp_data,
                               type = "csv",
                               title = "wqx_temperature")
# gage data
wq_data_raw |> pins::pin_write(wqx_gage_data,
                               type = "csv",
                               title = "wqx_temperature")
### USGS 
# temp data
wq_data_raw |> pins::pin_write(usgs_temp_data,
                               type = "csv",
                               title = "usgs_temperature")
# gage data
wq_data_raw |> pins::pin_write(usgs_temp_gage_data,
                               type = "csv",
                               title = "usgs_temperature_gage")
