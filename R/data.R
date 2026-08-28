#' @name temperature_gage
#' @title Temperature gages in the Klamath Basin watershed (HUC8 18010204)
#' @description A dataset containing metadata for temperature gages located across the Klamath Basin watershed.
#' Includes location, agency, and hydrologic unit code (HUC) information for each station.
#' @format A tibble with 96 rows and 8 columns
#' \itemize{
#'   \item \code{location}: location associated where data was collected/where gage is located
#'   \item \code{gage_name}: name of the gaging station
#'   \item \code{gage_id}: unique identifier for the gage
#'   \item \code{agency}: agency responsible for operating or maintaining the gage (e.g., USGS, State of Oregon Dept. of Environmental Quality,
#'   Hoopa Valley Tribe (Tribal), USDA FS PIBO Monitoring Program)
#'   \item \code{latitude}: latitude coordinate of the gage location
#'   \item \code{longitude}: longitude coordinate of the gage location
#'   \item \code{river_mile}: closest river mile location relative to river mouth or a reference point
#'   \item \code{huc8}: 8-digit Hydrologic Unit Code identifying the sub-basin where the gage is located
#' }
"temperature_gage"

#' @name temperature_data
#' @title Publicly available temperature data in the Klamath Basin watershed (HUC8 18010204)
#' @description Mean, min and max temperature data from gages across the Klamath Basin. Raw data was obtained from USGS, WQX and USFWS.
#' @format A tibble with 414,312 rows and 8 columns
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
#' @title pH gages in the Klamath Basin watershed (HUC8 18010204)
#' @description A dataset containing metadata for pH gages located across the Klamath Basin watershed.
#' Includes location, agency, and hydrologic unit code (HUC) information for each station.
#' @format A tibble with 124 rows and 8 columns
#' \itemize{
#'   \item \code{location}: location associated where data was collected/where gage is located
#'   \item \code{gage_name}: name of the gaging station
#'   \item \code{gage_id}: unique identifier for the gage
#'   \item \code{agency}: agency responsible for operating or maintaining the gage (e.g., USGS, State of Oregon Dept. of Environmental Quality,
#'   Hoopa Valley Tribe (Tribal), Bureau of Reclamation, Klamath Tribes (Tribal), Yurok Tribe of the Yurok Reservation, California (Tribal),
#'   California State Water Resources Control Board, National Park Service Water Resources Division, EPA National Aquatic Resources Survey (NARS))
#'   \item \code{latitude}: latitude coordinate of the gage location
#'   \item \code{longitude}: longitude coordinate of the gage location
#'   \item \code{river_mile}: closest river mile location relative to river mouth or a reference point
#'   \item \code{huc8}: 8-digit Hydrologic Unit Code identifying the sub-basin where the gage is located
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
#' @title Flow gages in the Klamath Basin watershed (HUC8 18010204)
#' @description A dataset containing metadata for flow gages located across the Klamath Basin watershed.
#' Includes location, agency, and hydrologic unit code (HUC) information for each station.
#' @format A tibble with 118 rows and 8 columns
#' \itemize{
#'   \item \code{location}: location associated where data was collected/where gage is located
#'   \item \code{gage_name}: name of the gaging station
#'   \item \code{gage_id}: unique identifier for the gage
#'   \item \code{agency}: agency responsible for operating or maintaining the gage (e.g., USGS, Quartz Valley Indian Community of the Quartz Valley Reservation of California (Tribal),
#'   Klamath Tribes (Tribal))
#'   \item \code{latitude}: latitude coordinate of the gage location
#'   \item \code{longitude}: longitude coordinate of the gage location
#'   \item \code{river_mile}: closest river mile location relative to river mouth or a reference point
#'   \item \code{huc8}: 8-digit Hydrologic Unit Code identifying the sub-basin where the gage is located
#' }
"flow_gage"

