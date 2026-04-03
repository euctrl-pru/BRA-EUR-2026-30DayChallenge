library(ggplot2)
library(dplyr)

cats <- c("Very early", "Early", "On time", "Late", "Very late")
#cats_rev <- rev(cats)

# Inferring numbers from the report

bra_arr <- c(23,32,22,10,13)
bra_dep <- c(2,23,40,18,17)

eur_arr <- c(12,20,22,16,30)
eur_dep <- c(3,10,28,22,37)

# Build the "proportions" matrix

build_matrix <- function(arr, dep) {
  outer(arr, dep) / sum(arr)
}

BRA <- build_matrix(bra_arr, bra_dep)
EUR <- build_matrix(eur_arr, eur_dep)

# Make it a workable df

build_df <- function(mat, region){
  expand.grid(arrival = cats, departure = cats) %>%
    mutate(value = as.vector(mat),
           region = region)
}

df <- bind_rows(
  build_df(BRA, "BRAZIL"),
  build_df(EUR, "EUROPE")
) %>%
  mutate(
    arrival = factor(arrival, levels = cats),
    departure = factor(departure, levels = cats)
  )

# plot (mosaic style)

ggplot(df, aes(x = departure, y = arrival, fill = value)) +
  geom_tile(color = "white") +
  geom_text(aes(label = paste0(round(value*1,1), "%")), size = 2) +
  facet_wrap(~region) +
  scale_fill_gradient(low = "cyan", high = "cyan4") +
  labs(
    title = "Arrival vs Departure Delay Patterns: Brazil vs Europe",
    #subtitle = "Source: Independent distribution based on observed punctuality profiles (2024)",
    caption = "Source: DECEA-EUROCONTROL Operational Comparison of ANS Performance (2024)",
    x = "Departures",
    y = "Arrivals",
    fill = "Flights %"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 30, hjust = 1),
    plot.caption = element_text(hjust = 1.5, size = 5)
  )
