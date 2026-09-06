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

#' Format a date in English, whatever the machine's locale
#'
#' `format(x, "%B")` reads month names from `LC_TIME`, so on a Czech or German
#' workstation the report would render "06 září 2026" in the middle of English
#' prose. The month names are therefore supplied rather than looked up, which
#' also makes the rendered site byte-identical across contributors' machines.
#'
#' @param x A Date or POSIXct.
#' @param time Append the time of day.
#' @return A character vector like "6 September 2026".
fmt_date_en <- function(x, time = FALSE) {
  months_en <- c("January", "February", "March", "April", "May", "June",
                 "July", "August", "September", "October", "November",
                 "December")
  out <- sprintf("%d %s %s",
                 as.integer(format(x, "%d")),
                 months_en[as.integer(format(x, "%m"))],
                 format(x, "%Y"))
  if (time) out <- paste0(out, ", ", format(x, "%H:%M"))
  out
}

# ------------------------------------------------------------------------------
# Kosovo reference boundary
# ------------------------------------------------------------------------------

#' Download (and cache) the GADM administrative geography for Kosovo
#'
#' One GeoPackage holds all three levels — the country, its 7 districts and its
#' 30 municipalities — as GADM digitised them, and the levels tile each other
#' exactly: the union of the municipalities is the national polygon, to the
#' square metre. Both `kosovo_boundary()` and `kosovo_municipalities()`
#' therefore read from this single file rather than from separate sources that
#' would not quite agree along the border.
#'
#' @param cache_path Where to keep the downloaded GeoPackage.
#' @param url Source archive (GADM 4.1).
#' @param verbose Print progress messages.
#' @return The local path to the GeoPackage.
gadm_kosovo <- function(cache_path = "data/gadm41_XKO.gpkg",
                        url = "https://geodata.ucdavis.edu/gadm/gadm4.1/gpkg/gadm41_XKO.gpkg",
                        verbose = TRUE) {

  if (file.exists(cache_path)) return(cache_path)

  if (verbose) say("Downloading GADM administrative boundaries for Kosovo ...")

  dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)

  tmp <- paste0(cache_path, ".part")
  utils::download.file(url, tmp, mode = "wb", quiet = TRUE)

  # Only adopt the file once the download has completed, so an interrupted run
  # cannot leave a truncated GeoPackage behind that later runs would trust.
  file.rename(tmp, cache_path)

  cache_path
}