#' @name flow_data
#' @title Publicly available flow data in the Klamath Basin watershed (HUC8 18010204)
#' @description Mean flow data from gages across the Klamath Basin. Raw data was obtained from USGS, WQX, USBR, and OWRD data portals.
#' @format A tibble with 436,361 rows and 8 columns
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
#' @title Dissolved oxygen gages in the Klamath Basin watershed (HUC8 18010204)
#' @description A dataset containing metadata for dissolved oxygen gages located across the Klamath Basin watershed.
#' Includes location, agency, and hydrologic unit code (HUC) information for each station.
#' @format A tibble with 131 rows and 8 columns
#' \itemize{
#'   \item \code{location}: location associated where data was collected/where gage is located
#'   \item \code{gage_name}: name of the gaging station
#'   \item \code{gage_id}: unique identifier for the gage
#'   \item \code{agency}: agency responsible for operating or maintaining the gage (e.g., USGS, Hoopa Valley Tribe (Tribal))
#'   \item \code{latitude}: latitude coordinate of the gage location
#'   \item \code{longitude}: longitude coordinate of the gage location
#'   \item \code{river_mile}: closest river mile location relative to river mouth or a reference point
#'   \item \code{huc8}: 8-digit Hydrologic Unit Code identifying the sub-basin where the gage is located
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
#' @title Lake water surface elevation data from four different USGS gages, and six USBR monitoring sites across the Klamath Basin
#' @description Lake water surface elevation (ft) data from the following gages:
#' \itemize{
#'   \item 11505900
#'   \item 11504300
#'   \item 11505800
#'   \item 11507001
#'   \item usbr-tulc (Sump 1A; combines TID Daily Report data, 1986-2021, with USBR Hydromet data, 2024-present)
#'   \item usbr-tulc2 (Tule Lake Sump 1B, USBR Hydromet)
#'   \item usbr-ger (Gerber Reservoir, USBR Hydromet)
#'   \item usbr-mal (Malone Reservoir, USBR Hydromet)
#'   \item usbr-lrs
#'   \item usbr-clk (Clear Lake West Lobe, USBR Hydromet)
#'   }
#' @format A tibble with 81,730 rows and 8 columns:
#' \itemize{
#'   \item \code{location}: location associated where data was collected/where gage is located
#'   \item \code{gage_name}: name of the gaging station
#'   \item \code{gage_id}: unique identifier for the gage
#'   \item \code{variable_name}: variable measured: "water level"
#'   \item \code{value}: observed value of the temperature (numeric)
#'   \item \code{unit}: units of measurement: feet, feet above sea level - USBR datum
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
#'   \item usbr-tulc
#'   \item usbr-tulc2
#'   \item usbr-ger
#'   \item usbr-mal
#'   \item usbr-lrs
#'   \item usbr-clk
#'   }
#' @format A tibble with 10 rows and 7 columns:
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

