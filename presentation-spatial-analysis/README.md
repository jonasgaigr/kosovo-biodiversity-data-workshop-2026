# Analysing spatial data for biodiversity conservation

The Day 1 afternoon keynote for the TAIEX Expert Mission on GIS and biodiversity
data management, Pristina, 28–30 September 2026 (case ID ETT IND/EXP 82606),
built on the same vendored AOPK ČR reveal.js template as the other three decks
in this repository.

| | |
|---|---|
| Slot | Day 1, Monday 28 September 2026, **14:00–14:45** |
| Delivery | **35 minutes over 18 content slides**, leaving the balance for questions |
| Source | [`spatial-analysis.qmd`](spatial-analysis.qmd) |
| Slides | `spatial-analysis.html` – reveal.js, 16:9, one self-contained file |
| Handout | `spatial-analysis.pdf` – 21 pages, one slide per page |
| Outline | [`OUTLINE.md`](OUTLINE.md) – **generated**; timings, key messages, visual plan, speaker notes, likely questions, references |
| Plan data | [`data/slide-plan.csv`](data/slide-plan.csv) – one row per slide: minutes, key message, visual and whether it exists |
| Questions | [`questions.md`](questions.md) – authored; appended to the outline |
| Figures | [`make-figures.R`](make-figures.R) builds the one computed figure; [`image-slot.lua`](image-slot.lua) stands in for the rest until they are captured |
| Sources | [`references.bib`](references.bib) |
| Extra styles | [`spatial-analysis.scss`](spatial-analysis.scss), loaded after [`custom.scss`](custom.scss) |
| Audience | MESPI and KEPA officials, national policymakers, university academics |

The deck was **rebuilt from scratch on 22 September 2026** against a written
brief; only the formatting of the earlier version was kept.

## The argument

Five parts, each one slide-group, each handing over to the next:

1. **The data reality** (slides 1–4). Kosovo's published record is thin and
   concentrated – 28 % of it from one 1.1 km² wetland, 189 protected sites with
   no boundary – and that is *not* a reason to wait: decisions are taken anyway,
   the burden of proof sits with the project, and the satellite archive is a
   baseline that can still be collected retrospectively.
2. **Earth observation** (5–6). Land-cover change from Sentinel-2 and CORINE,
   and fragmentation measures, as the immediate baseline – with the limit stated
   plainly: EO shows where and how much, never which species or what condition.
3. **One system, shared standards** (7–9). Why project data dies on hard drives;
   one central biodiversity information system fed by ministry, universities and
   EIA consultants; Darwin Core and INSPIRE as what makes a record readable by
   strangers and across the Sharri and Bjeshkët e Nemuna borders into the
   neighbours' Emerald Network work.
4. **Three working models** (10–17). The open-data dilemma and the Czech NDOP
   answer (open by default, generalised for sensitive species, precise for named
   users); raw data versus an answer, and the UNCG Biodiversity Viewer that joins
   GBIF to legal status for impact assessment; the great crested newt survey trap
   and English district level licensing as spatial data turned into a priced,
   predictable permit.
5. **Next steps** (18). Govern, build, fund: the twelve months of no-cost
   governance work that produce the baseline, owner and data series funders
   back.

The great crested newt is a deliberate thread: it appears first in the NDOP
full-precision screenshot (slide 13, with recorded absences), and is the
subject of the English case four slides later.

**Three audiences, named explicitly.** Ministry officials need the obligation and
the cheapest first step; policymakers need the economic and permitting argument;
academics need methodological rigour and credit for their data. The notes say
which group a point is aimed at, and the closing notes end on one request to
each.

## Where it sits in the agenda

- **11:10 the same morning**, Martin Koška on the EU nature and digital policy
  framework, and again on **Day 2** on INSPIRE data flows. The interoperability
  slide therefore treats INSPIRE narrowly – as a *services* standard – and says
  so in the notes.
- **11:50 the same morning**, Karel Chobot and the author on biodiversity
  database architecture and data modelling. This deck starts one layer up: not
  how the database is modelled, but what having one changes.
- **Day 2, 15:15**, the author on accessing and using GBIF data. The publishing
  route is stated here and taught there.

