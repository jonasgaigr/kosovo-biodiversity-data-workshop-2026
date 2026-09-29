# Prompt: "Data sources" section for the Kosovo biodiversity data workshop site

ROLE AND CONTEXT
You are working in the GitHub repository jonasgaigr/kosovo-biodiversity-data-workshop-2026, which is published with GitHub Pages at https://jonasgaigr.github.io/kosovo-biodiversity-data-workshop-2026/. The site looks like a Quarto website. Its navbar has Workshop, Report (report.html), Natura 2000 questions and GBIF, and an R script, pipeline.R, drives the analysis. Before writing anything, read _quarto.yml, pipeline.R, the existing .qmd pages and the site styles, and follow their conventions. That covers the theme, callout styles, leaflet map setup, file layout, and how the OpenStreetMap Kosovo outline is built and cached. If the site is not Quarto, adapt the plan below to what it actually is and say so in your final summary.

The site already serves two aims. It teaches participants to work with open biodiversity data, and it builds the evidence base for future Natura 2000 site identification in Kosovo. It frames data precision in three tiers: national screening, site-level screening, and Standard Data Form (SDF). The Natura 2000 questions page defines these tiers, so link to it rather than redefining them.

The report already uses the following sources, so do not rebuild them. The new pages may refer to them and say what they add on top.
- GBIF download for Kosovo (GADM XKO filter, DOI 10.15468/dl.wzpexq), cleaned with CoordinateCleaner
- OpenStreetMap national and municipal boundaries, with Eurostat GISCO used for border validation
- EEA Nationally designated areas (NatDA/CDDA) v24
- the Birds and Habitats Directive annex lists
- the IUCN Red List (global)
- the EU list of invasive alien species of Union concern, plus the cross-border watch list

TASK
Add a new site section, "Data sources". It should contain one short, independent report page per candidate dataset from a prior desk review (listed below), plus a hub page. Each page must stand on its own, so that it can be read, rendered, updated and completed without touching any other page.

THE GOVERNING PRINCIPLE
Fill in only what you can access and verify in this session, and leave everything else visibly empty so it can be completed later. An empty field is correct. A guessed field is a defect. Never write plausible-looking values, filler text or lorem ipsum, and never make up URLs, DOIs, dataset names, version numbers, dates, licences or counts.

WHAT TO BUILD

1. `sources/registry.csv`: the single source of truth, one row per dataset, with these columns:
   slug, title, category (1–8), custodian, url, doi, licence, access (open / registration / on request / paid / none), format, access_method (download / API / WMS / WFS / R package / PDF), spatial_resolution, temporal_coverage, latest_version, kosovo_coverage (yes / partial / no / unverified), kosovo_codes_seen, tier (national / site / SDF, possibly several), n2k_question, effort (low / medium / high), sensitivity, status, last_checked, notes.
   Leave a cell blank when the value is not verified.

2. `sources/registry_evidence.csv`: one row per filled registry cell, with columns slug, field, value, evidence_url, checked_on. A registry value without an evidence row counts as unverified and must be blanked.

3. `R/sources_helpers.R`: a few small helpers, and nothing more.
   - `source_row(slug)` reads that dataset's row from the registry.
   - `metadata_table(row)` renders the "At a glance" table and shows blank fields as "— to be completed".
   - `status_badge(status)` draws the status badge.
   - `try_access(url, dest, timeout = 60)` attempts the download or HEAD request and returns the outcome (success, HTTP code, size, error message, time) without ever throwing.
   - `kosovo_outline()` reuses the outline that pipeline.R already produces and caches, rather than re-deriving it.
   - `todo_list(row, extra)` generates the "To be completed" checklist from the blank fields plus any open actions.

4. `sources/<slug>.qmd`: one page per dataset, using the page template below.

5. `sources/index.qmd`: the hub page. It contains:
   - a short purpose paragraph
   - a legend explaining the status values
   - a table built from the registry, grouped by category, showing title, custodian, status badge, Kosovo coverage, tier, effort, completeness (per cent of registry fields filled) and a link to the page
   - a "Data gaps" section with one stub per gap (list below)
   - a "Data requests" section that lists every open request action gathered from the pages

