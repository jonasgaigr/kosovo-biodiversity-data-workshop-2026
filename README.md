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
| Where the records are | Six maps, each with points, a classed density grid, a heat surface, protected areas and municipal boundaries |
| Survey coverage by municipality | Which parts of the country are under-recorded |
| Protected areas | What the national register holds, how much of the country it covers, and which sites have occurrence evidence behind them |
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
├── run_test.R                 # Offline smoke test for R/functions.R
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
│   ├── gadm41_XKO.gpkg             # GADM 4.1, all levels (GBIF's selection polygon)
│   ├── osm_kosovo.gpkg             # OpenStreetMap: country, 7 districts, 38 municipalities
│   ├── kosovo_boundary.gpkg        # National outline, from osm_kosovo.gpkg
│   ├── kosovo_municipalities.gpkg  # 38 municipalities, for coverage reporting
│   ├── kosovo_protected_areas.gpkg # EEA designated areas, Kosovo only (cached)
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

### Check the install

```bash
Rscript run_test.R
```

A smoke test over the helpers in `R/functions.R` — the code that turns cleaned
records into the maps, tables and pop-ups. It needs no GBIF credentials, makes
no network calls and writes nothing into the project, so it is safe to run on a
fresh clone before the pipeline has ever been executed.

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
7. Stamp each record with the municipality it falls in (OpenStreetMap).
8. Stamp each record with the protected area it falls in (EEA NatDA, cached).
9. Write six thematic subsets to `data_exports/` as `.gpkg`, `.csv` and —
   for the smaller ones — `.xlsx`.
10. Write the protected-area register to `data_exports/` in the same three
    formats.
11. Resolve every contributing dataset and publisher from the GBIF registry.
12. Save run metadata to `data/run_metadata.rds`.

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

---

## Licence

Analysis code: see [LICENSE](LICENSE). Occurrence data remain under the terms
set by their original publishers.
