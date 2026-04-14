# =============================================================================
# Brazilian Airport Delay Aggregation
# =============================================================================
# Produces an airport_summary tibble directly compatible with plot_diverging_transfer()
# and plot_arr_vs_dep() in delay_transfer_analysis.R.
#
# Because the Brazilian dataset lacks aircraft registration (REG), true
# turnaround matching is not possible. Instead, delay transfer is estimated
# at hourly resolution:
#   - Flight-level ARR_DELAY and DEP_DELAY are computed per movement
#   - Movements are aggregated to ICAO x hour x PHASE, taking the mean delay
#   - Hours with no ARR *or* no DEP operations are excluded (not imputed)
#   - DELAY_TRANSFER = mean_DEP_DELAY - mean_ARR_DELAY per hour
#   - Airport-level summary = mean of hourly DELAY_TRANSFER values
#
# Input columns required in punc_bra (or per-airport subset):
#   FLTID      : character, flight identifier
#   ADEP       : character, origin ICAO
#   ADES       : character, destination ICAO
#   ICAO       : character, airport of study
#   PHASE      : character, "ARR" or "DEP"
#   SCHED_TIME : character, "dd-mm-yyyy HH:MM:SS"
#   BLOCK_TIME : character, "dd-mm-yyyy HH:MM:SS"
#
# TAT_REGION_FLAG is derived from ADEP / ADES using assign_region().
# mean_tat_buffer is set to NA throughout (no TAT data available).
# =============================================================================

library(tidyverse)

#' Parse Brazilian datetime strings to POSIXct
#'
#' Handles "dd-mm-yyyy HH:MM:SS" format.
#' @param x character vector
#' @param tz timezone string (default "UTC")
parse_bra_time <- function(x, tz = "UTC") {
  as.POSIXct(x, format = "%d-%m-%Y %H:%M:%S", tz = tz)
}

#' Prepare a single Brazilian airport's delay summary
#'
#' @param df            data.frame for ONE airport (ICAO column already present)
#' @param pattern_eur   regex pattern passed to assign_region() for EUR detection
#' @param bra_airports  character vector of BRA airport ICAO codes (for GEO_REGION)
#' @param eur_airports  character vector of EUR airport ICAO codes (for GEO_REGION)
#'
#' @return tibble with one row per TAT_REGION_FLAG level, airport_summary format
prepare_bra_airport <- function(df,
                                pattern_eur,
                                bra_airports = character(),
                                eur_airports = character()) {
  
  icao <- unique(df$ICAO)
  if (length(icao) != 1L) stop("df must contain exactly one ICAO value.")
  
  # --- 1. Parse times & compute flight-level delay ---------------------------
  fl <- df |>
    mutate(
      BLOCK_TIME = parse_bra_time(BLOCK_TIME),
      SCHED_TIME = parse_bra_time(SCHED_TIME)
    ) |>
    filter(!is.na(BLOCK_TIME), !is.na(SCHED_TIME)) |>
    mutate(
      DELAY      = as.numeric(difftime(BLOCK_TIME, SCHED_TIME, units = "mins")),
      BLOCK_HOUR = floor_date(BLOCK_TIME, unit = "hour"),
      REGION_FLAG = paste(
        assign_region(ADEP, pattern_eur, "EUR", "INTL"),
        assign_region(ADES, pattern_eur, "EUR", "INTL"),
        sep = "-"
      )
    ) |>
    filter(!is.na(DELAY))
  
  # --- 2. Hourly mean delay per PHASE x REGION_FLAG --------------------------
  hourly <- fl |>
    group_by(ICAO, BLOCK_HOUR, PHASE, REGION_FLAG) |>
    summarise(
      mean_delay = mean(DELAY, na.rm = TRUE),
      n_flights  = n(),
      .groups    = "drop"
    )
  
  # --- 3. Pivot wide: one row per hour x REGION_FLAG -------------------------
  # Hours missing either ARR or DEP are dropped (cannot estimate transfer)
  hourly_wide <- hourly |>
    pivot_wider(
      id_cols     = c(ICAO, BLOCK_HOUR, REGION_FLAG),
      names_from  = PHASE,
      values_from = c(mean_delay, n_flights)
    ) |>
    filter(!is.na(mean_delay_ARR), !is.na(mean_delay_DEP)) |>
    mutate(
      DELAY_TRANSFER = mean_delay_DEP - mean_delay_ARR
    )
  
  # --- 4. Airport-level summary per REGION_FLAG ------------------------------
  # n = number of valid hours (both ARR and DEP present)
  # pct_absorbed = % of hours where transfer is negative (absorbing)
  airport_summary <- hourly_wide |>
    group_by(ICAO, REGION_FLAG) |>
    summarise(
      n                   = n(),                                      # hours
      mean_arr_delay      = mean(mean_delay_ARR,   na.rm = TRUE),
      mean_dep_delay      = mean(mean_delay_DEP,   na.rm = TRUE),
      mean_delay_transfer = mean(DELAY_TRANSFER,   na.rm = TRUE),
      mean_tat_buffer     = NA_real_,                                 # not available
      pct_absorbed        = mean(DELAY_TRANSFER < 0, na.rm = TRUE) * 100,
      .groups             = "drop"
    ) |>
    rename(TAT_REGION_FLAG = REGION_FLAG) |>
    mutate(
      GEO_REGION = case_when(
        ICAO %in% bra_airports ~ "BRA",
        ICAO %in% eur_airports ~ "EUR",
        TRUE                   ~ "OTHER"
      )
    ) |>
    # Match column order of EUR airport_summary
    select(ICAO, GEO_REGION, TAT_REGION_FLAG, n,
           mean_arr_delay, mean_dep_delay,
           mean_delay_transfer, mean_tat_buffer, pct_absorbed)
  
  airport_summary
}

#' Prepare all Brazilian airports and bind into one summary tibble
#'
#' @param punc_bra      full Brazilian movements tibble (all airports)
#' @param pattern_eur   regex pattern for assign_region()
#' @param bra_airports  character vector of BRA ICAO codes
#' @param eur_airports  character vector of EUR ICAO codes
#'
#' @return tibble in airport_summary format, all BRA airports stacked
prepare_bra_summary <- function(punc_bra,
                                pattern_bra, # pattern_eur,
                                bra_airports = character(),
                                eur_airports = character()) {
  
  punc_bra |>
    group_by(ICAO) |>
    group_split() |>
    set_names(
      punc_bra |> group_by(ICAO) |> group_keys() |> pull(ICAO)
    ) |>
    map(\(airport_df) {
      prepare_bra_airport(airport_df, pattern_bra, bra_airports, eur_airports)
    }) |>
    list_rbind()
}
