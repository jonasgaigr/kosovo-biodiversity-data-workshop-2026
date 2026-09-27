# ==============================================================================
# R/site_report.R
#
# Site-level reporting for a protected-area register: resolving a site,
# clipping the occurrence evidence to it, summarising that evidence, and
# drawing the static maps a printed report needs.
#
# This file is sourced by BOTH `site_reports.R` (the batch runner) and
# `reports/site_report.qmd` (the PDF template), for the same reason
# `R/functions.R` is shared between the pipeline and the national report: a
# number computed in two places will eventually be computed two ways.
#
# It builds on `R/functions.R` and does not duplicate it. The palette, the
# density class breaks, the kingdom and Red List groupings, the formatting
# helpers and the register reader all come from there.
#
# NOTHING HERE IS COUNTRY-SPECIFIC. Every path, layer name, register attribute
# and threshold arrives through the `config` list built in `site_reports.R`;
# the header of that file says what to change to point the tool at another
# country's register and another GBIF download.
#
# Two departures from `R/functions.R` are deliberate, and are argued where they
# occur rather than here:
#
#   * every metric quantity is computed in EPSG:3035 (ETRS89-LAEA), the
#     European standard for area, not in the UTM zone the national report uses;
#   * the 1 km grid is built in that metric CRS and clipped to the site rather
#     than through `occurrence_density_grid()`, which grids in degrees because
#     it feeds Leaflet rectangles. The class breaks are shared, so the two
#     still class record density identically.
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(sf)
})


# ==============================================================================
# 1. HOUSE-KEEPING
# ==============================================================================

# `R/functions.R` is sourced by the caller rather than from here, and the check
# is a hard stop rather than a `source()` from a guessed path: the runner and
# the Quarto template run with different working directories, so a path guessed
# here would be wrong in one of them, and quietly loading a second copy of the
# palette is exactly the drift this file exists to prevent.
if (!exists("map_palette", mode = "list") || !exists("say", mode = "function")) {
  stop("R/site_report.R builds on R/functions.R. Source that first:\n",
       "  source(\"R/functions.R\")\n  source(\"R/site_report.R\")",
       call. = FALSE)
}

#' Version of this reporting tool, stamped into every output
#'
#' Raised by hand when the meaning of an output changes — a new layer, a
#' different definition of a figure — so that two GeoPackages carrying
#' different versions can be told apart without reading them.
site_report_version <- "1.0.0"

#' The source revision the outputs were produced from
#'
#' The tool version says what the code means; the commit says which code it
#' was. Both are recorded, because a hand-maintained version string cannot
#' distinguish two runs from the same afternoon.
#'
#' @return A short commit hash, or `NA` where git is unavailable.
code_revision <- function() {
  out <- tryCatch(
    suppressWarnings(
      system2("git", c("rev-parse", "--short", "HEAD"),
              stdout = TRUE, stderr = FALSE)
    ),
    error = function(e) character()
  )
  status <- attr(out, "status")
  if (!length(out) || !nzchar(out[1]) || (!is.null(status) && status != 0)) {
    return(NA_character_)
  }
  out[1]
}

#' Print a progress message unless the run asked for silence
#'
#' `--quiet` has to reach code several calls deep without threading a flag
#' through every signature, so it travels as an option.
site_say <- function(...) {
  if (!isTRUE(getOption("site_report.quiet", FALSE))) say(...)
}

#' Render the shared display labels as plain text
#'
#' `density_labels` and `short_licence()` are written for HTML, where
#' `&ndash;` is the correct way to write an en dash. A PDF and a GeoPackage
#' attribute are not HTML, and a column reading "1 &ndash; 4" in QGIS is a
#' defect. The substitutions are listed rather than resolved through an HTML
#' parser so that this adds no dependency.
#'
#' @param x Character vector carrying HTML entities.
#' @return The same vector with the entities replaced by their characters.
plain_text <- function(x) {
  out <- as.character(x)
  subs <- c("&ndash;" = "–", "&mdash;" = "—", "&sup2;" = "²",
            "&amp;" = "&", "&nbsp;" = " ", "&deg;" = "°")
  for (nm in names(subs)) out <- gsub(nm, subs[[nm]], out, fixed = TRUE)
  out
}

#' Name the licences an occurrence export carries
#'
#' `short_licence()` shortens the URI form GBIF's registry returns, which is
#' what the dataset table holds. An occurrence download states the same
#' licences as enum labels instead — `CC_BY_4_0` rather than
#' `http://creativecommons.org/licenses/by/4.0/legalcode` — and that helper
#' passes them through unchanged, because keeping an unrecognised value is
#' safer than guessing at it. Translating the enum here lets one set of names
#' describe licences everywhere in the project, without changing what the
#' shared helper does to the inputs it already understands.
#'
#' @param x Character vector of licence labels or URIs.
#' @return Short names such as "CC BY 4.0".
licence_name <- function(x) {

  v   <- as.character(x)
  out <- rep(NA_character_, length(v))

  zero <- !is.na(v) & grepl("^CC0", v)
  out[zero] <- "CC0 1.0"

  by <- !is.na(v) & grepl("^CC_BY", v)
  if (any(by)) {
    parts <- sub("^CC_", "", v[by])
    code  <- gsub("_", "-", sub("_[0-9]+_[0-9]+$", "", parts))
    ver   <- sub("^.*_([0-9]+)_([0-9]+)$", "\\1.\\2", parts)
    out[by] <- paste("CC", code, ver)
  }

  rest <- is.na(out)
  out[rest] <- plain_text(short_licence(v[rest]))
  out
}

#' Fold a name to a lower-case ASCII matching key
#'
#' Site names carry Albanian and Serbian diacritics, and a reader typing
#' `--site "Bjeshket e Nemuna"` without them should still find the site.
#'
#' ICU's transliteration is used rather than `iconv(to = "ASCII//TRANSLIT")`
#' for the same reason `fmt_date_en()` supplies its own month names: iconv's
#' transliteration comes from the C library, so the same name folds to
#' "Bjeshket" on one machine and "Bjeshk?t" on another, and slugs derived from
#' it would differ between contributors. ICU gives the same answer everywhere.
#' `stringi` is not a new dependency — `stringr`, already in the stack, is
#' built on it.
#'
#' Case is folded too, because both callers — name matching and slug building —
#' are case-insensitive by definition.
#'
#' @param x Character vector.
#' @return A lower-case ASCII vector.
ascii_fold <- function(x) {
  if (!requireNamespace("stringi", quietly = TRUE)) {
    stop("Package 'stringi' is needed to fold site names to ASCII.\n",
         "It ships with 'stringr', which this project already uses:\n",
         "  install.packages(\"stringr\")", call. = FALSE)
  }
  tolower(stringi::stri_trans_general(as.character(x), "Latin-ASCII"))
}

#' Turn a site name into a file-system slug
#'
#' Output directories are named after the site, so the slug has to survive
#' every file system the outputs are copied onto: ASCII only, lower case,
#' hyphen-separated, no quotation marks, and short enough that
#' `outputs/<slug>/<slug>.gpkg` stays well inside a Windows path limit.
#'
#' Truncation happens at a hyphen rather than mid-word, which keeps the slug
#' readable and — because the cut is computed from the name alone — identical
#' on every run.
#'
#' @param x Character vector of site names.
#' @param max_chars Longest slug to produce before truncating.
#' @return A character vector of slugs.
make_slug <- function(x, max_chars = 60) {

  s <- ascii_fold(x)
  s <- gsub("[^a-z0-9]+", "-", s)
  s <- gsub("-{2,}", "-", s)
  s <- gsub("^-|-$", "", s)
  s[is.na(s)] <- ""

  long <- nchar(s) > max_chars
  if (any(long)) {
    cut <- substr(s[long], 1, max_chars)
    at  <- regexpr("-[^-]*$", cut)
    s[long] <- ifelse(at > 1, substr(cut, 1, at - 1), cut)
  }
  s
}

#' Build the slug for every site in a register, collision-checked
#'
#' Two sites can share a slug where their names differ only in a character the
#' fold removes. The identifier is then appended to BOTH members of the clash
#' rather than to the later one: leaving the first site unsuffixed would make
#' its slug depend on which other sites happen to be in the register, and the
#' contract is that a slug is stable across runs.
#'
#' @param id Register identifier, used to disambiguate and as a last resort.
#' @param name Site names.
#' @param max_chars Passed to `make_slug()`.
#' @return A character vector of unique slugs, one per site.
register_slugs <- function(id, name, max_chars = 60) {

  id   <- as.character(id)
  slug <- make_slug(name, max_chars = max_chars)

  # A site whose name is missing, or is entirely punctuation, still needs a
  # directory to be written into.
  blank <- is.na(slug) | !nzchar(slug)
  slug[blank] <- paste0("site-", make_slug(id[blank], max_chars = max_chars))

  clash <- slug %in% slug[duplicated(slug)]
  slug[clash] <- paste0(slug[clash], "-", make_slug(id[clash]))

  if (anyDuplicated(slug)) {
    stop("Two sites resolve to the same slug even after the identifier is ",
         "added: ", paste(unique(slug[duplicated(slug)]), collapse = ", "),
         call. = FALSE)
  }

  slug
}


