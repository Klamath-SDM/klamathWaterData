#' @name temperature_gage
#' @title Temperature gages in the Klamath Basin watershed (HUC8 18010204)
#' @description A dataset containing metadata for temperature gages located across the Klamath Basin watershed.
#' Includes location, agency, and hydrologic unit code (HUC) information for each station.
#' @format A tibble with 94 rows and 8 columns
#' \itemize{
#'   \item{\code{location}: location associated where data was collected/where gage is located
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
#'   \item \code{location}: location associated where data was collected/where gage is located
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
#'   \item{\code{location}: location associated where data was collected/where gage is located
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
#'   \item \code{location}: location associated where data was collected/where gage is located
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
#'   \item{\code{location}: location associated where data was collected/where gage is located
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
#' @description Mean flow data from gages across the Klamath Basin. Raw data was obtained from USGS, WQX and USBR data portals.
#' @format A tibble with 128,113 rows and 8 columns
#' \itemize{
#'   \item \code{location}: location associated where data was collected/where gage is located
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
#' @format A tibble with 131 rows and 8 columns
#' \itemize{
#'   \item{\code{location}: location associated where data was collected/where gage is located
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
#' @format A tibble with 365,162 rows and 8 columns
#' \itemize{
#'   \item \code{location}: location associated where data was collected/where gage is located
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

#' @name water_level_data
#' @title Lake water surface elevation data from four different USGS gages, and one USBR monitoring site across the Klamath Basin
#' @description Lake water surface elevation (ft) data from the following gages:
#' \itemize{
#'   \item 11505900
#'   \item 11504300
#'   \item 11505800
#'   \item 11507001
#'   \item usbr tule lake sump 1a
#' @format A tibble with 30,084 rows and 8 columns:
#' \itemize{
#'   \item \code{location}: location associated where data was collected/where gage is located
#'   \item \code{gage_name}: name of the gaging station
#'   \item \code{gage_id}: unique identifier for the gage
#'   \item \code{variable_name}: variable measured: "water level"
#'   \item \code{value}: observed value of the temperature (numeric)
#'   \item \code{unit}: units of measurement: feet
#'   \item \code{statistic}: summary statistic type: "mean"
#'   \item \code{date}: date of the observation
#'   }
"water_level_data"

#' @name water_level_gage
#' @title Metadata for water level gages in the Klamath Basin.
#'
#' @description A dataset containing metadata for water level gages located
#' across the Klamath Basin watershed, including location, agency, and
#' Hydrologic Unit Code (HUC8) information for each station.
#' \itemize{
#'   \item 11505900
#'   \item 11504300
#'   \item 11505800
#'   \item 11507001
#'   \item usbr tule lake sump 1a
#'   }
#' @format A tibble with 5 rows and 7 columns:
#' \itemize{
#'   \item \code{location}: location associated where data was collected/where gage is located
#'   \item \code{gage_name}: name of the gaging station
#'   \item \code{gage_id}: unique identifier for the gage
#'   \item \code{agency}: agency responsible for operating or maintaining the gage
#'   \item \code{latitude}: latitude coordinate of the gage location
#'   \item \code{longitude}: longitude coordinate of the gage location
#'   \item \code{huc8}: 8-digit Hydrologic Unit Code identifying the sub-basin where the gage is located
#'   }
"water_level_gage"

