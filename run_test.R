# ==============================================================================
# run_test.R
#
# A smoke test for the helpers in R/functions.R — the code that turns cleaned
# occurrence records into the maps, tables and pop-ups the report publishes.
#
# Run with:  Rscript run_test.R
#
# It needs no GBIF credentials and makes no network calls, so it is safe to run
# on a fresh clone before the pipeline has ever been executed.
#
# IT WRITES NOTHING INTO THE PROJECT. Everything happens in a temporary
# directory. The previous version of this script mocked a three-row annex list
# straight over `data/eu_directives_species.csv` and four mock records over
# every file in `data_exports/`, so running the "test" destroyed the real
# dataset — and, because both are tracked, the damage was one `git commit`
# away from being permanent.
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(sf)
  library(leaflet)
  library(leaflet.extras)
})

source("R/functions.R")

# --- Tiny test harness --------------------------------------------------------

.failures <- 0L

check <- function(label, expr) {
  ok <- tryCatch(isTRUE(expr), error = function(e) {
    message("    error: ", conditionMessage(e))
    FALSE
  })
  cat(sprintf("  [%s] %s\n", if (ok) "PASS" else "FAIL", label))
  if (!ok) .failures <<- .failures + 1L
  invisible(ok)
}

builds <- function(label, expr) {
  check(label, inherits(try(force(expr), silent = TRUE),
                        c("leaflet", "htmlwidget")))
}

# --- Fixtures -----------------------------------------------------------------
#
# Four records at four distinct places, one of them repeated often enough to
# exercise the density transforms, and one carrying no Red List assessment.

set.seed(1)

occ <- dplyr::tibble(
  gbifID           = as.character(1:12),
  species          = c(rep("Ciconia ciconia", 8), "Canis lupus",
                       "Ursus arctos", "Quercus robur", "Amanita muscaria"),
  vernacularName   = c(rep("White Stork", 8), "Wolf", "Brown Bear",
                       "Pedunculate Oak", "Fly Agaric"),
  kingdom          = c(rep("Animalia", 10), "Plantae", "Fungi"),
  class            = c(rep("Aves", 8), "Mammalia", "Mammalia",
                       "Magnoliopsida", "Agaricomycetes"),
  family           = c(rep("Ciconiidae", 8), "Canidae", "Ursidae",
                       "Fagaceae", "Amanitaceae"),
  decimalLongitude = c(rep(21.1633, 8), 20.9001, 20.4, 21.0, 20.75),
  decimalLatitude  = c(rep(42.6629, 8), 42.5002, 42.3, 42.6, 42.45),
  eventDate        = c(rep("2023-05-01T08:30:00", 8), "2023-06-15",
                       "2023-07-20", "2023-08-10", "2023-09-02"),
  year             = c(rep(2023L, 12)),
  basisOfRecord    = c(rep("HUMAN_OBSERVATION", 11), "PRESERVED_SPECIMEN"),
  datasetKey       = "0d0f1b1a-0000-0000-0000-000000000000",
  municipality     = c(rep("Prishtinë / Priština", 8), "Pejë / Peć",
                       "Deçan / Dečani", "Prizreni / Prizren", NA),
  district         = "Prishtinë / Priština",
  coordinateUncertaintyInMeters = c(rep(50, 8), 7071, NA, 250, 1200),
  iucnRedListCategory = c(rep("LC", 8), "LC", "VU", NA, "NE"),
  iucnRedListStatus   = NA_character_
)

cat("\nCategorical and status encodings\n")

check("kingdom_group folds to the three mapped classes plus Other",
      identical(levels(kingdom_group(occ$kingdom)),
                names(map_palette$kingdom)) &&
        all(as.character(kingdom_group(c("Bacteria", NA))) == "Other"))

check("iucn_group keeps EX rather than folding it into NE",
      as.character(iucn_group("EX")) == "EX")

check("iucn_group sends unknown and missing codes to NE",
      all(as.character(iucn_group(c(NA, "", "banana"))) == "NE"))