6. Add "Data sources" to the navbar in _quarto.yml, and set `freeze: auto` for the sources/ directory so that heavy pages do not re-run on every build.

STATUS VALUES (use exactly these)
- Complete: all registry fields verified and the Kosovo check executed.
- Partial: some fields verified, or the check only partly executed.
- Documented only: the dataset is described in a report or paper but not published as data.
- Awaiting request: the data exist but are available on request or after registration only.
- Lead, not verified: named in the desk review but no primary source confirmed yet.
- Not applicable to Kosovo: the product exists but excludes Kosovo by design (e.g. Emerald). Keep the page, because the reason itself is evidence.

PAGE TEMPLATE (fixed section order; 300–800 words of prose per page, excluding tables and code)
0. Title, a one-sentence subtitle (blank if you cannot write it from verified facts), the status badge, and the last-checked date.
1. **At a glance**: `metadata_table(source_row("<slug>"))`.
2. **What it is**: one or two paragraphs, paraphrased from the custodian's own description. Quote at most one short phrase.
3. **Access**: what you attempted, when, and the outcome, for example "downloaded 14 MB GeoPackage", "HTTP 403", "registration required at …", or "request form at …". Include a visible R chunk showing how to access the data, where that is possible. This is teaching material.
4. **Kosovo coverage check**: the core of each page.
   - If the data are accessible, execute a real check: crop or clip to `kosovo_outline()`, then report features, cells or pixels inside Kosovo, the NA or no-data fraction, and which country codes appear. Look specifically for XK, XKX, XKO, KOS, RKS, KV, Kosovo merged into RS/SRB, or "Serbia and Montenegro". Add a small map if the data are spatial.
   - If the data are not accessible, state what the documentation says about coverage, and leave the rest under a "To be completed" callout.
   - For EU-only products such as Article 17 and 12, Kosovo is blank by design. Report instead what lies within 50 km of the border.
5. **What it adds for Natura 2000 in Kosovo**: the question it helps answer, the precision tier or tiers (linked to the Natura 2000 questions page), and how it complements the sources already in the report.
6. **Caveats and sensitivity**: known limitations, and any risk to persecuted or collected species.
7. **Integration into the pipeline**: the effort estimate, and where it would fit in pipeline.R, with a proposed function name. Do not modify pipeline.R itself.
8. **To be completed**: `todo_list()` output plus open actions (whom to request data from, what to check).
9. **Citation**: in the form the custodian requests. Leave it blank if no citation guidance was found.

PLACEHOLDER CONVENTION
- In tables, write "— to be completed".
- In prose, use a Quarto `callout-warning` titled "To be completed" that names exactly what is missing and where it might be found, for example "Licence of the 10 km modelled maps; ask EBCC".
- Every placeholder must be specific, so the page doubles as a to-do list.

BUILD AND DATA-HANDLING RULES
- Every page must render even when its data cannot be fetched.
  - Wrap all access in `try_access()` or `tryCatch`.
  - Evaluate heavy chunks only when the cache exists.
  - A failed download must never break `quarto render`.
- Cache downloads under `data/sources/<slug>/`.
  - Do not commit files larger than 50 MB. Add them to .gitignore and record the size, SHA-256 checksum and download date on the page.
  - Never commit data obtained on request, behind registration, or under a licence that forbids redistribution.
- For large European rasters, prefer remote reads cropped to the Kosovo bounding box (`terra` with `/vsicurl/`, or WMS/WCS) over full downloads.
- Do not scrape anything behind a login, and do not submit request forms. List the request as an open action instead.
- Sensitive species:
  - never display locations finer than 10 km for species that are persecuted or collected;
  - show atlas data only at its native grid;
  - say on the page what was generalised.
- If the network blocks a domain, record the blocked domain and the error on the page and move on.

VERIFICATION RULES
- Use only sources you actually opened in this session. The URLs below come from earlier desk research and are starting points only.
  - Re-verify each one.
  - If a URL is dead or has moved, say so on the page and search for the current location at the primary custodian.
- Prefer primary custodians to aggregators and secondary reports. Where only a secondary source exists, say so on the page.
- Record the latest version date of each dataset and the date you checked it.
- Flag anything that exists only as a report or paper figure as "Documented only".

