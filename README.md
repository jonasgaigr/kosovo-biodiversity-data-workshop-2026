# Biodiversity of Kosovo — GBIF data analysis

A reproducible R workflow that acquires, quality-controls, analyses and
publishes Global Biodiversity Information Facility (GBIF) occurrence data for
the territory of Kosovo, with particular attention to species protected under
the EU Birds and Habitats Directives.

The output is a Quarto website — summary statistics, interactive Leaflet maps,
a browser-side record explorer and open data downloads — designed for ministry
officials and conservation practitioners, and hosted on GitHub Pages.

---

## What the report contains

| Section | What it answers |
|---|---|
| Summary statistics | How much data is there, and of what |
| Data quality control | What was screened out, and how precisely records are placed |
| Where the records are | Six maps, each with points, a classed density grid, a heat surface and municipal boundaries |
| Survey coverage by municipality | Which parts of the country are under-recorded |
| EU Nature Directives | Which species of Community interest have been recorded |
| Extinction risk | The IUCN Red List profile, and the threatened species in detail |
| Explore the records | A filterable, linked map and table over the records of conservation interest |
| Species checklist | Every species, with counts and links to GBIF |
| Who published these records | Attribution for all contributing datasets and publishers |
| Download the data | GeoPackage, CSV and Excel for every subset |

### Adopted from the GBIF Viewer

