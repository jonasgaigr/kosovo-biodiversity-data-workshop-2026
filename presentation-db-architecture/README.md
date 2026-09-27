# Data flow, quality and standards

Part 2 of the joint session *Biodiversity Database Architecture and Data
Modelling – overview of the recommended structure of a national biodiversity
database* (Day 1, Monday 28 September 2026, 11:50–12:30). It follows Karel
Chobot's Part 1 (`../Day1_CZ_BDarchit_Chobot.pdf`) directly. Part 1 shows
**what** the Czech system holds; Part 2 shows **how data flow** through a
national database, **how quality is earned**, and **which standards** make it
work. Built on the AOPK ČR reveal.js template.

| | |
|---|---|
| Source | [`db-architecture.qmd`](db-architecture.qmd) |
| Slides | `db-architecture.html` – reveal.js, 16:9, one self-contained file |
| Slides as PDF | `db-architecture.pdf` – 12 pages, one slide per page |
| One-page handout | `db-architecture-handout.pdf`, from [`db-architecture-handout.qmd`](db-architecture-handout.qmd) (Typst, A4) |
| Outline | [`OUTLINE.md`](OUTLINE.md) – per slide: time, key message, on-slide text, visual, speaker notes; then the Mermaid diagram. **Generated** |
| Diagram | [`data-flow.mmd`](data-flow.mmd) – the slide 4 data-flow diagram, Mermaid |
| Length | 15–17 minutes; notes are ~2,100 spoken words |
| Audience | Kosovo nature-protection and biodiversity-data staff; strong on biology, mixed on databases and standards |

**Eleven slides and a closing slide.** Title and bridge · about me · five layers ·
data-flow diagram · Flow A (structured monitoring) · Flow B (trusted experts) ·
Flow C (citizen science) · feedback loops · Darwin Core · six habits · takeaways
and discussion · AOPK closing.

**Dashes are en dashes throughout**, spaced; the deck is `lang: en-GB`.

---

## Building it

Run everything from this folder. It is its own Quarto project, excluded from
the website render in the root `_quarto.yml`.

```bash
quarto render db-architecture.qmd --to aopk-revealjs   # slides
quarto render db-architecture-handout.qmd               # one-page handout (Typst)
Rscript check-pacing.R                                  # words per minute, per slide
Rscript build-outline.R                                 # regenerates OUTLINE.md
```

`Rscript` is not on PATH on the author's machine; use
`"C:\Program Files\R\R-4.6.1\bin\Rscript.exe"`. Both R scripts are base R.

The slides PDF is printed from the HTML by headless Chrome, as for the sibling
decks (see `../presentation-n2k-condition/README.md` for why each flag is
there):

```bash
chrome --headless=new --disable-gpu --no-pdf-header-footer \
       --allow-file-access-from-files --run-all-compositor-stages-before-draw \
       --virtual-time-budget=90000 --print-to-pdf=db-architecture.pdf \
       "file:///ABSOLUTE/PATH/TO/db-architecture.html?print-pdf"
```

Then check every slide for content cut off by the footer bar:

```bash
pdftoppm -r 60 -png db-architecture.pdf _pages/page
Rscript check-overflow.R _pages      # every content slide must score 0
```

The title and closing slides always score high (their leaf sits in the strip
the check reads); every other page must be 0. `_pages/` is git-ignored.

**The handout must stay on one page.** After any edit run
`pdfinfo db-architecture-handout.pdf` and check `Pages: 1`. The last time it
spilled, it was the status footnote at the foot of the right-hand column; it now
sits under the resources in the left-hand column, which has room.

### What is generated from what

| Output | Built from |
|---|---|
| `OUTLINE.md` | `db-architecture.qmd` (titles, on-slide text, notes) + `data/slide-plan.csv` (timings, key messages, visuals) + `data-flow.mmd` |
| slide 4 | `data-flow.mmd`, included with `%%| file:` |
| pacing table | `db-architecture.qmd` + `data/slide-plan.csv` |

Both scripts read the deck through [`parse-deck.R`](parse-deck.R), so they
cannot disagree about what a slide says. Never edit `OUTLINE.md` by hand.

---

## Things worth knowing before editing

**The title slide's notes live in the YAML header.** The AOPK title slide is a
fixed template partial and cannot hold a `::: notes` block. reveal.js also reads
speaker notes from a `data-notes` attribute, and the partial writes every
`title-slide-attributes` pair onto the slide, so the spoken bridge from Part 1
is `title-slide-attributes: data-notes:`. It becomes an HTML attribute: **no
double quotes** in it.

**The data-flow diagram.** Mermaid lays the diagram out in the browser, against
its container's width, and reveal's print layout is not its screen layout – so
the diagram has two geometries. Measured with
`chrome --headless=new --dump-dom <deck>.html[?print-pdf] | grep -o 'viewBox="[^"]*"'`:

| | viewBox | ratio |
|---|---|---|
| screen | 1005.3 × 261.9 | 3.84 : 1 |
| print | 1479.8 × 358.3 | 4.13 : 1 |

It is wide rather than tall, so it is limited by **width**: raising the Mermaid
font size alone scales the whole drawing and changes nothing on the slide. What
made the labels bigger was the `%%{init}%%` line in `data-flow.mmd` –
`rankSpacing: 28` and `nodeSpacing: 22` shrink the gaps so the same width holds
larger text (20 px on screen, the size that is projected). Line breaks in the
labels are explicit `<br>`; `wrappingWidth: 320` stops Mermaid adding its own.
Re-measure both viewBoxes if a node is added or a label reworded.

**Tables take the theme's green header band.** The AOPK theme sets every `<th>`
to dark green with white type; the deck's `.codes` and `.xwalk` tables keep
that and only set size and alignment. An earlier draft set the header text grey
and it disappeared into the band.

