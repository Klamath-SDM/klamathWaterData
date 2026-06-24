library(tidyverse)
library(httr)
library(lubridate)
library(scales)
library(patchwork)

# ============================================================
# USBR Klamath Basin Hydromet — Bulk Daily Data Pull
# Source: https://www.usbr.gov/pn/hydromet/klamath/arcread.html
# API:    https://www.usbr.gov/pn-bin/webarccsv.pl
# ============================================================

STATIONS <- tribble(
  ~site,   ~parameter, ~label,
  "LRS",   "FD",       "Clear Lake East Lobe - Daily Avg Forebay Elevation (ft)",
  "LRS",   "QD",       "Clear Lake East Lobe - Discharge (cfs)",
  "CLK",   "FD",       "Clear Lake West Lobe - Daily Avg Forebay Elevation (ft)",
  "CLK",   "FB",       "Clear Lake West Lobe - Midnight Forebay Elevation (ft)",
  "LRSC",  "GD",       "Lost River below Clear Lake Dam - Stage (ft)",
  "KELO",  "GD",       "Lost River at Keller Bridge - Stage (ft)",
  "HRPO",  "GD",       "Lost River at Harpold Dam - Stage (ft)",
  "HRPO",  "QD",       "Lost River at Harpold Dam - Flow (cfs)",
  "LRD",   "QD",       "Lost River Diversion Dam - Flow (cfs)",
  "LRVO",  "QJ",       "Lost River Diversion at Tingley - Flow (cfs)",
  "GER",   "FB",       "Gerber Reservoir - Forebay Elevation (ft)",
  "GER",   "FD",       "Gerber Reservoir - Daily Avg Forebay Elevation (ft)",
  "GER",   "GD",       "Gerber Reservoir - Discharge Stage (ft)",
  "GER",   "QD",       "Gerber Reservoir - Discharge (cfs)",
  "ACHO",  "QJ",       "A Canal Headworks OR - Flow (cfs)",
  "MHPO",  "QP",       "Miller Hill Pump Plant OR - Flow (cfs)",
  "MAL",   "GD",       "Malone Reservoir - Stage (ft)",
  "LVNO",  "QJ",       "Langell Valley North Canal - Flow (cfs)",
  "EEEO",  "GJ",       "Pump Plants E/EE Sump KSD3 - Stage (ft)",
  "EEEO",  "GJ2",      "Pump Plants E/EE Sump KSD4 - Stage (ft)",
  "FPPO",  "GJ",       "Pump Plants F/FF Sump KSD5 - Stage (ft)",
  "FPPO",  "GJ2",      "Pump Plants F/FF Outlet KSD7 - Stage (ft)",
  "STDC",  "GJ",       "Straits Drain at Stateline Rd - GJ (ft)",
  "STDC",  "GJ2",      "Straits Drain at Stateline Rd - GJ2 (ft)"
)

START_DATE <- as.Date("1900-10-01")
END_DATE   <- Sys.Date() - 1
BASE_URL   <- "https://www.usbr.gov/pn-bin/webarccsv.pl"
SLEEP_SEC  <- 1
BATCH_SIZE <- 14
UA <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

# ============================================================
# Parse webarccsv.pl response
# ============================================================

