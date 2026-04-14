# =============================================================================
# Turnaround Matching Function
# =============================================================================
# Matches ARR and DEP movements for the same aircraft registration (REG)
# at a given airport to identify valid turnarounds.
#
# Input data expectations:
#   - ADEP        : character, origin airport ICAO
#   - ADES        : character, destination airport ICAO
#   - PHASE       : character, "ARR" or "DEP"
#   - REG         : character, aircraft registration
#   - MVT_TIME    : POSIXct, actual landing (ARR) or take-off (DEP) time
#   - BLOCK_TIME  : POSIXct, actual in-block (ARR) or off-block (DEP) time
#   - SCHED_TIME  : POSIXct, scheduled in-block (ARR) or off-block (DEP) time
#   - REGION_FLAG : character, one of "EUR-EUR", "EUR-INTL", "INTL-EUR", "INTL-INTL"
#                   (reflecting the region combination of the full flight)
#
# Notes:
#   - For ARR rows: ADES == study airport
#   - For DEP rows: ADEP == study airport
#   - BLOCK_TIME and SCHED_TIME must be proper POSIXct (timezone-aware recommended)
#     so that midnight / month / year boundaries are handled by arithmetic alone.
#   - data.table rolling join (roll = "nearest" with upper bound) is used for
#     efficiency at ~500k row scale.
# =============================================================================

library(data.table)

#' Match turnarounds at a single airport
#'
#' @param df            data.frame or data.table for one airport (all phases)
#' @param tat_eur_eur   integer, max turnaround minutes for EUR-EUR pairs
#' @param tat_eur_intl  integer, max turnaround minutes for EUR-INTL pairs
#' @param tat_intl_eur  integer, max turnaround minutes for INTL-EUR pairs
#' @param tat_intl_intl integer, max turnaround minutes for INTL-INTL pairs
#'
#' @return data.table with one row per valid turnaround
match_turnarounds <- function(
    df,
    tat_eur_eur   = 120L,
    tat_eur_intl  = 120L,
    tat_intl_eur  = 120L,
    tat_intl_intl = 270L
) {
  
  # --- 0. Coerce to data.table (no-copy if already DT) ----------------------
  dt <- as.data.table(df)
  
  # --- 1. Split ARR and DEP --------------------------------------------------
  arr <- dt[PHASE == "ARR", .(
    REG,
    ARR_ADEP_ADES  = paste(ADEP, ADES, sep = "-"),
    ARR_REGION     = REGION_FLAG,          # region flag of the inbound flight
    ARR_BLOCK_TIME = BLOCK_TIME,           # actual in-block
    ARR_SCHED_TIME = SCHED_TIME            # scheduled in-block
  )]
  
  dep <- dt[PHASE == "DEP", .(
    REG,
    DEP_ADEP_ADES  = paste(ADEP, ADES, sep = "-"),
    DEP_REGION     = REGION_FLAG,          # region flag of the outbound flight
    DEP_BLOCK_TIME = BLOCK_TIME,           # actual off-block
    DEP_SCHED_TIME = SCHED_TIME            # scheduled off-block
  )]
  
  # --- 2. Deduplicate before joining -----------------------------------------
  # Duplicate rows (same REG + BLOCK_TIME) cause a cartesian explosion in the
  # rolling join. Keep the first occurrence per REG x BLOCK_TIME in each table.
  # This handles both exact duplicate rows and the rare case of two flights
  # logged with identical registration and block time to the second.
  arr <- unique(arr, by = c("REG", "ARR_BLOCK_TIME"))
  dep <- unique(dep, by = c("REG", "DEP_BLOCK_TIME"))
  
  # --- 3. Set keys for rolling join ------------------------------------------
  # Use distinct column names for the join key in each table to avoid
  # data.table's i. prefix ambiguity after the rolling join.
  arr[, arr_join_time := as.numeric(ARR_BLOCK_TIME)]
  dep[, dep_join_time := as.numeric(DEP_BLOCK_TIME)]
  
  # Rolling join requires a single shared key column name, so we add one
  # to each table pointing at their respective block times.
  arr[, join_time := arr_join_time]
  dep[, join_time := dep_join_time]
  
  setkey(arr, REG, join_time)
  setkey(dep, REG, join_time)
  
  # --- 3. Rolling join -------------------------------------------------------
  # For each ARR row, find the smallest DEP join_time >= ARR join_time
  # for the same REG (i.e. roll forward to next departure).
  # roll = -Inf in data.table rolls forward (finds next value >= query).
  matched <- dep[arr, roll = -Inf, rollends = c(FALSE, TRUE)]
  
  # After the join:
  #   join_time        = DEP join_time (from the rolling/reference table)
  #   arr_join_time    = carried through from arr (no i. clash as named distinctly)
  #   dep_join_time    = carried through from dep
  # Drop the redundant shared key column; the originals are sufficient.
  matched[, join_time := NULL]
  
  # --- 4. Remove unmatched rows (no DEP found) -------------------------------
  matched <- matched[!is.na(DEP_BLOCK_TIME)]
  
  # Safety: DEP must be strictly AFTER ARR in-block (not same second)
  matched <- matched[DEP_BLOCK_TIME > ARR_BLOCK_TIME]
  
  # --- 5. Compute actual turnaround duration (minutes) ----------------------
  matched[, TAT_ACTUAL := as.numeric(
    difftime(DEP_BLOCK_TIME, ARR_BLOCK_TIME, units = "mins")
  )]
  
  matched[, TAT_SCHED := as.numeric(
    difftime(DEP_SCHED_TIME, ARR_SCHED_TIME, units = "mins")
  )]
  
  # --- 6. Derive combined region flag for the turnaround --------------------
  # The inbound leg REGION_FLAG encodes its own origin region (EUR or INTL).
  # The outbound leg REGION_FLAG encodes its own destination region.
  # We extract the first element (origin side) of each to compose the pair.
  #
  # Convention:  ARR REGION_FLAG = "X-AIRPORT_REGION"  -> take part 1 = inbound origin
  #              DEP REGION_FLAG = "AIRPORT_REGION-Y"  -> take part 2 = outbound dest
  #
  # Combined turnaround region = inbound_origin + "-" + outbound_destination
  matched[, inbound_origin  := sub("-.*", "", ARR_REGION)]
  matched[, outbound_dest   := sub(".*-", "", DEP_REGION)]
  matched[, TAT_REGION_FLAG := paste(inbound_origin, outbound_dest, sep = "-")]
  
  # --- 7. Build threshold lookup and filter ----------------------------------
  threshold_map <- data.table(
    TAT_REGION_FLAG = c("EUR-EUR", "EUR-INTL", "INTL-EUR", "INTL-INTL"),
    max_tat         = c(tat_eur_eur, tat_eur_intl, tat_intl_eur, tat_intl_intl)
  )
  
  matched <- threshold_map[matched, on = "TAT_REGION_FLAG"]
  matched <- matched[TAT_ACTUAL <= max_tat]
  
  # --- 8. Select and order output columns ------------------------------------
  result <- matched[, .(
    REG,
    ARR_ADEP_ADES,
    DEP_ADEP_ADES,
    TAT_REGION_FLAG,
    ARR_BLOCK_TIME,
    ARR_SCHED_TIME,
    DEP_BLOCK_TIME,
    DEP_SCHED_TIME,
    TAT_ACTUAL,       # actual turnaround in minutes
    TAT_SCHED         # scheduled turnaround in minutes
  )]
  
  setorder(result, REG, ARR_BLOCK_TIME)
  
  return(result)
}


