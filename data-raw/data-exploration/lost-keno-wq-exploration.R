# =============================================================================
# Water Quality Gages — Lost River & Keno Reach (Lake Ewauna to Keno Dam)
# =============================================================================
# (1) Pulls gages from WQX
# (2) Filters to gages collecting Temperature, pH, and/or Dissolved Oxygen
# (3) Determines temporal coverage of each parameter (USGS only — WQP site
#     search does not return per-parameter date ranges)
# (4) Plots all gages on one interactive map
# (5) cross-check with klamathWaterData objects and determine if we have pulled
#     that data already, or not
# =============================================================================


library(dataRetrieval)
library(dplyr)
library(purrr)
library(stringr)
library(tidyr)
library(lubridate)
library(leaflet)
library(htmltools)

# ---------------------------
# Inputs
# ---------------------------

wq_chars <- c(
  "Temperature, water",
  "pH",
  "Dissolved oxygen (DO)"
)

usgs_pcodes <- c(
  "00010", # Temperature, water
  "00400", # pH
  "00300"  # Dissolved oxygen
)

pcode_lookup <- tibble(
  parameterCd = usgs_pcodes,
  CharacteristicName = c(
    "Temperature, water",
    "pH",
    "Dissolved oxygen (DO)"
  )
)

wqp_boxes <- list(
  "Lost River"  = c(-121.701762, 41.929380, -121.052246, 42.210610),
  "Keno Reach" = c(-121.883019, 42.078811, -121.763552, 42.235661)
)

start_date <- "1900-01-01"
end_date   <- as.character(Sys.Date())

# ---------------------------
# Final gage list
# ---------------------------

target_wqx <- tribble(
  ~Reach, ~MonitoringLocationIdentifier,
  "Lost River", "USGS-415635121301401",
  "Lost River", "USGS-11488495",
  "Lost River", "USGS-415714121301401",
  "Lost River", "OREGONDEQ-12491-ORDEQ",
  "Lost River", "CALWR_WQX-F1379300",
  "Lost River", "OREGONDEQ-30182-ORDEQ",
  "Lost River", "OREGONDEQ-10758-ORDEQ",
  "Lost River", "OREGONDEQ-28293-ORDEQ",
  "Lost River", "OREGONDEQ-13045-ORDEQ",
  "Lost River", "OREGONDEQ-10759-ORDEQ",
  "Lost River", "OREGONDEQ-40823-ORDEQ",
  "Lost River", "USGS-421010121271200",
  "Lost River", "OREGONDEQ-38907-ORDEQ",
  "Lost River", "OREGONDEQ-10761-ORDEQ",
  "Keno Reach", "OREGONDEQ-30940-ORDEQ",
  "Keno Reach", "OREGONDEQ-11598-ORDEQ",
  "Keno Reach", "OREGONDEQ-11603-ORDEQ",
  "Keno Reach", "OREGONDEQ-10768-ORDEQ"
)

target_usgs <- tribble(
  ~Reach, ~site_no,
  "Lost River", "415954121312100",
  "Lost River", "420036121333700",
  "Lost River", "420535121143800",
  "Lost River", "420024121132800",
  "Keno Reach", "420732121501100",
  "Keno Reach", "420853121505500",
  "Keno Reach", "421015121471800",
  "Keno Reach", "421209121463000"
)

# ---------------------------
# Helper functions
# ---------------------------

safe_bind <- function(x) {
  bind_rows(lapply(x, function(df) {
    if (is.null(df) || nrow(df) == 0) return(tibble())
    df |> mutate(across(everything(), as.character))
  }))
}

pull_wqp_sites <- function(box, reach) {
  message("Finding WQP sites in ", reach, "...")

  whatWQPsites(
    bBox = box,
    characteristicName = wq_chars
  ) |>
    mutate(Reach = reach)
}

pull_wqp_results <- function(box, reach) {
  message("Pulling WQP results in ", reach, "...")

  readWQPdata(
    bBox = box,
    characteristicName = wq_chars,
    startDateLo = start_date,
    startDateHi = end_date,
    service = "Result"
  ) |>
    mutate(Reach = reach)
}

pull_usgs_site_info <- function(site_no, reach) {
  message("Finding USGS site info for ", site_no, "...")

  readNWISsite(site_no) |>
    mutate(
      Reach = reach,
      DataSource = "USGS NWIS"
    )
}

