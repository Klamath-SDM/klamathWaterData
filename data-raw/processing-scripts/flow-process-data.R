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
# Anderson-Rose Dam (Tulelake Irrigation District daily report workbooks -
# see flow-data-pull.R for reading them; cleaned and shaped here)
# ============================================================
# data-raw/data-exploration/anderson-rose-dam-flow.Rmd has the QA behind each
# step below (reconciliation against the workbooks' own monthly totals, which
# tabs needed repair, the overlap checks, plots).

## 1. Older workbooks (1996-2011, SPILL tab) ----
# The grid has a cell for every day 1-31 of every month, so days that don't
# exist (Feb 30, Apr 31, Feb 29 in a non-leap year) come out as NA dates and
# are dropped. That drops one real value: 30 cfs on "Feb 29, 2002" (2002
# wasn't a leap year - Feb 27 = 40, Feb 28 = 36, "Feb 29" = 30, Mar 1 = 30, so
# it looks like a duplicated entry), which can't be assigned to a real day.
anderson_rose_spill <- anderson_rose_spill_raw |>
  mutate(date = make_date(year, month, day))

anderson_rose_phantom <- anderson_rose_spill |>
  filter(is.na(date), !is.na(value), value != 0)
if (nrow(anderson_rose_phantom) > 0) {
  message("Anderson-Rose: dropped ", nrow(anderson_rose_phantom),
          " non-zero SPILL value(s) on dates that don't exist: ",
          paste0(anderson_rose_phantom$year, "-", anderson_rose_phantom$month, "-",
                 anderson_rose_phantom$day, " = ", anderson_rose_phantom$value, collapse = "; "))
}

anderson_rose_spill <- anderson_rose_spill |>
  filter(!is.na(date)) |>
  transmute(date, value, source_file, source_rank = year)

## 2. Newer workbooks (WY 2011-12 onward, one tab per month) ----
# The date cells on a few tabs are wrong - a template copied forward without
# its dates being updated (e.g. the "Mar 2024" tab is dated entirely 2023,
# "Mar 2022"/"Mar 2023" keep stale 2021 dates from the 7th on, "Sep 2018" has
# two 2016 dates). The values on those tabs are real (the March tabs hold
# clearly different numbers), so the tab name is treated as the source of
# truth for the year and month, and only the day-of-month comes from the date
# cell. A date whose month doesn't match its tab is dropped: those are the
# blank 29th rows on some Feb tabs, whose dates roll over to Mar 1 (the real
# Mar 1 is on the Mar tab), and the junk dates on empty template tabs.
anderson_rose_month <- anderson_rose_month_raw |>
  mutate(
    month_matches = month(date_as_entered) == tab_month,
    date = if_else(month_matches, make_date(tab_year, tab_month, day(date_as_entered)), as.Date(NA))
  )

message("Anderson-Rose: ", sum(anderson_rose_month$month_matches & year(anderson_rose_month$date_as_entered) != anderson_rose_month$tab_year),
        " date(s) with the wrong year corrected from the tab name; ",
        sum(!anderson_rose_month$month_matches), " row(s) dropped (date in a different month than its tab)")

# dropping a row is only safe if it's blank - say so if that ever stops being true
if (any(!anderson_rose_month$month_matches & !is.na(anderson_rose_month$value))) {
  warning("Anderson-Rose: dropped row(s) with a value because their date is in a different month than their tab:\n",
          paste(capture.output(print(anderson_rose_month |>
                                       filter(!month_matches, !is.na(value)) |>
                                       select(source_file, tab, date_as_entered, value))), collapse = "\n"))
}

anderson_rose_month <- anderson_rose_month |>
  filter(!is.na(date)) |>
  transmute(date, value, source_file,
            # any newer-layout workbook outranks any older-layout one, and later
            # water years outrank earlier ones
            source_rank = 1000L + as.integer(str_extract(source_file, "\\d{4}")))

## 3. Combine - newest workbook wins ----
# A few dates are in more than one workbook: Oct-Dec 2011 is in both
# "Daily 2011" and the WY 2011-12 workbook, and each water-year workbook can
# carry the start of the next one as a leftover tab (e.g. "Oct 2025" in the
# WY 2024-25 workbook, repeated in full in WY 2025-26). The value from the
# newest workbook is kept, and a non-blank value always beats a blank one.
anderson_rose_all <- bind_rows(anderson_rose_spill, anderson_rose_month)

anderson_rose_conflicts <- anderson_rose_all |>
  filter(!is.na(value)) |>
  group_by(date) |>
  filter(n_distinct(value) > 1) |>
  ungroup()
if (nrow(anderson_rose_conflicts) > 0) {
  warning("Anderson-Rose: ", n_distinct(anderson_rose_conflicts$date),
          " date(s) have different values in different workbooks (newest workbook kept): ",
          paste(format(sort(unique(anderson_rose_conflicts$date))), collapse = ", "))
}