# =============================================================================
# Example usage
# =============================================================================
if (FALSE) {
  
  library(tidyverse)   # for downstream analysis after matching
  
  # Load airport data (one file per airport)
  raw <- readRDS("data/EGLL_movements.rds")   # or read_csv / fread etc.
  
  # Run matching
  turnarounds <- match_turnarounds(
    df            = raw,
    tat_eur_eur   = 120L,
    tat_eur_intl  = 120L,
    tat_intl_eur  = 120L,
    tat_intl_intl = 270L
  )
  
  # Quick look
  glimpse(turnarounds)
  
  # Derive delay metrics (downstream, outside the function)
  turnarounds <- turnarounds |>
    mutate(
      ARR_DELAY   = as.numeric(difftime(ARR_BLOCK_TIME, ARR_SCHED_TIME, units = "mins")),
      DEP_DELAY   = as.numeric(difftime(DEP_BLOCK_TIME, DEP_SCHED_TIME, units = "mins")),
      TAT_DELTA   = TAT_ACTUAL - TAT_SCHED   # positive = longer than planned
    )
  
  # Summary statistics by region flag
  turnarounds |>
    group_by(TAT_REGION_FLAG) |>
    summarise(
      n             = n(),
      mean_tat_act  = mean(TAT_ACTUAL, na.rm = TRUE),
      mean_tat_sched= mean(TAT_SCHED,  na.rm = TRUE),
      mean_arr_delay= mean(ARR_DELAY,  na.rm = TRUE),
      mean_dep_delay= mean(DEP_DELAY,  na.rm = TRUE),
      .groups = "drop"
    )
}
