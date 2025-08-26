library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

# the goal of this script is to pull Lake water surface elevation data from different sources and save into aws bucket. Pulling last 10 years of data

# Define aws bucket (klamath-sdm)
wq_data_raw <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1", prefix = "water_quality/data-raw/")

#### pulling usgs lake water surface data
ukl_levels_1 <- dataRetrieval::readNWISdv(11505900, parameterCd = "72275", startDate = "2014-01-01")

ukl_levels_2 <- dataRetrieval::readNWISdv(11504300, parameterCd = "72275", startDate = "2014-01-01")

ukl_levels_3 <- dataRetrieval::readNWISdv(11505800, parameterCd = "72275", startDate = "2014-01-01")

ukl_levels_4 <- dataRetrieval::readNWISdv(11507001, parameterCd = "72275", startDate = "2014-01-01")

water_level_data <- bind_rows(ukl_levels_1, ukl_levels_2, ukl_levels_3, ukl_levels_4)


#### gage data ----
usgs_gages <- c("11505900", "11504300", "11505800", "11507001")


water_level_gage_data <- readNWISsite(usgs_gages)

##### save raw data into aws bucket water-quality/data-raw/

### USGS
# lake surface elevation data
wq_data_raw |> pins::pin_write(water_level_data,
                               type = "csv",
                               title = "water_level_data")
# gage data
wq_data_raw |> pins::pin_write(water_level_gage_data,
                               type = "csv",
                               title = "water_level_gage_data")
