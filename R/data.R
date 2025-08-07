#' @name temperature_gage
#' @title Temperature gages in the Klamath Basin watershed (HUC8 18010204)
#' @description A dataset containing metadata for temperature gages located across the Klamath Basin watershed.
#' Includes location, agency, and hydrologic unit code (HUC) information for each station.
#' @format A tibble with 94 rows and 8 columns
#' \itemize{
#'   \item{\code{stream}: name of the stream or river where the gage is located
#'   \item{\code{gage_name}: name of the gaging station
#'   \item{\code{gage_id}: unique identifier for the gage
#'   \item{\code{agency}: agency responsible for operating or maintaining the gage (e.g., USGS, State of Oregon Dept. of Environmental Quality,
#'   Hoopa Valley Tribe (Tribal), USDA FS PIBO Monitoring Program)
#'   \item{\code{latitude}: latitude coordinate of the gage location
#'   \item{\code{longitude: longitude coordinate of the gage location
#'   \item{\code{river_mile}: closest river mile location relative to river mouth or a reference point
#'   \item{\code{huc8}: 8-digit Hydrologic Unit Code identifying the sub-basin where the gage is located
#' }
"temperature_gage"

#' @name temperature_data
#' @title Publicly available temperature data in the Klamath Basin watershed (HUC8 18010204)
#' @description Mean, min and max temperature data from gages across the Klamath Basin. Raw data was obtained from USGS and WQX data portals.
#' @format A tibble with 348,642 rows and 8 columns
#' \itemize{
#'   \item \code{stream}: stream associated where data was collected/where gage is located
#'   \item \code{gage_name}: name of the gaging station
#'   \item \code{gage_id}: unique identifier for the gage
#'   \item \code{variable_name}: variable measured: "Temperature"
#'   \item \code{value}: observed value of the temperature (numeric)
#'   \item \code{unit}: units of measurement (e.g., degrees Celsius)
#'   \item \code{statistic}: summary statistic type: "min", "max", or "mean"
#'   \item \code{date}: date of the observation
#'   }
"temperature_data"

#' @name ph_gage
#' @description A dataset containing metadata for pH gages located across the Klamath Basin watershed.
#' Includes location, agency, and hydrologic unit code (HUC) information for each station.
#' @format A tibble with 124 rows and 8 columns
#' \itemize{
#'   \item{\code{stream}: name of the stream or river where the gage is located
#'   \item{\code{gage_name}: name of the gaging station
#'   \item{\code{gage_id}: anique identifier for the gage
#'   \item{\code{agency}: agency responsible for operating or maintaining the gage (e.g., USGS, State of Oregon Dept. of Environmental Quality,
#'   Hoopa Valley Tribe (Tribal), Bureau of Reclamation", Klamath Tribes (Tribal), Yurok Tribe of the Yurok Reservation, California (Tribal),
#'   California State Water Resources Control Board,  National Park Service Water Resources Division, EPA National Aquatic Resources Survey (NARS))
#'   \item{\code{latitude}: latitude coordinate of the gage location
#'   \item{\code{longitude: longitude coordinate of the gage location
#'   \item{\code{river_mile}: closest river mile location relative to river mouth or a reference point
#'   \item{\code{huc8}: 8-digit Hydrologic Unit Code identifying the sub-basin where the gage is located
#' }
"ph_gage"

#' @name ph_data
#' @title Publicly available pH data in the Klamath Basin watershed (HUC8 18010204)
#' @description Mean, min and max pH data from gages across the Klamath Basin. Raw data was obtained from USGS and WQX data portals.
#' @format A tibble with 111,594 rows and 8 columns
#' \itemize{
#'   \item \code{stream}: stream associated where data was collected/where gage is located
#'   \item \code{gage_name}: name of the gaging station
#'   \item \code{gage_id}: unique identifier for the gage
#'   \item \code{variable_name}: variable measured: "pH"
#'   \item \code{value}: observed value of the temperature (numeric)
#'   \item \code{unit}: units of measurement: sdt unit
#'   \item \code{statistic}: summary statistic type: "min", "max", or "mean"
#'   \item \code{date}: date of the observation
#'   }
"ph_data"

