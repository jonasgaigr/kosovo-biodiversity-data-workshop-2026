# Datasets to Add to the Kosovo Biodiversity Data Workshop Report: Natura 2000 Evidence Sources (September 2026)

The additions that would help the report most are the EU Member State Article 17 and Article 12 range and distribution grids, the EEA "Ecosystem types of Europe" layer and the newer 100 m EUNIS habitat-probability maps, the Kosovo Red Books and the protected-species instrument (Administrative Instruction No. 18/2012), EBBA2 and EMMA2 atlas grids, and the Balkan hydropower database. Kosovo has no official Natura 2000 or Emerald site list, and no Annex I habitat map exists as open data, so the gap analysis will have to be built from these proxies.\[1\]

## TL;DR

- **Where to start:** use the EEA Article 17 (2013–2018, 10 km grid) and Article 12 datasets from neighbouring Member States to draw up the "expected" Annex species and habitats list. Add EBBA2 (50 km data are free under a CC licence) and EMMA2 (Kosovo is included for the first time) to fill the gaps in GBIF. Add the Ecosystem types v3.1 layer and the EUNIS level-3 habitat maps as habitat proxies. All are open, and all except the atlases are EEA39 products that include Kosovo.
- **What Kosovo lacks:** it is not a Bern Convention Contracting Party, so it has no Emerald sites. The only Natura 2000 site identification is a 2008/09 EU-funded "Sustainable Forest Management" report by Mustafa et al., which names about 8 potential zones. It exists only as a report, not as spatial data. The 2016 national biodiversity strategy says the Natura 2000 process is "only at the very beginning". No confirmed BirdLife IBA or KBA polygon could be verified for Kosovo.
- **Pressures and national data:** the best pressure layers are the RiverWatch/EuroNatur Balkan hydropower inventory and the Independent Commission for Mines and Minerals (ICMM) GIS. The hydropower 2024 update (Schwarz 2025) counts 3,188 plants planned, 94 under construction and 1,836 operational region-wide, with 49% inside existing or planned protected areas, and its GIS data feed the balkanrivers.net interactive map. National cadastral data from the Kosovo Cadastral Agency geoportal require registration. The 2012 national forest inventory is only available as reports.

## Key Findings

### Ranked shortlist: the 10 most valuable additions

1. **EEA Article 17 Habitats Directive distribution dataset, 2013–2018 (public version, Aug 2020).**\[2\] It gives 10 km presence grids for every Annex I habitat and Annex II/IV/V species in Greece, Bulgaria and Croatia, the Member States nearest Kosovo. That makes it the most defensible basis for a list of habitats and species expected in Kosovo.
2. **EEA Article 12 Birds Directive dataset.**\[3\] It does the same job for birds, and it is the bird-side reference for SPA-trigger species screening.
3. **EEA Ecosystem types of Europe v3.1 (100 m, EEA39, CC-BY, WMS).**\[4\]\[5\] It is the only official, open, pan-European EUNIS level-2 ecosystem map that includes Kosovo, and it serves as a first habitat-stratification layer.
4. **EUNIS habitat maps at level 3 (Scientific Data, 2025; 260 habitat types, 100 m, EEA39).**\[6\] It is the finest open habitat-probability product available. Level-3 EUNIS types can be crosswalked to Annex I far better than MAES level-2 classes.
5. **Red Book of Fauna (KEPA/AMMK and the Kosovo Institute for Nature Protection, 2019) and Red Book of Vascular Flora of Kosovo (2013).** These give national threat categories. The Standard Data Form's "other important species" section and national prioritisation both need them, and the global IUCN list cannot supply them.
6. **Administrative Instruction No. 18/2012 on protected and strictly protected wild species.**\[7\] It is the legal list of species protected under Kosovo law. That list sets national screening obligations and is the counterpart of the Annex lists already in the report.
7. **EBBA2 (European Breeding Bird Atlas 2).** Its 50 km occurrence data are free under a Creative Commons licence, and its 10 km modelled maps cover bird distribution.\[8\]\[9\] That gives systematic 2013–2017 breeding evidence for Kosovo that is independent of GBIF.\[10\]
8. **EMMA2 (Atlas of European Mammals, 2nd edition).** Kosovo is included as a new country in its 50 km mammal grid.\[11\] The grid is the only harmonised source for large carnivores, bats and small mammals, and these are core Annex II/IV groups.
9. **RiverWatch/EuroNatur "Hydropower Projects on Balkan Rivers", 2024 update.**\[12\] This inventory covers existing, planned and under-construction hydropower plants. Rivers are where Natura 2000 sites and development pressure collide most sharply in Kosovo.
10. **Mustafa et al. 2009, "Natura 2000 potential areas in Kosovo", with the MESP Biodiversity Strategy 2016–2020.**\[13\] This is the only prior site-identification work.\[1\]\[14\] The workshop should digitise and test it rather than rebuild it from scratch.

