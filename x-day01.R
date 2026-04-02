# dabbling on challenge - produce data set

# defaults -------
ggplot2::theme_set(ggplot2::theme_minimal())

# study airports and names --------------------------
bra_apts <- c("SBGR","SBGL","SBRJ","SBCF","SBBR","SBSV","SBKP","SBSP","SBCT","SBPA","SBRF","SBEG")
eur_apts <- c("EGLL","EGKK","EHAM","EDDF","EDDM","LSZH","LFPG","LEMD","LEBL","LPPT","LTFM","LGAV") 


# get European data -----------------------------------------------------
source("~/RProjects/BRA-EUR-2026-30DayChallenge/R/rqutils-zip.R")
check_zip_content("/Users/rainerkoelle/RProjects/__DATA//NM-flight-table/", "NM-flt-2025.zip")

nm_flt <- read_zip_content(
  "/Users/rainerkoelle/RProjects/__DATA//NM-flight-table/"
  , "NM-flt-2025.zip") |> dplyr::bind_rows()

# get Brazilian data
# Bene provided "all mvts"
bra_flt <- arrow::read_parquet("totalbr.parquet")
bra_flt <- bra_flt |> 
  dplyr::select(DATE = dt_dia, ADEP = co_addep, ADES = co_addes) |> 
  dplyr::mutate(YEAR = lubridate::year(DATE)) |> filter(YEAR %in% c(2025))

# --------------------- helper functions ---------------------------------
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


# ---------------------- prep Brazil data ---------------------------------
adep_ades_daio_bra_2025 <- bra_flt |> 
  dplyr::mutate(YEAR = lubridate::year(DATE)) |> 
  dplyr::group_by(YEAR, ADEP, ADES) |> 
  dplyr::reframe(
    # ----------- daily movements & DAIO
    FLTS = dplyr::n()
  )

#adep_ades_daio_bra_2025 |> arrow::write_parquet("BRA-adep-ades-2025.parquet")

# ---------------------- prep European data -------------------------------
adep_ades_daio_2025 <- nm_flt |> 
  dplyr::select(DATE = LOBT, ADEP, ADES) |> 
  dplyr::mutate(YEAR = lubridate::year(DATE)) |> 
  dplyr::group_by(YEAR, ADEP, ADES) |> 
  dplyr::reframe(
    # ----------- daily movements & DAIO
    FLTS = dplyr::n()
  )

#adep_ades_daio_2025 |> arrow::write_parquet("EUR-adep-ades-2025.parquet")

# ----------------- make DAIO -----------------------------------------------
# Brazil
adep_ades_daio_bra_2025 <- adep_ades_daio_bra_2025 |> 
  dplyr::arrange(dplyr::desc(FLTS))

adep_ades_daio_bra_2025 <- adep_ades_daio_bra_2025 |> 
  dplyr::mutate(DAIO = dplyr::case_when(
      check_bra_apt_icao(ADEP) & !check_bra_apt_icao(ADES)   ~ "D"
    ,!check_bra_apt_icao(ADEP) &  check_bra_apt_icao(ADES)   ~"A"
    , check_bra_apt_icao(ADEP) &  check_bra_apt_icao(ADES)   ~ "I"
    ,!check_bra_apt_icao(ADEP) & !check_bra_apt_icao(ADES)   ~ "O"
    ,.default = NA
  ))


# Europe
adep_ades_daio_2025 <-adep_ades_daio_2025 |> dplyr::arrange(dplyr::desc(FLTS))
adep_ades_daio_2025 <- adep_ades_daio_2025 |> 
  dplyr::mutate(DAIO = dplyr::case_when(
      check_ectrl_ms_apt_icao(ADEP) & !check_ectrl_ms_apt_icao(ADES)   ~ "D"
    ,!check_ectrl_ms_apt_icao(ADEP) &  check_ectrl_ms_apt_icao(ADES)   ~"A"
    , check_ectrl_ms_apt_icao(ADEP) &  check_ectrl_ms_apt_icao(ADES)   ~ "I"
    ,!check_ectrl_ms_apt_icao(ADEP) & !check_ectrl_ms_apt_icao(ADES)   ~ "O"
    ,.default = NA
  ))

