## Load the packages.
library("dplyr")
library("reshape2")
library("ggplot2")
library("gridExtra")
library("leaflet")
library("maps")
library("ggmap")
library("htmltools")
library("htmlwidgets")
library("webshot")
library("rgdal")

#----------

## Load the datasets into a list called "velib".

# Set the working directory and list the csv files in it.
setwd("./velib/data")
datasets <- list.files(pattern = "*.csv")

# Import the files into a list ("velib").
velib <- lapply(datasets, function (x) read.csv(x, sep = ";", 
                                                stringsAsFactors = FALSE))

# Give some names to the data frames into the list by using the names 
# of the files imported (but without the .csv at the end).
names(velib) <- gsub(pattern = ".csv", replacement = "", datasets)

# Check the import.
lapply(velib, head)
lapply(velib, dim)

# NA values.
lapply(velib, function (x) sum(is.na(x)))

#----------

## Plots and tables.

## Histograms.

# List the numeric variables.
numeric_cols <- c("bike_stands", "available_bike_stands", "available_bikes")

# Create a function called "histogram_function" to plot histograms.
histogram_function <- function (df, x) {
  ggplot(df, aes_string(x)) +
    geom_histogram()
}

# Call the function "histogram_function".
# for (i in seq_along(velib)) {
#   list_ggplot <- lapply(numeric_cols, histogram_function, df = velib[[i]])
#   do.call(grid.arrange, list_ggplot)
# }

## Barplots.

# List the factor variables.
factor_cols <- c("banking", "bonus", "status")

# Create a function called "barplot_function" to plot barplots.
barplot_function <- function (df, x) {
  ggplot(df, aes_string(x)) +
    geom_bar()
}

# Call the function "barplot_function".
# for (i in seq_along(velib)) {
#   list_ggplot <- lapply(factor_cols, barplot_function, df = velib[[i]])
#   do.call(grid.arrange, list_ggplot)
# }

## Tables.

# Create a function called "one_way_table" to build one-way tables.
one_way_table <- function(x) {
  cbind(count = table(x), proportion = (prop.table(table(x)) * 100) %>%
    round(., 2))
}

# Call the function "one_way_table".
# for (i in seq_along(velib)) {
#   print(names(velib[i]))
#   velib[[i]] %>%
#     select(one_of(factor_cols)) %>%
#     lapply(one_way_table) %>%
#     print()
# }

#----------

## Map the velib stations.

# Paris (Hotel de Ville)
# longitude: 48.856488
# latitude: 2.352427

# Keep only the stations "OPEN".
velib <- lapply(velib, function (x) filter(x, status == "OPEN"))

# Convert lower-case addresses to upper-case.
velib <- lapply(velib, function (x) mutate(x, address = toupper(address)))

# Create a function called "lat_long" to split the variable "position" in 
# latitude and longitude.
lat_long <- function (x) {
  x %>%
    mutate(latitude = gsub(pattern = ",.+", replacement = "", position),
           longitude = gsub(pattern = ".+,", replacement = "", position))
}

# Call the function "lat_long".
velib <- lapply(velib, lat_long)

# Compute the availability rate for each station.
velib <- lapply(velib, function (x) {
  mutate(x, availability = available_bikes / bike_stands * 100)
})

# Create a continuous palette function.
pal <- colorNumeric(palette = "Blues", domain = c(0, 100))

# Create a function called "map_stations" to map the stations.
# The radius of the circles is a function of the number of available bikes.
# The color of the circles depends on the % of available bikes.
map_stations <- function(df, x) {
  
  # Extract the last 5 characters of the names of the data frames 
  # in the list df and replace the character "h" by ":"
  # (useful to display the hour for each map).
  time_legend <- names(df[x]) %>%
    substr(start = (nchar(.) + 1) - 5, nchar(.)) %>%
    gsub(pattern = "h", replacement = ":")
  
  # Map the stations.
  leaflet(data = df[[x]]) %>% 
    setView(lng = 2.352427, lat = 48.856488, zoom = 12) %>%
    addProviderTiles("CartoDB.Positron") %>%
    addCircles(lng = ~ longitude, lat = ~ latitude,
               radius = ~ available_bikes * 5,
               color = ~ pal(availability), stroke = FALSE, fillOpacity = 0.8, 
               popup = ~ paste0(address, 
                                "<br>",  # HTML tag to add a line.
                                "Velib' disponibles : ",
                                as.character(available_bikes), 
                                " / ",
                                as.character(bike_stands))) %>%
    addLegend(position = "bottomleft", colors = NULL, labels = NULL,
              title = time_legend)
}

# Call the function "map_stations".
m <- lapply(names(velib), map_stations, df = velib)
m  # Show the maps.