## Details

### Kosovo coverage checks: method and general warnings

- **EEA39 products** (Ecosystem types, CORINE-family Copernicus layers, NatDA) include Kosovo as one of the six West Balkan cooperating countries. The EEA's Forest Information System for Europe lists Kosovo under "cooperating countries", which confirms this.\[15\] Kosovo is therefore expected to be present as its own unit, not merged with Serbia. Clip it with the OSM outline, as the report already does.\[16\]
- **Article 17 and 12 data** cover EU Member States only.\[2\] Kosovo is blank by design, so these data serve as a reference for what to expect, not as Kosovo evidence.
- **Council of Europe (Emerald) products** do not include Kosovo. The MESP strategy states: "Kosovo is not a Party to the Bern Convention, meaning that the Emerald Network has not been developed in the country."\[1\]
- **Atlas products (EBBA2, EMMA2)** use 50 km UTM squares,\[17\] and many straddle the borders with Serbia, Montenegro, Albania and North Macedonia. Kosovo evidence must be read at square level, not by country attribute.
- **Code hygiene:** carry the report's XKO/XK/XKX warning into every new join.\[16\] Emerald field SDF 2.5 uses NUTS 2 codes, and the Council of Europe notes that where no official NUTS codes exist, "an agreed similar coding system is used".\[18\] Expect ad-hoc codes in any Kosovo-related Emerald or NUTS table.

### Category 1: Species occurrence data not yet in GBIF

| Dataset | Custodian / URL | Licence & access | Format / method | Resolution & time (latest version) | Kosovo coverage check | Supports (section, tier) | Effort & caveats | Sensitivity |
|---|---|---|---|---|---|---|---|---|
| EBBA2 European Breeding Bird Atlas 2 | European Bird Census Council; ebba2.info; map viewer mapviewer.ebba2.info | 50 km occurrence data free under Creative Commons. Abundance, breeding-evidence and 10 km modelled data "© EBCC", on request, possibly with handling fees | Download / request via website; images |\[8\] 50×50 km (UTM, 5,217 squares Europe-wide) plus 10×10 km modelled maps; fieldwork mostly 2013–2017; EBBA Live under way |\[10\]\[17\] Kosovo squares are visible in the viewer. Pre-EBBA2 Western Balkan coverage was described as "very low", so check Kosovo square completeness flags |\[19\] Birds Annex I evidence, SPA pre-screening; national screening | Low for 50 km (join to OSM outline); medium for requested data. Squares cross borders | Low at 50 km; request-only layers may hide sensitive raptors |
| EMMA2 Atlas of European Mammals, 2nd ed. | European Mammal Foundation; european-mammals.org; book (Routledge) | Book is paid. Maps are to be freely viewable on the Societas Europaea Mammalogica site. Uploading the 50 km database to GBIF is only a stated plan, not verified as done: The Habitat Foundation's report of an EMMA2 meeting in Prague says "The final atlas database, at the 50 x 50km resolution used in the atlas will also be uploaded to [GBIF]" | Book; web maps; future GBIF dataset | 50×50 km; 142,965 records of 245 species in final database |\[20\] Milvus Group (Romania) names Kosovo, with Montenegro, among the "new countries compared to the first atlas" in the 43-country project launched in 2016. A national Kosovo support page exists | Annex II/IV mammals (bats, carnivores, rodents); national screening | Low once on GBIF; otherwise medium (manual digitising). Check whether the upload has happened before the workshop | Moderate (bat roosts, large carnivores) but mitigated by 50 km grain |
| Kosovo Red Book of Fauna (with underlying records) | KEPA/AMMK; PDF at ammk-rks.net (Publikime-raporte, "v2Red_Book") | Public PDF; underlying locality data not published | PDF (maps inside) | National; first fauna Red Book, published 2019 (Ibrahimi et al. 2019, Ministry of Environment and Spatial Planning / Kosovo Institute for Nature Protection, as cited in later faunistic papers) | Kosovo-only | Species evidence and national categories; national screening | High to extract points; request raw data from the Kosovo Institute for Nature Protection (KINP) | High for raptors, large carnivores and reptiles collected for trade |
| Recent Kosovo data papers (e.g. new floristic records: *Najas*, *Lycopodium*, *Cyperus*; *Anchusella cretica* first record) | Biodiversity Data Journal (Pensoft); PMC (PMC12374165) |\[21\]\[22\] CC-BY; occurrences often as Darwin Core | Article supplements; BDJ/IPT export |\[23\] Point records, 2020s | Kosovo-specific by title | Checklist enrichment; site screening | Low to medium; check whether BDJ occurrences were also pushed to GBIF to avoid double counting | Low (plants), but check orchids |
| Conservation assessment of Kosovo endemic plants | Hacquetia (ZRC SAZU), ojs.zrc-sazu.si/hacquetia/article/view/4787 |\[24\] Open-access article | Tables in paper | National | Kosovo-specific | Balkan endemics, "other important species"; national screening | Medium (manual extraction) | Moderate (narrow serpentine endemics) |
| iNaturalist Kosovo place | inaturalist.org/places/kosovo |\[25\] Research-grade data flow to GBIF (already in report); non-research-grade does not | API | Points, recent | Place defined for Kosovo | Teaching (data quality) | Low; mostly duplicative of GBIF | Obscured coordinates for threatened taxa |

