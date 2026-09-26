library(httr)
library(dplyr)
library(purrr)
library(tibble)
library(lubridate)

# Karuk Tribe Water Quality portal -----------

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


# ----------- Hoopa helper functions ----------------

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

# ----------- OWRD helper functions ----------------


# ------------------------------------------------------------
# Live lat/long lookup for OWRD "near real time" gaging stations, via
# OWRD's own KML station feed, so coordinates don't have to be
# hand-transcribed. Shared by flow-data-pull.R and
# temperature-process-data.R.
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
