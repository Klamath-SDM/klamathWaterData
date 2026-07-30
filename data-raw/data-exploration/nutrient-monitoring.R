library(dataRetrieval)
library(dplyr)
library(janitor)
library(readr)
library(sf)
library(ggplot2)

#  the purpose of this markdown is to pull and explore nutrient data al UKL and Tule lake
#  this script will serve as a reference to what it is publicly available and their time coverage

# Upper Klamath Lake -----

### USGS sites for UKL nutrient data --------
usgs_sites <- list(
  buck_island = "USGS-421830121512600",
  howard = "USGS-421935121551200",
  rpt = "USGS-422042121513100",
  shb = "USGS-422444121580400",
  wmr = "USGS-422719121571400",
  mdnl = "USGS-422622122004000")

# Pull nutrient data for all sites
all_usgs_nutrients <- list()
for (site_name in names(usgs_sites)) {
  cat("Pulling", site_name, "\n")

  all_usgs_nutrients[[site_name]] <- readWQPdata(
    siteid = usgs_sites[[site_name]],
    characteristicType = "Nutrient",
    startDateLo = "01-01-1996",
    startDateHi = "12-31-2025"
  )

  Sys.sleep(1)
}

# Combine all sites
usgs_nutrients <- do.call(rbind, all_usgs_nutrients)

# Summary of each site
usgs_nutrients_ukl <- usgs_nutrients |>
  select(OrganizationIdentifier, ActivityStartDate, MonitoringLocationIdentifier, CharacteristicName,
         ResultMeasureValue, ResultMeasure.MeasureUnitCode) |>
  clean_names() |>
  filter(!is.na(result_measure_value)) |>
  glimpse()

unique(usgs_nutrients_ukl$characteristic_name)


usgs_nutrients_ukl_clean <- usgs_nutrients_ukl |>
  mutate(location = "upper klamath lake",
         # gage_name = monitoring_location_identifier,
         gage_id = monitoring_location_identifier,
         variable_name = characteristic_name,
         value = result_measure_value,
         unit = result_measure_measure_unit_code,
         statistic = "mean", # TODO check if this is correct
         date = as.Date(activity_start_date)) |>
  select(location, gage_id, variable_name, value, unit, statistic, date) |>
  glimpse()


gage_data <- read_waterdata_monitoring_location(
  monitoring_location_id = unlist(usgs_sites, use.names = FALSE))

gage_reference <- gage_data |>
  mutate(monitoring_location_name = tolower(monitoring_location_name),
         gage_id = monitoring_location_id) |>
  select(monitoring_location_name, gage_id) |>
  st_drop_geometry() |>
  glimpse()

ukl_usgs_nutrients_data <- usgs_nutrients_ukl_clean |> left_join(gage_reference, by = "gage_id") |>
  mutate(gage_name = monitoring_location_name) |>
  relocate(gage_name, .after = location) |>
  select(-monitoring_location_name) |>
  glimpse()


### Klamath Tribes -----
# the klamath tribes data was downloaded from the Klamath Tribes Water Quality Monitoring Data portal:
# https://klamathtribeswaterquality.com/data/
klamath_tribes_wqx <- read_csv("data-raw/klamath-tribes-data/all_klamath_wqx_data.csv")

unique(klamath_tribes_wqx$characteristic_name)

klmth_trib_nutrients_data <- klamath_tribes_wqx |>
  filter(characteristic_name %in% c("Phosphorus", "Silica", "Ammonia-nitrogen",
                                    "Total Phosphorus, mixed forms","Nitrogen", "Nitrite",
                                    "Nitrate + Nitrite")) |>
  filter(!monitoring_location_identifier %in% c("KLAMATHTRIBES_WQX-WR1000", "KLAMATHTRIBES_WQX-SR0090",
                                                "KLAMATHTRIBES_WQX-SR0050", "KLAMATHTRIBES_WQX-SR0150",
                                                "KLAMATHTRIBES_WQX-SR0140", "KLAMATHTRIBES_WQX-SR0040",
                                                "KLAMATHTRIBES_WQX-SR0060", "KLAMATHTRIBES_WQX-SR0070",
                                                "AMATHTRIBES_WQX-SR0080")) |>
  mutate(location = "upper klamath lake",
         gage_name = tolower(monitoring_location_name),
         gage_id = monitoring_location_identifier,
         variable_name = characteristic_name,
         value = result_measure_value,
         unit = result_measure_measure_unit_code,
         statistic = "mean", # TODO check if this is correct
         date = as.Date(activity_start_date)) |>
  select(location, gage_name, gage_id, variable_name, value, unit, statistic, date) |>
  glimpse()

