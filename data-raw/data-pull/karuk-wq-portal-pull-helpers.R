library(httr)
library(dplyr)
library(purrr)
library(tibble)
library(lubridate)

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