# Save the maps as both html and png files.
setwd("../maps/all")
for (i in seq_along(m)) {
  saveWidget(widget = m[[i]],
             file = paste0(names(velib[i]), "_all.html"),
             selfcontained = TRUE)
  webshot(url = paste0(names(velib[i]), "_all.html"),
          file = paste0(names(velib[i]), "_all.png"),
          cliprect = "viewport")
}

#----------

## Group the stations by arrondissement (or by city if not in Paris) 
## in order to see some tendencies more easily.

# Create a function called "zip_city" to build a new column "address_short" 
# from the variable "address".
# This variable contains only the zip code and the city (e.g. 75001 PARIS).
zip_city <- function (x) {
  x %>%
    mutate(address_short = regmatches(address, gregexpr(pattern = "[0-9]{5,}.+",
                                                        address)) %>%
             unlist() %>%
             toupper() %>%
             gsub(pattern = "-", replacement = " "))
}

# Call the function "zip_city".
velib <- lapply(velib, zip_city)

# Create a function called "fix_names" to fix some mistakes 
# in the name of the cities.
fix_names <- function (x) {
  mutate(x, address_short = plyr::mapvalues(address_short,
                                            c("92100 ISSY LES MOULINEAUX",
                                              "92200 NEUILLY",
                                              "92300 LEVALLOIS",
                                              "93210 SAINT DENIS",
                                              "94130 NOGENT",
                                              "94200 IVRY",
                                              "94270 LE KREMELIN BICETRE"),
                                            c("92130 ISSY LES MOULINEAUX",
                                              "92200 NEUILLY SUR SEINE",
                                              "92300 LEVALLOIS PERRET",
                                              "93200 SAINT DENIS",
                                              "94130 NOGENT SUR MARNE",
                                              "94200 IVRY SUR SEINE",
                                              "94270 LE KREMLIN BICETRE")))
}

# Call the function "fix_names".
velib <- lapply(velib, fix_names)

# Create a data frame (with just one column) of all unique arrondissements 
# (or cities if not in Paris) for each data frame of the main list and 
# merge them into one.
unique_arrond <- lapply(velib, function (x) {
  select(x, address_short) %>%
    unique()
})

unique_arrond <- Reduce(function(df1, df2) {
  merge(df1, df2, all = TRUE, by = "address_short")}, 
  unique_arrond)

# Get the latitude and the longitude with geocode() for each arrondissement 
# (or city if not in Paris) - Internet connection needed.
geocodes <- as.character(unique_arrond$address_short) %>%
  geocode()

# Bind the geocodes with the names.
unique_arrond <- cbind(unique_arrond, geocodes)

# Create a function called "group_by_arrond" which group the velib stations 
# by arrondissement (or by city if not in Paris) and compute 
# the number of available bikes.
group_by_arrond <- function (x) {
  select(x, bike_stands, available_bike_stands, 
         available_bikes, address_short) %>%
    group_by(address_short) %>%
    summarise(bike_stands = sum(bike_stands), 
              available_bike_stands = sum(available_bike_stands),
              available_bikes = sum(available_bikes))  
}

# Call the function "group_by_arrond".
velib_grouped_by_arrond <- lapply(velib, group_by_arrond)

# Merge the result with the latitude and the longitude for each arrondissement 
# (or city if not in Paris).
velib_grouped_by_arrond <- lapply(velib_grouped_by_arrond, function (x) {
  left_join(x, unique_arrond, by = "address_short")
})

# Compute the availability rate.
velib_grouped_by_arrond <- lapply(velib_grouped_by_arrond, function (x) {
  mutate(x, availability = available_bikes / bike_stands * 100)
})

# Create a function called "map_stations_grouped_by_arrond" to map 
# the stations grouped by arrondissement (or city if not in Paris).
# The radius of the circles is a function of the number of available bikes.
# The color of the circles depends on the % of available bikes.
map_stations_grouped_by_arrond <- function(df, x) {
  
  # Extract the last 5 characters of the names of the data frames 
  # in the list df and replace the character "h" by ":" 
  # (useful to display the hour for each map).
  time_legend <- names(df[x]) %>%
    substr(start = (nchar(.) + 1) - 5, nchar(.)) %>%
    gsub(pattern = "h", replacement = ":")

  # Map the stations.    
  leaflet(data = df[[x]]) %>%
    setView(lng = 2.352427, lat = 48.856488, zoom = 12) %>%
    addProviderTiles("CartoDB.Positron") %>%
    addCircles(lng = ~ lon, lat = ~ lat,
               radius = ~ available_bikes,
               color = ~ pal(availability), stroke = FALSE, fillOpacity = 0.8, 
               popup = ~ paste0(address_short, 
                                "<br>",  # HTML tag to add a line.
                                "Velib' disponibles : ",
                                as.character(available_bikes), 
                                " / ",
                                as.character(bike_stands))) %>%
    addLegend(position = "bottomleft", colors = NULL, labels = NULL,
              title = time_legend)
}