parse_webarccsv <- function(raw_text, station_params, debug = FALSE) {
  lines <- strsplit(raw_text, "\n")[[1]]

  # --- DEBUG: print first 30 lines so you can see the raw format ---
  if (debug) {
    message("\n=== RAW RESPONSE (first 30 lines) ===")
    message(paste(head(lines, 30), collapse = "\n"))
    message("======================================\n")
  }

  begin_idx <- which(grepl("^BEGIN DATA", lines, ignore.case = TRUE))
  if (length(begin_idx) == 0) {
    message("  [parse] No 'BEGIN DATA' marker found")
    if (debug) message("Full response:\n", raw_text)
    return(NULL)
  }

  data_lines <- lines[(begin_idx + 1):length(lines)]
  data_lines <- data_lines[nzchar(trimws(data_lines))]

  if (length(data_lines) < 2) {
    message("  [parse] No data rows after header")
    return(NULL)
  }

  header_line <- data_lines[1]
  data_lines  <- data_lines[-1]

  # Parse header — strip ALL whitespace from each token
  raw_col_names <- strsplit(header_line, ",")[[1]]
  col_names     <- trimws(raw_col_names)

  if (debug) {
    message("=== PARSED COLUMN NAMES ===")
    message(paste(sprintf("  [%d] raw='%s'  clean='%s'",
                          seq_along(col_names), raw_col_names, col_names),
                  collapse = "\n"))
    message("===========================\n")
  }

  # Read as character to avoid any coercion
  df_raw <- tryCatch(
    read.csv(
      text             = paste(data_lines, collapse = "\n"),
      header           = FALSE,
      col.names        = col_names,
      colClasses       = "character",
      stringsAsFactors = FALSE,
      fill             = TRUE,
      strip.white      = TRUE   # strip whitespace from values too
    ),
    error = function(e) {
      message("  [parse] read.csv error: ", conditionMessage(e))
      NULL
    }
  )

  if (is.null(df_raw) || ncol(df_raw) < 2) return(NULL)

  # Parse dates
  date_col     <- col_names[1]
  dates_parsed <- mdy(trimws(df_raw[[date_col]]))

  n_dates <- length(dates_parsed)

  # Build lookup with multiple key variants to handle any spacing oddities:
  #   "GER QD", "GER  QD", "GER.QD" (R converts spaces to dots in col names)
  lookup <- station_params |>
    mutate(
      key_space = paste(site, parameter),          # "GER QD"
      key_dot   = paste(site, parameter, sep = ".") # "GER.QD" (R default)
    )

  # Actual df column names (R may have converted spaces to dots)
  df_col_names <- names(df_raw)

  if (debug) {
    message("=== DATA FRAME COLUMN NAMES (after read.csv) ===")
    message(paste(sprintf("  [%d] '%s'", seq_along(df_col_names), df_col_names),
                  collapse = "\n"))
    message("=================================================\n")
    message("=== FIRST 3 DATA ROWS ===")
    print(head(df_raw, 3))
    message("=========================\n")
  }

  # Match each lookup key to an actual df column (try space then dot then fuzzy)
  find_col <- function(site, param) {
    key_space <- paste(site, param)
    key_dot   <- paste(site, param, sep = ".")
    # Direct match on cleaned col_names
    m <- which(col_names == key_space)
    if (length(m) > 0) return(df_col_names[m[1]])
    # Match on dot-separated (R's default column name behavior)
    m <- which(df_col_names == key_dot)
    if (length(m) > 0) return(df_col_names[m[1]])
    # Case-insensitive
    m <- which(toupper(df_col_names) == toupper(key_dot))
    if (length(m) > 0) return(df_col_names[m[1]])
    # Fuzzy: col contains both site and param
    m <- which(grepl(site, df_col_names, ignore.case = TRUE) &
                 grepl(param, df_col_names, ignore.case = TRUE))
    if (length(m) > 0) return(df_col_names[m[1]])
    return(NA_character_)
  }

  long_list <- lapply(seq_len(nrow(lookup)), function(i) {
    row      <- lookup[i, ]
    col_match <- find_col(row$site, row$parameter)

    if (is.na(col_match)) {
      if (debug) message("  [match] No column found for: ", row$site, " ", row$parameter)
      return(NULL)
    }

    if (debug) message("  [match] ", row$site, " ", row$parameter, " -> '", col_match, "'")

    raw_vals <- df_raw[[col_match]]
    vals     <- suppressWarnings(as.numeric(trimws(raw_vals)))

    if (length(vals) != n_dates) {
      message("  [parse] Length mismatch for ", col_match, " — padding with NA")
      vals <- rep(NA_real_, n_dates)
    }

    data.frame(
      site      = row$site,
      parameter = row$parameter,
      label     = row$label,
      date      = dates_parsed,
      value     = vals,
      stringsAsFactors = FALSE
    )
  })

  long_list <- Filter(Negate(is.null), long_list)
  if (length(long_list) == 0) return(NULL)

  result <- do.call(rbind, long_list)
  result <- result[!is.na(result$date), ]
  as_tibble(result)
}

# ============================================================
# Fetch one batch
# ============================================================

fetch_batch <- function(batch_df, start_date, end_date, debug = FALSE) {
  param_string <- paste(
    paste(batch_df$site, batch_df$parameter),
    collapse = ","
  )

  sites_label <- paste(unique(batch_df$site), collapse = ", ")
  message("Fetching batch: ", sites_label, " [", nrow(batch_df), " params]")

  resp <- tryCatch(
    GET(
      BASE_URL,
      query = list(
        parameter = param_string,
        syer      = year(start_date),
        smnth     = month(start_date),
        sdy       = day(start_date),
        eyer      = year(end_date),
        emnth     = month(end_date),
        edy       = day(end_date),
        format    = "2"
      ),
      add_headers(
        `User-Agent` = UA,
        `Referer`    = "https://www.usbr.gov/pn/hydromet/arcread.html"
      ),
      timeout(120)
    ),
    error = function(e) {
      warning("  HTTP error: ", conditionMessage(e))
      NULL
    }
  )

  Sys.sleep(SLEEP_SEC)

  if (is.null(resp)) return(NULL)

  status <- status_code(resp)
  if (status != 200) {
    warning("  Status ", status, " for batch: ", sites_label)
    return(NULL)
  }

  raw <- content(resp, as = "text", encoding = "UTF-8")
  parse_webarccsv(raw, batch_df, debug = debug)
}

