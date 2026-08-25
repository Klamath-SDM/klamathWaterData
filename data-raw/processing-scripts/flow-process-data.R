library(tidyverse)
library(dataRetrieval)
library(purrr)
library(pins)
library(rivermile)
library(sf)

#notes and questions:
#	WQX There is one site that does not seem to be located on a stream “QVIR-SRES (Shackleford at Reservation)”. Waterbody_name function did not work
#	USGS some flow sites are in canals. Do we want to keep them?
# raw data will be pulled from S3 bucket. These data is originally retrieved on flow-data-pull.R

# setting up aws bucket
# wq_data_board <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1")
source("data-raw/data-pull/flow-data-pull.R")

#source(here::here('data-raw', 'processing-scripts', 'utils.R'))


### WQX ----
# pulling raw data
# FLOW data
# wqx_data_raw <- wq_data_board |>
#   pins::pin_read("water_quality/data-raw/wqx_flow_data") |>
#   janitor::clean_names() |>
#   glimpse()

wqx_data_raw <- wqx_flow_data |>
  janitor::clean_names() |>
  glimpse()


# GAGE data
# wqx_gage_raw <- wq_data_board |>
#   pins::pin_read("water_quality/data-raw/wqx_gage_data") |>
#   janitor::clean_names() |>
#
#   mutate(gage_id = monitoring_location_identifier) |>
#   glimpse()

wqx_gage_raw <- wqx_gage_data |>
  janitor::clean_names() |>
  mutate(gage_id = monitoring_location_identifier) |>
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
  distinct()

# check
missing_names_wqx <- all_wqx_flow_data |>
  filter(is.na(waterbody_name))

table(missing_names_wqx$monitoring_location_name) # only 2 names that did not catch on function. This a source for checking those names https://www.waterqualitydata.us/provider/STORET/QVIR/

# fixing names that did not get transformed with the function
all_wqx_flow_data_clean <- all_wqx_flow_data |>
mutate(waterbody_name = case_when(
  monitoring_location_name == "Townsends Gulch" ~ "Scott River",
  TRUE ~ waterbody_name))

# QVIR-SRES (Shackleford at Reservation) does not seem to be located on a stream (https://www.google.com/maps/place/41%C2%B021'13.0%22N+122%C2%B034'58.8%22W/@41.3542763,-122.587643,2087m/data=!3m1!1e3!4m4!3m3!8m2!3d41.3536!4d-122.583?authuser=0&entry=ttu&g_ep=EgoyMDI1MDIyNi4xIKXMDSoASAFQAw%3D%3D)
all_wqx_flow_data_clean |>
  select(waterbody_name, monitoring_location_name, monitoring_location_identifier) |>
  distinct()

#### Flow data table ----
flow_wqx <- all_wqx_flow_data_clean |>
  mutate(gage_id = monitoring_location_identifier,
         gage_name = monitoring_location_name,
         variable_name = tolower(characteristic_name),
         value = result_measure_value,
         unit = result_measure_measure_unit_code,
         statistic = "mean",
         date = activity_start_date,
         stream = waterbody_name) |>
  select(stream, gage_name, gage_id, variable_name, value, unit, statistic, date) |>
  glimpse()

#### monitoring site table ----
# wqx_gage_raw <- wq_data_board |>
#   pins::pin_read("water_quality/data-raw/wqx_gage_data") |>
#   janitor::clean_names() |>
#   rename(gage_id = monitoring_location_identifier) |>
#   glimpse()

wqx_gage_raw <- wqx_gage_data |>
  janitor::clean_names() |>
  rename(gage_id = monitoring_location_identifier)

gage_flow_wqx_clean <- flow_wqx |> left_join(wqx_gage_raw, by = "gage_id") |>
  mutate(gage_name = monitoring_location_name,
         agency = organization_formal_name,
         latitude = latitude_measure,
         longitude = longitude_measure,
         river_mile = NA,
         huc8 = huc_eight_digit_code) |>
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |>
  distinct() |>
  gage_data_format(filter_streams = FALSE) |>
  glimpse()

