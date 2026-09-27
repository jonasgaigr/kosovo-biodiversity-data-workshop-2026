# ==============================================================================
# run_test_site_report.R
#
# A smoke test for the site-level reporting tool in R/site_report.R — the code
# that turns a protected-area register and a cleaned occurrence export into one
# GeoPackage and one PDF per site.
#
# Run with:  Rscript run_test_site_report.R
#
# It needs no GBIF credentials and makes no network calls, so it is safe to run
# on a fresh clone before the pipeline has ever been executed.
#
# IT WRITES NOTHING INTO THE PROJECT. Every fixture and every output goes into
# a directory under `tempdir()` — read the warning at the top of `run_test.R`
# for what the previous generation of this project's tests cost when they did
# otherwise.
#
# The fixtures are synthetic and deliberately awkward: a site whose name folds
# to the same slug as another's, a site with no records at all, a site recorded
# as a point, and a name carrying both diacritics and quotation marks.
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(sf)
})

source("R/functions.R")
source("R/site_report.R")

# --- Tiny test harness --------------------------------------------------------
#
# The same harness as `run_test.R`, copied rather than sourced: sourcing that
# file would run its 80 checks as a side effect of loading four functions.

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

#' Check that an expression fails, and that its message says something useful
errors_with <- function(label, pattern, expr) {
  out <- tryCatch({ force(expr); NULL },
                  error = function(e) conditionMessage(e))
  check(label, !is.null(out) && grepl(pattern, out))
}


# ==============================================================================
# 1. FIXTURES — written into tempdir() and nowhere else
# ==============================================================================

work <- file.path(tempdir(), paste0("site-report-test-",
                                    format(Sys.time(), "%H%M%S")))