pull_usgs_uv <- function(site_no, reach) {
  message("Pulling USGS instantaneous data for ", site_no, "...")

  out <- tryCatch(
    readNWISuv(
      siteNumbers = site_no,
      parameterCd = usgs_pcodes,
      startDate = start_date,
      endDate = end_date,
      tz = "UTC"
    ),
    error = function(e) NULL
  )

  if (is.null(out) || nrow(out) == 0) return(tibble())

  out |>
    mutate(
      Reach = reach,
      site_no = site_no
    )
}

# ---------------------------
# 1. WQP / WQX sites and results
# ---------------------------

wqp_sites_raw <- imap(wqp_boxes, pull_wqp_sites) |>
  safe_bind()

wqp_results_raw <- imap(wqp_boxes, pull_wqp_results) |>
  safe_bind()

wqp_sites <- wqp_sites_raw |>
  semi_join(target_wqx, by = c("Reach", "MonitoringLocationIdentifier"))

wqp_results <- wqp_results_raw |>
  filter(CharacteristicName %in% wq_chars) |>
  semi_join(target_wqx, by = c("Reach", "MonitoringLocationIdentifier"))

# ---------------------------
# 2. WQP temporal coverage
# ---------------------------

wqp_coverage_by_parameter <- wqp_results |>
  mutate(ActivityDate = as.Date(ActivityStartDate)) |>
  filter(!is.na(ActivityDate)) |>
  group_by(
    Reach,
    MonitoringLocationIdentifier,
    CharacteristicName
  ) |>
  summarise(
    start_date = min(ActivityDate, na.rm = TRUE),
    end_date   = max(ActivityDate, na.rm = TRUE),
    n_results  = n(),
    .groups = "drop"
  )

wqp_site_summary <- wqp_coverage_by_parameter |>
  group_by(
    Reach,
    MonitoringLocationIdentifier
  ) |>
  summarise(
    parameters = paste(sort(unique(CharacteristicName)), collapse = "; "),
    start_date = min(start_date, na.rm = TRUE),
    end_date = max(end_date, na.rm = TRUE),
    temporal_coverage = paste(start_date, "to", end_date),
    n_results = sum(n_results),
    .groups = "drop"
  )

wqp_map_df <- wqp_sites |>
  select(
    Reach,
    MonitoringLocationIdentifier,
    MonitoringLocationName,
    OrganizationIdentifier,
    OrganizationFormalName,
    LatitudeMeasure,
    LongitudeMeasure
  ) |>
  distinct() |>
  inner_join(
    wqp_site_summary,
    by = c("Reach", "MonitoringLocationIdentifier")
  ) |>
  transmute(
    Reach,
    DataSource = "WQP/WQX",
    SiteID = MonitoringLocationIdentifier,
    SiteName = MonitoringLocationName,
    Agency = OrganizationFormalName,
    OrgID = OrganizationIdentifier,
    parameters,
    start_date,
    end_date,
    temporal_coverage,
    n_results,
    lat = as.numeric(LatitudeMeasure),
    lon = as.numeric(LongitudeMeasure)
  ) |>
  filter(!is.na(lat), !is.na(lon))

# ---------------------------
# 3. USGS site info and results
# ---------------------------

usgs_sites_raw <- pmap(
  list(target_usgs$site_no, target_usgs$Reach),
  pull_usgs_site_info
) |>
  safe_bind()

usgs_uv_raw <- pmap(
  list(target_usgs$site_no, target_usgs$Reach),
  pull_usgs_uv
) |>
  safe_bind()

# Convert USGS wide instantaneous columns to long format.
# This captures columns like X_00010_00000, X_00400_00000, X_00300_00000.
usgs_uv_long <- usgs_uv_raw |>
  mutate(dateTime = as.POSIXct(dateTime, tz = "UTC")) |>
  pivot_longer(
    cols = matches("^[A-Za-z]*_?(00010|00400|00300)_"),
    names_to = "parameter_column",
    values_to = "value",
    values_drop_na = TRUE
  ) |>
  mutate(
    parameterCd = str_extract(parameter_column, "00010|00400|00300")
  ) |>
  left_join(pcode_lookup, by = "parameterCd")

