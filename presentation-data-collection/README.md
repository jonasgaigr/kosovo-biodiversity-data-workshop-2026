# Open-source and free options for spatial data collection on biodiversity

The Day 3 afternoon deck for the TAIEX Expert Mission on GIS and biodiversity
data management, Pristina, 28–30 September 2026 (case ID ETT IND/EXP 82606),
built on the same vendored AOPK ČR reveal.js template as the other two decks in
this repository.

| | |
|---|---|
| Slot | Day 3, Wednesday 30 September 2026, **14:00–14:45** |
| Source | [`spatial-data-collection.qmd`](spatial-data-collection.qmd) |
| Slides | `spatial-data-collection.html` — reveal.js, 16:9, one self-contained file |
| Handout | `spatial-data-collection.pdf` — 32 pages, one slide per page |
| Data | [`data/comparison.csv`](data/comparison.csv) — the head-to-head matrix, with a source URL and a check date per row |
| Sources | [`references.bib`](references.bib) — every vendor page behind a figure, with its access date |
| Extra styles | [`spatial-data-collection.scss`](spatial-data-collection.scss), loaded after [`custom.scss`](custom.scss) |
| Logos | [`images/logos/`](images/logos) — eight vendor brand assets; provenance and trademark status in [`SOURCES.md`](images/logos/SOURCES.md) |
| Audience | MESPI and KEPA biodiversity officers and GIS staff; institutional, not individual |

The deck is written from the position of an agency choosing a collection system
for itself, not from a vendor's. It runs the data lifecycle from plan to
archive, places four families of tool on it — form-based apps, GIS-native field
mapping, observation platforms, and the specialised tools for patrols and
camera traps — compares eight of them head to head, and ends on a decision
flowchart and the field pitfalls that cost a season.

Two neighbours in the agenda set its boundaries. Publishing to GBIF was covered
in the Day 2 GBIF slot and in the Day 3 morning portal and geoportal sessions,
so section 8 is a single hand-off slide rather than a re-teach; and automated
map and report production follows at 15:15, so the pipeline slide stops where
that one starts.

**Every tool gets at least one strength and at least one limitation.** That is a
rule of the deck, not a stylistic habit — the argument only works if the open
options are not assumed to win.

---

## Accuracy

**Every price, free-tier limit, licence and hosting location was checked
against the vendor's own page on 21 September 2026, and re-checked on 23
September 2026.** The comparison slide carries the check date on the slide
itself, `data/comparison.csv` carries it per row alongside the source URL, and
`references.bib` carries an `urldate` on every entry. These move constantly.
**Re-check before the deck is given again**, and re-check anything quoted from
it.

The 23 September pass corrected four things, all now fixed in the deck, the CSV
and the bibliography:

- **KoboToolbox is free for government bodies.** The pricing page's
  "Nonprofit" category is defined as "nonprofits, government agencies, UN
  organizations, and educational institutions", so a ministry gets the free
  Community Plan (5 000 submissions a month, 1 GB). The $25 Starter plan is
  marked n/a for that category; the next tier open to a public body is
  Professional, $159 a month or $129 billed annually. The earlier text said the
  opposite on three slides.
- **Esri's product pages carry no price.** The Survey123, Field Maps, ArcGIS
  Online and user-type pages all route to sales, and the cells say exactly
  that. Third-party sources quote Esri's own store for a Creator seat, so "no
  list price is published anywhere" would overstate it.
- **Wildlife Insights does not export Camtrap DP.** Its private downloads are
  its own CSV set. Only Agouti, of the two, emits the standard, and Camtrap DP
  is described as maintained by a TDWG interest group rather than as a ratified
  TDWG standard.
- **Fulcrum stores WGS84 only** (EPSG:4326, per its help centre). That closes
  what was the one `TODO: verify` in the CSV.

One fact is stated more narrowly than the obvious phrasing, because the narrow
version is what the source supports:

- **KoboToolbox paid tiers** are $25–$359 a month depending on plan, billing
  period and category. The slide quotes the Community Plan limits and the first
  tier open to a public body, which are the two figures that actually decide
  anything for this audience.

The record counts on the licensing slide were read from the GBIF API on the
same date, not from a vendor page.

---

## Building it

### Slides

```bash
cd presentation-data-collection
quarto render spatial-data-collection.qmd --to aopk-revealjs
```

This directory carries its own `_quarto.yml`, so it is a **separate Quarto
project** from the website in the repository root and from the other two deck
directories. Rendering it does not touch `docs/`, and `quarto render` at the
root skips it — see the `render:` list in the root `_quarto.yml`.

The deck needs **R with `knitr`**, which the other two decks do not: the two
head-to-head slides are built by an R chunk from `data/comparison.csv` so they
cannot drift apart, and so that correcting a price is a one-line edit to a data
file. Nothing beyond base R and `knitr` is used, deliberately — `quarto check
knitr` is the whole dependency check.

