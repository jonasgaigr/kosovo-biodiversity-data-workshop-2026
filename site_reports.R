# ==============================================================================
# site_reports.R
#
# Site-level reports for a protected-area register: one GeoPackage and one PDF
# per designated site, built from data already on disk.
#
# Run with:  Rscript site_reports.R --site "Bjeshket e Nemuna"
#            Rscript site_reports.R --all
#            Rscript site_reports.R --help
#
# No GBIF credentials, no network access and no new download: this reads what
# `pipeline.R` has already published. If an input is missing the run stops and
# names the file and the command that produces it.
#
# ------------------------------------------------------------------------------
# ADAPTING THIS TO ANOTHER COUNTRY OR ANOTHER SITE NETWORK
#
# Everything country-specific is in the `config` list below, and nothing
# outside it needs to change:
#
#   * `path_register` / `layer_*` / `register_fields` — the designated-area
#     register and the names its attributes go by. `register_fields` maps the
#     source's column names onto the schema this tool publishes, so a register
#     that is not a CDDA extract is a matter of editing that list rather than
#     the code.
#   * `path_occurrences` — any GBIF export carrying `gbifID`, coordinates and
#     the usual backbone columns.
#   * `path_boundary` / `path_municipalities` — the national context layers the
#     locator map is drawn on.
#   * `path_directive_subsets` — the legal framework. Set it to `character()`
#     where the EU Nature Directives do not apply; the report then says so
#     instead of showing an empty annex table as though it were a finding.
#   * `crs_metric` — EPSG:3035 is the European standard for area. Elsewhere,
#     the national equal-area projection.
#   * `register_source` — the provenance line every output carries.
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(sf)
  library(ggplot2)
})

source("R/functions.R")
source("R/site_report.R")


# ==============================================================================
# 1. CONFIGURATION
# ==============================================================================

config <- list(

  # --- The register ---------------------------------------------------------
  path_register  = "data/kosovo_protected_areas.gpkg",
  layer_polygons = "protected_area_polygons",
  layer_points   = "protected_area_points",

  # The two kinds of polygon in a CDDA extract. Only the first is a site; the
  # second is the strictly protected core of a site already listed in its own
  # right, which is why the two are never added together.
  site_type   = "designatedSite",
  strict_type = "strictProtectionBoundary",

  # The published GeoPackage schema on the left, the register's own column
  # names on the right. For this CDDA extract the two coincide.
  register_fields = list(
    natda_id                 = "natda_id",
    national_id              = "national_id",
    site_name                = "site_name",
    designation              = "designation",
    designation_sq           = "designation_sq",
    designation_code         = "designation_code",
    designated_area_type     = "designated_area_type",
    iucn_management_category = "iucn_management_category",
    reported_area_ha         = "reported_area_ha",
    designation_year         = "designation_year",
    ecosystem_type           = "ecosystem_type",
    management_plan          = "management_plan",
    authority                = "authority"
  ),

  # Where the register came from, quoted in every report.
  register_source = list(
    name    = "EEA Nationally designated areas (CDDA)",
    version = cdda_source$version,
    licence = cdda_source$licence,
    doi     = cdda_source$doi
  ),

  # --- The evidence ---------------------------------------------------------
  path_occurrences  = "data_exports/kosovo_overall_biodiversity.gpkg",
  layer_occurrences = "kosovo_overall_biodiversity",

  # The cleaned export carries no annex columns — the pipeline attaches those
  # to the thematic subsets only — so directive membership is joined back from
  # these by record identifier.
  path_directive_subsets = c(
    "data_exports/kosovo_birds_annex_I.csv",
    "data_exports/kosovo_habitats_directive.csv"
  ),

  # --- National context -----------------------------------------------------
  path_boundary            = "data/kosovo_boundary.gpkg",
  path_municipalities      = "data/kosovo_municipalities.gpkg",
  municipality_field       = "municipality",
  municipality_group_field = "district",

  path_metadata = "data/run_metadata.rds",
  path_datasets = "data/dataset_registry.csv",

  # The command named in every "this file is missing" message.
  made_by = "Rscript pipeline.R",

  # --- Code -----------------------------------------------------------------
  path_functions   = "R/functions.R",
  path_site_report = "R/site_report.R",
  path_template    = "reports/site_report.qmd",
  path_theme       = "reports/gbif-report.typ",

  # --- Outputs --------------------------------------------------------------
  dir_out                  = "outputs/protected_areas",
  path_manifest            = "outputs/run_manifest.csv",
  path_national_statistics = "outputs/national_site_statistics.csv",

  # --- Measurement ----------------------------------------------------------
  #
  # Stored in EPSG:4326 because the outputs travel and a reader opening them
  # should not have to know which UTM zone the country falls in; measured in
  # EPSG:3035 (ETRS89-LAEA), which is what the European Environment Agency
  # computes area in. Both are written into every `report_metadata` layer, so
  # neither has to be inferred from the numbers.
  crs_storage = 4326,
  crs_metric  = 3035,

  buffer_m = 1000,
  grid_m   = 1000,

  # A point-only site is drawn as a circle of the area the register reports for
  # it. This radius is the placeholder used when even that is missing, and it
  # is labelled as a placeholder wherever it appears.
  point_default_radius_m = 100,

  # The locator ring, so that a site of a few hundred square metres can be
  # found on a map of the whole country.
  locator_ring_m = 6000,

  # Above this many records the point layer is withheld and the density grid is
  # drawn instead, with the reason printed on the map. Records are never
  # silently thinned.
  map_max_points = 20000,

  top_datasets   = 5,
  slug_max_chars = 60
)