# Call the function "map_stations_grouped_by_arrond".
m <- lapply(names(velib_grouped_by_arrond), map_stations_grouped_by_arrond, 
            df = velib_grouped_by_arrond)
m  # Show the maps.

# Save the maps as both html and png files.
setwd("../arrondissement")
for (i in seq_along(m)) {
  saveWidget(widget = m[[i]], 
             file = paste0(names(velib[i]), "_by_arrond.html"),
             selfcontained = TRUE)
  webshot(url = paste0(names(velib[i]), "_by_arrond.html"), 
          file = paste0(names(velib[i]), "_by_arrond.png"),
          cliprect = "viewport")
}

#----------

## Map the velib stations with a user-created icon.

# Load a GeoJSON file which contains the shapefiles 
# for the arrondissement of Paris.
setwd("../..")
arrond_shapefile <- readOGR("arrondissement.geojson", layer="OGRGeoJSON")

# A quick look at this object.
slotNames(arrond_shapefile)
head(arrond_shapefile@data)

# Keep only the shapefile of the 1st arrondissement.
arrond_1_shapefile <- arrond_shapefile[arrond_shapefile@data$code == "75101", ]

# Make a new icon (you have to create or download the png before).
velib_icon <- makeIcon(iconUrl = "velib_icon_175x112.png", iconWidth = 80, 
                       iconHeight = 51)

# Extract the last 5 characters of the name of the data frame selected and 
# replace the character "h" by ":" (useful to display the hour on the map).
time_legend <- names(velib[1]) %>%
  substr(start = (nchar(.) + 1) - 5, nchar(.)) %>%
  gsub(pattern = "h", replacement = ":")

# Map the stations of the 1st arrondissement with this new icon and 
# add a polygon to show the borders.
m <- leaflet(data = velib[[1]] %>% filter(address_short == "75001 PARIS")) %>%
  setView(lng = 2.338, lat = 48.8630, zoom = 15) %>%
  addProviderTiles("CartoDB.Positron") %>%
  addMarkers(lng = ~ longitude, lat = ~ latitude,
             icon = ~ velib_icon,
             popup = ~ paste0(address,
                              "<br>",  # HTML tag to add a line.
                              "Velib' disponibles : ",
                              as.character(available_bikes),
                              " / ",
                              as.character(bike_stands))) %>%
  addPolygons(data = arrond_1_shapefile, stroke = FALSE, color = "#b3c6ff", 
              fillOpacity = 0.3, smoothFactor = 0.9) %>%
  addLegend(position = "bottomleft", colors = NULL, labels = NULL,
            title = time_legend)

# Show the map.
m

# Save the map as both html and png files.
setwd("./maps/velib_icon")
saveWidget(widget = m,
           file = paste0("stations_1_arron_velib_icon.html"),
           selfcontained = TRUE)
webshot(url = "stations_1_arron_velib_icon.html",
        file = "stations_1_arron_velib_icon.png",
        cliprect = "viewport")

#----------

## Compute an indicator to cluster the stations in two groups: 
## "working" stations and "residential" station.
## This indicator is compute as: 
## the number of avalaible bikes between 10:00 am and 5:00 pm 
## divided by the number of avalaible bikes for the whole day.

# Select only the station number and the number of available bikes for each
# data frame of the list velib.
working_residential <- lapply(velib, function (x) {
  select(x, number, available_bikes)
})

# Merge the data frames of this new list into one data frame.
working_residential <- Reduce(function(df1, df2) {
  merge(df1, df2, all = TRUE, by = "number")}, 
  working_residential)

# Give some proper names to the variables (available_bikes_hh:mm).
proper_names <- names(velib) %>%
  substr(start = (nchar(.) + 1) - 6, nchar(.)) %>%
  gsub(pattern = "h", replacement = ":") %>%
  paste0("available_bikes", .)

names(working_residential) <- c("number", proper_names)

# Compute the number of available bikes between 10:00 am and 5:00 pm 
# and also the number of available bikes for the whole day.
available_bikes_10am_5pm <- as.character()

for (i in seq(10, 16)) {
  available_bikes_10am_5pm <- c(available_bikes_10am_5pm,
                                paste0("available_bikes_", i, ":00"))
  for (j in seq(15, 45, by = 15)) {
    available_bikes_10am_5pm <- c(available_bikes_10am_5pm,
                                  paste0("available_bikes_", i, ":", j))
  }
}

working_residential <- working_residential %>%
  mutate(available_bikes_10am_5pm = select(., 
                                           one_of(available_bikes_10am_5pm, 
                                                  "available_bikes_17:00")) %>% 
           rowSums(),
         available_bikes_9am_9pm = select(., contains("available_bikes")) %>% 
           rowSums())

