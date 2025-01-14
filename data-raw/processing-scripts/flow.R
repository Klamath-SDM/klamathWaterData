# Processing script for USGS flow data 
library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)
library(pins)

# define AWS data bucket
# note that you need to set up access keys in R environ
klamath_project_board <- pins::board_s3(
  bucket="klamath-sdm",
  access_key=Sys.getenv("aws_access_key_id"),
  secret_access_key=Sys.getenv("secret_access_key_id"),
  session_token = Sys.getenv("session_token_id"),
  region = "us-east-1"
)


# USGS primarily provides mean daily flow data (statCd = "00003") for most gages when querying the daily value.
# Minimum (statCd = "00002") and maximum (statCd = "00001") statistics are generally not available for flow data 
# unless they are specifically collected and reported for a given site. For now we are just pulling mean flow
# TODO unify the stream categories we will use. Probably establish on data schema

### Klmath mainsteam

gage_info_klamath <- tibble(
  gage_number = c("11509500", "11510700", "11516530", "11520500", "11523000", "11530500"),
  gage_name = c(
    "Klamath River at Keno OR",
    "Klamath River Below John C Boyle Powerplant",
    "Klamath River Below Irongate Dam",
    "Klamath River Nr Seiad Valley CA",
    "Klamath River At Orleans",
    "Klamath River Near Klamath (Furthest Downstream)"))

# Initialize an empty list to store data
all_gage_klamath <- list()

# Loop through each gage
for (i in seq_len(nrow(gage_info_klamath))) {
  gage_number <- gage_info_klamath$gage_number[i]
  gage_name <- gage_info_klamath$gage_name[i]
  
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
    all_gage_klamath[[i]] <- data
  }
}

# Combine all data into a single tibble
klamath <- bind_rows(all_gage_klamath)
glimpse(klamath)

### Trinity River ----
gage_info_trinity <- tibble(
  gage_number = c(
    "11528700", "11530000", "11523200", "11525500", "11525655",
    "11525854", "11526250", "11526400", "11527000"),
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
        statCd = "00003") |> 
        select(
          date = Date,
          mean_flow = X_00060_00003) |> 
        rename(value = mean_flow) |> 
        mutate(statistic = "mean",
               stream = "trinity river",
               gage_number = gage_number,
               gage_name = gage_name,
               variable_name = "flow",
               unit = "cfs") |> 
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
  
 data <- readNWISdv(siteNumbers = gage_number, parameterCd = "00060", statCd = "00003") |> 
   select(date = Date,
          mean_flow = X_00060_00003) |> 
   rename(value = mean_flow) |> 
   mutate(statistic = "mean",
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
  select(date = Date,
         mean_flow = X_00060_00003) |> 
  rename(value = mean_flow) |> 
  mutate(statistic = "mean",
         stream = "salmon river",
         gage_number = "11522500",
         gage_name = "Salmon River At Somes Bar CA",
         variable_name = "flow",
         unit = "cfs") |> 
  select(stream, gage_number, gage_name, variable_name, date, value, unit, statistic)

glimpse(salmon_river)

### Sprague river ----
sprague_river <- readNWISdv(siteNumber = "11501000", parameterCd = "00060", statCd = "00003") |> 
  select(date = Date,
         mean_flow = X_00060_00003) |> 
  rename(value = mean_flow) |> 
  mutate(statistic = "mean",
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

### Link River ---
link_river <- readNWISdv(siteNumber = "11507500", parameterCd = "00060", statCd = "00003") |> 
  select(date = Date,
         mean_flow = X_00060_00003) |> 
  rename(value = mean_flow) |> 
  mutate(statistic = "mean",
         stream = "link river",
         gage_number = "11507500",
         gage_name = "Link River at Klamath Falls, OR",
         variable_name = "flow",
         unit = "cfs") |> 
  select(stream, gage_number, gage_name, variable_name, date, value, unit, statistic)

glimpse(link_river)

### Williamson ---- 
williamson_river <- readNWISdv(siteNumber = "11502500", parameterCd = "00060", statCd = "00003") |> 
  select(date = Date,
         mean_flow = X_00060_00003) |> 
  rename(value = mean_flow) |> 
  mutate(statistic = "mean",
         stream = "williamson river",
         gage_number = "11502500",
         gage_name = "Williamson River Below Sprague River Near Chiloquin, OR",
         variable_name = "flow",
         unit = "cfs") |> 
  select(stream, gage_number, gage_name, variable_name, date, value, unit, statistic)

glimpse(williamson_river)

### Other ----
gage_info_other <- tibble(
  gage_number = c(
    "11509340", "11509250", "11509105", "11504260",  "11504290"),
  gage_name = c(
    "Klamath Straits Drain Near Worden, OR",
    "Ady Canal Above Lower Klamath Nwr, Near Worden, OR",
    "North Canal at Highway 97, Near Midland, OR",
    "Fourmile Canal Near Klamath Agency, OR",
    "Sevenmile Cnl at Dike RD Br, NR Klamath Agency, OR"))

all_gage_list_other <- list()

for (i in seq_len(nrow(gage_info_other))) {
  gage_number <- gage_info_other$gage_number[i]
  gage_name <- gage_info_other$gage_name[i]
  
  data <- readNWISdv(siteNumbers = gage_number, parameterCd = "00060", statCd = "00003") |> 
    select(date = Date,
           mean_flow = X_00060_00003) |> 
    rename(value = mean_flow) |> 
    mutate(statistic = "mean",
           stream = "other", 
           gage_number = gage_number,
           gage_name = gage_name,
           variable_name = "flow",
           unit = "cfs") |> 
    select(stream, gage_number, gage_name, variable_name, date, value, unit, statistic)
  
  all_gage_list_other[[i]] <- data
}

other_streams <- bind_rows(all_gage_list_other)
glimpse(other_streams)


### Binding all data
all_usgs_flow_data <- bind_rows(trinity, klamath, scott_river, shasta, salmon_river, sprague_river, indian_creek, 
                           link_river, williamson_river, other_streams) |> 
  glimpse()

# write.csv(all_flow_data, "data/flow_usgs.csv")

# save to s3 storage
klamath_project_board |> pins::pin_write(all_usgs_flow_data,
                                         type = "csv",
                                         title = "usgs_flow")