# combine klamath tribes + usgs

ukl_nutrient_data <- bind_rows(klmth_trib_nutrients_data, ukl_usgs_nutrients_data) |> glimpse()


# Tule Lake -----
# Approximate bounding box around Tule Lake and nearby canals/refuge units

tule_sites <- list(
  tule_1 = "USGS-415223121323501",
  tule_2 = "USGS-415217121294901",
  tule_3 = "USGS-11488510",
  tule_4 = "USGS-415400121294201",
  tule_5 = "USGS-415334121314501")

# Pull nutrient data for all sites
all_tule_nutrients <- list()
for (site_name in names(tule_sites)) {
  cat("Pulling", site_name, "\n")

  all_tule_nutrients[[site_name]] <- readWQPdata(
    siteid = tule_sites[[site_name]],
    characteristicType = "Nutrient",
    startDateLo = "01-01-1996",
    startDateHi = "12-31-2025"
  )

  Sys.sleep(1)
}

# Combine all sites
tule_nutrients <- do.call(rbind, all_tule_nutrients)

range(tule_nutrients$ActivityStartDate) # overall time range "2002-08-19" - "2018-09-24"
# note that all sites except one has data within the time range of 1996-2025

# Summary of each site
tule_nutrients_usgs <- tule_nutrients |>
  select(OrganizationIdentifier, ActivityStartDate, MonitoringLocationIdentifier, CharacteristicName,
         ResultMeasureValue, ResultMeasure.MeasureUnitCode) |>
  clean_names() |>
  filter(!is.na(result_measure_value)) |>
  glimpse()

unique(tule_nutrients_usgs$characteristic_name)


tule_nutrients_usgs_clean <- tule_nutrients_usgs |>
  mutate(location = "tule lake",
         # gage_name = monitoring_location_identifier,
         gage_id = monitoring_location_identifier,
         variable_name = characteristic_name,
         value = result_measure_value,
         unit = result_measure_measure_unit_code,
         statistic = "mean", # TODO check if this is correct
         date = as.Date(activity_start_date)) |>
  select(location, gage_id, variable_name, value, unit, statistic, date) |>
  glimpse()

# get gage data
tule_gage_data <- read_waterdata_monitoring_location(
  monitoring_location_id = unlist(tule_sites, use.names = FALSE))

gage_reference_tule <- tule_gage_data |>
  mutate(monitoring_location_name = tolower(monitoring_location_name),
         gage_id = monitoring_location_id) |>
  select(monitoring_location_name, gage_id) |>
  st_drop_geometry()

# add gage name by joining gage data column
tule_nutrients_data <- tule_nutrients_usgs_clean |> left_join(gage_reference_tule, by = "gage_id") |>
  mutate(gage_name = monitoring_location_name) |>
  relocate(gage_name, .after = location) |>
  select(-monitoring_location_name) |>
  glimpse()

tule_nutrients_data_summary <- tule_nutrients_data |>
  filter(!is.na(date)) |>
  group_by(location, gage_id, gage_name) |>
  summarise(
    min_date = min(date, na.rm = TRUE),
    max_date = max(date, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(gage_name)


ukl_gage_data_summary <- ukl_nutrient_data |>
  filter(!is.na(date)) |>
  group_by(location, gage_id, gage_name) |>
  summarise(
    min_date = min(date, na.rm = TRUE),
    max_date = max(date, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(gage_name)

nutrient_data_summary <- bind_rows(tule_nutrients_data_summary, ukl_gage_data_summary)

nutrient_data_summary
# TODO only saves to share with Jim
# write_csv(nutrient_data_summary,"data-raw/data-exploration/nutrient_data_summary.csv")
