library(tidyverse)   # dplyr, purrr, tibble, stringr, readr, lubridate
library(httr)
library(xml2)
library(readxl)

# ============================================================
# Helper functions for the scripts in data-raw/data-pull/ - one file for all
# of them, so any pull script just does:
#   source("data-raw/data-pull/data-pull-helper-functions.R")
#
# Sections (alphabetical by source):
#   1. Anderson-Rose Dam - Tulelake Irrigation District daily report workbooks
#   2. Hoopa Valley Tribe - Hydromet portal (wxvisual.com)
#   3. Karuk Tribe - Water Quality portal (waterquality.karuk.us)
#   4. OWRD - near real time gage station feed
#   5. USBR - Hydromet archive and RISE locations
# ============================================================

# ====================================================================
# 1. Anderson-Rose Dam (TID daily report workbooks)
# ====================================================================

# ============================================================
# Readers for the Tulelake Irrigation District (TID) daily report workbooks
# in data-raw/anderson-rose-dam/, which carry Anderson-Rose Dam daily flow
# (cfs). Unlike the other flow sources this is not an API pull - the
# workbooks are shared as files. Shared by flow-data-pull.R; the cleaning
# (date repair, overlap handling) happens in flow-process-data.R.
# data-raw/data-exploration/anderson-rose-dam-flow.Rmd walks through the QA
# behind the choices made here and there.
#
# The workbooks come in two layouts:
#   - "Daily YYYY.xls(x)" (1996-2011): one workbook per calendar year, with
#     Anderson-Rose on the "SPILL" tab as one grid of days (rows) by months
#     (columns).
#   - "TID Daily Report ... WY.xls(x)" (WY 2011-12 onward): one workbook per
#     water year (Oct-Sep), one tab per month, Anderson-Rose in the
#     "ANDERSON-ROSE" column (a couple of tabs call it "ANDERSON-ROSE SPILL").
# ============================================================

anderson_rose_month_abb <- c(JAN = 1, FEB = 2, MAR = 3, APR = 4, MAY = 5, JUN = 6,
                             JUL = 7, AUG = 8, SEP = 9, OCT = 10, NOV = 11, DEC = 12)

# One older workbook's SPILL tab -> one row per cell of the days x months grid
# (so days that don't exist, like Feb 30, are still present; they're dropped
# when the dates are built in flow-process-data.R). sheet_month_total is the
# tab's own "CFS" monthly total row, kept so the parse can be reconciled
# against it (see the Rmd).
read_anderson_rose_spill_tab <- function(path) {
  year <- as.integer(str_extract(basename(path), "\\d{4}"))
  raw  <- read_excel(path, sheet = "SPILL", col_names = FALSE, col_types = "text",
                     .name_repair = "minimal")

  # The title carries the year too. Several newer tabs turned out to have a
  # template copied forward without updating the year, so confirm the two
  # agree rather than assume.
  title_year <- as.integer(str_extract(raw[[1]][1], "\\d{4}"))
  if (!identical(year, title_year)) stop(basename(path), ": title year ", title_year, " != file year ", year)

  header_row <- which(str_to_upper(trimws(raw[[1]])) == "DAY")[1]
  day_rows   <- header_row + 1:31
  if (!identical(suppressWarnings(as.integer(raw[[1]][day_rows])), 1:31)) {
    stop(basename(path), ": the 31 rows under the DAY header are not days 1-31")
  }

  header     <- str_to_upper(trimws(unlist(raw[header_row, ])))
  month_cols <- which(header %in% names(anderson_rose_month_abb))
  cfs_row    <- which(str_to_upper(trimws(raw[[1]])) == "CFS")[1]

  map_dfr(month_cols, function(col) {
    tibble(
      year = year, month = unname(anderson_rose_month_abb[header[col]]), day = 1:31,
      value = suppressWarnings(as.numeric(raw[[col]][day_rows])),
      sheet_month_total = suppressWarnings(as.numeric(raw[[col]][cfs_row])),
      source_file = basename(path)
    )
  })
}