# ==============================================================================
# 2. COMMAND LINE
# ==============================================================================

usage <- function() {
  cat(
    "Usage: Rscript site_reports.R [options]\n",
    "\n",
    "Produces one GeoPackage and one PDF per protected area, from data already\n",
    "on disk. No network access and no GBIF credentials are needed.\n",
    "\n",
    "Selecting sites\n",
    "  --site VALUE          A site identifier, a national identifier, or part\n",
    "                        of a site name (case- and diacritic-insensitive).\n",
    "                        Repeatable. An ambiguous name lists the candidates.\n",
    "  --all                 Every designated site in the register.\n",
    "  --designation NAME    Keep only this designation, e.g. \"National Park\".\n",
    "  --iucn-category CODE  Keep only this IUCN management category, e.g. II.\n",
    "  --min-area-km2 N      Keep only sites of at least N km2 as reported.\n",
    "\n",
    "Output\n",
    "  --out DIR             Output directory (default outputs/protected_areas).\n",
    "  --buffer M            Comparison buffer in metres (default 1000).\n",
    "  --gpkg-only           Write the GeoPackage, skip the PDF.\n",
    "  --pdf-only            Render the PDF from an existing GeoPackage.\n",
    "  --force               Regenerate even when the outputs are up to date.\n",
    "  --quiet               Print nothing but errors and the run summary.\n",
    "  --help                This message.\n",
    "\n",
    "Examples\n",
    "  Rscript site_reports.R --site \"Bjeshket e Nemuna\"\n",
    "  Rscript site_reports.R --site 555547192 --site NP_001\n",
    "  Rscript site_reports.R --all --designation \"National Park\" --out outputs/np\n",
    "  Rscript site_reports.R --site NP_002 --gpkg-only --force\n",
    sep = "")
}