### Handout

Quarto has no reveal.js → PDF converter. reveal.js prints itself when the page
is opened with `?print-pdf`, so the handout is produced by driving a headless
browser over the rendered slides:

```bash
chrome --headless=new --disable-gpu --no-pdf-header-footer \
       --allow-file-access-from-files \
       --run-all-compositor-stages-before-draw \
       --virtual-time-budget=90000 \
       --print-to-pdf=spatial-data-collection.pdf \
       "file:///ABSOLUTE/PATH/TO/spatial-data-collection.html?print-pdf"
```

`?print-pdf` is what puts reveal.js into print layout;
`--no-pdf-header-footer` suppresses Chrome's own page furniture so the page
size comes from reveal's `@page` rule (the 1280 × 720 slide);
`--run-all-compositor-stages-before-draw` makes the result deterministic.

**`--virtual-time-budget` matters more here than in the sibling decks.** The
three Mermaid diagrams are laid out by JavaScript at load time, so a print that
fires early gets a page with the diagram missing or half drawn. 90 seconds is
comfortable; do not cut it.

Render the slides first: the PDF is printed *from* the HTML, so it can never be
newer than it.

### Publishing

Pages serves `docs/` from the branch, and `docs/` is built locally rather than
in CI. Rendering the website at the repository root copies both built files
into `docs/slides/data-collection/`, side by side so that the handout link on
the title slide resolves, and lists the deck on the site's landing page. The
deck's row in [`../data/workshop_decks.csv`](../data/workshop_decks.csv) drives
both. After rebuilding the deck alone, republish it from the repository root
without re-rendering the site:

```bash
Rscript publish_slides.R
```

Both are self-contained single files, so nothing else has to go with them.

---

## Checking it before it is given

A slide that overflows the safe area prints straight through the footer bar,
and Quarto gives no warning at all. The check that catches it:

```bash
pdftoppm -r 60 -png spatial-data-collection.pdf page
```

then compare each page's bottom band against a page known to be clean. **There
are two clean shapes, not one** — a slide with the dvojlist and a `.no-leaf`
slide without it — and scoring every page against a single reference puts all
eleven no-leaf slides at the same non-zero distance, which is exactly where a
real overflow hides. Scoring against the nearer of the two separates them: the
clean pages sit at 0.0002 and an overflowing one at 0.009.

That is how the overflow on "Form-based collection: the open options" was
found: its left column ran two lines past the safe area and printed through
the bar. It now carries `{.no-leaf}` and shorter copy, and its last line sits
just clear. **It is the tightest slide in the deck — re-check it after any
edit.** It still scores about 0.007, because the sampled band deliberately
reaches above the bar to catch near-misses and that last line is inside it.

The five section dividers and the title and closing slides carry different
furniture at the foot by design and have to be read by eye.

---

## Notes on the styles

The AOPK extension in [`_extensions/aopk/`](_extensions/aopk) is vendored from
the graphic manual and is not modified here. It is the same copy as in
[`presentation/`](../presentation) and
[`presentation-n2k-condition/`](../presentation-n2k-condition), as is
[`custom.scss`](custom.scss); keep them in step if the template is revised.

Three things in [`spatial-data-collection.scss`](spatial-data-collection.scss)
are worth knowing before reworking a slide.

**A Mermaid diagram is sized through its width, and only its width.** Two
traps, both of which cost a render each to find. First, Quarto writes the
diagram into a `<pre class="mermaid">` but **mermaid.js replaces that element**
with the finished `<svg>` when the deck loads, so a rule hung off `pre.mermaid`
matches for one frame and then never again — an early version of the rule
changed nothing whatever and the print came out byte for byte identical.
Second, **height cannot be constrained**: the `<svg>` carries `width="100%"`
and a viewBox, so the browser scales the drawing when the width changes but not
when the height does. Probed with `height: 250px !important` and a red outline,
the outline drew at 250 px and the flowchart rendered straight through it,
unchanged. The theme's own `max-height` on `svg` is inert for the same reason.
So the rule keys off `div.cell svg`, and a diagram too tall at full width gets
`.diagram-tall` on its slide. The decision flowchart's viewBox is
1493.5 × 691.0 and the content column is 1129.2 px, so at full width it wants
522 px against the 455 px a `.no-leaf` slide has; 78 % of the column is 407 px
tall. **Re-derive that percentage from the viewBox if the flowchart changes.**

**The diagram font is deliberately left as mermaid's own.** Mermaid measures
every label in the font it renders with and draws each box around the
measurement, so a family swapped in afterwards is laid out against boxes
computed for a different one and the wider glyphs are clipped — the first
render lost the "d" of "In the field" and the "I" of "Zenodo DOI" exactly that
way. Setting it through mermaid's `themeVariables` would be measured correctly
but only where the font is installed, and the AOPK stack falls back on any
machine without Franklin Gothic. A diagram in mermaid's default sans is a small
break with the slide type; a clipped label is an error.

