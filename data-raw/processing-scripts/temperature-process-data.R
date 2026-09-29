library(tidyverse)
library(dataRetrieval)
library(purrr)
library(pins)
library(rivermile)
library(sf)
library(janitor)
library(httr)
library(xml2)

# These data is originally retrieved on temperature-data-pull.R and script is being sourced here
source("data-raw/data-pull/temperature-data-pull.R")

# ### WQX ----
# # pulling raw data
# # TEMPERATURE data
wqx_data_raw <- wqx_temp_data |>
  janitor::clean_names() |>
  mutate(result_measure_value = as.numeric(result_measure_value)) |>
  filter(statistical_base_code %in% c("Mean", "Maximum", "Minimum"), # filtering to stats of interest
         result_measure_value > 0) |>  #filtering out negative values and 0 values
  glimpse()

# # GAGE data
wqx_gage_raw <- wqx_gage_data |>
  janitor::clean_names() |>
  filter(monitoring_location_type_name %in% c("River/Stream", "Lake", "Stream",
                                                "Reservoir", "Lake, Reservoir, Impoundment",
                                                "Spring", "Estuary")) |>
  glimpse()



# JOIN - station data with temp data
all_wqx_temp_data <- wqx_data_raw |> left_join(wqx_gage_raw) |>
  glimpse()

#cleaning data
all_wqx_temp_data <- all_wqx_temp_data |>
  mutate(waterbody_name = extract_waterbody(monitoring_location_name)) # testing function

# check
missing_names_wqx <- all_wqx_temp_data |>
  filter(is.na(waterbody_name))

table(missing_names_wqx$monitoring_location_name) # only 8 names that did not catch on function. This a source for checking those names https://www.waterqualitydata.us/provider/STORET/HVTEPA_WQX/
 #test comparing original vs new names to aviod wrong designation (when two rivers/streams are mentioned on the name)

# check for naming assigned
all_wqx_temp_data |>
  select(waterbody_name, monitoring_location_name, monitoring_location_identifier) |>
  distinct()

# fix "HOBO at Confluence of Klamath and Trinity Rivers" - this is on Klamath River
# fixing stream names manually
all_wqx_temp_data_clean <- all_wqx_temp_data |>
  mutate(waterbody_name = case_when(
    monitoring_location_name %in% c("HOBO at Confluence of Klamath and Trinity Rivers", "CDR and Nutrients at Saints Rest Bar") ~ "Klamath River",
    monitoring_location_name %in% c("CDR at Red Rock", "CDR at South Boundary",
                                    "HOBO  A at TR_NORTON", "HOBO at North Boundary",
                                    "HOBO at South Boundary", "HOBO B  at TR_NORTON") ~ "Trinity River",
    monitoring_location_identifier == "323-02-I|Paradise|R6|Fremont-Winema|Paisley" ~ "Paradise Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ01" ~ "Cavern Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ02" ~ "Sun Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ03" ~ "Sun Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ05" ~ "Wheeler Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ06" ~ "Munson Creek",
    # monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ07" ~ "?",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ09" ~ "Lost Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ10" ~ "Middle Fork Annie Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ13" ~ "Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ14" ~ "Annie Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ17" ~ "Sand Creek",
    # monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ21" ~ " ?Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ22" ~ "Annie Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ26" ~ "Munson Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ29" ~ "Sand Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ30" ~ "Sun Creek",
    # monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ31" ~ "? Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ33" ~ "Sand Creek",
    monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ34" ~ "Munson Creek",
    # monitoring_location_identifier == "11NPSWRD_WQX-CRLA_WQ37" ~ "? Creek",
    TRUE ~ waterbody_name)) |>
  glimpse()

all_wqx_temp_data_clean |>
  select(waterbody_name, monitoring_location_name, monitoring_location_identifier, provider_name, organization_identifier) |>
  distinct()


  #### water data table ----
temperature_data_wqx <- all_wqx_temp_data_clean |>
  mutate(gage_id = monitoring_location_identifier,
         gage_name = monitoring_location_name,
         variable_name = characteristic_name,
         value = result_measure_value,
         unit = result_measure_measure_unit_code,
         statistic = statistical_base_code,
         date = activity_start_date,
         stream = waterbody_name) |>
  select(stream, gage_name, gage_id, variable_name, value, unit, statistic, date) |>
  glimpse()

  #### monitoring site table ----
gage_temperature_wqx_clean <- all_wqx_temp_data_clean |>
  mutate(gage_name = monitoring_location_name,
         gage_id = monitoring_location_identifier,
         agency = organization_formal_name,
         latitude = latitude_measure,
         longitude = longitude_measure,
         river_mile = NA,
         huc8 = huc_eight_digit_code,
         stream = waterbody_name) |>
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |>
  distinct() |>
  gage_data_format(filter_streams = FALSE) |>
  glimpse()