#' @name wet_surface_water
#' @title Monthly surface water extent estimates for wildlife refuges and lakes in the Klamath Basin
#' @description Monthly estimates of open water extent derived from the Intermountain West
#' Wetland Extent Tool (WET) raster dataset, summarized within bounding boxes for six wildlife
#' refuges and five lakes/reservoirs in the Klamath Basin. The WET SurfaceWater product
#' represents the probability or presence of open surface water for each pixel. Two temporal
#' resolutions are available: decadal composites (10-year mean) covering 2005–2014 and
#' 2015–2022, and individual monthly images from 2022 onward. Source rasters are distributed by
#' the Intermountain West Joint Venture (IWJV).
#'
#' Bounding boxes are derived from two authoritative \code{rivermile} boundary layers —
#' \code{rivermile::klamath_refuges} (refuges) and \code{rivermile::klamath_lakes} (lakes) —
#' each buffered by 0.5 miles and reduced to a bounding box before cropping the source rasters.
#' A refuge and its "same" lake are not the same polygon (e.g. the \code{tule_lake_refuge}
#' boundary and the \code{tule_lake} lake boundary cover different areas), so both appear
#' as separate rows rather than being merged. See
#' \code{data-raw/data-exploration/wet-data-exploration.Rmd} for exploratory analysis and
#' \code{data-raw/processing-scripts/wet-process-data.R} for processing details, including the
#' buffer distance and the refuge/lake lookups.
#'
#' \strong{Note on \code{bear_valley_refuge}}: all rows for this refuge are \code{NA}/zero-pixel
#' by design, not a processing bug. Visual QC (raster vs. refuge boundary overlay, checked
#' across multiple products/eras) confirmed the source WET rasters have no detected water
#' anywhere inside the actual Bear Valley NWR boundary — it is a small, mostly
#' upland/forested refuge, below this product's mapping resolution/threshold. An earlier
#' version of this dataset used a hand-drawn bounding box that happened to clip the edge of an
#' unrelated stream feature just northeast of the refuge, producing a handful of nonzero pixels
#' that were never actually inside the refuge; the current \code{rivermile}-derived bbox is
#' tighter and excludes that spillover.
#'
#' @format A tibble with columns:
#' \itemize{
#'   \item \code{name}: area id, built in \code{data-raw/processing-scripts/wet-process-data.R}.
#'     Refuges (\code{boundary_type == "refuge"}): always suffixed \code{_refuge} — one of
#'     \code{upper_klamath_lake_refuge}, \code{clear_lake_refuge}, \code{tule_lake_refuge},
#'     \code{bear_valley_refuge}, \code{lower_klamath_sheepy_refuge}, or
#'     \code{klamath_marsh_refuge} (see note above on \code{bear_valley_refuge}). Lakes
#'     (\code{boundary_type == "lake"}): never suffixed — one of \code{upper_klamath_lake},
#'     \code{clear_lake_reservoir}, \code{tule_lake}, \code{gerber_reservoir}, or
#'     \code{lower_klamath_lake}. The \code{_refuge} suffix means a refuge id can never
#'     collide with a lake id even where they cover roughly the same feature (e.g.
#'     \code{tule_lake_refuge} vs. \code{tule_lake})
#'   \item \code{boundary_type}: \code{"refuge"} or \code{"lake"} — which \code{rivermile}
#'     boundary layer this row's bbox came from
#'   \item \code{type}: product type; always \code{"SurfaceWater"} in this dataset
#'   \item \code{era_str}: era label as a character string (e.g., \code{"2005-2014"} for a
#'     decadal composite or \code{"2022"} for an individual year)
#'   \item \code{is_decadal}: logical; \code{TRUE} if the row represents a 10-year mean composite
#'   \item \code{era_start}: integer start year of the era
#'   \item \code{month_chr}: three-letter month abbreviation (e.g., \code{"JAN"})
#'   \item \code{month_num}: integer month number (1–12)
#'   \item \code{mean_val}: mean surface water raster value across all pixels within the area's
#'     bbox (buffered 0.5 miles) — a continuous water-probability/fraction signal, roughly
#'     between 0 and 1; this is the column to use for tracking extent/intensity
#'   \item \code{median_val}: median surface water raster value within the area's bbox
#'   \item \code{sd_val}: standard deviation of raster values within the area's bbox
#'   \item \code{n_pixels}: number of non-NA pixels within the area's bbox
#' }
#' @source Intermountain West Joint Venture (IWJV) WET dataset \url{https://iwjv.org};
#' refuge boundaries from \code{rivermile::klamath_refuges}; lake boundaries from
#' \code{rivermile::klamath_lakes}
"wet_surface_water"