# ==============================================================================
# 2. INPUTS
# ==============================================================================
#
# Every read goes through `require_input()`. A missing file is the likeliest
# failure on a fresh clone, and the message has to name both the file and the
# command that produces it: a silent empty result looks exactly like a site
# with no records, which is a legitimate finding, and the two must never be
# confusable.

#' Insist that an input file exists, and say how to make it if it does not
#'
#' @param path File path.
#' @param made_by The command that produces the file.
#' @param what Human-readable description used in the message.
#' @return The normalised path, invisibly.
require_input <- function(path, made_by, what = basename(path)) {
  if (!file.exists(path)) {
    stop(what, " not found:\n  ", path,
         "\nIt is produced by:\n  ", made_by, call. = FALSE)
  }
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

#' Record what every input was when the outputs were written
#'
#' Traceability is the point: an output that cannot name the state of its
#' inputs cannot be checked afterwards.
#'
#' @param paths Named character vector of file paths.
#' @return A tibble of input name, path, modification time (UTC) and size.
input_stamp <- function(paths) {

  paths <- unlist(paths, use.names = TRUE)
  paths <- paths[!is.na(paths) & nzchar(paths)]
  info  <- file.info(paths)

  dplyr::tibble(
    input        = names(paths),
    path         = unname(paths),
    modified_utc = format(as.POSIXct(info$mtime), "%Y-%m-%dT%H:%M:%SZ",
                          tz = "UTC"),
    bytes        = as.numeric(info$size)
  ) |>
    dplyr::arrange(.data$input)
}

#' Rename a register's columns onto the schema this tool documents
#'
#' The published GeoPackage schema has to be the same in every country, or the
#' QGIS project a reader built against one national extract breaks against the
#' next. The register's own attribute names therefore arrive through
#' `config$register_fields` and are mapped here, once, onto the documented
#' names. For a CDDA extract the mapping is the identity.
#'
#' @param x The register layer.
#' @param fields Named list: documented name = source column name.
#' @return `x` with the documented column names.
standardise_register <- function(x, fields) {

  for (canonical in names(fields)) {

    src <- fields[[canonical]]
    if (is.null(src) || is.na(src)) next

    if (!src %in% names(x)) {
      stop("The register has no column '", src, "', which ",
           "`config$register_fields$", canonical, "` points at.\n",
           "Columns present: ", paste(names(x), collapse = ", "),
           call. = FALSE)
    }

    if (!identical(src, canonical)) {
      names(x)[match(src, names(x))] <- canonical
    }
  }

  # Types are pinned here so that a register whose identifiers happen to be
  # numeric does not resolve differently from one whose identifiers are text.
  x$natda_id <- as.character(x$natda_id)
  if ("national_id" %in% names(x)) x$national_id <- as.character(x$national_id)
  if ("site_name" %in% names(x))   x$site_name   <- as.character(x$site_name)
  if ("reported_area_ha" %in% names(x)) {
    x$reported_area_ha <- suppressWarnings(as.numeric(x$reported_area_ha))
  }
  if ("designation_year" %in% names(x)) {
    x$designation_year <- suppressWarnings(as.integer(x$designation_year))
  }

  x
}

#' Read the protected-area register
#'
#' Returns the three things the rest of this file needs, kept apart because
#' they answer different questions: the designated sites, the strict-protection
#' zones nested inside some of them, and the sites recorded as a point because
#' they are too small to carry a mapped boundary.
#'
#' @param cfg The configuration list.
#' @return A list with `sites`, `strict`, `points` (all `sf`) and `register`
#'   (an attribute table of every designated site, carrying `slug`).
read_site_register <- function(cfg) {

  require_input(cfg$path_register, cfg$made_by, "The protected-area register")

  available <- sf::st_layers(cfg$path_register)$name

  read_layer <- function(layer) {
    if (is.null(layer) || is.na(layer) || !layer %in% available) return(NULL)
    standardise_register(
      sf::st_read(cfg$path_register, layer = layer, quiet = TRUE),
      cfg$register_fields
    )
  }

  polygons <- read_layer(cfg$layer_polygons)
  points   <- read_layer(cfg$layer_points)

  if (is.null(polygons)) {
    stop("The register has no layer '", cfg$layer_polygons, "'.\n",
         "Layers present: ", paste(available, collapse = ", "), call. = FALSE)
  }

  is_site <- polygons$designated_area_type == cfg$site_type
  sites   <- polygons[which(is_site), ]
  strict  <- polygons[which(!is_site), ]

  if (is.null(points)) points <- sites[0, ]

  # One row per designated site, whichever shape it was recorded in.
  # `geometry_source` is what tells a reader which, and what decides whether a
  # boundary has to be synthesised further down.
  register <- dplyr::bind_rows(
    sf::st_drop_geometry(sites)  |> dplyr::mutate(geometry_source = "boundary"),
    sf::st_drop_geometry(points) |> dplyr::mutate(geometry_source = "point")
  ) |>
    # Sorted by identifier so that `--all` walks the register in the same order
    # on every machine. dplyr sorts character columns in the C locale, which is
    # what makes that true across contributors' locales.
    dplyr::arrange(.data$natda_id)

  register$slug <- register_slugs(register$natda_id, register$site_name,
                                  max_chars = cfg$slug_max_chars)

  list(sites = sites, strict = strict, points = points, register = register)
}

#' Read the cleaned occurrence export, once
#'
#' @param cfg The configuration list.
#' @return An `sf` point layer in the storage CRS.
read_site_occurrences <- function(cfg) {

  require_input(cfg$path_occurrences, cfg$made_by,
                "The cleaned occurrence export")

  occ <- sf::st_read(cfg$path_occurrences, layer = cfg$layer_occurrences,
                     quiet = TRUE)

  if (!"gbifID" %in% names(occ)) {
    stop("The occurrence export has no `gbifID` column, so the directive ",
         "annotations cannot be joined to it.", call. = FALSE)
  }

  # A GBIF record identifier is a number only by accident of how it is
  # allocated. GDAL hands it back as a double from the GeoPackage and readr
  # reads it as text from the CSV subsets, so the join would fail on type
  # unless both are pinned to text here. `formatC` rather than `as.character`
  # because a large enough double would otherwise arrive as "4.5e+09".
  if (is.numeric(occ$gbifID)) {
    occ$gbifID <- formatC(occ$gbifID, format = "f", digits = 0)
  } else {
    occ$gbifID <- as.character(occ$gbifID)
  }

  sf::st_transform(occ, cfg$crs_storage)
}

#' Read the legal-framework annotations for individual records
#'
#' The cleaned export carries no `directive` or `annex` column — the pipeline
#' attaches those only to the thematic subsets — so the annotation is joined
#' back from those subsets by record identifier. A country outside the EU
#' Nature Directives sets `config$path_directive_subsets` to an empty vector,
#' and the report then says that no legal framework is configured rather than
#' showing an empty annex table as though it were a finding.
#'
#' @param cfg The configuration list.
#' @return A tibble of `gbifID`, `directive`, `annex`; zero rows when none are
#'   configured.
read_directive_annotations <- function(cfg) {

  empty <- dplyr::tibble(gbifID = character(), directive = character(),
                         annex = character())

  paths <- cfg$path_directive_subsets
  if (is.null(paths) || !length(paths)) return(empty)

  parts <- lapply(paths, function(p) {
    require_input(p, cfg$made_by, "A directive subset")
    readr::read_csv(
      p,
      col_select = dplyr::any_of(c("gbifID", "directive", "annex")),
      col_types  = readr::cols(.default = readr::col_character()),
      progress   = FALSE
    )
  })

  out <- dplyr::bind_rows(parts)
  if (!nrow(out) || !all(c("gbifID", "directive", "annex") %in% names(out))) {
    return(empty)
  }

  # A species can be listed on more than one annex, so a record can arrive from
  # more than one subset. Collapsing to one row per record is what stops the
  # later join duplicating occurrences.
  out |>
    dplyr::group_by(gbifID = .data$gbifID) |>
    dplyr::summarise(
      directive = paste(sort(unique(.data$directive[!is.na(.data$directive)])),
                        collapse = "; "),
      annex     = paste(sort(unique(.data$annex[!is.na(.data$annex)])),
                        collapse = "; "),
      .groups   = "drop"
    )
}

#' Read the pipeline's run metadata
#'
#' @param cfg The configuration list.
#' @return The metadata list written by `pipeline.R`.
read_run_metadata <- function(cfg) {
  require_input(cfg$path_metadata, cfg$made_by, "The pipeline run metadata")
  readRDS(cfg$path_metadata)
}


# ==============================================================================
# 3. SITE RESOLUTION AND SELECTION
# ==============================================================================

#' Resolve one command-line key to exactly one site
#'
#' The order of precedence is the register's own order of specificity: the
#' international identifier, then the national one, then the name. A name is
#' matched as a folded substring, so `--site "bjeshket"` finds
#' `Parku Kombetar "Bjeshket e Nemuna"`.
#'
#' An ambiguous name is an error that lists the candidates. Taking the first
#' match would be worse than failing: the run would succeed, the report would
#' carry a site name, and nobody would learn that a different site was meant.
#'
#' @param register The register table from `read_site_register()`.
#' @param key A single identifier or name fragment.
#' @return The matching row index into `register`.
resolve_site <- function(register, key) {

  key <- trimws(as.character(key))
  if (!nzchar(key)) stop("An empty --site value cannot be resolved.",
                         call. = FALSE)

  hit <- which(register$natda_id == key)
  if (length(hit) == 1) return(hit)

  if ("national_id" %in% names(register)) {
    hit <- which(!is.na(register$national_id) &
                   toupper(register$national_id) == toupper(key))
    if (length(hit) == 1) return(hit)
  }

  folded <- ascii_fold(register$site_name)
  hit    <- which(grepl(ascii_fold(key), folded, fixed = TRUE))

  if (length(hit) == 1) return(hit)

  if (length(hit) == 0) {
    stop("No site in the register matches '", key, "'.\n",
         "Tried the site identifier, the national identifier and a ",
         "diacritic-insensitive match on the name, against ",
         nrow(register), " sites.", call. = FALSE)
  }

  candidates <- paste0(
    "  ", register$natda_id[hit],
    "  ", format(register$national_id[hit] %||% ""),
    "  ", register$site_name[hit],
    "  (", register$designation[hit], ")"
  )

  stop("'", key, "' matches ", length(hit), " sites:\n",
       paste(candidates, collapse = "\n"),
       "\nUse a site identifier, a national identifier, or a longer name ",
       "fragment.", call. = FALSE)
}

#' Choose the set of sites a run will report on
#'
#' @param register The register table.
#' @param keys Character vector of `--site` values.
#' @param all Process the whole register.
#' @param designation Keep only this designation (case-insensitive).
#' @param iucn_category Keep only this IUCN management category.
#' @param min_area_km2 Keep only sites at least this large, measured on the
#'   register's reported area so that the filter can be applied before any
#'   geometry is built.
#' @return An integer vector of row indices into `register`, in register order.
select_sites <- function(register, keys = character(), all = FALSE,
                         designation = NULL, iucn_category = NULL,
                         min_area_km2 = NULL) {

  if (!all && !length(keys)) {
    stop("Nothing to do: give --site, or --all.", call. = FALSE)
  }

  idx <- if (all) {
    seq_len(nrow(register))
  } else {
    vapply(keys, function(k) resolve_site(register, k), integer(1),
           USE.NAMES = FALSE)
  }

  describe <- function(what, value) {
    paste0("No site is left after --", what, " ", shQuote(value), ".")
  }

  if (!is.null(designation)) {
    keep <- ascii_fold(register$designation[idx]) == ascii_fold(designation)
    idx  <- idx[which(keep)]
    if (!length(idx)) {
      stop(describe("designation", designation),
           "\nDesignations in the register: ",
           paste(sort(unique(register$designation)), collapse = ", "),
           call. = FALSE)
    }
  }

  if (!is.null(iucn_category)) {
    have <- register$iucn_management_category[idx]
    keep <- !is.na(have) & toupper(have) == toupper(iucn_category)
    idx  <- idx[which(keep)]
    if (!length(idx)) {
      stop(describe("iucn-category", iucn_category), call. = FALSE)
    }
  }

  if (!is.null(min_area_km2)) {
    have <- register$reported_area_ha[idx] / 100
    keep <- !is.na(have) & have >= min_area_km2
    idx  <- idx[which(keep)]
    if (!length(idx)) {
      stop(describe("min-area-km2", min_area_km2), call. = FALSE)
    }
  }

  sort(unique(idx))
}


# ==============================================================================
# 4. GEOMETRY
# ==============================================================================
#
# Everything measured is measured in `cfg$crs_metric` — EPSG:3035 by default,
# ETRS89-LAEA, the projection the European Environment Agency uses for area
# statistics. Everything stored is stored in `cfg$crs_storage` — EPSG:4326 —
# because the outputs travel, and a reader opening them in QGIS should not have
# to know which UTM zone the country happens to fall in. The CRS actually used
# is written into `report_metadata` so that neither choice has to be inferred.

#' Measure area in the metric CRS
#'
#' @param x An `sf` or `sfc` object.
#' @param crs_metric The equal-area CRS to measure in.
#' @return Area in square kilometres.
metric_area_km2 <- function(x, crs_metric) {
  as.numeric(units::set_units(
    sf::st_area(sf::st_transform(sf::st_geometry(x), crs_metric)), "km^2"))
}

#' Build one boundary geometry for every site in the register
#'
#' A site recorded as a point has no inside, so it can never match a record by
#' point-in-polygon however well surveyed it is. The point is therefore
#' buffered to a circle of the area the country reported for it — which for
#' these sites is a veteran tree or a spring of a few hundred square metres —
#' and both the report and `report_metadata` say that the boundary is a circle
#' rather than a mapped line.
#'
#' Where a point site has no reported area either, a default radius is used and
#' named as such. That is a placeholder, not a measurement, and it is labelled
#' so in every output that shows it.
#'
#' @param register The register table.
#' @param sites Polygon layer of mapped sites.
#' @param points Point layer of sites with no boundary.
#' @param cfg The configuration list.
#' @return A list with `geometry` (an `sfc` in the storage CRS, one per
#'   register row) and `basis` (how each was derived).
site_geometries <- function(register, sites, points, cfg) {

  n     <- nrow(register)
  geom  <- vector("list", n)
  basis <- rep(NA_character_, n)

  is_point <- register$geometry_source == "point"

  if (any(!is_point)) {
    at <- match(register$natda_id[!is_point], sites$natda_id)
    geom[which(!is_point)] <- sf::st_geometry(sites)[at]
    basis[!is_point] <- "mapped boundary"
  }

  if (any(is_point)) {
    at  <- match(register$natda_id[is_point], points$natda_id)
    pts <- sf::st_transform(sf::st_geometry(points)[at], cfg$crs_metric)

    area_m2 <- register$reported_area_ha[is_point] * 10000
    usable  <- !is.na(area_m2) & area_m2 > 0

    radius <- rep(cfg$point_default_radius_m, length(at))
    radius[usable] <- sqrt(area_m2[usable] / pi)

    circles <- sf::st_transform(sf::st_buffer(pts, dist = radius),
                                cfg$crs_storage)

    geom[which(is_point)] <- circles
    basis[is_point] <- ifelse(
      usable,
      "circle of the reported area, no mapped boundary",
      paste0("circle of the default ", cfg$point_default_radius_m,
             " m radius, no mapped boundary and no reported area")
    )
  }

  list(geometry = sf::st_sfc(geom, crs = sf::st_crs(cfg$crs_storage)),
       basis    = basis)
}

#' Buffer site boundaries by a fixed distance on the ground
#'
#' @param geoms An `sfc` in the storage CRS.
#' @param buffer_m Distance in metres.
#' @param cfg The configuration list.
#' @return An `sfc` in the storage CRS.
buffer_geometries <- function(geoms, buffer_m, cfg) {
  sf::st_transform(
    sf::st_buffer(sf::st_transform(geoms, cfg$crs_metric), dist = buffer_m),
    cfg$crs_storage
  )
}

#' Find the records inside each of a set of geometries
#'
#' This is the only place the occurrence layer is tested against geometry, and
#' it is called once per run with every geometry at once. `st_intersects()`
#' builds an index over the points it is given, so one call over 250 sites is
#' far cheaper than 250 calls over one site — which is what makes `--all`
#' finish in a sensible time.
#'
#' @param geoms An `sfc` of polygons.
#' @param occ The occurrence layer, in the same CRS.
#' @return A list of integer vectors of row indices into `occ`.
records_in <- function(geoms, occ) {
  suppressMessages(sf::st_intersects(geoms, occ))
}


# ==============================================================================
# 5. THE RUN CONTEXT
# ==============================================================================
#
# Everything a run needs, read and indexed once. `--all` over a few hundred
# sites must not re-read a 28 MB occurrence layer or rebuild a spatial index
# per site, so the three expensive spatial operations — buffering the register,
# testing the records against the sites, and testing them against the buffers —
# happen here, for the whole register, in one call each. Reporting on a single
# site pays the same cost, and it is seconds; the national ranking every report
# quotes needs the whole register anyway.

#' Read the national context layers
#'
#' Read straight from the cached GeoPackages rather than through
#' `kosovo_boundary()` and `kosovo_municipalities()`. Those helpers rebuild
#' from OpenStreetMap when the cache is missing, and this tool's contract is
#' that it never touches the network and fails loudly instead. The cache is
#' what `pipeline.R` leaves behind, so in a normal repository the two read the
#' same bytes.
#'
#' @param cfg The configuration list.
#' @return A list with `country` and `municipalities`, in the storage CRS.
read_context_layers <- function(cfg) {

  require_input(cfg$path_boundary, cfg$made_by, "The national boundary layer")
  require_input(cfg$path_municipalities, cfg$made_by,
                "The administrative unit layer")

  list(
    country = sf::st_transform(
      sf::st_read(cfg$path_boundary, quiet = TRUE), cfg$crs_storage),
    municipalities = sf::st_transform(
      sf::st_read(cfg$path_municipalities, quiet = TRUE), cfg$crs_storage)
  )
}

#' Assemble everything a run needs, once
#'
#' @param cfg The configuration list.
#' @return A context list consumed by `build_site_dataset()`.
site_report_context <- function(cfg) {

  site_say("Reading the protected-area register ...")
  reg <- read_site_register(cfg)
  site_say("  ", nrow(reg$register), " designated sites (",
           sum(reg$register$geometry_source == "boundary"), " with a mapped ",
           "boundary, ", sum(reg$register$geometry_source == "point"),
           " recorded as a point), ", nrow(reg$strict),
           " strict-protection zones.")

  site_say("Reading the cleaned occurrence export ...")
  occ <- read_site_occurrences(cfg)
  site_say("  ", fmt_int(nrow(occ)), " records.")

  context    <- read_context_layers(cfg)
  directives <- read_directive_annotations(cfg)
  meta       <- read_run_metadata(cfg)

  datasets <- if (!is.null(cfg$path_datasets) && file.exists(cfg$path_datasets)) {
    readr::read_csv(cfg$path_datasets, show_col_types = FALSE,
                    progress = FALSE)
  } else {
    dplyr::tibble(datasetKey = character(), datasetTitle = character(),
                  publisher = character())
  }

  site_say("Building site boundaries and buffers ...")
  geoms   <- site_geometries(reg$register, reg$sites, reg$points, cfg)
  buffers <- buffer_geometries(geoms$geometry, cfg$buffer_m, cfg)

  site_say("Indexing records against the register ...")
  hits_site   <- records_in(geoms$geometry, occ)
  hits_buffer <- records_in(buffers, occ)

  ctx <- list(
    cfg            = cfg,
    register       = reg$register,
    sites          = reg$sites,
    strict         = reg$strict,
    points         = reg$points,
    occ            = occ,
    occ_flat       = sf::st_drop_geometry(occ),
    country        = context$country,
    municipalities = context$municipalities,
    directives     = directives,
    datasets       = datasets,
    meta           = meta,
    geometry       = geoms$geometry,
    basis          = geoms$basis,
    buffers        = buffers,
    hits_site      = hits_site,
    hits_buffer    = hits_buffer,
    area_km2       = metric_area_km2(geoms$geometry, cfg$crs_metric),
    inputs         = input_stamp(c(
      register    = cfg$path_register,
      occurrences = cfg$path_occurrences,
      boundary    = cfg$path_boundary,
      units       = cfg$path_municipalities,
      metadata    = cfg$path_metadata
    ))
  )

  ctx$national <- national_site_statistics(ctx)
  ctx
}

#' Count distinct non-missing values
#'
#' Used for species, families and datasets alike, so that "distinct" means the
#' same thing in the key figures, the ranking and the grid.
#'
#' @param x A character vector.
#' @return An integer count.
n_distinct_values <- function(x) {
  x <- as.character(x)
  length(unique(x[!is.na(x) & nzchar(x)]))
}

#' Summarise every site in the register on the measures the reports rank
#'
#' Counted by intersection with the boundary, NOT from the `protectedArea`
#' stamp the pipeline leaves on each record. The stamp names the smallest site
#' containing a record, which is the right answer for a national table that has
#' to partition the records; it is the wrong answer here, because a record in
#' the overlap of two sites is evidence for both of the reports that mention
#' it. The consequence — that a site's count here can exceed its row in the
#' national report — is stated in the report itself rather than papered over.
#'
#' @param ctx The run context.
#' @return A tibble, one row per site, sorted by identifier.
national_site_statistics <- function(ctx) {

  flat <- ctx$occ_flat
  hits <- ctx$hits_site

  measure <- function(column) {
    if (!column %in% names(flat)) return(rep(NA_integer_, length(hits)))
    values <- as.character(flat[[column]])
    vapply(hits, function(i) n_distinct_values(values[i]), integer(1))
  }

  dplyr::tibble(
    natda_id          = ctx$register$natda_id,
    national_id       = ctx$register$national_id,
    slug              = ctx$register$slug,
    site_name         = ctx$register$site_name,
    designation       = ctx$register$designation,
    geometry_source   = ctx$register$geometry_source,
    computed_area_km2 = ctx$area_km2,
    records           = lengths(hits),
    species           = measure("species"),
    families          = measure("family"),
    datasets          = measure("datasetKey")
  ) |>
    dplyr::mutate(
      records_per_km2 = ifelse(.data$computed_area_km2 > 0,
                               .data$records / .data$computed_area_km2,
                               NA_real_)
    ) |>
    dplyr::arrange(.data$natda_id)
}

#' Rank one site against the whole register
#'
#' Ranked from the best downwards with ties taking the better rank, which is
#' how a reader reads "3rd of 256". Sites the measure cannot be computed for
#' are excluded from the denominator rather than ranked last.
#'
#' @param national The table from `national_site_statistics()`.
#' @param natda_id The site to rank.
#' @return A tibble of measure, value, rank and denominator.
site_ranks <- function(national, natda_id) {

  row <- national[national$natda_id == natda_id, , drop = FALSE]
  if (!nrow(row)) {
    stop("Site '", natda_id, "' is not in the national statistics table.",
         call. = FALSE)
  }

  measures <- c(records = "Records", species = "Species",
                families = "Families", datasets = "Source datasets",
                records_per_km2 = "Records per km²")

  dplyr::bind_rows(lapply(names(measures), function(m) {
    values <- national[[m]]
    value  <- row[[m]]
    usable <- !is.na(values)
    dplyr::tibble(
      measure = unname(measures[[m]]),
      value   = value,
      rank    = if (is.na(value)) NA_integer_
                else as.integer(sum(values[usable] > value) + 1L),
      of      = as.integer(sum(usable))
    )
  }))
}


# ==============================================================================
# 6. CLIPPING AND SUMMARISING ONE SITE
# ==============================================================================

#' The records inside a site and its buffer
#'
#' Both are returned as one layer with two flags rather than as two layers,
#' because the comparison the buffer exists for — what is recorded just outside
#' ground that is protected — is a comparison within one table.
#'
#' @param ctx The run context.
#' @param i Row index into the register.
#' @return An `sf` point layer with `inside_site` and `in_buffer_only`.
site_occurrence_layer <- function(ctx, i) {

  inside <- ctx$hits_site[[i]]
  within <- ctx$hits_buffer[[i]]

  # A buffer contains its site, but a degenerate geometry could in principle
  # break that, and a record inside the site must never be dropped for want of
  # being in the buffer.
  idx <- sort(unique(c(inside, within)))

  occ <- ctx$occ[idx, , drop = FALSE]
  occ$inside_site    <- idx %in% inside
  occ$in_buffer_only <- !occ$inside_site

  if (!"strictlyProtected" %in% names(occ)) {
    occ$strictlyProtected <- if (nrow(ctx$strict) && nrow(occ)) {
      lengths(suppressMessages(sf::st_intersects(occ, ctx$strict))) > 0
    } else {
      rep(FALSE, nrow(occ))
    }
  }

  if (nrow(occ)) {
    occ <- occ |>
      dplyr::left_join(ctx$directives, by = "gbifID")
  } else {
    occ$directive <- character()
    occ$annex     <- character()
  }

  if (!"directive" %in% names(occ)) occ$directive <- NA_character_
  if (!"annex" %in% names(occ))     occ$annex     <- NA_character_

  # A fixed order, so that two runs over unchanged inputs write the same rows
  # in the same order. (The GeoPackage files themselves are not byte-identical:
  # SQLite stamps its own `last_change` into `gpkg_contents`.) `gbifID` is a
  # number held as text, so it is sorted as one.
  if (nrow(occ)) {
    occ <- occ[order(!occ$inside_site,
                     suppressWarnings(as.numeric(occ$gbifID)),
                     occ$gbifID), , drop = FALSE]
  }

  occ
}

#' Build the 1 km grid over a site
#'
#' Built in the metric CRS and clipped to the boundary rather than through
#' `occurrence_density_grid()`. That helper grids in degrees and returns
#' unclipped rectangles, which is right for the Leaflet layer it feeds and
#' wrong here for two reasons: a site's metrics are computed in EPSG:3035 by
#' contract, and the share of a site that holds no records cannot be stated
#' honestly from cells that hang over its edge. The class breaks are the shared
#' ones, so the two still class density identically.
#'
#' Every cell is returned, empty ones included — the empty cells are the
#' recording gap, and dropping them here would make the gap uncomputable. The
#' writer drops them from the published layers.
#'
#' @param boundary The site boundary, in the storage CRS.
#' @param occ Records inside the site.
#' @param cfg The configuration list.
#' @return An `sf` polygon layer in the storage CRS.
site_grid <- function(boundary, occ, cfg) {

  b <- sf::st_transform(sf::st_geometry(boundary), cfg$crs_metric)

  cells <- sf::st_make_grid(b, cellsize = cfg$grid_m, square = TRUE)
  g     <- sf::st_sf(cell_id = seq_along(cells), geometry = cells)
  g     <- g[lengths(suppressMessages(sf::st_intersects(g, b))) > 0, ,
             drop = FALSE]

  g <- suppressWarnings(sf::st_intersection(g, b))

  # Clipping a square against a boundary can leave a point or a line where the
  # two only touch; those carry no area and are not cells.
  if (any(as.character(sf::st_geometry_type(g)) == "GEOMETRYCOLLECTION")) {
    g <- suppressWarnings(sf::st_collection_extract(g, "POLYGON"))
  }
  g <- g[!sf::st_is_empty(g), , drop = FALSE]

  g$cell_area_km2 <- metric_area_km2(g, cfg$crs_metric)
  g <- g[g$cell_area_km2 > 0, , drop = FALSE]

  if (nrow(occ)) {
    pts <- sf::st_transform(sf::st_geometry(occ), cfg$crs_metric)
    hit <- suppressMessages(sf::st_intersects(g, pts))
    species <- if ("species" %in% names(occ)) as.character(occ$species)
               else rep(NA_character_, nrow(occ))
    g$records <- lengths(hit)
    g$species <- vapply(hit, function(i) n_distinct_values(species[i]),
                        integer(1))
  } else {
    g$records <- 0L
    g$species <- 0L
  }

  g$density_class <- as.character(cut(g$records, breaks = density_breaks,
                                      right = FALSE,
                                      labels = plain_text(density_labels)))
  g$density_class[g$records == 0] <- "no records"

  g <- g[order(g$cell_id), , drop = FALSE]
  sf::st_transform(g, cfg$crs_storage)
}

#' One row per species recorded in a site
#'
#' @param occ Records inside the site.
#' @return A tibble sorted by record count, then by name.
site_species_summary <- function(occ) {

  flat <- sf::st_drop_geometry(occ)

  empty <- dplyr::tibble(
    species = character(), vernacularName = character(),
    kingdom = character(), family = character(), records = integer(),
    iucnRedListCategory = character(), directive = character(),
    annex = character(), first_year = integer(), last_year = integer()
  )

  if (!nrow(flat) || !"species" %in% names(flat)) return(empty)

  flat <- flat[!is.na(flat$species) & nzchar(flat$species), , drop = FALSE]
  if (!nrow(flat)) return(empty)

  years <- suppressWarnings(as.integer(flat$year))
  flat$.year <- ifelse(!is.na(years) & years > 1500, years, NA_integer_)

  # The alphabetically first non-missing value, not the first row's: a summary
  # table must not change because the records arrived in a different order.
  first_of <- function(x) {
    x <- sort(unique(as.character(x[!is.na(x) & nzchar(as.character(x))])))
    if (length(x)) x[1] else NA_character_
  }
  joined <- function(x) {
    x <- sort(unique(as.character(x[!is.na(x) & nzchar(as.character(x))])))
    if (length(x)) paste(x, collapse = "; ") else NA_character_
  }

  flat |>
    dplyr::group_by(species = .data$species) |>
    dplyr::summarise(
      vernacularName      = first_of(.data$vernacularName),
      kingdom             = first_of(.data$kingdom),
      family              = first_of(.data$family),
      records             = dplyr::n(),
      iucnRedListCategory = first_of(.data$iucnRedListCategory),
      directive           = joined(.data$directive),
      annex               = joined(.data$annex),
      first_year          = suppressWarnings(min(.data$.year, na.rm = TRUE)),
      last_year           = suppressWarnings(max(.data$.year, na.rm = TRUE)),
      .groups             = "drop"
    ) |>
    dplyr::mutate(
      # Converted after the guard, not inside it: a species whose records all
      # lack a year gives `min()` an infinity, and `ifelse()` evaluates both
      # branches over the whole column, so coercing first would warn on every
      # such species.
      first_year = as.integer(ifelse(is.finite(.data$first_year),
                                     .data$first_year, NA_real_)),
      last_year  = as.integer(ifelse(is.finite(.data$last_year),
                                     .data$last_year, NA_real_))
    ) |>
    dplyr::arrange(dplyr::desc(.data$records), .data$species)
}

#' The headline figures for a site
#'
#' Built on `summarise_subset()` so that "species", "families" and "first year"
#' mean here exactly what they mean in the national report.
#'
#' @param occ Records inside the site.
#' @param area_km2 The computed area of the site.
#' @return A one-row tibble.
site_key_figures <- function(occ, area_km2) {

  s <- summarise_subset(occ, "site")

  dplyr::tibble(
    records         = as.integer(s$Records),
    species         = as.integer(s$Species),
    families        = as.integer(s$Families),
    datasets        = as.integer(s$`Source datasets`),
    first_year      = as.integer(s$`First year`),
    last_year       = as.integer(s$`Most recent year`),
    records_per_km2 = if (is.na(area_km2) || area_km2 <= 0) NA_real_
                      else s$Records / area_km2
  )
}

#' Records and species by kingdom group
#'
#' @param occ Records inside the site.
#' @return A tibble in the palette's own kingdom order.
site_taxonomic_summary <- function(occ) {

  flat <- sf::st_drop_geometry(occ)

  if (!nrow(flat)) {
    return(dplyr::tibble(kingdom = character(), records = integer(),
                         species = integer()))
  }

  flat |>
    dplyr::mutate(.group = kingdom_group(.data$kingdom)) |>
    dplyr::group_by(kingdom = .data$.group) |>
    dplyr::summarise(
      records = dplyr::n(),
      species = n_distinct_values(.data$species),
      .groups = "drop"
    ) |>
    dplyr::filter(.data$records > 0) |>
    dplyr::arrange(match(as.character(.data$kingdom),
                         names(map_palette$kingdom))) |>
    dplyr::mutate(kingdom = as.character(.data$kingdom))
}

#' What the recording effort looks like, and where it is absent
#'
#' @param grid The full clipped grid, empty cells included.
#' @param occ Records inside the site.
#' @param datasets The dataset registry.
#' @param top_n How many datasets to name.
#' @return A list of effort statistics.
site_effort_summary <- function(grid, occ, datasets, top_n = 5) {

  flat <- sf::st_drop_geometry(occ)
  cells <- sf::st_drop_geometry(grid)

  area_total <- sum(cells$cell_area_km2, na.rm = TRUE)
  area_empty <- sum(cells$cell_area_km2[cells$records == 0], na.rm = TRUE)

  years <- suppressWarnings(as.integer(flat$year))
  years <- years[!is.na(years) & years > 1500]

  missing_years <- if (length(years)) {
    setdiff(seq(min(years), max(years)), sort(unique(years)))
  } else {
    integer()
  }

  top <- if (nrow(flat) && "datasetKey" %in% names(flat)) {
    counted <- flat |>
      dplyr::count(datasetKey = .data$datasetKey, name = "records") |>
      dplyr::arrange(dplyr::desc(.data$records), .data$datasetKey)
    if ("datasetKey" %in% names(datasets)) {
      counted <- dplyr::left_join(
        counted,
        dplyr::select(datasets, dplyr::any_of(c("datasetKey", "datasetTitle",
                                                "publisher", "datasetLicense"))),
        by = "datasetKey")
    }
    utils::head(counted, top_n)
  } else {
    dplyr::tibble(datasetKey = character(), records = integer())
  }

  list(
    cells               = nrow(cells),
    cells_with_records  = sum(cells$records > 0),
    area_km2            = area_total,
    unrecorded_km2      = area_empty,
    unrecorded_share    = if (area_total > 0) area_empty / area_total else NA_real_,
    max_records_in_cell = if (nrow(cells)) max(cells$records) else 0L,
    first_year          = if (length(years)) min(years) else NA_integer_,
    last_year           = if (length(years)) max(years) else NA_integer_,
    years_recorded      = length(unique(years)),
    years_missing       = as.integer(missing_years),
    datasets            = top
  )
}

#' The administrative units a site falls in
#'
#' Two shares are reported, because they answer different questions: how much
#' of the unit the site covers, and how much of the site the unit holds. A
#' reader in a municipal office wants the first; a reader planning survey
#' effort wants the second.
#'
#' @param municipalities The administrative unit layer.
#' @param boundary The site boundary.
#' @param cfg The configuration list.
#' @return An `sf` polygon layer of the overlapping units.
site_municipalities <- function(municipalities, boundary, cfg) {

  units <- sf::st_transform(municipalities, cfg$crs_metric)
  b     <- sf::st_transform(sf::st_geometry(boundary), cfg$crs_metric)

  touching <- lengths(suppressMessages(sf::st_intersects(units, b))) > 0
  units    <- units[which(touching), , drop = FALSE]

  unit_area_km2 <- metric_area_km2(units, cfg$crs_metric)
  site_area_km2 <- sum(metric_area_km2(b, cfg$crs_metric))

  # As with the strict zones: a site that touches no administrative unit still
  # gets the layer, with its columns, and no rows.
  if (!nrow(units)) {
    units$unit_area_km2 <- numeric()
    units$overlap_km2   <- numeric()
    units$share_of_unit <- numeric()
    units$share_of_site <- numeric()
    return(sf::st_transform(units, cfg$crs_storage))
  }

  # The clipped pieces are carried back to their unit by an explicit key.
  # Matching them geometrically instead looks equivalent and is not: units tile
  # the country, so each piece touches its neighbours along their shared
  # boundary, every piece would be claimed by two units, and every share would
  # come out inflated and near-identical.
  units$.unit_key <- seq_len(nrow(units))
  parts <- suppressWarnings(
    sf::st_intersection(units[, ".unit_key"], b))

  piece_km2 <- if (nrow(parts)) metric_area_km2(parts, cfg$crs_metric)
               else numeric()
  by_key <- tapply(piece_km2, parts$.unit_key, sum)

  overlap_km2 <- rep(0, nrow(units))
  overlap_km2[as.integer(names(by_key))] <- as.numeric(by_key)
  units$.unit_key <- NULL

  # NOT `ifelse(site_area_km2 > 0, overlap_km2 / site_area_km2, NA_real_)`.
  # `ifelse()` returns a result shaped like its TEST, and the site area is one
  # number, so that form silently returns a single share and recycles it down
  # the column — every unit reporting the first one's figure.
  share <- function(numerator, denominator) {
    out <- rep(NA_real_, length(numerator))
    ok  <- !is.na(denominator) & denominator > 0
    out[ok] <- numerator[ok] / denominator[ok]
    out
  }

  units$unit_area_km2   <- unit_area_km2
  units$overlap_km2     <- overlap_km2
  units$share_of_unit   <- share(overlap_km2, unit_area_km2)
  units$share_of_site   <- share(overlap_km2,
                                 rep(site_area_km2, length(overlap_km2)))

  units <- units[order(-units$overlap_km2,
                       as.character(units[[cfg$municipality_field]])), ,
                 drop = FALSE]

  sf::st_transform(units, cfg$crs_storage)
}

#' The strict-protection zones inside a site
#'
#' @param ctx The run context.
#' @param boundary The site boundary.
#' @param occ Records inside the site.
#' @return An `sf` polygon layer, possibly with no rows.
site_strict_zones <- function(ctx, boundary, occ) {

  strict <- ctx$strict

  if (nrow(strict)) {
    b      <- sf::st_geometry(boundary)
    inside <- lengths(suppressMessages(sf::st_intersects(strict, b))) > 0
    strict <- strict[which(inside), , drop = FALSE]
  }

  # The computed columns are added even when there is no zone to describe. A
  # layer whose columns depend on whether it has any rows is a layer a reader's
  # QGIS project breaks on at the first site without one.
  n <- nrow(strict)
  strict$computed_area_km2 <- metric_area_km2(strict, ctx$cfg$crs_metric)

  if (n && nrow(occ)) {
    hit <- suppressMessages(sf::st_intersects(strict, occ))
    species <- if ("species" %in% names(occ)) as.character(occ$species)
               else rep(NA_character_, nrow(occ))
    strict$records <- lengths(hit)
    strict$species <- vapply(hit, function(i) n_distinct_values(species[i]),
                             integer(1))
  } else {
    strict$records <- rep(0L, n)
    strict$species <- rep(0L, n)
  }

  strict[order(-strict$computed_area_km2, strict$natda_id), , drop = FALSE]
}


# ==============================================================================
# 7. THE SITE DATASET AND ITS GEOPACKAGE
# ==============================================================================

#' The layers of a site GeoPackage, in the order they are written
#'
#' The order is part of the published schema: a reader opening the file in
#' QGIS gets the boundary first and the record points after the surfaces they
#' are drawn over.
site_gpkg_layers <- c(
  "site_boundary", "site_buffer", "strict_protection", "occurrences",
  "species_richness_grid", "record_density_grid", "municipalities_overlapping",
  "species_summary", "report_metadata"
)

#' Describe the run that produced an output
#'
#' A long table rather than a wide one, because the number of input files is
#' not fixed and a schema that changes shape with the configuration is worse
#' than one extra row per file.
#'
#' @param ctx The run context.
#' @param i Row index into the register.
#' @param licences Short licence names present in the extract.
#' @param command The command that reproduces the output.
#' @return A tibble of `natda_id`, `item`, `value`.
site_report_metadata <- function(ctx, i, licences, command) {

  cfg <- ctx$cfg
  row <- ctx$register[i, , drop = FALSE]

  pkg_version <- function(p) {
    tryCatch(as.character(utils::packageVersion(p)),
             error = function(e) NA_character_)
  }

  soft <- tryCatch(sf::sf_extSoftVersion(), error = function(e) character())
  download <- ctx$meta$download %||% list()
  src <- cfg$register_source %||% list()

  items <- c(
    natda_id            = row$natda_id,
    national_id         = row$national_id %||% NA_character_,
    site_name           = row$site_name,
    slug                = row$slug,
    boundary_basis      = ctx$basis[i],

    run_timestamp_utc   = format(as.POSIXct(Sys.time()), "%Y-%m-%dT%H:%M:%SZ",
                                 tz = "UTC"),
    command             = command,

    tool                = "site_reports.R",
    tool_version        = site_report_version,
    code_revision       = code_revision(),

    crs_storage         = paste0("EPSG:", cfg$crs_storage),
    crs_metric          = paste0("EPSG:", cfg$crs_metric),
    buffer_m            = as.character(cfg$buffer_m),
    grid_m              = as.character(cfg$grid_m),

    # Carried so that the report template can draw its maps to the same
    # settings the GeoPackage was built with, rather than to its own defaults.
    locator_ring_m      = as.character(cfg$locator_ring_m),
    map_max_points      = as.character(cfg$map_max_points),

    gbif_download_key   = download$key %||% NA_character_,
    gbif_download_doi   = download$doi %||% NA_character_,
    gbif_download_created = download$created %||% NA_character_,
    gbif_citation       = download$citation %||% NA_character_,

    register_source     = src$name %||% NA_character_,
    register_version    = src$version %||% NA_character_,
    register_licence    = src$licence %||% NA_character_,
    register_doi        = src$doi %||% NA_character_,

    licences_in_extract = if (length(licences)) paste(licences, collapse = "; ")
                          else NA_character_,

    r_version           = R.version.string,
    sf_version          = pkg_version("sf"),
    dplyr_version       = pkg_version("dplyr"),
    ggplot2_version     = pkg_version("ggplot2"),
    quarto_version      = pkg_version("quarto"),
    gdal_version        = unname(soft["GDAL"] %||% NA_character_),
    geos_version        = unname(soft["GEOS"] %||% NA_character_),
    proj_version        = unname(soft["PROJ"] %||% NA_character_)
  )

  inputs <- ctx$inputs
  input_items <- stats::setNames(
    c(inputs$path, inputs$modified_utc),
    c(paste0("input_", inputs$input, "_path"),
      paste0("input_", inputs$input, "_modified_utc"))
  )

  all_items <- c(items, input_items)

  dplyr::tibble(
    natda_id = row$natda_id,
    item     = names(all_items),
    value    = as.character(unname(all_items))
  )
}

#' Build every layer of one site's GeoPackage
#'
#' Pure: given the same context and index it returns the same tables, with no
#' file system access and nothing random. That is what makes the outputs
#' reproducible and the tests cheap.
#'
#' @param ctx The run context.
#' @param i Row index into the register.
#' @param command The command that reproduces the output.
#' @return A named list of layers, in the published order.
build_site_dataset <- function(ctx, i, command = NA_character_) {

  cfg <- ctx$cfg
  row <- ctx$register[i, , drop = FALSE]

  boundary <- sf::st_sf(row, geometry = ctx$geometry[i])

  # The register's own `area_km2` is dropped rather than carried alongside the
  # computed one. It was measured in a different projection by
  # `kosovo_protected_areas()`, and two area columns differing in the third
  # decimal place is precisely the ambiguity this schema exists to remove: one
  # area, computed in the CRS `report_metadata` names.
  boundary$area_km2 <- NULL
  boundary$slug     <- NULL

  occ_all <- site_occurrence_layer(ctx, i)
  occ_in  <- occ_all[occ_all$inside_site, , drop = FALSE]

  area_km2 <- ctx$area_km2[i]
  figures  <- site_key_figures(occ_in, area_km2)
  grid     <- site_grid(boundary, occ_in, cfg)
  strict   <- site_strict_zones(ctx, boundary, occ_in)
  units    <- site_municipalities(ctx$municipalities, boundary, cfg)
  species  <- site_species_summary(occ_in)
  effort   <- site_effort_summary(grid, occ_in, ctx$datasets,
                                  top_n = cfg$top_datasets)

  licences <- if ("license" %in% names(occ_in) && nrow(occ_in)) {
    sort(unique(licence_name(occ_in$license)))
  } else {
    character()
  }

  boundary$boundary_basis           <- ctx$basis[i]
  boundary$computed_area_km2        <- area_km2
  boundary$buffer_m                 <- cfg$buffer_m
  boundary$records                  <- figures$records
  boundary$species                  <- figures$species
  boundary$families                 <- figures$families
  boundary$datasets                 <- figures$datasets
  boundary$records_per_km2          <- figures$records_per_km2
  boundary$first_year               <- figures$first_year
  boundary$last_year                <- figures$last_year
  boundary$records_in_buffer_only   <- sum(occ_all$in_buffer_only)
  boundary$strict_zones             <- nrow(strict)
  boundary$strict_records           <- sum(strict$records %||% 0)
  boundary$grid_cells               <- as.integer(effort$cells)
  boundary$grid_cells_with_records  <- as.integer(effort$cells_with_records)
  boundary$unrecorded_share         <- effort$unrecorded_share

  buffer <- sf::st_sf(
    dplyr::tibble(
      natda_id        = row$natda_id,
      site_name       = row$site_name,
      buffer_m        = cfg$buffer_m,
      buffer_area_km2 = metric_area_km2(ctx$buffers[i], cfg$crs_metric),
      records         = nrow(occ_all),
      records_outside = sum(occ_all$in_buffer_only)
    ),
    geometry = ctx$buffers[i]
  )

  richness <- grid[grid$records > 0, c("cell_id", "species", "records",
                                       "cell_area_km2"), drop = FALSE]
  density  <- grid[grid$records > 0, c("cell_id", "records", "density_class",
                                       "cell_area_km2"), drop = FALSE]

  list(
    site_boundary              = boundary,
    site_buffer                = buffer,
    strict_protection          = strict,
    occurrences                = occ_all,
    species_richness_grid      = richness,
    record_density_grid        = density,
    municipalities_overlapping = units,
    species_summary            = species,
    report_metadata            = site_report_metadata(ctx, i, licences,
                                                      command),
    # Not written to the GeoPackage: the full grid, which carries the empty
    # cells the published layers drop, and the effort statistics derived from
    # it. Both are summarised into `site_boundary`, so the report can state the
    # recording gap from the file alone.
    grid_full                  = grid,
    effort                     = effort,
    slug                       = row$slug
  )
}

#' Write a site dataset to a GeoPackage
#'
#' Every layer is written, including the empty ones. A site with no records
#' still gets an `occurrences` layer with no features: a missing layer and an
#' empty layer look the same to a reader in a hurry, and only one of them is
#' honest.
#'
#' @param dataset The list from `build_site_dataset()`.
#' @param path Destination GeoPackage.
#' @return The path, invisibly.
write_site_gpkg <- function(dataset, path) {

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(path)) unlink(path)

  for (layer in site_gpkg_layers) {

    x <- dataset[[layer]]
    if (is.null(x)) {
      stop("The dataset has no layer '", layer, "' to write.", call. = FALSE)
    }

    # Polygon layers are cast to MULTIPOLYGON so that the same layer has the
    # same geometry type in every site's file, whatever that site's boundary
    # happened to be. Empty layers are cast too: a layer that is POLYGON when
    # it has no rows and MULTIPOLYGON when it has some is the same drift seen
    # from the other end.
    #
    # The decision is taken from the geometry column's DECLARED class, not from
    # the types of the features present. An empty layer has no features to ask,
    # so testing those would find an empty set, conclude that everything in it
    # is a polygon, and write the occurrence layer of a site with no records as
    # an empty polygon layer.
    if (inherits(x, "sf")) {
      declared <- class(sf::st_geometry(x))[1]
      present  <- unique(as.character(sf::st_geometry_type(x)))
      # A mixed collection can only arise from clipping the grid to the site,
      # and those pieces are polygons.
      polygonal <- declared %in% c("sfc_POLYGON", "sfc_MULTIPOLYGON") ||
        (declared == "sfc_GEOMETRY" &&
           all(present %in% c("POLYGON", "MULTIPOLYGON")))
      if (polygonal) x <- suppressWarnings(sf::st_cast(x, "MULTIPOLYGON"))
    }

    sf::st_write(x, path, layer = layer, append = FALSE, quiet = TRUE)
  }

  invisible(path)
}