# One monthly tab of a newer workbook -> one row per day row on the tab.
# date_as_entered is the date cell exactly as typed: it is NOT reliable (a
# handful of tabs have a template copied forward with the year or even the
# whole month's dates left stale), so the tab name is carried alongside
# (tab_year / tab_month) for flow-process-data.R to repair the dates with.
#
# Anderson-Rose is found by matching "ANDERSON" in the header row rather than
# by position: some workbooks have an extra LRDC column before STATION 48.
# Real data rows are the ones whose first cell is an actual date; the footer
# rows under them (Monthly Total, Acre Feet, WY Total, ...) are text.
# Tabs not named like a month (the empty "Sheet1" tabs) are skipped.
read_anderson_rose_month_tab <- function(path, sheet) {
  tab_start <- parse_date_time(sheet, "b Y", quiet = TRUE)   # "Oct 2012"
  if (is.na(tab_start)) return(NULL)

  raw <- read_excel(path, sheet = sheet, col_names = FALSE, col_types = "list",
                    .name_repair = "minimal")
  if (nrow(raw) < 3) return(NULL)

  cell_text <- function(cell) if (is.null(cell[[1]]) || is.na(cell[[1]])) NA_character_ else as.character(cell[[1]])
  header    <- map_chr(raw[1, ], cell_text)

  date_col <- which(str_detect(str_to_upper(header), "^DATE"))[1]
  ar_col   <- which(str_detect(str_to_upper(header), "ANDERSON"))[1]
  if (is.na(date_col) || is.na(ar_col)) stop("No DATE / ANDERSON column in ", basename(path), " | ", sheet)

  # Row 2 of every tab is a units row ("(in CFS)") - carried through so a
  # workbook that ever switched units doesn't get stacked in silently.
  units <- cell_text(raw[[ar_col]][2])
  if (!isTRUE(str_detect(str_to_upper(units), "CFS"))) {
    warning(basename(path), " | ", sheet, ": units under the Anderson-Rose column are '", units, "', not CFS")
  }

  is_date <- map_lgl(raw[[date_col]], ~ inherits(.x[[1]], c("POSIXct", "POSIXt", "Date")))

  tibble(
    source_file     = basename(path),
    tab             = sheet,
    tab_year        = year(tab_start),
    tab_month       = month(tab_start),
    units           = units,
    date_as_entered = as.Date(map_vec(raw[[date_col]][is_date], ~ as.POSIXct(.x[[1]], tz = "UTC"))),
    value           = map_dbl(raw[[ar_col]][is_date], function(cell) suppressWarnings(as.numeric(cell[[1]] %||% NA)))
  )
}

# Reads every workbook in `dir`: both layouts are picked up by file name, so a
# newly added workbook (e.g. the next water year's) is read with no changes here.
read_anderson_rose_workbooks <- function(dir) {
  spill_files <- list.files(dir, pattern = "^Daily \\d{4}\\.xlsx?$", full.names = TRUE)
  month_files <- list.files(dir, pattern = "^TID Daily Report.*\\.xlsx?$", full.names = TRUE)

  list(
    spill = map_dfr(spill_files, read_anderson_rose_spill_tab),
    month = map_dfr(month_files, function(f) map_dfr(excel_sheets(f), ~ read_anderson_rose_month_tab(f, .x)))
  )
}

# ====================================================================
# 2. Hoopa Valley Tribe Hydromet portal
# ====================================================================

# ============================================================
# Shared helper for the Hoopa Valley Tribe's Hydromet portal
# (wxvisual.com/HoopaValley), a custom real-time water
# quality dashboard. No login/session is required.
#
# this one has no JSON data API at all - the
# Graph.php endpoint returns a full HTML page whose embedded Dygraph chart
# is initialized from a JS string literal:
#   var ress= '"Date,<parameter>\n<timestamp>,<value>\n...."';
# fetch_hoopa_station() pulls that page and extracts/parses this embedded
# CSV rather than scraping the rendered chart.
#
# A single request can return the entire period of record in one shot (no
# pagination/chunking needed - tested at 51,687 rows / ~6 years in ~3
# seconds), unlike the Karuk portal which required year-chunking.
#
# NOTE: per the portal's own disclaimer ("Data is provisional and is
# subject to revision. Not to be used as official record"), get sign-off
# from the Hoopa Valley Tribe before this data is used in anything
# published or operational.
# ============================================================

HOOPA_WQ_BASE_URL <- "https://wxvisual.com/HoopaValley"