check("every IUCN level has a colour and a spelled-out name",
      all(iucn_levels %in% names(map_palette$iucn)) &&
        all(iucn_levels %in% names(iucn_names)))

check("short_licence shortens the CC URIs GBIF returns",
      identical(
        short_licence(c("http://creativecommons.org/licenses/by/4.0/legalcode",
                        "http://creativecommons.org/licenses/by-nc/4.0/legalcode",
                        "http://creativecommons.org/publicdomain/zero/1.0/legalcode",
                        NA)),
        c("CC BY 4.0", "CC BY-NC 4.0", "CC0 1.0", "&mdash;")))

cat("\nDates\n")

check("fmt_date_en gives English months whatever the locale",
      fmt_date_en(as.Date("2026-09-06")) == "6 September 2026")

cat("\nDensity surfaces\n")

heat <- occurrence_heat_cells(occ)

check("heat cells collapse co-located records",
      nrow(heat) < nrow(occ) && max(heat$records) == 8)

check("heat intensity spans 0-1 and the busiest cell reaches the top",
      all(heat$intensity > 0 & heat$intensity <= 1) &&
        isTRUE(all.equal(max(heat$intensity), 1)))

check("heat intensity rises with the record count",
      {
        o <- order(heat$records)
        !is.unsorted(heat$intensity[o])
      })

# The point of the transform is that it still discriminates when counts span
# four orders of magnitude, which is the shape the real dataset has and the
# shape that defeated the previous heat map. A twelve-record fixture cannot
# show that, so the spread is checked against a realistic one.
check("a single record stays pale when the busiest cell holds thousands",
      {
        many <- dplyr::tibble(
          decimalLongitude = c(rep(21.100, 4000), 20.500),
          decimalLatitude  = c(rep(42.600, 4000), 42.400)
        )
        h <- occurrence_heat_cells(many)
        lone <- h$intensity[h$records == 1]
        busy <- h$intensity[h$records == 4000]
        lone < 0.3 && isTRUE(all.equal(busy, 1)) && busy - lone > 0.65
      })

check("a single-cell dataset does not divide by zero",
      {
        one <- occurrence_heat_cells(occ[1, ])
        nrow(one) == 1 && is.finite(one$intensity)
      })

grid <- occurrence_density_grid(occ, cell_km = 2)

check("density grid returns classed rectangles",
      !is.null(grid) &&
        all(c("lng1", "lat1", "lng2", "lat2", "records", "species",
              "class") %in% names(grid)))

check("every gridded record is accounted for exactly once",
      sum(grid$records) == nrow(occ))

check("grid classes come from the documented breaks",
      all(as.character(grid$class) %in% density_labels))

check("grid cells are square on the ground to within a per cent",
      {
        w <- (grid$lng2[1] - grid$lng1[1]) * 111.32 *
          cos(mean(occ$decimalLatitude) * pi / 180)
        h <- (grid$lat2[1] - grid$lat1[1]) * 111.32
        abs(w - h) / h < 0.01
      })

check("the density ramp has one colour per class",
      length(map_palette$density) == length(density_labels))

cat("\nPop-ups\n")

pop <- build_popup(occ)

check("one pop-up per record",  length(pop) == nrow(occ))

check("pop-ups carry exactly the six spans custom.scss labels",
      all(lengths(regmatches(pop, gregexpr("<span>", pop, fixed = TRUE))) == 6))

check("pop-ups link back to the record on GBIF",
      all(grepl("gbif.org/occurrence/", pop, fixed = TRUE)))

check("the timestamp is trimmed to a date",
      grepl(">2023-05-01<", pop[1], fixed = TRUE))

check("a missing municipality degrades to an em dash, not to 'NA'",
      grepl("&mdash;", pop[12], fixed = TRUE))

check("explorer pop-ups stay short",
      all(nchar(build_explorer_popup(occ)) < nchar(pop)))

cat("\nSummaries\n")

s <- summarise_subset(occ, "Test subset")

check("summarise_subset counts records, species and families",
      s$Records == 12 && s$Species == 5 && s$Families == 5)

cat("\nWidgets build\n")

