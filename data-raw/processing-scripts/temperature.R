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



### Klamath mainstem ### ----

gage_info <- tibble(
  gage_number = c("11507500", "11510700", "11530500", "11523000", "11509500", "11509370", 
                  "420741121554001", "420451121510000", "420448121503100", "420853121505500", "420853121505501"),
  gage_name = c(
    "LINK RIVER AT KLAMATH FALLS, OR",
    "SPRAGUE RIVER NEAR CHILOQUIN, OR",
    "SHASTA RIVER AT YREKA, CA",
    "SCOTT RIVER NEAR FORT JONES, CA",
    "WOOD RIVER NEAR KLAMATH FALLS, OR",
    "WILLIAMSON RIVER NEAR KLAMATH AGENCY, OR",
    "KLAMATH RIVER ABV KENO DAM, AT KENO - BOTTOM",
    "KLAMATH STRAITS DRAIN NEAR HIGHWAY 97, OR",
    "KLAMATH STRAITS DRAIN ABOVE F-FF PUMPS, WORDEN, OR",
    "KLAMATH RIVER AT MILLER ISLAND BOAT RAMP, OR",
    "KLAMATH RIVER AT MILLER ISLAND BOAT RAMP-BOTTOM"
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


### Trinity River ----

gage_info_trinity <- tibble(
  gage_number = c("11526400", "11530000"),
  gage_name = c("TRINITY R AB NF TRINITY R NR HELENA CA", "TRINITY R A HOOPA CA"
    
  )
)

# Function to fetch and process data for a single gage
# Initialize an empty list to store data frames for each gage
all_gage_list_trinity <- list()

# Loop through each gage in main_steam
for (i in seq_len(nrow(gage_info_trinity))) {
  gage_number <- gage_info_trinity$gage_number[i]
  gage_name <- gage_info_trinity$gage_name[i]
  
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
          stream = "tirnity river", 
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
    all_gage_list_trinity[[i]] <- data
  }
}

all_gage_data_trinity <- bind_rows(all_gage_list_trinity)
glimpse(all_gage_data_trinity)


### Upper Klamath River ----

gage_info_upper_kl <- tibble(
  gage_number = c("422042121513100", "421935121551200", "422305121553800", "422305121553803", "422444121580400",
                  "422622122004000", "422622122004003", "422719121571400", "11504290"),
  gage_name = c("RATTLESNAKE POINT - RPT", "UPPER KLAMATH LAKE AT HOWARD BAY, OR", "MID-TRENCH - LOWER - MDTL",
                "MID-TRENCH - UPPER - MDTU", "SHOALWATER BAY - SHB", "MID-NORTH - LOWER - MDNL", "MID-NORTH - UPPER - MDNU",
                "WILLIAMSON RIVER OUTLET - WMR", "SEVENMILE CNL AT DIKE RD BR, NR KLAMATH AGENCY, OR"
                
  )
)

# Function to fetch and process data for a single gage
# Initialize an empty list to store data frames for each gage
all_gage_list_upper_kl <- list()

# Loop through each gage in main_steam
for (i in seq_len(nrow(gage_info_upper_kl))) {
  gage_number <- gage_info_upper_kl$gage_number[i]
  gage_name <- gage_info_upper_kl$gage_name[i]
  
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
          stream = "upper klamath river", 
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
    all_gage_list_upper_kl[[i]] <- data
  }
}

all_gage_data_upper_kl <- bind_rows(all_gage_list_upper_kl)
glimpse(all_gage_data_upper_kl)
