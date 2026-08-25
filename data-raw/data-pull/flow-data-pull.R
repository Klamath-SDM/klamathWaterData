library(tidyverse)
library(dataRetrieval)
library(purrr)
library(pins)
library(janitor)

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



### USBR data pull -----
## Willow Creek: Willow Creek gage (USBR-WILC) ----
url <- paste0(
  "https://data.usbr.gov/rise/api/result/download",
  "?type=csv&itemId=134084&order=ASC",
  "&after=", format(start_date, "%Y-%m-%d"),
  "&before=", format(end_date, "%Y-%m-%d")
)

raw <- readLines(url, warn = FALSE)

# Header is the line containing "Datetime"
hdr <- grep("Datetime", raw)[1]

wilc <- read.csv(text = paste(raw[hdr:length(raw)], collapse = "\n"),
                 stringsAsFactors = FALSE, check.names = FALSE)

usbr_flow_data <- wilc |>
  clean_names() |>
  mutate(date = as.Date(datetime_utc),
         gage_name = tolower(location),
         location = "willow creek",
         gage_id = "usbr-wilc",
         variable_name = "flow",
         value = result,
         unit = units,
         statistic = "mean"
         ) |>
  select(location, gage_name, gage_id, variable_name, value, unit, statistic, date) |>
  glimpse()

## USBR Hydromet flow gages - missing from flow_data ----
# On the "teacup diagram" (teacup-diagram-data-pull.R) but never pulled into
# flow_data directly. Pulled via the same USBR Hydromet archive
# (webarccsv.pl) mechanism teacup-diagram-data-pull.R uses.
source("data-raw/data-pull/usbr-hydromet-pull-helpers.R")

# Pulled live rather than hand-transcribed, so coordinates stay accurate and
# reproducible if a station's location record is ever corrected upstream.
rise_klamath_locations <- fetch_rise_klamath_locations()

usbr_hydromet_flow_stations <- tribble(
  ~site,  ~parameter, ~label,
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
# SF Sprague River nr Bly (11495600) and NF Sprague River (11495900) are on
# the teacup diagram but have no usable USGS NWIS record (see
# teacup-diagram-data-pull.R for details), so they're pulled directly from
# OWRD via whychusModel::get_owrd_hydro(), same as there.
owrd_flow_data <- bind_rows(
  whychusModel::get_owrd_hydro(11495600, start_date, end_date, "MDF") |>
    transmute(
      location = "sf sprague river",
      gage_name = "sf sprague river nr bly, or",
      gage_id = as.character(station_nbr),
      variable_name = "flow",
      value = mean_daily_flow_cfs,
      unit = "cfs",
      statistic = "mean",
      date = mdy(record_date)),
  whychusModel::get_owrd_hydro(11495900, start_date, end_date, "MDF") |>
    transmute(
      location = "nf sprague river",
      gage_name = "n fk sprague r ab sric cn nr bly, or",
      gage_id = as.character(station_nbr),
      variable_name = "flow",
      value = mean_daily_flow_cfs,
      unit = "cfs",
      statistic = "mean",
      date = mdy(record_date))
) |>
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
