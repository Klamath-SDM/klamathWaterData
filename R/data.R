#' @name temperature_gage
#' @title Temperature gages in the Klamath Basin watershed (HUC8 18010204)
#' @examples
#' temperature_gage |> pillar::glimpse()
"temperature_gage"

#' @name temperature_data
#' @title Publicly available temperature data in the Klamath Basin watershed (HUC8 18010204)
#' @examples
#' temperature_data |> pillar::glimpse()
"temperature_data"

#' @name ph_gage
#' @title pH gages in the Klamath Basin watershed (HUC8 18010204)
#' @examples
#' ph_gage |> pillar::glimpse()
"ph_gage"

#' @name ph_data
#' @title Publicly available pH data in the Klamath Basin watershed (HUC8 18010204)
#' @examples
#' ph_data |> pillar::glimpse()
"ph_data"

#' @name flow_gage
#' @title Flow gages in the Klamath Basin watershed (HUC8 18010204)
#' @examples
#' flow_gage |> pillar::glimpse()
"flow_gage"

#' @name flow_data
#' @title Publicly available flow data in the Klamath Basin watershed (HUC8 18010204)
#' @examples
#' flow_data |> pillar::glimpse()
"flow_data"

#' @name do_gage
#' @title Dissolved oxygen gages in the Klamath Basin watershed (HUC8 18010204)
#' @examples
#' do_gage |> pillar::glimpse()
"do_gage"

#' @name do_data
#' @title Publicly available dissolved oxygen data in the Klamath Basin watershed (HUC8 18010204)
#' @examples
#' do_gage |> pillar::glimpse()
"do_gage"

#' @name usgs_dam_removal_monitoring_layers
#' @title Spatial layers from USGS dam removal monitoring in the Klamath Basin
#' @description
#' A named list of spatial (`sf`) layers pulled from the Klamath Dam Removal Monitoring Web Map hosted on ArcGIS Online.
#' Each element represents a layer of interest, such as reservoir footprints, sediment monitoring points, or dam sites.
#' @examples
#' names(usgs_dam_removal_monitoring_layers)
#' usgs_dam_removal_monitoring_layers$geomorphic_reaches |> sf::st_geometry() |> plot()
"usgs_dam_removal_monitoring_layers"
