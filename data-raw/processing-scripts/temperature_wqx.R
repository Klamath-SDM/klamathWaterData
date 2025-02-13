library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)


# define AWS data bucket
# note that you need to set up access keys in R environ
klamath_project_board <- pins::board_s3(
  bucket="klamath-sdm",
  access_key=Sys.getenv("aws_access_key_id"),
  secret_access_key=Sys.getenv("secret_access_key_id"),
  session_token = Sys.getenv("session_token_id"),
  region = "us-east-1"
)

## Pulling last 10 years of temp data - Filtering to monitoring location types: River/Stream, Lake, Stream, "Lake, Reservoir, Impoundment", Reservoir, spring, estuary
huc_code <- "180102" # huc code for Klamath basin

temp_data <- readWQPdata(huc = huc_code,                       
                         characteristicName = "Temperature, water",
                         startDateLo = "2014-01-01",               
                         startDateHi = Sys.Date()) |> 
  janitor::clean_names() 

#filtering to min, max, and mean
temp_data <- temp_data |> 
  filter(statistical_base_code %in% c("Mean", "Maximum", "Minimum"))

station_metadata <- whatWQPsites(huc = huc_code, 
                         MonitoringLocationTypeName = "River/Stream", "Lake", "Stream",
                         "Reservoir", "Lake, Reservoir, Impoundment",  "Spring", "Estuary") |> 
  janitor::clean_names() 
  

# join station data with temp data
all_temp_data <- temp_data |> left_join(station_metadata) |> 
  glimpse()

# drafting water quality data (stream, gage_name, variable_name, value, unit, statistic, date)
data_wq <- all_temp_data |> 
  mutate(stream = NA,
         gage_name = monitoring_location_identifier,
         variable_name = characteristic_name,
         value = result_measure_value,
         unit = result_measure_measure_unit_code,
         statistic = statistical_base_code,
         date = activity_start_date) |> 
  select(stream, gage_name, variable_name, value, unit, statistic, date) |> 
  glimpse()

# drafting location data (gage_name, gage_id, agency, latitude, longitude, river_mile, huc_8, stream)
site_data <- all_temp_data |> 
  mutate(gage_name = monitoring_location_name,
         gage_id = monitoring_location_identifier,
         agency = organization_identifier,
         latitude = as.numeric(latitude_measure),
         longitude = as.numeric(longitude_measure),
         river_mile = NA,
         huc_8 = NA,
         stream = NA) |> 
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc_8, stream) |> 
  distinct(gage_id, .keep_all = TRUE) |> 
  glimpse()
  


# save to s3 storage
# temp data
# klamath_project_board |> pins::pin_write(data_wq,
#                                          name = "water_quality/temperature",
#                                          type = "csv",
#                                          title = "wqx_temperature_data")

# temp location data
# klamath_project_board |> pins::pin_write(site_data,
#                                          name = "water_quality/wqx/temperature",
#                                          type = "csv",
#                                          title = "wqx_temperature_location_data")