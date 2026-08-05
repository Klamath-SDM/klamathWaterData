library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(sf)
library(janitor)
library(klamathWaterData)
library(leaflet)
library(stringr)
library(htmltools)

#  the purpose of this script is just to keep track gages that we are using and have questions about
# it currently explores Scott and Shasta River temp and flow gages and ukl wq gages
# this script is just exploratory and can be removed when we settle with having enough gages/the right gages
temp <- klamathWaterData::temperature_data

temp_gage <- klamathWaterData::temperature_gage


flow <- klamathWaterData::flow_data

flow_gage <- klamathWaterData::flow_gage |> glimpse()

scott_gage <- temp_gage |>
  filter(location == "scott river") |>
  bind_rows(
    flow_gage |>
      filter(location == "scott river")
  ) |>
  select(-location, -gage_name) |>
  glimpse()

scott_data <- bind_rows(temp |> filter(location == "scott river"), flow|> filter(location == "scott river")) |> glimpse()

scott_data_summary <- scott_data |>
  group_by(location, gage_id, gage_name) |>
  summarise(
    min_date = min(date, na.rm = TRUE),
    max_date = max(date, na.rm = TRUE),
    parameters = paste(
      sort(unique(variable_name)),
      collapse = ", "
    ),
    .groups = "drop"
  ) |>
  # arrange(gage_name) |>
  left_join(scott_gage, by = "gage_id") |>
  glimpse()


# Load data
temp <- klamathWaterData::temperature_data

temp_gage <- klamathWaterData::temperature_gage |>
  mutate(gage_id = tolower(gage_id))

flow <- klamathWaterData::flow_data

flow_gage <- klamathWaterData::flow_gage |>
  mutate(
    gage_id = tolower(gage_id),
    huc8 = as.numeric(huc8)
  )

# Shasta River gage reference table
shasta_gage <- temp_gage |>
  filter(location == "shasta river") |>
  bind_rows(
    flow_gage |>
      filter(location == "shasta river")
  ) |>
  select(-location, -gage_name) |>
  distinct(gage_id, .keep_all = TRUE)

glimpse(shasta_gage)

# Shasta River temperature and flow observations
shasta_data <- bind_rows(
  temp |>
    filter(location == "shasta river") |>
    mutate(gage_id = tolower(gage_id)),
  flow |>
    filter(location == "shasta river") |>
    mutate(gage_id = tolower(gage_id))
)

glimpse(shasta_data)

# Summarize period of record and available parameters
shasta_data_summary <- shasta_data |>
  filter(!is.na(date)) |>
  group_by(location, gage_id, gage_name) |>
  summarise(
    min_date = min(date, na.rm = TRUE),
    max_date = max(date, na.rm = TRUE),
    parameters = paste(
      sort(unique(variable_name[!is.na(variable_name)])),
      collapse = ", "
    ),
    .groups = "drop"
  ) |>
  left_join(
    shasta_gage,
    by = "gage_id"
  )

glimpse(shasta_data_summary)


# Combine Scott and Shasta summaries
reference_data <- bind_rows(
  scott_data_summary,
  shasta_data_summary
)

# Color by river
pal <- colorFactor(
  palette = c(
    "scott river" = "#1f78b4",
    "shasta river" = "#e31a1c"
  ),
  domain = reference_data$location
)

reference_map <- leaflet(reference_data) |>
  addProviderTiles(providers$Esri.WorldTopoMap) |>

  addCircleMarkers(
    lng = ~longitude,
    lat = ~latitude,
    color = ~pal(location),
    radius = 6,
    stroke = TRUE,
    weight = 1,
    fillOpacity = 0.9,

    # Hover
    label = ~paste0(
      gage_name, "\n",
      gage_id
    ),
    labelOptions = labelOptions(
      direction = "auto",
      textsize = "13px",
      style = list(
        "font-weight" = "normal",
        "padding" = "3px 8px"
      )
    ),

    # Click popup
    popup = ~paste0(
      "<b>", gage_name, "</b><br>",
      "<b>River:</b> ", location, "<br>",
      "<b>Gage ID:</b> ", gage_id, "<br>",
      "<b>Period:</b> ", min_date, " – ", max_date, "<br>",
      "<b>Parameters:</b><br>", parameters
    )
  ) |>

  addLegend(
    "bottomright",
    pal = pal,
    values = ~location,
    title = "River",
    opacity = 1
  )

reference_map



# UKL wq gages

# ------------------------------------------------------------
# 1. Load observations
# ------------------------------------------------------------

temp <- klamathWaterData::temperature_data |>
  mutate(
    gage_id = tolower(gage_id),
    parameter_group = "Temperature"
  )

flow <- klamathWaterData::flow_data |>
  mutate(
    gage_id = tolower(gage_id),
    parameter_group = "Flow"
  )

do_data <- klamathWaterData::do_data |>
  mutate(
    gage_id = tolower(gage_id),
    parameter_group = "Dissolved oxygen"
  )

ph_data <- klamathWaterData::ph_data |>
  mutate(
    gage_id = tolower(gage_id),
    parameter_group = "pH"
  )

# ------------------------------------------------------------
# 2. Load gage metadata
# ------------------------------------------------------------

