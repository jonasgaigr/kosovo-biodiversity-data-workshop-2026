# ------------------------------------------------------------------------------
# R/functions.R
#
# Shared helper functions for the Kosovo GBIF biodiversity analysis.
#
# This file is sourced by BOTH `pipeline.R` (data preparation) and `index.qmd`
# (reporting), so that the mapping and summary logic is defined exactly once.
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
  library(sf)
})

# Null-coalescing helper -------------------------------------------------------
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

#' Print a timestamped progress message
say <- function(...) {
  cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n", sep = "")
  utils::flush.console()
}

#' Format an integer with thousands separators
fmt_int <- function(x) formatC(x, format = "d", big.mark = ",")

# ------------------------------------------------------------------------------
# Kosovo reference boundary
# ------------------------------------------------------------------------------

#' Build (and cache) a national boundary polygon for Kosovo
#'
#' This polygon serves two purposes:
#'   1. It is the reference layer for the country-coordinate mismatch test in
#'      `CoordinateCleaner::clean_coordinates()`.
#'   2. It is drawn as a context outline on the Leaflet maps.
#'
#' IMPORTANT: Natural Earth records Kosovo with `iso_a3 == "-99"` (that is, no
#' assigned ISO 3166-1 alpha-3 code), and CoordinateCleaner's built-in country
#' reference therefore contains no usable code for Kosovo. Running the
#' `"countries"` test against the default reference flags 100 per cent of Kosovo
#' records as country-coordinate mismatches and silently returns an empty
#' dataset. We therefore construct a bespoke reference here and stamp it with
#' the code used in the occurrence data, so that the test does what it is
#' intended to do.
#'
#' @param iso3 Code attached to the polygon; must match the value placed in the
#'   occurrence data's country column.
#' @param cache_path Optional GeoPackage path used to cache the boundary.
#' @return An `sf` polygon with a single `iso_a3` column, in EPSG:4326.
kosovo_boundary <- function(iso3 = "XKX", cache_path = "data/kosovo_boundary.gpkg") {

  if (!is.null(cache_path) && file.exists(cache_path)) {
    return(sf::st_read(cache_path, quiet = TRUE))
  }

  if (!requireNamespace("rnaturalearth", quietly = TRUE)) {
    stop("Package 'rnaturalearth' is required to build the Kosovo boundary.")
  }

  world <- rnaturalearth::ne_countries(scale = "medium", returnclass = "sf")

  # Kosovo carries no ISO code in Natural Earth; it is identified by adm0_a3.
  kos <- world[!is.na(world$adm0_a3) & world$adm0_a3 == "KOS", ]

  if (nrow(kos) == 0) {
    stop("Could not locate the Kosovo polygon in the Natural Earth dataset.")
  }

  boundary <- sf::st_sf(
    iso_a3   = iso3,
    geometry = sf::st_geometry(kos)
  ) |>
    sf::st_make_valid() |>
    sf::st_transform(4326)

  if (!is.null(cache_path)) {
    dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
    sf::st_write(boundary, cache_path, append = FALSE, quiet = TRUE)
  }

  boundary
}

# ------------------------------------------------------------------------------
# Vernacular names
# ------------------------------------------------------------------------------

