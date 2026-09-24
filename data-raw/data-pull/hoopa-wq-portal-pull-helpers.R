library(httr)
library(dplyr)
library(stringr)
library(readr)
library(tibble)

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
