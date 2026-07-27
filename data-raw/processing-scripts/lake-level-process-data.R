library(tidyverse)
library(dplyr)
library(tidyr)
library(purrr)
library(pins)
library(rivermile)
library(sf)
library(readxl)
library(stringr)

# raw data will be pulled from S3 bucket. These data is originally retrieved on lake-level-data-pull.R
# Additionally, this script pulls and process data for water elevation at Tule Sumps provided by Torrey Tyler (USBR)
# both datasets are combined into water_level_data.rda

# setting up aws bucket
wq_data_board <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1")


# pulling raw data
water_level_data <- wq_data_board |>
  pins::pin_read("water_quality/data-raw/water_level_data") |>
  janitor::clean_names() |>
  glimpse()

water_level_data_raw_clean <- water_level_data |>
  mutate(gage_id = site_no,
         date = as.Date(date),
         mean_level = x_72275_00003) |>
  select(-c(x_72275_00003_cd,x_72275_00003)) |>
  pivot_longer(cols = c(mean_level),
               names_to = "statistic",
               values_to = "value",
               values_drop_na = TRUE) |>
  mutate(statistic = case_when(
    statistic == "mean_level" ~ "mean"),
    variable_name = "water level",
    unit = "feet") |>
  glimpse()

# GAGE data
water_level_gage_data <- wq_data_board |>
  pins::pin_read("water_quality/data-raw/water_level_gage_data") |>
  janitor::clean_names() |>
  mutate(station_nm = tools::toTitleCase(tolower(station_nm))) |>
  glimpse()

# JOIN - station data with temp data
all_usgs_water_level_raw <- water_level_data_raw_clean |> left_join(water_level_gage_data, by = "site_no") |>
  select(c(agency_cd.x, site_no, date, gage_id, statistic, value, variable_name,
           unit, station_nm, dec_lat_va, dec_long_va, huc_cd)) |>
  mutate(waterbody_name = "upper klamath lake") |>
  glimpse()

#### water data table usgs ----
water_level_data_usgs <- all_usgs_water_level_raw |>
  mutate(gage_id = as.character(site_no),
         gage_name = tolower(station_nm),
         stream = waterbody_name) |>
  select(stream, gage_name, gage_id, variable_name, value, unit, statistic, date) |>
  rename(location = stream) |>
  glimpse()

#### monitoring site table usgs ----
water_level_gage_usgs <- all_usgs_water_level_raw |>
  mutate(gage_name = tolower(station_nm),
         gage_id = as.character(site_no),
         agency = agency_cd.x,
         latitude = dec_lat_va,
         longitude = dec_long_va,
         huc8 = huc_cd,
         stream = waterbody_name) |>
  select(gage_name, gage_id, agency, latitude, longitude, huc8, stream) |>
  distinct() |>
  # st_as_sf(coords = c("longitude", "latitude"), crs = 4326) |>
  # gage_data_format(filter_streams = FALSE) |>
  rename(location = stream) |>
  relocate(location, .before = gage_name) |>
  glimpse()


# ============================================================
# Combine Tule Lake (Tule Sumps) daily elevation data
# from TID Daily Report workbooks, WY 2012-2013 ... WY 2024-2025
# these files were shared by Torrey Tyler (USBR)
#
# Each workbook has one tab per month (Sep ... Oct, newest first).
# Output: one data frame (tule_elev) with columns
#   date, tule_lake_elev_ft, water_year, sheet, file
# ============================================================


# ---- 1. Locate the files ------------------------------------------------
# Point this at the folder that holds the 13 workbooks.
data_dir <- "data-raw/raw-tule-lake-level-data"

files <- list.files(
  data_dir,
  pattern    = "^TID[ _]Daily[ _]Report[ _]WY[ _]\\d{4}-\\d{4}\\.xlsx$",
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(files) == 0) stop("No 'TID Daily Report WY ....xlsx' files found in ", data_dir)
message("Found ", length(files), " workbook(s).")