#' Retrieve English vernacular names for a set of GBIF species keys
#'
#' The GBIF SIMPLE_CSV download format does NOT include a `vernacularName`
#' column, so common names must be fetched separately from the GBIF species API.
#'
#' GBIF returns every vernacular name any publisher has ever supplied, in no
#' particular order, so taking the first English entry produces poor results
#' (for example "American War Bird" for *Aquila chrysaetos*). We instead take
#' the most frequently supplied English name, which reliably recovers the
#' standard common name ("Golden Eagle").
#'
#' Results are cached on disk, misses included, so that re-runs are effectively
#' instantaneous and the GBIF API is not queried repeatedly.
#'
#' @param species_keys Integer vector of GBIF species keys.
#' @param cache_path CSV file used to persist the lookup between runs.
#' @param language Three-letter language code (GBIF uses ISO 639-3).
#' @param max_lookups Maximum number of new keys to query in this run.
#' @param verbose Print progress messages.
#' @return A tibble with columns `speciesKey` and `vernacularName`.
fetch_vernacular_names <- function(species_keys,
                                   cache_path  = "data/vernacular_cache.csv",
                                   language    = "eng",
                                   max_lookups = Inf,
                                   verbose     = TRUE) {

  species_keys <- unique(stats::na.omit(as.integer(species_keys)))

  cache <- if (file.exists(cache_path)) {
    readr::read_csv(
      cache_path,
      show_col_types = FALSE,
      col_types = readr::cols(
        speciesKey     = readr::col_integer(),
        vernacularName = readr::col_character()
      )
    )
  } else {
    dplyr::tibble(speciesKey = integer(), vernacularName = character())
  }

  missing_keys <- setdiff(species_keys, cache$speciesKey)

  if (length(missing_keys) > max_lookups) {
    if (verbose) {
      say("Limiting vernacular lookups to ", fmt_int(max_lookups),
          " of ", fmt_int(length(missing_keys)), " outstanding taxa.")
    }
    missing_keys <- missing_keys[seq_len(max_lookups)]
  }

  if (length(missing_keys) > 0) {
    if (verbose) {
      say("Fetching vernacular names for ", fmt_int(length(missing_keys)),
          " taxa from GBIF ...")
    }

    fetched <- vector("list", length(missing_keys))

    for (i in seq_along(missing_keys)) {
      k  <- missing_keys[i]
      nm <- NA_character_

      res <- try(
        rgbif::name_usage(key = k, data = "vernacularNames", limit = 1000)$data,
        silent = TRUE
      )

      if (!inherits(res, "try-error") && !is.null(res) && nrow(res) > 0 &&
          all(c("language", "vernacularName") %in% names(res))) {

        eng <- res |>
          dplyr::filter(
            !is.na(.data$language),
            tolower(.data$language) == language,
            !is.na(.data$vernacularName)
          ) |>
          dplyr::mutate(nm = trimws(.data$vernacularName)) |>
          dplyr::filter(nzchar(.data$nm)) |>
          # Publishers frequently mis-tag the language of their vernacular
          # names, so GBIF returns Ukrainian, Greek and Russian names labelled
          # "eng". Requiring Latin script discards those without discarding
          # legitimate English names, which never need other alphabets.
          dplyr::filter(grepl("^[A-Za-z0-9 .,'()/-]+$", .data$nm))

        if (nrow(eng) > 0) {
          # The most frequently published name wins; ties broken alphabetically.
          nm <- eng |>
            dplyr::count(nm_lower = tolower(.data$nm), name = "n") |>
            dplyr::arrange(dplyr::desc(.data$n), .data$nm_lower) |>
            dplyr::slice_head(n = 1) |>
            dplyr::pull(.data$nm_lower) |>
            tools::toTitleCase()
        }
      }

      # NA is cached deliberately, to record that the taxon has been checked.
      fetched[[i]] <- dplyr::tibble(speciesKey = k, vernacularName = nm)

      if (verbose && i %% 250 == 0) {
        say("  ... ", fmt_int(i), " / ", fmt_int(length(missing_keys)))
      }
    }

    cache <- dplyr::bind_rows(cache, dplyr::bind_rows(fetched)) |>
      dplyr::distinct(.data$speciesKey, .keep_all = TRUE)

    dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
    readr::write_csv(cache, cache_path)
  }

  dplyr::filter(cache, .data$speciesKey %in% species_keys)
}

# ------------------------------------------------------------------------------
# Summary statistics
# ------------------------------------------------------------------------------