fetch_hoopa_station <- function(station, parameter, start_date, end_date) {
  resp <- tryCatch(
    GET(
      paste0(HOOPA_WQ_BASE_URL, "/Graph.php"),
      query = list(
        FY      = format(start_date, "%Y"),
        FM      = format(start_date, "%m"),
        FD      = format(start_date, "%d"),
        TY      = format(end_date, "%Y"),
        TM      = format(end_date, "%m"),
        TD      = format(end_date, "%d"),
        PARAMS  = parameter,
        hours   = "undefined",
        station = station,
        hours2  = as.integer(difftime(end_date, start_date, units = "hours"))
      ),
      timeout(120)
    ),
    error = function(e) { warning("  HTTP error: ", conditionMessage(e)); NULL }
  )
  if (is.null(resp) || status_code(resp) != 200) {
    return(tibble(timestamp = character(), value = double()))
  }

  html <- content(resp, as = "text", encoding = "UTF-8")

  m <- str_match(html, "var ress= '(.*?)';")
  if (is.na(m[1, 2])) return(tibble(timestamp = character(), value = double()))

  csv_text <- m[1, 2] |>
    str_replace_all(fixed("\\n"), "\n") |>
    str_replace_all(fixed("\\\""), "\"") |>
    str_remove_all('^"|"$')

  parsed <- suppressWarnings(
    read_csv(csv_text, col_names = c("timestamp", "value"), skip = 1,
             col_types = "cd", show_col_types = FALSE)
  )
  parsed
}

# ====================================================================
# 3. Karuk Tribe Water Quality portal
# ====================================================================

# ============================================================
# Shared helper for the Karuk Tribe Water Quality portal
# (waterquality.karuk.us), an Aquatic Informatics AQUARIUS WebPortal
# instance that aggregates continuous sonde data from the Karuk Tribe,
# Yurok Tribe (YTEP), and co-located USGS gages along the Klamath
# mainstem. No login/session is required - the portal's internal data-grid
# endpoint works statelessly (verified against a fresh, cookie-less
# session), it's just not a documented/public API.
#
# NOTE: per the portal's own disclaimer ("All Data Provisional. Do Not
# Cite without Karuk Tribe consent."), get sign-off from Karuk Tribe /
# KBMP before this data is used in anything published or operational.
# ============================================================

KARUK_WQ_BASE_URL <- "https://waterquality.karuk.us"

# Fetches one page of /Data/DatasetGrid for a bounded date range. Kept
# separate from the year-chunking/pagination loop below so a single slow or
# hung request can be retried without re-fetching everything.
#
# The portal's response time was observed to vary a lot between otherwise
# identical requests during testing (most pages return in ~2s, but some
# stall well past a 30s timeout) - most likely a lightly-provisioned
# tribal-government server rather than anything wrong with the request
# itself. Retries with backoff (10s, 20s, 30s) rather than giving up
# immediately, since a slow response is far more likely here than a
# genuinely bad request.
fetch_karuk_page <- function(dataset_id, start_date, end_date, page, page_size, max_attempts = 3) {
  for (attempt in seq_len(max_attempts)) {
    resp <- tryCatch(
      GET(
        paste0(KARUK_WQ_BASE_URL, "/Data/DatasetGrid"),
        query = list(
          dataset  = dataset_id,
          sort     = "TimeStamp-asc",
          page     = page,
          pageSize = page_size,
          interval = "Custom",
          timezone = -480,
          date     = format(start_date, "%Y-%m-%d"),
          endDate  = format(end_date, "%Y-%m-%d"),
          calendar = 1,
          alldata  = "false",
          virtual  = "true"
        ),
        timeout(30)
      ),
      error = function(e) { message("    attempt ", attempt, " failed: ", conditionMessage(e)); NULL }
    )
    if (!is.null(resp) && status_code(resp) == 200) {
      return(tryCatch(httr::content(resp, as = "parsed", type = "application/json"), error = function(e) NULL))
    }
    if (attempt < max_attempts) Sys.sleep(attempt * 10)
  }
  NULL
}

