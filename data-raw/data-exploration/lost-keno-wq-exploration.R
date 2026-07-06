# =============================================================================
# Gage Discovery — Water Quality Gages — Lost River & Keno Reach (Lake Ewauna to Keno Dam)
# =============================================================================
# 1. Finds ALL gages (USGS + WQP) within two bounding boxes with
#    Temperature, pH, and/or DO data from 2014 onwards
# 2. Maps gage locations
# 3. Builds a reference table (site, parameters, date range)
# 4. Compares against klamathWaterData objects and flags missing gages
# =============================================================================

library(dataRetrieval)
library(dplyr)
library(tidyr)
library(stringr)
library(leaflet)
library(htmltools)
library(knitr)
library(janitor)

# =============================================================================
# INPUTS
# =============================================================================

boxes <- list(
  "Lost River" = c(-121.701762, 41.929380, -121.052246, 42.210610),
  "Keno Reach" = c(-121.883019, 42.078811, -121.763552, 42.235661)
)

wq_chars    <- c("Temperature, water", "pH", "Dissolved oxygen (DO)")
usgs_pcodes <- c("00010", "00400", "00300")
pcode_label <- c("00010" = "Temperature, water",
                 "00400" = "pH",
                 "00300" = "Dissolved oxygen (DO)")

cutoff_year <- 2014

# =============================================================================
# HELPER
# =============================================================================

# Cast all columns to character before binding to avoid type conflicts
safe_bind <- function(lst) {
  bind_rows(lapply(Filter(Negate(is.null), lst),
                   function(df) mutate(df, across(everything(), as.character))))
}

# =============================================================================
# 1. DISCOVER GAGES
# =============================================================================

# ── 1a. USGS ─────────────────────────────────────────────────────────────────
cat("=== STEP 1: Discovering gages ===\n\n")
cat("Querying USGS NWIS...\n")

usgs_sites_list <- lapply(names(boxes), function(reach) {
  tryCatch({
    df <- whatNWISsites(
      bBox          = boxes[[reach]],
      parameterCd   = usgs_pcodes,
      hasDataTypeCd = "uv"
    )
    if (!is.null(df) && nrow(df) > 0) df$Reach <- reach
    df
  }, error = function(e) {
    cat("  Warning (USGS,", reach, "):", conditionMessage(e), "\n"); NULL
  })
})
usgs_sites_raw <- safe_bind(usgs_sites_list)

# Parameter inventory — what each site actually has and when
usgs_inv <- tryCatch(
  whatNWISdata(
    siteNumber = unique(usgs_sites_raw$site_no),
    service    = c("uv", "dv")
  ),
  error = function(e) { cat("  Warning (whatNWISdata):", conditionMessage(e), "\n"); NULL }
)

usgs_params <- usgs_inv |>
  filter(
    parm_cd %in% usgs_pcodes,
    !is.na(end_date),
    as.integer(substr(end_date, 1, 4)) >= cutoff_year
  ) |>
  transmute(
    SiteID        = site_no,
    Parameter     = pcode_label[parm_cd],
    Start         = as.Date(begin_date),
    End           = as.Date(end_date),
    Data_Type     = case_when(
      data_type_cd == "uv" ~ "Continuous",
      data_type_cd == "dv" ~ "Daily",
      TRUE                 ~ data_type_cd
    )
  )

# One row per site summarising all parameters
usgs_summary <- usgs_params |>
  group_by(SiteID) |>
  summarise(
    Parameters = paste(sort(unique(Parameter)), collapse = "; "),
    Start_Date = min(Start, na.rm = TRUE),
    End_Date   = max(End,   na.rm = TRUE),
    Data_Type  = paste(sort(unique(Data_Type)), collapse = "; "),
    .groups = "drop"
  ) |>
  filter(year(End_Date) >= cutoff_year)

usgs_gages <- usgs_sites_raw |>
  filter(site_no %in% usgs_summary$SiteID) |>
  transmute(
    Reach    = Reach,
    Source   = "USGS NWIS",
    SiteID   = site_no,
    SiteName = station_nm,
    Agency   = "U.S. Geological Survey",
    Lat      = as.numeric(dec_lat_va),
    Lon      = as.numeric(dec_long_va)
  ) |>
  distinct(SiteID, .keep_all = TRUE) |>
  left_join(usgs_summary, by = "SiteID") |>
  filter(!is.na(Lat), !is.na(Lon))

