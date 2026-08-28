library(tidyverse)
library(dataRetrieval)
library(purrr)
library(pins)
library(rivermile)
library(sf)

# notes and questions:
#	WQX There is one site that does not seem to be located on a stream "QVIR-SRES (Shackleford at Reservation)".
#	Waterbody_name function did not work - see the WQX section below.
#	USGS some flow sites are in canals. Do we want to keep them?
# raw data will be pulled from S3 bucket. These data is originally retrieved on flow-data-pull.R

# setting up aws bucket
# wq_data_board <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1")
source("data-raw/data-pull/flow-data-pull.R")

# ============================================================
# WQX
# ============================================================

## 1. Clean raw pulls ----
wqx_data_raw <- wqx_flow_data |>
  janitor::clean_names() |>
  glimpse()

wqx_gage_raw <- wqx_gage_data |>
  janitor::clean_names() |>
  mutate(gage_id = monitoring_location_identifier) |>
  glimpse()

## 2. Join flow + gage, derive stream name ----
all_wqx_flow_data <- wqx_data_raw |>
  left_join(wqx_gage_raw) |>
  mutate(waterbody_name = extract_waterbody(monitoring_location_name),
         waterbody_name = str_to_title(waterbody_name)) |>
  glimpse()

# extract_waterbody() misses a couple of names - fix by hand:
#   - "Townsends Gulch" is a Scott River tributary, grouped under "Scott River"
#   - "Shackleford at Reservation" (QVIR-SRES) doesn't parse at all; see
#     https://www.waterqualitydata.us/provider/STORET/QVIR/ - it's fixed
#     later against flow_gage/flow_data directly (see "Combine all sources"),
#     since extract_waterbody() can't recognize it as Shackleford Creek here.
all_wqx_flow_data_clean <- all_wqx_flow_data |>
  mutate(waterbody_name = case_when(
    monitoring_location_name == "Townsends Gulch" ~ "Scott River",
    TRUE ~ waterbody_name))

## 3. Build flow table ----
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

## 4. Build gage table ----
wqx_gage_raw <- wqx_gage_data |>
  janitor::clean_names() |>
  rename(gage_id = monitoring_location_identifier)

gage_flow_wqx_clean <- flow_wqx |>
  left_join(wqx_gage_raw, by = "gage_id") |>
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

# ============================================================
# USGS
# ============================================================

## 1. Clean raw pulls ----
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

# stream names live in the gage data, so pull that in and join
usgs_gage_raw <- usgs_gage_flow_data |>
  janitor::clean_names() |>
  glimpse()

## 2. Join flow + gage, derive stream name ----
flow_processed_data_usgs <- usgs_data_raw_clean |>
  left_join(usgs_gage_raw, by = "site_no") |>
  mutate(waterbody_name = extract_waterbody(station_nm),
         waterbody_name = tools::toTitleCase(tolower(waterbody_name)),
         gage_name = station_nm) |>
  glimpse()

# extract_waterbody() misses the two Indian Creek gages - fix by hand:
flow_processed_data_usgs_clean <- flow_processed_data_usgs |>
  mutate(waterbody_name = case_when(
    gage_name %in% c("INDIAN C NR DOUGLAS CITY CA", "INDIAN C NR HAPPY CAMP CA") ~ "Indian Creek",
    TRUE ~ waterbody_name)) |>
  glimpse()

## 3. Build flow table ----
flow_usgs <- flow_processed_data_usgs_clean |>
  mutate(gage_id = site_no,
         gage_name = station_nm,
         stream = waterbody_name) |>
  select(stream, gage_name, gage_id, variable_name, value, unit, statistic, date) |>
  glimpse()

## 4. Build gage table ----
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

# ============================================================
# USBR Hydromet (Willow Creek, Gerber/Malone/Tule Lake/Clear Lake flow
# gages, plus Langell Valley North Canal, Lost River, Cherry Creek - see
# flow-data-pull.R for the flow pull itself; only the gage table is built
# here)
# ============================================================
# lat/long come from rise_klamath_locations (pulled live - see
# flow-data-pull.R) rather than hand-transcribed. Not run through
# gage_data_format()/find_nearest_river_miles() (river_mile left NA), same
# treatment as the Willow Creek USBR gage above.