temp_gage <- klamathWaterData::temperature_gage |>
  mutate(gage_id = tolower(gage_id))

flow_gage <- klamathWaterData::flow_gage |>
  mutate(gage_id = tolower(gage_id))

do_gage <- klamathWaterData::do_gage |>
  mutate(gage_id = tolower(gage_id))

ph_gage <- klamathWaterData::ph_gage |>
  mutate(gage_id = tolower(gage_id))

# ------------------------------------------------------------
# 3. Filter to Upper Klamath Lake
# ------------------------------------------------------------

ukl_pattern <- regex(
  "upper klamath lake|agency lake",
  ignore_case = TRUE
)

ukl_data <- bind_rows(
  temp    |> filter(str_detect(location, ukl_pattern)),
  flow    |> filter(str_detect(location, ukl_pattern)),
  do_data |> filter(str_detect(location, ukl_pattern)),
  ph_data |> filter(str_detect(location, ukl_pattern))
) |>
  mutate(date = as.Date(date)) |>
  filter(
    !is.na(gage_id),
    !is.na(date)
  )

# ------------------------------------------------------------
# 4. Combine gage metadata
# ------------------------------------------------------------

ukl_gages <- bind_rows(
  temp_gage |> filter(str_detect(location, ukl_pattern)),
  flow_gage |> filter(str_detect(location, ukl_pattern)),
  do_gage   |> mutate(huc8 = as.numeric(huc8)) |> filter(str_detect(location, ukl_pattern)),
  ph_gage   |> filter(str_detect(location, ukl_pattern))
) |>
  mutate(
    latitude = as.numeric(latitude),
    longitude = as.numeric(longitude)
  ) |>
  filter(
    !is.na(gage_id),
    !is.na(latitude),
    !is.na(longitude)
  ) |>
  select(gage_id, latitude, longitude) |>
  distinct(gage_id, .keep_all = TRUE)

# ------------------------------------------------------------
# 5. Summarize parameters and period of record
# ------------------------------------------------------------

ukl_data_summary <- ukl_data |>
  group_by(location, gage_id, gage_name) |>
  summarise(
    min_date = min(date, na.rm = TRUE),
    max_date = max(date, na.rm = TRUE),
    parameter_groups = paste(
      sort(unique(parameter_group[!is.na(parameter_group)])),
      collapse = ", "
    ),
    parameters = paste(
      sort(unique(variable_name[!is.na(variable_name)])),
      collapse = ", "
    ),
    n_records = n(),
    .groups = "drop"
  ) |>
  left_join(
    ukl_gages,
    by = "gage_id"
  ) |>
  filter(
    !is.na(latitude),
    !is.na(longitude)
  ) |>
  arrange(gage_name)

# ------------------------------------------------------------
# 6. Create Leaflet map
# ------------------------------------------------------------

ukl_pal <- colorFactor(
  palette = "Set2",
  domain = ukl_data_summary$parameter_groups
)

ukl_reference_map <- leaflet(ukl_data_summary) |>
  addProviderTiles(providers$Esri.WorldTopoMap) |>
  addCircleMarkers(
    lng = ~longitude,
    lat = ~latitude,
    color = ~ukl_pal(parameter_groups),
    radius = 7,
    stroke = TRUE,
    weight = 1,
    fillOpacity = 0.9,

    label = ~lapply(
      paste0(
        "<b>", gage_name, "</b><br>",
        "<b>Gage ID:</b> ", gage_id, "<br>",
        "<b>Parameters:</b> ", parameter_groups, "<br>",
        "<b>Period:</b> ", min_date, " – ", max_date
      ),
      HTML
    ),

    labelOptions = labelOptions(
      direction = "auto",
      textsize = "13px",
      textOnly = FALSE
    ),

    popup = ~paste0(
      "<b>", gage_name, "</b><br>",
      "<b>Location:</b> ", location, "<br>",
      "<b>Gage ID:</b> ", gage_id, "<br>",
      "<b>Minimum date:</b> ", min_date, "<br>",
      "<b>Maximum date:</b> ", max_date, "<br>",
      "<b>Records:</b> ", format(n_records, big.mark = ","), "<br>",
      "<b>Parameter groups:</b> ", parameter_groups, "<br>",
      "<b>Variables:</b> ", parameters
    )
  ) |>
  addLegend(
    position = "bottomright",
    pal = ukl_pal,
    values = ~parameter_groups,
    title = "Parameters available",
    opacity = 1
  ) |>
  fitBounds(
    lng1 = min(ukl_data_summary$longitude, na.rm = TRUE),
    lat1 = min(ukl_data_summary$latitude, na.rm = TRUE),
    lng2 = max(ukl_data_summary$longitude, na.rm = TRUE),
    lat2 = max(ukl_data_summary$latitude, na.rm = TRUE)
  )

ukl_reference_map

# save table and map
# TODO only saves to share with Torrey and Danielle

ukl_wq_data_summary <- ukl_data_summary |>
  select(-parameter_groups) |>
  glimpse()

write_csv(ukl_wq_data_summary,"data-raw/data-exploration/ukl_wq_data_summary.csv")


saveWidget(
  ukl_reference_map,
  file = "data-raw/data-exploration/ukl_wq_gage_reference_map.html",
  selfcontained = TRUE)