cat("  USGS: found", nrow(usgs_gages), "gages with Temp/pH/DO from", cutoff_year, "onwards\n\n")

# ── 1b. WQP (non-USGS) ────────────────────────────────────────────────────────
cat("Querying Water Quality Portal (WQP)...\n")

# Pull sites
wqp_sites_list <- lapply(names(boxes), function(reach) {
  tryCatch({
    df <- whatWQPsites(bBox = boxes[[reach]], characteristicName = wq_chars)
    if (!is.null(df) && nrow(df) > 0) {
      df <- mutate(df, across(everything(), as.character))
      df$Reach <- reach
    }
    df
  }, error = function(e) {
    cat("  Warning (WQP sites,", reach, "):", conditionMessage(e), "\n"); NULL
  })
})
wqp_sites_raw <- safe_bind(wqp_sites_list) |>
  filter(!grepl("^USGS", OrganizationIdentifier, ignore.case = TRUE)) |>
  distinct(MonitoringLocationIdentifier, .keep_all = TRUE)

# Per-parameter result counts and year range (one call per characteristic)
cat("  Verifying WQP data availability (one call per parameter)...\n")

wqp_detail_list <- list()
for (reach in names(boxes)) {
  for (chr in wq_chars) {
    key <- paste(reach, chr)
    df <- tryCatch(
      whatWQPdata(bBox = boxes[[reach]], characteristicName = chr),
      error = function(e) NULL
    )
    if (!is.null(df) && nrow(df) > 0) {
      df <- mutate(df, across(everything(), as.character),
                   Parameter = chr, Reach = reach)
      wqp_detail_list[[key]] <- df
    }
  }
}
wqp_detail_raw <- safe_bind(wqp_detail_list) |>
  mutate(resultCount = as.numeric(resultCount)) |>
  filter(!is.na(resultCount), resultCount > 0)

# Year range per site x parameter via readWQPsummary
cat("  Fetching WQP year-level date ranges (readWQPsummary)...\n")

wqp_yr_list <- list()
for (reach in names(boxes)) {
  for (chr in wq_chars) {
    key <- paste(reach, chr)
    df <- tryCatch(
      readWQPsummary(bBox = boxes[[reach]], characteristicName = chr),
      error = function(e) NULL
    )
    if (!is.null(df) && nrow(df) > 0) {
      df <- mutate(df, across(everything(), as.character), Parameter = chr)
      wqp_yr_list[[key]] <- df
    }
  }
}
wqp_yr_raw <- safe_bind(wqp_yr_list) |>
  mutate(YearSummarized = as.integer(YearSummarized)) |>
  filter(!is.na(YearSummarized), YearSummarized >= cutoff_year)

# Sites confirmed to have data from cutoff_year onwards
wqp_yr_summary <- wqp_yr_raw |>
  group_by(MonitoringLocationIdentifier, Parameter) |>
  summarise(
    Start_Year = min(YearSummarized, na.rm = TRUE),
    End_Year   = max(YearSummarized, na.rm = TRUE),
    .groups = "drop"
  ) |>
  filter(End_Year >= cutoff_year)

confirmed_wqp_ids <- unique(wqp_yr_summary$MonitoringLocationIdentifier)

# Build WQP per-site summary
wqp_param_summary <- wqp_yr_summary |>
  group_by(MonitoringLocationIdentifier) |>
  summarise(
    Parameters = paste(sort(unique(Parameter)), collapse = "; "),
    Start_Date = as.Date(paste0(min(Start_Year), "-01-01")),
    End_Date   = as.Date(paste0(max(End_Year),   "-12-31")),
    Data_Type  = "Discrete samples",
    .groups = "drop"
  )

