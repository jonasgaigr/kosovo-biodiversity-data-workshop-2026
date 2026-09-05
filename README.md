# Biodiversity of Kosovo — GBIF data analysis

A reproducible R workflow that acquires, quality-controls, analyses and
publishes Global Biodiversity Information Facility (GBIF) occurrence data for
the territory of Kosovo, with particular attention to species protected under
the EU Birds and Habitats Directives.

The output is a Quarto website — summary statistics, interactive Leaflet maps
and open data downloads — designed for ministry officials and conservation
practitioners, and hosted on GitHub Pages.

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
│   ├── kosovo_boundary.gpkg        # Cached reference polygon
│   ├── vernacular_cache.csv        # Cached common names
│   └── run_metadata.rds            # DOI, citation, counts, cleaning report
│
├── data_exports/              # Published outputs (.gpkg + .csv), five subsets
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
  "rgbif", "tidyverse", "sf", "leaflet", "leaflet.extras",
  "CoordinateCleaner", "DT", "htmltools", "rnaturalearth"
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
6. Write five thematic subsets to `data_exports/` as `.gpkg` and `.csv`.
7. Save run metadata to `data/run_metadata.rds`.

The first run takes roughly 20 minutes, most of it resolving common names for
several thousand taxa. Subsequent runs are far quicker because both the
download and the name cache are reused.

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
warning. `kosovo_boundary()` in `R/functions.R` therefore builds a bespoke
reference polygon, which is passed via `country_ref`. With the fix in place the
test flags a plausible 2.7 per cent of records.

**3. Subspecies listings must not be matched at species level.**
The Birds Directive lists island endemics such as *Columba palumbus azorica*,
*Fringilla coelebs ombriosa* and *Parus ater cypriotes*. Matching a subspecies
listing on its accepted *species* key — which is the right thing to do for
species-level listings — places every Wood Pigeon, Chaffinch and Coal Tit in
Kosovo on Annex I. That added roughly 1,450 records and 11 species to the Annex
I subset for subspecies confined to the Azores and the Canaries.
`directive_lookup()` in `pipeline.R` therefore matches on the species key only
where the listing itself is at species rank.

**4. GBIF returns no match for cross-kingdom homonyms.**
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