DATASETS (slug — name — custodian — starting point — note from prior research)

Category 1: Species occurrence data not yet in GBIF
- `ebba2`: European Breeding Bird Atlas 2, European Bird Census Council.
  - https://www.ebcc.info/what-we-do/ebba2/ ; https://mapviewer.ebba2.info/
  - 50 km data reportedly free under a Creative Commons licence; 10 km modelled data and abundance on request.
- `emma2`: Atlas of European Mammals, 2nd ed., European Mammal Foundation / Societas Europaea Mammalogica.
  - https://european-mammals.org
  - Kosovo is reportedly included for the first time. Check whether the 50 km database has been uploaded to GBIF; if it has, avoid double counting against the existing download.
- `red-book-fauna`: Red Book of Fauna of Kosovo (Kosovo Environmental Protection Agency (KEPA/AMMK) and the Kosovo Institute for Nature Protection, cited as Ibrahimi et al. 2019).
  - PDF reportedly on ammk-rks.net (Publikime-raporte); exact URL not confirmed.
  - Locality data not published.
- `kosovo-data-papers`: recent Kosovo occurrence papers (Biodiversity Data Journal and others).
  - https://bdj.pensoft.net/ ; example https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12374165/
  - Check which records are already in GBIF.
- `endemic-plants-hacquetia`: Conservation assessment of Kosovo endemic plants (Hacquetia).
  - https://ojs.zrc-sazu.si/hacquetia/article/view/4787
- `european-taxon-atlases`: amphibian and reptile, butterfly, dragonfly, bat and orchid atlases. Lead, not verified; no URLs confirmed.
- `museum-collections`: natural history collections in Tirana, Belgrade, Skopje, Vienna and Budapest holding Kosovo material outside GBIF. Lead, not verified.
- `ebird-observation-org`: eBird / Observation.org records not in GBIF. Lead, not verified.

Category 2: National and regional reference lists
- `red-book-flora`: Red Book of Vascular Flora of the Republic of Kosovo (2013), KEPA/AMMK.
  - https://www.ammk-rks.net/assets/cms/uploads/files/Publikime-raporte/The_Red_Book_of_Vascular_Flora_of_Republic_of_Kosovo-_English_(Summary).pdf
  - If feasible, parse to a species table matched to the GBIF backbone with rgbif.
- `protected-species-ai-18-2012`: Administrative Instruction No. 18/2012 on protected and strictly protected wild species.
  - Official Gazette, gzk.rks-gov.net; exact URL not confirmed.
  - Check for later amendments.
- `kepa-protected-areas-2020`: Table of protected areas in Kosovo 2020, KEPA/AMMK.
  - https://www.ammk-rks.net/assets/cms/uploads/files/Biodiversiteti/Zonat_e_Mbrojtura_2020.pdf
  - Cross-check against NatDA v24 (237 sites, 48 with boundaries).
- `biodiversity-of-kosovo-overview`: "Biodiversiteti i Kosovës", KEPA/AMMK.
  - https://www.ammk-rks.net/assets/cms/uploads/files/Biodiversiteti%20IK/Biodiversiteti_i_Kosoves.pdf
- `euro-med-plantbase`, `fauna-europaea`, `european-red-lists`: Lead, not verified.
  - Check whether each treats Kosovo as its own area or folds it into Serbia.

Category 3: Habitats and ecosystems
- `eea-ecosystem-types`: Ecosystem types of Europe 2012 v3.1, EEA.
  - https://www.eea.europa.eu/en/datahub/datahubitem-view/573ff9d5-6889-407f-b3fc-cfe3f9e23941 ; catalogue record https://sdi.eea.europa.eu/catalogue/srv/api/records/faff2281-1fca-4548-89d8-c8ec0c507bc7
  - 100 m, EEA39, CC-BY 4.0, WMS. Compute the class areas inside Kosovo.
- `eunis-habitat-maps`: EUNIS habitat maps at level 3 (Scientific Data, 2025).
  - https://www.nature.com/articles/s41597-025-06235-7
  - Find the data repository and licence, check that Kosovo pixels are not NA, and list the EUNIS L3 types present with an indicative Annex I crosswalk. Label the crosswalk clearly as indicative.