# ============================================================
# Run — first batch with debug=TRUE to inspect format
# ============================================================

batches <- split(STATIONS, ceiling(seq_len(nrow(STATIONS)) / BATCH_SIZE))

# Run first batch with debug on so you can see actual column names
message("\n>>> Running batch 1 with debug output <<<")
batch1_result <- fetch_batch(batches[[1]], START_DATE, END_DATE, debug = TRUE)

# Then run remaining batches normally
message("\n>>> Running remaining batches <<<")
remaining_results <- map_dfr(batches[-1], function(batch) {
  fetch_batch(batch, START_DATE, END_DATE, debug = FALSE)
})

all_data <- bind_rows(batch1_result, remaining_results)

# ============================================================
# Summary & save
# ============================================================

if (nrow(all_data) == 0) {
  stop("No data returned.")
}

message("\n--- Summary ---")
message("Total rows:  ", nrow(all_data))
message("Date range:  ", min(all_data$date, na.rm = TRUE),
        " to ", max(all_data$date, na.rm = TRUE))

print(
  all_data |>
    group_by(site, parameter, label) |>
    summarise(
      n_days       = n(),
      n_nonmissing = sum(!is.na(value)),
      pct_complete = round(100 * mean(!is.na(value)), 1),
      .groups      = "drop"
    )
)

# remove NAs
hydromet_data_filtered <- all_data |>
  filter(!is.na(value))

hydromet_data_filtered |> glimpse()

unique(hydromet_data_filtered$site)
unique(hydromet_data_filtered$parameter)

# ============================================================
# SITE & PARAMETER DEFINITIONS
# Source: USBR PN Hydromet pcode list (decod_params.html)
#         + Klamath index page (klamath/index.html)
# ============================================================

site_defs <- tribble(
  ~site,  ~full_name,                              ~waterbody,                    ~type,
  "LRS",  "Clear Lake East Lobe (Reservoir)",      "Clear Lake, CA/OR",           "Reservoir",
  "CLK",  "Clear Lake West Lobe",                  "Clear Lake, CA/OR",           "Reservoir",
  "LRSC", "Lost River below Clear Lake Dam",       "Lost River, OR",              "Stream gage",
  "KELO", "Lost River at Keller Bridge",           "Lost River, OR",              "Stream gage",
  "HRPO", "Lost River at Harpold Dam",             "Lost River, OR",              "Dam / gage",
  "LRD",  "Lost River Diversion Dam",              "Lost River, OR",              "Diversion dam",
  "LRVO", "Lost River Diversion at Tingley",       "Lost River, OR",              "Diversion",
  "GER",  "Gerber Reservoir",                      "Lost River, OR",              "Reservoir",
  "ACHO", "A Canal Headworks",                     "Klamath Project, OR",         "Canal headworks",
  "MHPO", "Miller Hill Pump Plant",                "Klamath Project, OR",         "Pump plant",
  "MAL",  "Malone Reservoir",                      "Klamath Project, OR",         "Reservoir",
  "LVNO", "Langell Valley North Canal",            "Langell Valley, OR",          "Canal",
  "EEEO", "Pump Plants E and EE sump",             "Klamath Straits Drain, OR",   "Pump plant / drain",
  "FPPO", "Pump Plants F and FF",                  "Klamath Straits Drain, OR",   "Pump plant / drain",
  "STDC", "Straits Drain at Stateline Rd",         "Klamath Straits Drain, OR/CA","Drain gage"
)

