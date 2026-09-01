library(tidyverse)
library(purrr)
library(janitor)
library(rivermile)
library(sf)
library(readxl)
library(stringr)

# These data is originally retrieved on lake-level-data-pull.R
# Additionally, this script pulls and process data for water elevation at Tule Sumps provided by Torrey Tyler (USBR)
# both datasets are combined into water_level_data.rda

source("data-raw/data-pull/lake-levels-data-pull.R")

# USGS ----
## water level data
water_level_data <- water_level_data |>
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

## GAGE data
water_level_gage_data <- water_level_gage_data |>
  janitor::clean_names() |>
  mutate(station_nm = tools::toTitleCase(tolower(station_nm))) |>
  glimpse()

# JOIN - station data with temp data
all_usgs_water_level_raw <- water_level_data_raw_clean |> left_join(water_level_gage_data, by = "site_no") |>
  select(c(agency_cd.x, site_no, date, gage_id, statistic, value, variable_name,
           unit, station_nm, dec_lat_va, dec_long_va, huc_cd)) |>
  mutate(waterbody_name = "upper klamath lake") |>
  glimpse()

### water data table usgs ----
water_level_data_usgs <- all_usgs_water_level_raw |>
  mutate(gage_id = as.character(site_no),
         gage_name = tolower(station_nm),
         stream = waterbody_name) |>
  select(stream, gage_name, gage_id, variable_name, value, unit, statistic, date) |>
  rename(location = stream) |>
  glimpse()

### monitoring site table usgs ----
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

# USBR Hydromet - Gerber, Malone, Tule Lake Sump 1A/1B, Clear Lake West/East
# Lobe (from teacup diagram; see lake-levels-data-pull.R) ----
water_level_data_usbr_hydromet <- usbr_hydromet_elev_raw |>
  mutate(
    location = case_when(
      site == "GER"   ~ "gerber reservoir",
      site == "MAL"   ~ "malone reservoir",
      site %in% c("TULC", "TULC2") ~ "tule lake",
      site %in% c("CLK", "LRS") ~ "clear lake"
    ),
    gage_id = case_when(
      site == "GER"   ~ "usbr-ger",
      site == "MAL"   ~ "usbr-mal",
      site == "TULC"  ~ "usbr-tulc",
      site == "TULC2" ~ "usbr-tulc2",
      site == "CLK"   ~ "usbr-clk",
      site == "LRS"   ~ "usbr-lrs"
    ),
    gage_name = case_when(
      site == "GER"   ~ "gerber reservoir forebay elevation",
      site == "MAL"   ~ "malone reservoir gage height",
      site == "TULC"  ~ "usbr tule lake sump 1a surface elevations",
      site == "TULC2" ~ "tule lake sump 1b surface elevations",
      site == "CLK"   ~ "clear lake west lobe forebay elevation",
      site == "LRS"   ~ "clear lake east lobe forebay elevation"
    ),
    variable_name = "water level",
    unit = "feet above sea level - usbr datum",
    statistic = "mean") |>
  select(location, gage_name, gage_id, variable_name, value, unit, statistic, date) |>
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
         gage_name = "tule lake sump 1a surface elevations",
         gage_id = "usbr-tulc",
         variable_name = "water level",
         value = tule_lake_elev_ft,
         unit = "feet above sea level - USBR datum",
         statistic = "mean") |>
  select(location, gage_name, gage_id, variable_name, value, unit, statistic, date) |> glimpse()


# earlier years
tule_elev_early <- readxl::read_excel("data-raw/raw-tule-lake-level-data/TID Elevation Report 1986-2012.xls") |>
  clean_names() |>
  select(-x3) |>
  slice(1:9179) |>
  mutate(date = as.Date(date),
         location = "tule lake",
         gage_name = "tule lake sump 1a surface elevations",
         gage_id = "usbr-tulc",
         variable_name = "water level",
         value = tlelev,
         unit = "feet above sea level - USBR datum",
         statistic = "mean") |> # TODO confirm that these values are mean
  select(location, gage_name, gage_id, variable_name, value, unit, statistic, date) |> glimpse()

#combine Tule data
# TULC (from usbr_hydromet_elev_raw, via the teacup diagram pull) is the same
# physical gage as the TID-report-derived series above ("usbr tule lake sump
# 1a") - union them into one continuous series. distinct() guards against
# date overlap (there's none today: TID data ends 2021-07-05, TULC starts
# 2024-04-15) should the two source windows ever grow to overlap.
tule_elevation <- bind_rows(
  tule_elev,
  tule_elev_early,
  water_level_data_usbr_hydromet |> filter(gage_id == "usbr-tulc")
) |>
  distinct(gage_id, date, .keep_all = TRUE)