- `kosovo-nfi-2012`: Kosovo National Forest Inventory 2012.
  - https://nfg.no/wp-content/uploads/2024/06/Kosovo-National-Forest-Inventory-2012-abstract.pdf
  - Plot data not open; expect Awaiting request.
- `fise-kosovo`: Forest Information System for Europe, Kosovo country page.
  - https://forest.eea.europa.eu/countries/cooperating-countries/kosovo
- `copernicus-land`: CORINE Land Cover, High Resolution Layers and Riparian Zones. Lead, not verified; check versions and Kosovo coverage.

Category 4: Site prioritisation and prior Natura 2000 work
- `emerald-network`: Emerald Network, Council of Europe.
  - https://www.coe.int/en/web/bern-convention/emerald-network-reference-portal ; viewer https://www.coe.int/en/web/bern-convention/emerald-viewer
  - Kosovo is not a Bern Convention Party, so expect "Not applicable to Kosovo". The SDF field guidance is still useful.
- `mustafa-2009-potential-n2k`: "Natura 2000 potential areas in Kosovo" (Mustafa et al., EU Sustainable Forest Management project, 2008/09).
  - Cited in https://landscape-online.org/index.php/lo/article/view/LO.201545
  - Expect Documented only. Search for the original report or maps. If a figure exists, note that digitising it is an open action; do not digitise it yourself.
- `nbsap-2016-2020`: Biodiversity Strategy and Action Plan 2016–2020 (Ministry of Environment and Spatial Planning (MESP)).
  - https://kryeministri.rks-gov.net/wp-content/uploads/2022/08/Eng-SAPB-2016-2020.pdf
  - Check for a successor strategy.
- `iba-kba`: Important Bird and Biodiversity Areas and Key Biodiversity Areas (BirdLife / KBA Partnership). No confirmed Kosovo polygons; boundaries reportedly on request.
- `important-plant-areas`: Plantlife IPAs. Lead, not verified. Korab-Koritnik is reported on the Albanian side.
- `eea-biogeographical-regions`: Lead, not verified. Check whether Kosovo is mapped.
- `ec-kosovo-report-2025`: European Commission Kosovo Report 2025, chapter 27.
  - https://enlargement.ec.europa.eu/kosovo-report-2025_en

Category 5: Cross-border context
- `art17-2013-2018`: Article 17 Habitats Directive reporting 2013–2018, public version, EEA.
  - https://www.eea.europa.eu/en/datahub/datahubitem-view/d8b47719-9213-485a-845b-db1bfe93598d
  - Check whether the 2019–2024 round is now published. Build a species/habitat list for the 10 km cells within 50 km and 100 km of Kosovo.
- `art12-birds`: Article 12 Birds Directive reporting, EEA. URL not confirmed.
- `serbia-eu-for-natura2000`: "EU for Natura 2000" in Serbia, which reportedly identified 277 pSCIs and 85 SPAs.
  - natura2000.gov.rs; exact page not confirmed.
  - Check whether draft site boundaries are published.
- `montenegro-n2k`: Montenegro Natura 2000 research, species reports.
  - https://www.academia.edu/39138586/Research_on_Natura_2000_network_Montenegro_Species_Reports
- `albania-natural`: Albania NaturAL project, e.g. the small-mammals data paper.
  - https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5904422/
- `neighbour-emerald-sufficiency`: Emerald sufficiency for Serbia, North Macedonia, Montenegro and Albania.
  - Secondary source: https://bankwatch.org/press_release/bern-convention-western-balkan-countries-need-to-propose-new-protected-natural-areas
  - Find the primary Bern Convention document.

Category 6: Environmental covariates (all Lead, not verified)
- `copernicus-dem`, `chelsa`, `worldclim`, `eu-hydro`, `hydrosheds`, `soils-geology`
- For each, verify the version and licence, crop to Kosovo, and show a small map.
- Where the R package `geodata` provides the layer, demonstrate it.

