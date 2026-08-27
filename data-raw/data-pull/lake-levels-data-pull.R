library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

# the goal of this script is to pull Lake water surface elevation data from different sources. Pulling 1996-2025 data

#  USGS data ----
# Standardized pull window - every source below uses this same start/end date.
start_date <- as.Date("1996-01-01")
end_date   <- as.Date("2025-12-31")

#### usgs lake water surface data ----
ukl_levels_1 <- dataRetrieval::readNWISdv(11505900, parameterCd = "72275", start_date , end_date)

ukl_levels_2 <- dataRetrieval::readNWISdv(11504300, parameterCd = "72275", start_date , end_date)

ukl_levels_3 <- dataRetrieval::readNWISdv(11505800, parameterCd = "72275", start_date , end_date)

ukl_levels_4 <- dataRetrieval::readNWISdv(11507001, parameterCd = "72275", start_date , end_date)

water_level_data <- bind_rows(ukl_levels_1, ukl_levels_2, ukl_levels_3, ukl_levels_4)


#### gage data ----
usgs_gages <- c("11505900", "11504300", "11505800", "11507001")


water_level_gage_data <- readNWISsite(usgs_gages)


#  USBR data----
## USBR Hydromet - gages missing from water_level_data ----
# Gerber Reservoir, Malone Reservoir, Tule Lake Sump 1A/1B, Clear Lake West
# Lobe (CLK), and Clear Lake East Lobe (LRS) are all on the "teacup diagram"
# (teacup-diagram-data-pull.R). CLK and LRS were previously pulled via the
# USBR RISE API's result/download CSV endpoint - replaced here with the same
# USBR Hydromet archive (webarccsv.pl) mechanism teacup-diagram-data-pull.R
# uses, for consistency with the other Hydromet-sourced gages. This also
# drops the RISE download's UTC-to-Pacific date conversion entirely: that
# conversion was wrong for LRS's fixed-UTC-hour daily value (it silently
# shifted every winter/PST-season reading back one calendar day, and
# duplicated/skipped a date each year at the DST transition). Hydromet's own
# archive parses dates as plain calendar dates (see mdy() in
# parse_webarccsv()), so this class of bug doesn't exist here.
source("data-raw/data-pull/usbr-hydromet-pull-helpers.R")

# Pulled live rather than hand-transcribed, so coordinates stay accurate and
# reproducible if a station's location record is ever corrected upstream.
rise_klamath_locations <- fetch_rise_klamath_locations()

usbr_hydromet_elev_stations <- tribble(
  ~site,   ~parameter, ~label,
  "GER",   "FB",       "Gerber Reservoir - Forebay Elevation (ft)",
  "MAL",   "GD",       "Malone Reservoir - Gage Height (ft)",
  "TULC",  "FB",       "Tule Lake Sump 1A - Forebay Elevation (ft)",
  "TULC2", "FB",       "Tule Lake Sump 1B - Forebay Elevation (ft)",
  "CLK",   "FB",       "Clear Lake West Lobe - Forebay Elevation (ft)",
  "LRS",   "FD",       "Clear Lake East Lobe - Forebay Elevation (ft)"
) |>
  left_join(rise_klamath_locations, by = "site")

usbr_hydromet_elev_raw <- fetch_usbr_batch(
  usbr_hydromet_elev_stations,
  start_date = start_date,
  end_date   = end_date
)

##### save raw data into aws bucket water-quality/data-raw/

### USGS
# lake surface elevation data
# wq_data_raw |> pins::pin_write(water_level_data,
#                                type = "csv",
#                                title = "water_level_data")
# # gage data
# wq_data_raw |> pins::pin_write(water_level_gage_data,
#                                type = "csv",
#                                title = "water_level_gage_data")
