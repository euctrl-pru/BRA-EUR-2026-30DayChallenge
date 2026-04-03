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
