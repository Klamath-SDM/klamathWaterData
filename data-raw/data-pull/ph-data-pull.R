library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)

# the goal of this script is to pull pH data from different sources.

# Standardized pull window - matches lake-levels/flow/teacup-diagram pulls.
start_date <- as.Date("1996-01-01")
end_date   <- as.Date("2025-12-31")

### WQX data pull -----
#### ph data pull----
huc_code <- "180102" # huc code for Klamath basin

# DO data
wqx_ph_data <- readWQPdata(huc = huc_code,
                           characteristicName = "pH",
                           startDateLo = start_date,
                           startDateHi = end_date)

# gage data - this gage data pull can serve other parameters since it covers
# all sites with this huc code (Klamath basin); matches flow-data-pull.R and
# temperature-data-pull.R's own wqx_gage_data pulls. Pulled here directly
# rather than assumed to already exist from one of those other scripts
# having run first in the same session (ph-process-data.R depends on this).
wqx_gage_data <- whatWQPsites(huc = huc_code)

### USGS data pull -----
#### pH data pull----

# Define Klamath Basin HUC-8 codes (split into two groups)
klamath_hucs_1 <- c("18010201", "18010202", "18010203", "18010204",
                    "18010205", "18010206", "18010207", "18010208",
                    "18010209", "18010210")  # First 10 HUC-8 codes

klamath_hucs_2 <- c("18010211", "18010212")  # Remaining HUC-8 codes

# Retrieve sites for each batch - filtered to sites that actually report pH
# (parameterCd) up front, same rationale as do-data-pull.R: without this
# filter these two calls return every USGS site of any kind in these 12
# HUC8s, most with no pH data at all, and the per-site pull below would
# waste a network round-trip on each one.
klamath_sites_1 <- whatNWISsites(huc = klamath_hucs_1, parameterCd = "00400")
klamath_sites_2 <- whatNWISsites(huc = klamath_hucs_2, parameterCd = "00400")

# Combine both datasets
klamath_sites <- bind_rows(klamath_sites_1, klamath_sites_2)

# Extract unique site numbers
usgs_gages <- unique(klamath_sites$site_no)

# View first few gages
head(usgs_gages)

# Define parameters
parameterCd <- "00400"  # pH
statCd <- c("00001", "00002", "00003")  # Min, Max, Mean pH

# Pull DV data in batches rather than one site at a time - readNWISdv()
# accepts multiple site numbers per call, and NWIS's dv service handles a
# comma-joined site list in a single request. This replaces one network
# round-trip per site with one per ~50 sites, matching the batch size
# already used for the gage metadata pull below (and do-data-pull.R).
ph_site_batches <- split(usgs_gages, ceiling(seq_along(usgs_gages) / 50))

all_ph_data <- map(ph_site_batches, function(batch) {
  message("Pulling pH data for ", length(batch), " sites...")
  tryCatch(
    readNWISdv(
      siteNumbers = batch,
      parameterCd = parameterCd,
      statCd = statCd,
      startDate = start_date,
      endDate = end_date
    ),
    error = function(e) { message("  batch failed: ", conditionMessage(e)); NULL }
  )
})

# Combine all gage data into one dataframe
usgs_ph_data <- bind_rows(all_ph_data) |>
  mutate(gage_id = site_no)

# View the data
glimpse(usgs_ph_data)


#### gage data pull----
usgs_gage_ph_data <- readNWISsite(usgs_gages)
