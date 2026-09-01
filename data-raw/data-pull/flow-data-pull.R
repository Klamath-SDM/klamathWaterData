library(tidyverse)
library(dataRetrieval)
library(purrr)
library(pins)
library(janitor)
library(httr)
library(xml2)

# the goal of this script is to pull flow data from different sources and save into aws bucket.

# Define aws bucket (klamath-sdm)
# wq_data_raw <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1", prefix = "water_quality/data-raw/")

# Standardized pull window - every source below (WQX, USGS, USBR RISE, USBR
# Hydromet, OWRD) uses this same start/end date.
start_date <- as.Date("1996-01-01")
end_date   <- as.Date("2025-12-31")

### WQX data pull -----
#### flow data pull----
huc_code <- "180102" # huc code for Klamath basin

wqx_flow_data <- readWQPdata(huc = huc_code,
                         characteristicName = "Flow",
                         startDateLo = start_date,
                         startDateHi = end_date)

# gage data has already been pulled in temp data pull script
wqx_gage_data <- whatWQPsites(huc = huc_code)  # this gage data pull can serve other parameters since it covers all sites with this huc code (Klamath basin)




### USGS data pull -----
#### flow data pull----
usgs_gages <- c("11509500", "11510700", "11516530", "11520500", "11523000", "11530500", "11528700", "11530000", "11523200",
                "11525500", "11525655", "11525854", "11526250", "11526400", "11527000",
                "11519500", "11517000", "11517500", "11522500", "11501000", "11525670", "11521500", "11507500", "11502500",
                "11509340", "11509250", "11509105", "11504260", "11504290",
                # missing from the "teacup diagram" (teacup-diagram-data-pull.R) overlap check.
                # NOTE: "11499100" (Sycan River) currently returns zero rows - per
                # teacup-diagram-data-pull.R's own note, that gauge's daily-value
                # record ends ~1991, before this script's start_date (above).
                "11499100", "11504115", "11507200", "11509200")

# Define the parameters
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
      startDate = start_date,
      endDate = end_date)


    all_flow_data[[gage]] <- flow_data
  }, silent = TRUE)
}

# Combine all gage data into one dataframe
usgs_flow_data <- bind_rows(all_flow_data)

usgs_flow_data <- usgs_flow_data |>
  janitor::clean_names() |>
  glimpse()


#### gage data pull----
usgs_gage_flow_data <- readNWISsite(usgs_gages)



## USBR Hydromet flow gages - missing from flow_data ----
# On the "teacup diagram" (teacup-diagram-data-pull.R) but never pulled into
# flow_data directly. Pulled via the same USBR Hydromet archive
# (webarccsv.pl) mechanism teacup-diagram-data-pull.R uses.
#
# Willow Creek (WILC) is included here too. teacup-diagram-data-pull.R's own
# notes say WILC has "NO daily archive record at all" - true for the "Q"/"FB"
# pcodes the teacup diagram itself links to, but re-verified live against
# webarccsv.pl: "WILC QD" *does* carry a full daily discharge record back to
# 1996 (same real-time-pcode -> daily-archive-pcode mapping already
# documented here for LRS/HRPO/LRD's "Q" -> "QD"). Its values match exactly
# what was previously pulled from the RISE API's result/download endpoint
# (itemId=134084) for this same physical gage, so this replaces that bespoke
# pull with no change in the underlying data - just the standard mechanism
# used by every other USBR Hydromet gage below.
source("data-raw/data-pull/usbr-hydromet-pull-helpers.R")

# Pulled live rather than hand-transcribed, so coordinates stay accurate and
# reproducible if a station's location record is ever corrected upstream.
rise_klamath_locations <- fetch_rise_klamath_locations()

usbr_hydromet_flow_stations <- tribble(
  ~site,  ~parameter, ~label,
  "WILC", "QD",       "Willow Creek - Flow (cfs)",
  "LVNO", "QJ",       "Langell Valley North Canal - Flow (cfs)",
  "MHPO", "QP",       "Miller Hill Pump Plant - Flow (cfs)",
  "LRD",  "QD",       "Lost River Diversion - Flow (cfs)",
  "HRPO", "QD",       "Lost River at Harpold Dam - Flow (cfs)",
  "LRS",  "QD",       "Clear Lake East Lobe / Lost River - Flow (cfs)",
  "CHRO", "QD",       "Cherry Creek - Flow (cfs)"
) |>
  left_join(rise_klamath_locations, by = "site")

usbr_hydromet_flow_raw <- fetch_usbr_batch(
  usbr_hydromet_flow_stations,
  start_date = start_date,
  end_date   = end_date
)

usbr_hydromet_flow_data <- usbr_hydromet_flow_raw |>
  mutate(
    location = case_when(
      site == "WILC" ~ "willow creek",
      site == "LVNO" ~ "langell valley north canal",
      site == "MHPO" ~ "miller hill pump plant",
      site == "LRD"  ~ "lost river diversion",
      site == "HRPO" ~ "lost river at harpold dam",
      site == "LRS"  ~ "clear lake east lobe / lost river",
      site == "CHRO" ~ "cherry creek"
    ),
    gage_name = tolower(label),
    gage_id = paste0("usbr-", tolower(site)),
    variable_name = "flow",
    unit = "cfs",
    statistic = "mean") |>
  select(location, gage_name, gage_id, variable_name, value, unit, statistic, date) |>
  glimpse()

