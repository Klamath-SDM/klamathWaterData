library(tidyverse)
library(readxl)
library(lubridate)

# ============================================================
# Tule Lake Elevation — Reconciling Three Data Sources
#
# Three separate sources report Tule Lake surface elevation, and they
# disagree on sump split and period of record. This inventories each
# on a common basis: (1) how many sites/sumps, (2) date range, (3)
# temporal resolution (daily & continuous vs. intermittent).
#
# Source A: klamathWaterData::teacup_diagram_data, site %in% c("TULC", "TULC2")
#   Pulled live from the USBR Hydromet historical archive API
#   (webarccsv.pl) in data-raw/data-pull/teacup-diagram-data-pull.R.
#   TULC = Sump 1A forebay elevation, TULC2 = Sump 1B forebay elevation.
#
# Source B: klamathWaterData::water_level_data, location == "tule lake"
#   A single gage_id, "usbr tule lake sump 1a", built in
#   data-raw/processing-scripts/lake-level-process-data.R from:
#     - TID Elevation Report 1986-2012.xls (1986-2012)
#     - TID Daily Report WY 2012-2013 ... WY 2024-2025 workbooks'
#       "TULE LAKE ELEV." column (real data 2012 - Jul 2021; empty
#       "-" placeholder from ~Aug 2021 onward - confirmed below)
#   OPEN QUESTION - two USBR emails describe this same "Tule Lake
#   Elev." / "TULE LAKE ELEV." column two different ways:
#     - The email that originally sent these TID files (undated in our
#       records) says: "I've attached files with Tule Lake Sump 1A
#       surface elevations ... the data you seek is labeled as column
#       'Tule Lake Elevation' for each month" - i.e. it IS Sump 1A.
#     - The 2026-08-17 email (sent alongside the new split-sump
#       Hydromet file, source C2 below) says the TID "Tule Lake Elev."
#       column is "a single undifferentiated gauge (not split by
#       sump)" - i.e. it is NOT sump-specific.
#   These conflict and haven't been reconciled - worth confirming
#   with USBR which characterization is correct before trusting the
#   gage_id label. Not changed here pending that answer.
#
# Source C: raw files in data-raw/raw-tule-lake-level-data/tule-lake/,
#   supplied with the same email, not yet in the package:
#   - C1: the same TID Daily Report workbooks as Source B (identical
#     files, re-supplied) - included here only to confirm/quantify the
#     undifferentiated gauge's real period of record.
#   - C2: "Tule lake elevations_Hydromet_2021_topresent.xlsx" - USBR
#     Hydromet pull, split by sump: "TULC FB sump 1a" / "TULC2 FB sump
#     1b". Per the email: Sump 1B continuous from Apr 2023 (intermittent
#     back to Aug 2021); Sump 1A continuous from Apr 2024. There's also
#     an old stilling well at Sump 1A pre-2012 that USBR is still
#     tracking down data for (not available yet).
# ============================================================

summarize_daily_series <- function(dates) {
  d <- sort(unique(as.Date(dates)))
  span <- as.numeric(max(d) - min(d)) + 1
  gaps <- diff(d)
  tibble(
    n_obs        = length(d),
    min_date     = min(d),
    max_date     = max(d),
    span_days    = span,
    pct_coverage = round(100 * length(d) / span, 1),
    n_gaps_gt7d  = sum(gaps > 7),
    resolution   = case_when(
      pct_coverage >= 95 ~ "daily, continuous",
      pct_coverage >= 50 ~ "daily, intermittent",
      TRUE               ~ "sparse/intermittent"
    )
  )
}

# ------------------------------------------------------------
# Source A: teacup_diagram_data (package, live Hydromet API pull)
# ------------------------------------------------------------
source_a <- klamathWaterData::teacup_diagram_data |>
  filter(site %in% c("TULC", "TULC2")) |>
  group_by(site) |>
  group_modify(~ summarize_daily_series(.x$date)) |>
  ungroup() |>
  mutate(source = "A. teacup_diagram_data (package)", .before = 1)

# ------------------------------------------------------------
# Source B: water_level_data (package)
# ------------------------------------------------------------
source_b <- klamathWaterData::water_level_data |>
  filter(location == "tule lake", !is.na(value)) |>
  group_by(gage_id) |>
  group_modify(~ summarize_daily_series(.x$date)) |>
  ungroup() |>
  rename(site = gage_id) |>
  mutate(source = "B. water_level_data (package)", .before = 1)

