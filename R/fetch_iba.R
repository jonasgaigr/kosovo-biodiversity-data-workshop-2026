# ==============================================================================
# R/fetch_iba.R
#
# Builds `data/kosovo_ibas.csv` and `data/kosovo_iba_species.csv` — the
# Important Bird and Biodiversity Areas (IBAs) that concern Kosovo, and the bird
# populations for which each one qualifies — from BirdLife International's
# DataZone.
#
# Run with:  Rscript R/fetch_iba.R
#
# Only needs re-running when BirdLife re-assesses the sites. Nothing in
# `pipeline.R` depends on it; `natura2000.qmd` reads the two CSVs.
#
# ------------------------------------------------------------------------------
# WHY ATTRIBUTES ONLY, AND NOT BOUNDARIES
# ------------------------------------------------------------------------------
#
# The site factsheets — name, code, area, centroid, criteria, qualifying
# populations — are public and meant to be cited. The digital boundaries are
# not: the World Database of Key Biodiversity Areas is released on request, and
# the request form carries the terms of use. Taking polygons from the map
# server behind DataZone would skip that step, so this script does not. For
# official work the boundaries should be requested by the institution that will
# use them (keybiodiversityareas.org, free for non-commercial use).
#
# Without boundaries, which sites concern Kosovo is decided on the centroid:
# inside the national boundary, or within `near_km` of it. A centroid tells you
# where a site is, not how much of it lies on either side of a border, so the
# `relation` column says which of the two it is and makes no stronger claim.
#
# ------------------------------------------------------------------------------
# WHY SERBIA
# ------------------------------------------------------------------------------
#
# BirdLife has no country record for Kosovo: `country/slug?country=kosovo`
# returns nothing, and the sites in Kosovo are held in the inventory compiled
# for Serbia (country id 271). That is where the inventory sits, not a statement
# about status.
# ==============================================================================

suppressPackageStartupMessages({
  library(sf)
})

api       <- "https://bli-prod-fd-dz-eu-bgf5eqfcf2bmgtdn.a02.azurefd.net"
country   <- 271          # the inventory that holds the sites in Kosovo
near_km   <- 5            # how far outside the boundary a centroid may lie
accessed  <- format(Sys.Date())

get_json <- function(path) {
  jsonlite::fromJSON(paste0(api, path), simplifyVector = TRUE)
}

sites <- get_json(sprintf("/country/%d/sites?pageSize=500", country))
details <- do.call(rbind, lapply(sites$id, function(id) {
  d <- get_json(sprintf("/site/%d", id))
  data.frame(id = d$id, code = d$sitFinalCode, name = d$sitInternational,
             name_national = d$sitNational, area_km2 = d$area,
             lat = d$sitLat, lon = d$sitLong,
             alt_min = d$altMin, alt_max = d$altMax)
}))
details <- merge(details,
                 sites[, c("id", "slug", "ibaClassification", "kbaClassification",
                           "ibaCriteria", "yearOfLastAssessment")],
                 by = "id")

boundary <- st_read("data/kosovo_boundary.gpkg", quiet = TRUE) |>
  st_transform(4326) |>
  st_union()
pts <- st_as_sf(details, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
inside  <- lengths(st_intersects(pts, boundary)) > 0
dist_km <- as.numeric(st_distance(pts, st_boundary(boundary))) / 1000

details$relation <- ifelse(
  inside & dist_km > 1, "centroid inside Kosovo",
  ifelse(dist_km <= 1, "centroid within 1 km of the boundary",
         sprintf("centroid outside, within %d km", near_km))
)
details$centroid_to_boundary_km <- round(dist_km, 1)
ibas <- details[inside | dist_km <= near_km, ]
ibas$factsheet <- paste0("https://datazone.birdlife.org/site/factsheet/", ibas$slug)
ibas$accessed  <- accessed
ibas <- ibas[order(ibas$relation, -ibas$area_km2), ]

species <- do.call(rbind, lapply(seq_len(nrow(ibas)), function(i) {
  q <- get_json(sprintf("/site/%d/factsheet/qualifying-species", ibas$id[i]))
  p <- q$birdPopulationsMeetingIBAKBACriteria
  if (is.null(p) || !length(p)) return(NULL)
  data.frame(iba_code = ibas$code[i], iba_name = ibas$name[i],
             scientific_name = p$scientificName, common_name = p$commonName,
             season = p$season, population = p$population, units = p$units,
             population_year = p$yearOfPopulationEstimate,
             iba_criteria = vapply(p$confirmedIBACriteria, paste, "",
                                   collapse = ", "),
             accessed = accessed)
}))

write.csv(ibas[, c("code", "name", "name_national", "relation",
                   "centroid_to_boundary_km", "area_km2", "alt_min", "alt_max",
                   "ibaClassification", "kbaClassification", "ibaCriteria",
                   "yearOfLastAssessment", "lat", "lon", "factsheet", "accessed")],
          "data/kosovo_ibas.csv", row.names = FALSE, fileEncoding = "UTF-8")
write.csv(species, "data/kosovo_iba_species.csv", row.names = FALSE,
          fileEncoding = "UTF-8")

message(sprintf("%d sites, %d qualifying populations written.",
                nrow(ibas), nrow(species)))