# ------------- summarise annual DAIO -------------------------------------
aggregate_annual_daio <- function(df){
  df_agg <- df |> 
    dplyr::group_by(REGION, YEAR, DAIO) |> 
    dplyr::reframe(FLTS = sum(FLTS)) |> 
    dplyr::mutate(SHARE = FLTS / sum(FLTS))
  return(df)
}

annual_daio_bra <- adep_ades_daio_bra_2025 |> 
  dplyr::mutate(REGION = "BRA") |> 
  aggregate_annual_daio()

annual_daio <- adep_ades_daio_2025 |> 
  dplyr::mutate(REGION  = "EUR") |> 
  aggregate_annual_daio()
  

# simple bar chart - annual DAIO -----------------------------------------
plot_bar_simple <- function(df){
  
  # User-defined legend labels
  custom_labels <- c(A = "arrivals", D = "departures"
                     , I = "intra-regional", O = "overflights")
  
  p <- df |> 
  ggplot() + 
    geom_col(aes(x = "", y = FLTS, fill = DAIO), position = position_stack()) + 
    scale_y_continuous(
      labels = label_number(scale = 1e-6, suffix = "M")
      ) +
    scale_fill_discrete(
      labels = custom_labels
      ,palette = "Set2") +
    facet_wrap(vars(REGION)) +
    labs(x = NULL, y = NULL, fill = NULL
       #  , subtitle = "Regional air traffic"
       ) +
    theme( legend.position = c(0.25, 0.8)
          ,legend.key.size = unit(0.3, "cm"))
  return(p)
}

p1_bra <- annual_daio_bra |> plot_bar_simple() 
p1_eur <- annual_daio |> plot_bar_simple()

p1_bra + p1_eur

# DAIO facetted to show scale of traffic
p1 <- annual_daio_bra |> dplyr::bind_rows(annual_daio) |> 
  plot_bar_simple()
p1

# look at connections, i.e. regional departures ------------------------------
# Brazil ------------
conns_bra <- adep_ades_daio_bra_2025 |> 
  dplyr::filter(DAIO == "D") |>    # filter all departures
  dplyr::mutate(
    ADEP_BRA = dplyr::case_when(
       !(ADEP %in% bra_apts) ~ "BRA"
      ,  ADEP %in% bra_apts  ~ "BRA12"
      , .default = NA
    )
    ,ADES_EUR = dplyr::case_when(
       check_ectrl_ms_apt_icao(ADES) & !(ADES %in% eur_apts) ~ "EUR"
      ,check_ectrl_ms_apt_icao(ADES) &  (ADES %in% eur_apts) ~ "EUR12"
      ,.default = "Intl."
    )
  ) |> dplyr::mutate(CONN = paste0(ADEP_BRA,"-", ADES_EUR))

conns_breakdown_bra <- conns_bra |> 
  dplyr::mutate(REGION = "BRA") |> 
  dplyr::group_by(REGION, YEAR, CONN) |> 
  reframe(DEPS = sum(FLTS)) |> 
  dplyr::mutate(SHARE = DEPS / sum(DEPS)) 

# EUR --------------
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

# viz -----------
plot_regional_bar <- function(breakdown, region = ""){
  p <- breakdown |> 
    ggplot() + 
      geom_col(aes(x = {{ region }}, y = SHARE, fill = CONN)) +
      scale_y_continuous(labels = scales::percent) +
      labs(x = NULL)
  return(p)
}

p2_bra <- conns_breakdown_bra |> plot_regional_bar("BRA")
p2_eur <- conns_breakdown     |> plot_regional_bar("EUR")
 
p2_bra + p2_eur

# regional interconnectivity --------------------------------------------
# BRA ----------
conns_bra_eur <- conns_bra |> 
  dplyr::filter(grepl("^EUR", ADES_EUR)) |>  # get only EUR connections
  dplyr::mutate(REGION = "BRA") |> 
  dplyr::group_by(REGION, YEAR, CONN) |> 
  reframe(DEPS = sum(FLTS)) |> 
  dplyr::mutate(SHARE = DEPS / sum(DEPS))