wqp_gages <- wqp_sites_raw |>
  filter(MonitoringLocationIdentifier %in% confirmed_wqp_ids) |>
  transmute(
    Reach    = Reach,
    Source   = "WQP",
    SiteID   = MonitoringLocationIdentifier,
    SiteName = MonitoringLocationName,
    Agency   = OrganizationFormalName,
    Lat      = as.numeric(LatitudeMeasure),
    Lon      = as.numeric(LongitudeMeasure)
  ) |>
  distinct(SiteID, .keep_all = TRUE) |>
  left_join(wqp_param_summary, by = c("SiteID" = "MonitoringLocationIdentifier")) |>
  filter(!is.na(Lat), !is.na(Lon), !is.na(Parameters))

cat("  WQP: found", nrow(wqp_gages), "non-USGS gages with Temp/pH/DO from",
    cutoff_year, "onwards\n\n")

# ── 1c. Combine ───────────────────────────────────────────────────────────────
all_gages <- bind_rows(usgs_gages, wqp_gages) |>
  arrange(Reach, Source, SiteID)

cat("  TOTAL:", nrow(all_gages), "gages across both reaches and both sources\n\n")

# =============================================================================
# 2. MAP
# =============================================================================
cat("=== STEP 2: Building map ===\n")

reach_pal <- colorFactor(
  palette = c("Lost River" = "#1b9e77", "Keno Reach" = "#7570b3"),
  domain  = all_gages$Reach
)

all_gages <- all_gages |>
  mutate(
    radius     = if_else(Source == "USGS NWIS", 9, 6),
    popup_text = paste0(
      "<b>", htmlEscape(SiteName), "</b><br>",
      "<b>Site ID:</b> ",    htmlEscape(SiteID), "<br>",
      "<b>Reach:</b> ",      htmlEscape(Reach), "<br>",
      "<b>Source:</b> ",     htmlEscape(Source), "<br>",
      "<b>Agency:</b> ",     htmlEscape(Agency), "<br>",
      "<b>Parameters:</b> ", htmlEscape(Parameters), "<br>",
      "<b>Period:</b> ",     as.character(Start_Date), " to ", as.character(End_Date)
    )
  )

gage_map <- leaflet(all_gages) |>
  addProviderTiles(providers$Esri.WorldTopoMap) |>
  addCircleMarkers(
    lng         = ~Lon,
    lat         = ~Lat,
    radius      = ~radius,
    fillColor   = ~reach_pal(Reach),
    color       = "#333333",
    weight      = 1,
    fillOpacity = 0.9,
    popup       = ~popup_text,
    label       = ~paste0(SiteID, " | ", Source, " | ", Parameters)
  ) |>
  addLegend(
    position = "bottomright",
    pal      = reach_pal,
    values   = ~Reach,
    title    = "Reach"
  ) |>
  addControl(
    html = "<div style='background:white;padding:8px 12px;border-radius:5px;font-size:12px'>
              <b>All gages: Temp / pH / DO</b><br>
              ● Large = USGS NWIS &nbsp; ● Small = WQP<br>
              Data from 2014 onwards only<br>
              Click marker for details
            </div>",
    position = "topleft"
  )

print(gage_map)
cat("  Map created (object: gage_map)\n\n")

# =============================================================================
# 4. COMPARE AGAINST klamathWaterData
# =============================================================================
cat("=== STEP 4: Comparing against klamathWaterData ===\n\n")

# ── Load klamathWaterData objects ─────────────────────────────────────────────
kwd <- list(
  temperature = klamathWaterData::temperature_gage,
  pH          = klamathWaterData::ph_gage,
  DO          = klamathWaterData::do_gage
)

# ── Extract IDs — full form AND prefix-stripped, to handle format mismatches ──
# e.g. "USGS-11509500"       -> also stores "11509500"
#      "HVTEPA_WQX-TR_SB"   -> also stores "TR_SB"
#      "11509500"            -> already bare, stored as-is
get_ids <- function(df) {
  id_col <- names(df)[str_detect(names(df), regex("gage_id", ignore_case = TRUE))][1]
  if (is.na(id_col)) return(character(0))
  ids     <- unique(as.character(df[[id_col]]))
  ids     <- ids[!is.na(ids) & ids != ""]
  stripped <- str_remove(ids, "^[A-Za-z0-9_]+-")   # strip any org prefix
  unique(c(ids, stripped))
}