#' Read a site GeoPackage back
#'
#' The report template reads its numbers from the file rather than recomputing
#' them, so that the GeoPackage and the PDF cannot state different figures.
#'
#' @param path A site GeoPackage.
#' @return A named list of layers.
read_site_gpkg <- function(path) {

  require_input(path, "Rscript site_reports.R --site <id>",
                "The site GeoPackage")

  present <- sf::st_layers(path)$name
  out <- lapply(stats::setNames(present, present), function(layer) {
    sf::st_read(path, layer = layer, quiet = TRUE)
  })
  out
}

#' Look one value out of the metadata layer
#'
#' @param metadata The `report_metadata` table.
#' @param item The item name.
#' @return A single character value, or `NA`.
meta_value <- function(metadata, item) {
  hit <- metadata$value[metadata$item == item]
  if (!length(hit)) return(NA_character_)
  hit[1]
}


# ==============================================================================
# 8. STATIC MAPS
# ==============================================================================
#
# ggplot2 only, and no tile layer of any kind. A report that fetched a basemap
# while rendering would look different next year and would not render at all on
# a machine without a network, and both of those defeat the point of a tool
# meant to be re-run unattended.
#
# The map colours are `map_palette`, shared with the website's interactive maps
# so that a site drawn here and the same site drawn there are the same green.
# The two values below are the document's rather than the map's: the text a
# figure carries has to match the text around it, which on the page and in
# `reports/gbif-report.typ` is GBIF black for reading and #666666 for captions.
# `run_test_site_report.R` checks the three files still agree.

