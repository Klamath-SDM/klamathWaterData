# klamathWaterData

## What is klamathWaterData?

klamathWaterData is an R data package developed by FlowWest to support exploration, processing, and modeling of flow, temperature, and water quality datasets across rivers, lakes, streams, reservoirs, springs, and estuaries within the Klamath Basin.

This package was developed to support environmental decision models and scientific analyses.

**Data Sourced from:**

-   [United States Geological Survey (USGS)](https://dashboard.waterdata.usgs.gov/app/nwd/en/?region=lower48&aoi=default)
-   [National Water Quality Monititoring Council Water - Water Quality Portal (WQX)](https://www.waterqualitydata.us/)


## Install 
To install the `klamathWaterData` data package, please use the remotes package to download from GitHub.

``` r
#install.packages("remotes")
remotes::install_github("Klamath-SDM/klamathWaterData")
```

# Usage

After installation, you can explore the datasets included in the package:

``` r
library(klamathWaterData)

# View available datasets
data(package = "klamathWaterData")

# Load and inspect one
head(flow_data)
summary(temp_data)
``` 