# ------------------------------------------------------------
# Source C1: raw TID Daily Report workbooks - confirm the
# undifferentiated "TULE LAKE ELEV." column's real period of record
# (this is the same data feeding Source B's post-2012 portion)
# ------------------------------------------------------------
tid_dir <- "data-raw/raw-tule-lake-level-data/tule-lake/Tule Lake Sump 1a Date"
tid_files <- list.files(tid_dir, pattern = "\\.xlsx?$", full.names = TRUE)
tid_files <- tid_files[!grepl("~\\$", tid_files)]

parse_tid_month_sheet <- function(path, sheet) {
  df <- suppressMessages(read_excel(path, sheet = sheet, col_names = TRUE))
  names(df) <- trimws(names(df))
  elev_col <- names(df)[str_detect(names(df), regex("TULE LAKE ELEV", ignore_case = TRUE))]
  if (!"DATE" %in% names(df) || length(elev_col) == 0) return(NULL)

  tibble(
    date    = as.Date(suppressWarnings(as.numeric(df[["DATE"]])), origin = "1899-12-30"),
    elev_ft = suppressWarnings(as.numeric(df[[elev_col[1]]]))
  ) |>
    filter(!is.na(date), !is.na(elev_ft))
}

tid_undifferentiated <- map_dfr(tid_files, function(f) {
  sheets <- excel_sheets(f)
  sheets <- sheets[str_detect(sheets, "^[A-Za-z]{3} [0-9]{4}$")]
  map_dfr(sheets, ~ parse_tid_month_sheet(f, .x))
}) |>
  distinct(date, .keep_all = TRUE)

source_c1 <- summarize_daily_series(tid_undifferentiated$date) |>
  mutate(source = "C1. raw TID 'TULE LAKE ELEV.' (undifferentiated, not sump-specific)",
         site = "tule lake (undifferentiated)", .before = 1)

# ------------------------------------------------------------
# Source C2: raw Hydromet export, split by sump (not yet in package)
# ------------------------------------------------------------
hydromet_email <- read_excel(
  "data-raw/raw-tule-lake-level-data/tule-lake/Tule lake elevations_Hydromet_2021_topresent.xlsx",
  col_types = c("date", "numeric", "numeric")
) |>
  rename(date = DATE, TULC = `TULC FB sump 1a`, TULC2 = `TULC2 FB sump 1b`) |>
  mutate(date = as.Date(date)) |>
  pivot_longer(c(TULC, TULC2), names_to = "site", values_to = "value") |>
  filter(!is.na(value))

source_c2 <- hydromet_email |>
  group_by(site) |>
  group_modify(~ summarize_daily_series(.x$date)) |>
  ungroup() |>
  mutate(source = "C2. raw Hydromet export, 2021-present (not yet in package)", .before = 1)

# ------------------------------------------------------------
# Combined summary - answers: how many sites, date range, resolution
# ------------------------------------------------------------
tule_source_summary <- bind_rows(source_a, source_b, source_c1, source_c2) |>
  select(source, site, n_obs, min_date, max_date, pct_coverage, n_gaps_gt7d, resolution)

print(tule_source_summary, n = Inf, width = Inf)

# ------------------------------------------------------------
# Reconciliation check: does Source A (live API) match Source C2
# (manually-supplied Hydromet export) for the overlapping period?
# ------------------------------------------------------------
source_a_wide <- klamathWaterData::teacup_diagram_data |>
  filter(site %in% c("TULC", "TULC2")) |>
  select(site, date, value)

value_compare <- hydromet_email |>
  inner_join(source_a_wide, by = c("site", "date"), suffix = c("_email", "_teacup")) |>
  mutate(diff_ft = value_email - value_teacup)

message(
  "\nSource A vs. Source C2 (", nrow(value_compare), " overlapping site-days): ",
  "max abs diff = ", max(abs(value_compare$diff_ft)), " ft -> ",
  if (max(abs(value_compare$diff_ft)) < 0.01) "identical, confirms both trace to the same USBR Hydromet system." else "MISMATCH - investigate."
)