**Not found / not confirmed:** I did not find confirmed Kosovo holdings from the natural history museums in Tirana, Belgrade, Skopje, Vienna or Budapest outside GBIF. Nor did I find eBird or Observation.org data beyond what GBIF already carries. Treat these as request leads, not datasets.

### Category 2: National and regional reference lists

| Dataset | Custodian / URL | Licence & access | Format | Version / date | Kosovo check | Supports | Effort & caveats | Sensitivity |
|---|---|---|---|---|---|---|---|---|
| Red Book of Vascular Flora of the Republic of Kosovo (Millaku et al.) | MMPH/KEPA with GIZ support; English summary PDF on ammk-rks.net | Public PDF | PDF | 2013 |\[7\]\[24\]\[26\] Kosovo-only | National threat categories; SDF 3.3 "other species" | Medium (parse to table, match to GBIF backbone) | Low |\[1\]
| Red Book of Fauna of Kosovo | KEPA/AMMK (see above) | Public PDF | PDF | First edition, 2019 (Ibrahimi et al. 2019) | Kosovo-only | Same, fauna | Medium | As above |
| Administrative Instruction No. 18/2012 on protected and strictly protected wild species |\[7\] MESP; Official Gazette gzk.rks-gov.net | Public legal text | PDF/HTML | 2012 (check for amendments) | Kosovo law | National legal protection flag; national screening | Medium (legal text to species table) | n/a |
| "Biodiversiteti i Kosovës" overview | KEPA/AMMK PDF | Public | PDF | Undated on page | Kosovo-only; states "Kosova akoma nuk ka një inventar të plotë të biodiversitetit" ("Kosovo still has no complete biodiversity inventory") |\[27\] Context; gap statement | Low | n/a |
| Table of protected areas in Kosovo 2020 (Zonat e Mbrojtura 2020) | KEPA/AMMK PDF | Public | PDF table | 2020 |\[28\] Kosovo-only | Cross-check against NatDA v24 (237 sites) |\[16\] Low | n/a |

Euro+Med Plantbase, Fauna Europaea and the European regional Red Lists are clear candidates. I did not verify their current versions or Kosovo handling in this session, so they are not tabulated. Check in particular whether Euro+Med and Fauna Europaea treat Kosovo as its own area or fold it into "Serbia (incl. Kosovo)".

### Category 3: Habitats and ecosystems

| Dataset | Custodian / URL | Licence & access | Format / method | Resolution & time (latest version) | Kosovo check | Supports | Effort & caveats | Sensitivity |
|---|---|---|---|---|---|---|---|---|
| Ecosystem types of Europe 2012 v3.1 (terrestrial and full map; reliability map) | EEA / ETC-BD; sdi.eea.europa.eu (DAT-146-en); WMS at bio.discomap.eea.europa.eu (EcosystemTypeMap_v3_1_FullMap) | CC-BY 4.0, open | GeoTIFF, WMS, ESRI REST | 100 m; reference year 2012; published 26 Feb 2019, last modified 9 Oct 2025 | Metadata extent "EEA39", which includes Kosovo |\[29\]\[30\] Habitat stratification; national screening | Low (terra; /vsicurl/). MAES level 2 is coarse and not Annex I; reference year 2012 | None |
| EUNIS habitat maps, level 3 (260 types) | Scientific Data (Nature), 2025, s41597-025-06235-7 |\[6\] Open access (check data licence in repository) | Rasters (probability and most-probable class) | 100 m; EEA39 | EEA39 claimed; verify Kosovo pixels are not NA |\[6\] Candidate Annex I proxies via EUNIS–Annex I crosswalk; national to site screening | Medium; modelled, with uncertainty layers provided. Validate in the field before any SDF use | None |
| Kosovo National Forest Inventory 2012 | MAFRD / Kosovo Forest Agency with Norwegian Forestry Group; abstract at nfg.no | Report public; plot data not open | PDF; Kosovo Forest Information System (KFIS) internal | 2012–2013; forest area 481,000 ha |\[31\]\[32\]\[33\] Kosovo-only | Forest Annex I types (9110/9130/9150, 91M0, 95A0 context); site screening if plots obtained | High (request plot data from ministry) | Low |\[1\]\[34\]
| FISE country profile – Kosovo | EEA Forest Information System for Europe, forest.eea.europa.eu |\[15\] Open | Web | Updated periodically | Lists Kosovo as cooperating country | Forest context | Low | None |

