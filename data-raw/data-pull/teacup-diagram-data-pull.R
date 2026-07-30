library(tidyverse)
library(httr)
library(lubridate)
library(dataRetrieval)

# ============================================================
# Klamath "Teacup" Diagram — Elevation & Flow Data Pull
#
# Source diagram: https://www.usbr.gov/pn/hydromet/klamath/teacup.html
#   "Major Storage Reservoirs in the Klamath River Basin"
#
# The diagram is an HTML image map. Its embedded <area> links point to
# three different data providers:
#   1. USBR Hydromet stations  (kinstant_graph.html?cbtt=<site>&pcode=<param>)
#      -> pulled here via the Hydromet archive CSV API (webarccsv.pl).
#         Supersedes the old hydromet-data-pull.R / hydromet_data dataset,
#         which pulled a broader but less-curated station list from the
#         same API.
#   2. USGS NWIS gauges        (waterdata.usgs.gov/nwis/uv?site_no=...&parm_cd=...)
#      -> pulled here via dataRetrieval::readNWISdv
#   3. Oregon Water Resources Dept "near real time" stations
#      (apps.wrd.state.or.us/apps/sw/hydro_near_real_time) — SF Sprague River
#      nr Bly (11495600) and NF Sprague River (11495900). Neither has a usable
#      USGS NWIS record (11495600 doesn't exist in NWIS; 11495900 exists but
#      has zero IV/DV records), so both are pulled directly from OWRD via
#      whychusModel::get_owrd_hydro() instead.
#
# Agrimet weather-station links (KFLO, AGKO, BATO, LORO, WRDO) on the
# diagram are excluded — they report weather, not elevation/flow.
# ============================================================

START_DATE <- as.Date("1990-10-01")
END_DATE   <- Sys.Date() - 1

# ------------------------------------------------------------
# 1. USBR Hydromet stations embedded in the teacup diagram
#    (site/cbtt, pcode, label, measure_type)
#
# NOTE: The teacup diagram's circles link to *real-time* pcodes
# (e.g. "Q", "GH", "QC2") via kinstant_graph.html / pn-bin/instant.pl.
# The bulk historical archive (webarccsv.pl, used below) stores most
# of these under their daily-value pcode instead (confirmed against
# the archive: "LRS Q" -> "LRS QD", "HRPO Q" -> "HRPO QD",
# "MAL GH" -> "MAL GD", "LVNO QC2" -> "LVNO QJ", "LRDO QC" -> "LRD QD").
# Three teacup circles are real-time telemetry only with NO daily
# archive record at all (verified against webarccsv.pl) and are
# excluded here: Willow Creek (WILC Q/FB), Station 48 (S48O Q), and
# West Canal at Malone (MAL QC). Pull those via pn-bin/instant.pl
# directly if current/near-real-time values are needed.
# ------------------------------------------------------------

# lat/long sourced from the USBR RISE API (data.usbr.gov/rise/api/location),
# which catalogs each Hydromet cbtt under a named Reclamation location.
# NOTE: LRD ("Lost River Reservoir and Diversion Dam", RISE id 7307) is used
# as the archived-data proxy for the teacup's "LRDO" circle, but RISE shows
# these are technically two distinct points ~0.6 mi apart along the same
# channel: LRDO is "Lost River Diversion Channel at C-G Canal Crossing"
# (RISE id 7324, 42.140669 / -121.682313) downstream of the LRD dam site
# used here (42.142822 / -121.672895).
usbr_stations <- tribble(
  ~site,   ~parameter, ~label,                                            ~measure_type, ~lat,       ~long,
  "GER",   "FB",       "Gerber Reservoir - Forebay Elevation (ft)",       "Elevation",   42.201271, -121.129795,
  "GER",   "AF",       "Gerber Reservoir - Storage (acre-ft)",            "Storage",     42.201271, -121.129795,
  "CLK",   "FB",       "Clear Lake West Lobe - Forebay Elevation (ft)",   "Elevation",   41.846626, -121.209623,
  "CLK",   "AF",       "Clear Lake West Lobe - Storage (acre-ft)",        "Storage",     41.846626, -121.209623,
  "MAL",   "GD",       "Malone Reservoir - Gage Height (ft)",             "Elevation",   42.005769, -121.223952,
  "TULC",  "FB",       "Tule Lake Sump 1A - Forebay Elevation (ft)",      "Elevation",   41.878620, -121.545291,
  "TULC2", "FB",       "Tule Lake Sump 1B - Forebay Elevation (ft)",      "Elevation",   41.853279, -121.492546,
  "LVNO",  "QJ",       "Langell Valley North Canal - Flow (cfs)",         "Flow",        42.134649, -121.198025,
  "MHPO",  "QP",       "Miller Hill Pump Plant - Flow (cfs)",             "Flow",        42.142778, -121.751389,
  "LRD",   "QD",       "Lost River Diversion - Flow (cfs)",               "Flow",        42.142822, -121.672895,
  "HRPO",  "QD",       "Lost River at Harpold Dam - Flow (cfs)",          "Flow",        42.169507, -121.453355,
  "LRS",   "QD",       "Clear Lake East Lobe / Lost River - Flow (cfs)",  "Flow",        41.926030, -121.075876,
  "CHRO",  "QD",       "Cherry Creek - Flow (cfs)",                       "Flow",        42.598333, -122.095556
)

