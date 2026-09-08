# ==============================================================================
# pipeline.R
#
# Kosovo biodiversity data pipeline — GBIF occurrence acquisition, taxonomic
# matching against the EU Nature Directives, coordinate cleaning, subsetting
# and export.
#
# Run with:  Rscript pipeline.R
#
# The script is idempotent. A completed GBIF download is recorded in
# `data/gbif_download/download_key.txt` and re-used on subsequent runs, so
# re-running does not create a new download or a new DOI. Delete that file to
# force a fresh download.
#
# GBIF credentials must be present in `.Renviron` — see README.md.
# ==============================================================================

suppressPackageStartupMessages({
  library(rgbif)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
  library(sf)
  library(CoordinateCleaner)
})

source("R/functions.R")


# ==============================================================================
# 1. CONFIGURATION
# ==============================================================================

config <- list(

  # --- Spatial extent -------------------------------------------------------
  #
  # Kosovo is queried through the GADM predicate rather than the ISO country
  # code, because GADM's boundary also captures records whose publisher left
  # `countryCode` blank or misassigned.
  #
  # NOTE ON THE CODE: GADM's GID for Kosovo is "XKO". The code "XKX" is the
  # World Bank / ISO-3166 alpha-3 style code for Kosovo and is NOT recognised
  # by GADM — `pred("gadm", "XKX")` returns zero records. Verified against the
  # GBIF occurrence API:
  #     gadmGid=XKO -> 52,290 records
  #     gadmGid=XKX ->      0 records
  #     country=XK  -> 48,947 records
  gadm_gid = "XKO",

  # ISO3-style code stamped onto the records and onto the reference polygon,
  # used by the country-coordinate mismatch test.
  iso3 = "XKX",

  # --- Paths ----------------------------------------------------------------
  dir_download   = "data/gbif_download",
  dir_exports    = "data_exports",
  path_directives= "data/eu_directives_species.csv",
  path_gadm      = "data/gadm41_XKO.gpkg",
  path_boundary  = "data/kosovo_boundary.gpkg",
  path_municipal = "data/kosovo_municipalities.gpkg",
  path_protected = "data/kosovo_protected_areas.gpkg",
  path_vernacular= "data/vernacular_cache.csv",
  path_iucn      = "data/iucn_cache.csv",
  path_datasets  = "data/dataset_registry.csv",
  path_metadata  = "data/run_metadata.rds",
  path_key       = "data/gbif_download/download_key.txt",

  # --- Cleaning -------------------------------------------------------------
  #
  # The tests required by the brief: zero coordinates, country-coordinate
  # mismatches, GBIF headquarters, and biodiversity institutions. "equal" is
  # added as a cheap sanity test for transposed/identical lat==lon values.
  #
  # DELIBERATELY EXCLUDED: "capitals" and "centroids". Both remove records
  # within a radius of a capital city or a country/province centroid. Kosovo is
  # small and Pristina falls inside it, so those tests would discard large
  # numbers of legitimate urban and national records. Set `use_capitals_test`
  # to TRUE if you accept that trade-off.
  cleaning_tests    = c("zeros", "countries", "gbif", "institutions", "equal"),
  use_capitals_test = FALSE,
  country_buffer    = NULL,   # metres; NULL = strict boundary test

  # --- Enrichment -----------------------------------------------------------
  # Neither common names nor IUCN Red List categories are part of the GBIF
  # SIMPLE_CSV download; both are fetched per taxon from the species API and
  # cached on disk, so only the first run pays for them. Set either to a finite
  # number to cap the work done in a single run.
  vernacular_max_lookups = Inf,
  iucn_max_lookups       = Inf,

  # --- Coordinate precision -------------------------------------------------
  #
  # The GBIF Viewer discards records whose stated coordinate uncertainty
  # exceeds a threshold, on the grounds that a record placed to the nearest
  # 10 km cannot support a site-level decision. That is the right instinct, but
  # applied here it would silently remove more than half the dataset: 54 per
  # cent of Kosovo records carry an uncertainty of exactly 7,071 m, the
  # half-diagonal of a 10 km atlas square, and those records are perfectly good
  # evidence of presence at landscape scale.
  #
  # The pipeline therefore *reports* the precision profile rather than acting
  # on it, keeps `coordinateUncertaintyInMeters` in every export, and offers
  # the threshold as an opt-in. Readers filter interactively instead.
  coord_uncertainty_max = Inf,   # metres; Inf keeps every record

  # Uncertainty classes used in the precision report and the record explorer.
  precision_breaks = c(0, 100, 1000, 10000, Inf),
  precision_labels = c("100 m or better", "100 m &ndash; 1 km",
                       "1 &ndash; 10 km", "coarser than 10 km"),

  # --- Export ---------------------------------------------------------------
  # A lean column set keeps the published files small enough to serve from
  # GitHub Pages while retaining everything needed for conservation use.
  export_columns = c(
    "gbifID", "scientificName", "species", "vernacularName",
    "kingdom", "phylum", "class", "order", "family", "genus",
    "taxonRank", "taxonKey", "speciesKey",
    "iucnRedListCategory", "iucnRedListStatus",
    "eventDate", "year", "month", "day",
    "decimalLatitude", "decimalLongitude", "coordinateUncertaintyInMeters",
    "elevation", "locality", "municipality", "district",
    "protectedArea", "protectedAreaDesignation", "strictlyProtected",
    "basisOfRecord", "individualCount", "establishmentMeans",
    "recordedBy", "identifiedBy",
    "institutionCode", "collectionCode", "catalogNumber",
    "datasetKey", "license", "issue",
    "directive", "annex"
  ),

  # Excel is the format most conservation officers actually open, so the GBIF
  # Viewer offers it alongside CSV. It is written only for the smaller thematic
  # extracts: an .xlsx of the full 47,000-record table would be slow to build,
  # slow to open, and close to Excel's practical limits.
  xlsx_max_records = 12000
)