Copernicus CORINE Land Cover, the High Resolution Layers (forest, grassland, water and wetness), Riparian Zones and the N2K land-cover product are standard EEA39 products. I did not re-verify their latest versions in this session. For Kosovo, the N2K product maps only EU Natura 2000 sites, so it will not cover Kosovo, while CORINE and the HRLs are expected to. No Kosovo wetland, peatland, grassland or cave inventory was found as open data.

### Category 4: Site-prioritisation layers and prior Natura 2000 work

| Item | Custodian / URL | Status / access | What it contains | Kosovo check | Supports | Caveats |
|---|---|---|---|---|---|---|
| Emerald Network (lists, viewer, SDF reference portal, biogeographical regions map 2010) | Council of Europe, coe.int/en/web/bern-convention/emerald-network; Emerald Network Viewer | Candidate/adopted lists updated December 2025 | Sites for 16 implementing Parties |\[18\]\[35\] **Kosovo does not participate** (not a Bern Party) | Cross-border context; SDF field guidance | None for Kosovo; reference portal useful for SDF structure |\[1\]\[18\]\[35\]
| Mustafa et al. 2009 "Natura 2000 potential areas in Kosovo" (EU "Sustainable Forest Management" project; "Identifikimi paraprak i zonave të Natura 2000 në Kosovë") | Cited in Landscape Online (LO.201545) and Procedia 2011 (doi:10.1016/j.sbspro.2011.05.181) |\[13\] **Report only, no spatial data found** | About 8 potential zones: Sharr, Bjeshkët e Nemuna, Koritnik, Pashtrik, Koznik, Gërmia, Kopaonik, Mirusha | Kosovo-only | Starting hypothesis for the site list; national screening | 2008/09 data; no boundaries or SDFs |\[13\]\[14\]
| MESP Biodiversity Strategy and Action Plan 2016–2020 | kryeministri.rks-gov.net (Eng-SAPB-2016-2020.pdf), June 2016 | Public PDF | Section 6.1.7; ecological network instrument AI 03/156 (2013); planned IPA habitat-mapping measures (2.4.1–2.4.5) and IBA identification (2019–20) | Kosovo | Policy baseline for gap section | Measures are planned; delivery not verified |\[1\]
| Wetland Henc-Radeva | KEPA | Declared 2014, 109–110 ha |\[36\] Only designated bird-protection area | Should appear in NatDA v24 | SPA candidate | — |\[1\]\[36\]
| BirdLife IBAs / KBAs | keybiodiversityareas.org; BirdLife DataZone | **Not confirmed for Kosovo.** The workshop repository notes IBAs from DataZone "as attributes only; the boundaries are released on request" | — | Bjeshkët e Nemuna described only as a "potential IBA"; strategy lists IBA identification as future action |\[36\] Site screening | Request boundaries from BirdLife; check cross-border Prokletije/Šar sites |\[1\]\[36\]\[37\]
| Important Plant Areas | Plantlife | Koritnik and Korab are recognised IPAs on the Albanian side (Korab-Koritnik Nature Park) |\[38\] — | Kosovo side not confirmed | Cross-border | No open polygons found |
| KEPA twinning "Support to the Environmental Sector in Kosovo" (Umweltbundesamt Austria, FMI, Latvia) | ammk-rks.net/en/projekte | Nov 2010 to Sep 2012, €1.0 m EU | Air/water monitoring, EEA reporting and databases; **no Natura 2000 site outputs** |\[39\] Kosovo | Context only | — |
| European Commission Kosovo Reports 2024 and 2025 (chapter 27) | enlargement.ec.europa.eu | Public PDFs (2025 published 4 Nov 2025) | Environmental administrative capacity "critically low" (per EuroNatur summary); urges site identification |\[40\] Kosovo | Policy framing | Verbatim ch. 27 text not extracted here |\[40\]\[41\]

No Prime Butterfly Area data for Kosovo were found.

### Category 5: Cross-border context