#' Parse the command line
#'
#' Base R rather than `optparse`: the grammar is a dozen flags, and a batch
#' tool that must run on a fresh clone should not need a package installed to
#' print its own usage.
#'
#' An unknown argument is an error. A typo that is merely warned about produces
#' a run that looks successful and reports on the wrong sites.
#'
#' @param args The raw arguments.
#' @return A list of options.
parse_args <- function(args) {

  opt <- list(
    sites = character(), all = FALSE, designation = NULL,
    iucn_category = NULL, min_area_km2 = NULL, out = NULL, buffer = NULL,
    gpkg_only = FALSE, pdf_only = FALSE, force = FALSE, quiet = FALSE,
    help = FALSE
  )

  takes_value <- c("--site", "--designation", "--iucn-category",
                   "--min-area-km2", "--out", "--buffer")

  i <- 1L
  while (i <= length(args)) {

    arg   <- args[[i]]
    value <- NULL

    # Both `--out DIR` and `--out=DIR` are accepted, because both are what
    # people type.
    if (grepl("^--[a-z0-9-]+=", arg)) {
      value <- sub("^--[a-z0-9-]+=", "", arg)
      arg   <- sub("=.*$", "", arg)
    } else if (arg %in% takes_value) {
      if (i == length(args)) {
        stop(arg, " needs a value.", call. = FALSE)
      }
      i <- i + 1L
      value <- args[[i]]
    }

    switch(
      arg,
      "--site"          = opt$sites <- c(opt$sites, value),
      "--all"           = opt$all <- TRUE,
      "--designation"   = opt$designation <- value,
      "--iucn-category" = opt$iucn_category <- value,
      "--min-area-km2"  = opt$min_area_km2 <- value,
      "--out"           = opt$out <- value,
      "--buffer"        = opt$buffer <- value,
      "--gpkg-only"     = opt$gpkg_only <- TRUE,
      "--pdf-only"      = opt$pdf_only <- TRUE,
      "--force"         = opt$force <- TRUE,
      "--quiet"         = opt$quiet <- TRUE,
      "--help"          = opt$help <- TRUE,
      "-h"              = opt$help <- TRUE,
      stop("Unknown argument: ", arg,
           "\nRun  Rscript site_reports.R --help  for the options.",
           call. = FALSE)
    )

    i <- i + 1L
  }

  numeric_option <- function(x, what) {
    if (is.null(x)) return(NULL)
    n <- suppressWarnings(as.numeric(x))
    if (is.na(n)) stop("--", what, " needs a number, not ", shQuote(x),
                       call. = FALSE)
    n
  }

  opt$min_area_km2 <- numeric_option(opt$min_area_km2, "min-area-km2")
  opt$buffer       <- numeric_option(opt$buffer, "buffer")

  if (opt$gpkg_only && opt$pdf_only) {
    stop("--gpkg-only and --pdf-only ask for opposite things.", call. = FALSE)
  }

  opt
}

opt <- parse_args(commandArgs(trailingOnly = TRUE))

if (opt$help) {
  usage()
  quit(status = 0L)
}

options(site_report.quiet = opt$quiet)

if (!is.null(opt$out))    config$dir_out  <- opt$out
if (!is.null(opt$buffer)) config$buffer_m <- opt$buffer


# ==============================================================================
# 3. THE RUN
# ==============================================================================

started <- Sys.time()

ctx <- site_report_context(config)

# Written once per run rather than once per site: it is the table every report
# quotes its national rank from, and a reader checking a rank should be able to
# see the whole ranking rather than take it on trust.
dir.create(dirname(config$path_national_statistics), recursive = TRUE,
           showWarnings = FALSE)
readr::write_csv(ctx$national, config$path_national_statistics, na = "")

selected <- select_sites(
  ctx$register,
  keys          = opt$sites,
  all           = opt$all,
  designation   = opt$designation,
  iucn_category = opt$iucn_category,
  min_area_km2  = opt$min_area_km2
)

site_say("Reporting on ", length(selected), " site",
         if (length(selected) == 1) "" else "s", " into ", config$dir_out, "/")

# The inputs an output has to be newer than. The code is included: a changed
# template with unchanged data must regenerate, or a re-run would quietly
# republish the previous layout.
watched_inputs <- c(
  config$path_register, config$path_occurrences, config$path_boundary,
  config$path_municipalities, config$path_metadata, config$path_datasets,
  config$path_directive_subsets,
  config$path_functions, config$path_site_report, config$path_template,
  config$path_theme, "site_reports.R"
)

#' The command that reproduces one site's outputs
#'
#' Built from what this run actually used rather than from the arguments as
#' typed, so that a report produced by `--all` still names a command that
#' rebuilds that one site.
reproducing_command <- function(natda_id) {
  parts <- c("Rscript site_reports.R", paste0("--site ", natda_id))
  if (!identical(config$buffer_m, 1000)) {
    parts <- c(parts, paste0("--buffer ", config$buffer_m))
  }
  if (!identical(config$dir_out, "outputs/protected_areas")) {
    parts <- c(parts, paste0("--out ", config$dir_out))
  }
  paste(parts, collapse = " ")
}

results <- vector("list", length(selected))