anderson_rose_daily <- anderson_rose_all |>
  arrange(date, is.na(value), desc(source_rank)) |>
  distinct(date, .keep_all = TRUE)

message("Anderson-Rose: ", sum(!is.na(anderson_rose_daily$value)), " days with a value, ",
        format(min(anderson_rose_daily$date)), " to ",
        format(max(anderson_rose_daily$date[!is.na(anderson_rose_daily$value)])),
        " (last day with a value)")

## 4. Flow table ----
# Clipped to the same standardized window as every other flow source
# (start_date/end_date in flow-data-pull.R) - the workbooks run later than
# that. Blank days drop out here, same as the other sources. Carries its name
# in `location` like the USBR Hydromet and OWRD tables, which the flow_data
# combine below accounts for. gage_id follows the "<source>-<site>" pattern
# of the other non-USGS ids (the workbooks have no official station code).
# statistic is "mean" to match the other flow sources - the workbooks report
# one cfs figure per day.
anderson_rose_flow_data <- anderson_rose_daily |>
  filter(!is.na(value), date >= start_date, date <= end_date) |>
  transmute(
    location      = "lost river",
    gage_name     = "anderson-rose dam",
    gage_id       = "tid-anderson-rose",
    variable_name = "flow",
    value         = value,
    unit          = "cfs",
    statistic     = "mean",
    date          = date) |>
  glimpse()

## 5. Gage table ----
# Built from the flow table like the USBR Hydromet/OWRD gages, so the two
# can't drift. Coordinates are the NWIS site AT the dam (pulled in
# flow-data-pull.R). river_mile and huc8 are filled in the combine below,
# alongside the other non-NHD gages.
flow_gage_anderson_rose <- anderson_rose_flow_data |>
  distinct(location, gage_name, gage_id) |>
  mutate(agency = "Tulelake Irrigation District",   # from the "TID Daily Report" workbook names
         latitude  = anderson_rose_site$dec_lat_va,
         longitude = anderson_rose_site$dec_long_va)

# ============================================================
# Combine all sources
# ============================================================

## 1. Combine USBR Hydromet + OWRD + Anderson-Rose gage rows, assign huc8 ----
# huc8 determined by spatial join against rivermile::klamath_hucs
# (point-in-polygon on lat/long) rather than hand-transcribed.
flow_gage_usbr_owrd <- bind_rows(flow_gage_usbr, flow_gage_owrd, flow_gage_anderson_rose) |>
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
    gage_name == "ANNIE SPRING NEAR CRATER LAKE, OR" ~ "annie spring",
    TRUE ~ location
  ))

## 4. Combine every source's flow table ----
flow_data <- flow_wqx |>
  mutate(date = as.Date(date)) |>
  bind_rows(flow_usgs |>
              mutate(gage_id = as.character(gage_id)),
            usbr_hydromet_flow_data, owrd_flow_data, anderson_rose_flow_data) |>
  # flow_wqx/flow_usgs carry the stream name in `stream`; the USBR Hydromet,
  # OWRD and Anderson-Rose tables carry it in `location`. Take whichever is
  # there - `tolower(stream)` on its own overwrote `location` with NA for
  # every row of the second group (~160,000 rows).
  mutate(location = coalesce(tolower(stream), location)) |>
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
# Mirrors step 3 above. Only the canal/drain gage_names and Annie Spring
# (a USGS gage, formerly pulled from OWRD, whose name has no stream keyword)
# appear in flow_data at all (the other flow_gage fixes - Howard Prairie/
# Hyatt Prairie/Shackleford/Stuart Fork/Squirrel Gulch - have no associated
# flow_data rows).
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
    gage_name == "ANNIE SPRING NEAR CRATER LAKE, OR" ~ "annie spring",
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

## 8. Check every flow_data location is filled in and agrees with flow_gage ----
# location is a property of the gage, so the two tables should always agree.
# This stops the script before saving rather than writing NA locations again
# (see the coalesce() in the flow_data combine above for what used to cause it).
flow_location_check <- flow_data |>
  distinct(gage_id, location) |>
  left_join(flow_gage |> select(gage_id, gage_location = location), by = "gage_id")

if (anyNA(flow_location_check$location)) {
  stop("flow_data has NA location for gage_id(s): ",
       paste(flow_location_check$gage_id[is.na(flow_location_check$location)], collapse = ", "))
}

flow_location_mismatch <- flow_location_check |>
  filter(is.na(gage_location) | location != gage_location)
if (nrow(flow_location_mismatch) > 0) {
  stop("flow_data location doesn't match flow_gage (or the gage is missing from flow_gage) for gage_id(s): ",
       paste(flow_location_mismatch$gage_id, collapse = ", "))
}

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