Category 7: Pressures and threats
- `balkan-hydropower`: Hydropower Projects on Balkan Rivers, 2024 update, RiverWatch & EuroNatur.
  - https://riverwatch.eu/en/balkanrivers/news/10-years-hydropower-data-2024-update-reveals-ongoing-threats-and-wins-balkan ; 2022 PDF https://balkanrivers.net/uploads/files/3/Balkan_HPP_Update_2022.pdf
  - Kosovo coded "KV" in older versions.
  - If point data are downloadable, overlay them with NatDA; otherwise expect Awaiting request.
- `icmm-mining`: Independent Commission for Mines and Minerals (ICMM), licences and GIS.
  - https://kosovo-mining.org/?lang=en
  - Check download terms.
- `kca-geoportal`: Kosovo Cadastral Agency State Geoportal.
  - https://geoportal.rks-gov.net/en/per-gjeoportalin/-/asset_publisher/EO0MH4mgPwJp/content
  - Reportedly registration is needed to download. Test any public WMS/WFS endpoints.
- `np-spatial-plans`: national park spatial plans.
  - Bjeshkët e Nemuna: https://mmphi.rks-gov.net/mmphifolder/OtherDocuments/Plani%20Hap%C3%ABsinor%20PK%20Bjeshk%C3%ABt%20e%20Nemuna.pdf
  - Sharri SEA draft: https://www.ammk-rks.net/assets/cms/uploads/files/Draft%20Raporti%20-%20Vler%C3%ABsimi%20Strategjik%20Mjedisor%20p%C3%ABr%20Parkun%20Komb%C3%ABtar%20Sharri_.pdf
- `river-basin-programme`: Ministry of Environment, Spatial Planning and Infrastructure (MMPHI) river basin work programme 2025–2027.
  - https://mmphi.rks-gov.net/MMPHIFolder/OtherDocuments/1.%20Programi%20i%20Punes%20per%20PMPL.pdf
- `forest-loss-hansen`, `effis-burnt-areas`: Lead, not verified.

Category 8: Teaching resources
- `r-access-toolkit`: one page covering terra, sf, geodata, rredlist, eurostat, giscoR, ows4R, and anything else used on the pages above.
  - rgbif and CoordinateCleaner are already in use.
  - Verify each package on CRAN and give its current version, what it reaches, and how it handles Kosovo (e.g. which code GISCO uses).

DATA GAPS (stubs on the hub page; each one short, stating what is missing, why it matters for the SDF, and who could fill it)
1. No Annex I habitat map or inventory for Kosovo.
2. No official or draft Natura 2000 or Emerald site list with boundaries.
3. No confirmed IBA/KBA polygons for Kosovo.
4. No published national species monitoring data. The Red Books do not release localities.
5. No population-size data for SDF section 3.2.
6. No wetland, peatland, cave or grassland inventories.
7. No Kosovo range assessments in the Article 17 style, and no delineation of biogeographical regions within Kosovo.
8. Scattered evidence only for Annex II invertebrates and freshwater fish.

VOICE
Write in British English ("per cent", "programme"). Match the voice of the existing report: plain, explanatory, specific and candid about limitations. Explain why a check matters, not just its result. Keep paragraphs short. Paraphrase the sources, with at most one short quotation per source.

WORKFLOW
1. Inspect the repository and confirm the site structure. Create a branch named `data-sources`.
2. Write the helpers, the registry skeleton (all slugs, fields blank) and the page template. Render one page end to end before scaling up.
3. Work through the datasets in this order: category 5 (Art. 17/12), then 3, 1, 2, 4, 7, 6, 8. Fill in the registry and evidence rows as you verify each value.
4. Build the hub page and add the navbar entry. Run `quarto render` and fix all errors and warnings.
5. Commit to the branch. Do not merge or push to main.

DONE WHEN
- `quarto render` completes without errors, and every slug above has a page and a registry row.
- Every filled registry cell has an evidence row, and every blank cell shows up as a specific "To be completed" item.
- Your final message to me contains:
  - a table of slug | status | fields filled / total | main blocker;
  - the list of data requests to send, with the contact route for each;
  - the URLs that failed or had moved;
  - anything in the site structure that forced you to deviate from this prompt.
