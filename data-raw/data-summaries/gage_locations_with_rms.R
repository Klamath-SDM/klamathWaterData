library(sf)
library(dplyr)
library(leaflet)
library(ggplot2)
library(htmlwidgets)

make_river_pts <- function(df) {
  df |>
    st_as_sf(coords = c("longitude", "latitude"),
             crs = 4326,
             remove = FALSE)
}

temp_pts <- make_river_pts(klamathWaterData::temperature_gage)
do_pts   <- make_river_pts(klamathWaterData::do_gage)
flow_pts <- make_river_pts(klamathWaterData::flow_gage)
ph_pts   <- make_river_pts(klamathWaterData::ph_gage)

pal_rm <- colorNumeric(
  palette = "viridis",
  domain  = rivermile::all_klamath_rivers_pts$river_mile
)

leaflet() |>
  addTiles() |>
  # addCircleMarkers(
  #   data = rivermile::all_klamath_rivers_pts,
  #   radius = 3,
  #   stroke = FALSE,
  #   fillOpacity = 0.9,
  #   fillColor = ~pal_rm(river_mile),
  #   popup = ~paste0("River: ", river, "<br>",
  #                   "River mile: ", river_mile),
  #   group = "River miles"
  # ) |>
  addPolylines(
    data = rivermile::all_klamath_rivers_line,
    color = "darkblue",
    weight = 2,
    popup = ~paste0("River: ", river),
    group = "River miles"
  ) |>
  addCircleMarkers(
    data = temp_pts |> filter(!is.na(river_mile)),
    radius = 8,
    fillOpacity = 0.8,
    fillColor = "green",
    color = "darkgreen",
    popup = ~paste0("Type: Temperature<br>",
                    "River: ", location, "<br>",
                    "River mile: ", river_mile, "<br>",
                    "Gage Name: ", gage_name),
    group = "Temperature gages"
  ) |>
  addCircleMarkers(
    data = do_pts |> filter(!is.na(river_mile)),
    radius = 8,
    fillOpacity = 0.8,
    fillColor = "deepskyblue",
    color = "dodgerblue4",
    popup = ~paste0("Type: DO<br>",
                    "River: ", location, "<br>",
                    "River mile: ", river_mile, "<br>",
                    "Gage Name: ", gage_name),
    group = "DO gages"
  ) |>
  addCircleMarkers(
    data = flow_pts |> filter(!is.na(river_mile)),
    radius = 8,
    fillOpacity = 0.8,
    fillColor = "orange",
    color = "darkorange4",
    popup = ~paste0("Type: Flow<br>",
                    "River: ", location, "<br>",
                    "River mile: ", river_mile, "<br>",
                    "Gage Name: ", gage_name),
    group = "Flow gages"
  ) |>
  addCircleMarkers(
    data = ph_pts |> filter(!is.na(river_mile)),
    radius = 8,
    fillOpacity = 0.8,
    fillColor = "purple",
    color = "purple4",
    popup = ~paste0("Type: pH<br>",
                    "River: ", location, "<br>",
                    "River mile: ", river_mile, "<br>",
                    "Gage Name: ", gage_name),
    group = "pH gages"
  ) |>
  addLayersControl(
    overlayGroups = c("River miles",
                      "Temperature gages",
                      "DO gages",
                      "Flow gages",
                      "pH gages"),
    options = layersControlOptions(collapsed = FALSE)
  ) |>
  addLegend(
    pal = pal_rm,
    values = rivermile::all_klamath_rivers_pts$river_mile,
    title = "River mile",
    opacity = 1
  )


# temperature specific leaflet map and plot ----------------------------------------
temp_pts_karuk <- make_river_pts(klamathWaterData::temperature_gage |> filter(agency == "karuk tribe"))
temp_pts_hoopa <- make_river_pts(klamathWaterData::temperature_gage |> filter(agency == "hoopa valley tribe"))
temp_pts <- make_river_pts(klamathWaterData::temperature_gage |> filter(!(agency %in% c("hoopa valley tribe", "karuk tribe"))))

temperature_gage_map <- leaflet() |>
  addTiles() |>
  addPolylines(
    data = rivermile::all_klamath_rivers_line,
    color = "darkblue",
    weight = 2,
    popup = ~paste0("River: ", river),
    group = "River"
  ) |>
  addCircleMarkers(
    data = temp_pts |> filter(!is.na(river_mile)),
    radius = 8,
    fillOpacity = 0.8,
    fillColor = "green",
    color = "darkgreen",
    popup = ~paste0("Type: Temperature<br>",
                    "River: ", location, "<br>",
                    "River mile: ", river_mile, "<br>",
                    "Gage Name: ", gage_name, "<br>",
                    "Agency: ", agency),
    group = "Temperature gages"
  ) |>
  addCircleMarkers(
    data = temp_pts_karuk |> filter(!is.na(river_mile)),
    radius = 8,
    fillOpacity = 0.8,
    fillColor = "pink",
    color = "red",
    popup = ~paste0("Type: Temperature<br>",
                    "River: ", location, "<br>",
                    "River mile: ", river_mile, "<br>",
                    "Gage Name: ", gage_name, "<br>",
                    "Agency: ", agency),
    group = "Karuk Temperature gages"
  ) |>
  addCircleMarkers(
    data = temp_pts_hoopa |> filter(!is.na(river_mile)),
    radius = 8,
    fillOpacity = 0.8,
    fillColor = "purple",
    color = "darkgrey",
    popup = ~paste0("Type: Temperature<br>",
                    "River: ", location, "<br>",
                    "River mile: ", river_mile, "<br>",
                    "Gage Name: ", gage_name, "<br>",
                    "Agency: ", agency),
    group = "Hoopa Temperature gages"
  ) |>
  addLayersControl(
    overlayGroups = c("River",
                      "Temperature gages",
                      "Hoopa Temperature gages",
                      "Karuk Temperature gages"),
    options = layersControlOptions(collapsed = FALSE)
  )

temperature_gage_map

saveWidget(
  temperature_gage_map,
  file = "data-raw/data-summaries/temperature_gage_map.html",
  selfcontained = TRUE
)

qc_data <- temperature_data |>
  filter(grepl("^karuk-|^hoopa-", gage_id)) |>
  left_join(temperature_gage |> select(gage_id, agency), by = "gage_id") |>
  mutate(facet_label = paste0(gage_name, " (", agency, ")"))

karuk_hoopa_temp_qc_plot <- ggplot(qc_data, aes(x = date, y = value, color = statistic)) +
  geom_line(linewidth = 0.4) +
  facet_wrap(~ facet_label, ncol = 2, scales = "free_x") +
  scale_color_manual(values = c(min = "#2166AC", mean = "#1B1B1B", max = "#B2182B")) +
  labs(
    title = "Karuk & Hoopa Water Temperature",
    subtitle = "Daily min / mean / max",
    x = NULL, y = "Water Temperature (\u00b0C)", color = "Statistic"
  ) +
  theme_minimal() +
  theme(
    legend.position = "top",
    strip.text = element_text(face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

karuk_hoopa_temp_qc_plot

ggsave(
  filename = "data-raw/data-summaries/karuk_hoopa_temperature_qc.png",
  plot = karuk_hoopa_temp_qc_plot,
  width = 12, height = 9, dpi = 300
)