## OWRD flow gages - missing from flow_data ----
# OWRD "near real time" gaging stations in the Klamath basin, station type =
# discharge, from https://apps.wrd.state.or.us/apps/sw/hydro_near_real_time/.
# None of these have a usable USGS NWIS record in this script's usgs_gages
# (above) - same rationale as the original two entries here (SF/NF Sprague
# River nr Bly). Stations that DO already have USGS coverage in usgs_gages
# (11501000, 11502500, 11507500, 11509500, 11510700, 11499100, 11504115) are
# deliberately excluded to avoid a duplicate/colliding series under the same
# station number.
#
# Five stations that were not pulled:
#   - 11504210 (Cherry Creek nr Klamath Agency, OR) - USBR site
#   - 11514500 (Keene Creek nr Ashland, OR) - hyatt dam and reservoir. There is discharge here from
#   a USBR gage but it doesn't seem necessary. we can add this in later if necessary:
#   https://www.usbr.gov/pn-bin/v1/instant.pl?list=HYA&format=dfcgi
#   - 11484200 (Lost R at Bonanza) and 11498500 (Long Cr nr Silver Lake, OR) - these are
#   only stage
#
# lat/long pulled live from OWRD's own KML station feed
# (near_real_time_gage_station_kml.aspx) rather than hand-transcribed. See
# owrd-pull-helpers.R (shared with temperature-process-data.R, which also
# pulls a subset of these same stations for water temperature).
source("data-raw/data-pull/owrd-pull-helpers.R")

owrd_station_list <- tribble(
  ~site,      ~location,                   ~gage_name,
  "11495600", "sf sprague river",          "sf sprague river nr bly, or",
  "11495900", "nf sprague river",          "n fk sprague r ab sric cn nr bly, or",
  "11491400", "williamson river",          "williamson r bl sheep cr nr lenz, or",
  "11493500", "williamson river",          "williamson r nr klamath agency, or",
  "11494000", "williamson river",          "williamson r ab spring cr nr klamath agency, or",
  "11494100", "larkin creek",              "larkin cr nr chiloquin, or",
  "11494200", "spring creek",              "spring cr nr chiloquin, or",
  "11494510", "williamson river",          "williamson r ab sprague r nr chiloquin, or",
  "11494950", "south fork sprague river",  "s fk sprague r at sprague r park nr bly, or",
  "11497500", "sprague river",             "sprague r nr beatty, or",
  "11497550", "sprague river",             "sprague r bl brown cr nr beatty, or",
  "11500400", "trout creek",               "trout cr nr lone pine",
  "11500500", "sprague river",             "sprague r at lone pine, or",
  "11502550", "williamson river",          "williamson r at modoc pt rd, nr chiloquin, or",
  "11502950", "sun creek",                 "sun cr at ranger sta nr fort klamath, or",
  "11502980", "wood river",                "wood r bl sun cr nr fort klamath, or",
  "11503000", "annie spring",              "annie spring nr crater lake, or",
  "11503500", "annie creek",               "annie cr nr ft klamath",
  "11504103", "wood river",                "wood r ab crooked cr, nr klamath agency, or",
  "11504109", "crooked creek",             "crooked cr nr klamath agency, or",
  "11504120", "sevenmile creek",           "sevenmile cr bl dry cr nr fort klamath",
  "11510000", "spencer creek",             "spencer cr nr keno, or"
)

owrd_coords <- map_dfr(owrd_station_list$site, fetch_owrd_coord)
owrd_stations <- owrd_station_list |> left_join(owrd_coords, by = "site")

owrd_flow_data <- map_dfr(seq_len(nrow(owrd_stations)), function(i) {
  station <- owrd_stations[i, ]
  message("Pulling OWRD data for station: ", station$site)
  result <- tryCatch(
    whychusModel::get_owrd_hydro(station$site, start_date, end_date, "MDF"),
    error = function(e) { message("  failed: ", conditionMessage(e)); NULL }
  )
  # OWRD's server occasionally returns an HTML error page instead of data for
  # a given station/parameter combination (get_owrd_hydro() doesn't detect
  # this itself, so it's parsed into a malformed 1-column result) - skip
  # rather than error out the whole pull.
  if (is.null(result) || !"station_nbr" %in% names(result)) {
    message("  no usable data returned for station ", station$site)
    return(NULL)
  }
  result |>
    transmute(
      location = station$location,
      gage_name = station$gage_name,
      gage_id = as.character(station_nbr),
      variable_name = "flow",
      value = mean_daily_flow_cfs,
      unit = "cfs",
      statistic = "mean",
      date = mdy(record_date))
}) |>
  filter(!is.na(value)) |>
  glimpse()


##### save raw data into aws bucket water-quality/data-raw/
### USGS
# flow data
# wq_data_raw |> pins::pin_write(usgs_flow_data,
#                                type = "csv",
#                                title = "usgs_flow")
# # gage flow data
# wq_data_raw |> pins::pin_write(usgs_gage_flow_data,
#                                type = "csv",
#                                title = "usgs_gage_flow")
# ### WQX
# # flow data
# wq_data_raw |> pins::pin_write(wqx_flow_data,
#                                type = "csv",
#                                title = "wqx_flow")
