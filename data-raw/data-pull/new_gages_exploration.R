library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

# summary of findings:
#  need to pull DO:
#  - "422711122003700" "422606121592600"
# need to expand DO:
# "422502122011400", "422719121571400", "421209121463000", "420853121505500", "420451121510000"
# no available data:
# - "423146121555900","423142121560700","423139121564600","423132121573200","423124121583401","422628121594500",

# need to expand River Discharge (flow):
# - "11502500", "11507500"
#  need to pull River Discharge (flow):
# - USBR-WILC

# need to expand lake elevation:
# - "11507001"
#  need to pull lake elevation:
# - USBR-LRS, USBR-CLK

#  DISSOLVED OXYGEN -----
# TODO it looks like gages that currently are not annotated don't have DO data
##  --- UKL----
gages_to_add <-c("422719121571400", # we have this gage, just need to expand time coverage
                 "422300121513000",
                 "422312121515900",
                 "422036121515700",
                 "422103121513300",
                 "422046121524400",
                 "422711122003700", # need to pull
                 "423146121555900",
                 "423142121560700",
                 "423139121564600",
                 "423132121573200",
                 "423124121583401",
                 "422628121594500",
                 "422606121592600", # need to pull
                 "422502122011400") # we have this gage, just need to expand time coverage

start_date <- "1996-01-01"
end_date   <- "2025-12-31"
parameterCd <- "00300"  # Dissolved Oxygen
statCd <- c("00001", "00002", "00003")  # Min, Max, Mean DO


data_ukl <- readNWISdv(
  siteNumbers = gages_to_add,
  parameterCd = parameterCd,
  statCd      = statCd,
  startDate   = start_date,
  endDate     = end_date
)


unique(data_ukl$site_no)


##  -------- Ewana Lake -----

gages_to_add_ewana <-c("421209121463000", # we have this gage, just need to expand time coverage
                       "420853121505500", # we have this gage, just need to expand time coverage
                       "420451121510000") # we have this gage, just need to expand time coverage


data_ewana <- readNWISdv(
  siteNumbers = gages_to_add,
  parameterCd = parameterCd,
  statCd = statCd,
  startDate = start_date,
  endDate = end_date)


unique(data_ewana$site_no)


# --- River Discharge ----

# Williamson River: Williamson River Blw Sprague River NR Chiloquin (USGS-11502500) # we have this gage, just need to expand time coverage
# Link River: Link River at Klamath Falls (USGS-11507500) # we have this gage, just need to expand time coverage

## UKL + Link River ----

flow_ukl <- readNWISdv(
  siteNumbers = c("11502500", "11507500"),
  parameterCd = "00060",
  statCd = "00003",
  startDate = start_date,
  endDate = end_date) |> glimpse()

# check for date range of each gage
range(flow_ukl |>
        filter(site_no == "11502500") |>
        pull(Date))
range(flow_ukl |>
        filter(site_no == "11507500") |>
        pull(Date))


## Willow Creek: Willow Creek gage (USBR-WILC) ----
url <- paste0(
  "https://data.usbr.gov/rise/api/result/download",
  "?type=csv&itemId=134084&order=ASC",
  "&after=1996-01-01",
  "&before=2026-01-01"
)

raw <- readLines(url, warn = FALSE)

# Header is the line containing "Datetime"
hdr <- grep("Datetime", raw)[1]

wilc <- read.csv(text = paste(raw[hdr:length(raw)], collapse = "\n"),
                 stringsAsFactors = FALSE, check.names = FALSE)

# Keep just the useful columns and clean them up
wilc <- data.frame(
  datetime_utc = wilc[["Datetime (UTC)"]],
  flow_cfs     = as.numeric(wilc[["Result"]])
)

# Timestamps are midnight Pacific expressed in UTC (07:00),
# so convert to the local calendar date:
wilc$date <- as.Date(as.POSIXct(wilc$datetime_utc, tz = "UTC"),
                     tz = "America/Los_Angeles")

wilc <- wilc[, c("date", "flow_cfs")]

head(wilc); tail(wilc)
summary(wilc$flow_cfs)

plot(wilc$date, wilc$flow_cfs, type = "l",
     xlab = "", ylab = "Daily average flow (cfs)",
     main = "Willow Creek nr Clear Lake NWR (WILC) - Daily Average Streamflow")





# --- Lake Elevation  ----

# Upper Klamath Lake: Upper Klamath Lake NR K.falls (USGS-11507001) # we have this gage, just need to expand time coverage
# Clear Lake: Dam channel gage (USBR-LRS) with correction rule with west lobe gage (USBR-CLK) when lobes are disconnected
# Notes:
ukl_level <- klamathWaterData::water_level_data |> filter(gage_id == "11507001") |> glimpse()

## Clear Lake East Lobe (LRS) ----
lrs_level <- paste0(
  "https://data.usbr.gov/rise/api/result/download",
  "?type=csv&itemId=134084&order=ASC",
  "&after=1996-01-01",
  "&before=2026-01-01"
)


lrs_level_raw <- readLines(lrs_level, warn = FALSE)
lrs_level <- grep("Datetime", lrs_level_raw)[1]

lrs <- read.csv(text = paste(lrs_level_raw[lrs_level:length(lrs_level_raw)], collapse = "\n"),
               stringsAsFactors = FALSE, check.names = FALSE)

clear_lake_east <- data.frame(
  location  = lrs[["Location"]],
  parameter = lrs[["Parameter"]],
  units     = lrs[["Units"]],
  date      = as.Date(as.POSIXct(lrs[["Datetime (UTC)"]], tz = "UTC"),
                      tz = "America/Los_Angeles"),
  value     = as.numeric(lrs[["Result"]])
)

## Clear Lake West Lobe (CLK) ----

clk_level_url <- paste0(
  "https://data.usbr.gov/rise/api/result/download",
  "?type=csv&order=ASC&itemId=134025",
  "&after=1996-01-01",
  "&before=2026-01-01"
)

clk_level_raw <- readLines(clk_level_url, warn = FALSE)
clk_level <- grep("Datetime", clk_level_raw)[1]

clk <- read.csv(text = paste(clk_level_raw[clk_level:length(clk_level_raw)], collapse = "\n"),
               stringsAsFactors = FALSE, check.names = FALSE)

clear_lake_west <- data.frame(
  location  = clk[["Location"]],
  parameter = clk[["Parameter"]],
  units     = clk[["Units"]],
  date      = as.Date(as.POSIXct(clk[["Datetime (UTC)"]], tz = "UTC"),
                      tz = "America/Los_Angeles"),
  value     = as.numeric(clk[["Result"]])
)