gage_flow_wqx <- rivermile::find_nearest_river_miles(gage_flow_wqx_clean) |>
  mutate(longitude = st_coordinates(gage_flow_wqx_clean)[, 1],
         latitude = st_coordinates(gage_flow_wqx_clean)[, 2]) |>
  st_drop_geometry() |>
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |>
  glimpse()


#### saves clean data to aws ----
# open processed-data folder
# wq_processed_data <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1", prefix = "water_quality/processed-data/")

# save data
# # monitoring data - flow
# wq_processed_data |> pins::pin_write(flow_wqx,
#                                      type = "csv",
#                                      title = "flow_processed_data_wqx")
# # gage data - flow
# wq_processed_data |> pins::pin_write(gage_flow_wqx,
#                                      type = "csv",
#                                      title = "gage_flow_processed_data_wqx")


### USGS ----
# pulling raw data
# FLOW data
# usgs_data_raw <- wq_data_board |>
#   pins::pin_read("water_quality/data-raw/usgs_flow_data") |>
#   janitor::clean_names() |>
#   glimpse()

usgs_data_raw <- usgs_flow_data |>
  janitor::clean_names() |>
  glimpse()

usgs_data_raw_clean <- usgs_data_raw |>
  mutate(gage_id = site_no,
         date = as.Date(date),
         variable_name = "flow",
         value = x_00060_00003,
         unit = "cfs",
         statistic = "mean") |>
  select(date, agency_cd, gage_id, variable_name, value, unit, site_no, statistic)

# since stream names are in the gage data, we are pulling in it in and binding
# usgs_gage_raw <- wq_data_board |>
#   pins::pin_read("water_quality/data-raw/usgs_gage_flow_data") |>  #pulling gage data
#   janitor::clean_names() |>
#   # select(site_no, station_nm) |>
#   glimpse()

usgs_gage_raw <- usgs_gage_flow_data |>
  janitor::clean_names() |>
  glimpse()


#### water data table ----
flow_processed_data_usgs <- usgs_data_raw_clean |> left_join(usgs_gage_raw, by = "site_no") |>
  mutate(waterbody_name = extract_waterbody(station_nm)) |> # function
  mutate(waterbody_name = tools::toTitleCase(tolower(waterbody_name)),
         gage_name = station_nm) |>
  glimpse()

flow_processed_data_usgs |>  #checking function
  select(gage_name, waterbody_name) |> distinct()

# fixing names
flow_processed_data_usgs_clean <- flow_processed_data_usgs |>
  mutate(waterbody_name = case_when(gage_name %in% c("INDIAN C NR DOUGLAS CITY CA", "INDIAN C NR HAPPY CAMP CA") ~ "Indian Creek",
                                    T ~ waterbody_name)) |>
  glimpse()

flow_usgs <- flow_processed_data_usgs_clean |>
  select(waterbody_name, gage_name, gage_id, variable_name, value, unit, statistic, date) |>
  glimpse()

flow_processed_data_usgs_clean |>  #check
  select(gage_name, waterbody_name) |> distinct()

flow_usgs <- flow_processed_data_usgs_clean |>
  mutate(gage_id = site_no,
         gage_name = station_nm,
         stream = waterbody_name) |>
  select(stream, gage_name, gage_id, variable_name, value, unit, statistic, date) |>
  glimpse()

#### monitoring site table ----
gage_flow_usgs_clean <- flow_processed_data_usgs_clean |>
  mutate(gage_name = station_nm,
         gage_id = as.character(site_no),
         agency = agency_cd.x,
         latitude = dec_lat_va,
         longitude = dec_long_va,
         river_mile = NA,
         huc8 = huc_cd,
         stream = waterbody_name) |>
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |>
  distinct() |>
  gage_data_format(filter_streams = FALSE) |>
  glimpse()

gage_flow_usgs <- rivermile::find_nearest_river_miles(gage_flow_usgs_clean) |>
  mutate(longitude = st_coordinates(gage_flow_usgs_clean)[, 1],
         latitude = st_coordinates(gage_flow_usgs_clean)[, 2]) |>
  st_drop_geometry() |>
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |>
  glimpse()