#' @name hydromet_data
#' @title Daily hydromet data from USBR Klamath Basin monitoring network
#' @description Daily hydrological and meteorological data from the U.S. Bureau of Reclamation (USBR)
#' Pacific Northwest Hydromet system for the Klamath Basin. Data are retrieved from the USBR
#' webarccsv API and cover reservoir forebay elevations, stream gauge heights, and discharge
#' at 15 stations across the Klamath Project area in Oregon and California.
#' Data span from water year 1918 (October 1, 1918) to the present.
#'
#' Parameter codes can be decoded using the \code{param_defs} lookup table defined in
#' \code{data-raw/data-pull/hydromet-data-pull.R}, which maps each short code to a full name,
#' units, and description:
#' \tabular{lll}{
#'   \strong{parameter} \tab \strong{full_name} \tab \strong{units} \cr
#'   FB  \tab Forebay elevation (instantaneous) \tab ft \cr
#'   FD  \tab Forebay elevation (daily average) \tab ft \cr
#'   GD  \tab Gauge height (daily average)      \tab ft \cr
#'   GJ  \tab Gauge height, junction/sump       \tab ft \cr
#'   GJ2 \tab Gauge height, junction/sump #2    \tab ft \cr
#'   QD  \tab Discharge (daily average)         \tab cfs \cr
#'   QJ  \tab Canal/diversion discharge         \tab cfs \cr
#'   QP  \tab Pumped discharge                  \tab cfs \cr
#' }
#' @format A tibble with columns:
#' \itemize{
#'   \item \code{site}: USBR station code (e.g., "GER", "CLK", "HRPO")
#'   \item \code{parameter}: short USBR parameter code (e.g., "FD", "QD", "GD"); join to \code{param_defs} for full name and units
#'   \item \code{label}: descriptive label combining site location and parameter (e.g., "Gerber Reservoir - Daily Avg Forebay Elevation (ft)")
#'   \item \code{date}: date of observation (1918-01-01 to present) (Date)
#'   \item \code{value}: observed numeric value
#' }
#' @source USBR PN Hydromet \url{https://www.usbr.gov/pn/hydromet/klamath/arcread.html}
"hydromet_data"

#' @name dswe_monthly
#' @title Monthly aggregated dynamic surface water extent (DSWE) data
#' @description Monthly summary statistics for the dynamic surface water extent for wildlife refuges in the Klamath Basin.
#' Raw data was pulled from the [USGS LandSat Collection](https://www.usgs.gov/landsat-missions/landsat-collection-2-level-3-dynamic-surface-water-extent-science-product)
#' and processed using a [DSWE algorithm developed by USGS in 2019](https://www.usgs.gov/publications/improved-automated-detection-subpixel-scale-inundation-revised-dynamic-surface-water).
#' LandSat data were accessed through [Google Earth Engine](https://developers.google.com/earth-engine/datasets/catalog/landsat/) using the R package [rgee](https://r-spatial.github.io/rgee/).
#' For full documentation on the process, including bounding boxes used for each wildlife refuge,
#' limitations, and assumptions, please see vignettes/dswe_klamath_basin.Rmd.
#' Currently the data span `2013-2025`. Though data goes back as far as `1984-2025`, only the data from 2013 to 2025 meets the criteria outlined in the DSWE calculations.
#' @format A tibble with 139 rows and 9 columns
#' \itemize{
#'   \item \code{area}: wildlife refuge area associated with the statistics. Currently one of `Tule Lake`, `Clear Lake`, `Bear Valley`, `Lower Klamath Sheepy`, `Upper Klamath Lake`, and `Klamath Marsh`
#'   \item \code{year}: calendar year
#'   \item \code{month}: month for which statistics were calculated, integer
#'   \item \code{mean_total_water}: mean total water coverage for a given month (shown as percentage of total pixels). Calculated as the sum of mean_class1, mean_class2, and mean_class3.
#'   \item \code{sd_total_water}: standard deviation of total water coverage for a given month
#'   \item \code{mean_class1}: mean Class 1 (High Confidence Water) coverage for a given month (shown as percentage of total pixels)
#'   \item \code{mean_class2}: mean Class 2 (Moderate Confidence Water) coverage for a given month (shown as percentage of total pixels)
#'   \item \code{mean_class3}: mean Class 3 (Partial Surface Water / Potential Wetland) coverage for a given month (shown as percentage of total pixels)
#'   \item \code{n}: number of LandSat images available for a given month and year with no cloud coverage
#'   }
"dswe_monthly"
