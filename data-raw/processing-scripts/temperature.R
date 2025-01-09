# Processing script for USGS temperature data 
library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)

# 00001	Maximum
# 00002	Minimum
# 00003	Mean

# code for reference, delete later
klamath_fl <- dataRetrieval::readNWISdv(11507500, "00010", statCd = c("00001", "00002", "00003")) |> 
  select(date = Date,     
         value = X_00010_00003, 
         min_temp = X_00010_00002,
         max_temp = X_00010_00001) |> 
  as_tibble() |> 
  mutate(stream = "klamath river",
         gage_number = "11507500",
         gage_name = "LINK RIVER AT KLAMATH FALLS, OR",
         variable_name = "temperature",
         unit = "celsius") |> 
  pivot_longer(cols = c(value, min_temp, max_temp),
               names_to = "statistic",
               values_to = "value") |> 
  mutate(statistic = case_when(
    statistic == "value" ~ "mean", # I noticed that min, max and mean do not have the same amount of values pulled
    statistic == "min_temp" ~ "minimum",
    statistic == "max_temp" ~ "maximum")) |> 
  glimpse()



### Klamath mainstem - testing with just a few gages to check functionality 

gage_info <- tibble(
  gage_number = c("11507500", "11510700", "11530500", "11523000", "11509500", "11509370"),
  gage_name = c(
    "LINK RIVER AT KLAMATH FALLS, OR",
    "SPRAGUE RIVER NEAR CHILOQUIN, OR",
    "SHASTA RIVER AT YREKA, CA",
    "SCOTT RIVER NEAR FORT JONES, CA",
    "WOOD RIVER NEAR KLAMATH FALLS, OR",
    "WILLIAMSON RIVER NEAR KLAMATH AGENCY, OR"
  )
)

# Function to fetch and process data for a single gage
# Initialize an empty list to store data frames for each gage
all_gage_list <- list()

# Loop through each gage in main_steam
for (i in seq_len(nrow(gage_info))) {
  gage_number <- gage_info$gage_number[i]
  gage_name <- gage_info$gage_name[i]

  data <- tryCatch(
    {
      readNWISdv(
        siteNumbers = gage_number, 
        parameterCd = "00010", 
        statCd = c("00001", "00002", "00003")
      ) |> 
        select(
          date = Date,
          max_temp = X_00010_00001, # Max
          min_temp = X_00010_00002, # Min
          mean_temp = X_00010_00003 # Mean 
        ) |> 
        pivot_longer(
          cols = c(max_temp, min_temp, mean_temp),
          names_to = "statistic",
          values_to = "value",
          values_drop_na = TRUE
        ) |> 
        mutate(
          statistic = case_when(
            statistic == "max_temp" ~ "maximum",
            statistic == "min_temp" ~ "minimum",
            statistic == "mean_temp" ~ "mean"
          ),
          stream = "klamath river", 
          gage_number = gage_number,
          gage_name = gage_name,
          variable_name = "temperature",
          unit = "celsius"
        ) |> 
        select(stream, gage_number, gage_name, variable_name, date, value, unit, statistic)
    },
    error = function(e) {
      message(paste("Error fetching data for gage", gage_number, ":", e$message))
      return(NULL)
    }
  )
  
  if (!is.null(data)) {
    all_gage_list[[i]] <- data
  }
}

all_gage_data <- bind_rows(all_gage_list)
glimpse(all_gage_data)
