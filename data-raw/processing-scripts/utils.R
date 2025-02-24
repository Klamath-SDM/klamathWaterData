# functions used to process water data 

extract_waterbody <- function(names) {
  names <- gsub("\\bRvr\\b", "River", names, ignore.case = TRUE)
  names <- gsub("\\br\\b", "River", names, ignore.case = TRUE)
  
  names <- stringr::str_extract(names, "(?i)(\\b(?:upper|lower|north|south|east|west|middle|fork|branch)?\\s*(?:\\w+\\s){0,3}(?:Creek|River))")
  
  cleaned_names <- gsub("\\b(?:at|HOBO)\\b", "", names, ignore.case = TRUE)
  result <- trimws(cleaned_names)
  return(result)
}