# ---- 2. Function to read one monthly sheet ------------------------------
read_month_sheet <- function(path, sheet) {

  raw <- read_excel(
    path, sheet = sheet,
    col_names = FALSE,           # read raw; we handle headers ourselves
    col_types = "list",          # keep mixed types (dates + text + totals)
    .name_repair = "minimal"
  )

  # Row 1 holds the headers ("DATE", ..., "TULE LAKE ELEV.", ...)
  headers <- map_chr(raw[1, ], ~ ifelse(is.null(.x[[1]]), NA_character_,
                                        as.character(.x[[1]])))

  date_col <- which(str_detect(str_to_upper(headers), "^DATE"))[1]
  elev_col <- which(str_detect(str_to_upper(headers), "TULE") &
                      str_detect(str_to_upper(headers), "ELEV"))[1]

  if (is.na(date_col) || is.na(elev_col)) {
    warning("Could not find DATE / TULE LAKE ELEV columns in ",
            basename(path), " | ", sheet, " - sheet skipped.")
    return(NULL)
  }

  # Pull the two columns as lists (cells are mixed types)
  date_cells <- raw[[date_col]]
  elev_cells <- raw[[elev_col]]

  # A cell is a real data row only if the DATE cell is a date/POSIXct.
  # This automatically drops the header row, the units row, the
  # "Monthly Total" / "WY Total" rows, and every table below.
  is_date <- map_lgl(date_cells, ~ inherits(.x[[1]], c("POSIXct", "POSIXt", "Date")))

  if (!any(is_date)) return(NULL)

  tibble(
    date = as.Date(map_vec(date_cells[is_date], ~ as.POSIXct(.x[[1]], tz = "UTC"))),
    tule_lake_elev_ft = map_dbl(elev_cells[is_date], function(cell) {
      val <- cell[[1]] %||% NA
      if (is.character(val)) {
        # Repair hand-entry typos, e.g. "4034..40" -> "4034.40"
        val <- str_replace_all(str_trim(val), "\\.{2,}", ".")
      }
      suppressWarnings(as.numeric(val))
    }),
    sheet = sheet,
    file  = basename(path)
  )
}

# ---- 3. Read every sheet of every workbook ------------------------------
tule_elev_raw <- map_dfr(files, function(path) {
  sheets <- excel_sheets(path)
  map_dfr(sheets, ~ read_month_sheet(path, .x))
})

# TODO note that 2021- 2025 are empty
# ---- 4. Clean & finalize ------------------------------------------------
tule_elev <- tule_elev_raw |>
  mutate(date = as.Date(date),
         location = "tule lake",
         gage_name = "usbr tule lake sump 1a surface elevations",
         gage_id = "usbr tule lake sump 1a",
         variable_name = "water level",
         value = tule_lake_elev_ft,
         unit = "ft above sea level - USBR datum",
         statistic = "mean") |>
  select(location, gage_name, gage_id, variable_name, value, unit, statistic, date) |> glimpse()


# earlier years
tule_elev_early <- readxl::read_excel("data-raw/raw-tule-lake-level-data/TID Elevation Report 1986-2012.xls") |>
  clean_names() |>
  select(-x3) |>
  slice(1:9179) |>
  mutate(date = as.Date(date),
         location = "tule lake",
         gage_name = "usbr tule lake sump 1a surface elevations",
         gage_id = "usbr tule lake sump 1a",
         variable_name = "water level",
         value = tlelev,
         unit = "ft above sea level - USBR datum",
         statistic = "mean") |> # TODO confirm that these values are mean
  select(location, gage_name, gage_id, variable_name, value, unit, statistic, date) |> glimpse()

#combine Tule data
tule_elevation <- bind_rows(tule_elev, tule_elev_early)



#### water data table ----
# join usbr tule lake data with usgs
water_level_data <- bind_rows(tule_elevation, water_level_data_usgs) |> glimpse()

#### water data gage table ----
water_level_gage <- water_level_gage_usgs |>
  add_row(location = "tule lake",
          gage_name = "usbr tule lake sump 1a surface elevations",
          gage_id = "usbr tule lake sump 1a",
          agency = "u.s. bureau of reclamation",
          latitude = NA_integer_,
          longitude = NA_integer_,
          huc8 = 18010203) |>
  glimpse()


### saves clean data to aws
# wq_processed_data <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1", prefix = "water_quality/processed-data/")
#
# # water level data
# wq_processed_data |> pins::pin_write(water_level_data,
#                                      type = "csv")
#
# # gage data
# wq_processed_data |> pins::pin_write(water_level_gage,
#                                      type = "csv")

# save rda files
usethis::use_data(water_level_data, overwrite = TRUE)
usethis::use_data(water_level_gage, overwrite = TRUE)