builds("occurrence map, coloured by kingdom",
       build_occurrence_map(occ, colour_by = "kingdom"))

builds("occurrence map, coloured by Red List category",
       build_occurrence_map(occ, colour_by = "iucn"))

builds("occurrence map survives an empty subset",
       build_occurrence_map(occ[0, ], colour_by = "kingdom"))

# --- The point layer is all of the records, or none of them -------------------
#
# The layer used to fall back to a random subsample above the cap, which put a
# thinned scatter of dots on top of a density grid built from every record. A
# reader cannot tell that layer from a genuinely sparse one, so the cap now
# withholds the markers instead. These checks pin both halves of that.

marker_calls <- function(w) {
  Filter(function(c) identical(c$method, "addCircleMarkers"), w$x$calls)
}

check("every record is drawn when the subset is within the cap",
      {
        w <- build_occurrence_map(occ, max_points = nrow(occ))
        mk <- marker_calls(w)
        length(mk) == 1 && length(mk[[1]]$args[[1]]) == nrow(occ)
      })

check("no subsample is drawn above the cap: the point layer is omitted",
      {
        w  <- build_occurrence_map(occ, max_points = nrow(occ) - 1L)
        mk <- marker_calls(w)
        groups <- unlist(lapply(w$x$calls, function(c) {
          if (identical(c$method, "addLayersControl")) c$args[[2]] else NULL
        }))
        length(mk) == 0 && !("Occurrence records" %in% groups)
      })

check("the density grid starts visible when the markers are withheld",
      {
        hidden <- function(w) unlist(lapply(w$x$calls, function(c) {
          if (identical(c$method, "hideGroup")) as.character(c$args[[1]]) else NULL
        }))
        with_pts <- build_occurrence_map(occ, max_points = nrow(occ))
        no_pts   <- build_occurrence_map(occ, max_points = nrow(occ) - 1L)
        "Record density" %in% hidden(with_pts) &&
          !("Record density" %in% hidden(no_pts))
      })

check("the caption says which of the two the reader is looking at",
      {
        caption <- function(w) {
          ctl <- Filter(function(c) identical(c$method, "addControl"), w$x$calls)
          paste(vapply(ctl, function(c) as.character(c$args[[1]]), character(1)),
                collapse = " ")
        }
        grepl("All 12 records mapped", caption(
          build_occurrence_map(occ, max_points = nrow(occ))), fixed = TRUE) &&
          grepl("left off above 11 records", caption(
            build_occurrence_map(occ, max_points = nrow(occ) - 1L)), fixed = TRUE)
      })

check("the map caption can be dismissed",
      {
        w   <- build_occurrence_map(occ)
        ctl <- Filter(function(c) identical(c$method, "addControl"), w$x$calls)
        html <- paste(vapply(ctl, function(c) as.character(c$args[[1]]),
                             character(1)), collapse = " ")
        grepl("map-caption-close", html, fixed = TRUE) &&
          grepl("leaflet-control\").remove()", html, fixed = TRUE)
      })

check("the heat-layer zoom shim is attached to every map",
      {
        w <- build_occurrence_map(occ)
        any(grepl("L.HeatLayer.prototype.options.maxZoom",
                  vapply(w$jsHooks$render, function(h) h$code, character(1)),
                  fixed = TRUE))
      })

# The base layers are now GBIF's own tiles, added with `addTiles` and a URL
# template, rather than named providers from leaflet's registry. Asserting on
# the layers control instead of on the method name keeps the check about what
# actually matters -- that every base layer is an alternative in one control,
# not a stack -- and keeps it honest if the transport changes again.
check("all four base layers are offered as alternatives, not stacked",
      {
        w <- build_occurrence_map(occ)
        calls <- vapply(w$x$calls, function(c) c$method, character(1))
        tiles <- sum(calls %in% c("addTiles", "addProviderTiles"))
        ctrl  <- w$x$calls[[which(calls == "addLayersControl")[1]]]
        tiles == length(basemap_groups) &&
          sum(calls == "addLayersControl") == 1 &&
          identical(as.character(ctrl$args[[1]]), basemap_groups)
      })