# Pulls every reading for one dataset (one parameter at one station) across
# [start_date, end_date] as a tibble of timestamp/value/approval.
#
# Requests are chunked by calendar year rather than issued as one
# continuous multi-decade range: a query spanning ~25 years (hundreds of
# thousands of underlying readings) was observed to hang the server-side
# query entirely, while single-year windows (tens of thousands of readings)
# consistently returned in well under a second. Each year is still paged
# within itself in case it exceeds `page_size`.
fetch_karuk_dataset <- function(dataset_id, start_date, end_date, page_size = 5000) {
  year_starts <- seq(as.Date(paste0(year(start_date), "-01-01")), end_date, by = "year")
  all_years <- list()

  for (year_start in year_starts) {
    year_start <- as.Date(year_start, origin = "1970-01-01")
    chunk_start <- max(year_start, start_date)
    chunk_end   <- min(as.Date(paste0(year(year_start), "-12-31")), end_date)
    if (chunk_start > chunk_end) next

    message("  ", format(chunk_start, "%Y"), "...")
    page <- 1
    year_rows <- list()

    repeat {
      parsed <- fetch_karuk_page(dataset_id, chunk_start, chunk_end, page, page_size)
      if (is.null(parsed) || length(parsed$Data) == 0) break

      # Vectorized across the whole page instead of map_dfr()'s one-tibble-
      # per-row pattern, which benchmarked at >100x slower here (4.7s vs
      # 0.04s for a 5,000-row page) - that difference is what made the
      # original row-by-row version of this pull effectively hang on
      # decades-long stations.
      year_rows[[page]] <- tibble(
        timestamp = map_chr(parsed$Data, "TimeStamp"),
        # some readings come back as the JSON string "NaN" rather than a
        # numeric literal - as.numeric() turns that into a real NA/NaN
        # instead of leaving the column as character and breaking
        # bind_rows once a later page mixes in real numbers.
        value     = suppressWarnings(as.numeric(map_chr(parsed$Data, ~ as.character(.x$Value %||% NA)))),
        approval  = map_chr(parsed$Data, "Approval")
      )

      if (page * page_size >= parsed$Total) break
      page <- page + 1
      Sys.sleep(0.5) # be polite to a small tribal-government server
    }

    if (length(year_rows) > 0) all_years[[length(all_years) + 1]] <- bind_rows(year_rows)
  }

  if (length(all_years) == 0) return(tibble(timestamp = character(), value = double(), approval = character()))
  bind_rows(all_years)
}

# Lists every dataset (parameter) available at one station, with its
# portal-internal numeric location id (from GetDropDownAll's IDNumber).
fetch_karuk_datasets <- function(location_id) {
  resp <- GET(paste0(KARUK_WQ_BASE_URL, "/Data/DataSets"), query = list(locationid = location_id), timeout(30))
  if (status_code(resp) != 200) return(NULL)
  content(resp, as = "parsed", type = "application/json") |>
    map_dfr(function(d) {
      tibble(
        parameter  = d$ParameterName,
        source     = d$Id,
        dataset_id = d$IDNumber,
        start      = d$StartTime,
        end        = d$EndTime
      )
    })
}

# ====================================================================
# 4. OWRD near real time gage stations
# ====================================================================

# ------------------------------------------------------------
# Live lat/long lookup for OWRD "near real time" gaging stations, via
# OWRD's own KML station feed, so coordinates don't have to be
# hand-transcribed. Used by flow-data-pull.R and temperature-data-pull.R.
# ------------------------------------------------------------
fetch_owrd_coord <- function(station_nbr) {
  url <- paste0(
    "https://apps.wrd.state.or.us/apps/sw/hydro_near_real_time/near_real_time_gage_station_kml.aspx",
    "?sn_start=", station_nbr
  )
  kml <- xml2::read_xml(content(GET(url), as = "text", encoding = "UTF-8"))
  for (pm in xml2::xml_find_all(kml, ".//Placemark")) {
    desc <- xml2::xml_text(xml2::xml_find_first(pm, ".//description"))
    if (grepl(paste0("Station Number: ", station_nbr, "<br>"), desc, fixed = TRUE)) {
      coords <- strsplit(trimws(xml2::xml_text(xml2::xml_find_first(pm, ".//coordinates"))), ",")[[1]]
      return(tibble(site = station_nbr, long = as.numeric(coords[1]), lat = as.numeric(coords[2])))
    }
  }
  tibble(site = station_nbr, long = NA_real_, lat = NA_real_)
}

# ====================================================================
# 5. USBR Hydromet archive and RISE locations
# ====================================================================

# ============================================================
# Shared USBR Hydromet historical archive (webarccsv.pl) pull/parse
# helpers. Extracted from teacup-diagram-data-pull.R so lake-levels
# and flow pull scripts can reuse the exact same mechanism instead of
# re-implementing it.
# ============================================================

BASE_URL  <- "https://www.usbr.gov/pn-bin/webarccsv.pl"
SLEEP_SEC <- 1
UA <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

