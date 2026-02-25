library(sf)
library(dplyr)
library(leaflet)

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
  addCircleMarkers(
    data = rivermile::all_klamath_rivers_pts,
    radius = 3,
    stroke = FALSE,
    fillOpacity = 0.9,
    fillColor = ~pal_rm(river_mile),
    popup = ~paste0("River: ", river, "<br>",
                    "River mile: ", river_mile),
    group = "River miles"
  ) |>
  addCircleMarkers(
    data = temp_pts |> filter(!is.na(river_mile)),
    radius = 8,
    fillOpacity = 0.8,
    fillColor = "green",
    color = "darkgreen",
    popup = ~paste0("Type: Temperature<br>",
                    "River: ", stream, "<br>",
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
                    "River: ", stream, "<br>",
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
                    "River: ", stream, "<br>",
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
                    "River: ", stream, "<br>",
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
