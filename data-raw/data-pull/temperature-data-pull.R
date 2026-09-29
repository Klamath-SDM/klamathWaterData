library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)
library(paws)

# the goal of this script is to pull temperature data from different sources

### WQX data pull -----
huc_code <- "180102" # huc code for Klamath basin

# Standardized pull window - matches lake-levels/flow/teacup-diagram pulls.
start_date <- as.Date("1996-01-01")
end_date   <- as.Date("2025-12-31")

#### temperature data ----
wqx_temp_data <- readWQPdata(huc = huc_code,
                         characteristicName = "Temperature, water",
                         startDateLo = start_date,
                         startDateHi = end_date)
####  gage data ----
wqx_gage_data <- whatWQPsites(huc = huc_code)  # this gage data pull can serve other parameters since it covers all sites with this huc code (Klamath basin)



### USGS data pull -----

#### temperature data ----
usgs_gages <- c(
  "11507500", "11510700", "11530500", "11523000", "11509500", "11509370",
  "420741121554001", "420451121510000", "420448121503100", "420853121505500",
  "420853121505501", "11526400", "11530000", "422042121513100",
  "421935121551200", "422305121553800", "422305121553803",
  "422444121580400", "422622122004000", "422622122004003",
  "422719121571400", "11504290", "420037121334100", "420036121333700",
  "420833121402000", "421010121271200", "421015121471800",
  "415954121312100", "11501000", "11502500", "11504115",
  "11511990", "11507501", "421401121480900", "11491470",
  "11491450", "11492550",
  "420024121132800", "420535121143800", "11485000") # pulling data for keno stretch and Lost river

# Define the parameters
parameter_code <- "00010"  # Temperature parameter code
stat_codes <- c("00001", "00002", "00003")  # Min, Max, Mean code

# empty list to store dataframes
all_data <- list()

# Loop through each gage and pull the data
for (gage in usgs_gages) {
  message(paste("Pulling data for gage:", gage))
  try({
    temp_data <- readNWISdv(
      siteNumbers = gage,
      parameterCd = parameter_code,
      statCd = stat_codes,
      startDate = start_date,
      endDate = end_date
    )

    temp_data <- temp_data |>
      mutate(gage_id = gage)

    all_data[[gage]] <- temp_data
  }, silent = TRUE)
}

# Combine all gage data into one dataframe
usgs_temp_data <- bind_rows(all_data)

#### gage data ----
usgs_temp_gage_data <- readNWISsite(usgs_gages)


### OWRD data pull -----
# sourcing helper functions
source("data-raw/data-pull/temperature-pull-helper-functions.R")

#### temperature data ----
owrd_temp_start_date <- as.Date("1996-01-01")
owrd_temp_end_date   <- as.Date("2025-12-31")

owrd_temp_station_list <- tribble(
  ~site,      ~location,          ~gage_name,
  "11491400", "williamson river", "williamson r bl sheep cr nr lenz, or",
  "11494000", "williamson river", "williamson r ab spring cr nr klamath agency, or",
  "11494510", "williamson river", "williamson r ab sprague r nr chiloquin, or",
  "11497500", "sprague river",    "sprague r nr beatty, or",
  "11497550", "sprague river",    "sprague r bl brown cr nr beatty, or",
  "11500400", "trout creek",      "trout cr nr lone pine",
  "11500500", "sprague river",    "sprague r at lone pine, or",
  "11502550", "williamson river", "williamson r at modoc pt rd, nr chiloquin, or",
  "11502950", "sun creek",        "sun cr at ranger sta nr fort klamath, or",
  "11503500", "annie creek",      "annie cr nr ft klamath",
  "11504103", "wood river",       "wood r ab crooked cr, nr klamath agency, or",
  "11504109", "crooked creek",    "crooked cr nr klamath agency, or",
  "11504120", "sevenmile creek",  "sevenmile cr bl dry cr nr fort klamath",
  "11510000", "spencer creek",    "spencer cr nr keno, or"
)

owrd_temp_coords <- map_dfr(owrd_temp_station_list$site, fetch_owrd_coord)
owrd_temp_stations <- owrd_temp_station_list |> left_join(owrd_temp_coords, by = "site")

#### water data table ----
#### pull OWRD water temperature data ----