# EUR ---------
conns_eur_bra <- conns |> 
  dplyr::filter(grepl("^BRA", ADES_BRA)) |>  # get only BRA connections
  dplyr::mutate(REGION = "EUR") |> 
  dplyr::group_by(REGION, YEAR, CONN) |> 
  reframe(DEPS = sum(FLTS)) |> 
  dplyr::mutate(SHARE = DEPS / sum(DEPS))

# plots ------
plot_region_to_region <- function(conns_reg_reg){
  
  conns_reg_reg <- conns_reg_reg |> 
     dplyr::mutate(LABEL = CONN) |>
     dplyr::arrange(desc(CONN))  # Reverse order to match stacking
  
  p <- conns_reg_reg |> 
    ggplot(aes(x = "", y = SHARE)) +
    geom_col(aes(fill = CONN)) +
    
    geom_text(aes(label = LABEL), position = position_stack(vjust = 0.5), size = unit(3, "mm")) +
    
    guides(fill = "none") +
    
    scale_y_continuous(labels = scales::percent) +
    labs(x = NULL, y = NULL, fill = NULL)
  return(p)
}

plot_region_to_region2 <- function(conns_reg_reg, min_share_for_label = 0.05){
  
  conns_reg_reg <- conns_reg_reg |> 
    dplyr::arrange(desc(CONN)) |>  # Arrange FIRST
    dplyr::mutate(
      LABEL = CONN, # ifelse(SHARE >= min_share_for_label, as.character(CONN), ""),
      y_pos = cumsum(SHARE) - SHARE/2  # THEN calculate positions
    )
  
  p <- conns_reg_reg |> 
    ggplot(aes(x = "", y = SHARE)) +
    geom_col(aes(fill = CONN), width = 0.5) +
    ggrepel::geom_text_repel(
      aes(x = 1, y = y_pos, label = LABEL),
      size = unit(3, "mm"),
      direction = "y",
      nudge_x = 0.3,
      segment.size = 0.3,
      min.segment.length = 0,
      hjust = 0
    ) +
    guides(fill = "none") +
    scale_y_continuous(labels = scales::percent) +
    scale_x_discrete(expand = expansion(add = c(0.5, 1.5))) +
    labs(x = NULL, y = NULL)
  return(p)
}

p3_bra <- conns_bra_eur |> plot_region_to_region2()

p3_eur <- conns_eur_bra |> plot_region_to_region2()

p3_bra + p3_eur  


p1_bra / p2_bra / p3_bra
p1_eur / p2_eur / p3_eur


# patchwork - design layout

design <- "#AA#
           BBCC"

p_bra <- p2_bra + p3_bra
p_eur <- p2_eur + p3_eur

#p1_eur + p2_eur + p3_eur +
#p1 + p2_eur + p3_eur +
p1 + p_bra + p_eur +
  plot_layout(design = design)

design <- "#AAA#
           BB#CC"
p1 + (p2_bra + p3_bra) + (p3_eur + p2_eur) +
  plot_layout(design = design)

p1/(p3_bra + p3_eur)


design <- "#A#
           BAC"
day01 <- p1 + 
  (p3_bra + scale_fill_brewer(palette = "Greens") + labs(subtitle = "Brazil (BRA)")
   ) + 
  (p3_eur + scale_fill_brewer(palette = "Blues") + labs(subtitle = "Europe (EUR)")
   ) +
  plot_layout(design = design) + 
  plot_annotation(
    title = 'Comparison of Inter-Regional Traffic between Brazil and Europe and its share',
    subtitle = 'The comparison study will focus on 12 airports within each region. The center plot shows the volume of regional traffic. Looking at \nthe inter-regional connection, we see about 70% of traffic between the study airports \nBRA-EUR refers to traffic between the regions and to airport that are not part of the study. Traffic between the study airports is labelled as BRA12 or EUR12. \nPlease not that regional traffic to the study airport, e.g. BRA12-EUR, is inverted on the European side.'
    ,caption = 'DECEA Performance Section & EUROCONTROL PRU | data: provided by groups'
  )
day01

ggsave("day01.png", day01, width = 12, height = 8, dpi = 300, bg = "white")