#note that all NPSWRD_WQX gages do not have lat/long so they are getting filtered out

temperature_gage_wqx <- rivermile::find_nearest_river_miles(gage_temperature_wqx_clean) |>
  mutate(longitude = st_coordinates(gage_temperature_wqx_clean)[, 1],
         latitude = st_coordinates(gage_temperature_wqx_clean)[, 2],
         huc8 = as.numeric(huc8)) |>
  st_drop_geometry() |>
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |>
  glimpse()

### USGS ----

# pulling raw data
# TEMPERATURE data
usgs_data_raw <- usgs_temp_data |>
  janitor::clean_names() |>
  glimpse()

usgs_data_raw_clean <- usgs_data_raw |>
  mutate(gage_id = site_no,
         date = as.Date(date),
         max_temp = x_00010_00001,
         min_temp = x_00010_00002,
         mean_temp = x_00010_00003) |>
  select(-c(x_00010_00001, x_00010_00001_cd, x_00010_00002, x_00010_00002_cd, x_00010_00003, x_00010_00003_cd, date_time, tz_cd)) |>
  pivot_longer(cols = c(max_temp, min_temp, mean_temp),
               names_to = "statistic",
               values_to = "value",
               values_drop_na = TRUE) |>
  mutate(statistic = case_when(
    statistic == "max_temp" ~ "maximum",
    statistic == "min_temp" ~ "minimum",
    statistic == "mean_temp" ~ "mean"),
    variable_name = "temperature",
    unit = "celsius") |>
  filter(value > 0) |> #filtering out negative values and 0 values
  glimpse()

# GAGE data
usgs_gage_raw <- usgs_temp_gage_data |>
  janitor::clean_names() |>
  mutate(station_nm = tools::toTitleCase(tolower(station_nm))) |>
  glimpse()

# JOIN - station data with temp data
all_usgs_temp_data_raw <- usgs_data_raw_clean |> left_join(usgs_gage_raw, by = "site_no") |>
  select(c(agency_cd.x, site_no, date, gage_id, statistic, value, variable_name,
           unit, station_nm, dec_lat_va, dec_long_va, huc_cd)) |>
  glimpse()

#cleaning data
all_usgs_temp_data_raw <- all_usgs_temp_data_raw |>
  mutate(waterbody_name = extract_waterbody(station_nm)) # testing function

all_usgs_temp_data_raw |>
  select(station_nm, waterbody_name) |> distinct()

unique(all_usgs_temp_data_raw$waterbody_name)

# water_names that did not work with the function
all_usgs_temp_data_raw |>
  filter(is.na(waterbody_name)) |>
  select(site_no , station_nm, waterbody_name) |>
  distinct() |>
  mutate(site_no = as.character(site_no))

# fixing names
all_usgs_temp_data_raw_clean <- all_usgs_temp_data_raw |>
  mutate(waterbody_name = case_when(station_nm %in% c("Upper Klamath Lake at Howard Bay, or", "Mid-Trench - Lower   -  Mdtl",
                                                      "Mid-Trench - Upper   - Mdtu", "Mid-North - Lower  - Mdnl",
                                                      "Mid-North - Upper  - Mdnu", "Rattlesnake Point  -  Rpt") ~ "Upper Klamath Lake",
                                    station_nm == "Shoalwater Bay - Shb" ~ "Shoalwater Bay",
                                    gage_id %in% c("422042121513100", "421935121551200", "422305121553800", # upper klamath lake gages
                                                   "422305121553803", "422444121580400", "422622122004000",
                                                   "422622122004003", "422719121571400","11504290") ~ "upper klamath lake",
                                    site_no == "420024121132800" ~ "lost river",
                                    T ~ waterbody_name)) |>
           glimpse()

all_usgs_temp_data_raw_clean |>
  select(site_no , station_nm, waterbody_name) |> # there are two gages remaining that I am on sure on how no name
  distinct()


#### water data table ----
temperature_data_usgs <- all_usgs_temp_data_raw_clean |>
  mutate(gage_id = site_no,
         gage_name = station_nm,
         stream = waterbody_name) |>
  select(stream, gage_name, gage_id, variable_name, value, unit, statistic, date) |>
  glimpse()