| Dataset | Custodian / URL | Access | Content / date | Relevance |
|---|---|---|---|---|
| Article 17 distribution, 2013–2018, public version | EEA datahub (d8b47719-…); GDB, GeoPackage, WMS; tabular .csv/.mdb | Open (sensitive species removed) | 10 km grid; MS and EU aggregates; Aug 2020 |\[2\]\[42\] Expected-habitat and species list from Greece and Bulgaria (Alpine, Continental and Mediterranean regions); national screening |
| Article 12 bird dataset | EEA |\[3\] Open | Status and trends, distribution grids | Bird-side expected list |
| Montenegro IPA "Establishment of Natura 2000 network" outputs | Species reports (field seasons 2017–2018, 19 experts, nine KBAs); Skadar Lake habitat mapping (GIZ CSBL) | Reports on academia.edu / ResearchGate; spatial data not public | Annex II species and Annex I habitat mapping method |\[43\]\[44\] Methods template; Prokletije transboundary evidence |
| Serbia "EU for Natura 2000" | Project outputs (EPTISA); natura2000.gov.rs | Reports | Serbia's government Natura 2000 portal confirms the project "identified 277 potential Sites of Community Interest (pSCIs) and 85 Special Protection Areas (SPAs)", with "more than 30 international and national experts"; the project ended 30 November 2021 | Draft sites adjacent to northern and eastern Kosovo |
| Albania NaturAL project | e.g. small-mammal data paper (PMC5904422) including Korab-Koritnik | Open article | 2016–2017 fieldwork |\[45\] Cross-border Sharr/Korab evidence |
| Emerald sufficiency (neighbours) | Bankwatch summary of Bern Standing Committee | Web | Sufficiency: Serbia 13.5%, North Macedonia 16%, Montenegro 16.3%, Albania 28.3% |\[46\] Shows neighbours' networks are incomplete too, so their sites are weak evidence of absence |

### Category 6: Environmental covariates for SDMs

I did not re-verify these in this research session, so check versions before use. Copernicus DEM (GLO-30), CHELSA and WorldClim climate, EU-Hydro and HydroSHEDS river networks are all global or EEA39 products that cover Kosovo without coding issues. In R they are reachable through `geodata` (WorldClim, elevation, soil) and `terra` with `/vsicurl/`. Kosovo-specific hydrology exists in the MMPHI river basin management work programme 2025–2027. That document names the Ibër, Morava e Binçës and Lepenc basins as flood-risk areas,\[47\] but it is not a spatial dataset.

### Category 7: Pressures and threats

| Dataset | Custodian / URL | Access | Format / version | Kosovo check | Supports | Caveats |
|---|---|---|---|---|---|---|
| Hydropower Projects on Balkan Rivers | RiverWatch & EuroNatur; balkanrivers.net (2022 update PDF, 37 pp.); 2024 update with interactive map (released March 2025) |\[12\]\[48\] Reports public; point data via map, full data likely on request | Points with status and capacity classes; biennial |\[49\] Kosovo is its own country chapter. Older versions used the non-standard code "KV"; the 2024 update uses "Kosovo (XK)". Schwarz (2025), Hydropower Projects on Balkan Rivers – 2024 Update, reports "Kosovo: 83 planned, 8 under construction", notes that "some already constructed HPPs had to be temporarily shut down due to licensing issues", and flags the Shar Mountain NP zonation's "exclusion of large river valleys, such as the Lepenci river" | Pressure overlay on rivers; site screening | NGO-compiled; SHPP status hard to verify |
| ICMM mining cadastre and GIS | Independent Commission for Mines and Minerals, kosovo-mining.org (data portal and GIS; quarterly licence reports) |\[50\]\[51\]\[52\] Public web; download terms unverified | GIS / reports | Kosovo-only | Mining licences vs candidate sites | Check licence conditions |
| Kosovo Cadastral Agency State Geoportal | geoportal.rks-gov.net; akk.rks-gov.net; new beta portal | Viewing open; **registration required to download**; some products paid |\[53\]\[54\] WMS/web services, orthophotos, cadastre | Kosovo-only (national SDI) |\[55\] Land ownership for SDF and management; site-level | Licence terms unclear; cadastral data may be restricted |
| NP spatial plans (Bjeshkët e Nemuna; Sharri SEA draft) | MMPHI / KEPA PDFs |\[56\]\[57\] Public | PDF zoning maps | Kosovo | Site-level context in the two main candidate areas | Digitising needed |

Global Forest Watch/Hansen forest loss and EFFIS burnt areas are expected to be the main forest-loss and fire layers, but I did not verify them here. Forest pressure is documented nationally: the 2012 inventory reports an annual harvest of 1.6 million m³, 300,000–400,000 m³ above the recommended level, and says "more than 90 percent of the volume is not harvested according to regulations".\[1\]\[31\]

### Category 8: Workshop teaching resources (R)