check("no base layer requires an API key",
      {
        w <- build_occurrence_map(occ)
        providers <- unlist(lapply(w$x$calls, function(c) {
          if (identical(c$method, "addProviderTiles")) c$args[[1]] else NULL
        }))
        urls <- unlist(lapply(w$x$calls, function(c) {
          if (identical(c$method, "addTiles")) c$args[[1]] else NULL
        }))
        !any(grepl("^(CartoDB|Stadia|Jawg|Thunderforest|MapBox|HERE|TomTom)",
                   providers)) &&
          !any(grepl("key=|apikey|access_token|api_key", urls,
                     ignore.case = TRUE))
      })

check("the GBIF basemaps are drawn at the tile size they are served in",
      {
        w <- build_occurrence_map(occ)
        gbif <- Filter(function(c) identical(c$method, "addTiles") &&
                         grepl("tile.gbif.org", c$args[[1]], fixed = TRUE),
                       w$x$calls)
        length(gbif) == 3 &&
          all(vapply(gbif, function(c) {
            o <- c$args[[4]]
            isTRUE(o$tileSize == 512) && isTRUE(o$zoomOffset == -1)
          }, logical(1)))
      })

# A minimal municipal layer: two squares with contrasting coverage.
mun <- sf::st_sf(
  municipality    = c("Alpha / Alfa", "Beta / Beta"),
  district        = "Test district",
  area_km2        = c(100, 200),
  records         = c(500L, 20L),
  species         = c(60L, 8L),
  records_per_km2 = c(5, 0.1),
  geometry = sf::st_sfc(
    sf::st_polygon(list(rbind(c(20.5, 42.3), c(20.7, 42.3),
                              c(20.7, 42.5), c(20.5, 42.5), c(20.5, 42.3)))),
    sf::st_polygon(list(rbind(c(20.7, 42.3), c(20.9, 42.3),
                              c(20.9, 42.5), c(20.7, 42.5), c(20.7, 42.3)))),
    crs = 4326
  )
)

builds("municipal choropleth", build_municipal_map(mun))

check("choropleth classes cover the whole range, extremes included",
      {
        w <- build_municipal_map(mun)
        fills <- unlist(lapply(w$x$calls, function(c) {
          if (identical(c$method, "addPolygons")) c$args[[4]]$fillColor else NULL
        }))
        length(fills) > 0 && !any(is.na(fills))
      })

# --- Protected areas ----------------------------------------------------------
#
# A fixture standing in for the EEA layer, built here rather than read from
# disk so that the checks run on a fresh clone and make no network call. Two
# designated sites, the second overlapping the first, plus a strict-protection
# zone inside the first — the three arrangements the counting rules exist to
# handle.

pa <- sf::st_sf(
  natda_id                 = c("A", "B", "S"),
  site_name                = c("Big site", "Small site", "Strict core"),
  designation              = c("National Park", "Natural Monument",
                               "Strict Nature Reserve"),
  designation_code         = c("XK01", "XK06", "XK02"),
  designated_area_type     = c("designatedSite", "designatedSite",
                               "strictProtectionBoundary"),
  iucn_management_category = c("II", "III", "Ia"),
  reported_area_ha         = c(1000, 100, 50),
  designation_year         = c(2012L, 1985L, 1955L),
  area_km2                 = c(100, 20, 5),
  geometry = sf::st_sfc(
    # Big site: a wide box. Small site: overlaps its right-hand edge.
    # Strict core: wholly inside the big site, away from the overlap.
    sf::st_polygon(list(rbind(c(20.0, 42.0), c(21.0, 42.0),
                              c(21.0, 43.0), c(20.0, 43.0), c(20.0, 42.0)))),
    sf::st_polygon(list(rbind(c(20.9, 42.0), c(21.5, 42.0),
                              c(21.5, 43.0), c(20.9, 43.0), c(20.9, 42.0)))),
    sf::st_polygon(list(rbind(c(20.1, 42.1), c(20.3, 42.1),
                              c(20.3, 42.3), c(20.1, 42.3), c(20.1, 42.1)))),
    crs = 4326
  )
)