#' Summarise a single occurrence subset
#'
#' @param x An `sf` occurrence data frame.
#' @param label Human-readable name for the subset.
#' @return A one-row tibble of summary statistics.
summarise_subset <- function(x, label) {

  d <- if (inherits(x, "sf")) sf::st_drop_geometry(x) else x

  n_species <- if ("species" %in% names(d)) {
    dplyr::n_distinct(d$species[!is.na(d$species) & nzchar(d$species)])
  } else {
    NA_integer_
  }

  years <- if ("year" %in% names(d)) suppressWarnings(as.integer(d$year)) else integer()
  years <- years[!is.na(years) & years > 1500 &
                   years <= as.integer(format(Sys.Date(), "%Y"))]

  dplyr::tibble(
    Dataset            = label,
    Records            = nrow(d),
    Species            = n_species,
    Families           = if ("family" %in% names(d)) {
                            dplyr::n_distinct(d$family[!is.na(d$family) & nzchar(d$family)])
                          } else NA_integer_,
    `First year`       = if (length(years)) min(years) else NA_integer_,
    `Most recent year` = if (length(years)) max(years) else NA_integer_,
    `Source datasets`  = if ("datasetKey" %in% names(d)) {
                            dplyr::n_distinct(d$datasetKey[!is.na(d$datasetKey)])
                          } else NA_integer_
  )
}

# ------------------------------------------------------------------------------
# Leaflet mapping
# ------------------------------------------------------------------------------

#' Build the HTML popup text for occurrence records
#'
#' The popup markup is deliberately terse and carries no inline styling: the
#' string produced here is repeated once per marker, so every byte is
#' multiplied by many thousands. Presentation lives in `custom.scss` under the
#' `.occ-popup` class instead, which keeps the rendered page a fraction of the
#' size it would otherwise be.
#'
#' @param d A data frame of occurrence records.
#' @return A character vector of HTML popup strings.
build_popup <- function(d) {

  pick <- function(col, transform = identity) {
    if (col %in% names(d)) {
      v <- as.character(d[[col]])
      v[is.na(v) | !nzchar(v)] <- "&mdash;"
      transform(v)
    } else {
      rep("&mdash;", nrow(d))
    }
  }

  paste0(
    "<div class='occ-popup'><i>", pick("species"), "</i>",
    "<b>", pick("vernacularName"), "</b>",
    "<span>Date</span>", pick("eventDate"),
    "<span>Basis</span>", pick("basisOfRecord", function(v) gsub("_", " ", v)),
    "<span>Family</span>", pick("family"),
    "</div>"
  )
}