#### monitoring site table ----
gage_temperature_usgs_clean <- all_usgs_temp_data_raw_clean |>
  mutate(gage_name = station_nm,
         gage_id = site_no,
         agency = agency_cd.x,
         latitude = dec_lat_va,
         longitude = dec_long_va,
         river_mile = NA,
         huc8 = huc_cd,
         stream = waterbody_name
         ) |>
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |>
  distinct() |>
  gage_data_format(filter_streams = FALSE) |>
  glimpse()

temperature_gage_usgs <- rivermile::find_nearest_river_miles(gage_temperature_usgs_clean) |>
  mutate(longitude = st_coordinates(gage_temperature_usgs_clean)[, 1],
         latitude = st_coordinates(gage_temperature_usgs_clean)[, 2]) |>
  st_drop_geometry() |>
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |>
  glimpse()

### OWRD ----
# Some OWRD "near real time" gaging stations already used for flow (see the
# owrd_station_list tribble in flow-data-pull.R) also report water
# temperature (WTEMP_MEAN). Of those 22 stations, only the 14 below returned
# real temperature data - the rest either have no temperature sensor or the
# scraper can't parse their report page for this parameter (a different
# subset than for flow - not every discharge station has a temperature
# sensor). None of these 14 station numbers overlap usgs_gages above.
# lat/long pulled live from OWRD's own KML station feed

#### clean OWRD water temperature data ----
# sourced from temperature-data-pull.R
temperature_data_owrd <- temperature_data_owrd_raw |>
  transmute(
    stream,
    gage_name,
    gage_id = as.character(station_nbr),
    variable_name = "temperature",
    value = daily_mean_water_temp_c,
    unit = "celsius",
    statistic = "mean",
    # WTEMP_MEAN's record_date includes a time component
    # ("01-01-2023 00:00"), so use mdy_hm().
    date = as.Date(mdy_hm(record_date))
  ) |>
  filter(!is.na(value),
         value > 0) |> #filtering out negative values and 0 values
  glimpse()

#### monitoring site table ----
# Not run through gage_data_format()/find_nearest_river_miles() (river_mile
# left NA) - same treatment flow-process-data.R gives its OWRD/USBR Hydromet
# gages. huc8 determined by spatial join against rivermile::klamath_hucs
# (point-in-polygon on lat/long) rather than hand-transcribed.
# sources from temperature-data-pull.R
temperature_gage_owrd <- owrd_temp_stations |>
  transmute(stream = location,
            gage_name = gage_name,
            gage_id = site,
            agency = "Oregon Water Resources Department",
            latitude = lat,
            longitude = long,
            river_mile = NA_real_) |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |>
  st_join(klamath_hucs |> st_transform(4326), join = st_intersects) |>
  st_drop_geometry() |>
  select(-name) |>
  mutate(huc8 = as.numeric(huc8)) |>
  glimpse()

### Karuk Tribe Water Quality Portal (includes Yurok and Quartz Valley) ----

#### water data table ----
#### clean Karuk water temperature data ----
# sourcing temperature_data_karuk_raw from temperature-data-pull.R script
temperature_data_karuk <- temperature_data_karuk_raw |>
  mutate(
    date = as.Date(timestamp)
  ) |>
  filter(!is.na(value),
         value > 0) |>
  group_by(stream, gage_name, gage_id, date) |>
  summarise(
    mean_temp = mean(value, na.rm = TRUE),
    min_temp  = min(value, na.rm = TRUE),
    max_temp  = max(value, na.rm = TRUE),
    .groups = "drop"
  ) |>
  pivot_longer(
    cols = c(mean_temp, min_temp, max_temp),
    names_to = "statistic",
    values_to = "value"
  ) |>
  mutate(
    statistic = case_when(
      statistic == "mean_temp" ~ "mean",
      statistic == "min_temp"  ~ "min",
      statistic == "max_temp"  ~ "max"
    ),
    variable_name = "temperature",
    unit = "celsius"
  ) |>
  select(
    stream,
    gage_name,
    gage_id,
    variable_name,
    value,
    unit,
    statistic,
    date
  ) |>
  glimpse()

#### monitoring site table ----
# Not run through gage_data_format()/find_nearest_river_miles() (river_mile
# left NA) - same treatment as the OWRD/USBR Hydromet gages elsewhere in
# this package. huc8 determined by spatial join against
# rivermile::klamath_hucs (point-in-polygon on lat/long) rather than
# hand-transcribed.
temperature_gage_karuk <- karuk_stations |>
  transmute(stream = location,
            gage_name = gage_name,
            gage_id = gage_id,
            agency = agency,
            latitude = lat,
            longitude = long,
            river_mile = NA_real_) |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |>
  st_join(klamath_hucs |> st_transform(4326), join = st_intersects) |>
  st_drop_geometry() |>
  select(-name) |>
  mutate(huc8 = as.numeric(huc8)) |>
  glimpse()