pa_points <- sf::st_sf(
  natda_id         = c("P1", "P2"),
  site_name        = c("Veteran oak", "Mineral spring"),
  designation      = "Natural Monument",
  reported_area_ha = c(0.05, 0.07),
  designation_year = c(2007L, 1985L),
  geometry = sf::st_sfc(sf::st_point(c(20.5, 42.5)),
                        sf::st_point(c(20.6, 42.6)), crs = 4326)
)

# Records: one in the big site only, one in the overlap (both sites), one in
# the strict core (and so also in the big site), and one outside everything.
pa_occ <- dplyr::tibble(
  gbifID           = as.character(1:4),
  species          = c("Aaa aaa", "Bbb bbb", "Ccc ccc", "Ddd ddd"),
  decimalLongitude = c(20.5, 20.95, 20.2, 19.0),
  decimalLatitude  = c(42.7, 42.5,  42.2, 41.0)
)

stamped <- assign_protected_area(pa_occ, pa)

cat("\nProtected areas\n")

check("a record outside every site is left unstamped",
      is.na(stamped$protectedArea[4]))

check("a record inside one site takes its name",
      stamped$protectedArea[1] == "Big site")

check("a record inside two sites takes the smaller one",
      stamped$protectedArea[2] == "Small site")

check("the strict-protection flag is set only inside a strict zone",
      identical(stamped$strictlyProtected, c(FALSE, FALSE, TRUE, FALSE)))

check("a strict zone does not displace the site the record is in",
      stamped$protectedArea[3] == "Big site")

check("the designation is carried alongside the site name",
      stamped$protectedAreaDesignation[2] == "Natural Monument")

pa_summary <- summarise_protected_areas(stamped, pa)

check("every polygon is returned, zones included",
      nrow(pa_summary) == 3)

check("site counts partition the records rather than double-counting them",
      sum(pa_summary$records[
        pa_summary$designated_area_type == "designatedSite"]) ==
        sum(!is.na(stamped$protectedArea)))

check("a strict zone is counted by its own geometry, not by the site stamp",
      pa_summary$records[pa_summary$site_name == "Strict core"] == 1)

check("record density per square kilometre is computed from the mapped area",
      isTRUE(all.equal(
        pa_summary$records_per_km2[pa_summary$site_name == "Big site"],
        pa_summary$records[pa_summary$site_name == "Big site"] / 100)))

builds("occurrence map with the protected-area overlay",
       build_occurrence_map(occ, protected_areas = pa,
                            protected_points = pa_points))

check("the overlay offers sites, strict zones and points as separate layers",
      {
        w <- build_occurrence_map(occ, protected_areas = pa,
                                  protected_points = pa_points)
        ctl <- Find(function(c) identical(c$method, "addLayersControl"),
                    w$x$calls)
        all(c("Protected areas", "Strict protection zones",
              "Natural monuments (point only)") %in% unlist(ctl$args[[2]]))
      })

check("the site layer is shown by default and the detail layers are not",
      {
        w <- build_occurrence_map(occ, protected_areas = pa,
                                  protected_points = pa_points)
        hidden <- unlist(lapply(w$x$calls, function(c) {
          if (identical(c$method, "hideGroup")) unlist(c$args) else NULL
        }))
        !("Protected areas" %in% hidden) &&
          all(c("Strict protection zones",
                "Natural monuments (point only)") %in% hidden)
      })

check("a map built without a protected-area layer offers no such control",
      {
        w <- build_occurrence_map(occ)
        ctl <- Find(function(c) identical(c$method, "addLayersControl"),
                    w$x$calls)
        !("Protected areas" %in% unlist(ctl$args[[2]]))
      })

# --- Result -------------------------------------------------------------------

cat("\n")
if (.failures == 0L) {
  cat("All checks passed.\n")
} else {
  cat(sprintf("%d check(s) FAILED.\n", .failures))
  quit(status = 1L)
}