report_ink <- list(
  text    = "#231F20",   # $body-color in custom.scss — GBIF black
  caption = "#666666"    # the grey every caption and meta line on the page wears
)

#' The shared look of the maps in a site report
#'
#' @param base_size Base font size.
#' @return A ggplot2 theme.
site_theme <- function(base_size = 9) {
  ggplot2::theme_void(base_size = base_size) +
    ggplot2::theme(
      text             = ggplot2::element_text(colour = report_ink$text),
      legend.position  = "bottom",
      legend.title     = ggplot2::element_blank(),
      legend.key.size  = grid::unit(0.32, "cm"),
      legend.text      = ggplot2::element_text(size = base_size - 1),
      plot.caption     = ggplot2::element_text(size = base_size - 1.5,
                                               colour = report_ink$caption,
                                               hjust = 0),
      plot.margin      = ggplot2::margin(2, 2, 2, 2)
    )
}

#' Where the site is in the country
#'
#' A locator ring is drawn around the site as well as the site itself. Most of
#' this register is natural monuments of a few hundred square metres, which at
#' national scale are smaller than the line that would draw them; without the
#' ring the map would be a picture of the country with nothing on it.
#'
#' @param dataset The site dataset.
#' @param country The national boundary.
#' @param municipalities The administrative units.
#' @param cfg The configuration list.
#' @return A ggplot object.
site_locator_map <- function(dataset, country, municipalities, cfg) {

  boundary <- dataset$site_boundary

  centre <- suppressWarnings(
    sf::st_centroid(sf::st_transform(sf::st_geometry(boundary),
                                     cfg$crs_metric)))
  ring <- sf::st_transform(
    sf::st_buffer(centre, dist = cfg$locator_ring_m), cfg$crs_storage)

  ggplot2::ggplot() +
    ggplot2::geom_sf(data = municipalities, fill = map_palette$land,
                     colour = map_palette$municipality, linewidth = 0.15) +
    ggplot2::geom_sf(data = country, fill = NA,
                     colour = map_palette$boundary, linewidth = 0.4) +
    ggplot2::geom_sf(data = boundary, fill = map_palette$protected[["site"]],
                     colour = map_palette$protected[["strict"]],
                     linewidth = 0.3) +
    ggplot2::geom_sf(data = ring, fill = NA,
                     colour = map_palette$protected[["strict"]],
                     linewidth = 0.5) +
    # Deliberately broken over two lines: a caption is drawn inside the plot
    # and is clipped, not wrapped, when it runs past the panel.
    ggplot2::labs(
      caption = paste0(
        "The ring marks the position of the site.\n",
        "At this scale a small site is smaller than the line that draws it.")) +
    site_theme()
}

