# Processing script for USGS flow data 
library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)

# USGS primarily provides mean daily flow data (statCd = "00003") for most gages when querying the daily value.
# Minimum (statCd = "00002") and maximum (statCd = "00001") statistics are generally not available for flow data 
# unless they are specifically collected and reported for a given site. For now we are just pulling mean flow

### Klmath mainsteam

gage_info_klamath <- tibble(
  gage_number = c("11509500", "11510700", "11516530", "11520500", "11523000", "11530500"),
  gage_name = c(
    "Klamath River at Keno OR",
    "Klamath River Below John C Boyle Powerplant",
    "Klamath River Below Irongate Dam",
    "Klamath River Nr Seiad Valley CA",
    "Klamath River At Orleans",
    "Klamath River Near Klamath (Furthest Downstream)"
  )
)

# Initialize an empty list to store data
all_gage_klamath <- list()

# Loop through each gage
for (i in seq_len(nrow(gage_klamath))) {
  gage_number <- gage_klamath$gage_number[i]
  gage_name <- gage_klamath$gage_name[i]
  
  # Fetch mean flow data
  data <- tryCatch(
    {
      readNWISdv(
        siteNumbers = gage_number, 
        parameterCd = "00060", # Flow parameter code
        statCd = "00003"       # Mean flow only
      ) |> 
        select(
          date = Date,
          mean_flow = X_00060_00003 # Mean flow
        ) |> 
        rename(value = mean_flow) |> 
        mutate(
          statistic = "mean",
          stream = "klamath river",
          gage_number = gage_number,
          gage_name = gage_name,
          variable_name = "flow",
          unit = "cfs"
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


# Combine all data into a single tibble
klamath <- bind_rows(all_gage_list)

# View the combined data
glimpse(klamath)

### Trinity River ----
gage_info_trinity <- tibble(
  gage_number = c(
    "11528700", "11530000", "11523200", "11525500", "11525655",
    "11525854", "11526250", "11526400", "11527000"
  ),
  gage_name = c(
    "SF Trinity River Below Hyampom CA",
    "Trinity River At Hoopa CA",
    "Trinity River Above Coffee C Near Trinity Center CA",
    "Trinity River At Lewiston CA",
    "Trinity River Below Limekiln Gulch Near Douglas City CA",
    "Trinity River At Douglas City CA",
    "Trinity River At Junction City CA",
    "Trinity River Above NF Trinity River Near Helena CA",
    "Trinity River Near Burnt Ranch CA"))

all_gage_list_trinity <- list()

for (i in seq_len(nrow(gage_info_trinity))) {
  gage_number <- gage_info_trinity$gage_number[i]
  gage_name <- gage_info_trinity$gage_name[i]

  data <- tryCatch(
    {
      readNWISdv(
        siteNumbers = gage_number, 
        parameterCd = "00060", 
        statCd = "00003"      
      ) |> 
        select(
          date = Date,
          mean_flow = X_00060_00003
        ) |> 
        rename(value = mean_flow) |> 
        mutate(
          statistic = "mean",
          stream = "trinity river",
          gage_number = gage_number,
          gage_name = gage_name,
          variable_name = "flow",
          unit = "cfs"
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

trinity <- bind_rows(all_gage_list_trinity)
glimpse(trinity)

### Scott ----
scott_river <- readNWISdv(siteNumber = "11519500", parameterCd = "00060", statCd = "00003") |> 
  select(date = Date,
         mean_flow = X_00060_00003) |> 
  rename(value = mean_flow) |> 
  mutate(statistic = "mean",
    stream = "scott river",
    gage_number = gage_number,
    gage_name = "Scott River Near Fort Jones CA",
    variable_name = "flow",
    unit = "cfs") |> 
  select(stream, gage_number, gage_name, variable_name, date, value, unit, statistic)

glimpse(scott_river)

### Shasta ----
gage_info_shasta <- tibble(
  gage_number = c("11517000", "11517500"),
  gage_name = c(
    "Shasta River Near Montague CA",
    "Shasta River Near Yreka CA"))

all_gage_list_shasta <- list()

for (i in seq_len(nrow(gage_info_shasta))) {
  gage_number <- gage_info_shasta$gage_number[i]
  gage_name <- gage_info_shasta$gage_name[i]
  
 data <- readNWISdv(
    siteNumbers = gage_number, 
    parameterCd = "00060", 
    statCd = "00003") |> 
    select(date = Date,
           mean_flow = X_00060_00003) |> 
    rename(value = mean_flow) |> 
    mutate(
      statistic = "mean",
      stream = "shasta river",
      gage_number = gage_number,
      gage_name = gage_name,
      variable_name = "flow",
      unit = "cfs") |> 
    select(stream, gage_number, gage_name, variable_name, date, value, unit, statistic)
  
  all_gage_list_shasta[[i]] <- data
}

shasta <- bind_rows(all_gage_list_shasta)
glimpse(shasta)

### Salmon ----
salmon_river <- readNWISdv( siteNumber = "11522500", parameterCd = "00060", statCd = "00003") |> 
  select(
    date = Date,
    mean_flow = X_00060_00003) |> 
  rename(value = mean_flow) |> 
  mutate(
    statistic = "mean",
    stream = "salmon river",
    gage_number = "11522500",
    gage_name = "Salmon River At Somes Bar CA",
    variable_name = "flow",
    unit = "cfs") |> 
  select(stream, gage_number, gage_name, variable_name, date, value, unit, statistic)

glimpse(salmon_river)

### Sprague river ----
sprague_river <- readNWISdv(siteNumber = "11501000", parameterCd = "00060", statCd = "00003") |> 
  select(
    date = Date,
    mean_flow = X_00060_00003) |> 
  rename(value = mean_flow) |> 
  mutate(
    statistic = "mean",
    stream = "sprague river",
    gage_number = "11501000",
    gage_name = "Sprague River Near Chiloquin, OR",
    variable_name = "flow",
    unit = "cfs") |> 
  select(stream, gage_number, gage_name, variable_name, date, value, unit, statistic)

glimpse(sprague_river)

### Indian reek ----
gage_info_indian_creek <- tibble(
  gage_number = c("11525670", "11521500"),
  gage_name = c(
    "Indian Creek Near Douglas City CA",
    "Indian Creek Near Happy Camp CA"))

all_gage_list_indian_creek <- list()

for (i in seq_len(nrow(gage_info_indian_creek))) {
  gage_number <- gage_info_indian_creek$gage_number[i]
  gage_name <- gage_info_indian_creek$gage_name[i]
    
  data <- readNWISdv(siteNumbers = gage_number, parameterCd = "00060", statCd = "00003") |> 
    select(date = Date,
           mean_flow = X_00060_00003) |> 
    rename(value = mean_flow) |> 
    mutate(statistic = "mean",
           stream = "indian creek",
           gage_number = gage_number,
           gage_name = gage_name,
           variable_name = "flow",
           unit = "cfs") |> 
    select(stream, gage_number, gage_name, variable_name, date, value, unit, statistic)
  
  all_gage_list_indian_creek[[i]] <- data
}

indian_creek <- bind_rows(all_gage_list_indian_creek)

glimpse(indian_creek)

#Still need to pull:
# Klamath Straits Drain Near Worden, OR - 11509340
# - Ady Canal Above Lower Klamath Nwr, Near Worden, OR - 11509250
# - North Canal at Highway 97, Near Midland, OR - 11509105
# - Link River at Klamath Falls, OR - 11507500
# - Williamson River Blw Sprague River NR Chiloquin,or - 11502500
# - Crystal Creek Near Rocky Point, OR - 11504270 - NODATA
# - Fourmile Canal Near Klamath Agency, OR - 11504260
# - Sevenmile Cnl at Dike RD Br, NR Klamath Agency, OR - 11504290



### Test binding with data so far

all_flow_data <- bind_rows(trinity, klamath, scott_river, shasta, salmon_river, sprague_river, indian_creek) |> 
  glimpse()