# Compute the indicator as:
# "indicator" = "available_bikes_10am_5pm" / "available_bikes_9am_9pm"
working_residential <- working_residential %>%
  mutate(indicator = ifelse(available_bikes_9am_9pm != 0,
                            (available_bikes_10am_5pm / 
                               available_bikes_9am_9pm) %>%
                              round(2), 0))

# Remove NA values.
working_residential <- na.omit(working_residential)

# Define the threshold to choose between a "working" or a "residential" station. 
# This choice is somehow really subjective.
threshold <- quantile(working_residential$indicator,  probs = c(0.75))

# Create a new variable "indicator_w_r" using the threshold defined above.
working_residential <- working_residential %>%
  mutate(indicator_w_r = ifelse(indicator > threshold, "w", "r"))

# Join "address", "latitude", "longitude" and "bike_stands" to the data frame.
working_residential <- left_join(working_residential, velib[[1]] %>%
                                   select(number, address, 
                                          latitude, longitude, bike_stands),
                                 by = "number")

# Create a palette that maps factor levels to colors.
pal <- colorFactor(c("#00BFC4", "#F8766D"), domain = c("r", "w"))

# Map the stations: 
# "working" stations in red and "residential" stations in blue.
m <- leaflet(data = working_residential) %>%
  setView(lng = 2.352427, lat = 48.856488, zoom = 12) %>%
  addProviderTiles("CartoDB.Positron") %>%
  addCircles(lng = ~ longitude, lat = ~ latitude,
             color = ~ pal(indicator_w_r),
             stroke = FALSE, radius = 150, 
             fillOpacity = 0.6, 
             popup = ~ paste0(address,
                              "<br>",  # HTML tag to add a line.
                              "Indicateur : ",
                              as.character(indicator)))

# Show the map.
m

# Save the map as both html and png files.
setwd("../working_residential")
saveWidget(widget = m,
           file = paste0("working_residential.html"),
           selfcontained = TRUE)
webshot(url = "working_residential.html",
        file = "working_residential.png",
        cliprect = "viewport")

## Boxplots of the rate of available bikes during the day 
## by "type" of stations ("working" or "residential").
## It is easier to work with ggplot2 if data are in a long format 
## (opposed to wide format). Consequently a bit of data wrangling is required.

# Keep only the variables of interest.
working_residential_long <- working_residential %>%
  select(-indicator, -address, -latitude, -longitude,
         -available_bikes_10am_5pm, -available_bikes_9am_9pm)

# Get the rate of available bikes rather than a count. 
working_residential_long <- working_residential_long %>%
  mutate_each(funs( . / bike_stands), -number, -indicator_w_r, -bike_stands)

# Keep only the "on the hour" variables (hh:00) and convert the data frame to
# long format.
on_the_hour <- as.character()

for (i in seq(9, 21)) {
  if (i < 10) {
    on_the_hour <- c(on_the_hour, paste0("available_bikes_0", i, ":00"))
  } else {
    on_the_hour <- c(on_the_hour, paste0("available_bikes_", i, ":00"))
  }
}

working_residential_long <- working_residential_long %>%
  select(number, indicator_w_r, one_of(on_the_hour)) %>%
  melt(id = c("number", "indicator_w_r"))

# Define the labels for the hours by keeping only the five 
# last characters of the variables.
labels_time <- on_the_hour %>%
  substr(start = (nchar(.) + 1) - 5, nchar(.))

# Define a labeller for the "working" and "residential" stations.
labeller_w_r <- c(`w` = 'Stations Vélib\' "Travail"',
                  `r` = 'Stations Vélib\' "Domicile"')

# Boxplots of the number of available bikes by type of stations.
ggplot(data = working_residential_long, aes(x = variable, y = value,
                                            fill = factor(indicator_w_r))) +
  geom_boxplot() +
  facet_grid(indicator_w_r ~ ., labeller = as_labeller(labeller_w_r)) +
  scale_x_discrete(name = "", breaks = on_the_hour, labels = labels_time) +
  scale_y_continuous(name = "Taux de Vélib\' disponibles (%) \n", 
                     labels = scales::percent) +
  scale_fill_manual(values = c("#00BFC4", "#F8766D")) +
  ggtitle(expression(atop(bold("Taux de Vélib\' disponibles selon le type de stations (\"Domicile\" ou \"Travail\")"), 
                          atop(italic("Journée du mardi 26 janvier 2016"))))) +
  theme(legend.position = "none", axis.text = element_text(size = 12),
        axis.title = element_text(size = 14), 
        strip.text = element_text(size = 12),
        plot.title = element_text(size = 18))