usgs_coverage_by_parameter <- usgs_uv_long |>
  filter(!is.na(CharacteristicName), !is.na(dateTime)) |>
  group_by(
    Reach,
    site_no,
    CharacteristicName
  ) |>
  summarise(
    start_date = as.Date(min(dateTime, na.rm = TRUE)),
    end_date   = as.Date(max(dateTime, na.rm = TRUE)),
    n_results  = n(),
    .groups = "drop"
  )

usgs_site_summary <- usgs_coverage_by_parameter |>
  group_by(
    Reach,
    site_no
  ) |>
  summarise(
    parameters = paste(sort(unique(CharacteristicName)), collapse = "; "),
    start_date = min(start_date, na.rm = TRUE),
    end_date = max(end_date, na.rm = TRUE),
    temporal_coverage = paste(start_date, "to", end_date),
    n_results = sum(n_results),
    .groups = "drop"
  )

usgs_map_df <- usgs_sites_raw |>
  select(
    Reach,
    site_no,
    station_nm,
    agency_cd,
    dec_lat_va,
    dec_long_va
  ) |>
  distinct() |>
  inner_join(
    usgs_site_summary,
    by = c("Reach", "site_no")
  ) |>
  transmute(
    Reach,
    DataSource = "USGS NWIS",
    SiteID = site_no,
    SiteName = station_nm,
    Agency = "U.S. Geological Survey",
    OrgID = agency_cd,
    parameters,
    start_date,
    end_date,
    temporal_coverage,
    n_results,
    lat = as.numeric(dec_lat_va),
    lon = as.numeric(dec_long_va)
  ) |>
  filter(!is.na(lat), !is.na(lon))

# ---------------------------
# 4. Final combined gage summary
# ---------------------------

gage_summary <- bind_rows(wqp_map_df, usgs_map_df) |>
  arrange(Reach, DataSource, SiteID)

parameter_summary <- bind_rows(
  wqp_coverage_by_parameter |>
    transmute(
      Reach,
      DataSource = "WQP/WQX",
      SiteID = MonitoringLocationIdentifier,
      CharacteristicName,
      start_date,
      end_date,
      n_results
    ),
  usgs_coverage_by_parameter |>
    transmute(
      Reach,
      DataSource = "USGS NWIS",
      SiteID = site_no,
      CharacteristicName,
      start_date,
      end_date,
      n_results
    )
) |>
  arrange(Reach, DataSource, SiteID, CharacteristicName)

print(gage_summary)
print(parameter_summary)

# ---------------------------
# 5. Clean map with just target gages
# ---------------------------

bbox_rects <- tibble(
  Reach = names(wqp_boxes),
  west  = map_dbl(wqp_boxes, 1),
  south = map_dbl(wqp_boxes, 2),
  east  = map_dbl(wqp_boxes, 3),
  north = map_dbl(wqp_boxes, 4)
)

reach_pal <- colorFactor(
  palette = c("Lost River" = "#1b9e77", "Keno Reach" = "#7570b3"),
  domain = gage_summary$Reach
)

shape_radius <- function(source) {
  ifelse(source == "USGS NWIS", 8, 6)
}

gage_map <- leaflet(gage_summary) |>
  addProviderTiles(providers$Esri.WorldTopoMap) |>

  addRectangles(
    data = bbox_rects,
    lng1 = ~west,
    lat1 = ~south,
    lng2 = ~east,
    lat2 = ~north,
    color = "red",
    weight = 2,
    fill = FALSE,
    popup = ~paste0("<b>", Reach, " bounding box</b>")
  ) |>

  addCircleMarkers(
    data = gage_summary,
    lng = ~lon,
    lat = ~lat,
    radius = ~shape_radius(DataSource),
    color = ~reach_pal(Reach),
    fillColor = ~reach_pal(Reach),
    fillOpacity = 0.85,
    stroke = TRUE,
    weight = ~ifelse(DataSource == "USGS NWIS", 3, 1.5),
    popup = ~paste0(
      "<b>", htmlEscape(SiteName), "</b><br>",
      "<b>Site ID:</b> ", htmlEscape(SiteID), "<br>",
      "<b>Reach:</b> ", htmlEscape(Reach), "<br>",
      "<b>Source:</b> ", htmlEscape(DataSource), "<br>",
      "<b>Agency:</b> ", htmlEscape(Agency), "<br>",
      "<b>Parameters:</b> ", htmlEscape(parameters), "<br>",
      "<b>Temporal coverage:</b> ", temporal_coverage, "<br>",
      "<b>Result count:</b> ", n_results
    ),
    label = ~paste0(
      SiteID, " | ",
      DataSource, " | ",
      parameters, " | ",
      temporal_coverage
    )
  ) |>

  addLegend(
    position = "bottomright",
    pal = reach_pal,
    values = ~Reach,
    title = "Reach"
  )

