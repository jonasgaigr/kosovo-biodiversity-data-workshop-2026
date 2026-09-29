# ------------------------------------------------------------------------------
# R/functions.R
#
# Shared helper functions for the Kosovo GBIF biodiversity analysis.
#
# This file is sourced by BOTH `pipeline.R` (data preparation) and `report.qmd`
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
# Kosovo reference geography
# ------------------------------------------------------------------------------
#
# Every map, every area figure and the country-coordinate test all rest on one
# polygon, so it is worth being explicit about which one and why.
#
# The source is OpenStreetMap, not GADM. GADM 4.1 is the obvious choice — it is
# what GBIF filters on — but its Kosovo geometry is a heavily generalised
# outline, and the generalisation is large enough to change results rather than
# only appearance. Sampling each candidate border every 200 m and measuring to
# Eurostat's GISCO 1:1M line — an independent official digitisation of the same
# international border, taken from the Serbia polygon, since GISCO does not
# publish Kosovo separately:
#
#                       median deviation   90th percentile
#     GADM 4.1 level 0        587 m            2,980 m
#     OpenStreetMap            60 m              189 m
#
# Only the stretch that is a true international border is measured — sample
# points within 6 km of the GISCO line — because GISCO draws no Kosovo–Serbia
# boundary at all. The ratio holds at 3 km and at 10 km, so it is not an
# artefact of that threshold. The residual 60 m for OSM is GISCO's own
# generalisation; GADM's 587 m is GADM's.
#
# The areas say the same thing. Published figures for Kosovo cluster between
# 10,887 km² (World Bank) and 10,910 km²; OSM's polygon measures 10,898 km²,
# inside that range, and GADM's 10,828 km², below all of it. The two outlines
# disagree over 755 km² — 6.9 per cent of the country — with the lines up to
# 4.1 km apart.
#
# The practical consequence is not cartographic. GADM's outline bulges across
# the real border in places, and GBIF's `pred("gadm", "XKO")` filter therefore
# swept in 1,776 records that lie outside Kosovo. Their own publishers say so:
# 1,030 are stamped ME, 320 MK, 284 RS and 45 AL, against only 97 stamped XK.
# Screening against an accurate border removes them, which is what the
# country-coordinate test is for.
#
# The same swap fixes the administrative layer. GADM's 30 municipalities are
# the pre-2010 set; Kosovo has had 38 since the decentralisation, and OSM
# carries all of them.

#' Download (and cache) the GADM administrative geography for Kosovo
#'
#' Retained for two jobs, neither of them the reference boundary. It is the
#' polygon GBIF selected these records with, so it is the honest description of
#' the extract's extent; and it is the offline fallback for `kosovo_boundary()`
#' and `kosovo_municipalities()` when OpenStreetMap cannot be reached.
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

# Set once `osm_kosovo()` has given up, so that the two layers built from it
# fall back together rather than one each way. See the note there.
.osm_kosovo_state <- new.env(parent = emptyenv())

# Kosovo's 7 districts, keyed on the OpenStreetMap relation that carries each
# one. Districts are named after their principal town, and that town's name in
# both languages is the label wanted here: OSM's own "Rajoni i Ferizajt /
# Uroševački okrug" is a pair of adjectival forms, and the Albanian half is in
# the genitive "Rajoni i ..." governs, so neither half can simply be trimmed.
.osm_kosovo_districts <- c(
  "6898087" = "Ferizaj / Uroševac",
  "6898247" = "Gjakovë / Đakovica",
  "6898305" = "Gjilan / Gnjilane",
  "6898597" = "Mitrovicë / Kosovska Mitrovica",
  "6898457" = "Pejë / Peć",
  "6900417" = "Prishtinë / Priština",
  "6898227" = "Prizren"
)

# Kosovo's 38 municipalities, keyed on the OpenStreetMap relation that carries
# each one and labelled "Albanian / Serbian" from the official bilingual list.
#
# The names are given rather than read from the relations' `name:sq` and
# `name:sr` tags for the same reason the district labels are: the tags cannot
# be relied on. Three municipalities carry no `name:sr-Latn` at all, two of the
# ones that do misspell the Serbian word for municipality ("Opsrina",
# "Optsina"), and every Albanian name sits in the genitive that "Komuna e ..."
# governs — "Komuna e Deçanit" yields "Deçanit", not "Deçan". A published
# report should also not have its municipal labels change under it because
# someone retagged a relation.
.osm_kosovo_municipalities <- c(
  "1332170" = "Deçan / Dečan",
  "1332198" = "Dragash / Dragaš",
  "1332192" = "Ferizaj / Uroševac",
  "1332190" = "Fushë Kosovë / Kosovo Polje",
  "1332169" = "Gjakovë / Đakovica",
  "1332172" = "Gjilan / Gnjilane",
  "1332168" = "Gllogoc / Glogovac",
  "6901830" = "Graçanicë / Gračanica",
  "1332197" = "Hani i Elezit / Elez Han",
  "1332163" = "Istog / Istok",
  "1332191" = "Junik / Junik",
  "1332180" = "Kaçanik / Kačanik",
  "1332162" = "Kamenicë / Kamenica",
  "1332179" = "Klinë / Klina",
  "6901841" = "Kllokot / Klokot",
  "1332176" = "Leposaviq / Leposavić",
  "1332188" = "Lipjan / Lipljan",
  "1332165" = "Malishevë / Mališevo",
  "1332174" = "Mamushë / Mamuša",
  "1332167" = "Mitrovicë e Jugut / Kosovska Mitrovica",
  "7426353" = "Mitrovicë e Veriut / Severna Kosovska Mitrovica",
  "1332177" = "Novobërdë / Novo Brdo",
  "1332178" = "Obiliq / Obilić",
  "6901844" = "Partesh / Parteš",
  "1332187" = "Pejë / Peć",
  "1332182" = "Podujevë / Podujevo",
  "1332181" = "Prishtinë / Priština",
  "1332193" = "Prizren / Prizren",
  "1332196" = "Rahovec / Orahovac",
  "6903238" = "Ranillug / Ranilug",
  "1332171" = "Shtërpcë / Štrpce",
  "1332175" = "Shtime / Štimlje",
  "1332183" = "Skenderaj / Srbica",
  "1332166" = "Suharekë / Suva Reka",
  "1332194" = "Viti / Vitina",
  "1332164" = "Vushtrri / Vučitrn",
  "1332173" = "Zubin Potok / Zubin Potok",
  "1332195" = "Zveçan / Zvečan"
)

#' Assemble the polygon of one OpenStreetMap boundary relation
#'
#' GDAL's OSM driver is not used for this. It silently drops relations whose
#' rings it cannot close — for Kosovo it lost Prishtina and Kamenicë, two of
#' the thirty-eight municipalities and a fifth of the country by area, with no
#' warning and no error. Assembling the rings here from the member ways is both
#' complete and checkable: `st_polygonize()` is given the merged linework and
#' either returns closed rings or returns nothing at all.
#'
#' Ring assembly is planar, and that is load-bearing rather than a preference.
#' `st_polygonize()` and `st_line_merge()` are GEOS operations either way, but
#' `st_union()` on lon/lat goes through s2 unless told otherwise, and s2 works
#' on geodesic edges: it splits and re-orders the linework in ways the GEOS
#' steps downstream cannot then close. Left on, it cost five of the thirty-
#' eight municipalities — Ferizaj, Hani i Elezit, Mamushë, North Mitrovica and
#' Podujevë — quietly, on every run. Nothing here measures anything, so plane
#' geometry is the right tool; areas are computed later, in a projected CRS.
#'
#' @param el One `relation` element of an Overpass `out geom` response.
#' @return An `sfc` polygon in EPSG:4326, or `NULL` if the rings do not close.
osm_relation_polygon <- function(el) {

  s2 <- suppressMessages(sf::sf_use_s2(FALSE))
  on.exit(suppressMessages(sf::sf_use_s2(s2)), add = TRUE)

  members <- Filter(
    function(m) {
      identical(m$type, "way") &&
        (is.null(m$role) || m$role %in% c("outer", "inner", ""))
    },
    el$members
  )

  lines <- lapply(members, function(m) {
    g <- m$geometry
    if (is.null(g) || length(g) < 2) return(NULL)
    sf::st_linestring(cbind(vapply(g, function(p) p$lon, numeric(1)),
                            vapply(g, function(p) p$lat, numeric(1))))
  })
  lines <- lines[!vapply(lines, is.null, logical(1))]
  if (!length(lines)) return(NULL)

  # The member ways arrive in arbitrary order and arbitrary direction, which is
  # what `st_line_merge()` on the union exists to sort out. Inner rings look
  # after themselves: polygonising the whole linework yields faces, and
  # unioning the faces subtracts anything one of them encloses.
  rings <- try(
    {
      merged <- sf::st_line_merge(sf::st_union(sf::st_sfc(lines, crs = 4326)))
      sf::st_collection_extract(sf::st_polygonize(merged), "POLYGON")
    },
    silent = TRUE
  )
  if (inherits(rings, "try-error") || !length(rings)) return(NULL)

  sf::st_make_valid(sf::st_union(rings))
}

#' Fetch (and cache) Kosovo's administrative geography from OpenStreetMap
#'
#' One GeoPackage holds the country (relation 2088990), its 7 districts and its
#' 38 municipalities, so that the levels tile each other exactly and
#' `kosovo_boundary()` and `kosovo_municipalities()` cannot disagree along the
#' border. Nothing is written until the three layers have been checked to
#' actually tile: an incomplete answer from Overpass fails the run rather than
#' caching a boundary with a hole in it.
#'
#' The file is committed to the repository. A fresh clone therefore never
#' touches Overpass, which matters both because the public instance refuses
#' roughly one request in three at busy times and because a published report
#' should not silently re-cut its own boundaries against a moving source.
#' Delete the cache to rebuild it.
#'
#' @param cache_path GeoPackage used to cache the three layers.
#' @param endpoints Overpass instances, tried in order and each retried.
#' @param verbose Print progress messages.
#' @return The local path to the GeoPackage.
osm_kosovo <- function(cache_path = "data/osm_kosovo.gpkg",
                       endpoints = c("https://overpass-api.de/api/interpreter",
                                     "https://overpass.kumi.systems/api/interpreter"),
                       verbose = TRUE) {

  if (file.exists(cache_path)) return(cache_path)

  # A failure is remembered for the rest of the session. Two callers want this
  # geography — the national outline and the municipalities — and each falls
  # back to GADM on its own if it cannot have it. Without this, a build that
  # failed for one and succeeded for the other would pair a GADM outline with
  # OSM municipalities, which is the one combination guaranteed not to tile.
  # It also saves sitting through the retry loop a second time.
  if (isTRUE(.osm_kosovo_state$failed)) {
    stop("OpenStreetMap was already unreachable earlier in this session.",
         call. = FALSE)
  }
  on.exit(if (!file.exists(cache_path)) .osm_kosovo_state$failed <- TRUE,
          add = TRUE)

  # Planar throughout, for the reason given on `osm_relation_polygon()`: the
  # overlay work here is topological, and the one place an area is wanted
  # projects to UTM 34N first.
  s2 <- suppressMessages(sf::sf_use_s2(FALSE))
  on.exit(suppressMessages(sf::sf_use_s2(s2)), add = TRUE)

  stopifnot(requireNamespace("curl", quietly = TRUE),
            requireNamespace("jsonlite", quietly = TRUE))

  if (verbose) say("Building Kosovo's administrative geography from OpenStreetMap ...")

  # Every relation is asked for by id, and the answer is checked against the
  # list. Selecting them by tag instead — `admin_level` inside a bounding box —
  # reads better and cannot be checked: whatever comes back is by definition
  # the answer, so a run that quietly assembled 33 of the 38 municipalities
  # produced a layer that tiled the country apart from a 1,076 km² hole, and
  # nothing downstream had grounds to complain. (That particular loss was the
  # s2 problem noted on `osm_relation_polygon()`, but the point stands: it took
  # a comparison against a known list to notice it at all.) Two of the missing
  # units were Prishtina and Kamenicë, a fifth of the country between them.
  #
  # `out geom` inlines each member way's coordinates, which avoids pulling the
  # node table and cuts the response from 39 MB to 22 MB.
  ids <- c("2088990", names(.osm_kosovo_districts),
           names(.osm_kosovo_municipalities))

  query <- paste0(
    '[out:json][timeout:300];',
    'rel(id:', paste(ids, collapse = ","), ');',
    'out geom;'
  )

  # Overpass refuses a fair share of requests — 504 when the gateway gives up,
  # 429 when it is rate-limiting, and, most awkwardly, 200 with an HTML error
  # page when the dispatcher is busy. All three are transient and all three are
  # worth waiting out, so the loop is patient and says which one it hit; a
  # bare "declined" leaves the next person guessing whether the query is wrong.
  res <- NULL
  for (endpoint in endpoints) {
    for (attempt in 1:4) {
      # The query goes in the POST body, not as a multipart form: Overpass
      # answers 400 to a `multipart/form-data` request.
      h <- curl::new_handle(timeout = 600, connecttimeout = 30)
      curl::handle_setopt(h, post = TRUE, postfields = query)
      got <- tryCatch(curl::curl_fetch_memory(endpoint, handle = h),
                      error = function(e) conditionMessage(e))

      why <- if (is.character(got)) {
        got
      } else if (got$status_code != 200) {
        paste("HTTP", got$status_code)
      } else {
        txt <- rawToChar(got$content)
        Encoding(txt) <- "UTF-8"
        if (!startsWith(trimws(txt), "{")) {
          "the server answered with an error page"
        } else {
          res <- tryCatch(jsonlite::fromJSON(txt, simplifyVector = FALSE),
                          error = function(e) NULL)
          if (is.null(res)) "the response was not readable JSON" else NA_character_
        }
      }

      if (!is.na(why) && is.null(res)) {
        if (verbose) {
          say("  ... ", sub("^https://([^/]+).*", "\\1", endpoint), " declined (",
              why, "); attempt ", attempt, " of 4")
        }
        if (attempt < 4) Sys.sleep(30)
      } else {
        break
      }
    }
    if (!is.null(res)) break
  }

  if (is.null(res)) {
    stop("Could not get an answer out of any Overpass instance. The service ",
         "refuses requests when busy; try again in a few minutes.",
         call. = FALSE)
  }

  elements <- Filter(function(e) identical(e$type, "relation"), res$elements)
  geoms    <- lapply(elements, osm_relation_polygon)
  keep     <- !vapply(geoms, is.null, logical(1))
  elements <- elements[keep]
  geoms    <- geoms[keep]

  adm <- if (length(geoms)) {
    sf::st_sf(
      osm_id   = vapply(elements, function(e) as.character(e$id), character(1)),
      geometry = do.call(c, geoms),
      crs      = 4326
    )
  } else {
    NULL
  }

  absent <- setdiff(ids, adm$osm_id)
  if (length(absent)) {
    labels <- c("2088990" = "Kosovo", .osm_kosovo_districts,
                .osm_kosovo_municipalities)[absent]
    stop("OpenStreetMap returned no usable geometry for ", length(absent),
         " of the ", length(ids), " expected relations: ",
         paste(sprintf("%s (%s)", absent, labels), collapse = ", "),
         ". Re-run to try Overpass again.", call. = FALSE)
  }

  country   <- adm[adm$osm_id == "2088990", ]
  districts <- adm[adm$osm_id %in% names(.osm_kosovo_districts), ]
  municipal <- adm[adm$osm_id %in% names(.osm_kosovo_municipalities), ]

  districts$district    <- unname(.osm_kosovo_districts[districts$osm_id])
  municipal$municipality <- unname(.osm_kosovo_municipalities[municipal$osm_id])

  # Kllokot was carved out of Viti in 2010 and OSM never shrank Viti to match,
  # so the two relations overlap exactly on Kllokot's 23.4 km². Left alone the
  # municipalities would not partition the country, and a record in Kllokot
  # would fall in two of them. Subtracting the child from the parent is the
  # only repair the layer needs: with it, the 38 units sum to the national
  # polygon to four decimal places of a square kilometre.
  viti    <- which(municipal$osm_id == "1332194")
  kllokot <- which(municipal$osm_id == "6901841")
  if (length(viti) == 1 && length(kllokot) == 1) {
    sf::st_geometry(municipal)[viti] <- sf::st_make_valid(sf::st_difference(
      sf::st_geometry(municipal)[viti], sf::st_geometry(municipal)[kllokot]
    ))
  }

  municipal$district <- vapply(
    suppressMessages(sf::st_intersects(
      suppressWarnings(sf::st_point_on_surface(sf::st_geometry(municipal))),
      sf::st_geometry(districts)
    )),
    function(i) if (length(i)) districts$district[i[1]] else NA_character_,
    character(1)
  )
  if (anyNA(municipal$district)) {
    stop("These municipalities fall in no district: ",
         paste(municipal$municipality[is.na(municipal$district)],
               collapse = ", "), call. = FALSE)
  }

  # The levels have to tile each other, because the coverage figures divide
  # records by municipal area and the maps draw one on top of the other. Three
  # ways of failing are checked: ground the units miss, ground they add, and
  # ground two of them claim at once. A tenth of a square kilometre is generous
  # for a check whose observed failure mode is hundreds.
  #
  # Measured in UTM 34N, the projection the rest of the pipeline uses for
  # Kosovo, rather than on the ellipsoid: the overlay itself is planar, so the
  # areas being compared should be too.
  km2 <- function(g) {
    a <- sf::st_area(sf::st_transform(g, 32634))
    if (!length(a)) 0 else as.numeric(sum(a)) / 1e6
  }
  for (level in list(list("districts", districts),
                     list("municipalities", municipal))) {
    parts   <- sf::st_geometry(level[[2]])
    covered <- sf::st_union(parts)
    worst <- max(
      km2(sf::st_difference(sf::st_geometry(country), covered)),
      km2(sf::st_difference(covered, sf::st_geometry(country))),
      km2(parts) - km2(covered)
    )
    if (worst > 0.1) {
      stop("The ", level[[1]], " do not tile the national outline: worst ",
           "discrepancy ", signif(worst, 3), " km².", call. = FALSE)
    }
  }

  municipal <- municipal[order(municipal$municipality), ]
  districts <- districts[order(districts$district), ]

  dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
  sf::st_write(country[, "osm_id"], cache_path, layer = "ADM_0",
               delete_dsn = TRUE, quiet = TRUE)
  sf::st_write(districts[, c("osm_id", "district")], cache_path, layer = "ADM_1",
               append = FALSE, quiet = TRUE)
  sf::st_write(municipal[, c("osm_id", "municipality", "district")], cache_path,
               layer = "ADM_2", append = FALSE, quiet = TRUE)

  if (verbose) {
    say("  ... ", nrow(municipal), " municipalities in ", nrow(districts),
        " districts, ", fmt_int(nrow(sf::st_coordinates(country))),
        " vertices on the national outline.")
  }

  cache_path
}