Several features are adapted from the
[GBIF Viewer](https://github.com/ABiatov/gbif_shiny_onlineviewer) built for
Ukraine by the Habitat Foundation and the Ukrainian Nature Conservation Group.
That tool is a Shiny application with a server behind it; this is a static
site, so each idea is re-implemented to run in the reader's browser:

| GBIF Viewer | Here |
|---|---|
| Conservation-status filter panel | `crosstalk` filters driving a linked map and table, no server needed |
| IUCN Red List as the primary filter | Red List category resolved per species and carried through every export, map, table and filter |
| Administrative-unit selector | Every municipality summarised in advance — a coverage choropleth and a per-unit table |
| Draw an area of interest | Leaflet.draw polygon and rectangle tools with live area readout, plus measure, place search and mouse coordinates |
| Links to the record and dataset on gbif.org | In every pop-up and in the attribution table |
| Dataset and publisher listing | Resolved from the GBIF registry and published as a credited table |
| Coordinate-uncertainty threshold | Reported as a precision profile and offered as a filter, rather than silently discarding half the data — see the report for why |
| CSV / XLSX export | Both, plus GeoPackage, for every subset |
| Colour by kingdom | Kept, with a validated colour-blind-safe palette and a legend |

---

## Repository structure

```
kosovo-biodiversity-data-workshop-2026/
├── .Renviron                  # GBIF credentials — LOCAL ONLY, never committed
├── .Renviron.example          # Template to copy
├── .gitignore
├── _quarto.yml                # Website configuration
├── custom.scss                # Report theme
├── index.qmd                  # The report
├── pipeline.R                 # Acquisition → cleaning → matching → export
├── README.md
├── LICENSE
│
├── R/
│   ├── functions.R            # Shared helpers, sourced by pipeline.R AND index.qmd
│   └── build_directive_list.R # Builds the annex lists from the EUR-Lex texts
│
├── data/                      # Inputs, caches and run metadata
│   ├── eu_directives_species.csv   # Annex lists (generated; tracked)
│   ├── eurlex/                     # Cached consolidated legal texts
│   ├── gbif_download/              # Raw GBIF archives (not tracked)
│   │   └── download_key.txt        # Tracked, so the DOI is reused
│   ├── gadm41_XKO.gpkg             # GADM 4.1, all levels (downloaded)
│   ├── kosovo_boundary.gpkg        # National outline, GADM level 0
│   ├── kosovo_municipalities.gpkg  # GADM level 2, for coverage reporting
│   ├── vernacular_cache.csv        # Cached common names
│   ├── iucn_cache.csv              # Cached IUCN Red List categories
│   ├── dataset_registry.csv        # Cached dataset and publisher titles
│   └── run_metadata.rds            # DOI, citation, counts, cleaning report
│
├── data_exports/              # Published outputs (.gpkg, .csv, .xlsx), six subsets
└── docs/                      # Rendered website — GitHub Pages serves this
```

`R/functions.R` is deliberately shared between the pipeline and the report so
that the mapping and summary logic exists in exactly one place.

---

## 1. Set your GBIF credentials securely

The pipeline uses the GBIF **asynchronous download service**, which requires an
account. Credentials are read from environment variables and must never be
written into the R scripts or committed to git.

### Register

Create a free account at <https://www.gbif.org/user/profile>.

### Create `.Renviron`

`.Renviron` is a plain key–value file — **not** an R script, so there are no
quotes, no `<-`, and no `Sys.setenv()` calls. Place it in the project root:

```
GBIF_USER=your_gbif_username
GBIF_PWD=your_gbif_password
GBIF_EMAIL=your.address@example.org
```

The quickest way to create and open it:

```r
# install.packages("usethis")
usethis::edit_r_environ(scope = "project")
```

Or copy the supplied template:

```bash
cp .Renviron.example .Renviron
```

Then edit in the real values.

### Points to observe

- **End the file with a newline.** R silently ignores the final line if it does
  not end in a line break — a classic cause of "missing credentials" errors.
- **Restart R after editing.** `.Renviron` is read only at session start.
  In RStudio: *Session → Restart R*.
- **Never commit it.** `.Renviron` is already in `.gitignore`. Verify with
  `git status --ignored` before your first push.
- **Use a project-scoped file**, not `~/.Renviron`, if you work with several
  GBIF accounts. The project file takes precedence.
- Your GBIF **password is stored in clear text** in this file. That is what
  `rgbif` requires. Ensure the file is readable only by you, and if the machine
  is shared consider a credential manager such as the `keyring` package
  instead.

### Verify

```r
Sys.getenv("GBIF_USER")   # should print your username, not ""
```

If it prints an empty string, R has not picked the file up: check the filename
is exactly `.Renviron` (Windows Explorer may have appended `.txt`), that it
sits in the project root, and that you have restarted R.

---

## 2. Install the R packages

```r
install.packages(c(
  "rgbif", "tidyverse", "sf", "leaflet", "leaflet.extras", "leafem",
  "CoordinateCleaner", "DT", "crosstalk", "htmltools", "htmlwidgets",
  "writexl", "curl", "jsonlite", "rnaturalearth"
))
```

Quarto itself is a separate command-line tool: <https://quarto.org/docs/download/>.

---

## 3. Build the annex lists

```bash
Rscript R/build_directive_list.R
```

This is only needed once — the resulting CSV is tracked in the repository. See
[The annex lists](#the-annex-lists) below.

## 4. Run the pipeline

```bash
Rscript pipeline.R
```

This will:

1. Submit an asynchronous GBIF download for Kosovo and wait for it to build.
2. Record the resulting **DOI** for citation.
3. Match the EU annex list against the GBIF backbone taxonomy.
4. Screen coordinates with `CoordinateCleaner`.
5. Resolve English common names from the GBIF species API (cached).
6. Resolve IUCN Red List categories from the GBIF species API (cached).
7. Stamp each record with the municipality it falls in (GADM level 2).
8. Write six thematic subsets to `data_exports/` as `.gpkg`, `.csv` and —
   for the smaller ones — `.xlsx`.
9. Resolve every contributing dataset and publisher from the GBIF registry.
10. Save run metadata to `data/run_metadata.rds`.

The first run takes roughly 20 minutes, most of it resolving common names for
several thousand taxa one at a time. The Red List and registry lookups are
issued concurrently and take seconds. Subsequent runs are far quicker because
the download and all three caches are reused.

**The pipeline is idempotent.** The GBIF download key is stored in
`data/gbif_download/download_key.txt` and re-used, so re-running does not mint
a new DOI. Delete that file to force a fresh extract.

---

## 5. Render the website

```bash
quarto render
```

The site is written to `docs/`, with the exported data files copied alongside
it so that the download buttons resolve.

To preview locally while editing:

```bash
quarto preview
```

---

## 6. Publish to GitHub Pages

Commit `docs/` and push, then in the repository settings:

**Settings → Pages → Source: Deploy from a branch → Branch: `main`, folder: `/docs`**

The site appears at `https://<username>.github.io/<repository>/` within a
minute or two. A `.nojekyll` file is included in `docs/` so that GitHub serves
Quarto's `site_libs/` directory correctly.

Update `site-url` and the GitHub links in `_quarto.yml` to match your own
repository.

---

## The annex lists

`data/eu_directives_species.csv` drives the directive subsets. It is
**generated**, not hand-maintained:

```bash
Rscript R/build_directive_list.R
```

That script parses the consolidated legal texts on EUR-Lex — the binding
versions — and resolves every name against the GBIF backbone taxonomy:

| Annex | Taxa | What it covers |
|---|---|---|
| Birds I | 193 | Species requiring Special Protection Areas |
| Birds II | 83 | Species that may be hunted |
| Habitats II | 887 | Species requiring Special Areas of Conservation |
| Habitats IV | 370 | Species in need of strict protection |
| Habitats V | 76 | Species whose taking from the wild may be managed |

Habitats Annex I is excluded because it lists habitat types rather than
species; Habitats Annex III and Birds Annex III cover criteria and trade rules.

The CSV keeps the three columns the pipeline requires — `scientific_name`,
`directive`, `annex` — so a hand-written list still works if you prefer one. It
adds `gbif_usage_key`, `gbif_species_key`, `matched_rank`, `priority` (the
asterisk marking priority species) and `listing_type`. When those columns are
present the pipeline uses the stored keys rather than re-matching, which
preserves the disambiguation the build script did.

### Why not a ready-made checklist

Per-annex checklists exist on GBIF, and they are tempting: DOIs, backbone keys,
no parsing. They are also geographically filtered. The Birds Annex I checklist
there holds 128 of the 193 listed taxa, and the omissions are exactly the ones
that matter for Kosovo — *Alectoris graeca* is absent, as are Balkan endemics.
Using it would have quietly under-reported the most conservation-relevant taxa
in the country.

### Known limitations

* Geographic qualifiers ("except the Estonian, Finnish and Swedish
  populations") are not captured, so each listing is treated as applying in
  full. For screening Kosovo data this errs in the safe direction.
* Habitats Annex IV(b) incorporates the Annex II(b) plants by reference; those
  plants appear under Annex II rather than being repeated under Annex IV.
* About 1.3 per cent of entries do not resolve to a current GBIF taxon. These
  are names superseded since 1992 — mostly Iberian and Macaronesian plants.
  The build script lists every one of them.

---

## Corrections worth knowing about

All were verified against live data while building this pipeline, and each
fails *silently* rather than raising an error.

**1. The GADM code for Kosovo is `XKO`, not `XKX`.**
`XKX` is the World Bank / ISO alpha-3 style code. `pred("gadm", "XKX")`
returns zero records — no error, just an empty dataset. Measured against the
GBIF occurrence API: `gadmGid=XKO` → 52,290 records, `gadmGid=XKX` → 0,
`country=XK` → 48,947.

**2. `CoordinateCleaner`'s country test cannot see Kosovo by default.**
Natural Earth, its reference dataset, records Kosovo with `iso_a3 == "-99"`,
meaning no assigned code. Running the `"countries"` test against the default
reference flags **100 per cent** of Kosovo records as country-coordinate
mismatches, and with `value = "clean"` returns an empty data frame with no
warning. `kosovo_boundary()` in `R/functions.R` therefore supplies a bespoke
reference polygon, passed via `country_ref`.

**3. Screen against the same polygon that selected the records.**
The bespoke reference was at first built from Natural Earth's 1:50m outline —
72 vertices for the whole country, departing from the true border by as much as
4.7 km. The GBIF download, however, is selected with `pred("gadm", "XKO")`, so
every record is inside the *GADM* polygon by construction. Screening those
records against a different, coarser outline flagged 1,296 of them (2.7 per
cent, 192 species) as country-coordinate mismatches. Every one was a real
record near the border, discarded because two datasets drew the same line
differently.

The reference is now GADM level 0 itself — 1,210 vertices, and the same
geometry GBIF filtered on — and the test flags nothing, which is the correct
answer rather than a broken one. The test is kept in the battery because it
becomes meaningful again the moment the download predicate changes: a
`country = "XK"` extract, for instance, relies on publisher-supplied country
codes and genuinely needs checking.

**4. Subspecies listings must not be matched at species level.**
The Birds Directive lists island endemics such as *Columba palumbus azorica*,
*Fringilla coelebs ombriosa* and *Parus ater cypriotes*. Matching a subspecies
listing on its accepted *species* key — which is the right thing to do for
species-level listings — places every Wood Pigeon, Chaffinch and Coal Tit in
Kosovo on Annex I. That added roughly 1,450 records and 11 species to the Annex
I subset for subspecies confined to the Azores and the Canaries.
`directive_lookup()` in `pipeline.R` therefore matches on the species key only
where the listing itself is at species rank.

**5. CARTO's free basemap tiles now arrive watermarked.**
`providers$CartoDB.Positron` — the usual light basemap for data cartography —
still returns HTTP 200 and a valid PNG, but CARTO now stamps
"API KEY REQUIRED" diagonally across every tile served to an unauthenticated
client. Nothing in the console reports it; the map simply looks wrong. The
light basemap is now `Esri.WorldGrayCanvas`, which needs no key. Its tiles stop
at zoom 16, so `maxNativeZoom` is set and Leaflet upscales beyond that rather
than showing blanks.

**6. Leaflet's heat layer discards intensity unless it is told the zoom.**
`L.heatLayer` multiplies every intensity by `1 / 2^(maxZoom − currentZoom)`,
where `maxZoom` defaults to the *map's* maximum — 19 as soon as a street or
satellite layer is present. At the country view that divides every value by
about a thousand, so the entire surface falls onto the minimum-opacity floor
and renders as one flat wash. `addHeatmap()` does not expose the option, so
`pin_heatmap_zoom()` sets it on the layer prototype.

Two further defaults compound it. The plugin draws each cell at
`intensity / max` clamped to 1, so raw record counts — which here run from 1 to
over 13,000 — all saturate identically; counts are therefore mapped onto 0–1
with a log transform and a fractional power. And the default gradient is a
rainbow, which has no inherent order; it is now a single hue running light to
dark.

**7. `tibble()` evaluates its columns in sequence, with earlier ones in scope.**
```r
dplyr::tibble(
  gpkg      = if (file.exists(gpkg)) basename(gpkg)  else NA_character_,
  gpkg_size = if (file.exists(gpkg)) file.size(gpkg) else NA_real_   # wrong
)
```
By the second line `gpkg` is no longer the path — it is the bare filename the
first line just produced. `file.exists()` is then false, `file.size()` returns
`NA`, and every download button on the site loses its size with no warning
anywhere. Resolve names and sizes *before* building the tibble.

**8. Quarto's `freeze` does not watch the files your document sources.**
With `freeze: auto`, editing `R/functions.R` — where every map, pop-up and
palette in this report actually lives — and re-rendering silently republishes
the previous output, because Quarto only fingerprints the `.qmd` itself. This
project therefore sets `freeze: false`.

**9. GBIF returns no match for cross-kingdom homonyms.**
`name_backbone_checklist("Coronella austriaca")` returns `matchType: "NONE"`
with the note "Multiple equal matches", because the name exists as both a snake
and a plant homonym; *Liparis loeselii* fails the same way. Supplying the
kingdom the taxon was listed under resolves both. The build script reads the
ANIMALS/PLANTS headings from the annex text to obtain that hint, and retries
without it for the cases where the directive's botanical grouping disagrees
with GBIF (lichens, listed under plants but placed in Fungi).

---

## Citing the data

Every run records a DOI, shown in the published report and stored in
`data/run_metadata.rds`. Cite it in any resulting publication — it credits the
institutions that collected and published the underlying records, and lets any
reader retrieve the identical dataset.

GBIF-mediated data are released under licences chosen by each publishing
institution. The `license` column in every export records the terms applying to
each record.

---

## Licence

Analysis code: see [LICENSE](LICENSE). Occurrence data remain under the terms
set by their original publishers.