temperature_data_owrd_raw <- map_dfr(seq_len(nrow(owrd_temp_stations)), function(i) {
  station <- owrd_temp_stations[i, ]
  message("Pulling OWRD temperature data for station: ", station$site)
  result <- tryCatch(
    whychusModel::get_owrd_hydro(
      station$site,
      owrd_temp_start_date,
      owrd_temp_end_date,
      "WTEMP_MEAN"
    ),
    error = function(e) {
      message("  failed: ", conditionMessage(e))
      NULL
    }
  )
  # OWRD's server occasionally returns an HTML error page instead of data.
  if (is.null(result) || !"station_nbr" %in% names(result)) {
    message("  no usable data returned for station ", station$site)
    return(NULL)
  }
  # Add station metadata needed during cleaning
  result |>
    mutate(
      stream = station$location,
      gage_name = station$gage_name
    )
})

glimpse(temperature_data_owrd_raw)

### karuk data pull -----
# using sourced helper functions from script

# Continuous sonde temperature for Klamath mainstem sites below Keno, plus
# one Scott River (a Klamath tributary) site
# (waterquality.karuk.us, an Aquatic Informatics AQUARIUS WebPortal
# aggregating Karuk Tribe, Yurok Tribe (YTEP), Quartz Valley Indian
# Reservation (QVIR), and co-located USGS telemetry) - fills a gap raised
# for the salmon-model temperature placeholder: USGS's own NWIS
# daily-values record for water temperature only exists at a handful of
# gages below Keno (see usgs_gages above), while this portal has
# continuous instream temperature at several more sites.
#
# Checked every USGS-numbered site on this portal against usgs_gages above
# to avoid duplicating what we already pull from NWIS: four
# (11509500/Keno, 11510700/below Boyle, 11511990/above Fall Creek,
# 11530500/near the mouth) are either a pure mirror of the official USGS
# record (dataset source tagged "USGS"/"USGS OGC" in the portal's own API)
# or have no temperature dataset there at all (11530500) - not pulled
# again here. One site, 11523000 (near Orleans), is genuinely Karuk's own
# independent sonde record under the same USGS site number (source tagged
# "Final"): it starts in 2001 and is still live, while usgs_gages' NWIS
# record for that same number only covers 2014-2024. Kept under a
# "karuk-" prefixed gage_id rather than merged into "11523000" so the two
# different-source records don't collide into ambiguous duplicate
# gage_id/date rows.
#
# Data is explicitly provisional per the portal's own disclaimer ("All
# Data Provisional. Do Not Cite without Karuk Tribe consent.") - get
# sign-off from Karuk Tribe / KBMP before this is used in anything
# published or operational.
# temperature-pull-helper-functions.R

# Every value below was looked up by hand against the portal's own
#  endpoints - not hand-guessed, and
# reproducible/updatable the same way if the portal ever reorganizes its
# stations or these need re-checking:
#   - gage_id: the numeric ones are real USGS gage numbers Karuk/Yurok have
#     co-located a sonde at, prefixed "karuk-" so they can't collide with
#     the plain-numeric gage_id usgs_gages above already uses for that same
#     station number (e.g. "11523000" from NWIS vs "karuk-11523000" here -
#     see the note above on why 11523000 specifically needs this). "kas"/
#     "kat"/"sc1" are the portal's own (already-unique) short codes for
#     those stations, used as-is.
#   - location/gage_name: hand-transcribed from each station's entry in
#     GET https://waterquality.karuk.us/Data/GetDropDownAll (a station
#     picker list; response body is itself a JSON-encoded string containing
#     the real JSON array - decode it twice). Every station below is
#     Klamath mainstem, confirmed by that listing's own display name (e.g.
#     "11516530 - KLAMATH RIVER BELOW IRON GATE (Karuk)"), except "sc1"
#     ("SC1 - SCOTT R NR FORT JONES (QVIR)"), which is on the Scott River,
#     a Klamath tributary.
#   - agency: the parenthesized suffix on that same DisplayText field
#     ("(Karuk)" -> Karuk Tribe, "(YTEP)" -> Yurok Tribe, "(QVIR)" ->
#     Quartz Valley Indian Reservation).
#   - dataset_id: the portal's internal id for each station's "Temperature
#     water" parameter, from
#     GET https://waterquality.karuk.us/Data/DataSets?locationid=<id>
#     (<id> is that station's own IDNumber field from GetDropDownAll, not
#     its site code) - look for the row where ParameterName is
#     "Temperature water" and read its IDNumber. That same response's
#     Id field is worth checking too: a value of "USGS"/"USGS OGC" there
#     means the portal is just mirroring the official NWIS record (already
#     pulled via usgs_gages above, so not worth re-pulling); "Final" or
#     "Telemetered" means it's the tribe/agency's own independent sonde
#     record, as all eight below are.
#   - start_date: that same DataSets response's StartTime field for the
#     "Temperature water" row.
#   - lat/long: not given directly by DataSets - fetch
#     GET https://waterquality.karuk.us/Data/Dataset_Side/?dataset=<dataset_id>&isDataset=true
#     (an HTML fragment, not JSON) and read the coordinates out of its
#     embedded onclick="...GoTo('map', <long>, <lat>)..." attribute.
karuk_stations <- tribble(
  ~gage_id,         ~location,       ~gage_name,                          ~dataset_id, ~start_date,            ~lat,        ~long,         ~agency,
  "karuk-11516530", "klamath river", "klamath river below iron gate",     1883,        as.Date("2001-05-17"),  41.927762,   -122.443927,   "Karuk Tribe",
  "karuk-11516000", "klamath river", "klamath river above shasta river",  1972,        as.Date("2023-12-20"),  41.831236,   -122.593248,   "Karuk Tribe",
  "karuk-11517818", "klamath river", "klamath river at walker bridge",    1905,        as.Date("2022-09-27"),  41.837087,   -122.864828,   "Karuk Tribe",
  "karuk-11520500", "klamath river", "klamath river near seiad valley",   1864,        as.Date("2001-05-17"),  41.853798,   -123.232033,   "Karuk Tribe",
  "karuk-11523000", "klamath river", "klamath river near orleans",        1849,        as.Date("2001-05-18"),  41.303471,   -123.534421,   "Karuk Tribe",
  "kas",            "klamath river", "klamath river at salt creek",       1888,        as.Date("2022-11-02"),  41.546886,   -124.062264,   "Yurok Tribe",
  "kat",            "klamath river", "klamath at turwar gage",            1666,        as.Date("2019-02-27"),  41.5159431,  -124.0003835,  "Yurok Tribe",
  "sc1",            "scott river",   "scott r nr fort jones",              2018,        as.Date("2017-07-18"),  41.64,       -123.0138,     "Quartz Valley Indian Reservation"
)