gage_map


#  Figure out from this gages, which ones we have pulled already
kwd_gage_objects <- list(
  temperature = klamathWaterData::temperature_gage,
  pH          = klamathWaterData::ph_gage,
  DO          = klamathWaterData::do_gage
)

# ---------------------------
# 2. Helper: guess likely gage/site ID columns
# ---------------------------

get_gage_ids <- function(df) {
  possible_id_cols <- names(df)[
    str_detect(
      names(df),
      regex(
        "gage_id",
        ignore_case = TRUE
      )
    )
  ]

  ids <- df |>
    select(any_of(possible_id_cols)) |>
    mutate(across(everything(), as.character)) |>
    pivot_longer(
      cols = everything(),
      values_to = "gage_id",
      values_drop_na = TRUE
    ) |>
    distinct(gage_id) |>
    pull(gage_id)

  ids <- unique(c(
    ids,
    str_remove(ids, "^USGS-")
  ))

  ids[!is.na(ids) & ids != ""]
}

kwd_gage_ids <- imap_dfr(kwd_gage_objects, function(df, parameter_group) {
  tibble(
    parameter_group = parameter_group,
    existing_id = get_gage_ids(df)
  )
}) |>
  distinct()

# ---------------------------
# 3. Prepare your target gage IDs
# ---------------------------

target_gages <- gage_summary |>
  transmute(
    Reach,
    DataSource,
    SiteID,
    SiteID_no_prefix = str_remove(SiteID, "^USGS-"),
    SiteName,
    Agency,
    parameters,
    temporal_coverage
  )

# ---------------------------
# 4. Check whether each target gage exists in each KWD object
# ---------------------------

gage_existing_check <- target_gages |>
  crossing(parameter_group = c("temperature", "pH", "DO")) |>
  left_join(
    kwd_gage_ids,
    by = "parameter_group",
    relationship = "many-to-many"
  ) |>
  mutate(
    exists_in_klamathWaterData =
      SiteID == existing_id |
      SiteID_no_prefix == existing_id |
      str_remove(existing_id, "^USGS-") == SiteID_no_prefix
  ) |>
  group_by(
    Reach,
    DataSource,
    SiteID,
    SiteName,
    Agency,
    parameters,
    temporal_coverage,
    parameter_group
  ) |>
  summarise(
    exists_in_klamathWaterData = any(exists_in_klamathWaterData, na.rm = TRUE),
    matched_id = paste(unique(existing_id[exists_in_klamathWaterData]), collapse = "; "),
    .groups = "drop"
  ) |>
  mutate(
    matched_id = na_if(matched_id, "")
  ) |>
  arrange(Reach, DataSource, SiteID, parameter_group)

# ---------------------------
# 5. Wide summary: one row per gage
# ---------------------------

gage_existing_summary <- gage_existing_check |>
  select(
    Reach,
    DataSource,
    SiteID,
    SiteName,
    Agency,
    parameters,
    temporal_coverage,
    parameter_group,
    exists_in_klamathWaterData
  ) |>
  pivot_wider(
    names_from = parameter_group,
    values_from = exists_in_klamathWaterData,
    names_prefix = "exists_in_"
  ) |>
  mutate(
    exists_in_any_klamathWaterData_object =
      exists_in_temperature | exists_in_pH | exists_in_DO
  ) |>
  arrange(Reach, DataSource, SiteID)

# ---------------------------
# 6. Inspect/export
# ---------------------------

print(gage_existing_check)
print(gage_existing_summary)

# narrow down missing gages on klamathWaterData
missing <- gage_existing_summary |>
  filter(exists_in_any_klamathWaterData_object == FALSE) |>
  glimpse()