- **Already in use:** `rgbif`, `CoordinateCleaner`.\[16\]
- **Recommended additions:** `terra` and `sf` for reading EEA GeoTIFF, WMS and GeoPackage layers remotely via `/vsicurl/`, the same technique the repository already uses for NatDA.\[58\] Also `geodata` (WorldClim, elevation), `rredlist` (IUCN API), `eurostat` and `giscoR` (GISCO boundaries; the report already uses GISCO), and `ows4R` for WFS. Package versions and Kosovo handling were not re-verified in this session. GISCO carries Kosovo under the code "XK".

## Data gaps: what Natura 2000 work in Kosovo needs but no open dataset provides

1. **Annex I habitat map or inventory.** None exists. The 2016 strategy planned IPA-funded habitat mapping and distribution maps, and I found no evidence these were delivered.\[1\] The EUNIS level-3 model is only a proxy.
2. **Official or draft site list with boundaries.** There are no pSCIs, SPAs or Emerald sites. The Mustafa 2009 potential areas exist only as a report figure.\[14\]
3. **IBA and KBA polygons for Kosovo.** Unconfirmed; boundaries are available only on request, if at all.\[37\]
4. **National monitoring data.** KINP/KEPA do not publish structured species monitoring data. The Red Books are PDFs without released localities.
5. **Population-size data for SDF section 3.2.** No open source gives population estimates by site.
6. **Wetland, peatland, cave and grassland (6210/62A0, 6170) inventories.** None were found.
7. **Kosovo Article 17-style range assessments** and a delineation of biogeographical regions inside Kosovo. The strategy flags the latter as a priority.\[1\]
8. **Invertebrate and freshwater fish distributions** (Annex II beetles, *Unio crassus*, fish). Only scattered papers exist.

## Recommendations

- Build an **"expected in Kosovo" matrix** now. Take Article 17/12 grids within 50–100 km of the border, intersect them with the Ecosystem types and EUNIS L3 layers, and compare the result with GBIF, EBBA2 and EMMA2 evidence. Each species–square cell then falls into one of three states: expected but unrecorded (a survey gap), recorded (evidence), or recorded but unexpected (check). This gives the gap-analysis section a national-screening product.
- **Digitise Mustafa 2009 potential zones** and overlay them with NatDA, hydropower and ICMM licences. This is a site-screening exercise that participants can do in the workshop.
- **Make formal data requests** to KINP (Red Book localities, monitoring), BirdLife (IBA boundaries), EBCC (EBBA2 abundance and 10 km data), RiverWatch (hydropower points) and the ministry (forest inventory plots). Apply sensitive-species generalisation to 10 km before republishing, in line with the EEA's Article 17 practice.\[2\]

## Caveats

