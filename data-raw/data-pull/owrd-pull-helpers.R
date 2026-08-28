library(httr)
library(xml2)
library(dplyr)
library(tibble)

# ------------------------------------------------------------
# Live lat/long lookup for OWRD "near real time" gaging stations, via
# OWRD's own KML station feed, so coordinates don't have to be
# hand-transcribed. Shared by flow-data-pull.R and
# temperature-process-data.R.
# ------------------------------------------------------------
fetch_owrd_coord <- function(station_nbr) {
  url <- paste0(
    "https://apps.wrd.state.or.us/apps/sw/hydro_near_real_time/near_real_time_gage_station_kml.aspx",
    "?sn_start=", station_nbr
  )
  kml <- xml2::read_xml(content(GET(url), as = "text", encoding = "UTF-8"))
  for (pm in xml2::xml_find_all(kml, ".//Placemark")) {
    desc <- xml2::xml_text(xml2::xml_find_first(pm, ".//description"))
    if (grepl(paste0("Station Number: ", station_nbr, "<br>"), desc, fixed = TRUE)) {
      coords <- strsplit(trimws(xml2::xml_text(xml2::xml_find_first(pm, ".//coordinates"))), ",")[[1]]
      return(tibble(site = station_nbr, long = as.numeric(coords[1]), lat = as.numeric(coords[2])))
    }
  }
  tibble(site = station_nbr, long = NA_real_, lat = NA_real_)
}
