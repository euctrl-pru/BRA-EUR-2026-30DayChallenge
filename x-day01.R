# dabbling on challenge - produce data set

# defaults -------
ggplot2::theme_set(ggplot2::theme_minimal())

# get European data
# ------- helpers
source("~/RProjects/BRA-EUR-2026-30DayChallenge/R/rqutils-zip.R")

check_zip_content("/Users/rainerkoelle/RProjects/__DATA//NM-flight-table/", "NM-flt-2025.zip")

nm_flt <- read_zip_content(
  "/Users/rainerkoelle/RProjects/__DATA//NM-flight-table/"
  , "NM-flt-2025.zip") |> dplyr::bind_rows()

check_ectrl_ms_apt_icao <- function(
    icao_vec
    ,icao_pattern = "^(BI|E.|L.|UD|UG|GM|UK|GC)"){
  
  check_vec <- grepl(pattern = icao_pattern, x = icao_vec)
  
  return(check_vec)
}

check_bra_apt_icao <- function(
     icao_vec
    ,icao_pattern = "^S[B|D|I|J|N|S|W]"){
  check_vec <- grepl(pattern = icao_pattern, x = icao_vec)
  return(check_vec)
}

adep_ades_daio_2025 <- nm_flt |> 
  dplyr::select(DATE = LOBT, ADEP, ADES) |> 
  dplyr::mutate(YEAR = lubridate::year(DATE)) |> 
  dplyr::group_by(YEAR, ADEP, ADES) |> 
  dplyr::reframe(
    # ----------- daily movements & DAIO
    FLTS = dplyr::n()
  )

#adep_ades_daio_2025 |> arrow::write_parquet("EUR-adep-ades-2025.parquet")

adep_ades_daio_2025 <-adep_ades_daio_2025 |> dplyr::arrange(dplyr::desc(FLTS))
adep_ades_daio_2025 <- adep_ades_daio_2025 |> 
  dplyr::mutate(DAIO = dplyr::case_when(
      check_ectrl_ms_apt_icao(ADEP) & !check_ectrl_ms_apt_icao(ADES)   ~ "D"
    ,!check_ectrl_ms_apt_icao(ADEP) &  check_ectrl_ms_apt_icao(ADES)   ~"A"
    , check_ectrl_ms_apt_icao(ADEP) &  check_ectrl_ms_apt_icao(ADES)   ~ "I"
    ,!check_ectrl_ms_apt_icao(ADEP) & !check_ectrl_ms_apt_icao(ADES)   ~ "O"
    ,.default = NA
  ))

# study airports and names ====================================================
bra_apts <- c("SBGR","SBGL","SBRJ","SBCF","SBBR","SBSV","SBKP","SBSP","SBCT","SBPA","SBRF","SBEG")
eur_apts <- c("EGLL","EGKK","EHAM","EDDF","EDDM","LSZH","LFPG","LEMD","LEBL","LPPT","LTFM","LGAV") 


annual_daio <- adep_ades_daio_2025 |> 
  dplyr::mutate(REGION  = "EUR") |> 
  dplyr::group_by(REGION, YEAR, DAIO) |> 
  dplyr::reframe(FLTS = sum(FLTS)) |> 
  dplyr::mutate(SHARE = FLTS / sum(FLTS))

# simple bar chart - annual DAIO
p1_eur <- annual_daio |> 
  ggplot() + 
    geom_col(aes(x = "EUR", y = FLTS, fill = DAIO), position = position_stack()) + 
    facet_wrap(vars(REGION)) +
    labs(x = NULL)

conns <- adep_ades_daio_2025 |> 
  dplyr::filter(DAIO == "D") |>    # filter all departures
  dplyr::mutate(
    ADEP_EUR = dplyr::case_when(
      !(ADEP %in% eur_apts) ~ "EUR"
      ,  ADEP %in% eur_apts  ~ "EUR12"
      , .default = NA
    )
    ,ADES_BRA = dplyr::case_when(
      check_bra_apt_icao(ADES) & !(ADES %in% bra_apts) ~ "BRA"
      ,check_bra_apt_icao(ADES) &  (ADES %in% bra_apts) ~ "BRA12"
      ,.default = "Intl."
    )
  ) |> dplyr::mutate(CONN = paste0(ADEP_EUR,"-", ADES_BRA))

conns_breakdown <- conns |> 
  dplyr::mutate(REGION = "EUR") |> 
  dplyr::group_by(REGION, YEAR, CONN) |> 
  reframe(DEPS = sum(FLTS)) |> 
  dplyr::mutate(SHARE = DEPS / sum(DEPS)) 

p2_eur <- conns_breakdown |> 
  ggplot() + 
  geom_col(aes(x ="EUR", y = SHARE, fill = CONN))+
  labs(x = NULL)

conns_eur_bra <- conns |> 
  dplyr::filter(grepl("^BRA", ADES_BRA)) |>  # get only BRA connections
  dplyr::mutate(REGION = "EUR") |> 
  dplyr::group_by(REGION, YEAR, CONN) |> 
  reframe(DEPS = sum(FLTS)) |> 
  dplyr::mutate(SHARE = DEPS / sum(DEPS))

p3_eur <- conns_eur_bra |> 
  ggplot() +
  geom_col(aes(x = "EUR", y = SHARE, fill = CONN))+
  labs(x = NULL)


p1_eur / p2_eur / p3_eur


# patchwork - design layout

design <- "#AAAA#
           BBBCCC"
p1_eur + p2_eur + p3_eur +
  plot_layout(design = design)
