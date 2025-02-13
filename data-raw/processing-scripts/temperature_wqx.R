library(tidyverse)
library(dplyr)
library(dataRetrieval)
library(tidyr)
library(purrr)


# define AWS data bucket
# note that you need to set up access keys in R environ
klamath_project_board <- pins::board_s3(
  bucket="klamath-sdm",
  access_key=Sys.getenv("aws_access_key_id"),
  secret_access_key=Sys.getenv("secret_access_key_id"),
  session_token = Sys.getenv("session_token_id"),
  region = "us-east-1"
)

## Pulling last 10 years of temp data - Filtering to monitoring location types: River/Stream, Lake, Stream, "Lake, Reservoir, Impoundment", Reservoir, spring, estuary``



# save to s3 storage
# klamath_project_board |> pins::pin_write(all_wqx_temperature_data,
#                                          type = "csv",
#                                          title = "wqx_temperature")