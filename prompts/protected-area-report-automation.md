# Prompt — Replicable and automated map and report production for biodiversity conservation

**What this is.** A single, self-contained brief to hand to a coding agent (Claude
Code, or any LLM with file access) working in this repository. It asks for a
site-level reporting tool: point it at a protected area and it returns a
GeoPackage of that site's biodiversity evidence and a short PDF report on it.

**Why it is written this way.** The deliverable is not one set of maps — it is the
machinery that produces them again, unattended, when GBIF publishes new records
or the designated-area register changes. Everything below is therefore phrased as
a standing contract the code must keep, not as a one-off request. The section
*Adapting this prompt* at the end says what to change to reuse it elsewhere.

---

## 1. Context the agent must read before writing any code

You are working in `kosovo-biodiversity-data-workshop-2026`, an R + Quarto
project that already acquires, cleans and publishes GBIF occurrence data for
Kosovo. **Read these files first — do not duplicate what they already do:**

| File | What it already gives you |
|---|---|
| `pipeline.R` | GBIF download → cleaning → directive matching → export. Its `config` list is the model for how configuration is done here. |
| `R/functions.R` | ~2,700 lines of shared helpers. Deliberately sourced by *both* `pipeline.R` and `index.qmd` so that map and summary logic exists in one place. Your code joins that arrangement; it does not start a second copy of it. |
| `index.qmd` | The national report. The section structure, tone and table design of the PDF should be recognisably the same document family. |
| `README.md` | House style, the GBIF colour rationale, repository layout. |
| `run_test.R` | The offline test harness and its non-negotiable rule: tests write **nothing** into the project. |

Helpers you are expected to reuse rather than reimplement:
`kosovo_protected_areas()`, `assign_protected_area()`, `summarise_protected_areas()`,
`kosovo_boundary()`, `kosovo_municipalities()`, `assign_municipality()`,
`summarise_subset()`, `occurrence_density_grid()`, `kingdom_group()`,
`iucn_group()`, `short_licence()`, `say()`, `fmt_int()`, `fmt_date_en()`.

Data already on disk (no new downloads required for a normal run):

- `data/kosovo_protected_areas.gpkg` — layers `protected_area_polygons`
  (designated sites and strict-protection boundaries) and
  `protected_area_points`. Key attributes: `natda_id`, `national_id`,
  `site_name`, `designation`, `designation_sq`, `designation_code`,
  `designated_area_type`, `iucn_management_category`, `reported_area_ha`,
  `area_km2`, `designation_year`, `ecosystem_type`, `management_plan`,
  `authority`.
- `data_exports/kosovo_overall_biodiversity.gpkg` / `.csv` — the cleaned
  occurrence records, already carrying `protectedArea`,
  `protectedAreaDesignation`, `strictlyProtected`, `municipality`,
  `iucnCategory`, `vernacularName`, `directive`, `annex`.
- `data/kosovo_boundary.gpkg`, `data/kosovo_municipalities.gpkg`.
- `data/dataset_registry.csv` — dataset and publisher titles, DOIs, licences.
- `data/run_metadata.rds` — GBIF download DOI, citation, record counts,
  cleaning report. **Every output must be traceable to this.**

---

## 2. What to build

Three new artefacts, and nothing else in the project may change behaviour:

1. **`R/site_report.R`** — the library. All site-level selection, clipping,
   summarising and static-map drawing lives here, as documented functions in
   the roxygen-style used by `R/functions.R`. It is sourced by both the runner
   and the Quarto template, for the same reason `R/functions.R` is shared.
2. **`site_reports.R`** — the command-line runner in the project root, matching
   `pipeline.R` in shape: banner comment, `config` list, `say()` progress.
3. **`reports/site_report.qmd`** — a parameterised Quarto document that renders
   one site to PDF.

### 2.1 The command-line interface

```
Rscript site_reports.R --site "Bjeshkët e Nemuna"
Rscript site_reports.R --site 555547192 --site NP_001
Rscript site_reports.R --all
Rscript site_reports.R --all --designation "National Park" --out outputs/np
Rscript site_reports.R --site NP_002 --gpkg-only --force
```

Required behaviour:

- `--site` accepts, in this order of precedence, a `natda_id`, a `national_id`,
  or a case- and diacritic-insensitive substring of `site_name`. Repeatable.
- An ambiguous name is an **error that lists the candidates**, never a silent
  pick of the first match.