### Hoopa Valley Tribe Hydromet Portal ----
temperature_data_hoopa <- hoopa_saints_rest_raw |>
  mutate(date = as.Date(timestamp)) |>
  filter(!is.na(value), value > 0, value < 35) |>
  group_by(date) |>
  summarise(mean_temp = mean(value, na.rm = TRUE),
            min_temp  = min(value, na.rm = TRUE),
            max_temp  = max(value, na.rm = TRUE),
            .groups = "drop") |>
  pivot_longer(cols = c(mean_temp, min_temp, max_temp),
               names_to = "statistic",
               values_to = "value") |>
  mutate(statistic = case_when(
    statistic == "mean_temp" ~ "mean",
    statistic == "min_temp"  ~ "min",
    statistic == "max_temp"  ~ "max"),
    stream = "klamath river",
    gage_name = "klamath river saints rest",
    gage_id = "hoopa-hvt-st2",
    variable_name = "temperature",
    unit = "celsius") |>
  select(stream, gage_name, gage_id, variable_name, value, unit, statistic, date) |>
  glimpse()

#### monitoring site table ----
# Coordinates and huc8 treated the same way as the Karuk/OWRD gages above
# (not run through gage_data_format()/find_nearest_river_miles(), river_mile
# left NA; huc8 via spatial join against rivermile::klamath_hucs).
temperature_gage_hoopa <- tibble(
  stream = "klamath river",
  gage_name = "klamath river saints rest",
  gage_id = "hoopa-hvt-st2",
  agency = "Hoopa Valley Tribe",
  latitude = 41.187972,
  longitude = -123.676941,
  river_mile = NA_real_
) |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |>
  st_join(klamath_hucs |> st_transform(4326), join = st_intersects) |>
  st_drop_geometry() |>
  select(-name) |>
  mutate(huc8 = as.numeric(huc8)) |>
  glimpse()

### USFWS ----

# pulling raw data -- This data was shared by Tylor Daley from USFWS
# TEMPERATURE data
#  scott river
# sckr gage
sckr_data_raw <- read_csv("data-raw/temp-data/water_temp_usfws_sckr.csv") |>
  clean_names() |>
  mutate(date = as.Date(date, format = "%m/%d/%Y")) |>
  group_by(date) |>
  summarise(mean_temp = mean(value, na.rm = TRUE), # calculating min, max and mean since data is hourly
            min_temp  = min(value, na.rm = TRUE),
            max_temp  = max(value, na.rm = TRUE),
            .groups = "drop") |>
  pivot_longer(cols = c(mean_temp, min_temp, max_temp),
               names_to = "statistic",
               values_to = "value",
               values_drop_na = TRUE) |>
  mutate(statistic = case_when(
    statistic == "mean_temp" ~ "mean",
    statistic == "min_temp"  ~ "min",
    statistic == "max_temp"  ~ "max",
    TRUE ~ statistic),
    variable_name = "temperature",
    unit = "celsius") |> glimpse()

sckr_metadata_raw <- read_csv("data-raw/temp-data/sckr_metadata.csv") |>
  slice(1) |>
  glimpse()

# info_cols <- sckr_metadata_raw |>
#   mutate(location = waterbody,
#          gage_name = site_name,
#          gage_id = organization_site_id) |>
#   select(location, gage_name, gage_id) |> glimpse()

#  shasta river
# shkr gage
shkr_data_raw <- read_csv("data-raw/temp-data/water_temp_usfws_shkr.csv") |>
  clean_names() |>
  mutate(date = as.Date(date, format = "%m/%d/%Y")) |>
  filter(!is.na(value)) |>
  group_by(date) |>
  summarise(mean_temp = mean(value, na.rm = TRUE), # calculating min, max and mean since data is hourly
            min_temp  = min(value, na.rm = TRUE),
            max_temp  = max(value, na.rm = TRUE),
            .groups = "drop") |>
  pivot_longer(cols = c(mean_temp, min_temp, max_temp),
               names_to = "statistic",
               values_to = "value",
               values_drop_na = TRUE) |>
  mutate(statistic = case_when(
    statistic == "mean_temp" ~ "mean",
    statistic == "min_temp"  ~ "min",
    statistic == "max_temp"  ~ "max",
    TRUE ~ statistic),
    variable_name = "temperature",
    unit = "celsius") |> glimpse()