---

## Accuracy

**The most important section in this README.** The deck makes claims about three
foreign systems and about Kosovo, and a keynote delivered under an EU instrument
is not the place to be approximately right.

### Kosovo figures – from this repository's pipeline

| Figure | Where it comes from |
|---|---|
| 46,831 occurrence records nationally | `data_exports/kosovo_overall_biodiversity.csv` |
| Ligatina e Hencit / Radevës: 1.1 km², 13,346 records, 28 % | `outputs/national_site_statistics.csv`; recomputed by `make-figures.R` |
| 48 sites with a boundary, 189 point-only; 28 of the 48 hold no record | `geometry_source` and `records` in the same file |
| 237 sites, 1,261 km², 11.6 % of the country | EEA Nationally designated areas, v24 July 2026 |
| The Darwin Core example record | GBIF occurrence 5897424625, as held in the export above |

The record counts are **GBIF-mediated and quality controlled by this
pipeline**; they are what has been *published*, not what is *known*, and the
deck says so out loud.

### Checked against primary sources on 22 September 2026

Each of these carries an `urldate` in `references.bib`.

| Claim | Source |
|---|---|
| NDOP: 42,116,850 published records; the great majority public; data provided under contract | NDOP search page; ISOP portal |
| UNCG Biodiversity Viewer: area by admin unit, drawn polygon or KML plus buffer; filters by the Ukrainian Red Data Book, Bern appendices and Resolution 6, Habitats and Birds Directive annexes, Bonn, IUCN, regional lists; CSV/XLSX and HTML/DOCX report; MIT licence; UNCG with The Habitat Foundation, NLBIF-funded; "adapt for any other country" | The repository's `about_en.md`, `Code_Explanation.md` and protected-species list columns |
| District level licensing: red and amber zones; highest-risk (black) areas excluded; no seasonal survey; certificate submitted with the planning application; at least four ponds per occupied pond lost; half of direct costs endowed for 25 years; March–June breeding season | NatureSpace FAQ; GOV.UK scheme page |
| CORINE Land Cover produced for the EEA39, Kosovo included | EEA / CLMS metadata |
| Kosovo Cadastral Agency geoportal launched June 2013, built to INSPIRE standards with search, view and download services | Meha, Crompvoets, Çaka and Pitarka, FIG Working Week 2015 |

**The brief this deck was built from quoted NDOP at "over 24 million records".
That figure is several years old** and is not used; the likely-questions section
explains the difference if someone raises it.

### Still to verify before delivery

| # | Claim | Where it appears |
|---|---|---|
| 1 | The precision NDOP's public view generalises sensitive species to | Slide 12, **visibly flagged on the slide** |
| 2 | NDOP professional-access categories and access logging, as described in the notes | Slide 12 notes – from the author's working knowledge |
| 3 | Which CORINE reference years actually carry Kosovo data | Not stated on any slide; flagged in the bibliography and the questions |
| 4 | Published evidence on DLL conservation outcomes | Questions only – do not claim delivery without it |
| 5 | A stable URL for the Sofia Declaration on the Green Agenda | Bibliography |
| 6 | The minted DOI of the GBIF download | Bibliography; quote the DOI, not the key |

### Where the deck deliberately says less than it could

- **Kosovo's international status.** The status designation footnote from the
  TAIEX agenda is reproduced verbatim on slide 1 and nowhere else. No slide
  asserts an obligation on Kosovo under any EU or Council of Europe instrument.
  The Habitats Directive is cited as the standard alignment leads towards; the
  Emerald Network is described through the neighbours, who are Parties.
- **Sentinel revisit intervals.** "Every few days" only.
- **The cost of a system.** No number is given; the questions section says how
  to answer without one.

---

## Building it

### The computed figure

```bash
Rscript make-figures.R
```

Builds `images/kosovo-record-density.png` from the repository's own pipeline
outputs one level up. Needs `sf` and `ggplot2`. Re-run it whenever the pipeline
is re-run, or the map and the numbers beside it drift apart.

### Slides

```bash
quarto render spatial-analysis.qmd --to aopk-revealjs
```