# matches the standardized end date used across this package's other pulls
karuk_end_date <- owrd_temp_end_date

#### pull Karuk water temperature data ----
temperature_data_karuk_raw <- map_dfr(seq_len(nrow(karuk_stations)), function(i) {
  station <- karuk_stations[i, ]

  message("Pulling Karuk WQ portal data for station: ", station$gage_id)

  raw <- fetch_karuk_dataset(
    station$dataset_id,
    station$start_date,
    karuk_end_date
  )

  if (nrow(raw) == 0) return(NULL)

  # Add station metadata needed during cleaning
  raw |>
    mutate(
      stream = station$location,
      gage_name = station$gage_name,
      gage_id = station$gage_id
    )
})

glimpse(temperature_data_karuk_raw)


### ### Hoopa Valley Tribe Hydromet Portal data pull -----

# Continuous sonde water temperature for one more Klamath mainstem site
# below Keno: "Klamath River Saints Rest" (wxvisual.com/HoopaValley, a
# custom Hoopa Valley Tribe hydromet dashboard, unrelated to the Karuk
# portal above). Coordinates (41.187972, -123.676941) match exactly the
# existing WQX gage "cdr and nutrients at saints rest bar"
# (HVTEPA_WQX-KR_STREST_CDR, in temperature_gage_wqx above) - same
# physical station, but that's discrete grab samples while this is a
# continuous sonde feed, so it's kept under its own "hoopa-" prefixed
# gage_id rather than merged into the WQX one.
#
# This portal has no JSON API - Graph.php returns a full HTML page with
# the chart's data embedded as a JS string (see
# hoopa-wq-portal-pull-helpers.R). Unlike the Karuk portal, one request
# returns the entire period of record at once (tested: ~53,000 rows /
# ~7 years in ~3 seconds), no chunking needed.
#
# ~5% of raw readings are sensor error codes, not real measurements: a
# literal 0.0 (sensor dropout, 2,615 of 51,687 in testing) and a fixed
# sentinel value in the tens of thousands (51425, clearly not a
# temperature) - both filtered out below, keeping only 0-35 C as a
# generous but real bound for this river.
#
# Data is explicitly provisional per the portal's own disclaimer ("Data
# is provisional and is subject to revision. Not to be used as official
# record.") - get sign-off from the Hoopa Valley Tribe before this is
# used in anything published or operational.
hoopa_start_date <- as.Date("2015-01-01") # portal returns whatever it actually has, starting ~2019-08-27
hoopa_end_date <- karuk_end_date

#### water data table ----
hoopa_saints_rest_raw <- fetch_hoopa_station(
  "Klamath River Saints Rest", "Water Temp C", hoopa_start_date, hoopa_end_date
)