- `--all` processes every designated site; `--designation`, `--iucn-category`
  and `--min-area-km2` filter that set.
- `--out DIR` (default `outputs/protected_areas`), `--buffer M` (default 1000),
  `--gpkg-only` / `--pdf-only`, `--force`, `--quiet`.
- `--help` prints usage. An unknown argument is an error, not a warning.
- Argument parsing uses base R `commandArgs()` or `optparse`; do not add a
  heavy dependency for this.
- Exit status is non-zero if any requested site failed.

### 2.2 The GeoPackage — `outputs/<slug>/<slug>.gpkg`

One file per site, layers written in this order, all stored in **EPSG:4326**
for portability, with every metric quantity computed in **EPSG:3035**
(ETRS89-LAEA, the European standard for area) and that choice recorded in the
metadata layer:

| Layer | Contents |
|---|---|
| `site_boundary` | The site polygon with its full register attributes plus computed record and species counts. |
| `site_buffer` | The boundary buffered by `--buffer`, used for the "just outside" comparison. |
| `strict_protection` | Any strict-protection boundaries falling inside the site. |
| `occurrences` | Every cleaned record inside the boundary, full attribute set, plus `inside_site` / `in_buffer_only` flags and `strictlyProtected`. |
| `species_richness_grid` | 1 km grid, distinct species per cell, empty cells dropped. |
| `record_density_grid` | The same grid, record counts, classed with the density breaks already used in the national report. |
| `municipalities_overlapping` | Municipalities the site touches, with the share of each inside it. |
| `species_summary` | Attribute-only table: one row per species, with counts, kingdom, IUCN category, directive and annex, first and last observation year. |
| `report_metadata` | Attribute-only table: site id, run timestamp (UTC, ISO 8601), GBIF download DOI and citation, source-file paths and their modification times, buffer distance, CRS used, tool version, R and key package versions. |

Determinism is part of the contract: fixed sort orders everywhere, no unseeded
randomness, and stable output when the inputs have not changed.

### 2.3 The PDF — `outputs/<slug>/<slug>.pdf`

Four to six pages, rendered through Quarto with `format: typst` (no LaTeX
installation required — say so in the documentation) from
`reports/site_report.qmd`, parameterised on the resolved site id and driven by
`quarto::quarto_render(execute_params = ...)`. Content, in order:

1. **Header block** — site name (Albanian and English), designation, IUCN
   management category, designation year, reported and computed area,
   responsible authority, whether a management plan is recorded.
2. **Locator map** — the site within Kosovo, with municipalities for context.
3. **Occurrence map** — records inside the site, coloured by kingdom in the
   GBIF palette already defined in `R/functions.R`, with the strict-protection
   zones and the buffer shown.
4. **Key figures** — records, species, families, datasets, records per km², the
   national rank of the site on each, and the first and most recent observation
   year.
5. **Taxonomic composition** — records and species by kingdom group.
6. **Species of conservation interest** — IUCN threatened species and Birds /
   Habitats Directive annex species, as tables with vernacular names. State
   plainly when either table is empty.
7. **Recording effort and its gaps** — the density grid summarised, the share of
   the site with no records at all, the years with no records, and the dominant
   datasets. This section exists to stop a reader mistaking absence of records
   for absence of species; say that in the text.
8. **Provenance and citation** — GBIF download DOI and full citation, the CDDA
   version behind the boundary, the licences present in the extract, the
   generation date, and the exact command that reproduces the document.

Static maps only (`ggplot2` or `tmap`), no Leaflet, and **no network tile
requests during rendering** — the tool must work offline and produce the same
output a year from now. Use the boundary and municipality layers for context.

### 2.4 Robustness

- A site with **zero records** must still produce both outputs, with the empty
  sections stating that plainly. This is the common case for small natural
  monuments and it must not be an error.
- A point-only site (no mapped boundary) is handled by buffering the point to a
  circle of the reported area and labelling it as such, both in the report and
  in a flag in `report_metadata`.
- Site names carry Albanian diacritics and embedded quotation marks
  (`Parku Kombëtar "Bjeshkët e Nemuna"`). Slugs must be ASCII, lower case,
  hyphenated, stable across runs, and collision-checked against `natda_id`.
- `--all` over roughly 250 sites must read the occurrence layer **once**, use a
  spatial index, and report progress and per-site timing. One site failing logs
  the error and continues; the run summary lists the failures.
- Every run appends to `outputs/run_manifest.csv`: site id, slug, timestamp,
  record and species counts, output paths and sizes, wall time, status.

