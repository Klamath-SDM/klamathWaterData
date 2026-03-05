library(tidyverse)
library(dplyr)
library(sf)
library(purrr)

# these layers are being sourced from USGS Dam Removal Monitoring Map: https://ca.water.usgs.gov/apps/klamath-dam-removal-monitoring.html

base_url <- "https://services.arcgis.com/v01gqwM5QqNysAAi/arcgis/rest/services/Klamath_Web_Map/FeatureServer"

layers_of_interest <- c(geomorphic_reaches = 0,
                        dams_tb_removed = 8,
                        dams = 9,
                        copco_res = 3,
                        estuary_bedsed = 6,
                        jc_boyle_reservoir_bedsed = 2,
                        ig_reservoir_bedsed = 4,
                        sediment_bug = 11,
                        fingerprinting = 5)

read_arcgis_layer <- function(layer_id) {
  url <- glue::glue("{base_url}/{layer_id}/query?where=1=1&outFields=*&f=geojson")
  sf::read_sf(url)
}

usgs_dam_removal_monitoring_layers <- purrr::map(layers_of_interest, read_arcgis_layer)


# save rda files
usethis::use_data(usgs_dam_removal_monitoring_layers, overwrite = TRUE)