#' @name flow_gage
#' @description A dataset containing metadata for flow gages located across the Klamath Basin watershed.
#' Includes location, agency, and hydrologic unit code (HUC) information for each station.
#' @format A tibble with 49 rows and 8 columns
#' \itemize{
#'   \item{\code{stream}: name of the stream or river where the gage is located
#'   \item{\code{gage_name}: name of the gaging station
#'   \item{\code{gage_id}: unique identifier for the gage
#'   \item{\code{agency}: agency responsible for operating or maintaining the gage (e.g., USGS, Quartz Valley Indian Community of the Quartz Valley Reservation of California (Tribal),
#'   Klamath Tribes (Tribal))
#'   \item{\code{latitude}: latitude coordinate of the gage location
#'   \item{\code{longitude: longitude coordinate of the gage location
#'   \item{\code{river_mile}: closest river mile location relative to river mouth or a reference point
#'   \item{\code{huc8}: 8-digit Hydrologic Unit Code identifying the sub-basin where the gage is located
#' }
"flow_gage"

#' @name flow_data
#' @title Publicly available flow data in the Klamath Basin watershed (HUC8 18010204)
#' @description Mean flow data from gages across the Klamath Basin. Raw data was obtained from USGS and WQX data portals.
#' @format A tibble with 114,654 rows and 8 columns
#' \itemize{
#'   \item \code{stream}: stream associated where data was collected/where gage is located
#'   \item \code{gage_name}: name of the gaging station
#'   \item \code{gage_id}: unique identifier for the gage
#'   \item \code{variable_name}: variable measured: "flow"
#'   \item \code{value}: observed value of the temperature (numeric)
#'   \item \code{unit}: units of measurement: cfs
#'   \item \code{statistic}: summary statistic type: mean"
#'   \item \code{date}: date of the observation
#'   }
"flow_data"

#' @name do_gage
#' @description A dataset containing metadata for dissolved oxygen gages located across the Klamath Basin watershed.
#' Includes location, agency, and hydrologic unit code (HUC) information for each station.
#' @format A tibble with 28 rows and 8 columns
#' \itemize{
#'   \item{\code{stream}: name of the stream or river where the gage is located
#'   \item{\code{gage_name}: name of the gaging station
#'   \item{\code{gage_id}: unique identifier for the gage
#'   \item{\code{agency}: agency responsible for operating or maintaining the gage (e.g., USGS, Hoopa Valley Tribe (Tribal))
#'   \item{\code{latitude}: latitude coordinate of the gage location
#'   \item{\code{longitude: longitude coordinate of the gage location
#'   \item{\code{river_mile}: closest river mile location relative to river mouth or a reference point
#'   \item{\code{huc8}: 8-digit Hydrologic Unit Code identifying the sub-basin where the gage is located
#' }
"do_gage"

#' @name do_data
#' @title Publicly available dissolved oxygen data in the Klamath Basin watershed (HUC8 18010204)
#' @description Mean, min and max dissolved oxygen data from gages across the Klamath Basin. Raw data was obtained from USGS and WQX data portals.
#' @format A tibble with 160,456 rows and 8 columns
#' \itemize{
#'   \item \code{stream}: stream associated where data was collected/where gage is located
#'   \item \code{gage_name}: name of the gaging station
#'   \item \code{gage_id}: unique identifier for the gage
#'   \item \code{variable_name}: variable measured: "do"
#'   \item \code{value}: observed value of the temperature (numeric)
#'   \item \code{unit}: units of measurement: mg/L
#'   \item \code{statistic}: summary statistic type: "max, "min, "mean"
#'   \item \code{date}: date of the observation
#'   }
"do_data"

#' @name usgs_dam_removal_monitoring_layers
#' @title Spatial layers from USGS dam removal monitoring in the Klamath Basin
#' @description
#' A named list of spatial (`sf`) layers pulled from the Klamath Dam Removal Monitoring Web Map hosted on ArcGIS Online.
#' Each element represents a layer of interest, such as reservoir footprints, sediment monitoring points, or dam sites.
#' @examples
#' names(usgs_dam_removal_monitoring_layers)
#' usgs_dam_removal_monitoring_layers$geomorphic_reaches |> sf::st_geometry() |> plot()
"usgs_dam_removal_monitoring_layers"