#' @name wet_hydroperiod
#' @title Monthly hydroperiod estimates for wildlife refuges and lakes in the Klamath Basin
#' @description Monthly estimates of hydroperiod duration derived from the Intermountain West
#' Wetland Extent Tool (WET) raster dataset, summarized within bounding boxes for six wildlife
#' refuges and five lakes/reservoirs in the Klamath Basin. The WET Hydroperiod product
#' represents the duration or persistence of water at each pixel — higher values indicate longer
#' hydroperiod duration. Data are available as decadal composites (10-year mean) covering four
#' eras from 1984 to 2022. Source rasters are distributed by the Intermountain West Joint
#' Venture (IWJV).
#'
#' Bounding boxes are derived from two authoritative \code{rivermile} boundary layers —
#' \code{rivermile::klamath_refuges} (refuges) and \code{rivermile::klamath_lakes} (lakes) —
#' each buffered by 0.5 miles and reduced to a bounding box before cropping the source rasters.
#' A refuge and its "same" lake are not the same polygon (e.g. the \code{tule_lake_refuge}
#' boundary and the \code{tule_lake} lake boundary cover different areas), so both appear
#' as separate rows rather than being merged. See
#' \code{data-raw/data-exploration/wet-data-exploration.Rmd} for exploratory analysis and
#' \code{data-raw/processing-scripts/wet-process-data.R} for processing details, including the
#' buffer distance and the refuge/lake lookups.
#'
#' \strong{Note on \code{bear_valley_refuge}}: all rows for this refuge are \code{NA}/zero-pixel
#' by design, not a processing bug. Visual QC (raster vs. refuge boundary overlay, checked
#' across multiple products/eras) confirmed the source WET rasters have no detected water
#' anywhere inside the actual Bear Valley NWR boundary — it is a small, mostly
#' upland/forested refuge, below this product's mapping resolution/threshold. An earlier
#' version of this dataset used a hand-drawn bounding box that happened to clip the edge of an
#' unrelated stream feature just northeast of the refuge, producing a handful of nonzero pixels
#' that were never actually inside the refuge; the current \code{rivermile}-derived bbox is
#' tighter and excludes that spillover.
#'
#' @format A tibble with columns:
#' \itemize{
#'   \item \code{name}: area id, built in \code{data-raw/processing-scripts/wet-process-data.R}.
#'     Refuges (\code{boundary_type == "refuge"}): always suffixed \code{_refuge} — one of
#'     \code{upper_klamath_lake_refuge}, \code{clear_lake_refuge}, \code{tule_lake_refuge},
#'     \code{bear_valley_refuge}, \code{lower_klamath_sheepy_refuge}, or
#'     \code{klamath_marsh_refuge} (see note above on \code{bear_valley_refuge}). Lakes
#'     (\code{boundary_type == "lake"}): never suffixed — one of \code{upper_klamath_lake},
#'     \code{clear_lake_reservoir}, \code{tule_lake}, \code{gerber_reservoir}, or
#'     \code{lower_klamath_lake}
#'   \item \code{boundary_type}: \code{"refuge"} or \code{"lake"} — which \code{rivermile}
#'     boundary layer this row's bbox came from
#'   \item \code{type}: product type; always \code{"Hydroperiod"} in this dataset
#'   \item \code{era_str}: decadal era label (e.g., \code{"1984-1994"}, \code{"1995-2004"},
#'     \code{"2005-2014"}, \code{"2015-2022"})
#'   \item \code{is_decadal}: logical; always \code{TRUE} — hydroperiod data are decadal composites only
#'   \item \code{era_start}: integer start year of the decadal era
#'   \item \code{month_chr}: three-letter month abbreviation (e.g., \code{"JAN"})
#'   \item \code{month_num}: integer month number (1–12)
#'   \item \code{mean_val}: mean hydroperiod raster value across all pixels within the area's
#'     bbox (buffered 0.5 miles); higher values indicate longer water persistence — this is the
#'     column to use for comparing hydroperiod duration
#'   \item \code{median_val}: median hydroperiod raster value within the area's bbox
#'   \item \code{sd_val}: standard deviation of raster values within the area's bbox
#'   \item \code{n_pixels}: number of non-NA pixels within the area's bbox
#' }
#' @source Intermountain West Joint Venture (IWJV) WET dataset \url{https://iwjv.org};
#' refuge boundaries from \code{rivermile::klamath_refuges}; lake boundaries from
#' \code{rivermile::klamath_lakes}
"wet_hydroperiod"

#' @name teacup_diagram_data
#' @title Elevation, storage, and flow data from the USBR Klamath "Teacup" diagram
#' @description Daily elevation, reservoir storage, and streamflow data for the monitoring
#' stations embedded in the USBR "Major Storage Reservoirs in the Klamath River Basin" teacup
#' diagram. Combines three sources: USBR Hydromet stations (retrieved from the webarccsv archive
#' API), USGS NWIS gauges (retrieved via \code{dataRetrieval::readNWISdv}), and two Sprague River
#' stations published only by the Oregon Water Resources Department (retrieved via
#' \code{whychusModel::get_owrd_hydro()}) — SF Sprague River nr Bly (OWRD station 11495600) and
#' NF Sprague River above SRIC Canal nr Bly (OWRD station 11495900) — neither of which has a
#' usable USGS NWIS record. See \code{data-raw/data-pull/teacup-diagram-data-pull.R} for the full
#' pull, including the station/parameter lookup tables for each source.
#' @format A tibble with columns:
#' \itemize{
#'   \item \code{source}: data provider, one of \code{"USBR Hydromet"}, \code{"USGS NWIS"}, or \code{"OWRD"}
#'   \item \code{site}: station identifier — USBR cbtt code (e.g., "GER", "CLK"), USGS site number (e.g., "11507001"), or OWRD station number (e.g., "11495600")
#'   \item \code{label}: descriptive label combining station location and parameter (e.g., "Gerber Reservoir - Forebay Elevation (ft)")
#'   \item \code{measure_type}: measurement category, one of \code{"elevation"}, \code{"storage"}, or \code{"flow"}
#'   \item \code{lat}: latitude of the station in decimal degrees (USBR sites from the USBR RISE API; USGS sites from \code{dataRetrieval::readNWISsite}; OWRD sites from the OWRD near-real-time station page)
#'   \item \code{long}: longitude of the station in decimal degrees
#'   \item \code{date}: date of observation (Date)
#'   \item \code{value}: observed numeric value (units vary by \code{measure_type}: ft for Elevation, acre-ft for Storage, cfs for Flow)
#' }
#' @source USBR PN Hydromet \url{https://www.usbr.gov/pn/hydromet/klamath/teacup.html}, USGS NWIS \url{https://waterservices.usgs.gov/}, Oregon Water Resources Department \url{https://apps.wrd.state.or.us/apps/sw/hydro_near_real_time/}
"teacup_diagram_data"