parse_webarccsv <- function(raw_text, station_params) {
  lines <- strsplit(raw_text, "\n")[[1]]

  begin_idx <- which(grepl("^BEGIN DATA", lines, ignore.case = TRUE))
  if (length(begin_idx) == 0) {
    message("  [parse] No 'BEGIN DATA' marker found")
    return(NULL)
  }

  data_lines <- lines[(begin_idx + 1):length(lines)]
  data_lines <- data_lines[nzchar(trimws(data_lines))]
  if (length(data_lines) < 2) return(NULL)

  header_line <- data_lines[1]
  data_lines  <- data_lines[-1]

  col_names <- trimws(strsplit(header_line, ",")[[1]])

  df_raw <- tryCatch(
    read.csv(
      text             = paste(data_lines, collapse = "\n"),
      header           = FALSE,
      col.names        = col_names,
      colClasses       = "character",
      stringsAsFactors = FALSE,
      fill             = TRUE,
      strip.white      = TRUE
    ),
    error = function(e) {
      message("  [parse] read.csv error: ", conditionMessage(e))
      NULL
    }
  )
  if (is.null(df_raw) || ncol(df_raw) < 2) return(NULL)

  date_col     <- col_names[1]
  dates_parsed <- mdy(trimws(df_raw[[date_col]]))
  n_dates      <- length(dates_parsed)
  df_col_names <- names(df_raw)

  find_col <- function(site, param) {
    key_space <- paste(site, param)
    key_dot   <- paste(site, param, sep = ".")
    m <- which(col_names == key_space)
    if (length(m) > 0) return(df_col_names[m[1]])
    m <- which(df_col_names == key_dot)
    if (length(m) > 0) return(df_col_names[m[1]])
    m <- which(toupper(df_col_names) == toupper(key_dot))
    if (length(m) > 0) return(df_col_names[m[1]])
    m <- which(grepl(site, df_col_names, ignore.case = TRUE) &
                 grepl(param, df_col_names, ignore.case = TRUE))
    if (length(m) > 0) return(df_col_names[m[1]])
    NA_character_
  }

  long_list <- lapply(seq_len(nrow(station_params)), function(i) {
    row       <- station_params[i, ]
    col_match <- find_col(row$site, row$parameter)
    if (is.na(col_match)) return(NULL)

    vals <- suppressWarnings(as.numeric(trimws(df_raw[[col_match]])))
    if (length(vals) != n_dates) vals <- rep(NA_real_, n_dates)

    tibble(
      site         = row$site,
      parameter    = row$parameter,
      label        = row$label,
      lat          = row$lat,
      long         = row$long,
      date         = dates_parsed,
      value        = vals
    )
  })

  long_list <- Filter(Negate(is.null), long_list)
  if (length(long_list) == 0) return(NULL)

  bind_rows(long_list) |> filter(!is.na(date))
}

# ------------------------------------------------------------
# Live lat/long lookup for USBR Hydromet/RISE Klamath Basin stations, so
# coordinates don't have to be hand-transcribed and can be re-pulled.
# RISE catalogs each station (Hydromet cbtt or RISE-only) as a
# "catalog-record" under the "Klamath Basin Water Operations Monitoring"
# generation effort (id 503); each record's title ends in "(<cbtt>) Water
# Operations Monitoring..." and links to a location with coordinates.
# ------------------------------------------------------------

fetch_rise_klamath_locations <- function(generation_effort_id = 503) {
  resp <- GET("https://data.usbr.gov/rise/api/catalog-record",
              query = list(generationEffortId = generation_effort_id))
  records <- content(resp, as = "parsed", type = "application/json")$data

  map_dfr(records, function(rec) {
    site <- str_match(rec$attributes$recordTitle,
                       "\\(([A-Z0-9]{2,6})\\)\\s+Water Operations Monitoring")[, 2]
    loc_path <- rec$relationships$location$data$id
    if (is.na(site) || is.null(loc_path)) return(NULL)

    loc_resp <- GET(paste0("https://data.usbr.gov", loc_path))
    loc <- content(loc_resp, as = "parsed", type = "application/json")$data$attributes
    coords <- loc$locationCoordinates$coordinates

    tibble(site = site, lat = coords[[2]], long = coords[[1]])
  })
}

fetch_usbr_batch <- function(batch_df, start_date, end_date) {
  param_string <- paste(paste(batch_df$site, batch_df$parameter), collapse = ",")
  message("Fetching USBR Hydromet batch: ", paste(unique(batch_df$site), collapse = ", "))

  resp <- tryCatch(
    GET(
      BASE_URL,
      query = list(
        parameter = param_string,
        syer      = year(start_date),  smnth = month(start_date), sdy = day(start_date),
        eyer      = year(end_date),    emnth = month(end_date),   edy = day(end_date),
        format    = "2"
      ),
      add_headers(`User-Agent` = UA, `Referer` = "https://www.usbr.gov/pn/hydromet/klamath/teacup.html"),
      timeout(120)
    ),
    error = function(e) { warning("  HTTP error: ", conditionMessage(e)); NULL }
  )
  Sys.sleep(SLEEP_SEC)

  if (is.null(resp) || status_code(resp) != 200) return(NULL)
  parse_webarccsv(content(resp, as = "text", encoding = "UTF-8"), batch_df)
}