param_defs <- tribble(
  ~parameter, ~full_name,                          ~units,  ~description,
  "FB",       "Forebay elevation (instantaneous)", "ft",    "Midnight (instantaneous) water surface elevation in the reservoir forebay, above mean sea level.",
  "FD",       "Forebay elevation (daily average)", "ft",    "Daily average water surface elevation in the reservoir forebay, above mean sea level.",
  "GD",       "Gauge height (daily average)",      "ft",    "Daily average water surface stage at a stream or outlet gauge; convert to discharge via a rating curve.",
  "GJ",       "Gauge height, junction/sump",       "ft",    "Water surface stage at a canal junction, sump, or drain structure. Suffixes (GJ, GJ2) distinguish multiple sensors at the same site.",
  "GJ2",      "Gauge height, junction/sump #2",    "ft",    "Second gauge height sensor at a canal junction or sump (distinguishes two measurement points at the same site).",
  "QD",       "Discharge (daily average)",         "cfs",   "Daily average streamflow or release discharge, in cubic feet per second. Computed from a stage-discharge rating curve or direct measurement.",
  "QJ",       "Canal/diversion discharge",         "cfs",   "Flow diverted into or through a canal or diversion structure, measured directly (not derived from a rating curve).",
  "QP",       "Pumped discharge",                  "cfs",   "Flow delivered by a pump plant, in cubic feet per second. Used at mechanically pumped conveyance structures."
)

# Quick-reference table (print or View())
site_defs
param_defs

# ============================================================
# VISUALIZATION
# A small-multiple time series: one panel per site,
# colored by parameter type (elevation vs. flow)
# Last 5 water years for readability
# ============================================================

# -- Classify parameters into two measurement families
param_type_lut <- tribble(
  ~parameter, ~param_type,
  "FB",       "Elevation (ft)",
  "FD",       "Elevation (ft)",
  "GD",       "Stage (ft)",
  "GJ",       "Stage (ft)",
  "GJ2",      "Stage (ft)",
  "QD",       "Flow (cfs)",
  "QJ",       "Flow (cfs)",
  "QP",       "Flow (cfs)"
)

# -- Join site/param metadata and filter to last 5 WYs
plot_data <- hydromet_data_filtered |>
  left_join(param_type_lut, by = "parameter") |>
  left_join(select(site_defs, site, full_name, type), by = "site") |>
  filter(
    date >= as.Date("2019-10-01"),   # WY 2020 onward
    !is.na(value)
  ) |>
  mutate(
    # Nice panel label: site code + abbreviated location
    panel_label = paste0(site, "\n", str_trunc(full_name, 28, ellipsis = "…")),
    # Water year
    wy = if_else(month(date) >= 10, year(date) + 1L, year(date))
  )

# Palette: two clean colors for flow vs. elevation/stage
pal <- c("Flow (cfs)"     = "#1D9E75",
         "Elevation (ft)" = "#378ADD",
         "Stage (ft)"     = "#BA7517")

# -- Build plot
p <- plot_data |>
  ggplot(aes(x = date, y = value, color = param_type)) +
  geom_line(linewidth = 0.4, alpha = 0.85) +
  facet_wrap(
    ~ panel_label,
    scales = "free_y",
    ncol   = 4
  ) +
  scale_color_manual(values = pal, name = "Measurement type") +
  scale_x_date(
    date_breaks = "1 year",
    date_labels = "WY%y",
    expand      = expansion(mult = 0.02)
  ) +
  scale_y_continuous(labels = comma_format(accuracy = 1)) +
  labs(
    title    = "Klamath Basin Hydromet — Daily values (WY 2020–present)",
    subtitle = "USBR Klamath Project monitoring network | provisional data subject to change",
    x        = NULL,
    y        = NULL,
    caption  = "Source: USBR PN Hydromet webarccsv.pl  |  Sites: LRS, CLK, LRSC, KELO, HRPO, LRD, LRVO, GER, ACHO, MHPO, MAL, LVNO, EEEO, FPPO, STDC"
  ) +
  theme_minimal(base_size = 10) +
  theme(
    plot.title       = element_text(face = "bold", size = 12),
    plot.subtitle    = element_text(color = "grey40", size = 9),
    plot.caption     = element_text(color = "grey50", size = 7, hjust = 0),
    strip.text       = element_text(size = 7.5, face = "bold", hjust = 0),
    strip.background = element_rect(fill = "grey95", color = NA),
    axis.text.x      = element_text(size = 7, angle = 45, hjust = 1),
    axis.text.y      = element_text(size = 7),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "grey92"),
    legend.position  = "bottom",
    legend.text      = element_text(size = 9),
    plot.margin      = margin(10, 12, 8, 8)
  )

p

# Save
ggsave(
  "data-raw/data-exploration/klamath_hydromet_daily.png",
  plot   = p,
  width  = 14,
  height = 10,
  dpi    = 180,
  bg     = "white"
)

# save data ---------------------------------------------------------------

hydromet_data <- hydromet_data_filtered |>
  #left_join(select(param_defs, parameter, full_name, units), by = "parameter") |>
  #mutate(parameter = full_name) |>
  select(site, parameter, label, date, value)

usethis::use_data(hydromet_data, overwrite = TRUE)
