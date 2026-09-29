# Biodiversity of Kosovo — GBIF data analysis

A reproducible R workflow that acquires, quality-controls, analyses and
publishes Global Biodiversity Information Facility (GBIF) occurrence data for
the territory of Kosovo, with particular attention to species protected under
the EU Birds and Habitats Directives and to the invasive alien species the EU
regulates as of Union concern.

The output is a Quarto website — summary statistics, interactive Leaflet maps,
a browser-side record explorer and open data downloads — designed for ministry
officials and conservation practitioners, and hosted on GitHub Pages.

The site opens on [`index.qmd`](index.qmd), the landing page for the TAIEX
Expert Mission on GIS and biodiversity data management, Pristina,
28–30 September 2026. It says briefly what the mission was for and links every
deck given there, as slides and as a PDF handout, alongside the report itself,
which is [`report.qmd`](report.qmd). The decks are listed once, in
[`data/workshop_decks.csv`](data/workshop_decks.csv): the page is built from
that file, and [`publish_slides.R`](publish_slides.R) copies the built decks
into `docs/slides/` from it after every render.

[`presentation/`](presentation) holds the two decks that present it at the TAIEX
Expert Mission on GIS and biodiversity data management, Pristina,
28–30 September 2026: *Accessing and utilising GBIF data for biodiversity
conservation* (Day 2) and *Replicable and automated map and report production
for biodiversity conservation* (Day 3), which is about the site-level tool
below.

[`natura2000.qmd`](natura2000.qmd) is a second page of the site. It answers the
Ministry's questions on moving towards Natura 2000, as far as they fall within
these sessions: evidence tiers, grid to boundary, habitat mapping, sufficiency,
the database, bird data and SPAs, and a two-site pilot. Its figures are computed
from the same pipeline outputs. The Important Bird Areas it lists come from
BirdLife's DataZone through [`R/fetch_iba.R`](R/fetch_iba.R), as attributes
only; the boundaries are released on request.

[`sources/`](sources/) is the site's *Data sources* section: one short page
per candidate dataset for Natura 2000 site identification, beyond those the
report already uses, plus a hub page. Each page shows only values verified
against the custodian, keeps them in
[`sources/registry.csv`](sources/registry.csv) with one evidence row per value
in [`sources/registry_evidence.csv`](sources/registry_evidence.csv), and runs a
Kosovo coverage check where the data could be reached. The helpers are in
[`R/sources_helpers.R`](R/sources_helpers.R); downloads are cached under
`data/sources/<slug>/`. The folder renders with `freeze: auto`, so after
editing the registry run `quarto render sources/`.

---

## What the report contains

| Section | What it answers |
|---|---|
| Summary statistics | How much data is there, and of what |
| Data quality control | What was screened out, and how precisely records are placed |
| Where the records are | Seven maps, each with points, a classed density grid, a heat surface, protected areas and municipal boundaries |
| Survey coverage by municipality | Which parts of the country are under-recorded |
| Protected areas | What the national register holds, how much of the country it covers, and which sites have occurrence evidence behind them |
| Potential Natura 2000 habitats | Where CORINE Land Cover suggests Annex I habitats may occur, and how much of that lies outside every designated site — a screen for gap analysis, not a habitat map |
| EU Nature Directives | Which species of Community interest have been recorded |
| Extinction risk | The IUCN Red List profile, and the threatened species in detail |
| Invasive alien species | Which species on the EU's Union list have been recorded, and a watch list of those recorded across the border but not yet here |
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
| Colour by kingdom | Kept, in GBIF's own brand colours, with a legend and a palette measured for colour-blind separation rather than eyeballed |

---

## Following GBIF's cartography

The report is styled to sit inside the GBIF family rather than beside it. Every
colour is GBIF's own, taken from one of two places — no values were eyeballed:

| Where it is used | Source |
|---|---|
| Site theme, kingdom colours, map furniture | GBIF's published brand steps, `gbif/portal16`, `app/views/shared/style/_variables.styl` |
| Record-density classes and the heat surface | Sampled from the tiles GBIF's own occurrence map serves (`api.gbif.org/v2/map/…&style=classic.poly`) |
| Basemaps | `tile.gbif.org`, styles `gbif-light`, `gbif-natural`, `gbif-classic` |

The GBIF brand steps are green `#509E2F`, black `#231F20`, azure `#175CA1`,
aqua `#40BFFF`, purple `#636FB4`, plum `#7E466A`, terracotta `#D66F27`, orange
peel `#FDB002` and mist `#E8E8E8` — and mist is exactly the land colour of the
`gbif-light` basemap, which is a good sign the two sources agree.

Three things had to be measured rather than assumed.

**The obvious reading of the brand is unreadable for one reader in twelve.**
Green for plants and terracotta for fungi is the natural mapping, and it fails:
GBIF green and GBIF terracotta collapse to a **dE of 4.0** under deuteranopia
(OKLab ×100, Machado-Oliveira-Fernandes 2009 at severity 1.0), tested over
*all* pairs rather than adjacent ones, because on a map any two marks can end
up touching. Orange peel — GBIF's other warm step — clears the same test at
12.0, and the trio plus the neutral holds 11.5. Fungi are therefore gold, not
terracotta.