#' The records inside the site
#'
#' Above `max_points` the point layer is withheld rather than thinned, and the
#' caption says so. A subsample of a dense site is indistinguishable from a
#' genuinely sparse one, which is the misreading this whole report is written
#' to prevent.
#'
#' @param dataset The site dataset.
#' @param cfg The configuration list.
#' @param max_points Cap above which the points are withheld.
#' @return A ggplot object carrying a `map_note` attribute.
site_occurrence_map <- function(dataset, cfg, max_points = cfg$map_max_points) {

  boundary <- dataset$site_boundary
  buffer   <- dataset$site_buffer
  strict   <- dataset$strict_protection
  occ      <- dataset$occurrences
  inside   <- occ[which(occ$inside_site), , drop = FALSE]

  p <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = buffer, fill = NA,
                     colour = map_palette$municipality,
                     linewidth = 0.3, linetype = "22") +
    ggplot2::geom_sf(data = boundary,
                     fill = grDevices::adjustcolor(
                       map_palette$protected[["site"]], alpha.f = 0.12),
                     colour = map_palette$protected[["site"]],
                     linewidth = 0.5)

  if (nrow(strict)) {
    p <- p + ggplot2::geom_sf(data = strict, fill = NA,
                              colour = map_palette$protected[["strict"]],
                              linewidth = 0.45, linetype = "solid")
  }

  note <- NULL

  if (!nrow(inside)) {

    note <- paste0("No quality-checked GBIF record falls inside this site, ",
                   "so no record layer is drawn.")

  } else if (nrow(inside) > max_points) {

    grid <- dataset$record_density_grid
    grid$density_class <- factor(grid$density_class,
                                 levels = plain_text(density_labels))
    p <- p + ggplot2::geom_sf(data = grid,
                              ggplot2::aes(fill = .data$density_class),
                              colour = NA) +
      ggplot2::scale_fill_manual(values = stats::setNames(
        map_palette$density, plain_text(density_labels)), drop = FALSE)
    note <- paste0(
      "The ", fmt_int(nrow(inside)), " records in this site are above the ",
      fmt_int(max_points), "-record limit for a printed point map. They are ",
      "shown as record density per square kilometre instead; the points are ",
      "withheld rather than thinned, because a thinned scatter cannot be told ",
      "from a sparsely recorded site. Every record is in the GeoPackage.")

  } else {

    # `drop = TRUE`: the legend names the classes that are actually drawn. A
    # kingdom with no mark on the map is not a category a reader should have to
    # search for.
    inside$.kingdom <- droplevels(kingdom_group(inside$kingdom))
    p <- p + ggplot2::geom_sf(data = inside,
                              ggplot2::aes(colour = .data$.kingdom),
                              size = 0.7, alpha = 0.85) +
      ggplot2::scale_colour_manual(values = map_palette$kingdom, drop = TRUE)
    note <- paste0("All ", fmt_int(nrow(inside)),
                   " records inside the site are mapped.")
  }

  # The buffer sets the extent, so that what lies just outside the site is
  # visible — which is the comparison the buffer exists to support.
  box <- sf::st_bbox(buffer)
  p <- p +
    ggplot2::coord_sf(xlim = c(box[["xmin"]], box[["xmax"]]),
                      ylim = c(box[["ymin"]], box[["ymax"]]),
                      expand = TRUE) +
    ggplot2::labs(caption = note) +
    site_theme()

  attr(p, "map_note") <- note
  p
}


