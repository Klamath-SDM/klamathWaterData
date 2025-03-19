library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

# the goal of this script is to pull dissolved oxygen data from different sources and save into aws bucket. Pulling last 10 years of data

# Define aws bucket (klamath-sdm)
wq_data_raw <- pins::board_s3(bucket = "klamath-sdm", region = "us-east-1", prefix = "water_quality/data-raw/")


### WQX data pull -----
#### do data pull----
huc_code <- "180102" # huc code for Klamath basin

# DO data
wqx_do_data <- readWQPdata(huc = huc_code,                       
                             characteristicName = "Dissolved oxygen (DO)",
                             startDateLo = "2014-01-01",               
                             startDateHi = "2025-01-01") 

# gage data has already been pulled in temp data pull script

### USGS data pull -----
#### do data pull----

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
parameterCd <- "00300"  # Dissolved Oxygen
statCd <- c("00001", "00002", "00003")  # Min, Max, Mean DO

# Empty list to store dataframes
all_do_data <- list()

# Loop through each gage and pull DO data
for (gage in usgs_gages) {
  message(paste("Pulling DO data for gage:", gage))
  try({
    do_data <- readNWISdv(
      siteNumbers = gage, 
      parameterCd = parameterCd, 
      statCd = statCd, 
      startDate = start_date
    ) 
    
    # Add gage ID column
    do_data <- do_data |> 
      mutate(gage_id = gage)
    
    # Store in list
    all_do_data[[gage]] <- do_data
  }, silent = TRUE)
}

# Combine all gage data into one dataframe
usgs_do_data <- bind_rows(all_do_data)

# View the data
glimpse(usgs_do_data)


#### gage data pull----
usgs_gage_do_data <- readNWISsite(usgs_gages)


##### save raw data into aws bucket water-quality/data-raw/
### WQX
# do data
wq_data_raw |> pins::pin_write(wqx_do_data,
                               type = "csv",
                               title = "wqx_do")

### USGS 
# do data
wq_data_raw |> pins::pin_write(usgs_do_data,
                               type = "csv",
                               title = "usgs_do")
# gage do data
wq_data_raw |> pins::pin_write(usgs_gage_do_data,
                               type = "csv",
                               title = "usgs_gage_do")