kwd_ids <- lapply(kwd, get_ids)

# Diagnostic — confirm IDs are found for each object
cat("── klamathWaterData ID counts ────────────────────────────────────────────\n")
for (nm in names(kwd_ids)) {
  cat(sprintf("  %-15s : %d IDs  (sample: %s)\n",
              nm,
              length(kwd_ids[[nm]]),
              paste(head(kwd_ids[[nm]], 3), collapse = ", ")))
}
cat("\n")

# ── Parameter -> kwd object mapping ──────────────────────────────────────────
param_to_kwd <- c(
  "Temperature, water"    = "temperature",
  "pH"                    = "pH",
  "Dissolved oxygen (DO)" = "DO"
)

# ── Long table: one row per gage x parameter ──────────────────────────────────
gage_params_long <- all_gages |>
  select(Reach, Source, SiteID, SiteName, Agency,
         Parameters, Start_Date, End_Date, Lat, Lon) |>
  mutate(param_list = str_split(Parameters, "; ")) |>
  unnest(param_list) |>
  rename(Parameter = param_list) |>
  filter(Parameter %in% names(param_to_kwd)) |>
  mutate(
    kwd_object  = param_to_kwd[Parameter],
    # Strip any org prefix from SiteID for matching
    SiteID_bare = str_remove(SiteID, "^[A-Za-z0-9_]+-"),
    in_kwd = mapply(function(sid, bare, obj) {
      ids <- kwd_ids[[obj]]
      sid %in% ids | bare %in% ids
    }, SiteID, SiteID_bare, kwd_object)
  )

# ── Wide table: one row per gage, in_kwd TRUE/FALSE per parameter ─────────────
kwd_check <- gage_params_long |>
  select(Reach, Source, SiteID, SiteName, Agency,
         Parameters, Start_Date, End_Date,
         Parameter, in_kwd, Lat, Lon) |>
  pivot_wider(
    names_from  = Parameter,
    values_from = in_kwd,
    names_prefix = "in_kwd_"
  ) |>
  rename_with(~ str_replace_all(., "[^A-Za-z0-9_]", "_"), starts_with("in_kwd_")) |>
  # NA means gage doesn't collect that parameter — not a failed match, treat as FALSE
  mutate(across(starts_with("in_kwd_"), ~ replace_na(., FALSE))) |>
  mutate(
    n_params_collected = str_count(Parameters, ";") + 1,
    n_params_in_kwd    = rowSums(across(starts_with("in_kwd_")), na.rm = TRUE),
    in_all_kwd         = n_params_in_kwd == n_params_collected,
    in_any_kwd         = n_params_in_kwd > 0,
    status = case_when(
      in_all_kwd             ~ "Complete — all params in klamathWaterData",
      in_any_kwd & !in_all_kwd ~ "Partial — some params missing",
      !in_any_kwd            ~ "Fully missing from klamathWaterData"
    )
  )

# ── Missing by parameter: one row per gage x missing parameter ────────────────
missing_by_param <- gage_params_long |>
  filter(!in_kwd) |>
  select(Reach, Source, SiteID, SiteName, Agency,
         Parameter, kwd_object,
         Start_Date, End_Date, Lat, Lon) |>
  arrange(Reach, Source, SiteID, Parameter)

# ── Missing wide: one row per gage showing which params are missing ───────────
missing_wide <- gage_params_long |>
  select(Reach, Source, SiteID, SiteName, Agency,
         Parameters, Start_Date, End_Date,
         Parameter, in_kwd, Lat, Lon) |>
  mutate(missing = !in_kwd) |>
  pivot_wider(
    names_from  = Parameter,
    values_from = missing,
    names_prefix = "missing_"
  ) |>
  rename_with(~ str_replace_all(., "[^A-Za-z0-9_]", "_"),
              starts_with("missing_")) |>
  # NA = parameter not collected at this site = not missing, replace with FALSE
  mutate(across(starts_with("missing_"), ~ replace_na(., FALSE))) |>
  mutate(
    missing_any = rowSums(across(starts_with("missing_")), na.rm = TRUE) > 0
  ) |>
  filter(missing_any) |>
  arrange(Reach, Source, SiteID)

