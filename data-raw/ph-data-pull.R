library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

# the goal of this script is to pull pH data from different sources and save into aws bucket. Pulling last 10 years data

# Define aws bucket (klamath-sdm)
wq_data_raw <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1", prefix = "water_quality/data-raw/")


### WQX data pull -----
#### ph data pull----
huc_code <- "180102" # huc code for Klamath basin

# DO data
wqx_ph_data <- readWQPdata(huc = huc_code,                       
                           characteristicName = "pH",
                           startDateLo = "2014-01-01",               
                           startDateHi = "2025-01-01") 

# gage data has already been pulled in temp data pull script

### USGS data pull -----
#### pH data pull----

# Define Klamath Basin HUC-8 codes (split into two groups)
klamath_hucs_1 <- c("18010201", "18010202", "18010203", "18010204",
                    "18010205", "18010206", "18010207", "18010208",
                    "18010209", "18010210")  # First 10 HUC-8 codes

klamath_hucs_2 <- c("18010211", "18010212")  # Remaining HUC-8 codes

# Retrieve sites for each batch
klamath_sites_1 <- whatNWISsites(huc = klamath_hucs_1)
klamath_sites_2 <- whatNWISsites(huc = klamath_hucs_2)

# Combine both datasets
klamath_sites <- bind_rows(klamath_sites_1, klamath_sites_2)

# Extract unique site numbers
usgs_gages <- unique(klamath_sites$site_no)

# View first few gages
head(usgs_gages)

# Define parameters
start_date <- "2014-01-01"
parameterCd <- "00400"  # pH
statCd <- c("00001", "00002", "00003")  # Min, Max, Mean pH

# Empty list to store dataframes
all_ph_data <- list()

# Loop through each gage and pull pH data
for (gage in usgs_gages) {
  message(paste("Pulling pH data for gage:", gage))
  try({
    ph_data <- readNWISdv(
      siteNumbers = gage, 
      parameterCd = parameterCd, 
      statCd = statCd, 
      startDate = start_date
    ) 
    
    # Add gage ID column
    ph_data <- ph_data |> 
      mutate(gage_id = gage)
    
    # Store in list
    all_ph_data[[gage]] <- ph_data
  }, silent = TRUE)
}

# Combine all gage data into one dataframe
usgs_ph_data <- bind_rows(all_ph_data)

# View the data
glimpse(usgs_ph_data)


#### gage data pull----
usgs_gage_ph_data <- readNWISsite(usgs_gages)


##### save raw data into aws bucket water-quality/data-raw/
### WQX
# pH data
wq_data_raw |> pins::pin_write(wqx_ph_data,
                               type = "csv",
                               title = "wqx_ph")

### USGS 
# pH data
wq_data_raw |> pins::pin_write(usgs_ph_data,
                               type = "csv",
                               title = "usgs_ph")
# # gage pH data
wq_data_raw |> pins::pin_write(usgs_gage_ph_data,
                               type = "csv",
                               title = "usgs_gage_ph")