#' Build (and cache) a national boundary polygon for Kosovo
#'
#' This polygon serves two purposes:
#'   1. It is the reference layer for the country-coordinate mismatch test in
#'      `CoordinateCleaner::clean_coordinates()`.
#'   2. It is drawn as a context outline on the Leaflet maps.
#'
#' The source is GADM level 0, for two reasons. It is precise — 1,210 vertices
#' against the 72 of the Natural Earth 1:50m polygon used previously, which
#' departed from the true border by as much as 4.7 km. And it is the *same*
#' polygon GBIF used to select these records in the first place: the download
#' predicate is `pred("gadm", "XKO")`. Screening records against a different
#' outline than the one that selected them invites a class of country-mismatch
#' flags that say nothing about the data and everything about two datasets
#' disagreeing at the border.
#'
#' IMPORTANT: Natural Earth records Kosovo with `iso_a3 == "-99"` (that is, no
#' assigned ISO 3166-1 alpha-3 code), and CoordinateCleaner's built-in country
#' reference therefore contains no usable code for Kosovo. Running the
#' `"countries"` test against the default reference flags 100 per cent of
#' Kosovo records as country-coordinate mismatches and silently returns an
#' empty dataset. We therefore supply a bespoke reference here and stamp it
#' with the code used in the occurrence data, so that the test does what it is
#' intended to do.
#'
#' @param iso3 Code attached to the polygon; must match the value placed in the
#'   occurrence data's country column.
#' @param cache_path Optional GeoPackage path used to cache the boundary.
#' @param gadm_path Cache path for the source GADM archive.
#' @return An `sf` polygon with `iso_a3` and `source` columns, in EPSG:4326.
kosovo_boundary <- function(iso3 = "XKX",
                            cache_path = "data/kosovo_boundary.gpkg",
                            gadm_path  = "data/gadm41_XKO.gpkg") {

  if (!is.null(cache_path) && file.exists(cache_path)) {
    return(sf::st_read(cache_path, quiet = TRUE))
  }

  geom <- try(
    sf::st_geometry(sf::st_read(gadm_kosovo(cache_path = gadm_path),
                                layer = "ADM_ADM_0", quiet = TRUE)),
    silent = TRUE
  )

  src <- "GADM 4.1 level 0"

  if (inherits(geom, "try-error")) {
    # Falling back keeps the pipeline runnable offline, but the coarser outline
    # is a materially different reference, so it is both warned about and
    # recorded in the layer — the report states which boundary was used rather
    # than leaving the reader to guess.
    warning("Could not fetch the GADM boundary; falling back to the coarser ",
            "Natural Earth 1:50m outline.", call. = FALSE)

    if (!requireNamespace("rnaturalearth", quietly = TRUE)) {
      stop("Package 'rnaturalearth' is required for the fallback boundary.",
           call. = FALSE)
    }

    world <- rnaturalearth::ne_countries(scale = "medium", returnclass = "sf")

    # Kosovo carries no ISO code in Natural Earth; it is identified by adm0_a3.
    kos <- world[!is.na(world$adm0_a3) & world$adm0_a3 == "KOS", ]

    if (nrow(kos) == 0) {
      stop("Could not locate the Kosovo polygon in the Natural Earth dataset.",
           call. = FALSE)
    }

    geom <- sf::st_geometry(kos)
    src  <- "Natural Earth 1:50m"
  }

  boundary <- sf::st_sf(iso_a3 = iso3, source = src, geometry = geom) |>
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
# GBIF web-service helpers
# ------------------------------------------------------------------------------
#
# Several attributes the conservation sector needs are not carried in a GBIF
# SIMPLE_CSV download and have to be fetched from the registry and species
# APIs: IUCN Red List categories, dataset titles and publishing organisations.
# Each is a per-key lookup over hundreds or thousands of keys, so requests are
# issued concurrently and every answer -- misses included -- is cached on disk.
# A second run of the pipeline therefore makes no network calls at all.

.gbif_user_agent <- paste0(
  "kosovo-biodiversity-data-workshop/1.0 ",
  "(+https://github.com/jonasgaigr/kosovo-biodiversity-data-workshop-2026) R/",
  getRversion()
)

#' Fetch many JSON documents concurrently
#'
#' A thin wrapper over curl's multi interface. Requests that fail, or return a
#' non-200 status, yield `NULL` rather than an error, because a missing answer
#' is a legitimate outcome here: GBIF returns 404 for a taxon that has never
#' been assessed by the IUCN, and that is information rather than a failure.
#'
#' @param urls Character vector of URLs.
#' @param concurrency Simultaneous connections. Deliberately modest; GBIF asks
#'   that its public API is used considerately.
#' @param chunk_size Number of handles queued at once.
#' @param verbose Print progress.
#' @return A list of parsed JSON documents, `NULL` where the request failed.
gbif_fetch_json <- function(urls, concurrency = 6, chunk_size = 250,
                            verbose = TRUE) {

  stopifnot(requireNamespace("curl", quietly = TRUE),
            requireNamespace("jsonlite", quietly = TRUE))

  out <- vector("list", length(urls))
  if (length(urls) == 0) return(out)

  chunks <- split(seq_along(urls), ceiling(seq_along(urls) / chunk_size))

  for (ch in chunks) {

    pool <- curl::new_pool(total_con = concurrency, host_con = concurrency)

    for (i in ch) {
      local({
        idx <- i
        h <- curl::new_handle(url = urls[idx], useragent = .gbif_user_agent,
                              timeout = 30, connecttimeout = 15)
        curl::multi_add(
          h,
          done = function(res) {
            if (isTRUE(res$status_code == 200)) {
              out[[idx]] <<- tryCatch(
                jsonlite::fromJSON(rawToChar(res$content), simplifyVector = TRUE),
                error = function(e) NULL
              )
            }
          },
          fail = function(msg) invisible(NULL),
          pool = pool
        )
      })
    }

    curl::multi_run(pool = pool)

    if (verbose) say("  ... ", fmt_int(max(ch)), " / ", fmt_int(length(urls)))
  }

  out
}

#' Retrieve IUCN Red List categories for a set of GBIF species keys
#'
#' Adopted from the GBIF Viewer, which makes the Red List category its primary
#' filter. The reasoning is sound: the EU annexes say what is *legally
#' protected*, the Red List says what is *at risk of extinction*, and the two
#' overlap only partly. A screening tool needs both.
#'
#' GBIF publishes the assessment against its backbone taxonomy at
#' `/species/{key}/iucnRedListCategory`, returning 404 for taxa that have never
#' been assessed. Misses are cached alongside hits so unassessed taxa are not
#' re-queried on every run.
#'
#' @param species_keys Integer vector of GBIF species keys.
#' @param cache_path CSV used to persist the lookup between runs.
#' @param max_lookups Maximum number of new keys to resolve in this run.
#' @param verbose Print progress messages.
#' @return A tibble with `speciesKey`, `iucnRedListCategory` (short code) and
#'   `iucnRedListStatus` (the category spelled out).
fetch_iucn_categories <- function(species_keys,
                                  cache_path  = "data/iucn_cache.csv",
                                  max_lookups = Inf,
                                  verbose     = TRUE) {

  species_keys <- unique(stats::na.omit(as.integer(species_keys)))

  cache <- if (file.exists(cache_path)) {
    readr::read_csv(cache_path, show_col_types = FALSE,
                    col_types = readr::cols(
                      speciesKey          = readr::col_integer(),
                      iucnRedListCategory = readr::col_character(),
                      iucnRedListStatus   = readr::col_character()
                    ))
  } else {
    dplyr::tibble(speciesKey = integer(), iucnRedListCategory = character(),
                  iucnRedListStatus = character())
  }

  missing_keys <- setdiff(species_keys, cache$speciesKey)

  if (length(missing_keys) > max_lookups) {
    if (verbose) {
      say("Limiting IUCN lookups to ", fmt_int(max_lookups), " of ",
          fmt_int(length(missing_keys)), " outstanding taxa.")
    }
    missing_keys <- missing_keys[seq_len(max_lookups)]
  }

  if (length(missing_keys) > 0) {

    if (verbose) {
      say("Fetching IUCN Red List categories for ",
          fmt_int(length(missing_keys)), " taxa from GBIF ...")
    }

    res <- gbif_fetch_json(
      sprintf("https://api.gbif.org/v1/species/%d/iucnRedListCategory",
              missing_keys),
      verbose = verbose
    )

    pick <- function(r, nm) {
      v <- if (is.null(r)) NULL else r[[nm]]
      if (is.null(v) || length(v) == 0) NA_character_ else as.character(v)[1]
    }

    fetched <- dplyr::tibble(
      speciesKey          = missing_keys,
      iucnRedListCategory = vapply(res, pick, character(1), "code"),
      iucnRedListStatus   = vapply(res, function(r) {
        v <- pick(r, "category")
        if (is.na(v)) NA_character_ else
          tools::toTitleCase(tolower(gsub("_", " ", v)))
      }, character(1))
    )

    cache <- dplyr::bind_rows(cache, fetched) |>
      dplyr::distinct(.data$speciesKey, .keep_all = TRUE)

    dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
    readr::write_csv(cache, cache_path)
  }

  dplyr::filter(cache, .data$speciesKey %in% species_keys)
}

#' Retrieve dataset titles and publishing organisations for GBIF dataset keys
#'
#' Adopted from the GBIF Viewer's `Get_list_of_datasets_and_publishers.R`. A
#' GBIF download aggregates records from many independent publishers, and
#' crediting them is a condition of use rather than a courtesy. Resolving the
#' keys turns an opaque list of UUIDs into an attribution table a reader can
#' act on.
#'
#' @param dataset_keys Character vector of GBIF dataset UUIDs.
#' @param cache_path CSV used to persist the lookup between runs.
#' @param verbose Print progress messages.
#' @return A tibble of dataset key, title, DOI, licence, publisher and
#'   publisher key.
fetch_dataset_registry <- function(dataset_keys,
                                   cache_path = "data/dataset_registry.csv",
                                   verbose    = TRUE) {

  dataset_keys <- unique(stats::na.omit(as.character(dataset_keys)))
  dataset_keys <- dataset_keys[nzchar(dataset_keys)]

  cache <- if (file.exists(cache_path)) {
    readr::read_csv(cache_path, show_col_types = FALSE,
                    col_types = readr::cols(.default = readr::col_character()))
  } else {
    dplyr::tibble(datasetKey = character(), datasetTitle = character(),
                  datasetDOI = character(), datasetLicense = character(),
                  publisherKey = character(), publisher = character())
  }

  missing_keys <- setdiff(dataset_keys, cache$datasetKey)

  if (length(missing_keys) > 0) {

    if (verbose) {
      say("Fetching registry metadata for ", fmt_int(length(missing_keys)),
          " GBIF datasets ...")
    }

    ds <- gbif_fetch_json(
      sprintf("https://api.gbif.org/v1/dataset/%s", missing_keys),
      verbose = verbose
    )

    field <- function(x, nm) vapply(x, function(r) {
      v <- if (is.null(r)) NULL else r[[nm]]
      if (is.null(v) || length(v) == 0) NA_character_ else as.character(v)[1]
    }, character(1))

    pub_keys <- field(ds, "publishingOrganizationKey")
    uniq_pub <- unique(stats::na.omit(pub_keys))

    if (verbose && length(uniq_pub)) {
      say("Fetching ", fmt_int(length(uniq_pub)), " publishing organisations ...")
    }

    orgs <- gbif_fetch_json(
      sprintf("https://api.gbif.org/v1/organization/%s", uniq_pub),
      verbose = verbose
    )
    pub_names <- stats::setNames(field(orgs, "title"), uniq_pub)

    fetched <- dplyr::tibble(
      datasetKey     = missing_keys,
      datasetTitle   = field(ds, "title"),
      datasetDOI     = field(ds, "doi"),
      datasetLicense = field(ds, "license"),
      publisherKey   = pub_keys,
      publisher      = unname(pub_names[pub_keys])
    )

    cache <- dplyr::bind_rows(cache, fetched) |>
      dplyr::distinct(.data$datasetKey, .keep_all = TRUE)

    dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
    readr::write_csv(cache, cache_path)
  }

  dplyr::filter(cache, .data$datasetKey %in% dataset_keys)
}

# ------------------------------------------------------------------------------
# Administrative geography
# ------------------------------------------------------------------------------

#' Label a GADM district in both official languages
#'
#' GADM records Kosovo's seven districts under a single name each, mostly the
#' Serbian form and in one case an adjectival one ("Pećki"). Districts are named
#' after their principal town, so the bilingual forms are simply those towns'
#' names; they are given explicitly rather than derived, because the derivation
#' would be fragile for the sake of seven fixed strings.
#'
#' @param x Character vector of GADM `NAME_1` values.
#' @return The matching "Albanian / Serbian" labels, unchanged where no match.
kosovo_district_label <- function(x) {
  rules <- list(
    c("akovica",   "Gjakovë / Đakovica"),
    c("Gnjilane",  "Gjilan / Gnjilane"),
    c("Mitrovica", "Mitrovicë / Kosovska Mitrovica"),
    c("Pe",        "Pejë / Peć"),
    c("Pristina",  "Prishtinë / Priština"),
    c("Prizren",   "Prizren"),
    c("evac",      "Ferizaj / Uroševac")
  )
  out <- as.character(x)
  for (r in rules) out[grepl(r[1], x, fixed = TRUE)] <- r[2]
  out
}

#' Build (and cache) the municipal boundaries of Kosovo
#'
#' The GBIF Viewer lets a user pick an administrative unit and returns the
#' records inside it. A static site cannot run that query on demand, but it can
#' answer the question the query is really asked for -- which parts of the
#' country are covered and which are not -- by summarising the records in each
#' unit in advance. This function supplies the units: 30 municipalities (GADM
#' level 2) grouped into 7 districts (level 1).
#'
#' Names are given in both official languages of Kosovo. GADM stores the
#' Serbian form in `NAME_2` and Albanian variants in `VARNAME_2`; the label
#' built here is "Albanian / Serbian" wherever the two differ.
#'
#' @param cache_path GeoPackage used to cache the boundaries.
#' @param url Source GeoJSON (GADM 4.1, simplified).
#' @param verbose Print progress messages.
#' @return An `sf` polygon layer with `municipality`, `district` and `gid`.
kosovo_municipalities <- function(
    cache_path = "data/kosovo_municipalities.gpkg",
    gadm_path  = "data/gadm41_XKO.gpkg",
    verbose    = TRUE) {

  if (!is.null(cache_path) && file.exists(cache_path)) {
    return(sf::st_read(cache_path, quiet = TRUE))
  }

  # The full GeoPackage rather than GADM's simplified GeoJSON: it is the same
  # file `kosovo_boundary()` reads, so the municipalities tile the national
  # outline exactly instead of leaving slivers along the border where two
  # differently generalised versions of the same line disagree.
  g <- sf::st_read(gadm_kosovo(cache_path = gadm_path, verbose = verbose),
                   layer = "ADM_ADM_2", quiet = TRUE)

  # GADM's *simplified GeoJSON* runs multi-word names together
  # ("KosovskaMitrovica", "FushëKosovë"); the GeoPackage read here spaces them
  # correctly. The repair is kept as a no-op guard in case the source is
  # switched back. The Unicode classes matter: a plain `[a-z]` would miss the
  # "ë" that ends several Albanian names.
  unrun <- function(x) {
    gsub("(\\p{Ll})(\\p{Lu})", "\\1 \\2", x, perl = TRUE)
  }

  # VARNAME_2 holds pipe-separated variants; the first is the Albanian form.
  albanian <- vapply(strsplit(as.character(g$VARNAME_2), "|", fixed = TRUE),
                     function(v) if (length(v)) trimws(v[1]) else NA_character_,
                     character(1))
  albanian[albanian %in% c("NA", "")] <- NA_character_
  albanian <- unrun(albanian)

  serbian <- unrun(as.character(g$NAME_2))

  # GADM 4.1 carries no Albanian variant for three municipalities. Both
  # languages are official in Kosovo, and leaving three units labelled in one
  # language while the other twenty-seven are bilingual would be an artefact of
  # the source rather than a fact about the places, so the gaps are filled from
  # the official municipal names. Matching is on an ASCII substring so that the
  # lookup cannot be broken by how the leading diacritic is encoded.
  albanian <- dplyr::case_when(
    !is.na(albanian)          ~ albanian,
    grepl("Podujev", serbian) ~ "Podujevë",
    grepl("timlje",  serbian) ~ "Shtime",
    grepl("trpce",   serbian) ~ "Shtërpcë",
    TRUE                      ~ NA_character_
  )

  out <- sf::st_sf(
    gid          = as.character(g$GID_2),
    municipality = ifelse(is.na(albanian) | albanian == serbian,
                          serbian, paste0(albanian, " / ", serbian)),
    name_sq      = ifelse(is.na(albanian), serbian, albanian),
    name_sr      = serbian,
    district     = kosovo_district_label(unrun(as.character(g$NAME_1))),
    geometry     = sf::st_geometry(g)
  ) |>
    sf::st_make_valid() |>
    sf::st_transform(4326)

  if (!is.null(cache_path)) {
    dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
    sf::st_write(out, cache_path, append = FALSE, quiet = TRUE)
  }

  out
}

#' Attach the municipality and district each record falls in
#'
#' @param d Occurrence data frame carrying decimal coordinates.
#' @param municipalities Polygon layer from `kosovo_municipalities()`.
#' @return `d` with `municipality` and `district` columns added.
assign_municipality <- function(d, municipalities) {

  pts <- sf::st_as_sf(
    d[, c("decimalLongitude", "decimalLatitude")],
    coords = c("decimalLongitude", "decimalLatitude"), crs = 4326
  )

  # `st_intersects` rather than `st_within`: a record sitting exactly on a
  # shared boundary should be assigned rather than dropped. The duplicates that
  # creates are resolved by keeping the first match.
  hit <- suppressMessages(sf::st_intersects(pts, municipalities))
  idx <- vapply(hit, function(i) if (length(i)) i[1] else NA_integer_,
                integer(1))

  d$municipality <- municipalities$municipality[idx]
  d$district     <- municipalities$district[idx]
  d
}

#' Summarise occurrence records by municipality
#'
#' @param d Occurrence data frame carrying a `municipality` column.
#' @param municipalities Polygon layer from `kosovo_municipalities()`.
#' @return An `sf` polygon layer with record, species and area statistics.
summarise_by_municipality <- function(d, municipalities) {

  d <- if (inherits(d, "sf")) sf::st_drop_geometry(d) else d

  years <- suppressWarnings(as.integer(d$year))
  d$.year <- ifelse(!is.na(years) & years > 1500, years, NA_integer_)

  stats_tbl <- d |>
    dplyr::filter(!is.na(.data$municipality)) |>
    dplyr::group_by(municipality = .data$municipality) |>
    dplyr::summarise(
      records       = dplyr::n(),
      species       = dplyr::n_distinct(
                        .data$species[!is.na(.data$species) &
                                        nzchar(.data$species)]),
      last_year     = suppressWarnings(max(.data$.year, na.rm = TRUE)),
      .groups       = "drop"
    ) |>
    dplyr::mutate(last_year = ifelse(is.finite(.data$last_year),
                                     .data$last_year, NA_integer_))

  area_km2 <- as.numeric(
    units::set_units(sf::st_area(sf::st_transform(municipalities, 32634)),
                     "km^2")
  )

  municipalities |>
    dplyr::mutate(area_km2 = area_km2) |>
    dplyr::left_join(stats_tbl, by = "municipality") |>
    dplyr::mutate(
      records          = dplyr::coalesce(.data$records, 0L),
      species          = dplyr::coalesce(.data$species, 0L),
      records_per_km2  = .data$records / .data$area_km2
    )
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
# Cartographic palette
# ------------------------------------------------------------------------------
#
# Colour here does one of three jobs and each job gets one structure:
#
#   * identity  (which kingdom a record belongs to) -> categorical hues,
#     assigned in a fixed order and capped at three, because on a map any two
#     marks can end up side by side and three is the number that stays
#     separable under red-green colour blindness at that harder test;
#   * magnitude (how many records fall in a place) -> ONE hue, light to dark.
#     The rainbow that heat maps default to is not a magnitude scale: it has no
#     inherent order, and it spends most of its range on hues the eye reads as
#     equally "high";
#   * conservation state (IUCN Red List) -> a reserved severity scale, never
#     shown without its label.
#
# Every value below is taken from a validated palette; the categorical trio and
# the density ramp were checked for colour-blind separation and for contrast
# against the light grey basemap rather than picked by eye.

map_palette <- list(

  # Categorical -- identity. Fixed order: blue, orange, aqua.
  kingdom = c(
    Animalia = "#2a78d6",
    Plantae  = "#eb6834",
    Fungi    = "#1baf7a",
    Other    = "#898781"
  ),

  # Sequential -- magnitude. One hue, light to dark, five classes. The light
  # end still holds 2:1 contrast against the grey basemap, so the sparsest
  # class is visible rather than lost in the surface.
  density = c("#6da7ec", "#3987e5", "#256abf", "#184f95", "#0d366b"),

  # Sequential -- magnitude, continuous. Same hue, extended one step lighter at
  # the bottom: the heat surface also fades its alpha there, so near-zero is
  # meant to recede into the map.
  heat = c("#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#256abf", "#0d366b"),

  # Status -- reserved severity steps, always paired with the category label.
  # Extinct and Extinct in the Wild sit off the severity scale rather than at
  # the top of it, so they take ink rather than a status hue.
  iucn = c(
    EX = "#0b0b0b",  # Extinct
    EW = "#52514e",  # Extinct in the Wild
    CR = "#d03b3b",  # Critically Endangered
    EN = "#ec835a",  # Endangered
    VU = "#fab219",  # Vulnerable
    NT = "#898781",  # Near Threatened
    LC = "#0ca30c",  # Least Concern
    DD = "#b9b7b0",  # Data Deficient
    NE = "#b9b7b0"   # Not Evaluated
  ),

  boundary     = "#21282d",
  municipality = "#4d7c8a"
)

# Order used wherever IUCN categories are listed, most severe first.
iucn_levels <- c("EX", "EW", "CR", "EN", "VU", "NT", "LC", "DD", "NE")

# Spelled-out category names, used in legends, tables and popups so that a
# status colour never has to carry the meaning on its own.
iucn_names <- c(
  EX = "Extinct", EW = "Extinct in the Wild",
  CR = "Critically Endangered", EN = "Endangered", VU = "Vulnerable",
  NT = "Near Threatened", LC = "Least Concern", DD = "Data Deficient",
  NE = "Not evaluated"
)

# The categories that mean "threatened with extinction" in Red List terms.
iucn_threatened <- c("CR", "EN", "VU")

#' Class breaks used by every record-density display
#'
#' Occurrence counts per cell span four orders of magnitude and three quarters
#' of occupied cells hold a single record, so equal-interval classes would put
#' everything in the bottom bin. These breaks are roughly logarithmic, which is
#' the shape the data actually has, and they are round numbers a reader can
#' hold in their head.
density_breaks <- c(1, 5, 20, 100, 500, Inf)
density_labels <- c("1 &ndash; 4", "5 &ndash; 19", "20 &ndash; 99",
                    "100 &ndash; 499", "500 or more")

#' Shorten a GBIF licence URI to the name people use
#'
#' GBIF reports licences as full legal-code URLs. In a table column the URL is
#' pure noise: it is long enough to dominate the row, and the licence page is
#' one click away from the dataset anyway.
#'
#' @param x Character vector of licence URIs.
#' @return Short names such as "CC BY 4.0", or an em dash where unknown.
short_licence <- function(x) {
  v <- tolower(trimws(as.character(x)))
  out <- rep(NA_character_, length(v))

  cc0 <- grepl("publicdomain/zero", v, fixed = TRUE)
  out[cc0] <- "CC0 1.0"

  m <- regmatches(v, regexpr("licenses/[a-z-]+/[0-9.]+", v))
  has <- grepl("licenses/[a-z-]+/[0-9.]+", v)
  if (any(has)) {
    parts <- sub("^licenses/", "", m)
    code  <- toupper(sub("/.*$", "", parts))
    ver   <- sub("^.*/", "", parts)
    out[has] <- paste("CC", code, ver)
  }

  # Anything unrecognised keeps whatever GBIF supplied, rather than being
  # silently reported as "unknown".
  keep <- is.na(out) & nzchar(v)
  out[keep] <- as.character(x)[keep]
  ifelse(is.na(out), "&mdash;", out)
}

#' Collapse the kingdom column onto the three mapped classes plus "Other"
kingdom_group <- function(x) {
  x <- as.character(x)
  out <- ifelse(x %in% c("Animalia", "Plantae", "Fungi"), x, "Other")
  out[is.na(x)] <- "Other"
  factor(out, levels = names(map_palette$kingdom))
}

#' Normalise an IUCN category column to the codes used for display
iucn_group <- function(x) {
  x <- toupper(trimws(as.character(x)))
  x[is.na(x) | !nzchar(x) | !x %in% iucn_levels] <- "NE"
  factor(x, levels = iucn_levels)
}

# ------------------------------------------------------------------------------
# Density surfaces
# ------------------------------------------------------------------------------

#' Prepare weighted cells for the heat map layer
#'
#' Leaflet.heat draws each point with an alpha of `intensity / max`, clamped at
#' 1, and then colours the accumulated alpha through the gradient. Feeding it
#' raw record counts is what flattens the display: with counts running from 1 to
#' more than thirteen thousand, every occupied cell saturates at alpha 1 and the
#' surface carries no information about density at all. Two steps fix it.
#'
#' 1. Collapse records onto a fixed grid (about 110 m) and count them. This is
#'    also a large payload saving, because occurrence data is heavily
#'    co-located.
#' 2. Map those counts onto 0-1 with a log transform -- which compresses the
#'    long tail into a usable range -- followed by a power below one, which
#'    lifts the bottom of that range clear of the floor. A single record then
#'    reads as the palest class rather than as nothing, and a well-worked site
#'    reads as the darkest, with everything in between actually distinguishable.
#'
#' @param d Occurrence data frame with decimal coordinates.
#' @param digits Decimal places to round coordinates to (3 is about 110 m).
#' @param exponent Power applied to the log-scaled value; below 1 spreads the
#'   low end, above 1 compresses it.
#' @return A tibble of `lng`, `lat`, `records` and `intensity` in 0-1.
occurrence_heat_cells <- function(d, digits = 3, exponent = 0.55) {

  cells <- stats::aggregate(
    list(records = rep(1L, nrow(d))),
    by  = list(lng = round(d$decimalLongitude, digits),
               lat = round(d$decimalLatitude,  digits)),
    FUN = sum
  )

  top <- max(cells$records)

  # Rounded to three decimals: the alpha channel it drives has 256 levels, so
  # further precision is invisible and would cost roughly fifteen bytes on
  # every one of several thousand cells, on every map in the page.
  cells$intensity <- if (top <= 1) {
    rep(1, nrow(cells))
  } else {
    round((log1p(cells$records) / log1p(top))^exponent, 3)
  }

  dplyr::as_tibble(cells)
}

#' Aggregate records onto a fixed grid for the density choropleth
#'
#' The heat map is a smooth surface and deliberately has no numbers on it. This
#' is its counterpart: hard-edged cells of a stated size, classed against stated
#' breaks, with a legend and the exact counts on hover. It is the layer to read
#' when the question is "how much", and unlike a heat map it does not change
#' meaning as the reader zooms.
#'
#' The grid is built directly in longitude/latitude, with the longitude step
#' widened by 1/cos(latitude) so that cells are square on the ground. Kosovo
#' spans less than a degree and a half of latitude, over which that factor
#' varies by about two per cent, so a single step computed at the mean latitude
#' is accurate enough and lets the layer be drawn as plain rectangles — roughly
#' a quarter of the payload of an equivalent polygon layer, which matters when
#' the same grid is drawn on several maps in one page.
#'
#' @param d Occurrence data frame with decimal coordinates.
#' @param cell_km Cell size in kilometres.
#' @return A tibble of cell bounds with `records`, `species` and `class`, or
#'   `NULL` when there is nothing to grid.
occurrence_density_grid <- function(d, cell_km = 2) {

  if (nrow(d) == 0) return(NULL)

  lat0 <- mean(range(d$decimalLatitude, na.rm = TRUE))

  step_lat <- cell_km / 111.32
  step_lng <- cell_km / (111.32 * cos(lat0 * pi / 180))

  i <- floor(d$decimalLongitude / step_lng)
  j <- floor(d$decimalLatitude  / step_lat)

  tally <- dplyr::tibble(
    i = i, j = j,
    species = if ("species" %in% names(d)) d$species else NA_character_
  ) |>
    dplyr::group_by(.data$i, .data$j) |>
    dplyr::summarise(
      records = dplyr::n(),
      species = dplyr::n_distinct(.data$species[!is.na(.data$species) &
                                                  nzchar(.data$species)]),
      .groups = "drop"
    )

  if (nrow(tally) == 0) return(NULL)

  tally |>
    dplyr::mutate(
      lng1  = round(.data$i * step_lng, 5),
      lng2  = round((.data$i + 1) * step_lng, 5),
      lat1  = round(.data$j * step_lat, 5),
      lat2  = round((.data$j + 1) * step_lat, 5),
      class = cut(.data$records, breaks = density_breaks, right = FALSE,
                  labels = density_labels)
    ) |>
    dplyr::select(-"i", -"j")
}

# ------------------------------------------------------------------------------
# Leaflet mapping
# ------------------------------------------------------------------------------

#' Add the standard base layers
#'
#' None of these providers requires an API key.
#'
#' CARTO's Positron tiles, used here previously, no longer qualify: CARTO now
#' stamps "API KEY REQUIRED" across every tile served to an unauthenticated
#' client, so the light basemap arrived watermarked. Esri's World Light Gray
#' Canvas is the closest key-free equivalent -- a pale, low-chroma ground that
#' lets data colour carry the meaning. Its tiles stop at zoom 16, so
#' `maxNativeZoom` is set and Leaflet upscales beyond that rather than showing
#' blank tiles.
#'
#' @param m A leaflet map.
#' @return The map, with four base groups added.
add_basemaps <- function(m) {
  m |>
    leaflet::addProviderTiles(
      leaflet::providers$Esri.WorldGrayCanvas,
      group   = "Light basemap",
      options = leaflet::providerTileOptions(maxNativeZoom = 16, maxZoom = 19)
    ) |>
    leaflet::addProviderTiles(
      leaflet::providers$OpenStreetMap.Mapnik,
      group   = "Street map",
      options = leaflet::providerTileOptions(maxZoom = 19)
    ) |>
    leaflet::addProviderTiles(
      leaflet::providers$Esri.WorldImagery,
      group   = "Satellite imagery",
      options = leaflet::providerTileOptions(maxNativeZoom = 18, maxZoom = 19)
    ) |>
    leaflet::addProviderTiles(
      leaflet::providers$OpenTopoMap,
      group   = "Topographic",
      options = leaflet::providerTileOptions(maxNativeZoom = 17, maxZoom = 19)
    )
}

basemap_groups <- c("Light basemap", "Street map", "Satellite imagery",
                    "Topographic")

#' Draw the national outline, on a pane of its own above the fills
#'
#' The border is the one line on these maps that has to be trusted, so it is
#' not left to share the default overlay pane with the thematic fills. In
#' insertion order the 2 km density grid (78 per cent opaque) and the municipal
#' choropleth (80 per cent) are both drawn *after* the outline and cover it, so
#' the moment a reader switches on the layer they came for, the border stops
#' being visible — which reads as an imprecise border even though the geometry
#' underneath is exact.
#'
#' Leaflet's overlay pane sits at z-index 400 and the marker pane at 600. A
#' dedicated pane at 450 puts the outline above every polygon fill and still
#' below the occurrence markers, which are the subject and should stay on top.
#'
#' The geometry is passed through untouched — no simplification, no rounding.
#' It is GADM 4.1 level 0 at full resolution (1,210 vertices), the same polygon
#' GBIF used to select these records via `pred("gadm", "XKO")`, and the
#' municipal layer tiles it exactly.
#'
#' `smoothFactor = 0` is the load-bearing argument. Exact geometry in the
#' GeoPackage is only half the job: Leaflet runs its own Douglas–Peucker pass
#' over every path as it draws, in *screen pixels*, and the default tolerance
#' of 1 discards any vertex that falls within a pixel of its neighbours. At the
#' country view that is roughly 400 m on the ground, so the drawn border was a
#' generalisation of the precise one — and it re-generalised differently at
#' every zoom level, which is what makes an outline look like it is wobbling as
#' you zoom. Zero renders all 1,210 vertices at every scale.
#'
#' @param m A leaflet map.
#' @param boundary An `sf` polygon, or `NULL` to add nothing.
#' @param group Overlay group name.
#' @param weight Stroke width.
#' @param dash Dash pattern, or `NULL` for a solid line.
#' @return The map, with the outline added.
add_boundary_outline <- function(m, boundary, group = "Kosovo boundary",
                                 weight = 2, dash = NULL) {

  if (is.null(boundary)) return(m)

  m <- leaflet::addMapPane(m, "boundary", zIndex = 450)

  leaflet::addPolygons(
    m, data = boundary,
    fill = FALSE, color = map_palette$boundary,
    weight = weight, opacity = 0.9, dashArray = dash,
    smoothFactor = 0,
    # A crisp join keeps the fine detail of the GADM outline legible where the
    # border doubles back on itself, which a round join would smooth away.
    options = leaflet::pathOptions(pane = "boundary", lineJoin = "miter",
                                   lineCap = "butt", interactive = FALSE),
    group = group
  )
}

#' Add the base-layer switcher
#'
#' Every map that calls `add_basemaps()` must also call this, even when it has
#' no overlays to offer. Leaflet draws all four tile layers unless a control
#' tells it they are alternatives, and the last one added — the topographic
#' layer — would otherwise cover the light ground the data is designed for.
#'
#' `overlays` must be an empty *character vector* when a map has nothing to
#' switch, never `NULL`. `addLayersControl()` serialises `NULL` to JSON `null`,
#' and the binding's `asArray(null)` yields `[null]` — one dead checkbox
#' labelled "null" where the thematic layers should be. Coercing here keeps
#' every caller honest rather than relying on each to remember.
#'
#' @param m A leaflet map.
#' @param overlays Overlay group names, if any.
#' @return The map, with a layers control.
add_layer_switcher <- function(m, overlays = NULL) {
  overlays <- if (length(overlays)) as.character(overlays) else character(0)

  leaflet::addLayersControl(
    m,
    baseGroups    = basemap_groups,
    overlayGroups = overlays,
    options       = leaflet::layersControlOptions(collapsed = TRUE)
  )
}

#' Add the interactive tool set shared by every map
#'
#' Adopted from the GBIF Viewer, which fronts its workflow with a Leaflet.draw
#' toolbar so that a user can outline an area of interest on the map. A static
#' report cannot run a query against a drawn polygon, but the sketching and
#' measuring tools are useful in their own right when a reader is sizing up a
#' site, and the place search saves hunting for a municipality by eye.
#'
#' @param m A leaflet map.
#' @param draw Include the polygon / rectangle drawing toolbar.
#' @return The map with controls added.
add_map_tools <- function(m, draw = TRUE) {

  m <- m |>
    leaflet::addScaleBar(
      position = "bottomleft",
      options  = leaflet::scaleBarOptions(imperial = FALSE)
    ) |>
    leaflet::addMeasure(
      position            = "topleft",
      primaryLengthUnit   = "kilometers",
      secondaryLengthUnit = "meters",
      primaryAreaUnit     = "hectares",
      activeColor         = "#14556b",
      completedColor      = "#14556b"
    ) |>
    leaflet.extras::addFullscreenControl(position = "topleft") |>
    leaflet.extras::addResetMapButton() |>
    leaflet.extras::addSearchOSM(
      options = leaflet.extras::searchOptions(collapsed = TRUE,
                                              autoCollapse = TRUE,
                                              hideMarkerOnCollapse = TRUE)
    )

  if (draw) {
    m <- leaflet.extras::addDrawToolbar(
      m,
      position          = "topleft",
      polylineOptions   = leaflet.extras::drawPolylineOptions(
                            metric = TRUE, feet = FALSE, nautic = FALSE),
      polygonOptions    = leaflet.extras::drawPolygonOptions(
                            showArea = TRUE, metric = TRUE),
      rectangleOptions  = leaflet.extras::drawRectangleOptions(
                            showArea = TRUE, metric = TRUE),
      circleOptions     = FALSE,
      markerOptions     = FALSE,
      circleMarkerOptions = FALSE,
      editOptions       = leaflet.extras::editToolbarOptions(
                            edit = TRUE, remove = TRUE)
    )
  }

  leafem::addMouseCoordinates(m)
}

#' Pin the heat layer's zoom reference
#'
#' Leaflet.heat scales every intensity by `1 / 2^(maxZoom - currentZoom)`,
#' where `maxZoom` falls back to the map's own maximum -- 19 once a street or
#' satellite layer is present. At the country view that divides every value by
#' about a thousand, so the whole surface collapses onto the minimum-opacity
#' floor and renders as one flat wash. That is the single largest reason the
#' previous heat map showed no variation.
#'
#' `addHeatmap()` does not expose the option, so it is set on the layer
#' prototype instead. Instance options are created with the prototype's option
#' object as their prototype, so the change is picked up by layers that were
#' already constructed, and pinning it to a fixed zoom makes the surface mean
#' the same thing at every scale.
#'
#' @param m A leaflet map.
#' @param reference_zoom Zoom at and above which intensities are used unscaled.
#' @return The map, with the shim attached.
pin_heatmap_zoom <- function(m, reference_zoom = 11) {
  htmlwidgets::onRender(m, sprintf("
function(el, x) {
  var map = this, REF = %d;
  if (!window.L || !L.HeatLayer || !L.HeatLayer.prototype.options) { return; }

  L.HeatLayer.prototype.options.maxZoom = REF;

  // Leaflet.heat defers its draw to an animation frame but never cancels it in
  // onRemove, and Leaflet nulls the layer's _map on removal. Every map here
  // calls hideGroup('Heat map') immediately after addHeatmap, so the queued
  // frame lands on a detached layer and throws 'Cannot read properties of null
  // (reading getSize)' -- once per map, straight into the console. Guarding the
  // three entry points that dereference _map is enough to make the layer safe
  // to add and remove at any time, including before the map has a size, which
  // is the case for every tab that is not the one on top at load.
  if (!L.HeatLayer.prototype.__kosovoGuarded) {
    L.HeatLayer.prototype.__kosovoGuarded = true;

    ['_reset', '_redraw', '_animateZoom'].forEach(function(name) {
      var inner = L.HeatLayer.prototype[name];
      if (typeof inner !== 'function') { return; }
      L.HeatLayer.prototype[name] = function() {
        if (!this._map || !this._map._panes) { this._frame = null; return; }
        var s = this._map.getSize();
        if (!s || !s.x || !s.y) { this._frame = null; return; }
        return inner.apply(this, arguments);
      };
    });

    var onRemove = L.HeatLayer.prototype.onRemove;
    L.HeatLayer.prototype.onRemove = function(m) {
      if (this._frame) { L.Util.cancelAnimFrame(this._frame); this._frame = null; }
      return onRemove.apply(this, arguments);
    };
  }

  var stamp = function(layer) {
    if (layer instanceof L.HeatLayer) {
      layer.options.maxZoom = REF;
      if (map.hasLayer(layer) && layer.redraw) { layer.redraw(); }
    }
  };
  map.eachLayer(stamp);
  map.on('layeradd', function(e) { stamp(e.layer); });

  // A map built inside a hidden tab initialises at 0x0, so its layers have
  // nothing to draw onto. Quarto shows the tab long after the widget is built
  // and fires no event the widget sees, so observe the container instead and
  // invalidate once it first has a size.
  if (window.ResizeObserver) {
    var ro = new ResizeObserver(function() {
      if (el.offsetWidth > 0 && el.offsetHeight > 0) {
        map.invalidateSize();
        map.eachLayer(function(layer) {
          if (layer instanceof L.HeatLayer && layer.redraw) { layer.redraw(); }
        });
      }
    });
    ro.observe(el);
  }
}", as.integer(reference_zoom)))
}

#' Build the HTML popup text for occurrence records
#'
#' The popup markup is deliberately terse and carries no inline styling: the
#' string produced here is repeated once per marker, so every byte is
#' multiplied by many thousands. Presentation lives in `custom.scss` under the
#' `.occ-popup` class instead — including the field *labels*, which are emitted
#' by CSS from the position of each value rather than repeated in the HTML.
#' Only the values travel down the wire, which is roughly a third off the size
#' of the point layers across the page.
#'
#' The order of the `<span>` elements below is therefore load-bearing: it must
#' match the `nth-of-type` rules in `custom.scss`.
#'
#' Following the GBIF Viewer, every popup carries a link back to the record on
#' gbif.org and to the dataset that published it. That is what makes a mapped
#' dot verifiable: a reader who doubts a determination can go and look at the
#' evidence, including any photographs attached to it.
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

  link <- function(col, base, label) {
    if (!col %in% names(d)) return(rep("", nrow(d)))
    v <- as.character(d[[col]])
    ifelse(is.na(v) | !nzchar(v), "",
           paste0("<a href='", base, v, "' target='_blank' rel='noopener'>",
                  label, "</a>"))
  }

  uncertainty <- if ("coordinateUncertaintyInMeters" %in% names(d)) {
    v <- suppressWarnings(as.numeric(d$coordinateUncertaintyInMeters))
    ifelse(is.na(v), "&mdash;",
           ifelse(v >= 1000, sprintf("%.1f km", v / 1000), sprintf("%.0f m", v)))
  } else {
    rep("&mdash;", nrow(d))
  }

  iucn <- if ("iucnRedListCategory" %in% names(d)) {
    code <- as.character(d$iucnRedListCategory)
    ifelse(is.na(code) | !nzchar(code), "Not evaluated", code)
  } else {
    rep("&mdash;", nrow(d))
  }

  # Field order: date, basis, family, IUCN, place, accuracy. `custom.scss`
  # supplies the label for each position.
  paste0(
    "<div class='occ-popup'><i>", pick("species"), "</i>",
    "<b>", pick("vernacularName"), "</b>",
    # GBIF returns eventDate as a full timestamp; the time of day is noise in a
    # pop-up and nine bytes on every marker.
    "<span>", pick("eventDate", function(v) sub("T.*$", "", v)), "</span>",
    "<span>", pick("basisOfRecord", function(v) tolower(gsub("_", " ", v))),
    "</span>",
    "<span>", pick("family"), "</span>",
    "<span>", iucn, "</span>",
    "<span>", pick("municipality"), "</span>",
    "<span>", uncertainty, "</span>",
    "<em>",
    # Only the record link travels with every marker. The dataset behind a
    # record is one click further on from the GBIF record page, and every
    # contributing dataset is listed with its own link further down this
    # report, so carrying a second URL on ten thousand markers would buy very
    # little for well over a megabyte.
    link("gbifID", "https://www.gbif.org/occurrence/", "View record on GBIF"),
    "</em></div>"
  )
}

#' Build a compact popup for the linked record explorer
#'
#' The explorer shows a table beside the map, so the popup only has to identify
#' the record and offer the way through to the evidence; everything else is a
#' glance away. Keeping it short matters because the explorer embeds its
#' records twice, once for the map and once for the table.
#'
#' @param d A data frame of occurrence records.
#' @return A character vector of HTML popup strings.
build_explorer_popup <- function(d) {
  vern <- as.character(d$vernacularName)
  vern <- ifelse(is.na(vern) | !nzchar(vern), "", paste0("<b>", vern, "</b>"))
  paste0("<div class='occ-popup'><i>", d$species, "</i>", vern,
         "<em><a href='https://www.gbif.org/occurrence/", d$gbifID,
         "' target='_blank' rel='noopener'>Record</a></em></div>")
}

#' Resolve the colour encoding for the point layer
#'
#' @param d Occurrence data frame.
#' @param colour_by One of "kingdom", "iucn", or a single colour.
#' @return A list with `values`, `palette`, `title` and `labels`, or NULL for a
#'   flat colour.
occurrence_colouring <- function(d, colour_by = "kingdom") {

  if (identical(colour_by, "kingdom")) {
    v <- kingdom_group(d$kingdom)
    keep <- levels(v)[levels(v) %in% unique(as.character(v))]
    return(list(values = v, levels = keep,
                colours = unname(map_palette$kingdom[keep]),
                title = "Kingdom", labels = keep))
  }

  if (identical(colour_by, "iucn")) {
    v <- iucn_group(d$iucnRedListCategory)
    keep <- levels(v)[levels(v) %in% unique(as.character(v))]
    return(list(values = v, levels = keep,
                colours = unname(map_palette$iucn[keep]),
                title = "IUCN Red List",
                labels = sprintf("%s &mdash; %s", keep,
                                 unname(iucn_names[keep]))))
  }

  NULL
}

#' Build a standard interactive occurrence map
#'
#' Produces a Leaflet map carrying, as switchable layers: a clustered point
#' layer with linked popups, a classed record-density grid with a legend, a
#' smooth heat surface, municipal boundaries with per-unit counts, and the
#' national outline. Base maps, drawing, measuring and search tools are shared
#' with every other map in the report.
#'
#' For performance the clustered point layer is capped at `max_points` records.
#' Both density layers always use every record, because neither carries a popup
#' payload. Where sampling occurs the map caption says so, so the reader is
#' never misled about what is displayed.
#'
#' @param x An `sf` occurrence data frame (or a plain data frame carrying
#'   `decimalLongitude` / `decimalLatitude`).
#' @param boundary Optional `sf` polygon drawn as a context outline.
#' @param municipalities Optional `sf` polygons drawn as an administrative
#'   overlay, labelled with this subset's record counts.
#' @param colour_by "kingdom", "iucn", or a single colour for a flat layer.
#' @param max_points Maximum number of individual markers to render.
#' @param cell_km Cell size, in kilometres, for the density grid.
#' @param seed Random seed, so that any subsample is reproducible.
#' @return A `leaflet` htmlwidget.
build_occurrence_map <- function(x,
                                 boundary       = NULL,
                                 municipalities = NULL,
                                 colour_by      = "kingdom",
                                 max_points     = 6000,
                                 cell_km        = 2,
                                 seed           = 42) {

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
    add_basemaps()

  if (nrow(d) == 0) {
    return(
      m |>
        add_layer_switcher() |>
        leaflet::setView(lng = 20.9, lat = 42.58, zoom = 8) |>
        leaflet::addControl(
          "<strong>No records available for this selection.</strong>",
          position = "topright"
        ) |>
        add_map_tools(draw = FALSE)
    )
  }

  overlay_groups <- character()

  # --- Municipal overlay ----------------------------------------------------
  if (!is.null(municipalities)) {

    counts <- if ("municipality" %in% names(d)) {
      d |>
        dplyr::filter(!is.na(.data$municipality)) |>
        dplyr::group_by(municipality = .data$municipality) |>
        dplyr::summarise(
          records = dplyr::n(),
          species = dplyr::n_distinct(
            .data$species[!is.na(.data$species) & nzchar(.data$species)]),
          .groups = "drop"
        )
    } else {
      dplyr::tibble(municipality = character(), records = integer(),
                    species = integer())
    }

    # Drawn at full precision. Generalising the overlay was tried and dropped:
    # GADM's geometry carries no redundant vertices, so `st_simplify()` at a
    # 167 m tolerance removed 4 of 7,137 points — no saving, and any tolerance
    # large enough to matter would pull the municipal edges off the national
    # outline they are supposed to tile.
    mun <- municipalities |>
      dplyr::left_join(counts, by = "municipality") |>
      dplyr::mutate(records = dplyr::coalesce(.data$records, 0L),
                    species = dplyr::coalesce(.data$species, 0L))

    m <- leaflet::addPolygons(
      m, data = mun,
      fill = TRUE, fillColor = "#ffffff", fillOpacity = 0.01,
      color = map_palette$municipality, weight = 1, opacity = 0.75,
      # Drawn unsimplified for the same reason as the national outline: the
      # municipal edges are the same vertices as the border along the outside
      # of the country, and letting Leaflet generalise the two layers
      # independently opens visible slivers between them.
      smoothFactor = 0,
      label = ~lapply(sprintf(
        "<strong>%s</strong><br>%s records &middot; %s species<br><em>%s district</em>",
        municipality, fmt_int(records), fmt_int(species), district),
        htmltools::HTML),
      highlightOptions = leaflet::highlightOptions(
        weight = 2.5, color = map_palette$municipality, fillOpacity = 0.08,
        bringToFront = FALSE),
      group = "Municipalities"
    )
    overlay_groups <- c(overlay_groups, "Municipalities")
  }

  if (!is.null(boundary)) {
    # Solid, not dashed. A 4/4 dash drops half the vertices of a 1,210-point
    # outline out of the drawing, which is exactly the detail that makes the
    # border look approximate at the scale where it matters.
    m <- add_boundary_outline(m, boundary)
    overlay_groups <- c(overlay_groups, "Kosovo boundary")
  }

  # --- Classed density grid -------------------------------------------------
  grid <- occurrence_density_grid(d, cell_km = cell_km)

  if (!is.null(grid) && nrow(grid) > 0) {
    grid_pal <- leaflet::colorFactor(map_palette$density,
                                     levels = density_labels,
                                     na.color = "transparent")
    m <- m |>
      leaflet::addRectangles(
        data = grid,
        lng1 = ~lng1, lat1 = ~lat1, lng2 = ~lng2, lat2 = ~lat2,
        fillColor = ~grid_pal(class), fillOpacity = 0.78,
        color = "#ffffff", weight = 0.4, opacity = 0.55,
        label = ~lapply(sprintf(
          "<strong>%s records</strong><br>%s species<br><em>%s km cell</em>",
          fmt_int(records), fmt_int(species), format(cell_km)),
          htmltools::HTML),
        highlightOptions = leaflet::highlightOptions(
          weight = 2, color = map_palette$boundary, bringToFront = TRUE),
        group = "Record density"
      ) |>
      leaflet::addLegend(
        position = "bottomleft", colors = map_palette$density,
        labels = density_labels,
        title = sprintf("Records per<br>%s km cell", format(cell_km)),
        opacity = 0.85, group = "Record density"
      )
    overlay_groups <- c(overlay_groups, "Record density")
  }

  # --- Heat surface ---------------------------------------------------------
  heat <- occurrence_heat_cells(d)

  m <- leaflet.extras::addHeatmap(
    m, data = heat, lng = ~lng, lat = ~lat, intensity = ~intensity,
    blur = 14, radius = 15, max = 1, minOpacity = 0.02,
    gradient = map_palette$heat,
    group = "Heat map"
  )
  overlay_groups <- c(overlay_groups, "Heat map")

  # --- Point layer ----------------------------------------------------------
  sampled <- nrow(d) > max_points
  pts <- if (sampled) {
    set.seed(seed)
    d[sample.int(nrow(d), max_points), , drop = FALSE]
  } else {
    d
  }

  colouring <- occurrence_colouring(pts, colour_by)

  if (is.null(colouring)) {
    fill <- if (is.character(colour_by)) colour_by else map_palette$kingdom[["Animalia"]]
    pts$.fill <- fill
  } else {
    pal <- stats::setNames(colouring$colours, colouring$levels)
    pts$.fill <- unname(pal[as.character(colouring$values)])
  }

  m <- leaflet::addCircleMarkers(
    m, data = pts,
    lng = ~decimalLongitude, lat = ~decimalLatitude,
    radius = 5, weight = 1.2, color = "#ffffff", opacity = 0.9,
    fillColor = ~.fill, fillOpacity = 0.85,
    popup = build_popup(pts),
    clusterOptions = leaflet::markerClusterOptions(
      showCoverageOnHover     = FALSE,
      spiderfyOnMaxZoom       = TRUE,
      disableClusteringAtZoom = 13
    ),
    group = "Occurrence records"
  )
  overlay_groups <- c("Occurrence records", overlay_groups)

  if (!is.null(colouring)) {
    m <- leaflet::addLegend(
      m, position = "bottomright", colors = colouring$colours,
      labels = colouring$labels, title = colouring$title,
      opacity = 0.9, group = "Occurrence records"
    )
  }

  caption <- if (sampled) {
    sprintf(
      paste0("%s records mapped. The point layer shows a random sample of %s ",
             "records for browser performance; both density layers and the ",
             "downloadable files use every record."),
      fmt_int(nrow(d)), fmt_int(max_points)
    )
  } else {
    sprintf("%s records mapped.", fmt_int(nrow(d)))
  }

  m <- m |>
    add_layer_switcher(overlay_groups) |>
    leaflet::hideGroup(intersect(c("Heat map", "Record density",
                                   "Municipalities"), overlay_groups)) |>
    add_map_tools() |>
    pin_heatmap_zoom() |>
    leaflet::addControl(
      html = paste0("<div class='map-caption'>", caption, "</div>"),
      position = "bottomright"
    ) |>
    leaflet::fitBounds(
      lng1 = min(d$decimalLongitude), lat1 = min(d$decimalLatitude),
      lng2 = max(d$decimalLongitude), lat2 = max(d$decimalLatitude)
    )

  m
}

#' Build a municipal choropleth
#'
#' The static counterpart to the GBIF Viewer's administrative-unit selector.
#' Rather than letting the reader query one unit at a time, every unit is
#' summarised at once, which is the more useful view when the question is where
#' the survey gaps are.
#'
#' @param x Polygon layer from `summarise_by_municipality()`.
#' @param value Column to map: "records", "species" or "records_per_km2".
#' @param title Legend title.
#' @param boundary Optional national outline.
#' @return A `leaflet` htmlwidget.
build_municipal_map <- function(x, value = "records_per_km2",
                                title = "Records per km&sup2;",
                                boundary = NULL) {

  v <- x[[value]]

  # Quantile classes: the distribution is strongly skewed — one municipality
  # carries thirty times the coverage of the median — and equal intervals would
  # put twenty-nine of the thirty units in the lowest class. Break values are
  # rounded because a quantile boundary carries no meaning of its own and
  # "1.744" only makes the legend harder to read; `unique()` guards the case
  # where two quantiles round together.
  digits <- if (value == "records_per_km2") 1 else 0
  raw    <- stats::quantile(v, probs = seq(0, 1, length.out = 6), na.rm = TRUE)
  brks   <- round(raw, digits)

  # Rounding may pull the outer breaks inside the data, which would leave the
  # extreme values uncoloured; the ends are therefore widened rather than
  # rounded to nearest.
  brks[1]            <- floor(raw[1] * 10^digits) / 10^digits
  brks[length(brks)] <- ceiling(raw[length(raw)] * 10^digits) / 10^digits
  brks               <- unique(brks)

  if (length(brks) < 3) brks <- unique(raw)

  pal <- leaflet::colorBin(map_palette$density, domain = v, bins = brks,
                           na.color = "#e1e0d9")

  m <- leaflet::leaflet(options = leaflet::leafletOptions(minZoom = 6)) |>
    add_basemaps() |>
    leaflet::addPolygons(
      data = x,
      fillColor = ~pal(x[[value]]), fillOpacity = 0.8,
      color = "#ffffff", weight = 1, opacity = 0.9,
      smoothFactor = 0,
      label = ~lapply(sprintf(
        paste0("<strong>%s</strong><br>%s records &middot; %s species<br>",
               "%s per km&sup2; &middot; %s km&sup2;<br><em>%s district</em>"),
        municipality, fmt_int(records), fmt_int(species),
        sprintf("%.1f", records_per_km2), sprintf("%.0f", area_km2), district),
        htmltools::HTML),
      highlightOptions = leaflet::highlightOptions(
        weight = 2.5, color = map_palette$boundary, fillOpacity = 0.9,
        bringToFront = TRUE),
      group = "Survey coverage"
    ) |>
    leaflet::addLegend(
      position = "bottomright", pal = pal, values = v, title = title,
      opacity = 0.9,
      labFormat = leaflet::labelFormat(digits = digits, big.mark = ","),
      group = "Survey coverage"
    )

  overlay_groups <- "Survey coverage"

  if (!is.null(boundary)) {
    m <- add_boundary_outline(m, boundary)
    overlay_groups <- c(overlay_groups, "Kosovo boundary")
  }

  m |>
    add_layer_switcher(overlay_groups) |>
    add_map_tools(draw = FALSE) |>
    leaflet::fitBounds(
      lng1 = as.numeric(sf::st_bbox(x)$xmin),
      lat1 = as.numeric(sf::st_bbox(x)$ymin),
      lng2 = as.numeric(sf::st_bbox(x)$xmax),
      lat2 = as.numeric(sf::st_bbox(x)$ymax)
    )
}

#' Build the map half of the linked record explorer
#'
#' Takes a `crosstalk::SharedData` object so that the filter controls and the
#' table beside it drive the same selection. This is the static stand-in for
#' the GBIF Viewer's filter tab: the filtering happens in the reader's browser
#' rather than on a server, which means it costs nothing to host and keeps
#' working for as long as the page does.
#'
#' @param sd A `crosstalk::SharedData` carrying `lon`, `lat`, `.fill` and
#'   `popup` columns.
#' @param boundary Optional national outline.
#' @param legend_codes IUCN codes present in the data, for the legend.
#' @param height Map height in pixels.
#' @return A `leaflet` htmlwidget.
build_explorer_map <- function(sd, boundary = NULL, legend_codes = NULL,
                               height = 520) {

  m <- leaflet::leaflet(sd, height = height,
                        options = leaflet::leafletOptions(minZoom = 6)) |>
    add_basemaps()

  overlay_groups <- character()

  if (!is.null(boundary)) {
    m <- add_boundary_outline(m, boundary)
    overlay_groups <- c(overlay_groups, "Kosovo boundary")
  }

  # The marker layer is driven by crosstalk, so it is deliberately *not* given
  # a group: leaflet's layers control and crosstalk's filter would then both
  # own whether a record is on the map, and switching the group back on after a
  # filter re-adds every point, silently defeating the filters beside it. The
  # control offers the outline only, and the filters stay the one way records
  # are added and removed here.
  m <- leaflet::addCircleMarkers(
    m, lng = ~lon, lat = ~lat,
    radius = 5, weight = 1.2, color = "#ffffff", opacity = 0.9,
    fillColor = ~.fill, fillOpacity = 0.85,
    popup = ~popup
  )

  if (length(legend_codes)) {
    keep <- iucn_levels[iucn_levels %in% legend_codes]
    m <- leaflet::addLegend(
      m, position = "bottomright",
      colors = unname(map_palette$iucn[keep]),
      labels = sprintf("%s &mdash; %s", keep, unname(iucn_names[keep])),
      title = "IUCN Red List", opacity = 0.9)
  }

  m |>
    add_layer_switcher(overlay_groups) |>
    add_map_tools(draw = FALSE) |>
    leaflet::setView(lng = 20.9, lat = 42.58, zoom = 8)
}