BASE_URL  <- "https://www.usbr.gov/pn-bin/webarccsv.pl"
SLEEP_SEC <- 1
UA <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

# ------------------------------------------------------------
# Parse webarccsv.pl response
# ------------------------------------------------------------

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
      measure_type = row$measure_type,
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

usbr_batches <- split(usbr_stations, ceiling(seq_len(nrow(usbr_stations)) / 14))
usbr_data <- map_dfr(usbr_batches, fetch_usbr_batch, start_date = START_DATE, end_date = END_DATE)

# ------------------------------------------------------------
# 2. USGS NWIS gauges embedded in the teacup diagram
#    (site_no, parm_cd, label, measure_type)
#
# NOTE: Two teacup circles ("SF Sprague River nr Bly", station_nbr
# 11495600, and "NF Sprague River", station_nbr 11495900) link to
# Oregon Water Resources Dept "near real time" pages, but those
# station numbers are NOT usable USGS sites: 11495600 does not exist
# in NWIS at all, and 11495900 exists but has zero IV/DV records (its
# streamflow is only published by OWRD, which renders data as chart
# images with no CSV/JSON API). Both are excluded here; Spencer Creek
# (11510000, data through 1932) and Sycan River (11499100, data
# through 1991) are legitimate but long-discontinued USGS gauges kept
# below — they'll simply return no rows if START_DATE is after their
# end_date.
# ------------------------------------------------------------

# lat/long sourced from dataRetrieval::readNWISsite() (dec_lat_va/dec_long_va)
usgs_stations <- tribble(
  ~site_no,     ~parm_cd, ~label,                                                    ~measure_type, ~lat,      ~long,
  "11507001",   "72275",  "Upper Klamath Lake nr Klamath Falls - Elevation (ft)",     "Elevation",   42.24983, -121.8164,
  "11501000",   "00060",  "Sprague River - Flow (cfs)",                              "Flow",         42.58431, -121.8483,
  "11510000",   "00060",  "Spencer Creek - Flow (cfs)",                              "Flow",         42.15816, -122.0289,
  "11497550",   "00060",  "SF Sprague River below Brown Creek, nr Beatty - Flow (cfs)","Flow",        42.45979, -121.2713,
  "11499100",   "00060",  "Sycan River - Flow (cfs)",                                "Flow",         42.48598, -121.2789,
  "11502500",   "00060",  "Williamson River below Sprague River - Flow (cfs)",       "Flow",         42.56437, -121.8797,
  "11504115",   "00060",  "Wood River nr Klamath Agency - Flow (cfs)",               "Flow",         42.58156, -121.9417,
  "11507200",   "00060",  "A Canal Headworks at Klamath Falls - Flow (cfs)",         "Flow",         42.23876, -121.8025,
  "11507500",   "00060",  "Link River at Klamath Falls - Flow (cfs)",                "Flow",         42.22348, -121.7942,
  "11509105",   "00060",  "North Canal at Hwy 97, nr Midland - Flow (cfs)",          "Flow",         42.12139, -121.8268,
  "11509340",   "00060",  "Klamath Straits Drain nr Worden - Flow (cfs)",            "Flow",         42.08095, -121.8483,
  "11509200",   "00060",  "ADY Canal at Hwy 97, nr Worden - Flow (cfs)",             "Flow",         42.08089, -121.8446,
  "11509250",   "00060",  "ADY Canal above Lower Klamath NWR, nr Worden - Flow (cfs)","Flow",        42.00417, -121.8258,
  "11509500",   "00060",  "Klamath River at Keno - Flow (cfs)",                      "Flow",         42.13320, -121.9622,
  "11516530",   "00060",  "Klamath River below Iron Gate Dam - Flow (cfs)",          "Flow",         41.92788, -122.4442
)