# ==============================================================================
# 9. RUNNING
# ==============================================================================

#' Are the outputs newer than everything they were built from?
#'
#' The code counts as an input. A changed report template with unchanged data
#' must regenerate, or a re-run would quietly republish the previous layout.
#'
#' @param outputs Paths that must exist.
#' @param inputs Paths they were built from.
#' @return `TRUE` when nothing needs doing.
outputs_up_to_date <- function(outputs, inputs) {

  outputs <- outputs[!is.na(outputs)]
  if (!length(outputs) || !all(file.exists(outputs))) return(FALSE)

  inputs <- inputs[!is.na(inputs) & file.exists(inputs)]
  if (!length(inputs)) return(TRUE)

  max(file.mtime(inputs)) <= min(file.mtime(outputs))
}

#' Render the PDF for one site
#'
#' The template is parameterised on the GeoPackage that was just written, not
#' on the context in memory, so the document and the file it accompanies are
#' built from the same bytes.
#'
#' @param dataset The site dataset.
#' @param out_dir The site's output directory.
#' @param cfg The configuration list.
#' @param command The command that reproduces the output.
#' @return The path to the PDF.
render_site_pdf <- function(dataset, out_dir, cfg, command) {

  if (!requireNamespace("quarto", quietly = TRUE)) {
    stop("Package 'quarto' is needed to render the PDF:\n",
         "  install.packages(\"quarto\")", call. = FALSE)
  }

  template <- cfg$path_template
  require_input(template, "the repository", "The report template")

  # Checked here rather than left to Quarto: the template includes the theme
  # by name, and a missing one fails 237 times over, once per site, with a
  # Typst error that does not say which file is gone.
  require_input(file.path(dirname(template), "gbif-report.typ"),
                "the repository", "The report's colour theme")

  slug <- dataset$slug
  gpkg <- file.path(out_dir, paste0(slug, ".gpkg"))
  require_input(gpkg, "Rscript site_reports.R --site <id>",
                "The site GeoPackage the report is built from")

  absolute <- function(p) normalizePath(p, winslash = "/", mustWork = FALSE)

  params <- list(
    gpkg           = absolute(gpkg),
    country        = absolute(cfg$path_boundary),
    municipalities = absolute(cfg$path_municipalities),
    national       = absolute(cfg$path_national_statistics),
    functions      = absolute(cfg$path_functions),
    site_report    = absolute(cfg$path_site_report),
    command        = command,
    max_points     = cfg$map_max_points
  )

  output <- paste0(slug, ".pdf")

  quarto::quarto_render(
    input          = template,
    output_file    = output,
    execute_params = params,
    quiet          = TRUE
  )

  # Quarto writes beside the template; the deliverable belongs with its
  # GeoPackage.
  produced <- file.path(dirname(template), output)
  target   <- file.path(out_dir, output)

  if (!file.exists(produced)) {
    stop("Quarto reported success but no PDF was found at ", produced,
         call. = FALSE)
  }

  if (file.exists(target)) unlink(target)
  ok <- file.rename(produced, target)
  if (!ok) {
    file.copy(produced, target, overwrite = TRUE)
    unlink(produced)
  }

  target
}

#' Append one row per site to the run manifest
#'
#' @param path The manifest CSV.
#' @param rows A tibble of manifest rows.
#' @return The path, invisibly.
append_run_manifest <- function(path, rows) {

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(rows, path, append = file.exists(path), na = "")
  invisible(path)
}

#' One manifest row
#'
#' @param ... Columns, in the documented order.
#' @return A one-row tibble.
manifest_row <- function(timestamp_utc, natda_id, national_id, slug, site_name,
                         records, species, gpkg, gpkg_bytes, pdf, pdf_bytes,
                         seconds, status, message = NA_character_) {
  dplyr::tibble(
    timestamp_utc = timestamp_utc, natda_id = natda_id,
    national_id = national_id, slug = slug, site_name = site_name,
    records = records, species = species,
    gpkg = gpkg, gpkg_bytes = gpkg_bytes, pdf = pdf, pdf_bytes = pdf_bytes,
    seconds = seconds, status = status, message = message
  )
}