# ── Print summary ─────────────────────────────────────────────────────────────
cat("── Summary ───────────────────────────────────────────────────────────────\n")
cat("  Total gages found                    :", nrow(all_gages), "\n")
cat("  Complete (all params in kwd)         :", sum(kwd_check$in_all_kwd,  na.rm = TRUE), "\n")
cat("  Partial  (some params missing)       :", sum(kwd_check$in_any_kwd & !kwd_check$in_all_kwd, na.rm = TRUE), "\n")
cat("  Fully missing (not in any kwd obj)   :", sum(!kwd_check$in_any_kwd, na.rm = TRUE), "\n\n")

cat("── Gages with at least one parameter missing from klamathWaterData ───────\n")
print(kable(
  missing_wide |>  select(-Lat, -Lon),
  format = "simple"
))

cat("\n── Detail: which gage x parameter is missing ─────────────────────────────\n")
print(kable(
  missing_by_param |>  select(-Lat, -Lon),
  format = "simple"
))

# ── Map: missing gages ────────────────────────────────────────────────────────
if (nrow(missing_wide) > 0) {

  status_pal <- colorFactor(
    palette = c("Partial — some params missing"          = "#fc8d59",
                "Fully missing from klamathWaterData"     = "#d73027"),
    domain = c("Partial — some params missing",
               "Fully missing from klamathWaterData")
  )

  # Add status back for map coloring
  missing_map_df <- missing_wide |>
    left_join(kwd_check |>  select(SiteID, status), by = "SiteID")

  missing_map <- leaflet(missing_map_df) |>
    addProviderTiles(providers$Esri.WorldTopoMap) |>
    addCircleMarkers(
      lng         = ~Lon,
      lat         = ~Lat,
      radius      = 8,
      fillColor   = ~status_pal(status),
      color       = "#333333",
      weight      = 1,
      fillOpacity = 0.9,
      popup       = ~paste0(
        "<b>", htmlEscape(SiteName), "</b><br>",
        "<b>Site ID:</b> ",    htmlEscape(SiteID), "<br>",
        "<b>Reach:</b> ",      htmlEscape(Reach), "<br>",
        "<b>Source:</b> ",     htmlEscape(Source), "<br>",
        "<b>Agency:</b> ",     htmlEscape(Agency), "<br>",
        "<b>Parameters:</b> ", htmlEscape(Parameters), "<br>",
        "<b>Period:</b> ",     as.character(Start_Date), " to ", as.character(End_Date), "<br>",
        "<b>Status:</b> ",     htmlEscape(status)
      ),
      label = ~paste0(SiteID, " | ", status)
    ) |>
    addLegend(
      position = "bottomright",
      pal      = status_pal,
      values   = ~status,
      title    = "klamathWaterData status"
    ) |>
    addControl(
      html = "<div style='background:white;padding:8px 12px;border-radius:5px;font-size:12px'>
                <b>Gages with missing parameters</b><br>
                Orange = partially missing<br>
                Red    = fully missing<br>
                Click marker for details
              </div>",
      position = "topleft"
    )

  print(missing_map)
}

# ── Save outputs ──────────────────────────────────────────────────────────────
# file_path <- "C:/Users/YourName/Documents/my_folder/output_file.csv"
#
# # 3. Save the data frame to the folder
# write.csv(my_data, file = file_path, row.names = FALSE)


missing_temp <- missing_wide |>
  clean_names() |>
  filter(missing_temperature_water == TRUE) |>
  select(reach, source, site_id, site_name, agency, parameters, start_date, end_date, lat, lon) |>
  glimpse()

#  no missing ph gages
# missing_ph <- missing_wide |>
#   clean_names() |>
#   filter(missing_p_h == TRUE) |>
#   select(reach, source, site_id, site_name, agency, parameters, start_date, end_date, lat, lon) |>
#   glimpse()

missing_do <- missing_wide |>
  clean_names() |>
  filter(missing_dissolved_oxygen_do == TRUE) |>
  select(reach, source, site_id, site_name, agency, parameters, start_date, end_date, lat, lon) |>
  glimpse()