flow_gage_usbr <- usbr_hydromet_flow_data |>
  distinct(location, gage_name, gage_id) |>
  mutate(
    agency = "Bureau of Reclamation",
    site = toupper(str_remove(gage_id, "^usbr-"))) |>
  left_join(rise_klamath_locations, by = "site") |>
  rename(latitude = lat, longitude = long) |>
  select(-site)

# ============================================================
# OWRD (see flow-data-pull.R for the flow pull itself; only the gage table
# is built here)
# ============================================================
# lat/long come from owrd_stations (pulled live from OWRD's own KML station
# feed - see flow-data-pull.R) rather than hand-transcribed. Same
# river_mile/gage_data_format() treatment as the USBR Hydromet gages above.

flow_gage_owrd <- owrd_flow_data |>
  distinct(location, gage_name, gage_id) |>
  mutate(agency = "Oregon Water Resources Department") |>
  left_join(owrd_stations |> select(site, lat, long), by = c("gage_id" = "site")) |>
  rename(latitude = lat, longitude = long)

# ============================================================
# Combine all sources
# ============================================================

## 1. Combine USBR Hydromet + OWRD gage rows, assign huc8 ----
# huc8 determined by spatial join against rivermile::klamath_hucs
# (point-in-polygon on lat/long) rather than hand-transcribed.
flow_gage_usbr_owrd <- bind_rows(flow_gage_usbr, flow_gage_owrd) |>
  mutate(river_mile = NA_real_) |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |>
  st_join(klamath_hucs |> st_transform(4326), join = st_intersects) |>
  st_drop_geometry() |>
  select(-name) |>
  mutate(huc8 = as.numeric(huc8)) |>
  glimpse()

## 2. Combine every source's gage table ----
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

## 3. Fill remaining NA location (stream name) on flow_gage using gage_name ----
# extract_waterbody() doesn't recognize canal/drain/gulch/dam-release names,
# so these fell through with no stream assigned. Matched by hand against each
# gage_name rather than a generic rule: canals/drains keep their own name
# (matches how canal-named USBR Hydromet gages elsewhere in this package -
# e.g. "langell valley north canal" - are already treated as their own
# location), and "Shackleford at Reservation" matches its sibling QVIR-SHFL
# "Shackleford Creek at Falls", already under location "shackleford creek".
# Two were genuinely ambiguous and confirmed with the user rather than
# guessed: "Squirrel Gulch" keeps its own name (unlike "Townsends Gulch"
# above, which maps to its parent river, "scott river" - gulches aren't
# consistently self-named locations, so this was checked rather than
# assumed); "Hyatt Prairie Dam Release at Outlet Works" has no stream
# keyword at all and uses "hyatt prairie" as a stand-in place name, same
# treatment as reservoir-name locations elsewhere (e.g. "gerber reservoir").
flow_gage <- flow_gage |>
  mutate(location = case_when(
    !is.na(location) ~ location,
    gage_name == "HOWARD PRAIRIE CANAL AT HEADWORKS" ~ "howard prairie canal",
    gage_name %in% c("HYATT PRAIRIE DAM RELEASE AT OUTLET WORKS",
                      "HYATTPRAIRIEDAMRELEASEATOUTLETWORKS") ~ "hyatt prairie",
    gage_name == "Shackleford at Reservation" ~ "shackleford creek",
    gage_name == "STUART FORK" ~ "stuart fork",
    gage_name == "SQUIRREL GULCH" ~ "squirrel gulch",
    gage_name == "KLAMATH STRAITS DRAIN NEAR WORDEN, OR" ~ "klamath straits drain",
    gage_name %in% c("ADY CANAL ABOVE LOWER KLAMATH NWR, NEAR WORDEN, OR",
                      "ADY CANAL AT HIGHWAY 97, NEAR WORDEN, OR") ~ "ady canal",
    gage_name == "NORTH CANAL AT HIGHWAY 97, NEAR MIDLAND, OR" ~ "north canal",
    gage_name == "FOURMILE CANAL NEAR KLAMATH AGENCY, OR" ~ "fourmile canal",
    gage_name == "SEVENMILE CNL AT DIKE RD BR, NR KLAMATH AGENCY, OR" ~ "sevenmile canal",
    gage_name == "A CANAL AT KLAMATH FALLS, OR" ~ "a canal",
    TRUE ~ location
  ))