#' Build (and cache) a national boundary polygon for Kosovo
#'
#' This polygon serves two purposes:
#'   1. It is the reference layer for the country-coordinate mismatch test in
#'      `CoordinateCleaner::clean_coordinates()`.
#'   2. It is drawn as a context outline on the Leaflet maps.
#'
#' The source is OpenStreetMap, for the reasons set out at the head of this
#' section: 19,268 vertices against GADM's 1,210, an area within 7 km² of the
#' national statistical office's figure rather than 77 km² short of it, and a
#' line that follows Eurostat's independent digitisation of the international
#' border to a median 60 m rather than 587 m.
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
#' @param osm_path Cache path for the OpenStreetMap geography.
#' @param gadm_path Cache path for the GADM archive used as a fallback.
#' @return An `sf` polygon with `iso_a3` and `source` columns, in EPSG:4326.
kosovo_boundary <- function(iso3 = "XKX",
                            cache_path = "data/kosovo_boundary.gpkg",
                            osm_path   = "data/osm_kosovo.gpkg",
                            gadm_path  = "data/gadm41_XKO.gpkg") {

  if (!is.null(cache_path) && file.exists(cache_path)) {
    return(sf::st_read(cache_path, quiet = TRUE))
  }

  geom <- try(
    sf::st_geometry(sf::st_read(osm_kosovo(cache_path = osm_path),
                                layer = "ADM_0", quiet = TRUE)),
    silent = TRUE
  )

  src <- "OpenStreetMap"

  # Both fallbacks are materially different references rather than slightly
  # coarser ones, so each is warned about and recorded in the layer — the
  # report states which boundary was used rather than leaving the reader to
  # guess. The underlying message is carried through, because "Overpass was
  # busy" and "the geometry did not validate" call for different responses and
  # a bare "could not build" hides which one happened.
  if (inherits(geom, "try-error")) {
    warning("Could not build the OpenStreetMap boundary (",
            conditionMessage(attr(geom, "condition")),
            "); falling back to the generalised GADM 4.1 outline.",
            call. = FALSE)

    geom <- try(
      sf::st_geometry(sf::st_read(gadm_kosovo(cache_path = gadm_path),
                                  layer = "ADM_ADM_0", quiet = TRUE)),
      silent = TRUE
    )
    src <- "GADM 4.1 level 0"
  }

  if (inherits(geom, "try-error")) {
    warning("Could not fetch the GADM boundary either; falling back to the ",
            "coarser Natural Earth 1:50m outline.", call. = FALSE)

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
# Nationally designated protected areas
# ------------------------------------------------------------------------------
#
# GBIF says where species have been recorded. The protected-area network says
# where the state has already accepted an obligation to look after them. Laying
# one over the other answers the first question a conservation officer asks of
# an occurrence dataset — is this population inside a designated site, or
# outside every one of them? — and that is what this section exists to support.
#
# The source is the European Environment Agency's inventory of Nationally
# designated areas (NatDA), long known as the Common Database on Designated
# Areas (CDDA). It is the channel through which 38 Eionet countries report
# their protected areas to the World Database on Protected Areas, so a
# country's entry is its own official list rather than a third-party
# compilation. Kosovo reports to it under UNSCR 1244/99.
#
# Version 24 (July 2026) is used throughout, licensed CC-BY 4.0 to the EEA.

cdda_source <- list(
  version   = "v24 (July 2026)",
  licence   = "CC-BY 4.0",
  copyright = "European Environment Agency",
  doi       = "10.2909/028003e7-7585-4d69-92fc-7f81e0cc2340",
  uuid      = "028003e7-7585-4d69-92fc-7f81e0cc2340",

  # The GeoPackage, and not the File Geodatabase the same share also offers,
  # even though the GDB is 510 MB against the GeoPackage's 1.7 GB. Two reasons,
  # and the second is decisive:
  #
  #   1. Nothing is downloaded. A GeoPackage is a SQLite database with an
  #      R-tree spatial index, the EEA's server honours HTTP range requests,
  #      and GDAL's /vsicurl/ turns those three facts into a query that fetches
  #      only the pages covering the bounding box it is given. Kosovo's 256
  #      features come back in about a minute and a few megabytes. Pulling the
  #      GDB would move half a gigabyte to arrive at the same place.
  #
  #   2. GDAL cannot read the point geometry out of the GDB at all. Its
  #      OpenFileGDB driver returns 3,133 empty GEOMETRYCOLLECTIONs for the
  #      `ProtectedSite_Multipoint` table — verified against GDAL 3.12.1, and
  #      not fixable from here by promote_to_multi, the SQLite dialect or
  #      ogr2ogr. Those are the 189 Kosovo sites recorded as a point rather
  #      than a boundary, three quarters of the national register, and they
  #      would have gone missing silently. The GeoPackage stores plain WKB and
  #      reads correctly.
  file      = "NatDA_2026_v01_public_EPSG4326.gpkg",

  # Fallback only — see `cdda_share_token()`.
  token     = "8ribwpg4cZNkC3T"
)

#' Resolve the EEA download token for a dataset
#'
#' The EEA serves its spatial data from a Nextcloud share whose token is not
#' part of the citable identifier and changes whenever a file is republished.
#' The stable address is the dataset UUID, which redirects to the share, so the
#' token is read from that page at run time. `fallback` — the token current
#' when this was written — is used only if the lookup fails, which keeps a
#' transient network problem from stopping the pipeline dead.
#'
#' @param uuid EEA datahub dataset UUID.
#' @param fallback Token to use if the page cannot be read.
#' @return A share token.
cdda_share_token <- function(uuid = cdda_source$uuid,
                             fallback = cdda_source$token) {

  page <- try(
    suppressWarnings(
      readLines(paste0("https://sdi.eea.europa.eu/data/", uuid), warn = FALSE)
    ),
    silent = TRUE
  )

  if (inherits(page, "try-error")) return(fallback)

  hit <- regmatches(page, regexpr('sharingToken"[^>]*value="[^"]+"', page))
  hit <- hit[nzchar(hit)]

  if (!length(hit)) return(fallback)

  sub('.*value="([^"]+)".*', "\\1", hit[1])
}

#' GDAL virtual path to the EEA GeoPackage
#'
#' @return A `/vsicurl/` path GDAL can open for random access.
cdda_url <- function() {
  paste0("/vsicurl/https://sdi.eea.europa.eu/datashare/s/", cdda_share_token(),
         "/download?files=", cdda_source$file)
}

#' Build (and cache) the nationally designated protected areas of Kosovo
#'
#' Kosovo reports 256 designated areas, and they arrive in two shapes. Sixty-
#' seven carry a mapped boundary; the remaining 189 are recorded as a single
#' representative point. That split is not a defect in the data — it is what
#' the sites are. Every national park, strict nature reserve, protected
#' landscape, nature park and wetland is a polygon; the 189 points are all
#' natural monuments (`XK06`), which in Kosovo means individual veteran trees,
#' springs and caves, most of them under a tenth of a hectare. A point is an
#' honest representation of a 500 m² stand of oak, and drawing it as a polygon
#' would imply a precision the register does not claim.
#'
#' The two are kept as two layers of one GeoPackage rather than forced into a
#' single mixed-geometry table: only the polygons can carry a point-in-polygon
#' test, and a caller that asks for `"polygons"` should not have to remember to
#' filter out 189 features that would silently never match.
#'
#' A second distinction runs through the polygons. Nineteen of the 67 are
#' `strictProtectionBoundary` features — the strictly protected core of a site
#' that is already listed in its own right, not a separate site. Summing the
#' areas of all 67 would therefore count that land twice. `designated_area_type`
#' keeps the two apart, and `assign_protected_area()` uses only the sites.
#'
#' @param cache_path GeoPackage used to cache both layers.
#' @param layer `"polygons"` for the mapped boundaries, `"points"` for the
#'   representative points of the sites that have no boundary.
#' @param verbose Print progress messages.
#' @return An `sf` layer of Kosovo's nationally designated areas.
kosovo_protected_areas <- function(
    cache_path = "data/kosovo_protected_areas.gpkg",
    layer      = c("polygons", "points"),
    verbose    = TRUE) {

  layer <- match.arg(layer)
  gpkg_layer <- paste0("protected_area_", layer)

  if (!is.null(cache_path) && file.exists(cache_path)) {
    return(sf::st_read(cache_path, layer = gpkg_layer, quiet = TRUE))
  }

  if (verbose) {
    say("Reading the Kosovo designated areas from the EEA inventory ",
        cdda_source$version, " ...")
  }

  # Tuned for reading a 1.7 GB SQLite file over HTTP: a 1 MB chunk keeps the
  # number of range requests down, and a cache large enough to hold everything
  # fetched stops GDAL re-requesting pages it has already seen while it walks
  # the R-tree.
  old <- Sys.getenv(c("GDAL_DISABLE_READDIR_ON_OPEN", "CPL_VSIL_CURL_CHUNK_SIZE",
                      "CPL_VSIL_CURL_CACHE_SIZE", "GDAL_HTTP_MAX_RETRY",
                      "GDAL_HTTP_RETRY_DELAY"), names = TRUE)
  Sys.setenv(GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR",
             CPL_VSIL_CURL_CHUNK_SIZE     = "1048576",
             CPL_VSIL_CURL_CACHE_SIZE     = "524288000",
             GDAL_HTTP_MAX_RETRY          = "3",
             GDAL_HTTP_RETRY_DELAY        = "2")
  on.exit(do.call(Sys.setenv, as.list(old)), add = TRUE)

  src <- cdda_url()

  # Geometry comes through the spatial index, not through a WHERE clause on the
  # country code. `ProtectedSite` holds 142,000 features for the whole of
  # Europe and carries no index on `natDACountryCode`, so filtering on the
  # attribute would drag the entire table across the network; a bounding box
  # touches only the pages that could contain Kosovo. The box is deliberately
  # generous, and the country code does the exact filtering afterwards.
  box <- sf::st_as_text(sf::st_as_sfc(sf::st_bbox(
    c(xmin = 19.9, ymin = 41.75, xmax = 21.7, ymax = 43.25), crs = 4326
  )))

  sites <- sf::st_read(src, layer = "ProtectedSite", wkt_filter = box,
                       quiet = TRUE)
  sites <- sites[!is.na(sites$natDACountryCode) &
                   sites$natDACountryCode == "XK", ]

  # The two attribute tables are small enough to fetch by attribute:
  # `DesignatedArea` carries one row per designated area — the designation
  # type, the IUCN management category, the reported area — and
  # `DesignationType` is where those type codes acquire names. Kosovo's are
  # given in Albanian and in English, so both are carried through, for the same
  # reason the municipal layer is bilingual.
  areas <- sf::st_read(
    src, query = "SELECT * FROM DesignatedArea WHERE natDACountryCode = 'XK'",
    quiet = TRUE)

  types <- sf::st_read(
    src, query = "SELECT * FROM DesignationType WHERE natDACountryCode = 'XK'",
    quiet = TRUE) |>
    dplyr::select(
      designation_code = "designationTypeCode",
      designation      = "designationTypeNameEnglish",
      designation_sq   = "designationTypeName",
      authority        = "competentAuthorityOrganisationName"
    ) |>
    dplyr::distinct(.data$designation_code, .keep_all = TRUE)

  attributes_tbl <- areas |>
    dplyr::transmute(
      natda_id             = as.character(.data$natDAId),
      national_id          = as.character(.data$nationalId),
      site_name            = .data$siteName,
      designation_code     = .data$designationTypeCode,
      designated_area_type = .data$designatedAreaType,
      # NOT the Red List category. This is the IUCN protected-area MANAGEMENT
      # category (Ia, Ib, II, III, V) — a statement about how a site is run,
      # not about how likely a species is to go extinct. The two share an
      # acronym and nothing else, and this report shows both, so the column is
      # named at length deliberately.
      iucn_management_category = .data$iucnCategory,
      reported_area_ha     = suppressWarnings(as.numeric(.data$siteArea)),
      designation_year     = suppressWarnings(
                               as.integer(.data$legalFoundationDate)),
      ecosystem_type       = .data$majorEcosystemType,
      management_plan      = .data$managementPlanPA
    )

  assemble <- function(g) {
    sf::st_sf(
      natda_id = as.character(g$natDAId),
      geometry = sf::st_geometry(g)
    ) |>
      dplyr::left_join(attributes_tbl, by = "natda_id") |>
      dplyr::left_join(types, by = "designation_code") |>
      sf::st_make_valid() |>
      sf::st_transform(4326) |>
      dplyr::relocate("geometry", .after = dplyr::last_col())
  }

  is_point <- sf::st_geometry_type(sites) %in% c("POINT", "MULTIPOINT")

  polygons <- assemble(sites[!is_point, ])
  points   <- assemble(sites[is_point, ])

  # Measured area, alongside the area the country reported. They are not the
  # same number, and the difference is worth being able to see: the reported
  # figure is the legal extent named in the designation act, the measured one
  # is what the digitised boundary actually encloses.
  polygons$area_km2 <- as.numeric(
    units::set_units(sf::st_area(sf::st_transform(polygons, 32634)), "km^2")
  )

  polygons <- dplyr::arrange(polygons, dplyr::desc(.data$area_km2))
  points   <- dplyr::arrange(points, .data$site_name)

  if (!is.null(cache_path)) {
    dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
    sf::st_write(polygons, cache_path, layer = "protected_area_polygons",
                 append = FALSE, quiet = TRUE)
    sf::st_write(points, cache_path, layer = "protected_area_points",
                 append = FALSE, quiet = TRUE)
  }

  if (layer == "polygons") polygons else points
}

#' Attach the protected area each record falls in
#'
#' Tested against the designated sites only. The 19 strict-protection
#' boundaries are nested inside sites that are already in the layer, so
#' including them would let one record match two features and inflate every
#' count that follows; they are reported separately, through
#' `strictlyProtected`.
#'
#' Where a record falls inside more than one site — seven of Kosovo's sites
#' overlap along their edges, though none is wholly inside another — the
#' smallest is taken. The smallest site is the most specific statement anyone
#' has made about that ground, and it is the one a reader chasing the record
#' would want named.
#'
#' @param d Occurrence data frame carrying decimal coordinates.
#' @param protected_areas Polygon layer from `kosovo_protected_areas()`.
#' @return `d` with `protectedArea`, `protectedAreaDesignation` and
#'   `strictlyProtected` columns added.
assign_protected_area <- function(d, protected_areas) {

  pts <- sf::st_as_sf(
    d[, c("decimalLongitude", "decimalLatitude")],
    coords = c("decimalLongitude", "decimalLatitude"), crs = 4326
  )

  sites  <- protected_areas[
    protected_areas$designated_area_type == "designatedSite", ]
  strict <- protected_areas[
    protected_areas$designated_area_type == "strictProtectionBoundary", ]

  hit <- suppressMessages(sf::st_intersects(pts, sites))

  # Smallest containing site, as documented above.
  idx <- vapply(
    hit,
    function(i) if (length(i)) i[which.min(sites$area_km2[i])] else NA_integer_,
    integer(1)
  )

  d$protectedArea            <- sites$site_name[idx]
  d$protectedAreaDesignation <- sites$designation[idx]

  d$strictlyProtected <- lengths(
    suppressMessages(sf::st_intersects(pts, strict))
  ) > 0

  d
}

#' Summarise occurrence records by protected area
#'
#' Every polygon in the layer is returned, but the two kinds of polygon are
#' counted differently, and for a reason worth stating because it decides
#' whether the column can be added up.
#'
#' The designated sites are counted from the `protectedArea` stamp that
#' `assign_protected_area()` left on each record. That stamp names one site per
#' record, so the counts partition the records and the column sums to the
#' number of records inside the network. Counting each site by intersection
#' instead would give 21,524 where 21,069 records are actually inside: 455 of
#' them fall in two sites at once, along the edges where seven of Kosovo's
#' sites overlap, and each would be counted twice.
#'
#' The strict-protection boundaries cannot use that stamp — they are not the
#' record's site, they are a zone inside it — so they are counted by direct
#' intersection. None of them overlaps another, so those counts are exact too.
#' What the two must not do is be added together: every record inside a strict
#' boundary is already counted in the site that contains it.
#'
#' @param d Occurrence data with a `protectedArea` column and coordinates.
#' @param protected_areas Polygon layer from `kosovo_protected_areas()`.
#' @return A tibble of protected areas with record and species counts.
summarise_protected_areas <- function(d, protected_areas) {

  flat <- if (inherits(d, "sf")) sf::st_drop_geometry(d) else d

  by_name <- flat |>
    dplyr::filter(!is.na(.data$protectedArea)) |>
    dplyr::group_by(site_name = .data$protectedArea) |>
    dplyr::summarise(
      records = dplyr::n(),
      species = dplyr::n_distinct(
        .data$species[!is.na(.data$species) & nzchar(.data$species)]),
      .groups = "drop"
    )

  # The strict boundaries, by intersection.
  pts <- if (inherits(d, "sf")) {
    sf::st_geometry(d)
  } else {
    sf::st_geometry(sf::st_as_sf(
      flat[, c("decimalLongitude", "decimalLatitude")],
      coords = c("decimalLongitude", "decimalLatitude"), crs = 4326))
  }

  strict <- protected_areas[
    protected_areas$designated_area_type == "strictProtectionBoundary", ]

  by_strict <- if (nrow(strict)) {
    inside <- suppressMessages(sf::st_intersects(strict, pts))
    dplyr::tibble(
      natda_id = strict$natda_id,
      records_strict = lengths(inside),
      species_strict = vapply(inside, function(i) {
        s <- flat$species[i]
        dplyr::n_distinct(s[!is.na(s) & nzchar(s)])
      }, integer(1))
    )
  } else {
    dplyr::tibble(natda_id = character(), records_strict = integer(),
                  species_strict = integer())
  }

  protected_areas |>
    sf::st_drop_geometry() |>
    dplyr::left_join(by_name, by = "site_name") |>
    dplyr::left_join(by_strict, by = "natda_id") |>
    dplyr::mutate(
      records = dplyr::coalesce(.data$records_strict, .data$records, 0L),
      species = dplyr::coalesce(.data$species_strict, .data$species, 0L),
      records_per_km2 = ifelse(.data$area_km2 > 0,
                               .data$records / .data$area_km2, NA_real_)
    ) |>
    dplyr::select(-"records_strict", -"species_strict") |>
    dplyr::arrange(dplyr::desc(.data$area_km2))
}

# ------------------------------------------------------------------------------
# CORINE Land Cover and potential Natura 2000 habitats
# ------------------------------------------------------------------------------
#
# The protected-area register says where the state already looks after land.
# This section asks the question a Natura 2000 gap analysis starts from: where
# does natural and semi-natural land cover suggest Annex I habitats could
# occur, and how much of it lies outside every designated site?
#
# The answer is a screen, not a habitat map. CORINE Land Cover is interpreted
# from satellite imagery at a 25 ha minimum mapping unit and a 100 m minimum
# width, it records land cover rather than vegetation, and a class such as
# "Broad-leaved forest" corresponds to half a dozen Annex I types or to none,
# depending on elevation, substrate and management. The translation from one
# to the other is therefore kept out of the code: it lives in
# `data/crosswalk_clc_annex1.csv`, one row per CLC class, where a specialist can
# read and correct it without touching R.
#
# Every area in this section is measured in EPSG:3035, the ETRS89 Lambert
# Azimuthal Equal-Area projection that CLC itself is produced in. The rest of
# the report measures in UTM 34N, which is conformal rather than equal-area and
# reads Kosovo about 0.08 per cent small (a scale factor of 0.9996, squared);
# harmless for record densities, but an area balance should be done in an
# equal-area CRS, and here it is.

#' Provenance of each CORINE Land Cover vintage the pipeline knows how to use
#'
#' Keyed by reference year. A vintage is only usable once its DOI, version,
#' licence and access points are recorded here, so that the report can never
#' publish figures from a layer it cannot cite. CLC2018 is the most recent
#' vintage the Copernicus Land Monitoring Service had published when this was
#' written (checked against the CLMS catalogue, 29 September 2026): CLC2024 is
#' in production, and when it appears it needs one more entry below and a
#' change of `clc_vintage` in `pipeline.R`.
#'
#' `service` is the EEA's own map service for the vector layer, in the native
#' EPSG:3035. It is not a third-party mirror: the CLMS product page names the
#' same server as the dataset's REST access point. It is used because it needs
#' no login, where the CLMS download API needs an EU Login account and a token.
clc_sources <- list(
  "2018" = list(
    title        = "CORINE Land Cover 2018 (vector), Europe, 6-yearly",
    version      = "V2020_20u1 (May 2020)",
    doi          = "10.2909/71c95a07-e296-44fc-b22b-415f42acfdf0",
    licence      = paste("Copernicus data and information policy: full, free",
                         "and open access under Commission Delegated",
                         "Regulation (EU) No 1159/2013"),
    # Verbatim from the CLMS data policy, "For added products or derivative
    # works" — which is what a clipped, reclassified and simplified layer is.
    attribution  = paste("Generated using European Union's Copernicus Land",
                         "Monitoring Service information"),
    product_page = "https://land.copernicus.eu/en/products/corine-land-cover/clc2018",
    service      = paste0("https://image.discomap.eea.europa.eu/arcgis/rest/",
                          "services/Corine/CLC2018_LAEA/MapServer/0"),
    code_field   = "Code_18",
    # The same data as rendered tiles, in the official CLC palette. Layer 12 is
    # the 100 m raster, drawn at scales above 1:250,000; layer 13 the vector,
    # drawn below it. Asking for both gives whichever suits the zoom.
    wms          = paste0("https://image.discomap.eea.europa.eu/arcgis/",
                          "services/Corine/CLC2018_WM/MapServer/WMSServer"),
    wms_layers   = "12,13"
  )
)

#' Provenance of the biogeographical regions layer
#'
#' The official delineation used by the Habitats Directive and by the Bern
#' Convention's Emerald Network, which is why it covers Kosovo at all. The EEA
#' has registered no DOI for it (DataCite returns nothing for either of its
#' identifiers, checked 29 September 2026), so it is cited by its catalogue
#' record instead.
biogeo_source <- list(
  title      = "Biogeographical regions, Europe 2016, ver. 1",
  version    = "edition 01.00, 26 January 2016",
  doi        = NA_character_,
  identifier = "c6d27566-e699-4d58-a132-bbe3fe01491b",
  catalogue  = paste0("https://sdi.eea.europa.eu/catalogue/srv/api/records/",
                      "c6d27566-e699-4d58-a132-bbe3fe01491b"),
  licence    = "CC-BY 4.0",
  copyright  = paste("European Environment Agency (EEA); administrative",
                     "boundaries &copy; EuroGeographics, &copy; FAO (UN),",
                     "&copy; TurkStat, source: European Commission &ndash;",
                     "Eurostat/GISCO"),
  service    = paste0("https://bio.discomap.eea.europa.eu/arcgis/rest/services/",
                      "BioRegions/BiogeographicalRegions_LAEA/MapServer/0")
)

#' Page through an ArcGIS feature layer and return an `sf` layer
#'
#' The EEA's map services answer at most 1,000 features a request, so the query
#' is repeated with an offset until a short page comes back. Geometry is asked
#' for in `out_sr` and at full resolution: no `maxAllowableOffset`, because the
#' areas computed downstream should be the layer's own, not a generalisation's.
#'
#' An ArcGIS server reports a failed query as HTTP 200 with an `error` object in
#' the body, so the body is checked as well as the status code.
#'
#' @param layer_url The feature layer, ending in `/MapServer/<id>`.
#' @param bbox Query envelope in EPSG:4326, as xmin, ymin, xmax, ymax.
#' @param fields Attribute fields to return.
#' @param out_sr EPSG code of the geometry returned.
#' @param where Attribute filter.
#' @param page_size Features per request; the server's own maximum.
#' @param verbose Print progress.
#' @return An `sf` layer in `out_sr`.
arcgis_query_sf <- function(layer_url, bbox, fields = "*", out_sr = 3035,
                            where = "1=1", page_size = 1000, verbose = TRUE) {

  parts  <- list()
  offset <- 0

  # Padded by about a kilometre, so that rounding the envelope can never leave
  # the edge of the area of interest outside it.
  envelope <- sprintf("%.5f", as.numeric(bbox) + c(-0.01, -0.01, 0.01, 0.01))

  repeat {
    args <- c(where = where,
              geometry = paste(envelope, collapse = ","),
              geometryType = "esriGeometryEnvelope", inSR = "4326",
              spatialRel = "esriSpatialRelIntersects", outFields = fields,
              outSR = out_sr, orderByFields = "OBJECTID",
              resultOffset = offset, resultRecordCount = page_size,
              f = "geojson")
    url <- paste0(layer_url, "/query?",
                  paste0(names(args), "=", curl::curl_escape(args),
                         collapse = "&"))

    txt <- NULL
    for (attempt in 1:3) {
      got <- tryCatch(
        curl::curl_fetch_memory(url, handle = curl::new_handle(timeout = 300)),
        error = function(e) conditionMessage(e))
      why <- if (is.character(got)) {
        got
      } else if (got$status_code != 200) {
        paste("HTTP", got$status_code)
      } else {
        body <- rawToChar(got$content)
        Encoding(body) <- "UTF-8"
        if (grepl('^\\s*\\{\\s*"error"', body)) substr(body, 1, 200) else {
          txt <- body
          NA_character_
        }
      }
      if (!is.null(txt)) break
      if (verbose) say("  ... map service declined (", why, "); attempt ",
                       attempt, " of 3")
      if (attempt < 3) Sys.sleep(15)
    }
    if (is.null(txt)) {
      stop("The EEA map service did not answer (", why, "): ", layer_url,
           call. = FALSE)
    }

    if (grepl('"features"\\s*:\\s*\\[\\s*\\]', txt)) break

    page <- sf::st_read(txt, quiet = TRUE)

    # The GeoJSON carries its CRS as a `crs` member naming EPSG:3035. GDAL
    # honours it; a reader that did not would silently take the metres for
    # degrees, so the CRS is checked rather than assumed.
    if (!identical(sf::st_crs(page)$epsg, as.integer(out_sr))) {
      stop("The map service returned geometry in ", sf::st_crs(page)$input,
           " rather than EPSG:", out_sr, ".", call. = FALSE)
    }

    parts[[length(parts) + 1]] <- page
    offset <- offset + nrow(page)
    if (verbose) say("  ... ", fmt_int(offset), " features")
    if (nrow(page) < page_size) break
  }

  if (!length(parts)) {
    stop("The map service returned no features for this area: ", layer_url,
         call. = FALSE)
  }
  do.call(rbind, parts)
}

#' Reduce a layer to its polygons, one row per feature, as MULTIPOLYGON
#'
#' Clipping a polygon layer to an outline returns a mix of POLYGON,
#' MULTIPOLYGON and — where a polygon only touches the outline — a
#' GEOMETRYCOLLECTION holding stray lines and points. Those have no area, and
#' left in they break every later step that expects polygons.
#'
#' @param x An `sf` layer.
#' @param id Column that identifies a feature, so that the pieces of one
#'   collection are put back together rather than split into several rows.
#' @return `x`, polygons only, cast to MULTIPOLYGON.
polygons_only <- function(x, id) {
  x <- x[!sf::st_is_empty(x), ]
  if (any(sf::st_geometry_type(x) == "GEOMETRYCOLLECTION")) {
    x <- suppressWarnings(sf::st_collection_extract(x, "POLYGON"))
  }
  x <- sf::st_cast(x, "MULTIPOLYGON", warn = FALSE)

  # A collection with two polygon parts comes out of the extraction as two
  # rows. The parts are disjoint by construction, so combining them is exact.
  dup <- x[[id]][duplicated(x[[id]])]
  if (length(dup)) {
    single <- x[!x[[id]] %in% dup, ]
    multi  <- x[x[[id]] %in% dup, ]
    merged <- do.call(rbind, lapply(split(multi, multi[[id]]), function(p) {
      g <- sf::st_cast(sf::st_combine(sf::st_geometry(p)), "MULTIPOLYGON")
      sf::st_set_geometry(p[1, ], g)
    }))
    x <- rbind(single, merged)
  }
  x
}

#' Build (and cache) CORINE Land Cover for Kosovo
#'
#' Clipped to the OpenStreetMap national outline — the same polygon every
#' other layer in the report is screened against, and not GADM's, for the
#' reasons given at the top of this file. Only the clipped extract is ever
#' stored; the pan-European product is never written to disk.
#'
#' Two routes to the data, tried in this order:
#'
#' 1. `clc_path`, a vector file downloaded by hand from the CLMS portal (the
#'    GeoPackage or File Geodatabase of the chosen vintage). The portal needs an
#'    EU Login, so the path is configuration, never a credential in code. Only
#'    the pages of the file that cover Kosovo are read.
#' 2. Otherwise the EEA's map service, which needs no account. It is the
#'    default because it keeps `Rscript pipeline.R` working from a clean clone.
#'
#' The cache records which route built it (`source`) and which vintage
#' (`vintage`), and a cache of another vintage is rebuilt rather than trusted.
#'
#' @param boundary National outline from `kosovo_boundary()`.
#' @param vintage CLC reference year; must be a key of `clc_sources`.
#' @param cache_path GeoPackage used to cache the clipped extract.
#' @param clc_path Optional path to a manually downloaded CLC vector file.
#' @param verbose Print progress messages.
#' @return An `sf` layer in EPSG:3035 with `clc_id`, `clc_code`, `area_ha`,
#'   `vintage` and `source`.
kosovo_clc <- function(boundary, vintage = "2018",
                       cache_path = paste0("data/kosovo_clc", vintage, ".gpkg"),
                       clc_path = "", verbose = TRUE) {

  src <- clc_sources[[vintage]]
  if (is.null(src)) {
    stop("No provenance is recorded for CLC vintage '", vintage, "'. Add its ",
         "title, version, DOI, licence and access points to `clc_sources` in ",
         "R/functions.R before using it.", call. = FALSE)
  }

  if (!is.null(cache_path) && file.exists(cache_path)) {
    cached <- sf::st_read(cache_path, quiet = TRUE)
    if (identical(unique(cached$vintage), vintage)) return(cached)
    if (verbose) say("Cached land cover is not CLC", vintage, "; rebuilding.")
  }

  outline <- sf::st_geometry(boundary) |>
    sf::st_transform(3035) |>
    sf::st_union() |>
    sf::st_make_valid()
  bbox <- sf::st_bbox(sf::st_transform(outline, 4326))

  if (nzchar(clc_path)) {

    if (!file.exists(clc_path)) {
      stop("`clc_path` is set to '", clc_path, "', but there is no file there.\n",
           "Download the vector product of CLC", vintage, " from\n  ",
           src$product_page, "\n(an EU Login is needed), unzip it, and point ",
           "`clc_path` — or the CLC_PATH environment variable — at the ",
           ".gpkg or .gdb inside. Or leave `clc_path` empty to read the same ",
           "data from the EEA map service instead.", call. = FALSE)
    }

    layers <- sf::st_layers(clc_path)
    poly <- which(vapply(layers$geomtype, function(g)
      any(grepl("polygon", g, ignore.case = TRUE)), logical(1)))
    if (!length(poly)) {
      stop(clc_path, " holds no polygon layer. `clc_path` must be the CLC ",
           "vector product, not the raster.", call. = FALSE)
    }
    lyr <- layers$name[poly[1]]
    if (verbose) say("Reading CLC", vintage, " for Kosovo from ", basename(clc_path),
                     " (layer ", lyr, ") ...")

    # A spatial filter, not a WHERE clause: the European file holds some two
    # million polygons and only the pages covering Kosovo should be read.
    box <- sf::st_as_text(sf::st_transform(sf::st_as_sfc(bbox), layers$crs[[poly[1]]]))
    raw <- sf::st_read(clc_path, layer = lyr, wkt_filter = box, quiet = TRUE)
    route <- basename(clc_path)

  } else {
    if (verbose) say("Reading CLC", vintage, " for Kosovo from the EEA map service ...")
    raw <- arcgis_query_sf(src$service, bbox,
                           fields = paste(src$code_field, "ID", sep = ","),
                           verbose = verbose)
    route <- "EEA map service"
  }

  if (!src$code_field %in% names(raw)) {
    stop("The land-cover layer has no `", src$code_field, "` column; is it CLC",
         vintage, "?", call. = FALSE)
  }

  x <- sf::st_sf(
    clc_id   = as.character(raw$ID %||% seq_len(nrow(raw))),
    clc_code = as.character(raw[[src$code_field]]),
    geometry = sf::st_geometry(raw)
  ) |>
    sf::st_transform(3035) |>
    sf::st_make_valid()

  x <- suppressWarnings(sf::st_intersection(x, outline)) |>
    polygons_only(id = "clc_id")

  x$area_ha  <- as.numeric(sf::st_area(x)) / 1e4
  x$vintage  <- vintage
  x$source   <- route
  # The day the data was read, which is what a citation's "accessed on" means;
  # the pipeline may re-run on the cache long after.
  x$accessed <- as.character(Sys.Date())
  x <- x[order(x$clc_code, x$clc_id), ]

  if (verbose) {
    say("  ", fmt_int(nrow(x)), " polygons, ",
        fmt_int(round(sum(x$area_ha) / 100)), " km2 inside the outline.")
  }

  if (!is.null(cache_path)) {
    dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
    sf::st_write(x, cache_path, layer = "clc", append = FALSE, quiet = TRUE)
  }

  x
}

#' Build (and cache) the biogeographical regions of Kosovo
#'
#' Needed because the Annex I type a land-cover class stands for can differ
#' between regions — an alpine grassland and a lowland one are different
#' habitats — and the crosswalk may therefore carry region-specific rows. The
#' layer is at 1:1,000,000, so its boundaries are good to about a kilometre.
#'
#' @param boundary National outline from `kosovo_boundary()`.
#' @param cache_path GeoPackage used to cache the clipped regions.
#' @param verbose Print progress messages.
#' @return An `sf` layer in EPSG:3035 with `region` (the layer's short code,
#'   e.g. "Alpine"), `name` and `area_km2`.
kosovo_biogeo_regions <- function(boundary,
                                  cache_path = "data/kosovo_biogeo_regions.gpkg",
                                  verbose = TRUE) {

  if (!is.null(cache_path) && file.exists(cache_path)) {
    return(sf::st_read(cache_path, quiet = TRUE))
  }

  if (verbose) say("Reading the biogeographical regions from the EEA map service ...")

  outline <- sf::st_geometry(boundary) |>
    sf::st_transform(3035) |>
    sf::st_union() |>
    sf::st_make_valid()

  raw <- arcgis_query_sf(biogeo_source$service,
                         sf::st_bbox(sf::st_transform(outline, 4326)),
                         fields = "code,name", verbose = FALSE)

  x <- sf::st_sf(region = raw$code, name = raw$name,
                 geometry = sf::st_geometry(raw)) |>
    sf::st_make_valid()

  x <- suppressWarnings(sf::st_intersection(x, outline)) |>
    polygons_only(id = "region")

  x$area_km2 <- as.numeric(sf::st_area(x)) / 1e6
  x <- x[x$area_km2 > 0, ]
  x <- x[order(-x$area_km2), ]
  x$accessed <- as.character(Sys.Date())

  if (!is.null(cache_path)) {
    dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
    sf::st_write(x, cache_path, append = FALSE, quiet = TRUE)
  }

  x
}

#' Annex I habitat types, with their names, from the legal text
#'
#' Read from the consolidated Habitats Directive already kept under
#' `data/eurlex/` for the species lists, so that the names shown beside each
#' code are the Directive's own. Doing it this way also checks the crosswalk: a
#' code that is not in Annex I is caught here rather than published.
#'
#' @param path The consolidated directive as saved from EUR-Lex.
#' @return A tibble of `code`, `name` and `priority` (the asterisk).
annex1_habitat_types <- function(path = "data/eurlex/habitats_directive.html") {

  html <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = " ")

  # Annex I is set as a definition list: the four-character code in one cell,
  # the name in the next, and a priority type's asterisk leading the name.
  pattern <- paste0('<p class="dlist-term">\\s*([0-9]{2}[0-9A-Z]{2})\\s*</p>',
                    '\\s*</td>\\s*<td[^>]*>\\s*',
                    '<p class="dlist-definition">(.*?)</p>')
  hits  <- regmatches(html, gregexpr(pattern, html, perl = TRUE))[[1]]
  parts <- regmatches(hits, regexec(pattern, hits, perl = TRUE))

  # The Directive sets syntaxon and species names in italics; that is kept, as
  # <i>, and every other tag is dropped.
  code <- vapply(parts, `[`, character(1), 2)
  name <- vapply(parts, `[`, character(1), 3) |>
    gsub(pattern = "<span class=\"italics\">(.*?)</span>",
         replacement = "\u0001\\1\u0002", perl = TRUE) |>
    gsub(pattern = "<[^>]+>", replacement = "") |>
    gsub(pattern = "\u0001", replacement = "<i>", fixed = TRUE) |>
    gsub(pattern = "\u0002", replacement = "</i>", fixed = TRUE) |>
    gsub(pattern = "[\u25BA\u25C4\u25BC]", replacement = "") |>
    gsub(pattern = "&amp;", replacement = "&", fixed = TRUE) |>
    gsub(pattern = "&nbsp;", replacement = " ", fixed = TRUE) |>
    gsub(pattern = "\\s+", replacement = " ") |>
    trimws()

  priority <- startsWith(name, "*")
  name <- trimws(sub("^\\*", "", name))

  out <- dplyr::tibble(code = code, name = name, priority = priority)
  out[!duplicated(out$code), ]
}

#' Read and check the CLC to Annex I crosswalk
#'
#' The crosswalk is a project input for specialist review, so it is checked
#' strictly: a typo in a status or a confidence would otherwise drop a class
#' from the analysis without a word. Classes missing from the file are treated
#' as "not natural", which is what the file itself says of every class it does
#' not list, and are reported.
#'
#' `biogeo_region` is optional. Left empty, a row applies everywhere; filled
#' with a region code from `kosovo_biogeo_regions()` ("Alpine", "Continental"),
#' it applies only there and takes precedence over the general row for the same
#' class.
#'
#' @param path CSV with the documented columns.
#' @param legend The CLC legend, `data/clc_legend.csv`.
#' @param annex1 Annex I types from `annex1_habitat_types()`.
#' @return The crosswalk as a tibble, one row per class and region.
read_clc_crosswalk <- function(path, legend, annex1) {

  cw <- readr::read_csv(path, col_types = readr::cols(.default = "c"),
                        na = character(), show_col_types = FALSE)

  required <- c("clc_code", "clc_label", "natural_status", "habitat_group",
                "candidate_annex1", "confidence", "note")
  missing <- setdiff(required, names(cw))
  if (length(missing)) {
    stop("The crosswalk ", path, " is missing column(s): ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  if (!"biogeo_region" %in% names(cw)) cw$biogeo_region <- ""
  cw <- dplyr::mutate(cw, dplyr::across(dplyr::everything(), trimws))

  bad <- function(test, what) {
    if (any(test)) {
      stop("Crosswalk ", path, ": ", what, " in the row(s) for CLC ",
           paste(cw$clc_code[test], collapse = ", "), ".", call. = FALSE)
    }
  }
  bad(!cw$clc_code %in% legend$clc_code, "an unknown CLC code")
  bad(!cw$natural_status %in% c("natural", "semi-natural", "not natural"),
      "natural_status must be natural, semi-natural or not natural")
  bad(!cw$confidence %in% c("high", "medium", "low", ""),
      "confidence must be high, medium or low")
  potential <- cw$natural_status != "not natural"
  bad(potential & (!nzchar(cw$habitat_group) | !nzchar(cw$confidence)),
      "a natural or semi-natural class needs a habitat_group and a confidence")
  bad(duplicated(paste(cw$clc_code, cw$biogeo_region)),
      "a class is listed twice for the same region")

  # Every candidate code must be an Annex I type, and flagged as a priority
  # type exactly when the Directive flags it.
  codes <- unlist(strsplit(cw$candidate_annex1[nzchar(cw$candidate_annex1)], ";"))
  codes <- unique(trimws(codes))
  plain <- sub("\\*$", "", codes)
  unknown <- codes[!plain %in% annex1$code]
  if (length(unknown)) {
    stop("Crosswalk ", path, ": not Annex I habitat type(s): ",
         paste(unknown, collapse = ", "), call. = FALSE)
  }
  starred <- endsWith(codes, "*")
  wrong <- codes[starred != annex1$priority[match(plain, annex1$code)]]
  if (length(wrong)) {
    warning("Crosswalk priority asterisks disagree with Annex I for: ",
            paste(wrong, collapse = ", "), call. = FALSE)
  }

  absent <- setdiff(legend$clc_code, cw$clc_code)
  if (length(absent)) {
    say("NOTE: CLC class(es) ", paste(absent, collapse = ", "), " are not in ",
        "the crosswalk and are treated as not natural.")
    cw <- dplyr::bind_rows(cw, dplyr::tibble(
      clc_code = absent,
      clc_label = legend$clc_label[match(absent, legend$clc_code)],
      natural_status = "not natural", habitat_group = "", candidate_annex1 = "",
      confidence = "", note = "", biogeo_region = ""))
  }

  cw
}

#' The indicative sufficiency band a network share falls in
#'
#' The biogeographical seminars have long used rough reference values when
#' judging whether the Natura 2000 network holds enough of a feature: 60 per
#' cent or more of its national resource inside the network as likely
#' sufficient, under 20 per cent as likely insufficient. They were written for
#' Annex I habitat types and species, not for land-cover classes, and they were
#' never meant to be used on their own; here they are an orientation only, and
#' the report says so wherever it shows them.
#'
#' @param pct Share of the resource inside designated sites, in per cent.
#' @return A character vector: "below 20 %", "20 to 60 %" or "60 % or more".
sufficiency_band <- function(pct) {
  as.character(cut(pct, c(-Inf, 20, 60, Inf), right = FALSE,
                   labels = c("below 20 %", "20 to 60 %", "60 % or more")))
}

#' Screen CORINE Land Cover for potential Annex I habitats
#'
#' Joins each polygon to the crosswalk, keeps the natural and semi-natural
#' classes at or above `min_confidence`, and measures how much of what is kept
#' lies inside a designated site and how much outside it — the gap — in total,
#' by habitat group, by confidence, by class, by region and by municipality.
#'
#' Four decisions are worth stating, because each changes a number:
#'
#' * **Sites, not points or zones.** "Inside" means inside the union of the
#'   designated sites with a mapped boundary. The strict-protection zones are
#'   nested inside those sites and add nothing; the natural monuments recorded
#'   only as a point have no area and cannot hold any.
#' * **The union, not the sum.** Seven sites overlap along their edges, and
#'   summing per-site overlaps would count the shared ground twice.
#' * **One region per polygon.** A CLC polygon takes the biogeographical region
#'   holding most of it, rather than being cut along the region boundary: that
#'   boundary is drawn at 1:1,000,000 and is good to a kilometre, and cutting
#'   100 m polygons along it would invent precision it does not have.
#' * **Overrides by polygon.** `overrides` reclassifies named polygons — in
#'   practice the reservoirs, which CLC files under "Water bodies" with the
#'   natural lakes — and the reclassification is reported, not hidden.
#'
#' @param clc Land cover from `kosovo_clc()`, EPSG:3035.
#' @param crosswalk From `read_clc_crosswalk()`.
#' @param overrides Polygon overrides, `data/clc_polygon_overrides.csv`.
#' @param regions From `kosovo_biogeo_regions()`.
#' @param sites Designated sites with a mapped boundary (any CRS).
#' @param municipalities Municipal polygons (any CRS).
#' @param vintage CLC vintage, used to select the overrides that apply.
#' @param min_confidence Lowest crosswalk confidence kept: "low", "medium" or
#'   "high".
#' @return A list of layers, tables and reconciliation checks; see the body.
assess_potential_habitats <- function(clc, crosswalk, overrides, regions, sites,
                                      municipalities, vintage,
                                      min_confidence = "low") {

  conf_levels <- c("low", "medium", "high")
  if (!min_confidence %in% conf_levels) {
    stop("`potential_habitat_min_confidence` must be one of: ",
         paste(conf_levels, collapse = ", "), call. = FALSE)
  }

  x <- sf::st_transform(clc, 3035)

  # --- Biogeographical region: the one holding most of each polygon ---------
  cut_up <- suppressWarnings(sf::st_intersection(x[, "clc_id"],
                                                 regions[, "region"]))
  cut_up$share <- as.numeric(sf::st_area(cut_up))
  best <- sf::st_drop_geometry(cut_up) |>
    dplyr::arrange(dplyr::desc(.data$share)) |>
    dplyr::distinct(.data$clc_id, .keep_all = TRUE)
  x$biogeo_region <- best$region[match(x$clc_id, best$clc_id)]

  # --- Crosswalk: a region-specific row first, then the general one ---------
  cw <- crosswalk
  cw$row <- seq_len(nrow(cw))
  general  <- cw[!nzchar(cw$biogeo_region), ]
  regional <- cw[nzchar(cw$biogeo_region), ]
  i_reg <- match(paste(x$clc_code, x$biogeo_region),
                 paste(regional$clc_code, regional$biogeo_region))
  i_gen <- match(x$clc_code, general$clc_code)
  x$cw_row <- ifelse(!is.na(i_reg), regional$row[i_reg], general$row[i_gen])

  take <- function(col) cw[[col]][x$cw_row]
  x$clc_label        <- take("clc_label")
  x$natural_status   <- take("natural_status")
  x$habitat_group    <- take("habitat_group")
  x$candidate_annex1 <- take("candidate_annex1")
  x$confidence       <- take("confidence")
  # The key the report's pop-ups use to look up the class-level text, so that
  # a region-specific row carries its own candidates.
  x$cw_key <- ifelse(nzchar(take("biogeo_region")),
                     paste(x$clc_code, take("biogeo_region"), sep = "-"),
                     x$clc_code)

  # --- Overrides ------------------------------------------------------------
  ov <- overrides[as.character(overrides$clc_vintage) == vintage, ]
  hit <- match(x$clc_id, ov$clc_id)
  x$override <- ov$name[hit]
  x$natural_status <- ifelse(is.na(hit), x$natural_status, ov$natural_status[hit])
  unmatched <- setdiff(ov$clc_id, x$clc_id)
  if (length(unmatched)) {
    warning("Override(s) for CLC polygon(s) not found in the extract: ",
            paste(unmatched, collapse = ", "), call. = FALSE)
  }

  # `%in% TRUE` so that a code the crosswalk cannot place counts as not
  # potential rather than as NA, which would put empty rows into the layer.
  rank <- match(x$confidence, conf_levels)
  x$potential <- (x$natural_status != "not natural" &
    !is.na(rank) & rank >= match(min_confidence, conf_levels)) %in% TRUE

  pot <- x[x$potential, ]

  # --- Inside the designated sites, and the gap -----------------------------
  sites <- sf::st_make_valid(sf::st_transform(sites, 3035))
  network <- sf::st_make_valid(sf::st_union(sites))

  inside <- suppressWarnings(sf::st_intersection(pot[, "clc_id"], network))
  inside$ha <- as.numeric(sf::st_area(inside)) / 1e4
  ha_in <- tapply(inside$ha, inside$clc_id, sum)
  pot$ha_inside  <- dplyr::coalesce(as.numeric(ha_in[pot$clc_id]), 0)
  pot$pct_inside <- 100 * pot$ha_inside / pot$area_ha

  # Which sites, for the pop-ups: largest overlap first. Shared edges between a
  # 100 m land-cover line and a surveyed site boundary produce slivers of a few
  # square metres, which are not "in" a site in any sense a reader means, so
  # overlaps under a tenth of a hectare are not named.
  by_site <- suppressWarnings(sf::st_intersection(pot[, "clc_id"],
                                                  sites[, "site_name"]))
  by_site$ha <- as.numeric(sf::st_area(by_site)) / 1e4
  named <- sf::st_drop_geometry(by_site) |>
    dplyr::filter(.data$ha >= 0.1) |>
    dplyr::arrange(.data$clc_id, dplyr::desc(.data$ha)) |>
    dplyr::group_by(.data$clc_id) |>
    dplyr::summarise(sites = paste(unique(.data$site_name), collapse = "; "),
                     .groups = "drop")
  pot$sites <- named$sites[match(pot$clc_id, named$clc_id)]

  gap <- suppressWarnings(sf::st_difference(pot, network)) |>
    polygons_only(id = "clc_id")
  gap$gap_ha <- as.numeric(sf::st_area(gap)) / 1e4
  gap <- gap[gap$gap_ha > 0, ]

  # --- Summaries, all from EPSG:3035 areas ----------------------------------
  d <- sf::st_drop_geometry(pot)

  summarise_area <- function(g) {
    g |>
      dplyr::summarise(
        polygons   = dplyr::n(),
        area_km2   = sum(.data$area_ha) / 100,
        inside_km2 = sum(.data$ha_inside) / 100,
        .groups    = "drop"
      ) |>
      dplyr::mutate(
        gap_km2    = .data$area_km2 - .data$inside_km2,
        pct_inside = 100 * .data$inside_km2 / .data$area_km2
      )
  }

  by_group <- d |>
    dplyr::group_by(habitat_group = .data$habitat_group) |>
    summarise_area() |>
    dplyr::left_join(
      d |>
        dplyr::group_by(habitat_group = .data$habitat_group,
                        confidence = .data$confidence) |>
        dplyr::summarise(km2 = sum(.data$area_ha) / 100, .groups = "drop") |>
        tidyr::pivot_wider(names_from = "confidence", values_from = "km2",
                           names_prefix = "km2_", values_fill = 0),
      by = "habitat_group") |>
    dplyr::mutate(indicative_band = sufficiency_band(.data$pct_inside)) |>
    dplyr::arrange(dplyr::desc(.data$area_km2))
  for (cl in paste0("km2_", conf_levels)) {
    if (!cl %in% names(by_group)) by_group[[cl]] <- 0
  }

  by_confidence <- d |>
    dplyr::group_by(confidence = .data$confidence) |>
    summarise_area() |>
    dplyr::arrange(match(.data$confidence, rev(conf_levels)))

  by_class <- d |>
    dplyr::group_by(clc_code = .data$clc_code, clc_label = .data$clc_label,
                    habitat_group = .data$habitat_group,
                    confidence = .data$confidence) |>
    summarise_area() |>
    dplyr::arrange(.data$clc_code)

  by_region <- d |>
    dplyr::group_by(biogeo_region = .data$biogeo_region,
                    habitat_group = .data$habitat_group) |>
    summarise_area()

  # Every class present, potential or not, for the account of what was left
  # out and why.
  all_classes <- sf::st_drop_geometry(x) |>
    dplyr::group_by(clc_code = .data$clc_code, clc_label = .data$clc_label,
                    natural_status = .data$natural_status,
                    potential = .data$potential) |>
    dplyr::summarise(polygons = dplyr::n(),
                     area_km2 = sum(.data$area_ha) / 100, .groups = "drop") |>
    dplyr::arrange(.data$clc_code)

  # --- By municipality ------------------------------------------------------
  mun <- sf::st_make_valid(sf::st_transform(municipalities, 3035))
  mun$mun_km2 <- as.numeric(sf::st_area(mun)) / 1e6

  per_mun <- function(layer, col) {
    cut_mun <- suppressWarnings(sf::st_intersection(layer[, "clc_id"],
                                                    mun[, "municipality"]))
    a <- tapply(as.numeric(sf::st_area(cut_mun)) / 1e6, cut_mun$municipality, sum)
    dplyr::tibble(municipality = names(a), !!col := as.numeric(a))
  }

  by_municipality <- sf::st_drop_geometry(mun) |>
    dplyr::select("municipality", "district", "mun_km2") |>
    dplyr::left_join(per_mun(pot, "potential_km2"), by = "municipality") |>
    dplyr::left_join(per_mun(gap, "gap_km2"), by = "municipality") |>
    dplyr::mutate(
      potential_km2 = dplyr::coalesce(.data$potential_km2, 0),
      gap_km2       = dplyr::coalesce(.data$gap_km2, 0),
      # A difference of two areas, so a municipality with no site at all comes
      # out at 1e-12 km² rather than zero; rounded to the square metre.
      inside_km2    = pmax(0, round(.data$potential_km2 - .data$gap_km2, 6)),
      pct_potential = 100 * .data$potential_km2 / .data$mun_km2,
      pct_inside    = ifelse(.data$potential_km2 > 0,
                             100 * .data$inside_km2 / .data$potential_km2,
                             NA_real_)
    ) |>
    dplyr::arrange(dplyr::desc(.data$gap_km2))

  # --- Reconciliation -------------------------------------------------------
  # Three routes to the same totals; they must agree to a hundredth of a per
  # cent, or something in the geometry is wrong and the run stops here rather
  # than publishing figures that do not add up.
  total_km2  <- sum(d$area_ha) / 100
  inside_km2 <- sum(d$ha_inside) / 100
  gap_geom_km2 <- sum(gap$gap_ha) / 100
  checks <- dplyr::tibble(
    check = c("groups sum to the total",
              "inside + gap (from geometry) = total",
              "municipalities sum to the total",
              "municipal gaps sum to the gap"),
    expected = c(total_km2, total_km2, total_km2, gap_geom_km2),
    observed = c(sum(by_group$area_km2), inside_km2 + gap_geom_km2,
                 sum(by_municipality$potential_km2),
                 sum(by_municipality$gap_km2))
  ) |>
    # Relative where there is something to be relative to; a confidence floor
    # that keeps nothing leaves every total at zero, and 0 / 0 is not a pass.
    dplyr::mutate(rel_diff = abs(.data$observed - .data$expected) /
                    pmax(.data$expected, 1e-9))
  if (any(checks$rel_diff > 1e-4)) {
    print(checks)
    stop("The potential-habitat areas do not reconcile; see the checks above.",
         call. = FALSE)
  }

  list(
    polygons        = pot,
    gap             = gap,
    network         = network,
    by_group        = by_group,
    by_confidence   = by_confidence,
    by_class        = by_class,
    by_region       = by_region,
    by_municipality = by_municipality,
    all_classes     = all_classes,
    overrides       = sf::st_drop_geometry(x[!is.na(x$override),
                                             c("clc_id", "clc_code", "override",
                                               "area_ha")]),
    national = dplyr::tibble(
      country_km2 = sum(x$area_ha) / 100,
      total_km2   = total_km2,
      inside_km2  = inside_km2,
      gap_km2     = gap_geom_km2,
      pct_inside  = 100 * inside_km2 / total_km2
    ),
    checks          = checks
  )
}

#' Generalise a polygon layer for the web map, keeping its topology
#'
#' Done with mapshaper (through `rmapshaper`), not `sf::st_simplify()`. The
#' difference matters for a land-cover layer, where every edge is shared by two
#' polygons: `st_simplify()` generalises each polygon on its own, so the two
#' copies of an edge move apart and open slivers and overlaps along every
#' boundary; mapshaper simplifies each shared edge once, and neighbours still
#' meet exactly.
#'
#' `tolerance_m` is mapshaper's `interval`, in metres even for longitude and
#' latitude. At 50 m it removes about two vertices in three from CLC, which is
#' already generalised to 100 m, while keeping every shape of that size;
#' `keep-shapes` stops a small polygon being simplified out of existence.
#'
#' Coordinates are then rounded, to four decimals by default: about 8 m east
#' to west and 11 m north to south at Kosovo's latitude. That is well inside
#' both the tolerance and CLC's own stated positional accuracy of 100 m, and
#' every vertex written to the page costs about a tenth less for it. Rounding
#' is deterministic, so a vertex two polygons share still lands in the same
#' place in both.
#'
#' Areas are never computed from the result. They come from the full geometry.
#'
#' @param x An `sf` polygon layer.
#' @param tolerance_m Simplification interval in metres.
#' @param digits Decimal places kept in longitude and latitude.
#' @return `x` in EPSG:4326, simplified, as MULTIPOLYGON.
simplify_for_map <- function(x, tolerance_m, digits = 4) {

  stopifnot(requireNamespace("rmapshaper", quietly = TRUE),
            requireNamespace("geojsonsf", quietly = TRUE))

  x <- sf::st_transform(x, 4326)
  x$.row <- seq_len(nrow(x))

  # Only the row number goes through mapshaper and back, because a GeoJSON
  # round trip does not preserve column types or order; the attributes are
  # re-attached afterwards by that number.
  gj  <- geojsonsf::sf_geojson(x[, ".row"])
  out <- rmapshaper::apply_mapshaper_commands(
    gj, sprintf("-simplify interval=%s keep-shapes", tolerance_m),
    force_FC = TRUE, quiet = TRUE)
  y <- geojsonsf::geojson_sf(out)

  g <- sf::st_as_sfc(sf::st_as_binary(sf::st_geometry(y),
                                      precision = 10^digits),
                     crs = 4326)
  attrs <- sf::st_drop_geometry(x)[match(y$.row, x$.row), , drop = FALSE]
  attrs$.row <- NULL

  sf::st_sf(attrs, geometry = g) |>
    sf::st_cast("MULTIPOLYGON", warn = FALSE)
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
# APIs: IUCN Red List categories, dataset titles and publishing organisations,
# and — for the invasive-species watch list — record counts across the border.
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

#' Kosovo's neighbours, as the GADM identifiers GBIF filters on
#'
#' GADM draws Serbia without Kosovo, so `SRB` counts nothing inside Kosovo's
#' border, which a `country=RS` filter would: some of Kosovo's own records are
#' published under that code. Names are given in English, the report's
#' language.
ias_neighbours <- c(ALB = "Albania", MKD = "North Macedonia",
                    MNE = "Montenegro", SRB = "Serbia")

#' Count records of each species in each of Kosovo's neighbours
#'
#' The Union list exists to catch invasive species early, and the species most
#' likely to reach Kosovo next are the ones already recorded across its
#' borders. These counts are what the report's watch list is built from.
#'
#' They come from the occurrence search API with the same quality filters as
#' the download, and they are NOT covered by the download's DOI: they are a
#' dated screening aid, and the cache records the day they were taken. Delete
#' the cache to refresh them.
#'
#' One request per species covers all four countries, faceted by GADM country.
#' The requests are made one at a time rather than through `gbif_fetch_json()`:
#' occurrence search is rate-limited far more tightly than the species and
#' registry endpoints, and at six concurrent connections GBIF answers most of
#' them with 429 Too Many Requests. A 429 is waited out and retried.
#'
#' @param species_keys Integer vector of GBIF species keys.
#' @param cache_path CSV used to persist the counts between runs.
#' @param verbose Print progress messages.
#' @return A tibble with `speciesKey`, one record count per neighbour (named by
#'   its GADM code), `last_year` (the most recent year recorded in any of them)
#'   and `queried`.
fetch_neighbour_counts <- function(species_keys,
                                   cache_path = "data/ias_neighbour_counts.csv",
                                   verbose    = TRUE) {

  species_keys <- unique(stats::na.omit(as.integer(species_keys)))
  gadm <- names(ias_neighbours)

  cache <- if (file.exists(cache_path)) {
    readr::read_csv(cache_path, show_col_types = FALSE,
                    col_types = readr::cols(queried = readr::col_date(),
                                            .default = readr::col_integer()))
  } else {
    dplyr::tibble(speciesKey = integer())
  }

  missing <- setdiff(species_keys, cache$speciesKey)

  if (length(missing) > 0) {

    if (verbose) {
      say("Counting records in neighbouring countries for ",
          fmt_int(length(missing)), " species ...")
    }

    one <- function(key) {
      url <- sprintf(paste0(
        "https://api.gbif.org/v1/occurrence/search?taxonKey=%d&%s",
        "&hasCoordinate=true&hasGeospatialIssue=false&occurrenceStatus=PRESENT",
        "&limit=0&facet=gadmLevel0Gid&facet=year&facetLimit=500"),
        key, paste0("gadmGid=", gadm, collapse = "&"))

      for (attempt in 1:5) {
        res <- tryCatch(
          curl::curl_fetch_memory(url, curl::new_handle(
            useragent = .gbif_user_agent, timeout = 60)),
          error = function(e) NULL)
        if (!is.null(res) && res$status_code == 200) break
        if (!is.null(res) && res$status_code != 429) return(NULL)
        Sys.sleep(2^attempt)
      }
      if (is.null(res) || res$status_code != 200) return(NULL)

      j <- jsonlite::fromJSON(rawToChar(res$content), simplifyVector = FALSE)
      facet <- function(field) {
        f <- Filter(function(x) identical(x$field, field), j$facets)
        if (!length(f)) return(stats::setNames(integer(), character()))
        stats::setNames(vapply(f[[1]]$counts, function(x) as.integer(x$count), 1L),
                        vapply(f[[1]]$counts, function(x) x$name, ""))
      }
      by_country <- facet("GADM_LEVEL_0_GID")
      years      <- suppressWarnings(as.integer(names(facet("YEAR"))))

      Sys.sleep(0.25)   # considerate pacing, even when nothing is refused
      dplyr::as_tibble(c(
        list(speciesKey = key),
        stats::setNames(as.list(dplyr::coalesce(unname(by_country[gadm]), 0L)),
                        gadm),
        list(last_year = if (any(!is.na(years))) max(years, na.rm = TRUE)
                         else NA_integer_,
             queried   = Sys.Date())
      ))
    }

    got <- lapply(missing, one)
    ok  <- !vapply(got, is.null, logical(1))

    # A failed request is left out of the cache rather than stored as zero, so
    # that it is asked again next time instead of becoming a false absence.
    if (verbose && any(!ok)) {
      say("  ", sum(!ok), " requests failed and will be retried next run.")
    }

    cache <- dplyr::bind_rows(cache, dplyr::bind_rows(got[ok])) |>
      dplyr::distinct(.data$speciesKey, .keep_all = TRUE)

    dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
    readr::write_csv(cache, cache_path, na = "")
  }

  dplyr::filter(cache, .data$speciesKey %in% species_keys)
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
#' Used only on the GADM fallback path. The OpenStreetMap layer takes its
#' district labels from `.osm_kosovo_districts`, keyed on relation id.
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
#' unit in advance. This function supplies the units: the 38 municipalities
#' grouped into 7 districts.
#'
#' Read from the same OpenStreetMap GeoPackage as `kosovo_boundary()`, so the
#' municipalities tile the national outline exactly instead of leaving slivers
#' along the border where two differently generalised versions of the same line
#' disagree. Names are given in both official languages of Kosovo.
#'
#' Thirty-eight, not GADM's thirty. Kosovo's decentralisation created new
#' municipalities in 2010 and split Mitrovica in two; GADM 4.1 still carries
#' the pre-2010 set, and the units it lacks are not empty ground. The single
#' coordinate that holds more records than any other in the country — over
#' thirteen thousand — sits on ground that moved from Fushë Kosovë to the new
#' municipality of Graçanicë in 2010. Reported through GADM, every one of them
#' was credited to Fushë Kosovë.
#'
#' @param cache_path GeoPackage used to cache the boundaries.
#' @param osm_path Cache path for the OpenStreetMap geography.
#' @param gadm_path Cache path for the GADM archive used as a fallback.
#' @param verbose Print progress messages.
#' @return An `sf` polygon layer with `municipality`, `district` and `gid`.
kosovo_municipalities <- function(
    cache_path = "data/kosovo_municipalities.gpkg",
    osm_path   = "data/osm_kosovo.gpkg",
    gadm_path  = "data/gadm41_XKO.gpkg",
    verbose    = TRUE) {

  if (!is.null(cache_path) && file.exists(cache_path)) {
    return(sf::st_read(cache_path, quiet = TRUE))
  }

  osm <- try(
    sf::st_read(osm_kosovo(cache_path = osm_path, verbose = verbose),
                layer = "ADM_2", quiet = TRUE),
    silent = TRUE
  )

  out <- if (!inherits(osm, "try-error")) {

    # The label is already "Albanian / Serbian"; the two halves are split back
    # out so that a reader searching in one language finds the unit. Where the
    # two languages agree — Junik, Prizren, Zubin Potok — the label is shown
    # once rather than doubled.
    parts   <- strsplit(osm$municipality, " / ", fixed = TRUE)
    albanian <- vapply(parts, function(p) p[1], character(1))
    serbian  <- vapply(parts, function(p) p[length(p)], character(1))

    sf::st_sf(
      gid          = osm$osm_id,
      municipality = ifelse(albanian == serbian, serbian,
                            paste0(albanian, " / ", serbian)),
      name_sq      = albanian,
      name_sr      = serbian,
      district     = osm$district,
      geometry     = sf::st_geometry(osm)
    )

  } else {

    warning("Could not build the OpenStreetMap municipalities (",
            conditionMessage(attr(osm, "condition")),
            "); falling back to GADM 4.1 level 2, which is both coarser and ",
            "out of date.", call. = FALSE)

    g <- sf::st_read(gadm_kosovo(cache_path = gadm_path, verbose = verbose),
                     layer = "ADM_ADM_2", quiet = TRUE)

    # GADM's *simplified GeoJSON* runs multi-word names together
    # ("KosovskaMitrovica", "FushëKosovë"); the GeoPackage read here spaces
    # them correctly. The repair is kept as a no-op guard in case the source is
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
    # language while the other twenty-seven are bilingual would be an artefact
    # of the source rather than a fact about the places, so the gaps are filled
    # from the official municipal names. Matching is on an ASCII substring so
    # that the lookup cannot be broken by how the leading diacritic is encoded.
    albanian <- dplyr::case_when(
      !is.na(albanian)          ~ albanian,
      grepl("Podujev", serbian) ~ "Podujevë",
      grepl("timlje",  serbian) ~ "Shtime",
      grepl("trpce",   serbian) ~ "Shtërpcë",
      TRUE                      ~ NA_character_
    )

    sf::st_sf(
      gid          = as.character(g$GID_2),
      municipality = ifelse(is.na(albanian) | albanian == serbian,
                            serbian, paste0(albanian, " / ", serbian)),
      name_sq      = ifelse(is.na(albanian), serbian, albanian),
      name_sr      = serbian,
      district     = kosovo_district_label(unrun(as.character(g$NAME_1))),
      geometry     = sf::st_geometry(g)
    )
  }

  out <- out |>
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
# Colour here does one of three jobs and each job gets one structure. Every
# value is GBIF's own: the brand steps come from GBIF's published style
# variables (gbif/portal16, app/views/shared/style/_variables.styl) and the
# density ramp is sampled from the tiles the GBIF occurrence map itself serves
# (style `classic.poly`), so this report reads as part of the GBIF family
# rather than as an approximation of it.
#
#   * identity  (which kingdom a record belongs to) -> GBIF brand hues,
#     assigned in a fixed order and capped at three, because on a map any two
#     marks can end up side by side and three is the number that stays
#     separable under red-green colour blindness at that harder test;
#   * magnitude (how many records fall in a place) -> GBIF's own density ramp,
#     light to dark. It runs yellow to red rather than through a single hue,
#     but its lightness falls at every step, which is the property that makes a
#     ramp read as an ordered scale. The rainbow that heat maps default to has
#     no such order, which is why it is not used here;
#   * conservation state (IUCN Red List) -> a reserved severity scale, never
#     shown without its label. Those are IUCN's categories rather than GBIF's,
#     so they keep their own scheme.
#
# The kingdom trio was measured, not picked by eye: OKLab dE under
# Machado-Oliveira-Fernandes protanopia and deuteranopia at severity 1.0, over
# ALL pairs -- the test a map needs, where any two marks can touch, rather than
# the adjacent-pair test a bar chart needs. The obvious reading of the brand,
# green for plants and terracotta for fungi, fails it: GBIF green and GBIF
# terracotta collapse to dE 4.0 under deuteranopia. Orange peel, GBIF's other
# warm step, clears it at 12.0, and the trio plus the neutral holds dE 11.5.
#
# Orange peel is the one compromise, and it is a deliberate one. It is light
# (OKLCH L 0.81), so it carries about 1.5:1 against the pale basemap where the
# other two carry 2.7:1 and 5.6:1. Fungi are much the smallest of the three
# kingdoms in these data; every map that uses these colours ships a legend, and
# every record a popup naming its kingdom, so identity never rests on the fill
# alone. On GBIF's own dark basemap -- one click away in the layer control --
# it is the strongest of the three at 6.9:1.

map_palette <- list(

  # Categorical -- identity. GBIF brand steps, in a fixed order.
  kingdom = c(
    Animalia = "#175CA1",  # GBIF azure
    Plantae  = "#509E2F",  # GBIF green
    Fungi    = "#FDB002",  # GBIF orange peel
    Other    = "#767C7A"   # neutral: a residual class, doing no hue work
  ),

  # Sequential -- magnitude. The five steps GBIF's `classic.poly` occurrence
  # map serves, sampled from the tiles themselves, and exactly the five classes
  # `density_breaks` cuts. Lightness falls monotonically, 0.97 down to 0.55.
  density = c("#FFFF00", "#FFCB00", "#FF9800", "#FF6600", "#D50A00"),

  # Sequential -- magnitude, continuous. The same five steps, so that the
  # classed grid and the heat surface cannot drift apart.
  heat = c("#FFFF00", "#FFCB00", "#FF9800", "#FF6600", "#D50A00"),

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

  boundary     = "#231F20",  # GBIF black
  municipality = "#6E7B7A",

  # The ground a static map draws land on. GBIF mist, which is exactly the land
  # colour of the `gbif-light` basemap the website's maps sit on: the printed
  # locator map and the interactive one are then the same picture in the same
  # colours, rather than two drawings of the same country.
  land         = "#E8E8E8",  # GBIF mist

  # Protected areas. Green is the one hue a reader already reads as "protected"
  # on any conservation map, and it is free to use here: the occurrence marks
  # carry GBIF green only for Plantae, and the protected-area layer is drawn as
  # a wash under the marks rather than as marks of its own, so the two never
  # compete for the same reading. The strict-protection zones take the darker
  # step, which is also the order of severity.
  protected = c(
    site   = "#2E7D32",
    strict = "#0F4A1E",
    point  = "#2E7D32"
  ),

  # Potential Natura 2000 habitats, one hue per habitat group. Six groups is
  # twice the number the kingdom palette stops at, and on a map any two of them
  # can touch, so the set was measured over ALL pairs with the dataviz palette
  # validator (OKLab, Machado protanopia and deuteranopia) on the light basemap:
  # worst colour-blind pair Heath & scrub / Forests at dE 7.6, worst pair for
  # full colour vision Rocky / Grasslands at dE 15.6. dE 7.6 is below the 8
  # target, which is allowed only with a second encoding, and there is one:
  # every polygon names its group on hover, and the legend lists them.
  #
  # These are Okabe-Ito hues, with the forest hue the bluish green rather than
  # a leaf green, to keep it apart from the protected-area green (dE 10.8). No
  # six-hue set was found that also clears every hue from that green under
  # colour blindness — rock and forest come closest to it — so on the habitat
  # map the protected areas are drawn as an outline over these fills, and are
  # told apart by form as well as by colour.
  habitat = c(
    "Forests"          = "#009E73",
    "Grasslands"       = "#E69F00",
    "Heath & scrub"    = "#CC79A7",
    "Rocky habitats"   = "#D55E00",
    "Wetlands & mires" = "#56B4E9",
    "Freshwater"       = "#0072B2"
  ),

  # Crosswalk confidence, carried by fill opacity so that the hue stays free
  # for the habitat group: a confident class reads as solid, a doubtful one as
  # a faint wash over the basemap.
  confidence = c(high = 0.8, medium = 0.5, low = 0.22),

  # The gap layer: a dark hatch and outline, the one neutral mark on the map.
  gap = "#1A1A1A"
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
#' These are GBIF's own basemaps, served from `tile.gbif.org`, so a map in this
#' report sits on the same ground as the same map on gbif.org. None requires an
#' API key.
#'
#' Two earlier choices are recorded here because both failed silently rather
#' than raising anything. CARTO's Positron tiles now arrive stamped "API KEY
#' REQUIRED" for an unauthenticated client -- HTTP 200, a valid PNG, a ruined
#' map. Esri's World Light Gray Canvas replaced them and is key-free, but it is
#' Esri's cartography, not GBIF's.
#'
#' `gbif-light` is the default: GBIF's minimal grey ground, whose land colour is
#' the brand's own "mist" (#E8E8E8). It is deliberately sparse -- coastlines,
#' borders and rivers, no roads and no labels at any zoom -- which is what makes
#' it a good ground for data. `gbif-natural` is the labelled, detailed style for
#' when a reader needs to place a record against a road or a town, and
#' `gbif-classic` is GBIF's signature dark ground, on which the yellow-to-red
#' density ramp is at its strongest (11.8:1 for the palest class against 1.1:1
#' on the pale ground). Satellite imagery stays with Esri, because GBIF serves
#' no imagery layer.
#'
#' TILE SIZE IS LOAD-BEARING. GBIF serves 512-pixel tiles on the OpenMapTiles
#' scheme -- the `omt` in the path -- so they are drawn at `tileSize = 512` with
#' `zoomOffset = -1`. Leaving Leaflet's 256-pixel default would still place the
#' tiles correctly, because the x/y indexing is standard, but every label and
#' road width would render at half its designed size.
#'
#' @param m A leaflet map.
#' @return The map, with four base groups added.
add_basemaps <- function(m) {

  gbif_tiles <- function(m, style, group, max_zoom = 19) {
    leaflet::addTiles(
      m,
      urlTemplate = sprintf(
        "https://tile.gbif.org/3857/omt/{z}/{x}/{y}@1x.png?style=%s", style),
      group       = group,
      attribution = paste(
        'Basemap <a href="https://www.gbif.org">GBIF</a> |',
        '&copy; <a href="https://www.openmaptiles.org/">OpenMapTiles</a>',
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
        'contributors'),
      options = leaflet::tileOptions(
        tileSize = 512, zoomOffset = -1, maxZoom = max_zoom)
    )
  }

  m |>
    gbif_tiles("gbif-light",   "GBIF light basemap") |>
    gbif_tiles("gbif-natural", "GBIF detailed basemap") |>
    gbif_tiles("gbif-classic", "GBIF dark basemap") |>
    leaflet::addProviderTiles(
      leaflet::providers$Esri.WorldImagery,
      group   = "Satellite imagery",
      options = leaflet::providerTileOptions(maxNativeZoom = 18, maxZoom = 19)
    )
}

basemap_groups <- c("GBIF light basemap", "GBIF detailed basemap",
                    "GBIF dark basemap", "Satellite imagery")

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
#' It is the OpenStreetMap national outline at full resolution (19,268
#' vertices), and the municipal layer tiles it exactly.
#'
#' `smoothFactor = 0` is the load-bearing argument. Exact geometry in the
#' GeoPackage is only half the job: Leaflet runs its own Douglas–Peucker pass
#' over every path as it draws, in *screen pixels*, and the default tolerance
#' of 1 discards any vertex that falls within a pixel of its neighbours. At the
#' country view that is roughly 400 m on the ground, so the drawn border was a
#' generalisation of the precise one — and it re-generalised differently at
#' every zoom level, which is what makes an outline look like it is wobbling as
#' you zoom. Zero renders all 19,268 vertices at every scale.
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

#' Add the protected-area overlay
#'
#' Drawn beneath the occurrence marks, as a fill rather than an outline: the
#' question the layer answers is whether a mark sits inside a site, and a
#' reader answers that far faster from a tinted ground than by tracing an
#' outline. The fill is kept light for the same reason the municipal overlay is
#' — it must not compete with the marks it exists to give context to.
#'
#' The point-only sites are added as small circle markers rather than left off.
#' They are three quarters of Kosovo's register, and a map that showed only the
#' 67 mapped boundaries would imply the other 189 do not exist.
#'
#' @param m A leaflet map.
#' @param protected_areas Polygon layer from `kosovo_protected_areas()`, or
#'   `NULL` to add nothing.
#' @param points Point layer from `kosovo_protected_areas(layer = "points")`,
#'   or `NULL`.
#' On a map whose subject is itself a set of coloured fills — the habitat map —
#' the wash would tint every fill beneath a site and change its apparent hue,
#' so `outline_only` draws the boundaries alone. The strict zones are then
#' dashed, so that the two kinds of line stay apart without a fill to tell
#' them by.
#'
#' @param group Overlay group name.
#' @param outline_only Draw boundaries without a fill.
#' @return A list with the map and the overlay group names added.
add_protected_areas <- function(m, protected_areas, points = NULL,
                                group = "Protected areas",
                                outline_only = FALSE) {

  if (is.null(protected_areas) || !nrow(protected_areas)) {
    return(list(map = m, groups = character(0)))
  }

  m <- leaflet::addMapPane(m, "protected", zIndex = 410)

  sites  <- protected_areas[
    protected_areas$designated_area_type == "designatedSite", ]
  strict <- protected_areas[
    protected_areas$designated_area_type == "strictProtectionBoundary", ]

  # A label that names the site, what it is, and how big it is. `records` is
  # present only when the caller has joined the counts on, so it is added
  # conditionally rather than assumed.
  site_label <- function(x) {
    base <- sprintf(
      "<strong>%s</strong><br>%s &middot; IUCN %s<br>%s km&sup2;, designated %s",
      x$site_name, x$designation,
      ifelse(is.na(x$iucn_management_category), "not assigned",
             x$iucn_management_category),
      formatC(x$area_km2, format = "f", digits = 1, big.mark = ","),
      ifelse(is.na(x$designation_year), "date not given", x$designation_year)
    )
    if ("records" %in% names(x)) {
      base <- paste0(base, sprintf("<br>%s records &middot; %s species",
                                   fmt_int(dplyr::coalesce(x$records, 0L)),
                                   fmt_int(dplyr::coalesce(x$species, 0L))))
    }
    lapply(base, htmltools::HTML)
  }

  groups <- character(0)

  if (nrow(sites)) {
    m <- leaflet::addPolygons(
      m, data = sites,
      fill = !outline_only, fillColor = map_palette$protected[["site"]],
      fillOpacity = 0.16,
      color = map_palette$protected[["site"]],
      weight = if (outline_only) 2 else 1.2, opacity = 0.85,
      smoothFactor = 0,
      label = site_label(sites),
      highlightOptions = leaflet::highlightOptions(
        weight = 2.5, color = map_palette$protected[["site"]],
        fillOpacity = 0.3, bringToFront = FALSE),
      options = leaflet::pathOptions(pane = "protected"),
      group = group
    )
    groups <- c(groups, group)
  }

  if (nrow(strict)) {
    strict_group <- "Strict protection zones"
    m <- leaflet::addPolygons(
      m, data = strict,
      fill = !outline_only, fillColor = map_palette$protected[["strict"]],
      fillOpacity = 0.3,
      color = map_palette$protected[["strict"]], weight = 1.2, opacity = 0.9,
      dashArray = if (outline_only) "5 3" else NULL,
      smoothFactor = 0,
      label = site_label(strict),
      options = leaflet::pathOptions(pane = "protected"),
      group = strict_group
    )
    groups <- c(groups, strict_group)
  }

  if (!is.null(points) && nrow(points)) {
    point_group <- "Natural monuments (point only)"
    m <- leaflet::addCircleMarkers(
      m, data = points,
      radius = 3, stroke = TRUE, weight = 1,
      color = map_palette$protected[["point"]],
      fillColor = map_palette$protected[["point"]], fillOpacity = 0.55,
      label = ~lapply(sprintf(
        "<strong>%s</strong><br>%s<br>%s ha, designated %s",
        site_name, designation,
        formatC(reported_area_ha, format = "f", digits = 2),
        ifelse(is.na(designation_year), "date not given", designation_year)),
        htmltools::HTML),
      options = leaflet::pathOptions(pane = "protected"),
      group = point_group
    )
    groups <- c(groups, point_group)
  }

  list(map = m, groups = groups)
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
      activeColor         = "#509E2F",
      completedColor      = "#509E2F"
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
#' The point layer is all of the records or none of them. Subsampling was tried
#' and dropped: a thinned layer is indistinguishable from a thin one, so a
#' sample drawn on top of a density grid built from every record quietly
#' contradicts the layer beside it, and no caption reliably undoes that. Above
#' `max_points` records the markers are therefore withheld rather than
#' sampled — the payload is roughly 390 bytes a record, which is what makes the
#' cap necessary at all — and the caption says so. The density grid, the heat
#' surface and the downloadable files always use every record, because none of
#' them carries a popup.
#'
#' @param x An `sf` occurrence data frame (or a plain data frame carrying
#'   `decimalLongitude` / `decimalLatitude`).
#' @param boundary Optional `sf` polygon drawn as a context outline.
#' @param municipalities Optional `sf` polygons drawn as an administrative
#'   overlay, labelled with this subset's record counts.
#' @param colour_by "kingdom", "iucn", or a single colour for a flat layer.
#' @param max_points Record count above which the point layer is omitted
#'   entirely. At or below it every record is drawn.
#' @param cell_km Cell size, in kilometres, for the density grid.
#' @return A `leaflet` htmlwidget.
build_occurrence_map <- function(x,
                                 boundary        = NULL,
                                 municipalities  = NULL,
                                 protected_areas = NULL,
                                 protected_points = NULL,
                                 colour_by       = "kingdom",
                                 max_points      = 10000,
                                 cell_km         = 2) {

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

  # --- Protected areas ------------------------------------------------------
  # Added before the boundary and the marks so that it sits underneath both.
  if (!is.null(protected_areas)) {
    pa <- add_protected_areas(m, protected_areas, protected_points)
    m  <- pa$map
    overlay_groups <- c(overlay_groups, pa$groups)
  }

  if (!is.null(boundary)) {
    # Solid, not dashed. A 4/4 dash drops half the outline out of the drawing,
    # which is exactly the detail that makes the border look approximate at the
    # scale where it matters.
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
        color = "#231F20", weight = 0.4, opacity = 0.35,
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
  # Every record, or none of them: see the note above the function for why the
  # subsample went. Where the layer is withheld the reader still has the two
  # density layers, which are built from the same records this layer would
  # have drawn.
  show_points <- nrow(d) <= max_points

  if (show_points) {

    pts       <- d
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
        disableClusteringAtZoom = 13,
        # The layer now carries every record rather than a fixed 2,500, so the
        # clusterer is told to build in chunks: without this the whole layer is
        # assembled in one pass and the page locks up while it happens.
        chunkedLoading          = TRUE
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
  }

  caption <- if (show_points) {
    sprintf("All %s records mapped.", fmt_int(nrow(d)))
  } else {
    sprintf(
      paste0("%s records mapped. Individual markers are left off above %s ",
             "records rather than shown as a sample, so this map is the ",
             "density layers and the heat surface — both built from every ",
             "record. The downloads carry every record too, and the record ",
             "explorer further down maps them one by one."),
      fmt_int(nrow(d)), fmt_int(max_points)
    )
  }

  # With the point layer withheld, the density grid is the only layer left
  # carrying the records themselves, so it starts visible in that case; where
  # the markers are drawn it stays a second reading behind the switcher.
  hidden <- c("Heat map", "Municipalities", "Strict protection zones",
              "Natural monuments (point only)")
  if (show_points) hidden <- c(hidden, "Record density")

  # The caption is dismissible. It is a note about the layers rather than part
  # of the map, and once it has been read it is only covering the corner of the
  # country it sits over. The button removes the whole `.leaflet-control`, so
  # the control's own padding goes with it instead of leaving an empty white
  # box in the corner.
  caption_html <- paste0(
    "<div class='map-caption'><span>", caption, "</span>",
    "<button type='button' class='map-caption-close' title='Dismiss' ",
    "aria-label='Dismiss this note' ",
    "onclick='this.closest(\".leaflet-control\").remove()'>&times;</button>",
    "</div>"
  )

  m <- m |>
    add_layer_switcher(overlay_groups) |>
    # "Protected areas" is deliberately NOT hidden. It is the context the marks
    # are read against, it is drawn as a wash rather than as marks of its own,
    # and a reader who has to find it in a menu before the map can answer
    # "is this record inside a site?" will mostly not ask the question. The
    # strict zones and the 189 point-only monuments are hidden, being detail
    # rather than context.
    leaflet::hideGroup(intersect(hidden, overlay_groups)) |>
    add_map_tools() |>
    pin_heatmap_zoom() |>
    leaflet::addControl(html = caption_html, position = "bottomright") |>
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
  # carries tens of times the coverage of the median — and equal intervals
  # would put nearly every unit in the lowest class. Break values are
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
                           na.color = "#E8E8E8")

  m <- leaflet::leaflet(options = leaflet::leafletOptions(minZoom = 6)) |>
    add_basemaps() |>
    leaflet::addPolygons(
      data = x,
      fillColor = ~pal(x[[value]]), fillOpacity = 0.8,
      color = "#231F20", weight = 0.7, opacity = 0.45,
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

#' The class-level text for the habitat map, one entry per crosswalk row
#'
#' A class's name, group, confidence, candidate Annex I types and note are the
#' same for every polygon of that class, and the candidate list with the
#' Directive's names runs to several hundred bytes. Written into each of 3,000
#' pop-ups and hover labels it would cost well over a megabyte; kept here once
#' per class and put together in the browser (see `build_habitat_gap_map()`),
#' it costs a few kilobytes.
#'
#' @param crosswalk The crosswalk as used, from `read_clc_crosswalk()`.
#' @param annex1 Annex I types from `annex1_habitat_types()`.
#' @param keys The `cw_key` values present on the map.
#' @return A named list keyed by `cw_key`, each entry holding `tip` (the hover
#'   label's first lines), `head` and `cand` (the pop-up's header and body) as
#'   HTML strings.
habitat_popup_lookup <- function(crosswalk, annex1, keys) {

  cw <- crosswalk[crosswalk$natural_status != "not natural", ]
  cw$key <- ifelse(nzchar(cw$biogeo_region),
                   paste(cw$clc_code, cw$biogeo_region, sep = "-"), cw$clc_code)
  cw <- cw[cw$key %in% keys, ]

  entry <- function(r) {
    codes <- trimws(unlist(strsplit(r$candidate_annex1, ";")))
    codes <- codes[nzchar(codes)]
    items <- if (length(codes)) {
      plain <- sub("\\*$", "", codes)
      nm <- annex1$name[match(plain, annex1$code)]
      paste0("<li><b>", codes, "</b> ", nm, "</li>", collapse = "")
    } else {
      "<li>none proposed</li>"
    }
    region <- if (nzchar(r$biogeo_region)) {
      paste0(" &middot; ", r$biogeo_region, " region")
    } else ""
    list(
      tip = sprintf("<strong>%s %s</strong><br>%s &middot; %s confidence%s",
                    r$clc_code, r$clc_label, r$habitat_group, r$confidence,
                    region),
      head = sprintf(
        "<b>%s</b><small>CLC %s &middot; %s &middot; %s confidence%s</small>",
        r$clc_label, r$clc_code, r$habitat_group, r$confidence, region),
      cand = paste0(
        "<span>Candidate Annex I types</span><ul>", items, "</ul>",
        if (nzchar(r$note)) paste0("<em>", r$note, "</em>") else "")
    )
  }

  stats::setNames(lapply(seq_len(nrow(cw)), function(i) entry(cw[i, ])), cw$key)
}

#' Build the potential Natura 2000 habitat map
#'
#' The map for the land-cover screen, on the same basemaps, layer control and
#' toolbar as every other map in the report. Its layers, in drawing order:
#'
#' 1. **CORINE Land Cover, all classes** — the EEA's own rendering, as WMS
#'    tiles, off by default. Tiles rather than polygons because the layer is
#'    context rather than subject: drawn as vectors it would add 4.6 MB to the
#'    page to repeat, in a second copy, most of the geometry of layer 2. The
#'    tiles are the official palette by construction, but they are not clipped
#'    to Kosovo and they depend on the EEA's server.
#' 2. **Potential natural habitats** — the kept CLC polygons, coloured by
#'    habitat group, with the crosswalk's confidence as fill opacity.
#' 3. **Protected areas** — the register, as outlines, from
#'    `add_protected_areas()`.
#' 4. **The gap** — potential habitat outside every designated site, hatched
#'    and outlined, on by default. It is not interactive, so hovering and
#'    clicking reach the habitat polygon underneath.
#' 5. **Municipalities** — each with its own gap figures on hover. Off by
#'    default, and on top when on, so while it is showing it takes the hover
#'    from the habitat polygons.
#'
#' The hatch is an SVG pattern. Leaflet writes a path's `fillColor` straight
#' into the SVG `fill` attribute, so a fill of `url(#gap-hatch)` works as soon
#' as a pattern with that id exists in the page; the `onRender` hook adds it.
#' The same hook fills each habitat pop-up from `habitat_popup_lookup()` when
#' it opens.
#'
#' @param habitats Potential-habitat polygons for display, EPSG:4326, with
#'   `clc_code`, `clc_label`, `habitat_group`, `confidence`, `area_ha`,
#'   `pct_inside`, `sites` and `cw_key`.
#' @param gap The gap, dissolved, for display.
#' @param crosswalk,annex1 For the pop-up text; see `habitat_popup_lookup()`.
#' @param clc Provenance of the CLC vintage (an entry of `clc_sources`, plus
#'   `vintage`).
#' @param clc_legend Legend rows (`clc_code`, `clc_label`, `colour`) for the
#'   classes present in Kosovo.
#' @param municipalities Municipal polygons for display, with `potential_km2`,
#'   `pct_potential`, `inside_km2`, `pct_inside` and `gap_km2`.
#' @param protected_areas,protected_points The register, as on the other maps.
#' @param boundary National outline.
#' @param caption Text for the dismissible note in the corner.
#' @return A `leaflet` htmlwidget.
build_habitat_gap_map <- function(habitats, gap, crosswalk, annex1, clc,
                                  clc_legend = NULL, municipalities = NULL,
                                  protected_areas = NULL,
                                  protected_points = NULL, boundary = NULL,
                                  caption = NULL) {

  g_clc <- sprintf("CORINE Land Cover %s (all classes)", clc$vintage)
  g_hab <- "Potential natural habitats"
  g_gap <- "Gap: potential habitat outside designated sites"
  g_mun <- "Municipalities"

  credit <- sprintf(
    paste0("Land cover: generated using European Union's Copernicus Land ",
           "Monitoring Service information; <a href='https://doi.org/%s'>",
           "CLC%s</a>"), clc$doi, clc$vintage)

  m <- leaflet::leaflet(options = leaflet::leafletOptions(minZoom = 6)) |>
    add_basemaps() |>
    leaflet::addMapPane("gap", zIndex = 420) |>
    leaflet::addMapPane("municipal", zIndex = 430)

  # --- 1. All classes, as the EEA renders them ------------------------------
  # zIndex above the basemaps', so that switching basemap cannot bury it.
  m <- leaflet::addWMSTiles(
    m, baseUrl = clc$wms, layers = clc$wms_layers,
    options = leaflet::WMSTileOptions(format = "image/png", transparent = TRUE,
                                      opacity = 0.8, zIndex = 10),
    attribution = credit, group = g_clc
  )
  if (!is.null(clc_legend) && nrow(clc_legend)) {
    m <- leaflet::addLegend(
      m, position = "bottomleft", colors = clc_legend$colour,
      labels = sprintf("%s %s", clc_legend$clc_code, clc_legend$clc_label),
      title = sprintf("CORINE Land Cover %s", clc$vintage), opacity = 0.8,
      group = g_clc, className = "info legend clc-legend"
    )
  }

  # --- 2. Potential natural habitats ----------------------------------------
  where <- ifelse(
    habitats$pct_inside < 0.5, "Outside every designated site",
    ifelse(habitats$pct_inside > 99.5,
           paste0("Inside ", habitats$sites),
           sprintf("%.0f %% inside %s", habitats$pct_inside,
                   dplyr::coalesce(habitats$sites, "a designated site"))))

  # Only what differs between polygons of a class travels with each polygon:
  # its lookup key, its size and where it lies. The onRender hook below builds
  # the hover label from that line and the class's entry in the lookup, and
  # completes the pop-up the same way when it opens, so neither the class text
  # nor a second copy of the per-polygon line is written 3,000 times.
  popups <- sprintf(
    "<div class='hab-popup' data-k='%s'><p>%s ha &middot; %s</p></div>",
    habitats$cw_key, fmt_int(round(habitats$area_ha)), where)

  m <- leaflet::addPolygons(
    m, data = habitats,
    fillColor = unname(map_palette$habitat[habitats$habitat_group]),
    fillOpacity = unname(map_palette$confidence[habitats$confidence]),
    color = "#FFFFFF", weight = 0.5, opacity = 0.7,
    popup = popups,
    highlightOptions = leaflet::highlightOptions(
      weight = 2, color = map_palette$boundary, opacity = 1,
      bringToFront = FALSE),
    options = leaflet::pathOptions(attribution = credit),
    group = g_hab
  )

  overlay_groups <- c(g_clc, g_hab)

  # --- 3. Protected areas, as outlines --------------------------------------
  if (!is.null(protected_areas)) {
    pa <- add_protected_areas(m, protected_areas, protected_points,
                              outline_only = TRUE)
    m  <- pa$map
    overlay_groups <- c(overlay_groups, pa$groups)
  }

  # --- 4. The gap -----------------------------------------------------------
  m <- leaflet::addPolygons(
    m, data = gap,
    fill = TRUE, fillColor = "url(#gap-hatch)", fillOpacity = 1,
    color = map_palette$gap, weight = 1.2, opacity = 0.85,
    options = leaflet::pathOptions(pane = "gap", interactive = FALSE),
    group = g_gap
  )
  overlay_groups <- c(overlay_groups, g_gap)

  # --- 5. Municipalities ----------------------------------------------------
  if (!is.null(municipalities)) {
    m <- leaflet::addPolygons(
      m, data = municipalities,
      fill = TRUE, fillColor = "#ffffff", fillOpacity = 0.01,
      color = map_palette$municipality, weight = 1.2, opacity = 0.8,
      label = lapply(sprintf(
        paste0("<strong>%s</strong><br>Potential habitat: %s km&sup2;, ",
               "%.0f %% of the municipality<br>Inside a designated site: ",
               "%s km&sup2; (%s)<br><strong>Gap: %s km&sup2;</strong><br>",
               "<em>%s district</em>"),
        municipalities$municipality,
        formatC(municipalities$potential_km2, format = "f", digits = 1,
                big.mark = ","),
        municipalities$pct_potential,
        formatC(municipalities$inside_km2, format = "f", digits = 1,
                big.mark = ","),
        ifelse(is.na(municipalities$pct_inside), "&mdash;",
               sprintf("%.0f %%", municipalities$pct_inside)),
        formatC(municipalities$gap_km2, format = "f", digits = 1,
                big.mark = ","),
        municipalities$district), htmltools::HTML),
      highlightOptions = leaflet::highlightOptions(
        weight = 2.5, color = map_palette$municipality, fillOpacity = 0.08,
        bringToFront = FALSE),
      options = leaflet::pathOptions(pane = "municipal"),
      group = g_mun
    )
    overlay_groups <- c(overlay_groups, g_mun)
  }

  if (!is.null(boundary)) {
    m <- add_boundary_outline(m, boundary)
    overlay_groups <- c(overlay_groups, "Kosovo boundary")
  }

  # --- Legend ---------------------------------------------------------------
  # One control rather than several legends, because the confidence key and
  # the hatch belong to the same reading as the group colours. A <details>
  # element, so that on a phone it can be folded out of the way; the onRender
  # hook folds it by default on narrow screens.
  present <- names(map_palette$habitat)[
    names(map_palette$habitat) %in% habitats$habitat_group]
  swatch_row <- function(style, text) {
    sprintf("<div class='row'><i style='%s'></i>%s</div>", style, text)
  }
  legend_html <- paste0(
    "<details open><summary>Potential natural habitat</summary>",
    paste0(vapply(present, function(g) swatch_row(
      sprintf("background:%s", map_palette$habitat[[g]]), g), ""),
      collapse = ""),
    "<div class='key'>Confidence</div><div class='conf'>",
    paste0(vapply(c("high", "medium", "low"), function(k) sprintf(
      "<span><i style='background:%s;opacity:%s'></i>%s</span>",
      map_palette$boundary, map_palette$confidence[[k]], k), ""),
      collapse = ""),
    "</div>",
    sprintf(paste0("<div class='row'><svg class='hatch' width='14' ",
                   "height='14' viewBox='0 0 14 14' aria-hidden='true'>",
                   "<rect width='14' height='14' ",
                   "fill='url(#gap-hatch)' stroke='%s'/></svg>",
                   "Outside every designated site</div>"), map_palette$gap),
    swatch_row(sprintf("background:transparent;border:2px solid %s",
                       map_palette$protected[["site"]]), "Designated site"),
    "<p class='caveat'>Land cover, not habitat: candidates for field ",
    "verification.</p></details>"
  )

  m <- leaflet::addControl(m, html = legend_html, position = "bottomright",
                           className = "info legend habitat-legend")

  if (!is.null(caption)) {
    m <- leaflet::addControl(
      m, position = "bottomleft",
      html = paste0(
        "<div class='map-caption'><span>", caption, "</span>",
        "<button type='button' class='map-caption-close' title='Dismiss' ",
        "aria-label='Dismiss this note' ",
        "onclick='this.closest(\".leaflet-control\").remove()'>&times;",
        "</button></div>"))
  }

  lookup <- habitat_popup_lookup(crosswalk, annex1, unique(habitats$cw_key))

  bb <- sf::st_bbox(if (is.null(boundary)) habitats else boundary)

  m |>
    add_layer_switcher(overlay_groups) |>
    leaflet::hideGroup(intersect(
      c(g_clc, g_mun, "Strict protection zones",
        "Natural monuments (point only)"), overlay_groups)) |>
    add_map_tools() |>
    htmlwidgets::onRender(sprintf("
function(el, x, data) {
  var map = this;

  // The hatch the gap layer is filled with. A path can only reference a
  // pattern that exists somewhere in the document; one hidden <svg> holding
  // it serves the map and the legend swatch alike. Zero-sized rather than
  // display:none, because some browsers do not paint from a pattern inside an
  // undisplayed element.
  if (!document.getElementById('gap-hatch')) {
    var ns = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('width', '0'); svg.setAttribute('height', '0');
    svg.setAttribute('aria-hidden', 'true');
    svg.style.position = 'absolute';
    var pat = document.createElementNS(ns, 'pattern');
    pat.setAttribute('id', 'gap-hatch');
    pat.setAttribute('patternUnits', 'userSpaceOnUse');
    pat.setAttribute('width', '7'); pat.setAttribute('height', '7');
    pat.setAttribute('patternTransform', 'rotate(45)');
    var line = document.createElementNS(ns, 'line');
    line.setAttribute('x1', '0'); line.setAttribute('y1', '0');
    line.setAttribute('x2', '0'); line.setAttribute('y2', '7');
    line.setAttribute('stroke', '%s'); line.setAttribute('stroke-width', '1.6');
    line.setAttribute('stroke-opacity', '0.75');
    pat.appendChild(line);
    var defs = document.createElementNS(ns, 'defs');
    defs.appendChild(pat); svg.appendChild(defs);
    document.body.appendChild(svg);
  }

  // Each habitat polygon arrives with a one-line pop-up: its lookup key, its
  // size and where it lies. Parsed once here, that line becomes the hover
  // label, prefixed with the class text from the lookup.
  var parse = function(c) {
    if (typeof c !== 'string' || c.indexOf('hab-popup') < 0) { return null; }
    var k = (c.match(/data-k='([^']+)'/) || [])[1];
    var line = (c.match(/<p>([\\s\\S]*?)<\\/p>/) || [])[1];
    var entry = data.lookup[k];
    return (entry && line) ? { entry: entry, line: line } : null;
  };

  var habitats = map.layerManager &&
    map.layerManager.getLayerGroup('%s', false);
  if (habitats) {
    habitats.eachLayer(function(layer) {
      var p = layer.getPopup && layer.getPopup();
      var got = p && parse(p.getContent());
      if (got) {
        layer.bindTooltip(got.entry.tip + '<br>' + got.line,
                          { sticky: true, direction: 'auto',
                            className: 'hab-tip' });
      }
    });
  }

  // The pop-up is completed the first time it opens. setContent() rather than
  // editing the DOM, so that Leaflet measures and places the grown pop-up
  // itself; the data-done marker stops it being filled twice.
  map.on('popupopen', function(e) {
    var c = e.popup.getContent();
    if (typeof c !== 'string' || c.indexOf('data-done') >= 0) { return; }
    var got = parse(c);
    if (!got) { return; }
    e.popup.setContent(
      \"<div class='hab-popup' data-done='1'><div class='hab-class'>\" +
      got.entry.head + '</div><p>' + got.line + \"</p><div class='hab-cand'>\" +
      got.entry.cand + '</div></div>');
  });

  // On a phone the legend would cover a third of the map; start it folded.
  if (el.offsetWidth < 640) {
    var d = el.querySelector('.habitat-legend details');
    if (d) { d.removeAttribute('open'); }
  }
}", map_palette$gap, g_hab), data = list(lookup = lookup)) |>
    leaflet::fitBounds(lng1 = as.numeric(bb$xmin), lat1 = as.numeric(bb$ymin),
                       lng2 = as.numeric(bb$xmax), lat2 = as.numeric(bb$ymax))
}