dir.create(file.path(work, "data"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(work, "exports"), recursive = TRUE, showWarnings = FALSE)

cat("\nFixtures in ", work, "\n", sep = "")

square <- function(xmin, ymin, size) {
  sf::st_polygon(list(rbind(
    c(xmin, ymin), c(xmin + size, ymin), c(xmin + size, ymin + size),
    c(xmin, ymin + size), c(xmin, ymin))))
}

# Four polygons: two designated sites, one strict-protection zone inside the
# first, and a site with no records at all. The two site names differ only in
# the diacritics that the slug fold removes, which is what makes them a
# collision test.
pa_polygons <- sf::st_sf(
  natda_id                 = c("1001", "1002", "1003", "1004"),
  national_id              = c("NP_01", "NR_01", "NM_01", "NM_02"),
  site_name                = c("Parku \"Gjë e Bukur\"", "Bërthama",
                               "Gjë e Bukur", "Guri i Zi"),
  designation_code         = c("XK01", "XK02", "XK06", "XK06"),
  designated_area_type     = c("designatedSite", "strictProtectionBoundary",
                               "designatedSite", "designatedSite"),
  iucn_management_category = c("II", "Ia", "III", "III"),
  reported_area_ha         = c(2000, 100, 400, 100),
  designation_year         = c(2001L, 2005L, 1999L, 1988L),
  ecosystem_type           = "terrestrial",
  management_plan          = NA_character_,
  designation              = c("National Park", "Strict Nature Reserve",
                               "Natural Monument", "Natural Monument"),
  designation_sq           = c("Parku Kombëtar", "Rezervat Natyror",
                               "Monument Natyre", "Monument Natyre"),
  authority                = "Ministry",
  area_km2                 = c(19.0, 1.2, 4.9, 1.2),
  geometry = sf::st_sfc(
    square(20.50, 42.50, 0.05),    # the national park
    # The zone's edges are deliberately offset from every record's coordinate.
    # A corner that lands exactly on a record makes the count depend on which
    # way the floating-point arithmetic of `xmin + size` happens to fall.
    square(20.505, 42.505, 0.02),  # a strict zone inside the park
    square(20.70, 42.70, 0.02),    # a monument with records
    square(20.90, 42.90, 0.02),    # a monument with none
    crs = 4326)
)

# One point-only site, the common case in a real register.
pa_points <- sf::st_sf(
  natda_id                 = "1005",
  national_id              = "NM_03",
  site_name                = "Lisi i Vjetër",
  designation_code         = "XK06",
  designated_area_type     = "designatedSite",
  iucn_management_category = "III",
  reported_area_ha         = 3.14,           # a circle of radius 100 m
  designation_year         = 1975L,
  ecosystem_type           = "terrestrial",
  management_plan          = NA_character_,
  designation              = "Natural Monument",
  designation_sq           = "Monument Natyre",
  authority                = "Municipality",
  geometry = sf::st_sfc(sf::st_point(c(21.10, 43.10)), crs = 4326)
)

register_path <- file.path(work, "data", "register.gpkg")
sf::st_write(pa_polygons, register_path, layer = "protected_area_polygons",
             quiet = TRUE)
sf::st_write(pa_points, register_path, layer = "protected_area_points",
             quiet = TRUE)

# Records: six inside the park (one of them in the strict zone), two in the
# monument, two just outside the park (the buffer case), one at the point-only
# site, and one far away. None in "Guri i Zi", which is the zero-record case.
occ <- dplyr::tibble(
  gbifID           = as.character(101:113),
  scientificName   = "x",
  species          = c("Aaa aaa", "Aaa aaa", "Bbb bbb", "Ccc ccc", "Ddd ddd",
                       "Eee eee", "Fff fff", "Ggg ggg", "Hhh hhh", "Iii iii",
                       "Jjj jjj", "Kkk kkk", NA),
  vernacularName   = "Something",
  kingdom          = c(rep("Animalia", 6), rep("Plantae", 4), "Fungi",
                       "Animalia", "Animalia"),
  family           = c(rep("Fam1", 6), rep("Fam2", 4), "Fam3", "Fam4", "Fam5"),
  year             = c(2001L, 2002L, 2002L, 2005L, 2005L, 2005L,
                       2010L, 2011L, 2012L, 2013L, 2014L, 2015L, NA),
  eventDate        = NA_character_,
  decimalLongitude = c(20.51, 20.52, 20.53, 20.515, 20.54, 20.52,
                       20.705, 20.706, 20.560, 20.561,
                       21.1001, 19.00, 19.01),
  decimalLatitude  = c(42.51, 42.52, 42.53, 42.515, 42.54, 42.52,
                       42.705, 42.706, 42.520, 42.521,
                       43.1001, 41.00, 41.01),
  iucnRedListCategory = c("VU", "LC", "LC", "EN", "LC", "NE",
                          "LC", "LC", "NE", "NE", "LC", "LC", NA),
  datasetKey       = c(rep("ds-1", 7), rep("ds-2", 6)),
  license          = "CC_BY_4_0",
  strictlyProtected = FALSE,
  municipality     = "Unit A",
  district         = "District A"
)

occ_sf <- sf::st_as_sf(occ, coords = c("decimalLongitude", "decimalLatitude"),
                       crs = 4326, remove = FALSE)
occ_path <- file.path(work, "exports", "occurrences.gpkg")
sf::st_write(occ_sf, occ_path, layer = "occurrences", quiet = TRUE)

# One record on each annex, joined by identifier exactly as the real subsets do.
directives_path <- file.path(work, "exports", "directive_subset.csv")
readr::write_csv(
  dplyr::tibble(gbifID = c("101", "104"), directive = c("Birds", "Habitats"),
                annex = c("I", "II")),
  directives_path)

# Two administrative units and a national outline.
units <- sf::st_sf(
  municipality = c("Unit A", "Unit B"),
  district     = c("District A", "District A"),
  geometry = sf::st_sfc(square(20.0, 42.0, 1.0), square(21.0, 43.0, 1.0),
                        crs = 4326)
)
units_path <- file.path(work, "data", "units.gpkg")
sf::st_write(units, units_path, quiet = TRUE)

country <- sf::st_sf(
  iso_a3 = "XXX",
  geometry = sf::st_sfc(square(19.5, 41.5, 2.5), crs = 4326)
)
country_path <- file.path(work, "data", "country.gpkg")
sf::st_write(country, country_path, quiet = TRUE)

meta_path <- file.path(work, "data", "run_metadata.rds")
saveRDS(list(download = list(key = "test-key", doi = "10.0000/test",
                             created = "2026-01-01T00:00:00Z",
                             citation = "A test citation")), meta_path)

datasets_path <- file.path(work, "data", "datasets.csv")
readr::write_csv(
  dplyr::tibble(datasetKey = c("ds-1", "ds-2"),
                datasetTitle = c("Dataset one", "Dataset two"),
                publisher = c("Publisher one", "Publisher two")),
  datasets_path)

cfg <- list(
  path_register  = register_path,
  layer_polygons = "protected_area_polygons",
  layer_points   = "protected_area_points",
  site_type      = "designatedSite",
  strict_type    = "strictProtectionBoundary",
  register_fields = list(
    natda_id = "natda_id", national_id = "national_id",
    site_name = "site_name", designation = "designation",
    designation_sq = "designation_sq", designation_code = "designation_code",
    designated_area_type = "designated_area_type",
    iucn_management_category = "iucn_management_category",
    reported_area_ha = "reported_area_ha",
    designation_year = "designation_year", ecosystem_type = "ecosystem_type",
    management_plan = "management_plan", authority = "authority"),
  register_source = list(name = "Test register", version = "v0",
                         licence = "CC0", doi = "10.0000/register"),
  path_occurrences  = occ_path,
  layer_occurrences = "occurrences",
  path_directive_subsets = directives_path,
  path_boundary          = country_path,
  path_municipalities    = units_path,
  municipality_field     = "municipality",
  path_metadata = meta_path,
  path_datasets = datasets_path,
  made_by       = "Rscript pipeline.R",
  crs_storage = 4326,
  crs_metric  = 3035,
  buffer_m    = 1000,
  grid_m      = 1000,
  point_default_radius_m = 100,
  locator_ring_m = 6000,
  map_max_points = 20000,
  top_datasets   = 5,
  slug_max_chars = 60
)

options(site_report.quiet = TRUE)
ctx <- site_report_context(cfg)
reg <- ctx$register


# ==============================================================================
# 2. SLUGS
# ==============================================================================

cat("\nSlugs\n")

check("a slug is ASCII, lower case and hyphenated",
      grepl("^[a-z0-9-]+$", make_slug("Parku Kombëtar \"Sharri\"")))

check("diacritics fold rather than being dropped",
      make_slug("Ujëvarat e Mirushës") == "ujevarat-e-mirushes")

check("quotation marks and punctuation become separators, not characters",
      make_slug("Parku Kombëtar \"Sharri\"") == "parku-kombetar-sharri")

check("a slug is truncated at a hyphen, never mid-word",
      {
        s <- make_slug(paste(rep("nemuna", 20), collapse = " "), max_chars = 20)
        nchar(s) <= 20 && !grepl("-$", s) && s == "nemuna-nemuna"
      })

check("the same name gives the same slug on every call",
      identical(make_slug(reg$site_name), make_slug(reg$site_name)))

check("names that fold to one slug are disambiguated by identifier",
      {
        clashing <- c("Gjë e Bukur", "Gje e Bukur")
        s <- register_slugs(c("A1", "A2"), clashing)
        length(unique(s)) == 2 && all(grepl("^gje-e-bukur-a[12]$", s))
      })

check("every site in the register has a unique slug",
      length(unique(reg$slug)) == nrow(reg))

check("a site with no usable name still gets a slug",
      register_slugs("77", "—") == "site-77")


# ==============================================================================
# 3. SITE RESOLUTION
# ==============================================================================

cat("\nSite resolution\n")

check("a site resolves by register identifier",
      reg$natda_id[resolve_site(reg, "1001")] == "1001")

check("a site resolves by national identifier",
      reg$natda_id[resolve_site(reg, "NM_03")] == "1005")

check("a national identifier resolves whatever its case",
      resolve_site(reg, "nm_03") == resolve_site(reg, "NM_03"))

check("a site resolves by a fragment of its name",
      reg$natda_id[resolve_site(reg, "Guri")] == "1004")

check("a name matches without its diacritics",
      reg$natda_id[resolve_site(reg, "lisi i vjeter")] == "1005")

check("the identifier wins over a name that would also match",
      # "1001" is a register identifier and nothing else, so precedence is
      # visible: the search never reaches the name test.
      reg$natda_id[resolve_site(reg, "1001")] == "1001")

errors_with("an ambiguous fragment lists the candidates",
            "matches 2 sites",
            resolve_site(reg, "e Bukur"))

errors_with("an ambiguous fragment names them, rather than picking one",
            "Parku",
            resolve_site(reg, "e Bukur"))

errors_with("an unmatched key says how many sites were searched",
            "against 4 sites",
            resolve_site(reg, "not a site"))

cat("\nSite selection\n")

check("--all selects every designated site, and no strict zone",
      {
        idx <- select_sites(reg, all = TRUE)
        length(idx) == 4 && !("1002" %in% reg$natda_id[idx])
      })

check("--designation filters the selection",
      {
        idx <- select_sites(reg, all = TRUE, designation = "Natural Monument")
        setequal(reg$natda_id[idx], c("1003", "1004", "1005"))
      })

check("--iucn-category filters the selection",
      {
        idx <- select_sites(reg, all = TRUE, iucn_category = "II")
        identical(reg$natda_id[idx], "1001")
      })

check("--min-area-km2 filters on the reported area",
      {
        idx <- select_sites(reg, all = TRUE, min_area_km2 = 5)
        identical(reg$natda_id[idx], "1001")
      })

errors_with("a filter that leaves nothing is an error, not an empty run",
            "No site is left",
            select_sites(reg, all = TRUE, designation = "Marine Reserve"))

errors_with("neither --site nor --all is an error",
            "give --site, or --all",
            select_sites(reg))


# ==============================================================================
# 4. THE SITE DATASET
# ==============================================================================

cat("\nClipping and summarising\n")

park <- build_site_dataset(ctx, resolve_site(reg, "1001"),
                           command = "test command")

check("records are clipped to the boundary",
      park$site_boundary$records == 6)

check("the buffer carries the records just outside, flagged",
      {
        occ <- park$occurrences
        sum(occ$inside_site) == 6 && sum(occ$in_buffer_only) == 2 &&
          nrow(occ) == 8
      })

check("species, families and datasets are counted distinctly",
      # Six records, but one species recorded twice: five species, one family,
      # one dataset.
      park$site_boundary$species == 5 && park$site_boundary$families == 1 &&
        park$site_boundary$datasets == 1)

check("area is computed in the metric CRS, not taken from the register",
      {
        a <- park$site_boundary$computed_area_km2
        # A 0.05 degree square at 42.5 N is about 4.1 km by 5.6 km.
        a > 20 && a < 25 && !("area_km2" %in% names(park$site_boundary))
      })

check("records per square kilometre follow the computed area",
      isTRUE(all.equal(park$site_boundary$records_per_km2,
                       park$site_boundary$records /
                         park$site_boundary$computed_area_km2)))

check("the strict zone inside the site is reported, with its own count",
      {
        # Four of the site's six records fall in the zone, counted by the
        # zone's own geometry rather than by the site stamp — and counted
        # inside the site as well, not instead of it.
        s <- park$strict_protection
        nrow(s) == 1 && s$natda_id == "1002" && s$records == 4 &&
          s$records <= park$site_boundary$records
      })

check("the species summary has one row per species, with its years",
      {
        s <- park$species_summary
        nrow(s) == 5 && all(s$records >= 1) &&
          s$first_year[s$species == "Aaa aaa"] == 2001 &&
          s$last_year[s$species == "Aaa aaa"] == 2002
      })

check("directive annotations are joined by record identifier",
      {
        s <- park$species_summary
        s$directive[s$species == "Aaa aaa"] == "Birds" &&
          s$annex[s$species == "Aaa aaa"] == "I" &&
          s$directive[s$species == "Ccc ccc"] == "Habitats"
      })

check("a record is never duplicated by the directive join",
      nrow(park$occurrences) == 8)

check("the grid drops empty cells from the published layers but counts them",
      {
        published <- nrow(park$record_density_grid)
        published > 0 &&
          published <= park$site_boundary$grid_cells &&
          park$site_boundary$grid_cells_with_records == published &&
          park$site_boundary$unrecorded_share > 0
      })

check("every record inside the site is in a grid cell",
      sum(park$record_density_grid$records) == park$site_boundary$records)

check("grid classes come from the shared density breaks",
      all(park$record_density_grid$density_class %in%
            plain_text(density_labels)))

check("the overlapping administrative units carry both shares",
      {
        u <- park$municipalities_overlapping
        nrow(u) == 1 && u$municipality == "Unit A" &&
          u$share_of_site > 0.99 && u$share_of_unit < 0.5
      })

check("the taxonomic summary uses the palette's kingdom classes",
      {
        t <- site_taxonomic_summary(
          park$occurrences[park$occurrences$inside_site, ])
        all(t$kingdom %in% names(map_palette$kingdom)) && sum(t$records) == 6
      })

cat("\nDeterminism\n")

again <- build_site_dataset(ctx, resolve_site(reg, "1001"),
                            command = "test command")

check("the same inputs give the same species summary, row for row",
      identical(park$species_summary, again$species_summary))

check("the same inputs give the same occurrence layer, in the same order",
      identical(sf::st_drop_geometry(park$occurrences),
                sf::st_drop_geometry(again$occurrences)))

check("the same inputs give the same grid",
      identical(sf::st_drop_geometry(park$record_density_grid),
                sf::st_drop_geometry(again$record_density_grid)))

check("only the run timestamp differs between two builds of one site",
      {
        a <- park$report_metadata
        b <- again$report_metadata
        differing <- a$item[a$value != b$value |
                              (is.na(a$value) != is.na(b$value))]
        all(differing %in% "run_timestamp_utc")
      })


# ==============================================================================
# 5. THE AWKWARD SITES
# ==============================================================================

cat("\nA site with no records\n")

empty <- build_site_dataset(ctx, resolve_site(reg, "1004"),
                            command = "test command")

check("a zero-record site is built rather than refused",
      empty$site_boundary$records == 0 && empty$site_boundary$species == 0)

check("its species summary is empty rather than missing",
      is.data.frame(empty$species_summary) && nrow(empty$species_summary) == 0)

check("all of its area is reported as unrecorded",
      isTRUE(all.equal(empty$site_boundary$unrecorded_share, 1)))

check("its key figures degrade to NA years rather than to infinities",
      is.na(empty$site_boundary$first_year) &&
        is.na(empty$site_boundary$last_year))

cat("\nA site recorded as a point\n")

point <- build_site_dataset(ctx, resolve_site(reg, "1005"),
                            command = "test command")

check("a point-only site is buffered to a circle of the reported area",
      {
        # 3.14 ha is a circle of radius 100 m; the area is preserved to within
        # the buffer's segmentation.
        a_ha <- point$site_boundary$computed_area_km2 * 100
        abs(a_ha - 3.14) / 3.14 < 0.01
      })

check("the substitution is stated in the metadata, not left to be inferred",
      grepl("circle of the reported area",
            meta_value(point$report_metadata, "boundary_basis")))

check("the geometry it came from is recorded too",
      point$site_boundary$geometry_source == "point")

check("records still fall inside the circle",
      point$site_boundary$records == 1)


# ==============================================================================
# 6. THE GEOPACKAGE
# ==============================================================================

cat("\nThe GeoPackage\n")

gpkg_dir <- file.path(work, "out", park$slug)
gpkg     <- file.path(gpkg_dir, paste0(park$slug, ".gpkg"))
write_site_gpkg(park, gpkg)

layers <- sf::st_layers(gpkg)

check("every documented layer is written, in the documented order",
      identical(layers$name, site_gpkg_layers))

check("every spatial layer is stored in EPSG:4326",
      {
        crs <- vapply(site_gpkg_layers, function(l) {
          x <- sf::st_read(gpkg, layer = l, quiet = TRUE)
          if (inherits(x, "sf")) as.character(sf::st_crs(x)$epsg) else NA_character_
        }, character(1))
        all(crs[!is.na(crs)] == "4326")
      })

check("the attribute-only tables are written without geometry",
      {
        x <- sf::st_read(gpkg, layer = "species_summary", quiet = TRUE)
        !inherits(x, "sf") && nrow(x) == nrow(park$species_summary)
      })

check("the metadata layer names the download, the register and the code",
      {
        md <- sf::st_read(gpkg, layer = "report_metadata", quiet = TRUE)
        !is.na(meta_value(md, "gbif_download_doi")) &&
          !is.na(meta_value(md, "register_version")) &&
          meta_value(md, "tool_version") == site_report_version &&
          meta_value(md, "crs_metric") == "EPSG:3035"
      })

check("the metadata layer names every input and when it was last changed",
      {
        md <- sf::st_read(gpkg, layer = "report_metadata", quiet = TRUE)
        items <- md$item
        all(c("input_register_path", "input_occurrences_path",
              "input_register_modified_utc") %in% items)
      })

check("a zero-record site still writes every layer, empty where it must be",
      {
        p <- file.path(work, "out", empty$slug, paste0(empty$slug, ".gpkg"))
        write_site_gpkg(empty, p)
        l <- sf::st_layers(p)
        identical(l$name, site_gpkg_layers) &&
          l$features[l$name == "occurrences"] == 0
      })

empty_gpkg <- file.path(work, "out", empty$slug, paste0(empty$slug, ".gpkg"))

check("an empty layer carries the same columns as a full one",
      {
        # A site with no strict zone inside it, against one that has one.
        full  <- sf::st_read(gpkg, layer = "strict_protection", quiet = TRUE)
        blank <- sf::st_read(empty_gpkg, layer = "strict_protection",
                             quiet = TRUE)
        nrow(full) > 0 && nrow(blank) == 0 &&
          identical(names(full), names(blank))
      })

check("an empty layer keeps its geometry type",
      {
        types <- function(p) {
          l <- sf::st_layers(p)
          stats::setNames(as.character(l$geomtype), l$name)
        }
        identical(types(gpkg), types(empty_gpkg))
      })

check("reading the file back gives the layers the report is built from",
      {
        back <- read_site_gpkg(gpkg)
        all(site_gpkg_layers %in% names(back)) &&
          back$site_boundary$records == park$site_boundary$records
      })

check("the GeoPackage and the summary tables agree on the record count",
      {
        back <- read_site_gpkg(gpkg)
        sum(back$occurrences$inside_site) == back$site_boundary$records &&
          sum(back$species_summary$records) == back$site_boundary$records
      })

cat("\nThe national ranking\n")

check("every site in the register is ranked",
      nrow(ctx$national) == nrow(reg))

check("the ranking counts the same way the site report does",
      {
        n <- ctx$national
        n$records[n$natda_id == "1001"] == park$site_boundary$records
      })

check("ranks are counted from the best downwards, ties taking the better rank",
      {
        r <- site_ranks(ctx$national, "1001")
        r$rank[r$measure == "Records"] == 1 &&
          r$of[r$measure == "Records"] == nrow(reg)
      })

cat("\nIdempotency\n")

check("outputs newer than every input are up to date",
      outputs_up_to_date(gpkg, cfg$path_register))

check("an output older than an input is not",
      {
        # A file created now is newer than the GeoPackage written a moment
        # ago. Written rather than back-dated with `Sys.setFileTime()`:
        # whether a file's time can be set at all is a property of the file
        # system, and a test should not depend on one.
        newer <- file.path(work, "newer-than-the-output.txt")
        writeLines("changed", newer)
        !outputs_up_to_date(gpkg, newer)
      })

check("a missing output is never up to date",
      !outputs_up_to_date(file.path(work, "nothing.gpkg"), cfg$path_register))

cat("\nFailing loudly\n")

errors_with("a missing input names the file and the command that makes it",
            "Rscript pipeline\\.R",
            require_input(file.path(work, "absent.gpkg"),
                          "Rscript pipeline.R", "The register"))

errors_with("a register column the configuration points at must exist",
            "register_fields",
            standardise_register(sf::st_drop_geometry(pa_polygons),
                                 list(natda_id = "no_such_column")))

cat("\nLicences and labels\n")

check("the download's licence enums are named as the registry's URIs are",
      identical(licence_name(c("CC_BY_4_0", "CC_BY_NC_4_0", "CC0_1_0")),
                c("CC BY 4.0", "CC BY-NC 4.0", "CC0 1.0")))

check("an unrecognised licence is kept rather than guessed at",
      licence_name("UNSPECIFIED") == "UNSPECIFIED")

check("the HTML entities of the shared labels are resolved for print",
      !any(grepl("&", plain_text(density_labels), fixed = TRUE)))

cat("\nMaps build\n")

check("the locator map builds",
      inherits(site_locator_map(park, ctx$country, ctx$municipalities, cfg),
               "ggplot"))

check("the occurrence map builds",
      inherits(site_occurrence_map(park, cfg), "ggplot"))

check("the occurrence map of a site with no records builds, and says so",
      {
        p <- site_occurrence_map(empty, cfg)
        inherits(p, "ggplot") && grepl("No quality-checked GBIF record",
                                       attr(p, "map_note"))
      })

check("above the cap the points are withheld and the map says why",
      {
        p <- site_occurrence_map(park, cfg, max_points = 1)
        grepl("withheld rather than thinned", attr(p, "map_note"))
      })

check("below the cap every record is drawn",
      grepl("All 6 records inside the site are mapped",
            attr(site_occurrence_map(park, cfg), "map_note")))

cat("\nColours, against the website's\n")

# The site report and the website are one publication, and the website is the
# reference: the same colour has to do the same job in both. Nothing can share
# the values — Typst cannot read SCSS, and a `_brand.yml` would restyle the
# website as well — so the four files that carry them are read back here and
# compared. These checks are all that stands between an edited theme and two
# documents that no longer look related.

scss  <- readLines("custom.scss", warn = FALSE)
theme <- readLines("reports/gbif-report.typ", warn = FALSE)
qmd   <- readLines("reports/site_report.qmd", warn = FALSE)

# `#let gbif-ink = rgb("#358305")` becomes c(`gbif-ink` = "#358305").
theme_colours <- {
  hits <- regmatches(theme, regexec(
    "^#let ([a-z-]+) +=? *rgb\\(\"(#[0-9A-Fa-f]{6})\"\\)", theme))
  hits <- hits[lengths(hits) == 3L]
  toupper(stats::setNames(vapply(hits, `[`, character(1), 3L),
                          vapply(hits, `[`, character(1), 2L)))
}

# `$primary-ink: #358305 !default;` becomes "#358305".
scss_value <- function(name) {
  hit <- regmatches(scss, regexec(
    paste0("^\\$", name, ": +(#[0-9A-Fa-f]{6})"), scss))
  hit <- hit[lengths(hit) == 2L]
  if (!length(hit)) NA_character_ else toupper(hit[[1]][2])
}

in_scss <- function(colour) any(grepl(colour, scss, ignore.case = TRUE))

check("the theme states a colour for every job the report has",
      setequal(names(theme_colours),
               c("gbif-black", "gbif-green", "gbif-ink", "gbif-azure",
                 "rule-grey", "caption-ink", "box-ground", "code-ink")))

check("body text is the page's body colour",
      theme_colours[["gbif-black"]] == scss_value("gbif-black"))

check("rules wear the brand green and text wears the ink step",
      theme_colours[["gbif-green"]] == scss_value("gbif-green") &&
        theme_colours[["gbif-ink"]] == scss_value("primary-ink"))

check("the citation block keeps the page's secondary colour",
      theme_colours[["gbif-azure"]] == scss_value("gbif-azure"))

check("no colour is invented: every one of them is on the page too",
      all(vapply(theme_colours[names(theme_colours) != "code-ink"],
                 in_scss, logical(1))))

check("inline code is the ink the page renders `code` in",
      {
        # The one value not written in `custom.scss`: Quarto derives the code
        # colour from the link colour by shading it 22 per cent, and what the
        # page actually renders is that result.
        ink <- grDevices::col2rgb(scss_value("primary-ink"))[, 1]
        shaded <- sprintf("#%02X%02X%02X", round(ink[1] * 0.78),
                          round(ink[2] * 0.78), round(ink[3] * 0.78))
        theme_colours[["code-ink"]] == shaded
      })

check("the figures are lettered in the same inks as the text around them",
      toupper(report_ink$text) == theme_colours[["gbif-black"]] &&
        toupper(report_ink$caption) == theme_colours[["caption-ink"]])

check("the maps take their colours from the palette, not from literals",
      !any(grepl("#[0-9A-Fa-f]{6}",
                 c(deparse(body(site_locator_map)),
                   deparse(body(site_occurrence_map))))))

check("the template includes the theme, and the theme is where it says",
      any(grepl("include-in-header: gbif-report.typ", qmd, fixed = TRUE)) &&
        file.exists("reports/gbif-report.typ"))

check("the pieces the template calls by name are defined in the theme",
      all(vapply(c("swatch", "keyfigure"),
                 function(f) any(grepl(paste0("^#let ", f, "\\("), theme)) &&
                   any(grepl(paste0("#", f), qmd, fixed = TRUE)),
                 logical(1))))

check("a Red List swatch is the colour the page gives that category",
      any(grepl("map_palette$iucn", qmd, fixed = TRUE)))


# ==============================================================================
# 7. RESULT
# ==============================================================================

# The fixtures are left in tempdir(), which the session cleans up. Nothing was
# written anywhere else — that is the point.

cat("\n")
if (.failures == 0L) {
  cat("All checks passed.\n")
} else {
  cat(sprintf("%d check(s) FAILED.\n", .failures))
  quit(status = 1L)
}