- The web search budget ran out before I could verify the covariate layers (CHELSA, WorldClim, Copernicus DEM, EU-Hydro, HydroSHEDS), Hansen/GFW, EFFIS, CORINE/HRL versions, Euro+Med, Fauna Europaea and the European Red Lists. They are named but not tabulated with verified URLs.
- The Serbian site counts are confirmed on the Serbian government portal (natura2000.gov.rs), and the Kosovo hydropower counts are confirmed in Schwarz (2025), the primary 2024 update report.
- The EMMA2 GBIF upload is a stated plan (The Habitat Foundation's report of the Prague meeting), not a verified release.
- The Red Book of Fauna is dated 2019 from how later papers cite it (Ibrahimi et al. 2019), not from the PDF itself. The status of the 2019–2024 Article 17 reporting round was not confirmed.

## Sources

1. <https://kryeministri.rks-gov.net/wp-content/uploads/2022/08/Eng-SAPB-2016-2020.pdf>
2. [Conservation status of habitat types and species: datasets from Article 17, Habitats Directive 92/43/EEC reporting (2013-2018) - PUBLIC VERSION - Aug. 2020](https://www.pigma.org/geonetwork/5a8srv/api/records/9f71b3e3-f8ec-442b-a2d5-c3c190605ac4)
3. [Spatial distribution of species conservation status trends at Member State level represented in a 10 x 10 km grid | Maps and charts | European Environment Agency (EEA)](https://www.eea.europa.eu/en/analysis/maps-and-charts/spatial-distribution-of-species-conservation)
4. [Ecosystem types of Europe 2012 - Terrestrial habitats - version 3 revision 1, Feb. 2019](https://sdi.eea.europa.eu/catalogue/geoss/api/records/7c0cf3f2-ab54-4cd0-a635-b322df7197f6?language=eng)
5. [• EEA geospatial data catalogue](https://sdi.eea.europa.eu/catalogue/srv/api/records/faff2281-1fca-4548-89d8-c8ec0c507bc7)
6. [EUNIS habitat maps: enhancing thematic and spatial resolution for Europe through machine learning | Scientific Data](https://www.nature.com/articles/s41597-025-06235-7)
7. [THE RED BOOK OF VASCULAR FLORA OF THE ...](<https://www.ammk-rks.net/assets/cms/uploads/files/Publikime-raporte/The_Red_Book_of_Vascular_Flora_of_Republic_of_Kosovo-_English_(Summary).pdf>)
8. [The new EBBA2 website is launched! | EBCC - EBCC](https://www.ebcc.info/the-new-ebba2-website-is-launched/)
9. [(PDF) High resolution maps for the second European Breeding Bird Atlas: a first provision of standardised data and pilot modelled maps](https://www.researchgate.net/publication/314208783_High_resolution_maps_for_the_second_European_Breeding_Bird_Atlas_a_first_provision_of_standardised_data_and_pilot_modelled_maps)
10. [EBBA2 | EBCC - EBCC](https://www.ebcc.info/what-we-do/ebba2/)
11. [A new European mammal atlas – Milvus Group](https://milvus.ro/en/a-new-european-mammal-atlas/)
12. [10 years of hydropower data: 2024 update reveals ongoing threats and wins for Balkan rivers | riverwatch.eu](https://riverwatch.eu/en/balkanrivers/news/10-years-hydropower-data-2024-update-reveals-ongoing-threats-and-wins-balkan)
13. [Overview of Nature Protection Progress in Kosovo | Landscape Online](https://landscape-online.org/index.php/lo/article/view/LO.201545)
14. [(PDF) Management status of protected areas in Kosovo](https://www.researchgate.net/publication/220740571_Management_status_of_protected_areas_in_Kosovo)
15. [Kosovo | Forest Information System of Europe](https://forest.eea.europa.eu/countries/cooperating-countries/kosovo)
16. [Biodiversity of Kosovo](https://jonasgaigr.github.io/kosovo-biodiversity-data-workshop-2026/report.html)
17. [Second European Breeding Bird Atlas](https://mapviewer.ebba2.info/)
18. [Emerald Network Reference Portal - Convention on the Conservation of European Wildlife and Natural Habitats - www.coe.int](https://www.coe.int/en/web/bern-convention/emerald-network-reference-portal)
19. [Full article: Using the first European Breeding Bird Atlas for science and perspectives for the new Atlas](https://www.tandfonline.com/doi/full/10.1080/00063657.2019.1618242)
20. [News](https://european-mammals.org/allnews)
21. [Articles - Biodiversity Data Journal - Pensoft Publishers](https://bdj.pensoft.net/browse_journal_articles.php?journal_name=bdj&alerts_subject_cats=s51&journal_id=1&p=8)
22. [Anchusellacretica (Boraginaceae): a new genus and species record for the flora of Kosovo (Southeast Europe)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12374165/)
23. [Biodiversity Data Journal](https://bdj.pensoft.net/)
24. [Conservation assessment of the endemic plants from Kosovo | Hacquetia](https://ojs.zrc-sazu.si/hacquetia/article/view/4787)
25. [Kosovo · iNaturalist](https://www.inaturalist.org/places/kosovo)
26. [(PDF) LIBRI I KUQ I FLORËS VASKULARE TË REPUBLIKËS SË KOSOVËS](https://www.researchgate.net/publication/260751499_LIBRI_I_KUQ_I_FLORES_VASKULARE_TE_REPUBLIKES_SE_KOSOVES)
27. [BIODIVERSITETI I KOSOVËS](https://www.ammk-rks.net/assets/cms/uploads/files/Biodiversiteti%20IK/Biodiversiteti_i_Kosoves.pdf)
28. [Tabela e zonave të mbrojtura në Kosovë Kodi Emërtimi i Zonës/ objektit](https://www.ammk-rks.net/assets/cms/uploads/files/Biodiversiteti/Zonat_e_Mbrojtura_2020.pdf)
29. [Ecosystem types of Europe 2012 - Full map (marine and terrestrial habitats) - version 3 revision 1, Feb. 2019](https://sdi.eea.europa.eu/catalogue/srv/api/records/faff2281-1fca-4548-89d8-c8ec0c507bc7?language=eng)
30. [Ecosystem types of Europe - European Environment Agency](https://www.eea.europa.eu/en/datahub/datahubitem-view/573ff9d5-6889-407f-b3fc-cfe3f9e23941)
31. [Kosovo National Forest Inventory 2012](https://nfg.no/wp-content/uploads/2024/06/Kosovo-National-Forest-Inventory-2012-abstract.pdf)
32. [Kosovo Forest Information System KFIS “2gether 4 Strong Digital Agriculture”](https://www.agroinnovations.bg/sites/default/files/kfis_presentation_nk_19.04.2018_min.pdf)
33. [Kosovo | Sustainable forestry and appropriate natural resource management](https://nfg.no/kosovo/)
34. [Five-year FAO programme helps Kosovo advance in sustainable forestry management](https://www.fao.org/europe/news/detail/five-year-fao-programme-helps-kosovo-advance-in-sustainable-forestry-management/en)
35. [The Emerald Network Viewer - Convention on the Conservation of European Wildlife and Natural Habitats - www.coe.int](https://www.coe.int/en/web/bern-convention/emerald-viewer)
36. [Birds, Birding Trips and Birdwatching Tours in Republic of Kosovo - Fat Birder](https://fatbirder.com/world-birding/europe/republic-of-kosovo/)
37. [GitHub - jonasgaigr/kosovo-biodiversity-data-workshop-2026: A reproducible R workflow that acquires, quality-controls, analyses and publishes Global Biodiversity Information Facility (GBIF) occurrence data for the territory of Kosovo, with particular attention to species protected under the EU Birds and Habitats Directives. · GitHub](https://github.com/jonasgaigr/kosovo-biodiversity-data-workshop-2026)
38. [Korab-Koritnik Nature Park](https://en.wikipedia.org/wiki/Korab-Koritnik_Nature_Park)
39. [AMMK](https://www.ammk-rks.net/en/projekte)
40. [Balkan nature on the line - EuroNatur](https://www.euronatur.org/en/what-we-do/news/balkan-nature-on-the-line-environmental-compliance-lags-in-eu-accession-drive)
41. [Kosovo Report 2025](https://enlargement.ec.europa.eu/kosovo-report-2025_en)
42. [Conservation status of habitat types and species: datasets from Article 17, Habitats Directive 92/43/EEC reporting](https://www.eea.europa.eu/en/datahub/datahubitem-view/d8b47719-9213-485a-845b-db1bfe93598d)
43. [(PDF) Natura 2000 Habitat Mapping of the Skadar Lake National Park in Montenegro](https://www.researchgate.net/publication/338596085_Natura_2000_Habitat_Mapping_of_the_Skadar_Lake_National_Park_in_Montenegro)
44. [(PDF) Research on Natura 2000 network, Montenegro Species Reports](https://www.academia.edu/39138586/Research_on_Natura_2000_network_Montenegro_Species_Reports)
45. [Small terrestrial mammals of Albania: distribution and diversity (Mammalia, Eulipotyphla, Rodentia)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5904422/)
46. [Bern Convention: Western Balkan countries need to propose new protected natural areas - Bankwatch](https://bankwatch.org/press_release/bern-convention-western-balkan-countries-need-to-propose-new-protected-natural-areas)
47. [PROGRAMI I PUNËS DHE KALENDARI I AKTIVITETEVE (2025-2027)](https://mmphi.rks-gov.net/MMPHIFolder/OtherDocuments/1.%20Programi%20i%20Punes%20per%20PMPL.pdf)
48. [Hydropower Projects on Balkan Rivers 2022 Update August 2022 Prepared by](https://balkanrivers.net/uploads/files/3/Balkan_HPP_Update_2022.pdf)
49. [Hydropower projects on Balkan Rivers: 2020 Update | riverwatch.eu](https://riverwatch.eu/en/balkanrivers/news/hydropower-projects-balkan-rivers-2020-update)
50. [KPMM – Welcome to the Homepage of the Independent Commission for Mines and Minerals](https://kosovo-mining.org/?lang=en)
51. [Function – KPMM](https://kosovo-mining.org/icmm/function/?lang=en)
52. [Applications – KPMM](https://kosovo-mining.org/publications/applications/?lang=en)
53. [About geoportal - KGP](https://geoportal.rks-gov.net/en/per-gjeoportalin/-/asset_publisher/EO0MH4mgPwJp/content)
54. [The New Geoportal of the Kosovo Cadastral Agency is Launched](https://indeksonline.net/en/lansohet-gjeoportali-i-ri-i-agjencise-kadastrale-te-kosoves1-1/)
55. [Kosovo Cadastral Agency | EuroGeographics](https://eurogeographics.org/member/kosovo-cadastral-agency/)
56. [PLANI HAPËSINOR Parku Kombëtar “Bjeshkët e Nemuna”](https://mmphi.rks-gov.net/mmphifolder/OtherDocuments/Plani%20Hap%C3%ABsinor%20PK%20Bjeshk%C3%ABt%20e%20Nemuna.pdf)
57. [Ammk-rks](https://www.ammk-rks.net/assets/cms/uploads/files/Draft%20Raporti%20-%20Vler%C3%ABsimi%20Strategjik%20Mjedisor%20p%C3%ABr%20Parkun%20Komb%C3%ABtar%20Sharri_.pdf)
58. [Add protected areas by jonasgaigr · Pull Request #4 · jonasgaigr/kosovo-biodiversity-data-workshop-2026](https://github.com/jonasgaigr/kosovo-biodiversity-data-workshop-2026/pull/4)
