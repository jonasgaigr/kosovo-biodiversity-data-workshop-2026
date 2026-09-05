# run_test.R
library(rgbif)
library(tidyverse)
library(sf)
library(leaflet)
library(leaflet.extras)
library(CoordinateCleaner)

print("Mocking data...")
raw_data <- tibble(
  decimalLongitude = c(21.1633, 20.9, 0, 21.0),
  decimalLatitude = c(42.6629, 42.5, 0, 42.6),
  countryCode = c("XK", "XK", "XK", "XK"),
  species = c("Ciconia ciconia", "Canis lupus", "Ursus arctos", "Felis silvestris"),
  class = c("Aves", "Mammalia", "Mammalia", "Mammalia"),
  speciesKey = c(1, 2, 3, 4),
  taxonKey = c(1, 2, 3, 4),
  vernacularName = c("White Stork", "Wolf", "Brown Bear", "Wildcat"),
  eventDate = c("2023-05-01", "2023-06-15", "2023-07-20", "2023-08-10"),
  basisOfRecord = c("HUMAN_OBSERVATION", "MACHINE_OBSERVATION", "HUMAN_OBSERVATION", "HUMAN_OBSERVATION")
)

print(paste("Fetched", nrow(raw_data), "records."))

print("Cleaning coordinates...")
cleaned_data <- clean_coordinates(
  x = raw_data,
  lon = "decimalLongitude",
  lat = "decimalLatitude",
  countries = "countryCode",
  tests = c("zeros"),
  value = "clean"
)

print(paste("Cleaned records:", nrow(cleaned_data)))

# Convert to sf
kosovo_sf <- st_as_sf(cleaned_data, 
                      coords = c("decimalLongitude", "decimalLatitude"), 
                      crs = 4326, 
                      remove = FALSE)

# Mock eu_directives_species.csv
if (!dir.exists("data")) dir.create("data")
mock_eu <- tibble(
  scientific_name = c("Ciconia ciconia", "Canis lupus", "Ursus arctos"),
  directive = c("Birds", "Habitats", "Habitats"),
  annex = c("I", "II", "II")
)
write_csv(mock_eu, "data/eu_directives_species.csv")

print("Matching taxa...")
eu_species <- read_csv("data/eu_directives_species.csv")
# Create mock backbone_matches since GBIF might be down
backbone_matches <- tibble(
  usageKey = c(1, 2, 3)
)
eu_species_matched <- eu_species %>% mutate(usageKey = backbone_matches$usageKey)

print("Subsetting data...")
subset_overall <- kosovo_sf
subset_birds <- kosovo_sf %>% filter(class == "Aves")

birds_annex_I_keys <- eu_species_matched %>% filter(directive == "Birds", annex == "I") %>% pull(usageKey)
subset_birds_annex_I <- kosovo_sf %>% filter(speciesKey %in% birds_annex_I_keys | taxonKey %in% birds_annex_I_keys)

habitats_all_keys <- eu_species_matched %>% filter(directive == "Habitats") %>% pull(usageKey)
subset_habitats_all <- kosovo_sf %>% filter(speciesKey %in% habitats_all_keys | taxonKey %in% habitats_all_keys)

habitats_annex_II_keys <- eu_species_matched %>% filter(directive == "Habitats", annex == "II") %>% pull(usageKey)
subset_habitats_annex_II <- kosovo_sf %>% filter(speciesKey %in% habitats_annex_II_keys | taxonKey %in% habitats_annex_II_keys)

print("Exporting datasets...")
if(!dir.exists("data_exports")) dir.create("data_exports")
export_subset <- function(sf_obj, name) {
  st_write(sf_obj, paste0("data_exports/", name, ".gpkg"), append = FALSE, quiet = TRUE)
  sf_obj %>% st_drop_geometry() %>% write_csv(paste0("data_exports/", name, ".csv"))
}

export_subset(subset_overall, "kosovo_overall_biodiversity")
export_subset(subset_birds, "kosovo_birds")
export_subset(subset_birds_annex_I, "kosovo_birds_annex_I")
export_subset(subset_habitats_all, "kosovo_habitats_directive")
export_subset(subset_habitats_annex_II, "kosovo_habitats_annex_II")

print("Pipeline test successful!")

