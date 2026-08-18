library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

# the goal of this script is to pull Lake water surface elevation data from different sources. Pulling 1996-2025 data

#  USGS data ----
start_date <- "1996-01-01"
end_date <- "2025-12-31"

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
## Clear Lake East Lobe (LRS) ----
# https://www.usbr.gov/pn-bin/wyreport.pl?site=lrs&parameter=FD&head=yes

lrs_level_url <- paste0(
  "https://data.usbr.gov/rise/api/result/download",
  "?type=csv",
  "&itemId=134049",
  "&order=ASC",
  "&after=1996-01-01",
  "&before=2026-01-01")

lrs_level_raw <- readLines(lrs_level_url, warn = FALSE)

hdr <- grep("Datetime", lrs_level_raw)[1]

lrs <- read.csv(
  text = paste(lrs_level_raw[hdr:length(lrs_level_raw)], collapse = "\n"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

# Confirm the downloaded series
unique(lrs[c("Location", "Parameter", "Units")])

clear_lake_dam_channel <- data.frame(
  location  = lrs[["Location"]],
  parameter = lrs[["Parameter"]],
  units     = lrs[["Units"]],
  date      = as.Date(
    as.POSIXct(lrs[["Datetime (UTC)"]], tz = "UTC"),
    tz = "America/Los_Angeles"
  ),
  value = as.numeric(lrs[["Result"]])
)

## Pull location metadata ----
parse_rise_location_meta <- function(lrs_level_raw) {
  loc_hdr  <- grep('^"Location","State","Coordinates', lrs_level_raw)
  meta_row <- lrs_level_raw[loc_hdr + 1]
  fields <- read.csv(text = paste(lrs_level_raw[loc_hdr], meta_row, sep = "\n"),
                     stringsAsFactors = FALSE, check.names = FALSE)
  coords <- str_match(fields$`Coordinates (long, lat)`, "\\(([-0-9.]+), ([-0-9.]+)\\)")
  tibble(
    location      = fields$Location,
    state         = fields$State,
    long          = as.numeric(coords[, 2]),
    lat           = as.numeric(coords[, 3]),
    timezone      = fields$Timezone,
    location_type = fields$`Location Type`
  )
}

lrs_coords  <- parse_rise_location_meta(lrs_level_raw)

## Clear Lake West Lobe (CLK) ----
clk_level_url <- paste0(
  "https://data.usbr.gov/rise/api/result/download",
  "?type=csv",
  "&itemId=134025",
  "&order=ASC",
  "&after=1996-01-01",
  "&before=2026-01-01"
)

clk_level_raw <- readLines(clk_level_url, warn = FALSE)

hdr <- grep("Datetime", clk_level_raw)[1]

clk <- read.csv(
  text = paste(clk_level_raw[hdr:length(clk_level_raw)], collapse = "\n"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

# Confirm the downloaded series
unique(clk[c("Location", "Parameter", "Units")])

clear_lake_west <- data.frame(
  location  = clk[["Location"]],
  parameter = clk[["Parameter"]],
  units     = clk[["Units"]],
  date      = as.Date(
    as.POSIXct(clk[["Datetime (UTC)"]], tz = "UTC"),
    tz = "America/Los_Angeles"
  ),
  value = as.numeric(clk[["Result"]])
)


##  gage_data ----
clk_coords  <- parse_rise_location_meta(clk_level_raw)



#  bind both USBR gages
usbr_lake_level <- bind_rows(clear_lake_dam_channel, clear_lake_west) |> glimpse()



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
