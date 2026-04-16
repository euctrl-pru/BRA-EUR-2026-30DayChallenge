# BRA-EUR-2026-30DayChallenge

workspace for the 2026 edition of the 30-Day-Challenge on data visualisation

Our goal is to -- ideally -- submit a (simple) chart every day! 

Rules of engagement:

* Read the prompt of the day.
* Pick any data you like ==> BRA-EUR comparison data
* Pick whatever tool and data you like. ==> in our case mostly ggplot2
* Share your work!
  + publish on LinkedIn or bluesky app
  + tag #30DayChartChallenge AND the day (#Day1)

And if you manage less than 30, that's fine, too! ❤️


This year's prompt for the 30-Day-Chart-Challenge are as follows:

![30-Day-Challenge-Prompts](figures/prompts-30-day-chart-challenge.webp)


## Progress

### Day 1 - "part-to-whole"

A late decision to participate - literally the night before - made it a bumpy start.
With our Day 1 contribution we want to (combine and) show the scale difference in traffic volume and the associated share of flights between both regions.
Focussing on "regional departures" (as a part of the whole traffic volume) how these shares stay constant or vary between Brazil and Europe.

Conceptual building blocks

* traffic volume ~ standard bar chart, i.e., geom_col() with respective scales to depict 'millions' of flights
* left bottom := share (Brazil) & right bottom := share (Europe)
* we used {patchwork} and its 'design' specification to combine the 3 building block plots
* provided some explanatory text using title, subtitle, and caption

![Day-01 contribution](figures/day01.png)

### Day 2 - "pictogram"

The pictogram graph uses fontaweseom to plot the aeroplane icon.
We present the share of punctuality for both regions.

Conceptual building blocks

* traffic data from study data
* the underlying chart is a waffle plot, i.e., x-y cells for which we need to build an index of "postions"
* geom_text() uses the icon as label, i.e., we "print" the icon multiple times
* rotating the icon is done per angle 180deg
* labs are placed and wrapped with ggtext::textbox_simple() and the associated parameters.
* extensive use of theme to place title, subtitle, strip bands, and payload.

![Day-02 contribution](figures/day02.png)

### Day 3 - "mosaic"

TODO - Some explanatory notes to follow 

![Day-03 contribution, mosaic](figures/day03-mosaic.jpeg)

### Day 4 - "slope"


### Day 8 - "circular"

We show the total amount of flights between the study airports in both regions.
As we were unable to make a chord diagram work, we reverted to {ggraph} using a **circular** presentation of the network nodes.
Links are depicted with *geom_arc()*.
The annotations use the standard tools provided by {ggtext} and {showtext}.

![Day-08 contribution](figures/day08-circular.png)

### Day 9 - "multi-scale"

![Day-09 ](figures/day09-lorenz.png)

### Day 10 - "pop-culture"

Thread-wise this was one of the most difficult graphics so far. It took us quite a while to come up with an idea.    
The grpah shows the share of aircraft types operated in 2025 between Brazil and Europe.
It shows the main widebody working horses ... and adds a twist in terms of the Millennium Falcon!

* barchart of shares as "pseudo-lollipop"
* aircraft icons/images integrated with geom_image()
* initial use of google fonts to underscore the theme/message

![Day-10 pop-culture](figures/day10-popculture-final.png)

### Day 12 - "flow"

For Day 12 we used a parallel-sets style flow chart to show how air transport services between Europe and Brazil in 2025 concentrate around a relatively small study network. The final chart highlights that 74% of services connect study airports at both ends, with Lisbon, Madrid, and Paris CDG leading on the European side and Guarulhos, Galeao, and Campinas absorbing the largest shares in Brazil.

Conceptual building blocks

* `geom_parallel_sets()` and `geom_parallel_sets_axes()` from `{ggforce}` for the flow geometry
* airport aggregation into study airports plus `Other European airports` / `Other Brazilian airports`
* `{ggtext}` and `{ggview}` for the final title, subtitle, caption, and output sizing
* outside airport labels with `{ggrepel}` and in-block service counts for the larger nodes

![Day-12 flow](figures/day12-flow.png)

### Day 13 - "ecosystem"

For Day 13 we interpreted airports as local ecosystems. The final candidate is a layered scatter plot where ecosystem richness is measured by the number of destinations served, average delay indicates systemic health, point size shows flight volume, point fill shows international exposure, and the outline color identifies the region. The chart suggests that the larger and more outward-facing airport ecosystems tend to sit higher on delay, while several Brazilian airports cluster in more specialized and stable niches.

Conceptual building blocks

* airport ecosystem richness from distinct destinations in the 2025 traffic data
* average delay across all flights from the binned punctuality distributions
* a layered `geom_point(shape = 21)` design to separate international exposure from region
* regime shading and labelled trend lines to support the ecosystem metaphor without overwhelming the payload

![Day-13 ecosystem](figures/day13-ecosystem.png)

### Day 16 - "simple causal graph + evidence panels"

For Day 16 we used a deliberately modest causal story: daily demand can create traffic pressure, and higher traffic pressure is consistent with more delay. The chart keeps the hypothesis and the evidence close together. A small directed graph labels which links are directly observed, which are simple proxies, and which remain interpretation; two evidence panels then show the airport-day association and the thicker delay tail on higher-pressure days.

Conceptual building blocks

* daily airport movements from `EUR-apt-tfc-2025.csv`
* binned punctuality outcomes from `PBWG-EUR-punc-2025.csv`
* a within-airport traffic pressure percentile to compare busy and quiet days fairly
* `{ggraph}` / `{tidygraph}` for the causal sketch
* `{patchwork}`, `{ggtext}`, and `{ggrepel}` for evidence panels, paragraph-style text, and selected outlier labels

![Day-16 causal evidence](figures/day16-causal-evidence-social.png)