**Kosovo placeholders are orange, on purpose.** The brief forbids inventing
facts about Kosovo's institutions, systems or law, so where a slide needs one it
carries a `[…]{.placeholder}` span instead: orange dashed, not the red
`[VERIFY]` of the sibling decks, because it is a blank for the hosts to fill,
not a doubtful claim. See the register below.

**Handout bold is Franklin Gothic Demi, reached by a quirk.** Typst files the
Windows Demi, Medium and Heavy cuts under one family, `Franklin Gothic`, all at
weight 400, so a weight cannot choose between them. Asking for the family at 400
resolves to Demi on this machine (`pdffonts db-architecture-handout.pdf` lists
`FranklinGothic-Demi`). Re-check that on another machine.

---

## Placeholders to fill

| Where | Placeholder | Filled by |
|---|---|---|
| slide 10, card 1 | `Here: [to be named]` – the data steward | the hosts, before or in the session |
| slide 11, discussion box | which flow first · who owns the checklist · who validates each group | the room – they are the discussion questions |
| handout, first bullet | legal basis and steward – to be confirmed | the hosts |
| handout, orange box | checklist owner, data steward, validators | participants, by hand |

The notes say nothing about who holds any of these roles in Kosovo today. The
Kosovo Environmental Protection Agency presents *Current State of Biodiversity
Data, GIS Infrastructure and Information Systems at KEPA* at 9:00 the same
morning; if that talk answers any of them, the placeholder can be replaced with
what was said.

---

## Where the content comes from

Part 1 is not repeated. Each slide refers back to it in at most one sentence
(the Survey123 form, the basic Darwin Core fields).

**Czech practice** is taken from the author's own decks in
`Documents/PREZENTACE`, not from memory:

| Claim | Source |
|---|---|
| Survey123 → coordinator marks the data as guaranteed → automatic integration into the species database (slide 5) | `taiex_kosovo_monitoring.pptx` (2 Dec 2024), slide 12 |
| The NDOP validation scale 0/1/3/6/9; validation by regional staff, guarantee by the monitoring department; compulsory for specially protected species, species of Community interest and Annex I birds (slide 6) | `data_druhovka.pptx` (11 Jul 2024), slide 45; `ndop_plzensky.pptx` (6 Jun 2025), slide 19 |
| BioLog: automatic transfer for selected users; other users' records checked, usually against evidence (slide 6) | `ndop_plzensky.pptx`, slide 31 |
| NDOP takes in research-grade iNaturalist records and a BirdLife partner database; two-step validation (slide 7) | `ncis_connatur_202603.pptx` (11 Mar 2026), slide 5 |
| The Nature Conservation Information System is set up in law by Act No. 364/2021 Coll., with AOPK ČR as operator and EU reporting among its purposes (handout) | `validace_slide.pptx` (26 Mar 2025), slide 4 |

No Czech statistics are quoted: record counts are Part 1's, and the afternoon
deck has its own.

**ndopred** (slide 8) is described from its own code
(`Documents/ndopred`, github.com/jonasgaigr/ndopred): `calculate_eoo()` applies
no outlier trimming, citing IUCN Guidelines v16 section 4.9, and
`get_assessment_data()` drops negative records and those with validation status
3 or 9. The deck says no more than that.

**Standards**, checked on 27 September 2026:

| Claim | Checked against |
|---|---|
| Humboldt Extension ratified by TDWG on 28 February 2024; `eco:` terms as spelled on the handout | tdwg.org, eco.tdwg.org/terms |
| GBIF's registry lists *HumboldtEcologicalInventory* (Event core), OBIS *ExtendedMeasurementOrFact*, and Darwin Core *MeasurementOrFact* as active extensions | rs.gbif.org/extensions.html |
| eMoF is an OBIS extension, not a TDWG standard | OBIS manual |
| GBIF has switched its taxonomy to the Catalogue of Life eXtended Release; the old Backbone was last built in 2023 and is frozen | GBIF data blog and technical documentation |

Stated as standing knowledge and **not** re-checked here: Art. 17 and Art. 12
reports every six years with distribution on the 10 km ETRS89-LAEA grid;
`identificationVerificationStatus` has no controlled vocabulary in Darwin Core.

The `gbif.org` pages (IPT) return HTTP 403 to automated requests, so they could
not be opened from here; the IPT link is the one the sibling decks cite. All
other handout links returned 200 on 27 September 2026.

---

## Overlap with the afternoon deck

The same speaker gives *Analysing spatial data for biodiversity conservation*
at 14:00 (`../presentation-spatial-analysis/`). That deck was written before
this one and also explains `coordinateUncertaintyInMeters` and absences on its
*Interoperability* slide, and NDOP's sensitive-species generalisation on
*NDOP: open by default, precise by permission*.

This deck points forward instead of repeating: slide 10 says the Czech
sensitive-species solution comes "this afternoon", and slide 11 ends on the
afternoon talk. **The afternoon notes may want one line –** "as we saw before
lunch" – where they re-explain uncertainty and absences. They have not been
changed.

---

## Publishing and open items

- The deck is listed in `../data/workshop_decks.csv`, so the site's landing
  page links its slides and slides PDF, and `../publish_slides.R` copies both
  into `docs/slides/db-architecture/` together with the one-page handout that
  the title slide links to. After rebuilding the deck, re-render the site (or
  run `Rscript publish_slides.R` from the root) to publish the new files.
- Possible visual upgrades, one per slide where it would help, are in
  `data/slide-plan.csv` (`visual_upgrade`) and in `OUTLINE.md`. None is needed
  for the deck to work.