shkr_metadata_raw <- read_csv("data-raw/temp-data/shkr_metadata.csv") |>
  slice(1)

#### water data table ----
# shkr
temperature_data_shkr <- bind_cols(shkr_data_raw, shkr_metadata_raw |>
                                     mutate(location = waterbody,
                                            gage_name = site_name,
                                            gage_id = organization_site_id) |>
                                     select(location, gage_name, gage_id)) |>
  mutate(stream = location) |>
  select(stream, gage_name, gage_id, variable_name, value, unit, statistic, date)

# sckr
temperature_data_sckr <- bind_cols(sckr_data_raw, sckr_metadata_raw |>
                                     mutate(location = waterbody,
                                            gage_name = site_name,
                                            gage_id = organization_site_id)) |>
  mutate(stream = location) |>
  select(stream, gage_name, gage_id, variable_name, value, unit, statistic, date)

# combine both shkr and sckr
temperature_data_usfws <- bind_rows(temperature_data_shkr, temperature_data_sckr) |> glimpse()

# TODO check rivermile package
# temperature_data_usfws <- rivermile::find_nearest_river_miles(temperature_data_usfws) |>
#   mutate(longitude = st_coordinates(temperature_data_usfws)[, 1],
#          latitude = st_coordinates(temperature_data_usfws)[, 2]) |>
#   st_drop_geometry() |>
#   select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, stream) |>
#   glimpse()

#### monitoring site table ----
# shkr
temperature_gage_shkr <- shkr_metadata_raw |>
  mutate(stream = waterbody,
         gage_name = site_name,
         gage_id = organization_site_id,
         agency = organization_name,
         latitude = lat,
         longitude = long,
         river_mile = NA,
         # stream = waterbody,# TODO look into rivermile package
         huc8 = 18010207) |>
  select(stream, gage_name, gage_id, agency, latitude, longitude, river_mile, huc8)

# sckr
temperature_gage_sckr <- sckr_metadata_raw |>
  mutate(stream = waterbody,
         gage_name = site_name,
         gage_id = organization_site_id,
         agency = organization_name,
         latitude = lat,
         longitude = long,
         river_mile = NA,
         # stream = waterbody,# TODO look into rivermile package
         huc8 = 18010208) |>
  select(stream, gage_name, gage_id, agency, latitude, longitude, river_mile, huc8)

#  combine shkr and sckr
temperature_gage_usfws <- bind_rows(temperature_gage_shkr, temperature_gage_sckr) |> glimpse()


# combine gage and data files ---------------------------------------------
temperature_data <- temperature_data_wqx |>
  mutate(date = as.Date(date),
         variable_name = "temperature",
         statistic = tolower(statistic),
         unit = "celsius",
         value = as.numeric(value)) |>
  bind_rows(temperature_data_usfws, temperature_data_usgs |>
              mutate(gage_id = as.character(gage_id)), temperature_data_owrd,
            temperature_data_karuk, temperature_data_hoopa) |>
  mutate(location = tolower(stream),
         gage_name = tolower(gage_name)) |>
  relocate(location, .before = gage_name) |>
  select(-stream) |>
  filter(!is.na(location) & !is.na(gage_name)) |>
  glimpse()

temperature_gage <- temperature_gage_usgs |>
  mutate(gage_id = as.character(gage_id),
         huc8 = as.numeric(huc8)) |>
  bind_rows(temperature_gage_wqx, temperature_gage_usfws, temperature_gage_owrd,
            temperature_gage_karuk, temperature_gage_hoopa) |>
  mutate(location = tolower(stream),
         gage_name = tolower(gage_name),
         agency = tolower(agency),
         # WQX's own agency name for HVTEPA's sites ("Hoopa Valley Tribe
         # (Tribal)") otherwise doesn't match the plain "Hoopa Valley Tribe"
         # used for the Hydromet portal gage above - same tribe, one name.
         agency = ifelse(agency == "hoopa valley tribe (tribal)", "hoopa valley tribe", agency)) |>
  relocate(location, .before = gage_name) |>
  filter(!is.na(location)) |>
  mutate(stream = location) |>
  gage_data_format(filter_streams = FALSE) |>
  rivermile::find_nearest_river_miles() |>
  mutate(longitude = st_coordinates(geometry)[, 1],
         latitude = st_coordinates(geometry)[, 2]) |>
  st_drop_geometry() |>
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, location = stream) |>
  glimpse()

# save rda files
usethis::use_data(temperature_data, overwrite = TRUE)
usethis::use_data(temperature_gage, overwrite = TRUE)