**The comparison matrices are `.matrix`, and their chunks are labelled
`matrix-…` rather than `tbl-…`.** `custom.scss` steps every table to 0.72 of
body size, which suits the sibling decks' three-column tables; eight tools
against five or six criteria needs 0.52. And a `tbl-` label prefix is Quarto's
cross-reference convention, which prints "Table 1" above the table and pushes
it down the slide.

One more, in the same file: the theme fills the table header row with dark
green, so `th` has to be set white explicitly. Without it the criterion names
are dark green on dark green and the header prints as an empty bar — which is
how it first rendered.

---

## Slide numbers

The extension ships `slide-number: false`; this deck turns it on, because it is
handed out as a PDF and questions in the room refer to slides by number.
Reveal pins the counter to the bottom-right corner, which in this template is
inside the footer bar and on top of the `footer-right` text, so the SCSS lifts
it clear. It is hidden in print, where the PDF reader's own page number is the
same number.

---

## What is still to write

The "What was painful" half of **"BiodivPond: what worked, what hurt"** is now
written, from the author: versioning the form, building it under time
pressure, and not testing it enough. The speaker notes tie all three to the
pitfalls slide and to "Where to start on Monday".

One `<!-- TODO: author to add -->` slot remains, in the "What the design got
right" column: one concrete thing that worked, with the evidence. **The three
bullets already in that column – the EU server chosen first, one row per
occurrence, names matched to the GBIF backbone in the pipeline – and the
pipeline diagram itself are not in any public source** (the analysis pipeline
is not public). Confirm them before delivery.

The verified public facts about the pilot are in the speaker notes of the
pipeline slide: a Biodiversa+ project running 2026–2028; standardised sampling
of a minimum of six ponds per partner, sixty in total, in late spring 2026; a
citizen-science component targeting five hundred more ponds; amphibians, fish,
aquatic macro-invertebrates and bats, by traditional methods, eDNA and passive
acoustic monitoring. The partner count – AOPK ČR coordinating, with nine
partners – is from the author's own partner briefing of 4 March 2026
(`BiodivPond_slidy.pptx`). The organisation at `github.com/BiodivPond` has
three public repositories — the `.github` profile, the project site, and a
conference poster — so **the analysis pipeline is not public**, and the deck
does not claim it is.

---

## Figures and logos

**There are no photographs or screenshots**, and that is a choice rather than
an omission: every diagram is Mermaid, generated from the `.qmd`, so there is
nothing to re-cut when an output changes. The five section dividers are plain,
and the theme's `.aopk-section-photo` from
[`presentation-n2k-condition/`](../presentation-n2k-condition) can be lifted
across if photographs are wanted on them.

**The eight product logos** in [`images/logos/`](images/logos) are the vendors'
own published brand assets, unmodified, on four slides: the two form-based
slides, the GIS-native slide and the map-versus-form slide. They are *not* in
the comparison matrices — those rows are already at 0.52 of body size, and a
logo per row would put the taller one through the footer bar for no gain, since
the tool column is a scanning anchor and reads faster as text.

[`images/logos/SOURCES.md`](images/logos/SOURCES.md) records, per logo, where
it was downloaded from and what that owner's trademark policy actually says.
**Read it before reusing any of them.** In short: ODK, QField and QGIS publish
an explicit permission for course and presentation material; KoboToolbox,
Epicollect5, Fulcrum and Esri require written consent or grant no rights at
all, and Mergin Maps publishes a brand-assets page with no terms on it. The
deck uses all of them nominatively — to identify the products it compares —
and the Sources slide carries the notice that says so, along with the
attribution to `getodk.org` that ODK's policy requires. **That was a decision
taken knowingly, not an oversight.** The logos are confined to four slides and
one SCSS block if it has to be reversed.

Two things about the markup are worth knowing before adding another.

**Size them by height, never width.** `.logo` is 30 px and `.logo-icon` is
26 px. The assets run from 5.4:1 wordmarks to square app icons, and height is
the only dimension that makes those look like one set. ODK's lockup is 1.83:1,
which is why it is an icon here and not a wordmark — at a wordmark's height it
was a third the weight of the Mergin wordmark beside it and read as a stray
thumbnail.

**Never leave a logo alone in its paragraph.** Pandoc's implicit-figure rule
turns an image that is the whole paragraph into a `<figure>` with its alt text
as the caption, so the Fulcrum logo first rendered centred in its column with
a green "Fulcrum" caption under it. Every logo here is followed by text on the
same line — the product's licence — which is both the fix and useful content.
The other half of the same problem: the theme sets `.aopk-cols img { display:
block }`, so `.logo` re-declares `display: inline-block`, without which every
heading on these slides wrapped to two lines and the tightest one overflowed.