dir.create(config$dir_download, recursive = TRUE, showWarnings = FALSE)
dir.create(config$dir_exports,  recursive = TRUE, showWarnings = FALSE)

run_meta <- list(run_date = Sys.time(), config = config)


# ==============================================================================
# 2. DATA ACQUISITION — asynchronous GBIF download
# ==============================================================================
#
# `occ_download()` is used rather than `occ_search()` / `occ_data()` because
# only the asynchronous download service mints a DOI. The DOI is what makes the
# analysis citable and the underlying data permanently retrievable, which is a
# requirement for evidence used in policy.

check_gbif_credentials <- function() {
  needed <- c("GBIF_USER", "GBIF_PWD", "GBIF_EMAIL")
  missing <- needed[!nzchar(Sys.getenv(needed))]
  if (length(missing)) {
    stop(
      "Missing GBIF credentials: ", paste(missing, collapse = ", "), ".\n",
      "Add them to your .Renviron file and restart R. See README.md.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Request (or re-use) the GBIF download for Kosovo
#'
#' @return A list with the download key, DOI, citation and local zip path.
acquire_gbif_download <- function(cfg) {

  # Re-use a previous download where one exists, so that re-running the
  # pipeline does not mint a new DOI or re-queue work on the GBIF servers.
  if (file.exists(cfg$path_key)) {
    key <- readLines(cfg$path_key, warn = FALSE)[1]
    say("Re-using existing GBIF download: ", key)
  } else {
    check_gbif_credentials()
    say("Requesting a new GBIF download for GADM GID '", cfg$gadm_gid, "' ...")

    req <- occ_download(
      pred("gadm", cfg$gadm_gid),
      pred("hasCoordinate", TRUE),
      pred("hasGeospatialIssue", FALSE),
      pred("occurrenceStatus", "PRESENT"),
      format = "SIMPLE_CSV",
      user   = Sys.getenv("GBIF_USER"),
      pwd    = Sys.getenv("GBIF_PWD"),
      email  = Sys.getenv("GBIF_EMAIL")
    )

    key <- as.character(req)
    say("Download requested (key ", key, "). Waiting for GBIF to prepare it ...")
    occ_download_wait(req, curlopts = list(), quiet = FALSE)

    writeLines(key, cfg$path_key)
  }

  zip_path <- file.path(cfg$dir_download, paste0(key, ".zip"))
  if (!file.exists(zip_path)) {
    say("Downloading archive from GBIF ...")
    occ_download_get(key, path = cfg$dir_download, overwrite = TRUE)
  } else {
    say("Archive already present locally.")
  }

  meta <- occ_download_meta(key)
  citation <- tryCatch(
    gbif_citation(key)$download,
    error = function(e) NA_character_
  )

  list(
    key       = key,
    doi       = meta$doi %||% NA_character_,
    created   = meta$created %||% NA_character_,
    n_records = meta$totalRecords %||% NA_integer_,
    citation  = citation,
    zip_path  = zip_path
  )
}

download <- acquire_gbif_download(config)
run_meta$download <- download

say("DOI: ", download$doi)
say("Records in download: ", fmt_int(download$n_records))

say("Importing occurrence records ...")
raw_data <- occ_download_import(key = download$key, path = config$dir_download)
say("Imported ", fmt_int(nrow(raw_data)), " records with ",
    ncol(raw_data), " fields.")


# ==============================================================================
# 3. TAXONOMIC MATCHING — EU Birds and Habitats Directives
# ==============================================================================
#
# Species names on the directive annexes are matched to the GBIF backbone so
# that occurrence records can be selected by numeric key rather than by string,
# which is robust to synonymy and to authorship variation.

#' Match a directive species list to the GBIF backbone taxonomy
#'
#' Returns one row per input name, carrying both the matched `usageKey` and the
#' `speciesKey` of the accepted species.
#'
#' Matching on BOTH keys matters. Where an annex lists a subspecies — for
#' example *Rupicapra rupicapra balcanica* — the backbone returns the
#' subspecies `usageKey`, but occurrence records identified only to species
#' level carry the species-level key. Matching on `usageKey` alone would miss
#' every such record. This is deliberately inclusive: for a conservation
#' screening exercise a false positive is far cheaper than a missed protected
#' species, and the `annex` column preserves the listing for expert review.
#'
#' @param path CSV with columns `scientific_name`, `directive`, `annex`, and
#'   optionally the pre-resolved `gbif_usage_key` / `gbif_species_key` written
#'   by `R/build_directive_list.R`.
#' @return A tibble of the input list with GBIF keys and match diagnostics.
match_directive_species <- function(path) {

  if (!file.exists(path)) {
    stop("Species list not found: ", path,
         "\nExpected columns: scientific_name, directive, annex.\n",
         "Generate it with: Rscript R/build_directive_list.R", call. = FALSE)
  }

  species_list <- readr::read_csv(path, show_col_types = FALSE)

  required <- c("scientific_name", "directive", "annex")
  missing  <- setdiff(required, names(species_list))
  if (length(missing)) {
    stop("Species list is missing column(s): ", paste(missing, collapse = ", "),
         call. = FALSE)
  }

  pre_resolved <- all(c("gbif_usage_key", "gbif_species_key") %in%
                        names(species_list))

  if (pre_resolved) {
    # `R/build_directive_list.R` has already done the matching, including the
    # kingdom hints that resolve cross-kingdom homonyms and the retries for
    # subspecies notation. Re-matching here would discard that work and give a
    # worse result, so the stored keys are used as they are.
    say("Using pre-resolved GBIF keys from ", basename(path), ".")

    out <- species_list |>
      dplyr::mutate(
        usageKey   = suppressWarnings(as.integer(.data$gbif_usage_key)),
        speciesKey = suppressWarnings(as.integer(.data$gbif_species_key)),
        matchType  = if ("match_type" %in% names(species_list))
                       .data$match_type else NA_character_
      )

  } else {
    # A plain three-column list still works: resolve the names here.
    say("Matching ", nrow(species_list),
        " directive taxa to the GBIF backbone ...")

    matched <- rgbif::name_backbone_checklist(species_list$scientific_name)
    stopifnot(nrow(matched) == nrow(species_list))

    out <- species_list |>
      dplyr::bind_cols(
        matched |>
          dplyr::select(dplyr::any_of(c(
            "usageKey", "acceptedUsageKey", "scientificName", "canonicalName",
            "rank", "status", "matchType", "confidence", "speciesKey",
            "species", "class", "family", "kingdom"
          )))
      ) |>
      dplyr::mutate(
        usageKey   = suppressWarnings(as.integer(.data$usageKey)),
        speciesKey = suppressWarnings(as.integer(.data$speciesKey))
      )
  }

  # Genus- and family-level listings ("Alosa spp.") carry no species key and are
  # matched by name instead; they are not failures.
  if (!"listing_type" %in% names(out)) out$listing_type <- "taxon"

  unresolved <- out |>
    dplyr::filter(.data$listing_type == "taxon", is.na(.data$usageKey))

  if (nrow(unresolved) > 0) {
    say("NOTE: ", nrow(unresolved), " of ", nrow(out),
        " listings have no GBIF key and cannot be matched to occurrences.")
    say("      These are mostly names superseded since the directives were ",
        "adopted; see R/build_directive_list.R.")
  }

  say("Directive listings: ", fmt_int(nrow(out)), " rows, ",
      fmt_int(dplyr::n_distinct(out$scientific_name)), " distinct taxa, ",
      fmt_int(sum(!is.na(out$usageKey))), " with a GBIF key.")

  out
}

directive_matches <- match_directive_species(config$path_directives)
run_meta$directive_matches <- directive_matches

#' Collect every GBIF key associated with a directive selection
#'
#' @param x The matched directive table.
#' @param ... Filter expressions applied to `x`.
#' @return An integer vector of unique GBIF keys.
directive_keys <- function(x, ...) {
  sel <- dplyr::filter(x, ...)
  unique(stats::na.omit(c(sel$usageKey, sel$speciesKey, sel$acceptedUsageKey)))
}


# ==============================================================================
# 4. DATA CLEANING — CoordinateCleaner
# ==============================================================================

#' Clean occurrence coordinates
#'
#' Applies the CoordinateCleaner test battery and returns only the records that
#' pass every test, together with a per-test summary of what was removed.
#'
#' @param x Raw occurrence data frame.
#' @param cfg The pipeline configuration list.
#' @return A list with `clean` (data frame) and `report` (per-test tibble).
clean_occurrences <- function(x, cfg) {

  before <- nrow(x)

  # Drop records without usable coordinates before testing.
  x <- x |>
    dplyr::filter(!is.na(.data$decimalLatitude), !is.na(.data$decimalLongitude))

  say("Records with coordinates: ", fmt_int(nrow(x)),
      " (", fmt_int(before - nrow(x)), " dropped as missing).")

  # The country test needs a reference polygon that actually knows about
  # Kosovo — see `kosovo_boundary()` for why the default reference cannot be
  # used here, and why the reference is GADM level 0 rather than a coarser
  # outline. The occurrence data is stamped with the matching code.
  boundary <- kosovo_boundary(iso3 = cfg$iso3, cache_path = cfg$path_boundary,
                              gadm_path = cfg$path_gadm)
  x$.iso3  <- cfg$iso3

  tests <- cfg$cleaning_tests
  if (isTRUE(cfg$use_capitals_test)) tests <- unique(c(tests, "capitals", "centroids"))

  say("Running CoordinateCleaner tests: ", paste(tests, collapse = ", "))

  flags <- CoordinateCleaner::clean_coordinates(
    x              = as.data.frame(x),
    lon            = "decimalLongitude",
    lat            = "decimalLatitude",
    species        = "species",
    countries      = ".iso3",
    tests          = tests,
    country_ref    = boundary,
    country_refcol = "iso_a3",
    country_buffer = cfg$country_buffer,
    value          = "spatialvalid",
    verbose        = FALSE
  )

  flag_cols <- grep("^\\.", names(flags), value = TRUE)
  flag_cols <- setdiff(flag_cols, c(".summary", ".iso3"))

  report <- dplyr::tibble(
    Test    = flag_cols,
    Flagged = vapply(flag_cols, function(cn) sum(!flags[[cn]]), integer(1))
  ) |>
    dplyr::mutate(
      Test = dplyr::recode(.data$Test,
        ".val"  = "Invalid coordinates",
        ".equ"  = "Identical latitude / longitude",
        ".zer"  = "Zero coordinates / plain zeros",
        ".cap"  = "Capital city vicinity",
        ".cen"  = "Country or province centroid",
        ".con"  = "Country-coordinate mismatch",
        ".gbf"  = "GBIF headquarters",
        ".inst" = "Biodiversity institution",
        .default = .data$Test
      ),
      `Per cent` = round(100 * .data$Flagged / nrow(flags), 2)
    ) |>
    dplyr::arrange(dplyr::desc(.data$Flagged))

  clean <- flags |>
    dplyr::filter(.data$.summary) |>
    dplyr::select(-dplyr::all_of(c(flag_cols, ".summary", ".iso3")))

  say("Retained ", fmt_int(nrow(clean)), " / ", fmt_int(nrow(x)),
      " records (", round(100 * nrow(clean) / nrow(x), 2), "% passed).")

  list(clean = clean, report = report, boundary = boundary)
}

cleaning <- clean_occurrences(raw_data, config)
run_meta$cleaning_report <- cleaning$report
run_meta$n_raw           <- nrow(raw_data)
run_meta$n_clean         <- nrow(cleaning$clean)

print(cleaning$report)


# ==============================================================================
# 5. ENRICHMENT — vernacular names, Red List status, administrative unit
# ==============================================================================

say("Resolving vernacular names ...")
vernacular <- fetch_vernacular_names(
  species_keys = cleaning$clean$speciesKey,
  cache_path   = config$path_vernacular,
  max_lookups  = config$vernacular_max_lookups
)

say("Vernacular names available for ",
    fmt_int(sum(!is.na(vernacular$vernacularName))), " taxa.")

# --- IUCN Red List ------------------------------------------------------------
# The EU annexes and the Red List answer different questions — what is legally
# protected, and what is at risk — so a screening dataset needs both.

say("Resolving IUCN Red List categories ...")
iucn <- fetch_iucn_categories(
  species_keys = cleaning$clean$speciesKey,
  cache_path   = config$path_iucn,
  max_lookups  = config$iucn_max_lookups
)

say("Red List assessments available for ",
    fmt_int(sum(!is.na(iucn$iucnRedListCategory))), " of ",
    fmt_int(nrow(iucn)), " taxa.")

# --- Administrative unit ------------------------------------------------------
# Stamping each record with its municipality is what makes coverage reportable
# per unit, which is the question the GBIF Viewer's area selector is really
# asked: not "what is here" so much as "where has nobody looked".

municipalities <- kosovo_municipalities(cache_path = config$path_municipal,
                                        gadm_path  = config$path_gadm)
say("Municipal boundaries: ", nrow(municipalities), " units in ",
    dplyr::n_distinct(municipalities$district), " districts.")

# --- Protected areas ----------------------------------------------------------
# The municipality answers "where has anybody looked". The protected area
# answers the question a conservation officer asks next: of what has been
# found, how much of it sits on ground the state has already undertaken to
# look after, and how much does not.

protected_areas <- kosovo_protected_areas(cache_path = config$path_protected,
                                          layer      = "polygons")
protected_points <- kosovo_protected_areas(cache_path = config$path_protected,
                                           layer      = "points")

designated_sites <- protected_areas[
  protected_areas$designated_area_type == "designatedSite", ]

say("Protected areas: ", nrow(designated_sites), " designated sites with a ",
    "mapped boundary, ", nrow(protected_points), " recorded as a point, ",
    nrow(protected_areas) - nrow(designated_sites),
    " strict-protection boundaries.")

occurrences <- cleaning$clean |>
  dplyr::mutate(speciesKey = suppressWarnings(as.integer(.data$speciesKey))) |>
  dplyr::left_join(vernacular, by = "speciesKey") |>
  dplyr::left_join(iucn, by = "speciesKey") |>
  assign_municipality(municipalities) |>
  assign_protected_area(protected_areas)

say("Records located within a municipality: ",
    fmt_int(sum(!is.na(occurrences$municipality))), " / ",
    fmt_int(nrow(occurrences)), ".")

say("Records inside a designated protected area: ",
    fmt_int(sum(!is.na(occurrences$protectedArea))), " / ",
    fmt_int(nrow(occurrences)), " (",
    round(100 * mean(!is.na(occurrences$protectedArea)), 1), "%).")

if (is.finite(config$coord_uncertainty_max)) {
  before <- nrow(occurrences)
  occurrences <- dplyr::filter(
    occurrences,
    is.na(.data$coordinateUncertaintyInMeters) |
      .data$coordinateUncertaintyInMeters <= config$coord_uncertainty_max
  )
  say("Coordinate-uncertainty filter removed ",
      fmt_int(before - nrow(occurrences)), " records.")
}

# The precision profile is reported rather than acted on — see the note in the
# configuration block for why.
precision_report <- occurrences |>
  dplyr::mutate(
    .band = cut(suppressWarnings(as.numeric(.data$coordinateUncertaintyInMeters)),
                breaks = config$precision_breaks, right = TRUE,
                labels = config$precision_labels)
  ) |>
  dplyr::count(`Stated coordinate uncertainty` = .data$.band, name = "Records") |>
  dplyr::mutate(
    `Stated coordinate uncertainty` = as.character(
      dplyr::coalesce(as.character(.data$`Stated coordinate uncertainty`),
                      "not stated")),
    `Per cent` = round(100 * .data$Records / nrow(occurrences), 1)
  )

run_meta$precision_report <- precision_report
print(precision_report)


# ==============================================================================
# 6. SUBSETTING
# ==============================================================================
#
# Five thematic subsets are produced. Directive membership is attached as
# `directive` / `annex` columns, collapsed to one row per taxon so that the
# join can never duplicate occurrence records.

#' Collapse directive listings to one row per GBIF key
#'
#' Every key that can identify a listed taxon — the matched `usageKey`, the
#' accepted species key, and any accepted-usage key — is expanded into its own
#' row, then collapsed so that each key appears exactly once. This guarantees
#' the subsequent join cannot duplicate occurrence records.
#' @return A list with `keys` (one row per GBIF key) and `genera` (one row per
#'   genus, for "spp." listings).
directive_lookup <- function(x, ...) {

  sel <- dplyr::filter(x, ...)

  empty_keys <- dplyr::tibble(key = integer(), directive = character(),
                              annex = character())
  empty_gen  <- dplyr::tibble(genus = character(), directive = character(),
                              annex = character())

  if (nrow(sel) == 0) return(list(keys = empty_keys, genera = empty_gen))

  if (!"listing_type" %in% names(sel)) sel$listing_type <- "taxon"

  collapse_by <- function(d, col) {
    d |>
      dplyr::filter(!is.na(.data[[col]])) |>
      dplyr::group_by(.data[[col]]) |>
      dplyr::summarise(
        directive = paste(sort(unique(.data$directive)), collapse = "; "),
        annex     = paste(sort(unique(.data$annex)),     collapse = "; "),
        .groups   = "drop"
      )
  }

  # --- Taxon listings, matched by key ---------------------------------------
  #
  # WHICH KEYS ARE SAFE TO MATCH ON DEPENDS ON THE RANK THAT WAS LISTED.
  #
  # For a taxon listed at SPECIES rank, both the species key and the taxon key
  # are used, so that records identified to subspecies are still captured.
  #
  # For a taxon listed at SUBSPECIES rank, only the subspecies key is used.
  # Promoting a subspecies listing to its whole species would be badly wrong
  # here: the Birds Directive lists island endemics such as *Columba palumbus
  # azorica*, *Fringilla coelebs ombriosa* and *Parus ater cypriotes*, and
  # matching those at species level pulls every Wood Pigeon, Chaffinch and Coal
  # Tit in Kosovo into the Annex I subset — several thousand records for
  # subspecies that do not occur anywhere near the Balkans.
  taxa <- sel |> dplyr::filter(.data$listing_type != "genus_or_family")

  if (!"matched_rank" %in% names(taxa)) taxa$matched_rank <- NA_character_

  infraspecific <- !is.na(taxa$matched_rank) &
    taxa$matched_rank %in% c("SUBSPECIES", "VARIETY", "FORM")

  key_frame <- function(d, cols) {
    cols <- intersect(cols, names(d))
    if (nrow(d) == 0 || length(cols) == 0) return(empty_keys)
    dplyr::bind_rows(lapply(cols, function(cn) {
      dplyr::tibble(
        key       = suppressWarnings(as.integer(d[[cn]])),
        directive = d$directive,
        annex     = as.character(d$annex)
      )
    }))
  }

  keys <- dplyr::bind_rows(
    # Listed at species rank (or rank unknown): match the species too.
    key_frame(taxa[!infraspecific, , drop = FALSE],
              c("usageKey", "speciesKey", "acceptedUsageKey")),
    # Listed at subspecies rank: match that subspecies only.
    key_frame(taxa[infraspecific, , drop = FALSE],
              c("usageKey", "acceptedUsageKey"))
  )

  keys <- if (nrow(keys) > 0) collapse_by(keys, "key") else empty_keys

  # --- "spp." listings, matched by genus name -------------------------------
  #
  # A handful of annex entries list an entire genus ("Alosa spp.", "Barbus
  # spp."). Those cannot be matched by species key, so they are matched on the
  # genus name that GBIF assigns to each occurrence record.
  spp <- sel |> dplyr::filter(.data$listing_type == "genus_or_family")

  genera <- if (nrow(spp) > 0) {
    spp |>
      dplyr::mutate(genus = .data$scientific_name) |>
      collapse_by("genus")
  } else {
    empty_gen
  }

  list(keys = keys, genera = genera)
}

#' Select occurrence records belonging to a directive selection
#'
#' A record is retained when its `speciesKey` or `taxonKey` appears among the
#' listed keys, or when its genus is one of the genus-level listings. The
#' annotation is joined on whichever criterion actually matched, so that records
#' identified at subspecies level are still labelled with their annex.
subset_by_directive <- function(occ, lookup) {

  keys   <- lookup$keys
  genera <- lookup$genera

  if (nrow(keys) == 0 && nrow(genera) == 0) {
    return(
      occ[0, , drop = FALSE] |>
        dplyr::mutate(directive = character(), annex = character())
    )
  }

  species_key <- suppressWarnings(as.integer(occ$speciesKey))
  taxon_key   <- suppressWarnings(as.integer(occ$taxonKey))
  genus_name  <- if ("genus" %in% names(occ)) as.character(occ$genus)
                 else rep(NA_character_, nrow(occ))

  hit_species <- !is.na(species_key) & species_key %in% keys$key
  hit_taxon   <- !is.na(taxon_key)   & taxon_key   %in% keys$key
  hit_genus   <- !is.na(genus_name)  & genus_name  %in% genera$genus

  keep <- hit_species | hit_taxon | hit_genus
  out  <- occ[keep, , drop = FALSE]

  if (nrow(out) == 0) {
    return(dplyr::mutate(out, directive = character(), annex = character()))
  }

  out$.match_key   <- ifelse(hit_species[keep], species_key[keep],
                             ifelse(hit_taxon[keep], taxon_key[keep], NA_integer_))
  out$.match_genus <- ifelse(is.na(out$.match_key) & hit_genus[keep],
                             genus_name[keep], NA_character_)

  out |>
    dplyr::left_join(keys, by = c(".match_key" = "key")) |>
    dplyr::left_join(genera, by = c(".match_genus" = "genus"),
                     suffix = c("", ".genus")) |>
    dplyr::mutate(
      directive = dplyr::coalesce(.data$directive, .data$directive.genus),
      annex     = dplyr::coalesce(.data$annex,     .data$annex.genus)
    ) |>
    dplyr::select(-".match_key", -".match_genus",
                  -"directive.genus", -"annex.genus")
}

say("Building thematic subsets ...")

subsets <- list()

# (1) Overall biodiversity — every cleaned record.
subsets[["kosovo_overall_biodiversity"]] <- occurrences

# (2) Birds — class Aves.
subsets[["kosovo_birds"]] <- occurrences |>
  dplyr::filter(.data$class == "Aves")

# (3) Birds Directive, Annex I — species requiring Special Protection Areas.
#     The species list holds one row per taxon per annex, so an exact match on
#     the annex label is both simpler and safer than a regular expression.
subsets[["kosovo_birds_annex_I"]] <- subset_by_directive(
  occurrences,
  directive_lookup(directive_matches,
                   .data$directive == "Birds",
                   .data$annex == "I")
)

# (4) Habitats Directive — Annexes II, IV and V combined.
subsets[["kosovo_habitats_directive"]] <- subset_by_directive(
  occurrences,
  directive_lookup(directive_matches, .data$directive == "Habitats")
)

# (5) Habitats Directive, Annex II — species requiring Special Areas of
#     Conservation.
subsets[["kosovo_habitats_annex_II"]] <- subset_by_directive(
  occurrences,
  directive_lookup(directive_matches,
                   .data$directive == "Habitats",
                   .data$annex == "II")
)

# (6) IUCN-threatened species — Critically Endangered, Endangered, Vulnerable.
#     Membership follows the global Red List assessment carried by the GBIF
#     backbone, so this subset is independent of the EU annexes and picks up
#     species that are at risk without being legally listed.
subsets[["kosovo_threatened_iucn"]] <- occurrences |>
  dplyr::filter(.data$iucnRedListCategory %in% iucn_threatened)

subset_labels <- c(
  kosovo_overall_biodiversity = "Overall biodiversity",
  kosovo_birds                = "Birds (class Aves)",
  kosovo_birds_annex_I        = "Birds Directive, Annex I",
  kosovo_habitats_directive   = "Habitats Directive (all annexes)",
  kosovo_habitats_annex_II    = "Habitats Directive, Annex II",
  kosovo_threatened_iucn      = "IUCN threatened species (CR, EN, VU)"
)

for (nm in names(subsets)) {
  say("  ", format(subset_labels[[nm]], width = 34), " ",
      format(fmt_int(nrow(subsets[[nm]])), width = 8, justify = "right"),
      " records")
}


# ==============================================================================
# 7. EXPORT — GeoPackage, CSV and Excel
# ==============================================================================

#' Convert an occurrence table to an sf object and export it
#'
#' Writes a GeoPackage (geometry preserved), a CSV (flat table, with coordinate
#' columns retained) and — for the smaller extracts — an Excel workbook,
#' restricted to the configured column set.
#'
#' @param d Occurrence data frame.
#' @param name File stem, without extension.
#' @param cfg The pipeline configuration list.
#' @return The exported `sf` object, invisibly.
export_subset <- function(d, name, cfg) {

  keep <- intersect(cfg$export_columns, names(d))
  d    <- dplyr::select(d, dplyr::all_of(keep))

  gpkg <- file.path(cfg$dir_exports, paste0(name, ".gpkg"))
  csv  <- file.path(cfg$dir_exports, paste0(name, ".csv"))
  xlsx <- file.path(cfg$dir_exports, paste0(name, ".xlsx"))

  # CSV first: a flat table is what most analysts open, and it keeps the
  # coordinates as ordinary columns.
  readr::write_csv(d, csv, na = "")

  if (file.exists(xlsx)) unlink(xlsx)
  if (nrow(d) > 0 && nrow(d) <= cfg$xlsx_max_records &&
      requireNamespace("writexl", quietly = TRUE)) {
    writexl::write_xlsx(as.data.frame(d), xlsx)
  }

  if (nrow(d) == 0) {
    # An empty GeoPackage cannot be written from a zero-row sf object, so
    # remove any stale file and report the gap rather than failing the run.
    if (file.exists(gpkg)) unlink(gpkg)
    warning("Subset '", name, "' contains no records; no GeoPackage written.",
            call. = FALSE)
    return(invisible(NULL))
  }

  spatial <- sf::st_as_sf(
    d,
    coords = c("decimalLongitude", "decimalLatitude"),
    crs    = 4326,
    remove = FALSE
  )

  if (file.exists(gpkg)) unlink(gpkg)
  sf::st_write(spatial, gpkg, layer = name, quiet = TRUE)

  invisible(spatial)
}

say("Exporting datasets to ", config$dir_exports, "/ ...")

exported <- list()
for (nm in names(subsets)) {
  exported[[nm]] <- export_subset(subsets[[nm]], nm, config)
}

# A machine-readable manifest of what was published, used by the report to
# build the download table with accurate file sizes.
manifest <- dplyr::bind_rows(lapply(names(subsets), function(nm) {

  spp <- subsets[[nm]]$species

  # Names and sizes are resolved BEFORE the tibble is built. `tibble()`
  # evaluates its arguments in sequence with the earlier columns in scope, so
  # writing `gpkg = basename(gpkg)` and then `gpkg_size = file.size(gpkg)`
  # silently measures the bare filename rather than the path — the file is not
  # found, `file.size()` returns NA, and every download button loses its size.
  described <- function(ext) {
    path <- file.path(config$dir_exports, paste0(nm, ".", ext))
    if (file.exists(path)) {
      list(name = basename(path), size = as.numeric(file.size(path)))
    } else {
      list(name = NA_character_, size = NA_real_)
    }
  }

  g <- described("gpkg"); c_ <- described("csv"); x <- described("xlsx")

  dplyr::tibble(
    name      = nm,
    label     = unname(subset_labels[[nm]]),
    records   = nrow(subsets[[nm]]),
    species   = dplyr::n_distinct(spp[!is.na(spp) & nzchar(spp)]),
    gpkg      = g$name,  gpkg_size = g$size,
    csv       = c_$name, csv_size  = c_$size,
    xlsx      = x$name,  xlsx_size = x$size
  )
}))

print(manifest |> dplyr::select(label, records, species))

# --- The protected-area register ----------------------------------------------
# Published alongside the occurrence extracts, because a reader screening a
# development proposal needs the site boundaries as much as the records, and
# because the EEA's own distribution is a 1.7 GB file covering 38 countries.
# Both geometries go into one GeoPackage, as two layers; the flat table carries
# all 256 sites, point-only ones included, since the attributes are complete
# even where the boundary is not.

say("Exporting the protected-area register ...")

pa_counts <- summarise_protected_areas(occurrences, protected_areas) |>
  dplyr::select("natda_id", "records", "species", "records_per_km2")

# The counts are attached to the polygons rather than recomputed, so the map,
# the table and the published file cannot disagree.
pa_polygons <- protected_areas |>
  dplyr::left_join(pa_counts, by = "natda_id")

pa_gpkg <- file.path(config$dir_exports, "kosovo_protected_areas.gpkg")
if (file.exists(pa_gpkg)) unlink(pa_gpkg)

sf::st_write(pa_polygons, pa_gpkg, layer = "protected_area_polygons",
             quiet = TRUE)
sf::st_write(protected_points, pa_gpkg, layer = "protected_area_points",
             quiet = TRUE)

# `geometry` here records how the site is represented in the register, not the
# geometry column itself — the sites with no mapped boundary are the point-only
# natural monuments, and a reader filtering the table needs to see which.
pa_register <- dplyr::bind_rows(
  sf::st_drop_geometry(pa_polygons)      |> dplyr::mutate(geometry = "boundary"),
  sf::st_drop_geometry(protected_points) |> dplyr::mutate(geometry = "point")
) |>
  dplyr::arrange(dplyr::desc(.data$reported_area_ha))

readr::write_csv(pa_register,
                 file.path(config$dir_exports, "kosovo_protected_areas.csv"),
                 na = "")

if (requireNamespace("writexl", quietly = TRUE)) {
  writexl::write_xlsx(as.data.frame(pa_register),
                      file.path(config$dir_exports,
                                "kosovo_protected_areas.xlsx"))
}


# ==============================================================================
# 8. RUN METADATA
# ==============================================================================
#
# Saved so that the Quarto report can state the DOI, the citation, the record
# counts and the cleaning outcome without re-running any of the analysis.

run_meta$manifest      <- manifest
run_meta$subset_labels <- subset_labels
run_meta$n_species     <- dplyr::n_distinct(
  occurrences$species[!is.na(occurrences$species)]
)

# --- Attribution --------------------------------------------------------------
# Every contributing dataset and publishing institution, resolved to a title
# so the report can credit them by name rather than by UUID.

say("Building the dataset attribution table ...")
dataset_registry <- fetch_dataset_registry(
  dataset_keys = occurrences$datasetKey,
  cache_path   = config$path_datasets
)

run_meta$datasets <- occurrences |>
  dplyr::count(datasetKey = .data$datasetKey, name = "records") |>
  dplyr::left_join(
    occurrences |>
      dplyr::group_by(datasetKey = .data$datasetKey) |>
      dplyr::summarise(
        species = dplyr::n_distinct(.data$species[!is.na(.data$species) &
                                                    nzchar(.data$species)]),
        .groups = "drop"),
    by = "datasetKey"
  ) |>
  dplyr::left_join(dataset_registry, by = "datasetKey") |>
  dplyr::arrange(dplyr::desc(.data$records))

say("  ", nrow(run_meta$datasets), " datasets from ",
    dplyr::n_distinct(run_meta$datasets$publisher), " publishers.")

# --- Coverage by municipality -------------------------------------------------

run_meta$municipal_summary <- sf::st_drop_geometry(
  summarise_by_municipality(occurrences, municipalities)
)

# --- Protected-area coverage --------------------------------------------------
#
# The denominators matter here and are easy to get wrong, so they are computed
# once, in one place, and the report reads them rather than deriving its own.
#
#   * `network_km2` is the area of the UNION of the designated sites, not the
#     sum of their areas. Seven of Kosovo's sites overlap along their edges,
#     and summing would count the shared ground twice — 1,306 km² against the
#     1,261 km² actually covered.
#   * The strict-protection boundaries are excluded from that union for the
#     same reason: every one of them lies inside a site already counted.

network_km2 <- as.numeric(units::set_units(
  sf::st_area(sf::st_union(sf::st_transform(designated_sites, 32634))), "km^2"))

country_km2 <- as.numeric(units::set_units(
  sf::st_area(sf::st_transform(cleaning$boundary, 32634)), "km^2"))

run_meta$protected_areas <- list(
  source        = cdda_source,
  n_sites       = nrow(designated_sites) + nrow(protected_points),
  n_mapped      = nrow(designated_sites),
  n_point_only  = nrow(protected_points),
  n_strict      = nrow(protected_areas) - nrow(designated_sites),
  network_km2   = network_km2,
  country_km2   = country_km2,
  coverage_pct  = 100 * network_km2 / country_km2,
  records_inside = sum(!is.na(occurrences$protectedArea)),
  records_strict = sum(occurrences$strictlyProtected),
  records_total  = nrow(occurrences),
  species_inside = dplyr::n_distinct(
    occurrences$species[!is.na(occurrences$protectedArea) &
                          !is.na(occurrences$species) &
                          nzchar(occurrences$species)]),
  summary       = summarise_protected_areas(occurrences, protected_areas),
  register      = pa_register,
  # `role` keeps the two kinds of row apart. Kosovo's 19 strict nature reserves
  # are zones inside sites that the table already lists, so their area and
  # their records are contained in the rows above rather than additional to
  # them, and a reader must not add the column up.
  by_designation = pa_register |>
    dplyr::mutate(
      role = ifelse(.data$designated_area_type == "strictProtectionBoundary",
                    "zone within a site", "site")
    ) |>
    dplyr::group_by(designation = .data$designation, role = .data$role) |>
    dplyr::summarise(
      sites      = dplyr::n(),
      mapped     = sum(.data$geometry == "boundary"),
      area_ha    = sum(.data$reported_area_ha, na.rm = TRUE),
      records    = sum(.data$records, na.rm = TRUE),
      # No species column: species counts cannot be added across sites without
      # counting a species once for every site it occurs in.
      .groups    = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(.data$area_ha))
)

say("Protected-area network: ", round(network_km2), " km2, ",
    round(100 * network_km2 / country_km2, 1), "% of Kosovo.")

# --- Red List profile ---------------------------------------------------------

run_meta$iucn_summary <- occurrences |>
  dplyr::filter(!is.na(.data$species), nzchar(.data$species)) |>
  dplyr::distinct(.data$species, .keep_all = TRUE) |>
  dplyr::count(category = iucn_group(.data$iucnRedListCategory),
               name = "species") |>
  dplyr::arrange(match(as.character(.data$category), iucn_levels))

saveRDS(run_meta, config$path_metadata)

say("Pipeline complete.")
say("  DOI:        ", run_meta$download$doi)
say("  Raw:        ", fmt_int(run_meta$n_raw), " records")
say("  Cleaned:    ", fmt_int(run_meta$n_clean), " records")
say("  Species:    ", fmt_int(run_meta$n_species))
say("  Metadata:   ", config$path_metadata)
say("Next step: render the website with  quarto render")
