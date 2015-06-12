library(maptools)
library(mapproj)
library(rgeos)
library(rgdal)
library(RColorBrewer)
library(ggplot2)
library(stringr)
library(scales)
library(RColorBrewer)

###--------------------------------------------------
### Set up the Maps.
### Code borrows heavily from work by Bob Rudis:
### https://github.com/hrbrmstr/rd3albers
###--------------------------------------------------

theme_set(theme_minimal())


## for theme_map
## devtools::source_gist("33baa3a79c5cfef0f6df")

theme_map <- function(base_size=9, base_family="") {
    require(grid)
    theme_bw(base_size=base_size, base_family=base_family) %+replace%
    theme(axis.line=element_blank(),
          axis.text=element_blank(),
          axis.ticks=element_blank(),
          axis.title=element_blank(),
          panel.background=element_blank(),
          panel.border=element_blank(),
          panel.grid=element_blank(),
          panel.margin=unit(0, "lines"),
          plot.background=element_blank(),
          legend.justification = c(0,0),
          legend.position = c(0,0)
          )
}

## US Census Shapefiles
## https://www.census.gov/geo/maps-data/data/cbf/cbf_counties.html

## Converted to geojson format
## http://eric.clst.org/Stuff/USGeoJSON
## Read U.S. counties moderately-simplified GeoJSON file
us.counties <- readOGR(dsn="data/geojson/gz_2010_us_050_00_5m.json", layer="OGRGeoJSON")

# Convert it to Albers equal area
us.counties.aea <- spTransform(us.counties,
                               CRS("+proj=laea +lat_0=45 +lon_0=-100 +x_0=0 +y_0=0 +a=6370997 +b=6370997 +units=m +no_defs"))

us.counties.aea@data$id <- rownames(us.counties.aea@data)

# Extract, then rotate, shrink & move alaska (and reset projection)
# need to use state IDs via # https://www.census.gov/geo/reference/ansi_statetables.html
alaska <- us.counties.aea[us.counties.aea$STATE=="02",]
alaska <- elide(alaska, rotate=-50)
alaska <- elide(alaska, scale=max(apply(bbox(alaska), 1, diff)) / 2.3)
alaska <- elide(alaska, shift=c(-2100000, -2500000))
proj4string(alaska) <- proj4string(us.counties.aea)

# extract, then rotate & shift hawaii
hawaii <- us.counties.aea[us.counties.aea$STATE=="15",]
hawaii <- elide(hawaii, rotate=-35)
hawaii <- elide(hawaii, shift=c(5400000, -1400000))
proj4string(hawaii) <- proj4string(us.counties.aea)

# remove old states and put new ones back in; note the different order
# we're also removing puerto rico in this example but you can move it
# between texas and florida via similar methods to the ones we just used
us.counties.aea <- us.counties.aea[!us.counties.aea$STATE %in% c("02", "15", "72"),]
us.counties.aea <- rbind(us.counties.aea, alaska, hawaii)


###--------------------------------------------------
### Merge census county-level dataset with map data
###--------------------------------------------------

county.data <- read.csv("data/census/DataSet.txt", header=TRUE)
county.data$id <- as.character(county.data$fips)
ind <- county.data$fips<10000
county.data$id[ind] <- paste("0", county.data$id[ind], sep="")

library(Hmisc)
county.data$pop.dens <- with(county.data, PST045214/LND110210)
county.data$pop.dens <- cut2(county.data$pop.dens,
                             cuts = c(0, 10, 100, 1000, 10000))

county.data$pct.black <- cut2(county.data$RHI225213,
                              cuts = c(0, 2, 5, 10, 15, 20, 40, 60))


co.map <- fortify(us.counties.aea, region="GEO_ID")
co.map$id <- str_replace(co.map$id, "0500000US", "")

co.map <- merge(co.map, county.data, by="id")


###--------------------------------------------------
### Make some maps
###--------------------------------------------------

### Population Density
p <- ggplot(data=co.map, aes(x=long, y=lat, group=group))

p1 <- p + geom_map(data=co.map,
                   map = co.map,
                   aes(map_id=id,
                       x=long,
                       y=lat,
                       group=group,
                       fill=pop.dens),
                   color="white",
                   size=0.2)

p2 <- p1 + scale_fill_brewer(palette="PuBu")
p2 <- p2 + coord_equal()
p2 <- p2 + theme_map()
p2 <- p2 + theme(legend.position="right") + labs(fill="Population\nDensity, 2014")
p2




### Percent Black
p <- ggplot(data=co.map, aes(x=long, y=lat, group=group))

p1 <- p + geom_map(data=co.map,
                   map = co.map,
                   aes(map_id=id,
                       x=long,
                       y=lat,
                       group=group,
                       fill=pct.black),
                   color="white",
                   size=0.2)

p2 <- p1 + scale_fill_brewer(palette="Oranges")
p2 <- p2 + coord_equal()
p2 <- p2 + theme_map()
p2 <- p2 + theme(legend.position="right") + labs(fill="Percent\nBlack, 2013")
p2