#' Build a standard interactive occurrence map
#'
#' Produces a Leaflet map with a toggleable heatmap layer, a clustered point
#' layer with informative popups, switchable base maps, and the Kosovo national
#' boundary for context.
#'
#' For performance the clustered point layer is capped at `max_points` records.
#' The heatmap always uses every record, because it carries no popup payload and
#' is therefore cheap. Where sampling occurs the map caption records the fact,
#' so that the reader is never misled about what is displayed.
#'
#' @param x An `sf` occurrence data frame (or plain data frame carrying
#'   `decimalLongitude` / `decimalLatitude`).
#' @param boundary Optional `sf` polygon drawn as a context outline.
#' @param colour Fill colour for the point markers.
#' @param max_points Maximum number of individual markers to render.
#' @param seed Random seed, so that any subsample is reproducible.
#' @return A `leaflet` htmlwidget.
build_occurrence_map <- function(x,
                                 boundary   = NULL,
                                 colour     = "#1b6ca8",
                                 max_points = 5000,
                                 seed       = 42) {

  stopifnot(requireNamespace("leaflet", quietly = TRUE))
  stopifnot(requireNamespace("leaflet.extras", quietly = TRUE))

  d <- if (inherits(x, "sf")) sf::st_drop_geometry(x) else as.data.frame(x)

  # Recover coordinates from the geometry if the columns were dropped.
  if (!all(c("decimalLongitude", "decimalLatitude") %in% names(d)) &&
      inherits(x, "sf")) {
    xy <- sf::st_coordinates(x)
    d$decimalLongitude <- xy[, 1]
    d$decimalLatitude  <- xy[, 2]
  }

  d <- d[!is.na(d$decimalLongitude) & !is.na(d$decimalLatitude), , drop = FALSE]

  m <- leaflet::leaflet(options = leaflet::leafletOptions(minZoom = 6)) |>
    leaflet::addProviderTiles(leaflet::providers$CartoDB.Positron,
                              group = "Light basemap") |>
    leaflet::addProviderTiles(leaflet::providers$Esri.WorldImagery,
                              group = "Satellite imagery") |>
    leaflet::addProviderTiles(leaflet::providers$OpenTopoMap,
                              group = "Topographic")

  if (!is.null(boundary)) {
    m <- leaflet::addPolygons(
      m, data = boundary,
      fill = FALSE, color = "#333333", weight = 2,
      opacity = 0.8, dashArray = "4,4",
      group = "Kosovo boundary"
    )
  }

  if (nrow(d) == 0) {
    return(
      m |>
        leaflet::setView(lng = 20.9, lat = 42.58, zoom = 8) |>
        leaflet::addControl(
          "<strong>No records available for this selection.</strong>",
          position = "topright"
        )
    )
  }

  # Heatmap: derived from every record, but collapsed onto a ~11 m grid and
  # weighted by the number of records falling on each cell. This is visually
  # identical to plotting every point and typically cuts the payload by an
  # order of magnitude, because occurrence data is heavily co-located.
  heat <- stats::aggregate(
    list(intensity = rep(1L, nrow(d))),
    by = list(
      lng = round(d$decimalLongitude, 4),
      lat = round(d$decimalLatitude, 4)
    ),
    FUN = sum
  )

  # Point layer: capped for browser performance, sampled reproducibly.
  sampled <- nrow(d) > max_points
  pts <- if (sampled) {
    set.seed(seed)
    d[sample.int(nrow(d), max_points), , drop = FALSE]
  } else {
    d
  }

  overlay_groups <- c("Occurrence records", "Heatmap")
  if (!is.null(boundary)) overlay_groups <- c(overlay_groups, "Kosovo boundary")

  m <- m |>
    leaflet.extras::addHeatmap(
      data = heat, lng = ~lng, lat = ~lat, intensity = ~intensity,
      blur = 18, radius = 10, minOpacity = 0.25,
      group = "Heatmap"
    ) |>
    leaflet::addCircleMarkers(
      data = pts,
      lng = ~decimalLongitude, lat = ~decimalLatitude,
      radius = 5, weight = 1, color = "#ffffff", opacity = 0.9,
      fillColor = colour, fillOpacity = 0.85,
      popup = build_popup(pts),
      clusterOptions = leaflet::markerClusterOptions(
        showCoverageOnHover     = FALSE,
        spiderfyOnMaxZoom       = TRUE,
        disableClusteringAtZoom = 14
      ),
      group = "Occurrence records"
    ) |>
    leaflet::addLayersControl(
      baseGroups    = c("Light basemap", "Satellite imagery", "Topographic"),
      overlayGroups = overlay_groups,
      options       = leaflet::layersControlOptions(collapsed = FALSE)
    ) |>
    leaflet::hideGroup("Heatmap") |>
    leaflet::addScaleBar(
      position = "bottomleft",
      options  = leaflet::scaleBarOptions(imperial = FALSE)
    ) |>
    leaflet.extras::addFullscreenControl(position = "topleft")

  caption <- if (sampled) {
    sprintf(
      paste0("%s records mapped. The point layer shows a random sample of %s ",
             "records for browser performance; the heatmap and the ",
             "downloadable files use all records."),
      fmt_int(nrow(d)), fmt_int(max_points)
    )
  } else {
    sprintf("%s records mapped.", fmt_int(nrow(d)))
  }

  m |>
    leaflet::addControl(
      html = paste0(
        "<div style='background:rgba(255,255,255,.88);padding:4px 8px;",
        "border-radius:4px;font-size:11px;color:#333;max-width:320px'>",
        caption, "</div>"
      ),
      position = "bottomright"
    ) |>
    leaflet::fitBounds(
      lng1 = min(d$decimalLongitude), lat1 = min(d$decimalLatitude),
      lng2 = max(d$decimalLongitude), lat2 = max(d$decimalLatitude)
    )
}