#### water data table ----
# join usbr tule lake data with usgs
water_level_data <- bind_rows(
  tule_elevation,
  water_level_data_usgs,
  water_level_data_usbr_hydromet |> filter(gage_id != "usbr-tulc")
) |>
  # Tule Lake Sump 1A/1B (usbr-tulc/usbr-tulc2) each have a handful of
  # physically-impossible sentinel/data-entry errors (e.g. 998877 ft,
  # 40235 ft, 3035 ft, against a true range of ~4030-4036 ft). Scoped to
  # just these two gages so it doesn't also strip Malone's legitimate
  # gage-height readings (a few feet, not an elevation in the thousands).
  filter(!(gage_id %in% c("usbr-tulc", "usbr-tulc2") & !(value > 3500 & value < 10000))) |>
  filter(!is.na(value)) |>
  glimpse()

ggplot(data = water_level_data, aes(x = date, y = value)) +
  geom_line() +
  facet_wrap(~gage_id, scales = "free") +
  theme_minimal()

#### water data gage table ----
# lat/long pulled live via rise_klamath_locations (see lake-levels-data-pull.R)
# rather than hand-transcribed, so they stay accurate/reproducible.
rise_coord <- function(site_code, field) {
  rise_klamath_locations[[field]][rise_klamath_locations$site == site_code]
}

# huc8 for the USBR Hydromet gages determined by spatial join against
# rivermile::klamath_hucs (point-in-polygon on each gage's lat/long), rather
# than hand-transcribed - this caught Tule Lake's huc8 having been wrong
# (hardcoded "18010203"/Upper Klamath Lake; it's actually in "18010204"/Lost,
# same basin as Clear Lake, Gerber, and Malone) and fills in Gerber/Malone,
# which had no huc8 at all before.
usbr_hydromet_huc8 <- usbr_hydromet_elev_stations |>
  st_as_sf(coords = c("long", "lat"), crs = 4326, remove = FALSE) |>
  st_join(klamath_hucs |> st_transform(4326), join = st_intersects) |>
  st_drop_geometry() |>
  select(site, huc8)

huc_coord <- function(site_code) {
  usbr_hydromet_huc8$huc8[usbr_hydromet_huc8$site == site_code]
}

water_level_gage <- water_level_gage_usgs |>
  add_row(location = "tule lake",
          gage_name = "tule lake sump 1a surface elevations",
          gage_id = "usbr-tulc",
          agency = "u.s. bureau of reclamation",
          latitude = rise_coord("TULC", "lat"),
          longitude = rise_coord("TULC", "long"),
          huc8 = huc_coord("TULC")) |>
  add_row(location = "tule lake",
          gage_name = "tule lake sump 1b surface elevations",
          gage_id = "usbr-tulc2",
          agency = "u.s. bureau of reclamation",
          latitude = rise_coord("TULC2", "lat"),
          longitude = rise_coord("TULC2", "long"),
          huc8 = huc_coord("TULC2")) |>
  add_row(location = "gerber reservoir",
          gage_name = "gerber reservoir forebay elevation",
          gage_id = "usbr-ger",
          agency = "u.s. bureau of reclamation",
          latitude = rise_coord("GER", "lat"),
          longitude = rise_coord("GER", "long"),
          huc8 = huc_coord("GER")) |>
  add_row(location = "malone reservoir",
          gage_name = "malone reservoir gage height",
          gage_id = "usbr-mal",
          agency = "u.s. bureau of reclamation",
          latitude = rise_coord("MAL", "lat"),
          longitude = rise_coord("MAL", "long"),
          huc8 = huc_coord("MAL")) |>
  add_row(
    location = "clear lake",
    gage_name = "clear lake west lobe forebay elevation",
    gage_id = "usbr-clk",
    agency = "u.s. bureau of reclamation",
    latitude = rise_coord("CLK", "lat"),
    longitude = rise_coord("CLK", "long"),
    huc8 = huc_coord("CLK")) |>
  add_row(
    location = "clear lake",
    gage_name = "clear lake east lobe forebay elevation",
    gage_id = "usbr-lrs",
    agency = "u.s. bureau of reclamation",
    latitude = rise_coord("LRS", "lat"),
    longitude = rise_coord("LRS", "long"),
    huc8 = huc_coord("LRS")) |>
  mutate(huc8 = as.numeric(huc8)) |>
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

