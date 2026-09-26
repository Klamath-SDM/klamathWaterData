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


### hoopa data pull -----
hoopa_start_date <- as.Date("2015-01-01") # portal returns whatever it actually has, starting ~2019-08-27
hoopa_end_date <- karuk_end_date

#### water data table ----
hoopa_saints_rest_raw <- fetch_hoopa_station(
  "Klamath River Saints Rest", "Water Temp C", hoopa_start_date, hoopa_end_date
)