**GBIF's density ramp is built for a dark ground.** The five steps of
`classic.poly` run `#FFFF00 → #FFCB00 → #FF9800 → #FF6600 → #D50A00`, and their
lightness falls at every step, which is what makes the ramp read as an ordered
scale. But the palest class carries **11.8:1** against GBIF's dark basemap and
**1.1:1** against the pale one. The report keeps a light default, because it is
a document meant to print, and gives every density cell a dark hairline so the
sparse classes stay defined; `gbif-classic` is one click away in the layer
control for anyone who wants the ramp at full strength.

**GBIF green cannot carry small text.** It is 3.35:1 on white — fine for the
rules, borders and key figures, short of the 4.5:1 that body-sized text needs.
The theme therefore splits it: `$primary` is the brand green, and
`$primary-ink` (`#358305`) is the same hue stepped down in OKLCH lightness
until it clears the threshold at 4.77:1. Links and small headings wear the ink;
everything else wears the brand.

`run_test.R` covers the parts of this that can regress silently — that the base
layers are alternatives rather than a stack, that none needs an API key, and
that the GBIF tiles keep `tileSize = 512` with `zoomOffset = -1`.

IUCN Red List categories keep IUCN's own severity scheme. They are a different
organisation's standard, and GBIF renders them in IUCN's colours too.

The per-site PDFs are dressed from the same palette, down to the swatch beside
a Red List category — see *The report wears the website's colours*.

---

## Repository structure

```
kosovo-biodiversity-data-workshop-2026/
├── .Renviron                  # GBIF credentials — LOCAL ONLY, never committed
├── .Renviron.example          # Template to copy
├── .gitignore
├── _quarto.yml                # Website configuration
├── custom.scss                # Report theme
├── index.qmd                  # Landing page: the mission and every deck
├── report.qmd                 # The report
├── publish_slides.R           # Copies the built decks into docs/slides/
├── pipeline.R                 # Acquisition → cleaning → matching → export
├── site_reports.R             # One GeoPackage and one PDF per protected area
├── run_test.R                 # Offline smoke test for R/functions.R
├── run_test_site_report.R     # Offline smoke test for R/site_report.R
├── README.md
├── LICENSE
│
├── R/
│   ├── functions.R            # Shared helpers, sourced by pipeline.R AND report.qmd
│   ├── site_report.R          # Site-level helpers, sourced by site_reports.R AND
│   │                          #   reports/site_report.qmd
│   ├── build_directive_list.R # Builds the annex lists from the EUR-Lex texts
│   ├── build_ias_list.R       # Builds the Union list of invasive alien species
│   └── sources_helpers.R      # Registry, badges and access checks for sources/
│
├── sources/                   # "Data sources" section: one page per dataset
│   ├── index.qmd              # Hub: registry by category, data gaps, requests
│   ├── registry.csv           # One row per dataset; blank = not verified
│   ├── registry_evidence.csv  # One row per verified value, with its evidence URL
│   └── _metadata.yml          # freeze: auto for this folder only
│
├── reports/
│   ├── site_report.qmd        # Parameterised Typst report for one site
│   ├── gbif-report.typ        # The report's colours — the website's, in Typst
│   └── _quarto.yml            # Keeps it out of the website project
│
├── data/                      # Inputs, caches and run metadata
│   ├── workshop_decks.csv          # The decks the landing page lists and publishes
│   ├── eu_directives_species.csv   # Annex lists (generated; tracked)
│   ├── eu_ias_union_list.csv       # Union list of invasive species (generated; tracked)
│   ├── eurlex/                     # Cached legal texts, both lists
│   ├── gbif_download/              # Raw GBIF archives (not tracked)
│   │   └── download_key.txt        # Tracked, so the DOI is reused
│   ├── gadm41_XKO.gpkg             # GADM 4.1, all levels (GBIF's selection polygon)
│   ├── osm_kosovo.gpkg             # OpenStreetMap: country, 7 districts, 38 municipalities
│   ├── kosovo_boundary.gpkg        # National outline, from osm_kosovo.gpkg
│   ├── kosovo_municipalities.gpkg  # 38 municipalities, for coverage reporting
│   ├── kosovo_protected_areas.gpkg # EEA designated areas, Kosovo only (cached)
│   ├── crosswalk_clc_annex1.csv    # CLC class -> candidate Annex I habitats (for review)
│   ├── clc_polygon_overrides.csv   # CLC polygons reclassified by name: the reservoirs
│   ├── clc_legend.csv              # Official CLC labels and colours
│   ├── kosovo_clc2018.gpkg         # CORINE Land Cover 2018, Kosovo only (cached)
│   ├── kosovo_biogeo_regions.gpkg  # Biogeographical regions, Kosovo only (cached)
│   ├── kosovo_potential_habitats_map.gpkg # Simplified layers for the habitat map
│   ├── vernacular_cache.csv        # Cached common names
│   ├── iucn_cache.csv              # Cached IUCN Red List categories
│   ├── dataset_registry.csv        # Cached dataset and publisher titles
│   ├── ias_neighbour_counts.csv    # Cached Union-list counts next door, dated
│   └── run_metadata.rds            # DOI, citation, counts, cleaning report
│
├── data_exports/              # Published outputs (.gpkg, .csv, .xlsx): seven subsets,
│                              #   the protected areas and the land-cover screen
├── docs/                      # Rendered website — GitHub Pages serves this
│   └── slides/<deck>/         # Each deck's slides and handout, copied by publish_slides.R
├── outputs/                   # Site reports (generated; not tracked)
│   ├── protected_areas/<slug>/<slug>.gpkg  and  <slug>.pdf
│   ├── run_manifest.csv               # One row per site per run
│   └── national_site_statistics.csv   # The ranking each report quotes
│
└── presentation/              # TAIEX workshop decks — their own Quarto project
    ├── gbif-data-access.qmd      # Day 2: accessing and utilising GBIF data
    ├── automated-reporting.qmd   # Day 3: automated map and report production
    ├── automated-reporting.scss  # Code-block styles for that deck alone
    ├── custom.scss            # Adjustments to the AOPK template, shared
    ├── images/                # Captures of the website and of a site report
    ├── _extensions/aopk/      # AOPK ČR reveal.js template (vendored)
    └── README.md              # How to build the HTML and the PDF
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
  "writexl", "curl", "jsonlite", "rnaturalearth", "rmapshaper", "geojsonsf"
))
```