for (n in seq_along(selected)) {

  i    <- selected[[n]]
  row  <- ctx$register[i, , drop = FALSE]
  slug <- row$slug
  t0   <- Sys.time()

  out_dir <- file.path(config$dir_out, slug)
  gpkg    <- file.path(out_dir, paste0(slug, ".gpkg"))
  pdf     <- file.path(out_dir, paste0(slug, ".pdf"))

  label <- paste0("[", n, "/", length(selected), "] ", row$site_name,
                  " (", row$natda_id, ")")

  outcome <- tryCatch({

    wanted <- c(if (!opt$pdf_only) gpkg, if (!opt$gpkg_only) pdf)

    if (!opt$force && outputs_up_to_date(wanted, watched_inputs)) {

      site_say(label, " — skipped: every output is newer than every input. ",
               "Use --force to regenerate.")
      list(status = "skipped", records = NA_integer_, species = NA_integer_,
           message = "outputs newer than inputs")

    } else {

      site_say(label)

      if (opt$pdf_only) {

        if (!file.exists(gpkg)) {
          stop("--pdf-only needs the GeoPackage that the report is built ",
               "from, and there is none at ", gpkg,
               ".\nRun the same command without --pdf-only first.",
               call. = FALSE)
        }
        layers   <- read_site_gpkg(gpkg)
        boundary <- layers$site_boundary
        dataset  <- list(slug = slug)
        records  <- boundary$records[1]
        species  <- boundary$species[1]

      } else {

        dataset <- build_site_dataset(ctx, i,
                                      command = reproducing_command(row$natda_id))
        write_site_gpkg(dataset, gpkg)
        records <- dataset$site_boundary$records[1]
        species <- dataset$site_boundary$species[1]
        site_say("  ", fmt_int(records), " records, ", fmt_int(species),
                 " species, ", basename(gpkg), " written.")
      }

      if (!opt$gpkg_only) {
        render_site_pdf(dataset, out_dir, config,
                        command = reproducing_command(row$natda_id))
        site_say("  ", basename(pdf), " rendered.")
      }

      list(status = "ok", records = records, species = species,
           message = NA_character_)
    }
  },
  error = function(e) {
    # One site failing is not the run failing. The error is logged, the loop
    # continues, and the summary lists every failure at the end.
    message("  FAILED: ", row$site_name, " (", row$natda_id, "): ",
            conditionMessage(e))
    list(status = "failed", records = NA_integer_, species = NA_integer_,
         message = conditionMessage(e))
  })

  seconds <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)

  # Per-site timing, printed as well as recorded: a run over the whole register
  # is long enough that a reader watching it needs to know whether it is
  # progressing or stuck on one site.
  if (identical(outcome$status, "ok")) site_say("  done in ", seconds, " s")

  results[[n]] <- manifest_row(
    timestamp_utc = format(as.POSIXct(t0), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    natda_id      = row$natda_id,
    national_id   = row$national_id,
    slug          = slug,
    site_name     = row$site_name,
    records       = outcome$records,
    species       = outcome$species,
    gpkg          = if (file.exists(gpkg)) gpkg else NA_character_,
    gpkg_bytes    = if (file.exists(gpkg)) as.numeric(file.size(gpkg)) else NA_real_,
    pdf           = if (file.exists(pdf)) pdf else NA_character_,
    pdf_bytes     = if (file.exists(pdf)) as.numeric(file.size(pdf)) else NA_real_,
    seconds       = seconds,
    status        = outcome$status,
    message       = outcome$message
  )
}

manifest <- dplyr::bind_rows(results)
append_run_manifest(config$path_manifest, manifest)


# ==============================================================================
# 4. SUMMARY
# ==============================================================================

ok      <- sum(manifest$status == "ok")
skipped <- sum(manifest$status == "skipped")
failed  <- manifest[manifest$status == "failed", , drop = FALSE]

cat("\n")
say("Finished in ",
    round(as.numeric(difftime(Sys.time(), started, units = "secs"))), " s: ",
    ok, " written, ", skipped, " skipped, ", nrow(failed), " failed.")
say("Manifest: ", config$path_manifest)

if (nrow(failed)) {
  cat("\nFailures:\n")
  for (k in seq_len(nrow(failed))) {
    cat("  ", failed$natda_id[k], "  ", failed$site_name[k], "\n    ",
        failed$message[k], "\n", sep = "")
  }
  quit(status = 1L)
}

quit(status = 0L)
