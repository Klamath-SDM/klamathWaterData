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

# Standardized pull window - matches lake-levels-data-pull.R / flow-data-pull.R.
start_date <- as.Date("1996-01-01")
end_date   <- as.Date("2025-12-31")

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

# lat/long pulled live from the USBR RISE API (see fetch_rise_klamath_locations()
# in usbr-hydromet-pull-helpers.R), which catalogs each Hydromet cbtt under a
# named Reclamation location, rather than hand-transcribed here.
# NOTE: LRD ("Lost River Reservoir and Diversion Dam") is used as the
# archived-data proxy for the teacup's "LRDO" circle, but RISE shows these
# are technically two distinct points ~0.6 mi apart along the same channel:
# LRDO is "Lost River Diversion Channel at C-G Canal Crossing" (42.140669 /
# -121.682313) downstream of the LRD dam site used here (42.142822 /
# -121.672895).
source("data-raw/data-pull/usbr-hydromet-pull-helpers.R")

rise_klamath_locations <- fetch_rise_klamath_locations()

usbr_stations <- tribble(
  ~site,   ~parameter, ~label,                                            ~measure_type,
  "GER",   "FB",       "Gerber Reservoir - Forebay Elevation (ft)",       "Elevation",
  "GER",   "AF",       "Gerber Reservoir - Storage (acre-ft)",            "Storage",
  "CLK",   "FB",       "Clear Lake West Lobe - Forebay Elevation (ft)",   "Elevation",
  "CLK",   "AF",       "Clear Lake West Lobe - Storage (acre-ft)",        "Storage",
  "MAL",   "GD",       "Malone Reservoir - Gage Height (ft)",             "Elevation",
  "TULC",  "FB",       "Tule Lake Sump 1A - Forebay Elevation (ft)",      "Elevation",
  "TULC2", "FB",       "Tule Lake Sump 1B - Forebay Elevation (ft)",      "Elevation",
  "LVNO",  "QJ",       "Langell Valley North Canal - Flow (cfs)",         "Flow",
  "MHPO",  "QP",       "Miller Hill Pump Plant - Flow (cfs)",             "Flow",
  "LRD",   "QD",       "Lost River Diversion - Flow (cfs)",               "Flow",
  "HRPO",  "QD",       "Lost River at Harpold Dam - Flow (cfs)",          "Flow",
  "LRS",   "QD",       "Clear Lake East Lobe / Lost River - Flow (cfs)",  "Flow",
  "CHRO",  "QD",       "Cherry Creek - Flow (cfs)",                       "Flow"
) |>
  left_join(rise_klamath_locations, by = "site")

# ------------------------------------------------------------
# Pull/parse webarccsv.pl responses (shared with lake-levels and flow
# pull scripts; see usbr-hydromet-pull-helpers.R)
# ------------------------------------------------------------

usbr_batches <- split(usbr_stations, ceiling(seq_len(nrow(usbr_stations)) / 14))
usbr_data <- map_dfr(usbr_batches, fetch_usbr_batch, start_date = start_date, end_date = end_date) |>
  # fetch_usbr_batch()/parse_webarccsv() are shared with other pull scripts and
  # don't carry measure_type themselves - join it back from usbr_stations.
  left_join(usbr_stations |> select(site, parameter, measure_type), by = c("site", "parameter"))

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
# below — they'll simply return no rows if start_date is after their
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
      startDate   = start_date,
      endDate     = end_date
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

sf_sprague <- whychusModel::get_owrd_hydro(11495600, start_date, end_date , "MDF") |>
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
nf_sprague <- whychusModel::get_owrd_hydro(11495900, start_date, end_date , "MDF") |>
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