## 4. Combine every source's flow table ----
flow_data <- flow_wqx |>
  mutate(date = as.Date(date)) |>
  bind_rows(flow_usgs |>
              mutate(gage_id = as.character(gage_id)),
            usbr_hydromet_flow_data, owrd_flow_data) |>
  mutate(location = tolower(stream)) |>
  relocate(location, .before = gage_name) |>
  select(-stream) |>
  filter(!is.na(value)) |>
  filter(value != 998877.00 & value >= 0) |>  # this removes outlier in sbr-hrpo
  glimpse()

## 5. Drop gages with too little data ----
site_with_little_data <- flow_data |>
  group_by(gage_name) |>
  summarise(min_date = min(date),
            max_date = max(date),
            n = n()) |>
  filter(n > 10) |>
  pull(gage_name)

flow_data <- flow_data |>
  filter(gage_name %in% site_with_little_data)

## 6. Fill remaining NA location (stream name) on flow_data using gage_name ----
# Mirrors step 3 above. Only the canal/drain gage_names appear in flow_data
# at all (the other flow_gage fixes - Howard Prairie/Hyatt Prairie/
# Shackleford/Stuart Fork/Squirrel Gulch - have no associated flow_data rows).
flow_data <- flow_data |>
  mutate(location = case_when(
    !is.na(location) ~ location,
    gage_name == "KLAMATH STRAITS DRAIN NEAR WORDEN, OR" ~ "klamath straits drain",
    gage_name %in% c("ADY CANAL ABOVE LOWER KLAMATH NWR, NEAR WORDEN, OR",
                      "ADY CANAL AT HIGHWAY 97, NEAR WORDEN, OR") ~ "ady canal",
    gage_name == "NORTH CANAL AT HIGHWAY 97, NEAR MIDLAND, OR" ~ "north canal",
    gage_name == "FOURMILE CANAL NEAR KLAMATH AGENCY, OR" ~ "fourmile canal",
    gage_name == "SEVENMILE CNL AT DIKE RD BR, NR KLAMATH AGENCY, OR" ~ "sevenmile canal",
    gage_name == "A CANAL AT KLAMATH FALLS, OR" ~ "a canal",
    TRUE ~ location
  ))

flow_gage <- flow_gage |>
  mutate(stream = location) |>
  gage_data_format(filter_streams = FALSE) |>
  rivermile::find_nearest_river_miles() |>
  mutate(longitude = st_coordinates(geometry)[, 1],
         latitude = st_coordinates(geometry)[, 2]) |>
  st_drop_geometry() |>
  select(gage_name, gage_id, agency, latitude, longitude, river_mile, huc8, location = stream) |>
  glimpse()

## 7. Lowercase every character column except gage_id ----
# gage_id keeps its source-system casing (e.g. "KLAMATHTRIBES_WQX-SR0040",
# "usbr-lvno"). Done last, after the gage_name-matching fixes above, since
# those match against gage_name's original casing.
flow_data <- flow_data |>
  mutate(across(where(is.character) & !any_of("gage_id"), tolower))
flow_gage <- flow_gage |>
  mutate(across(where(is.character) & !any_of("gage_id"), tolower))

# ============================================================
# QA
# ============================================================
flow_data |>
  group_by(gage_name) |>
  summarise(min_date = min(date),
            max_date = max(date),
            min_val = min(value),
            max_val = max(value),
            n = n())

# ============================================================
# Save
# ============================================================
# wq_processed_data |> pins::pin_write(flow_data,
#                                      type = "csv")
#
# wq_processed_data |> pins::pin_write(flow_gage,
#                                      type = "csv")

usethis::use_data(flow_data, overwrite = TRUE)
usethis::use_data(flow_gage, overwrite = TRUE)