This directory carries its own `_quarto.yml`, so it is a **separate Quarto
project** from the website in the repository root and from the other three deck
directories. Rendering it does not touch `docs/`, and `quarto render` at the root
skips it – see the `render:` list in the root `_quarto.yml`.

The deck itself needs **only Quarto**: it has no R chunks. The Kosovo figures are
written into the slide as text rather than computed, because they come from a
pipeline run that is not part of this project and freezing a number is the
point.

### The outline

```bash
Rscript build-outline.R
```

`OUTLINE.md` is **generated and must not be edited**. It is built from
`spatial-analysis.qmd` (slide titles and the `::: notes` blocks),
`data/slide-plan.csv` (timings, key messages, visuals), `questions.md` and
`references.bib`. The script stops rather than writing a wrong file if
`slide-plan.csv` and the deck disagree on how many content slides there are.

### Handout

Quarto has no reveal.js → PDF converter. reveal.js prints itself when the page is
opened with `?print-pdf`, so the handout is produced by driving a headless
browser over the rendered slides:

```bash
chrome --headless=new --disable-gpu --no-pdf-header-footer \
       --allow-file-access-from-files \
       --run-all-compositor-stages-before-draw \
       --virtual-time-budget=90000 \
       --print-to-pdf=spatial-analysis.pdf \
       "file:///ABSOLUTE/PATH/TO/spatial-analysis.html?print-pdf"
```

`--virtual-time-budget` matters: the flowchart is laid out by JavaScript at load
time, so a print that fires early gets a page with the diagram missing or half
drawn. Render the slides first: the PDF is printed *from* the HTML.

### Publishing

```bash
mkdir -p ../docs/slides/spatial-analysis
cp spatial-analysis.html spatial-analysis.pdf ../docs/slides/spatial-analysis/
```

**Do not publish while any placeholder box remains** (see "Figures").

---

## Figures

Every picture is written into the `.qmd` as the real thing, with two extra
attributes:

```markdown
![](images/uncg-viewer-map.png){slot="16/10" want="The viewer with an area..."}
```

[`image-slot.lua`](image-slot.lua) checks at render time whether the file
exists. If it does, the image passes through untouched. If not, it is replaced
by a red dashed box of the `slot` aspect ratio that names the file and repeats
the `want` brief. **Dropping the file into `images/` and re-rendering is the
whole of the work** – no slide is edited.

| File | Slide | Status | What it must show |
|---|---|---|---|
| `kosovo-record-density.png` | 3 | **exists** – `make-figures.R` | Records per km² by municipality, protected sites, Ligatina e Hencit ringed |
| `ndop-full-precision.png` | 13 | **exists** – cropped from the n2k deck's `ndop-record-list.png` | NDOP logged-in list, *Triturus cristatus*, NEG absences |
| `eo-change-before.jpg` | 5 | to capture | Sentinel-2 true colour, summer 2016, one extent with visible land-take |
| `eo-change-after.jpg` | 5 | to capture | The same extent, summer 2025, same bands and stretch |
| `fragmentation.png` | 6 | to produce | Habitat patches from a Copernicus layer with roads over them |
| `ndop-public-generalised.png` | 12 | to capture | NDOP public view of a sensitive species, generalised to a square |
| `uncg-viewer-report.png` | 14 | to capture | The viewer's species/legal-status table for one area |
| `uncg-viewer-map.png` | 15 | to capture | The viewer with an area selected, filtered records, filter panel |
| `dll-risk-zones.png` | 17 | to source | A published GCN impact risk zone map; check its reuse licence, or redraw |

Three things are drawn in the slide itself rather than as pictures, so they
cannot come out too small: the Darwin Core record (slide 9), the raw CSV
(slide 14) and the survey calendar (slide 16).

### Legibility – the rule every picture has to meet

**Text inside a picture must land at 16 px or more on the 1280 × 720 canvas.**
Body text is 25.9 px; below about 14 px nothing can be read past the second
row. Before accepting a picture, render the deck and look at the *slide*, not
the file – the first build of the Kosovo map looked fine as a PNG and landed at
11 px on the slide.

The space each picture actually gets:

| Layout | Used on | Picture box on the canvas |
|---|---|---|
| `.aopk-cols` (54 % column) | 3, 12, 17 | ≈ 610 × 370 px – height binds for anything squarer than 1.6:1 |
| `.aopk-cols-wide` (64 % column) | 6, 15 | ≈ 720 × 400 px |
| `.aopk-pair` (half each) | 5, 14 | ≈ 550 × 340 px |
| full width | 13 | ≈ 1130 × 400 px – for very wide strips such as a table |

**For screenshots**, that means: set the browser to 100 % zoom, crop to the
region that matters – never the whole window – and keep the crop no wider than
the box above in CSS pixels (so about 720 px wide for slide 15). Capture on a
high-density screen or with device-pixel-ratio 2, so the file is twice that and
stays sharp on a projector. A full-window screenshot shrunk into a column is the
single most common reason slide text becomes unreadable.

---

## Checking it before it is given

A slide that overflows the safe area is not warned about by Quarto, so this
check is not optional.

```bash
pdftoppm -r 60 -png spatial-analysis.pdf page-dir/page
Rscript check-overflow.R page-dir
```

[`check-overflow.R`](check-overflow.R) scores the strip immediately **above** the
footer bar on each page. It needs the `png` package and nothing else. The logic,
and the two dead ends that preceded it:

- The bar is `$aopk-footer-h`, 65.3 px of the 720 px canvas – the bottom 9.07 %.
- **Do not look inside the bar.** The bar is opaque and is painted *on top of*
  the content, so overflowing text is not printed through it – it is cut off by
  it, and the bar itself comes out pixel-perfect.
- Look instead at a strip about 8 px **above** the bar top, masking out the
  right-hand fifth where the dvojlist leaf legitimately sits.
- On a clean build every content page scores 0.

The `.aopk-section` dividers, the title slide and the closing slide carry
different furniture at the foot by design and always score high. Read those by
eye. **The Sources slide is the tightest in the deck** – on the rebuild it
overflowed until the one-line VERIFY note beneath the bibliography was removed.
Re-check it after any change to `references.bib`.

Placeholder boxes reserve their picture's aspect ratio under the same height cap
as a real figure, so the check is meaningful before the pictures exist – but
re-run it once they arrive, because a real caption may be longer.

### Pacing

```bash
Rscript check-pacing.R
```

The notes are written as full spoken prose, so their word count estimates how
long the talk runs. The target is **120–140 words per allotted minute** – slower
than a native-speaker default, because this audience hears the talk in a second
language. The rebuild sits at about 4,530 words, 130 wpm, with no slide above
150. **Run this after any edit to the notes.** If the timings change, change them
in `data/slide-plan.csv`; the script reads the budget from there.

---

## Notes on the styles

The AOPK extension in [`_extensions/aopk/`](_extensions/aopk) is vendored from
the graphic manual and is not modified here. It is the same copy as in the three
sibling decks, as is [`custom.scss`](custom.scss); keep them in step if the
template is revised.

**Dashes.** The deck uses spaced en dashes (–) throughout, never em dashes. The
vendored template's own comments are left as they are.

[`spatial-analysis.scss`](spatial-analysis.scss) documents each block where it is
defined. The ones worth knowing before editing:

- **`.aopk-cols-wide`** gives a screenshot 64 % of the width. The theme's 54 %
  column shrinks a browser window's text below legibility.
- **Figure captions are 16 px** (0.62 of body), not the siblings' 13 px, and the
  figure height cap reserves 3.6em for them rather than 4.6em.
- **`.aopk-pair` children carry `min-width: 0`.** Without it, the raw CSV's
  unbreakable 100-character line widened its column until the second one was a
  sliver.
- **The Mermaid flowchart has two geometries, not one** – a screen layout and a
  taller print layout – and mermaid's inline `max-width` defeats any percentage
  above the diagram's natural width. The current ratios and the arithmetic for
  the 72 % cap are in the SCSS. Re-derive both if a node or label changes:

  ```bash
  chrome --headless=new --dump-dom spatial-analysis.html             | grep -o 'viewBox="[^"]*"'
  chrome --headless=new --dump-dom 'spatial-analysis.html?print-pdf' | grep -o 'viewBox="[^"]*"'
  ```