#' @name refuge_elevation_wetland
#' @title Monthly water-surface elevation crosswalked to WET wetland/lake extent, by area
#' @description Combines the water-surface-elevation record for each Klamath refuge or lake's
#' assigned station (from \code{teacup_diagram_data}) with that area's WET monthly surface water
#' extent (\code{wet_surface_water}). One row per area-month, at whichever temporal resolution
#' \code{wet_surface_water} provides: decadal climatological months (\code{is_decadal == TRUE})
#' or actual year-months from 2022 onward (\code{is_decadal == FALSE}).
#'
#' The area/station crosswalk is a hand-curated lookup, not an automated nearest-neighbor match
#' — only stations that are genuinely on-site or the obvious controlling structure for an area
#' are assigned to it. Seven areas have a station assigned and therefore appear here:
#' \code{clear_lake_refuge} and \code{clear_lake_reservoir} (\code{CLK}); \code{tule_lake_refuge}
#' and \code{tule_lake} (\code{TULC} and \code{TULC2}, averaged); \code{upper_klamath_lake_refuge}
#' and \code{upper_klamath_lake} (\code{11507001}); and \code{gerber_reservoir} (\code{GER},
#' which has no matching refuge boundary). Bear Valley, Klamath Marsh, and Lower Klamath/Sheepy
#' refuges, plus Lower Klamath Lake, are excluded rather than matched to a distant proxy station
#' — see \code{data-raw/data-exploration/refuge-elevation-wetland-crosswalk.Rmd} (Section 3) for
#' the full crosswalk and why each excluded area is left out.
#' @format A tibble with columns:
#' \itemize{
#'   \item \code{name}: area id — same ids as \code{wet_surface_water$name}. One of
#'     \code{clear_lake_refuge}, \code{clear_lake_reservoir}, \code{tule_lake_refuge},
#'     \code{tule_lake}, \code{upper_klamath_lake_refuge}, \code{upper_klamath_lake}, or
#'     \code{gerber_reservoir}
#'   \item \code{boundary_type}: \code{"refuge"} or \code{"lake"} — which \code{rivermile}
#'     boundary layer this area's bbox came from (see \code{wet_surface_water})
#'   \item \code{is_decadal}: logical; \code{TRUE} for a 10-year decadal climatological month, \code{FALSE} for an actual year-month
#'   \item \code{era_str}: era label (e.g. \code{"2005-2014"} for decadal rows, or the year as a string for annual rows)
#'   \item \code{month_num}: integer month number (1-12)
#'   \item \code{month_chr}: three-letter month abbreviation (e.g. \code{"jan"})
#'   \item \code{elevation_mean_ft}: mean water surface elevation (ft) across the assigned station(s), over the aggregation window
#'   \item \code{elevation_min_ft}: minimum daily elevation (ft) observed within the aggregation window
#'   \item \code{elevation_max_ft}: maximum daily elevation (ft) observed within the aggregation window
#'   \item \code{wet_mean_val}: mean WET surface water raster value within the area's bbox (see
#'     \code{wet_surface_water}) — the continuous water-probability/fraction signal; use this
#'     column for tracking wetland extent/intensity
#'   \item \code{wet_median_val}: median WET surface water raster value within the area's bbox
#'   \item \code{wet_sd_val}: standard deviation of WET surface water raster values within the area's bbox
#'   \item \code{wet_n_pixels}: number of non-NA WET pixels within the area's bbox
#' }
#' @source USBR PN Hydromet / USGS NWIS elevations (\code{teacup_diagram_data});
#' Intermountain West Joint Venture (IWJV) WET dataset (\code{wet_surface_water})
"refuge_elevation_wetland"