Quarto itself is a separate command-line tool: <https://quarto.org/docs/download/>.

### Check the install

```bash
Rscript run_test.R
```

A smoke test over the helpers in `R/functions.R` — the code that turns cleaned
records into the maps, tables and pop-ups. It needs no GBIF credentials, makes
no network calls and writes nothing into the project, so it is safe to run on a
fresh clone before the pipeline has ever been executed.

---

## 3. Build the species lists

```bash
Rscript R/build_directive_list.R
Rscript R/build_ias_list.R
```

This is only needed once — the resulting CSVs are tracked in the repository.
See [The annex lists](#the-annex-lists) and
[The Union list of invasive alien species](#the-union-list-of-invasive-alien-species)
below.

## 4. Run the pipeline

```bash
Rscript pipeline.R
```

This will:

1. Submit an asynchronous GBIF download for Kosovo and wait for it to build.
2. Record the resulting **DOI** for citation.
3. Match the EU annex list against the GBIF backbone taxonomy, and read the
   Union list of invasive alien species.
4. Count each Union-list species in the four neighbouring countries (cached).
5. Screen coordinates with `CoordinateCleaner`.
6. Resolve English common names from the GBIF species API (cached).
7. Resolve IUCN Red List categories from the GBIF species API (cached).
8. Stamp each record with the municipality it falls in (OpenStreetMap).
9. Stamp each record with the protected area it falls in (EEA NatDA, cached).
10. Stamp each record with its Union-list status.
11. Write seven thematic subsets to `data_exports/` as `.gpkg`, `.csv` and —
    for the smaller ones — `.xlsx`.
12. Write the protected-area register to `data_exports/` in the same three
    formats.
13. Screen CORINE Land Cover for potential Annex I habitats and measure the
    gap against the designated sites (cached; see
    [The land-cover screen](#the-land-cover-screen)).
14. Resolve every contributing dataset and publisher from the GBIF registry.
15. Save run metadata to `data/run_metadata.rds`.

The first run takes roughly 20 minutes, most of it resolving common names for
several thousand taxa one at a time. The Red List and registry lookups are
issued concurrently and take seconds; the neighbouring-country counts are
issued one at a time, because occurrence search is rate-limited, and take about
a minute. Subsequent runs are far quicker because the download and all four
caches are reused.

**The pipeline is idempotent.** The GBIF download key is stored in
`data/gbif_download/download_key.txt` and re-used, so re-running does not mint
a new DOI. Delete that file to force a fresh extract.

---

## 5. Render the website

```bash
quarto render
```

The site is written to `docs/`, with the exported data files copied alongside
it so that the download buttons resolve. Once the pages are written,
`publish_slides.R` copies each workshop deck's slides and handout into
`docs/slides/<deck>/`. The decks are not built here — each is its own Quarto
project — so render a changed deck in its own folder first. The copy stops the
render if a listed deck has not been built, or if its slides still show a
placeholder for a missing figure. After rebuilding a deck alone,
`Rscript publish_slides.R` republishes it without re-rendering the site.

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

## The Union list of invasive alien species

`data/eu_ias_union_list.csv` drives the seventh subset and the report's
invasive-species section. It is generated the same way as the annex lists:

```bash
Rscript R/build_ias_list.R
```

The Union list is the Annex to Commission Implementing Regulation (EU)
2016/1141, adopted under Regulation (EU) No 1143/2014 and amended four times
since. The script reads the consolidated text and the five acts, and resolves
every name against the GBIF backbone:

| Act | Species | Applies from |
|---|---|---|
| 2016/1141 | 37 | 3 August 2016 |
| 2017/1263 | 12 | 2 August 2017; *Nyctereutes procyonoides* from 2 February 2019 |
| 2019/1262 | 17 | 15 August 2019 |
| 2022/1203 | 22 | 2 August 2022; three from 2 August 2024; *Celastrus orbiculatus* from 2 August 2027 |
| 2025/1422 | 26 | 7 August 2025; *Castor canadensis* and *Neogale vison* from 7 August 2027 |

That is **114 species, 111 of which apply today**. The three deferred ones are
not in the consolidated text at all — a consolidated version carries only what
already applies — so they are read from Article 2 and the Annex of the act
that listed them. The date each listing applies from is computed from the act
(publication plus twenty days, or the date the act gives for a deferred
point) and written to `applies_from`.

### Why the legal text, when a complete checklist exists

The Research Institute for Nature and Forest (INBO) publishes the Union list as
a checklist dataset on GBIF, [doi:10.15468/97aucj](https://doi.org/10.15468/97aucj),
and unlike the per-annex directive checklists it is complete. The build uses it
for the English names and as an independent cross-check, which passes species
for species. It is not the source, because two of its taxa have no backbone
link: *Neogale vison* (see correction 11 below) and "*Triadica sebífera*",
where one accent is enough for GBIF's name parser to give up and record the
canonical name as `Triadica spec.`. Its date for *Lampropeltis getula*
(12 July 2022) is the day the 2022 act was adopted rather than the day it
applied; the build reports the difference and keeps the act's own date.

### How records are matched

Every listing is matched on its own key and on the key of its species —
including the three listed below species rank, *Vespa velutina nigrithorax*,
*Procambarus fallax* f. *virginalis* and *Pueraria montana* var. *lobata*.
That is the opposite of the directive rule (correction 5), deliberately: each
of the three is the form of its species that is established in Europe, and
records are mostly identified to species only. Two columns are added to every
export:

| Column | Meaning |
|---|---|
| `iasUnionConcern` | Whether the record's species is on the Union list |
| `iasAppliesFrom` | The date its listing applies from in the EU; blank if not listed |

### The watch list

The Regulation is built around early detection, so the report also lists the
Union-list species recorded in Albania, North Macedonia, Montenegro or Serbia
and not in Kosovo. The counts come from the occurrence search API, one faceted
request per species, with the download's quality filters and the neighbours'
GADM boundaries — which draw Serbia without Kosovo. They are **not covered by
the download's DOI**; they are cached in `data/ias_neighbour_counts.csv` with
the date they were taken, and the report prints that date. Delete the file to
refresh them.

### Known limitations

* *Lampropeltis getula* is listed *sensu lato*, and a note to the table names
  the kingsnakes it covers (*L. californiae*, *L. nigra* and others). Only the
  listed name is matched.
* The Regulation binds EU Member States. The report uses the list as a
  screening reference for Kosovo, as it does the Nature Directives.

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

**3. Screen against an accurate polygon, not against the selecting one.**
The bespoke reference was at first built from Natural Earth's 1:50m outline —
72 vertices for the whole country, departing from the true border by as much as
4.7 km — and flagged 1,296 records on the strength of its own error. Replacing
it with GADM level 0, the polygon `pred("gadm", "XKO")` selects on, made the
test flag nothing at all. That looked like a clean result and was really the
test grading its own paper: every record is inside that polygon by
construction, so asking whether it is can only return yes.

GADM's outline is not accurate enough to be either. At 1,210 vertices it sits
a median 587 m from Eurostat's independent GISCO digitisation of the same
international border, and 2,980 m at the ninetieth percentile.
OpenStreetMap's — 19,268 vertices — sits 60 m and 189 m, and the residual
there is GISCO's generalisation rather than OSM's. The areas agree: published
figures for Kosovo cluster between 10,887 km² (World Bank) and 10,910 km²,
OpenStreetMap measures 10,898 km², and GADM measures 10,828 km².

The reference is now that OpenStreetMap outline, and the test does what it is
for: it flags **1,776 records**, 3.7 per cent of those with coordinates. They
are not borderline calls. Ninety-four per cent carry a publisher-assigned
country code of `ME`, `MK`, `RS` or `AL`, and they sit a median 552 m and up
to 3.3 km beyond the border — records that GADM's outward bulges swept into
the download. `country_buffer` in `pipeline.R` keeps records within a set
distance of the border if that is wanted; it is `NULL`, meaning a strict test.

The opposite error cannot be repaired downstream. 412 km² of Kosovo falls
*outside* GADM's outline, so records there were never in the download.
Selecting on a `geometry` predicate would close the gap, at the cost of a new
download and a new DOI.

**4. GADM's Kosovo municipalities are the pre-2010 set.**
Kosovo's decentralisation created new municipalities in 2010 and split
Mitrovica in two; the country has had 38 ever since. GADM 4.1 still draws 30.
The units it is missing are not empty ground, and the difference is not
academic: the single coordinate that carries more records than any other in
the country — over thirteen thousand of them — sits on ground that moved from
Fushë Kosovë to the new municipality of Graçanicë in 2010. Reported through
GADM, all of them landed in Fushë Kosovë, and every coverage figure, map and
table said so. The municipal layer is now read from the same OpenStreetMap
source as the national outline, which carries all 38.

**5. Subspecies listings must not be matched at species level.**
The Birds Directive lists island endemics such as *Columba palumbus azorica*,
*Fringilla coelebs ombriosa* and *Parus ater cypriotes*. Matching a subspecies
listing on its accepted *species* key — which is the right thing to do for
species-level listings — places every Wood Pigeon, Chaffinch and Coal Tit in
Kosovo on Annex I. That added roughly 1,450 records and 11 species to the Annex
I subset for subspecies confined to the Azores and the Canaries.
`directive_lookup()` in `pipeline.R` therefore matches on the species key only
where the listing itself is at species rank.

**6. Basemap tiles: CARTO watermarks, and GBIF serves 512-pixel tiles.**
`providers$CartoDB.Positron` — the usual light basemap for data cartography —
still returns HTTP 200 and a valid PNG, but CARTO now stamps
"API KEY REQUIRED" diagonally across every tile served to an unauthenticated
client. Nothing in the console reports it; the map simply looks wrong. It was
replaced by `Esri.WorldGrayCanvas`, and the basemaps are now GBIF's own, from
`tile.gbif.org` — the same ground the occurrence map on gbif.org draws on, and
no key required. See [Following GBIF's cartography](#following-gbifs-cartography).

GBIF serves **512-pixel** tiles on the OpenMapTiles scheme (the `omt` in the
path), so they are added with `tileSize = 512` and `zoomOffset = -1`. The x/y
indexing is standard, so leaving Leaflet's 256-pixel default still places every
tile correctly — it just draws each label and road at half its designed size,
which reads as a rendering fault rather than as a configuration one.

`gbif-light` is deliberately sparse: coastlines, borders and rivers, and no
roads or labels at *any* zoom. That is what makes it a good ground for data,
but it means zooming in adds no context, so `gbif-natural` is offered alongside
it for readers who need to place a record against a road or a town.

**7. Leaflet's heat layer discards intensity unless it is told the zoom.**
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

**8. `tibble()` evaluates its columns in sequence, with earlier ones in scope.**
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

**9. Quarto's `freeze` does not watch the files your document sources.**
With `freeze: auto`, editing `R/functions.R` — where every map, pop-up and
palette in this report actually lives — and re-rendering silently republishes
the previous output, because Quarto only fingerprints the `.qmd` itself. This
project therefore sets `freeze: false`.

**10. GBIF returns no match for cross-kingdom homonyms.**
`name_backbone_checklist("Coronella austriaca")` returns `matchType: "NONE"`
with the note "Multiple equal matches", because the name exists as both a snake
and a plant homonym; *Liparis loeselii* fails the same way. Supplying the
kingdom the taxon was listed under resolves both. The build script reads the
ANIMALS/PLANTS headings from the annex text to obtain that hint, and retries
without it for the cases where the directive's botanical grouping disagrees
with GBIF (lichens, listed under plants but placed in Fungi).

**11. GBIF answers an unknown species with its genus, and no error.**
The 2025 amendment to the Union list names the American mink *Neogale vison*,
the genus it was moved to in 2021. The backbone does not carry that
combination. `name_backbone("Neogale vison")` returns `matchType: HIGHERRANK`,
the genus *Neogale* — itself a synonym of *Mustela* — at 94 per cent
confidence. Keep that key and every native weasel, stoat and polecat becomes
an invasive species. Both build scripts treat `HIGHERRANK` as a failure;
`R/build_ias_list.R` then resolves the mink through its former name,
*Neovison vison*, to *Mustela vison*.

**12. EUR-Lex answers scripts with an empty page.**
EUR-Lex now puts a bot challenge in front of its documents. A script is
answered with HTTP **202** and a body of zero bytes — not an error status, so
`download.file()` writes an empty file and reports success. The same documents
are served without a challenge by Cellar, the Publications Office repository
behind EUR-Lex, by content negotiation:
`https://publications.europa.eu/resource/celex/<CELEX>` with
`Accept: application/xhtml+xml` and `Accept-Language: eng`.
`R/build_ias_list.R` fetches from there, and checks each document for text it
must contain before caching it.

---

## The protected-area layer

The report overlays the occurrence records on Kosovo's nationally designated
protected areas, taken from the European Environment Agency's inventory of
**Nationally designated areas** (NatDA, formerly the Common Database on
Designated Areas, CDDA), version 24 of July 2026. It is the channel through
which 38 Eionet countries report their protected areas to the World Database on
Protected Areas, so Kosovo's entry is its own official register.

```r
protected_areas  <- kosovo_protected_areas(layer = "polygons")   # 67 features
protected_points <- kosovo_protected_areas(layer = "points")     # 189 features
```

| | |
|---|---|
| Source | [EEA datahub, dataset `028003e7`](https://www.eea.europa.eu/en/datahub/datahubitem-view/f60cec02-6494-4d08-b12d-17a37012cb28) |
| DOI | [10.2909/028003e7-7585-4d69-92fc-7f81e0cc2340](https://doi.org/10.2909/028003e7-7585-4d69-92fc-7f81e0cc2340) |
| Licence | CC-BY 4.0, © European Environment Agency |
| Kosovo coverage | 237 designated sites and 19 strict-protection zones; 1,261 km², 11.6 % of the country |

### Nothing is downloaded

The EEA publishes the vector data as a 1.7 GB GeoPackage covering 38 countries,
and a 510 MB File Geodatabase of the same features. The pipeline takes neither.
A GeoPackage is a SQLite database with an R-tree spatial index, the EEA's server
honours HTTP range requests, and GDAL's `/vsicurl/` combines the two into a
query that fetches only the pages covering the bounding box it is given.
Kosovo's 256 features arrive in about a minute and a few megabytes.

The result is cached in `data/kosovo_protected_areas.gpkg` (700 kB, tracked),
so a fresh clone reads it from the repository and makes no request at all.
Delete that file to rebuild.

The File Geodatabase is deliberately not used despite being a third of the
size: GDAL 3.12's `OpenFileGDB` driver returns empty geometries for its
multipoint table, which would silently drop the 189 point-only sites — three
quarters of Kosovo's register.

### Two shapes, and why it matters

Of the 237 designated sites, 48 carry a mapped boundary and 189 are recorded as
a single point. That is a property of the sites, not a defect: every national
park, strict nature reserve, protected landscape, nature park and wetland is a
polygon, while the point-only sites are all natural monuments — individual
veteran trees, springs and caves, most under a tenth of a hectare.

Only the polygons can carry a point-in-polygon test, so the two are kept as
separate layers of one GeoPackage rather than one mixed-geometry table. Three
columns are added to every occurrence export:

| Column | Meaning |
|---|---|
| `protectedArea` | Name of the designated site the record falls in, or blank |
| `protectedAreaDesignation` | That site's designation, in English |
| `strictlyProtected` | Whether the record also falls inside a strict-protection zone |

Where a record falls inside more than one site — seven of Kosovo's sites
overlap along their edges — the smallest is taken, being the most specific
statement anyone has made about that ground. The strict-protection zones are
excluded from the site test, because each lies inside a site already counted.

> **`iucn_management_category` is not the Red List.** It is the IUCN
> protected-area *management* category (Ia, Ib, II, III, V), which describes how
> a site is run. The Red List categories used elsewhere in this project are CR,
> EN, VU and so on. The two share an acronym and nothing else.

---

## The land-cover screen

The report's section *Potential Natura 2000 habitats* reads CORINE Land Cover
(CLC) through an editable crosswalk and asks where natural and semi-natural
land cover suggests Annex I habitats may occur, and how much of it lies outside
every designated site. It is national-screening evidence, not a habitat map:
CLC's 25 ha minimum mapping unit loses springs, fens and riparian strips, and
a land-cover class stands for several habitat types or none.

| | |
|---|---|
| Land cover | CORINE Land Cover 2018 (vector), version V2020_20u1 — the latest CLC vintage published when this was written |
| DOI | [10.2909/71c95a07-e296-44fc-b22b-415f42acfdf0](https://doi.org/10.2909/71c95a07-e296-44fc-b22b-415f42acfdf0) |
| Licence | Copernicus data policy (Delegated Regulation (EU) No 1159/2013): free, full and open; state the source and any modification |
| Regions | Biogeographical regions, Europe 2016, ver. 1 — CC-BY 4.0, © EEA; no DOI registered |
| Kosovo | Continental 8,844 km², Alpine 2,063 km² |

### Parameters (in `pipeline.R`)

| Parameter | Default | What it does |
|---|---|---|
| `clc_vintage` | `"2018"` | CLC reference year. Refused unless its DOI, version and licence are recorded in `clc_sources` in `R/functions.R`. |
| `clc_path` | `""` | A CLC vector file downloaded by hand. Empty reads the EEA map service instead. Also settable as `CLC_PATH` in `.Renviron`. |
| `clc_simplify_tolerance` | `50` | Metres. Generalises the map layers only; every area is measured on the full geometry. |
| `potential_habitat_min_confidence` | `"low"` | Lowest crosswalk confidence kept: `low`, `medium` or `high`. `low` keeps every candidate class and shows confidence on the map instead. |

### Getting the data

**By default nothing needs doing.** The pipeline reads the Kosovo window of
CLC2018 from the EEA's own map service — the REST endpoint the Copernicus
product page names for the dataset — in native EPSG:3035, clips it to the
OpenStreetMap outline and caches the result as `data/kosovo_clc2018.gpkg`
(tracked, so a fresh clone makes no request). It is cached rather than re-read
because the EEA is due to publish a revised CLC2018 alongside CLC2024, and a
published figure should not move with it. Delete the file to read it again.

**To use a file from the Copernicus portal instead**, which needs an EU Login:

1. Download the *vector* product of the vintage from
   <https://land.copernicus.eu/en/products/corine-land-cover/clc2018>
   (GeoPackage or File Geodatabase; not the raster).
2. Unzip it outside the repository. Raw CLC files are git-ignored in case one
   lands inside it anyway.
3. Set `CLC_PATH=...` in `.Renviron` (see `.Renviron.example`) or `clc_path`
   in `pipeline.R`, delete `data/kosovo_clc2018.gpkg`, and run the pipeline.
   Only the part of the file covering Kosovo is read. If the path is set and
   nothing is there, the run stops and says what to download.

### The crosswalk and the overrides

The judgements are data, not code:

- `data/crosswalk_clc_annex1.csv` — one row per CLC class: `natural_status`,
  `habitat_group`, `candidate_annex1` (semicolon-separated Annex I codes, `*`
  for priority types), `confidence` and `note`. Every code is checked against
  Annex I as parsed from the legal text in `data/eurlex/`, so a typo stops the
  run. The optional `biogeo_region` column (`Alpine` or `Continental`) makes a
  row apply in one region only, taking precedence over the general row for the
  same class.
- `data/clc_polygon_overrides.csv` — individual CLC polygons reclassified by
  identifier, with the evidence. At present the eight reservoirs that CLC files
  as water bodies (Gazivoda/Ujmani, Radoniq, Batllava, Badovc and four smaller
  ones), each identified by its OpenStreetMap feature or dam.

Areas are measured in EPSG:3035 on the unsimplified geometry, "inside" means
inside the union of the 48 designated sites with a mapped boundary, and the
totals by group, by municipality and inside-plus-gap are checked against each
other on every run; a mismatch over 0.01 % stops the pipeline.

### The map, and what it costs

The habitat section adds about 5.7 MB to `report.html` (43.7 to 49.4 MB).
The all-classes CLC layer is drawn from the EEA's WMS rather than as vectors
(4.6 MB saved), the habitat polygons are simplified at 50 m with mapshaper so
that neighbours still meet exactly, and each polygon carries only its own
values: the class text and the Annex I names are held once per class and put
together in the browser.

---

## Site reports for individual protected areas

The website answers national questions. A conservation officer asked about one
site needs the same evidence for that site alone, in a form they can open in
QGIS and attach to a case file. `site_reports.R` produces it:

```bash
Rscript site_reports.R --site NP_001
```

writes `outputs/protected_areas/parku-kombetar-sharri/` containing

* `parku-kombetar-sharri.gpkg` — every record inside the site and its buffer,
  the boundary, the strict-protection zones, two 1 km grids, the overlapping
  municipalities, a species list and the provenance, as nine GeoPackage layers;
* `parku-kombetar-sharri.pdf` — a four- to six-page report on the same figures.

The PDF reads its numbers **out of the GeoPackage**, so the two cannot state
different figures. No GBIF credentials and no network access are needed: the
tool reads what `pipeline.R` has already published, and never triggers a new
download.

### The command line

| Option | Meaning |
|---|---|
| `--site VALUE` | A `natda_id`, a `national_id`, or part of a site name, case- and diacritic-insensitive. Repeatable. An ambiguous name is an error listing the candidates |
| `--all` | Every designated site in the register |
| `--designation NAME` | Keep only this designation, e.g. `"National Park"` |
| `--iucn-category CODE` | Keep only this IUCN management category, e.g. `II` |
| `--min-area-km2 N` | Keep only sites of at least N km², as reported by the register |
| `--out DIR` | Output directory (default `outputs/protected_areas`) |
| `--buffer M` | Comparison buffer in metres (default 1000) |
| `--gpkg-only` / `--pdf-only` | Write only one of the two outputs |
| `--force` | Regenerate even when the outputs are newer than every input |
| `--quiet` | Print nothing but errors and the run summary |
| `--help` | Usage |

```bash
Rscript site_reports.R --site "Bjeshket e Nemuna"          # diacritics optional
Rscript site_reports.R --site 555547192 --site NP_001      # repeatable
Rscript site_reports.R --all --designation "National Park" --out outputs/np
Rscript site_reports.R --site NP_002 --gpkg-only --force
```

Re-running regenerates nothing and says so, unless an input — including the
code — is newer than the outputs, or `--force` is given. One site failing is
logged and the run continues; the exit status is non-zero if any site failed.
Every run appends to `outputs/run_manifest.csv` and rewrites
`outputs/national_site_statistics.csv`, the table each report quotes its
national rank from.

### The GeoPackage

All layers are stored in **EPSG:4326**; every area, distance and density is
computed in **EPSG:3035** (ETRS89-LAEA), the projection the EEA uses for area
statistics. Both are recorded in `report_metadata`, so neither has to be
inferred from the numbers.

| Layer | Geometry | Columns beyond the register's own |
|---|---|---|
| `site_boundary` | polygon | `boundary_basis`, `computed_area_km2`, `buffer_m`, `records`, `species`, `families`, `datasets`, `records_per_km2`, `first_year`, `last_year`, `records_in_buffer_only`, `strict_zones`, `strict_records`, `grid_cells`, `grid_cells_with_records`, `unrecorded_share` |
| `site_buffer` | polygon | `natda_id`, `site_name`, `buffer_m`, `buffer_area_km2`, `records`, `records_outside` |
| `strict_protection` | polygon | register attributes, `computed_area_km2`, `records`, `species` |
| `occurrences` | point | the full export attribute set, plus `inside_site`, `in_buffer_only`, `strictlyProtected`, `directive`, `annex` |
| `species_richness_grid` | polygon | `cell_id`, `species`, `records`, `cell_area_km2` |
| `record_density_grid` | polygon | `cell_id`, `records`, `density_class`, `cell_area_km2` |
| `municipalities_overlapping` | polygon | `unit_area_km2`, `overlap_km2`, `share_of_unit`, `share_of_site` |
| `species_summary` | none | `species`, `vernacularName`, `kingdom`, `family`, `records`, `iucnRedListCategory`, `directive`, `annex`, `first_year`, `last_year` |
| `report_metadata` | none | `natda_id`, `item`, `value` — the GBIF DOI and citation, the register version, every input path and its modification time, the CRSs, the buffer, the tool version and commit, and the command that reproduces the file |

Both grids drop their empty cells, because an empty cell is not a
record; the count of empty cells survives in `site_boundary` as
`grid_cells` against `grid_cells_with_records`, which is what the report's
recording-gap figure is computed from.

Two counting rules are worth knowing before the numbers are compared with the
national report:

* **Records are counted by intersection with the boundary**, not from the
  `protectedArea` stamp. The stamp names only the smallest site containing a
  record, so a record in the overlap of two sites would otherwise vanish from
  one of the two reports. A site's total here can therefore be slightly higher
  than its row in the national table.
* **The register's own `area_km2` is dropped** in favour of
  `computed_area_km2`, measured in EPSG:3035. Two area columns differing in the
  third decimal place are worse than one.

### The PDF needs Typst, not LaTeX

The report is rendered through Quarto's `format: typst`. Typst ships **inside
Quarto** from version 1.4, so there is nothing to install: no TeX distribution,
no `tinytex`, no LaTeX packages. Check with `quarto typst --version`.

The maps are drawn with `ggplot2` and use no tile service, so a report renders
with the network unplugged and looks the same in a year's time. Above 20,000
records the point layer is withheld and the density grid is drawn in its place,
with the reason printed on the map — records are never silently thinned.

> **One line worth adding to `_quarto.yml`.** The website project's render list
> is `["*.qmd", "!presentation/"]`, and that glob reaches `reports/` as well, so
> a plain `quarto render` of the website renders the template too and leaves a
> stray `docs/reports/site_report.pdf` behind. Rendered without a site the
> template describes itself and stops rather than failing, so nothing breaks
> either way — but adding `- "!reports/"` beside `- "!presentation/"` keeps the
> website out of this directory altogether. `reports/_quarto.yml` makes the
> directory its own project, which is what keeps a targeted render of the
> template from inheriting the website's format and output directory; it does
> not exclude it from the parent's render list.

### The report wears the website's colours

A site report and the national report are one publication, so the PDF is drawn
in the colours of the page, each doing the job it does there: GBIF black for
reading text, the brand green for the rule under a section heading, the ink
step `#358305` for text that has to be green — the key figures, the links, the
file names — azure down the edge of the citation block, and the Red List's own
colours in a swatch beside every category, which is the swatch `report.qmd`
puts in its own species tables. The maps have always shared `map_palette` with
the website's interactive ones; the printed locator map now draws land in GBIF
mist as well, the land colour of the `gbif-light` basemap those maps sit on.

Those values live in `reports/gbif-report.typ`, which the template includes as
its Typst header. They are restated there rather than shared because nothing
can share them — Typst cannot read SCSS, and Quarto's own answer to this, a
`_brand.yml`, would restyle the website as well as the report. The duplication
is guarded instead: `run_test_site_report.R` reads `custom.scss`,
`R/site_report.R` and the theme together, and fails if a value drifts out of
step, if a map goes back to a hard-coded colour, or if the report starts using
a colour the page does not.

### Sites with no records, and sites with no boundary

Both are ordinary, and both produce complete outputs:

* a site with **no records** is not an error. Its layers are written empty, and
  every section says plainly that it is empty. Most of Kosovo's register is in
  this state, and the report says in as many words that absence of records is
  not absence of species;
* a site recorded as a **point** has no inside, so it is buffered to a circle of
  the area the register reports for it. The substitution is stated in the PDF
  and recorded in `report_metadata` as `boundary_basis`.

### Testing it

```bash
Rscript run_test_site_report.R
```

covers site resolution by all three keys, ambiguity, slug stability and
ASCII-safety, the zero-record and point-only sites, the layers and CRS of the
GeoPackage, the determinism of the summary tables, and that the PDF's colours
still agree with the website's. Like `run_test.R` it
needs no credentials and no network, and **writes only into `tempdir()`**.

---

## Citing the data

Every run records a DOI, shown in the published report and stored in
`data/run_metadata.rds`. Cite it in any resulting publication — it credits the
institutions that collected and published the underlying records, and lets any
reader retrieve the identical dataset.

GBIF-mediated data are released under licences chosen by each publishing
institution. The `license` column in every export records the terms applying to
each record.

The protected-area boundaries are © European Environment Agency and are
redistributed under CC-BY 4.0. Cite them as
<https://doi.org/10.2909/028003e7-7585-4d69-92fc-7f81e0cc2340>.

The land-cover screen is derived from CORINE Land Cover. Any reuse must carry
"Generated using European Union's Copernicus Land Monitoring Service
information; <https://doi.org/10.2909/71c95a07-e296-44fc-b22b-415f42acfdf0>",
say that the layer was clipped and reclassified, and not suggest that the EU
endorses it.

---

## Licence

Analysis code: see [LICENSE](LICENSE). Occurrence data remain under the terms
set by their original publishers.