fetch_usgs_site <- function(site_no, parm_cd) {
  message("Fetching USGS gauge: ", site_no, " (parm ", parm_cd, ")")
  tryCatch(
    readNWISdv(
      siteNumbers = site_no,
      parameterCd = parm_cd,
      startDate   = START_DATE,
      endDate     = END_DATE
    ),
    error = function(e) {
      warning("  USGS pull failed for ", site_no, "/", parm_cd, ": ", conditionMessage(e))
      NULL
    }
  )
}

usgs_raw <- pmap_dfr(
  usgs_stations,
  function(site_no, parm_cd, label, measure_type, lat, long) {
    df <- fetch_usgs_site(site_no, parm_cd)
    if (is.null(df) || nrow(df) == 0) return(NULL)

    value_col <- names(df)[grepl("^X_.*_00003$", names(df))][1]
    if (is.na(value_col)) return(NULL)

    tibble(
      site         = site_no,
      parameter    = parm_cd,
      label        = label,
      measure_type = measure_type,
      lat          = lat,
      long         = long,
      date         = df$Date,
      value        = df[[value_col]]
    )
  }
)

usgs_data <- usgs_raw |> filter(!is.na(date))


# ------------------------------------------------------------
# 3. add OWRD data:
# ------------------------------------------------------------

sf_sprague <- whychusModel::get_owrd_hydro(11495600, START_DATE, END_DATE , "MDF") |>
  transmute(
    source       = "OWRD",
    site         = as.character(station_nbr),
    parameter    = "00060",
    label        = "SF Sprague River nr Bly, OR - Flow (cfs)",
    measure_type = "Flow",
    lat          = 42.42,
    long         = -121.056389,
    date         = mdy(record_date),
    value        = mean_daily_flow_cfs
  ) |>
  filter(!is.na(value))
nf_sprague <- whychusModel::get_owrd_hydro(11495900, START_DATE, END_DATE , "MDF") |>
  transmute(
    source       = "OWRD",
    site         = as.character(station_nbr),
    parameter    = "00060",
    label        = "N FK SPRAGUE R AB SRIC CN NR BLY, OR - Flow (cfs)",
    measure_type = "Flow",
    lat          = 42.496528,
    long         = -121.006925,
    date         = mdy(record_date),
    value        = mean_daily_flow_cfs
  ) |>
  filter(!is.na(value))


# ------------------------------------------------------------
# 4. Combine USBR + USGS + OWRD into one tidy dataset
# ------------------------------------------------------------
ELEV_MAX_FT <- 5000

teacup_data <- bind_rows(
  usbr_data |> mutate(source = "USBR Hydromet"),
  usgs_data |> mutate(source = "USGS NWIS"),
  sf_sprague |> mutate(source = "OWRD"),
  nf_sprague |> mutate(source = "OWRD")
) |>
  filter(!is.na(value)) |>
  select(source, site, label, measure_type, lat, long, date, value) |>
  mutate(measure_type = tolower(measure_type)) |>
  # `TULC2` has one row (2022-02-09, value = 998877) that is obviously not a real elevation —
  # almost certainly a parsing artifact  (e.g. an unhandled sentinel value from the USBR archive).
  # It's excluded from everything downstream in this document; the
  # underlying pull script should be fixed to catch this at the source.
  filter(measure_type != "elevation" | value <= ELEV_MAX_FT)

message("\n--- Summary ---")
message("Total rows: ", nrow(teacup_data))
print(
  teacup_data |>
    group_by(source, site, label, measure_type, lat, long) |>
    summarise(n = n(), start = min(date), end = max(date), .groups = "drop")
)

# ------------------------------------------------------------
# Save
# ------------------------------------------------------------

teacup_diagram_data <- teacup_data
usethis::use_data(teacup_diagram_data, overwrite = TRUE)
