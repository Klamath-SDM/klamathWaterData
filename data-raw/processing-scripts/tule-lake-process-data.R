# ============================================================
# Combine Tule Lake (Tule Sumps) daily elevation data
# from TID Daily Report workbooks, WY 2012-2013 ... WY 2024-2025
# these files were shared by Torrey Tyler (USBR)
#
# Each workbook has one tab per month (Sep ... Oct, newest first).
# Output: one data frame (tule_elev) with columns
#   date, tule_lake_elev_ft, water_year, sheet, file
# ============================================================

library(readxl)
library(dplyr)
library(purrr)
library(stringr)

# ---- 1. Locate the files ------------------------------------------------
# Point this at the folder that holds the 13 workbooks.
data_dir <- "data-raw/raw-tule-lake-level-data"   # <-- change to your folder, e.g. "C:/Users/you/TID_data"

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
  # distinct(date, .keep_all = TRUE) |>          # guard against duplicated days
  # arrange(date) |>
  mutate(
    # Water year: Oct-Dec belong to the following WY (e.g. Oct 2012 -> WY 2013)
    #TODO check if water year is set appropiately
    water_year = ifelse(as.integer(format(date, "%m")) >= 10,
                        as.integer(format(date, "%Y")) + 1L,
                        as.integer(format(date, "%Y")))
  ) |>
  mutate(location = "tule lake",
         gage_name = "usbr tule lake sump 1a surface elevations",
         # gage_id = NA,
         variable_name = "water level",
         value = tule_lake_elev_ft,
         unit = "ft above sea level - USBR datum",
         statistic = "mean") |>
  select(location, gage_name, variable_name, value, unit, statistic, date) |> glimpse()


# earlier years
tule_elev_early <- readxl::read_excel("data-raw/raw-tule-lake-level-data/TID Elevation Report 1986-2012.xls") |>
  clean_names() |>
  select(-x3) |>
  mutate(location = "tule lake",
         gage_name = "usbr tule lake sump 1a surface elevations",
         # gage_id = NA, # decide if we want this
         variable_name = "water level",
         value = tlelev,
         unit = "ft above sea level - USBR datum",
         statistic = "mean") |>
  select(location, gage_name, variable_name, value, unit, statistic, date) |> glimpse()

#combine data
tule_elevation <- bind_rows(tule_elev, tule_elev_early)

# save the combined data
usethis::use_data(tule_elevation, overwrite = TRUE)