### USBR ----
usbr_flow_data <- usbr_flow_data |>
  rename(stream = location) |>
  glimpse()

# combine gage and data files ---------------------------------------------

site_with_little_data <- flow_data |>
  group_by(gage_name) |>
  summarise(min_date = min(date),
            max_date = max(date),
            n = n()) |>
  filter(n > 10) |>
  pull(gage_name)

flow_data <- flow_wqx |>
  mutate(date = as.Date(date)) |>
  bind_rows(flow_usgs |>
              mutate(gage_id = as.character(gage_id)), usbr_flow_data,
            usbr_hydromet_flow_data, owrd_flow_data) |>
  mutate(location = tolower(stream)) |>
  relocate(location, .before = gage_name) |>
  select(-stream) |>
  filter(gage_name %in% site_with_little_data) |>
  filter(!is.na(value)) |>
  filter(value != 998877.00 & value >= 0) |>  # this removes outlier in sbr-hrpo
  glimpse()

# USBR Hydromet / OWRD gages missing from flow_gage - see flow-data-pull.R.
# Not run through gage_data_format()/find_nearest_river_miles() (river_mile
# left NA), same treatment as the existing Willow Creek (usbr-wilc) USBR gage.
# USBR lat/long come from rise_klamath_locations (pulled live - see
# flow-data-pull.R); OWRD's two sites have no equivalent live coordinate
# source available, so they stay hand-transcribed here (matches
# teacup-diagram-data-pull.R's own OWRD block). huc8 determined by spatial
# join against rivermile::klamath_hucs (point-in-polygon on lat/long) rather
# than hand-transcribed.
flow_gage_usbr_owrd <- usbr_hydromet_flow_data |>
  bind_rows(owrd_flow_data) |>
  distinct(location, gage_name, gage_id) |>
  mutate(
    agency = if_else(gage_id %in% c("11495600", "11495900"),
                      "Oregon Water Resources Department",
                      "Bureau of Reclamation"),
    site = toupper(str_remove(gage_id, "^usbr-"))) |>
  left_join(rise_klamath_locations, by = "site") |>
  mutate(
    latitude = case_when(
      gage_id == "11495600" ~ 42.42,     gage_id == "11495900" ~ 42.496528,
      .default = lat),
    longitude = case_when(
      gage_id == "11495600" ~ -121.056389, gage_id == "11495900" ~ -121.006925,
      .default = long),
    river_mile = NA_real_) |>
  select(-site, -lat, -long) |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |>
  st_join(klamath_hucs |> st_transform(4326), join = st_intersects) |>
  st_drop_geometry() |>
  select(-name) |>
  mutate(huc8 = as.numeric(huc8)) |>
  glimpse()

flow_gage <- gage_flow_wqx |>
  bind_rows(gage_flow_usgs) |>
  # These two sites didn't overlap the NHD line for the Scott River so marking their RM as NA
  mutate(river_mile = case_when(gage_name == "Scott River at Gaging Station" ~ NA,
                                gage_name == "Scott River South Fork" ~ NA,
                                .default = as.numeric(river_mile)),
         huc8 = as.numeric(huc8)) |>
  mutate(location = tolower(stream)) |>
  relocate(location, .before = gage_name) |>
  select(-stream) |>
  bind_rows(flow_gage_usbr_owrd) |>
  glimpse()

ggplot(data = flow_data, aes(x = date, y = value)) +
  geom_line() +
  facet_wrap(~gage_id, scales = "free") +
  theme_minimal()

flow_data |>
  group_by(gage_name) |>
  summarise(min_date = min(date),
            max_date = max(date),
            min_val = min(value),
            max_val = max(value),
            n = n())

# save data
# wq_processed_data |> pins::pin_write(flow_data,
#                                      type = "csv")
#
# wq_processed_data |> pins::pin_write(flow_gage,
#                                      type = "csv")
# save rda files
usethis::use_data(flow_data, overwrite = TRUE)
usethis::use_data(flow_gage, overwrite = TRUE)

