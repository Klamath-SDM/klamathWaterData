library(tidyverse)
library(httr)
library(lubridate)

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
