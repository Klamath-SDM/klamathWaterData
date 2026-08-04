library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(sf)
library(janitor)
library(klamathWaterData)
library(leaflet)

#  the purpose of this script is just to keep track of Scott and Shasta River temp and flow gages
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
