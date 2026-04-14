assign_region <- function(
    icao
    , prefixes
    , label = "Study"
    , other = NA_character_
) {
  stopifnot(is.character(icao), is.character(prefixes))
  
  pattern <- paste0("^(", paste(prefixes, collapse = "|"), ")")
  
  ifelse(grepl(pattern, icao), label, other)
}