---

## 3. Replicability requirements — the actual point of the exercise

These are graded as strictly as the outputs:

- **No hard-coded site names, ids or counts anywhere.** Everything comes from
  the register or from the configuration list.
- **Nothing Kosovo-specific outside `config`.** The runner must work when the
  protected-area layer is replaced by another country's CDDA extract and the
  occurrence export by another GBIF download, with the changes confined to the
  `config` list and documented in the file header.
- **Idempotent.** Re-running without `--force` and without changed inputs skips
  regeneration and says why. No new GBIF download is ever triggered.
- **Traceable.** Every output states which GBIF download, which register version
  and which code version produced it. An output that cannot name its inputs is a
  defect.
- **Fails loudly.** A missing input file produces an actionable message naming
  the file and the command that creates it, never a silent empty result.
- **Offline-capable.** Once `pipeline.R` has run, generating reports needs no
  network access and no GBIF credentials.
- **Tested.** Extend `run_test.R`, or add `run_test_site_report.R` using the same
  harness, to cover: site resolution by all three keys, ambiguity handling, the
  zero-record site, the point-only site, slug stability and ASCII-safety, layer
  presence and CRS in the GeoPackage, and determinism of the summary tables.
  Tests make no network calls, need no credentials, and write only into
  `tempdir()`.
- **Documented.** Add a README section covering what the tool produces, the CLI,
  the GeoPackage schema (a table of layers and columns), the Typst dependency,
  and a worked example. Update the repository-structure tree.

---

## 4. Constraints

- R, matching the existing stack: `sf`, `dplyr`, `readr`, `stringr`, `ggplot2`,
  `quarto`. Do not introduce a new heavy dependency without justifying it in a
  comment; `writexl` and `optparse` are acceptable if actually used.
- Do not modify `pipeline.R`, `index.qmd`, `_quarto.yml`, or the contents of
  `data_exports/` and `docs/`. New files, and additive edits to `R/functions.R`
  only — and prefer `R/site_report.R` for anything site-specific.
- `outputs/` is generated; add it to `.gitignore`.
- House style: comments explain **why**, not what; en-GB spelling; no emoji;
  GBIF's palette and the accessibility reasoning already documented in
  `README.md`; numbered-section banners like `pipeline.R`.
- Never invent a figure. If a value cannot be derived from the data, the report
  says so rather than estimating it.

## 5. What not to do

- Do not re-download from GBIF, mint a new DOI, or touch
  `data/gbif_download/download_key.txt`.
- Do not write test fixtures over real files in `data/` or `data_exports/` —
  read the warning at the top of `run_test.R` for what that cost last time.
- Do not build a Shiny app, a second website, or an interactive HTML report.
  The deliverable is a batch tool.
- Do not silently subsample records to make a map draw faster; withhold the
  layer and say so, as the existing report does.

## 6. Acceptance criteria

The work is complete when all of these hold:

1. `Rscript site_reports.R --help` prints usage and exits 0.
2. `Rscript site_reports.R --site NP_001` produces a valid GeoPackage whose
   layers open in QGIS, and a PDF of four to six pages, in under two minutes.
3. `Rscript site_reports.R --all` completes over the full register, logs its
   failures rather than aborting, and writes `outputs/run_manifest.csv`.
4. A zero-record site and a point-only site both produce complete outputs.
5. Re-running without `--force` regenerates nothing and explains why.
6. The test script passes on a fresh clone, with no credentials and no network.
7. `README.md` documents the tool, the CLI and the GeoPackage schema.
8. The GeoPackage and the PDF agree on every number they both state.

## 7. How to work

Read the five files in section 1 before proposing anything. Then state your plan
— the function list for `R/site_report.R`, the GeoPackage schema and the report
layout — and wait for approval before implementing. Build in this order: site
resolution → clipping and summarising → GeoPackage → static maps → the Quarto
template → the batch runner → tests → documentation. Verify each stage by
running it on one real site before moving on, and report what you actually ran
and what it produced, including anything that did not work.

---

## Adapting this prompt

For another country or another site network, change only:

- the input paths and layer names in section 1,
- the register attribute names in section 2.2, if the source is not CDDA,
- the national context layers used in the locator map,
- the legal frameworks in section 2.3, item 6 — the EU Nature Directives here,
  national red lists or Emerald / Natura 2000 elsewhere.

Sections 3 to 6 are deliberately generic: they are the replicability contract,
and they transfer unchanged.
