# Condition evaluation of Natura 2000 target features

An English-language deck on the site-level condition evaluation framework for
the species and natural habitat types that are target features of the Czech
Natura 2000 network, built on the AOPK ČR reveal.js template.

| | |
|---|---|
| Source | [`n2k-condition-evaluation.qmd`](n2k-condition-evaluation.qmd) |
| Slides | `n2k-condition-evaluation.html` — reveal.js, 16:9, one self-contained file |
| Handout | `n2k-condition-evaluation.pdf` — 24 pages, one slide per page |
| Extra styles | [`n2k-condition-evaluation.scss`](n2k-condition-evaluation.scss), loaded after [`custom.scss`](custom.scss) |
| Length | ~25 minutes |
| Audience | International; data and GIS practitioners |

The deck runs the framework end to end, but the weight is on the **worked
examples and on what the data has to look like** for any of it to work: what a
habitat map carries besides its polygons; what an occurrence record has to
carry before it can show a decline; how a target state is derived, with two
worked cases; what to check about an indicator before fixing a threshold on it;
the validation step that gates publication; and the repository the whole
evaluation runs out of.

The Czech implementation is the vehicle, not the subject. There is no project
framing in the deck — no PAF pillars, no action numbers, no delivery schedule —
because none of that travels to another country, and the principles do.

**The deck is capped at 24 slides**, title slide included, which is what the
speaking slot allows. That cap is the reason several slides carry two points
that used to have one slide each — the mapping layer with the segment
attributes, area with the quality crosswalk, validation with publication, the
forest and amphibian result charts side by side, and the two repository slides
as one. That last merge made room for *A first habitat map: the minimum
standard*, which answers the Kosovo ministry's question on habitat mapping (see
`natura2000.qmd` in the repository root). Adding a slide means taking one out.

**Dashes are en-dashes throughout**, spaced, as the parenthetical dash; the
deck is set `lang: en-GB` and there are no em-dashes in the `.qmd`.

---

## Building it

### Slides

```bash
cd presentation-n2k-condition
quarto render n2k-condition-evaluation.qmd --to aopk-revealjs
```

This directory carries its own `_quarto.yml`, so it is a **separate Quarto
project** from the website in the repository root and from `presentation/`.
Rendering it does not touch `docs/`, and `quarto render` at the root skips it —
see the `render:` list in the root `_quarto.yml`.

### Handout

Quarto has no reveal.js → PDF converter. reveal.js prints itself when the page
is opened with `?print-pdf`, so the handout is produced by driving a headless
browser over the rendered slides:

```bash
chrome --headless=new --disable-gpu --no-pdf-header-footer \
       --allow-file-access-from-files \
       --run-all-compositor-stages-before-draw \
       --virtual-time-budget=90000 \
       --print-to-pdf=n2k-condition-evaluation.pdf \
       "file:///ABSOLUTE/PATH/TO/n2k-condition-evaluation.html?print-pdf"
```

`?print-pdf` is what puts reveal.js into print layout;
`--no-pdf-header-footer` suppresses Chrome's own page furniture so the page size
comes from reveal's `@page` rule (the 1280 × 720 slide);
`--run-all-compositor-stages-before-draw` makes the result deterministic — without
it the print occasionally fires mid-layout and yields a blank page.

Render the slides first: the PDF is printed *from* the HTML, so it can never be
newer than it.

Rasterising a page is the quickest way to check a slide for overflow, because
anything laid out below the safe area prints straight through the footer bar:

```bash
pdftoppm -f 14 -l 14 -r 100 -png n2k-condition-evaluation.pdf page
```

### Publishing

Pages serves `docs/` from the branch, and `docs/` is built locally rather than
in CI. Rendering the website at the repository root copies the slides and the
handout into `docs/slides/n2k-condition/` and lists the deck on the site's
landing page, from its row in
[`../data/workshop_decks.csv`](../data/workshop_decks.csv). After rebuilding the
deck alone, republish it from the repository root without re-rendering the
site:

```bash
Rscript publish_slides.R
```

---

## Notes on the template and the styles

The AOPK extension in [`_extensions/aopk/`](_extensions/aopk) is vendored from
the graphic manual and is not modified here. It is the same copy as in
[`presentation/`](../presentation), as is [`custom.scss`](custom.scss) bar two
comment edits; keep them in step if the template is ever revised.

A handful of things in
[`n2k-condition-evaluation.scss`](n2k-condition-evaluation.scss) are worth
knowing before reworking a slide:

**The condition scale is a grid of four cards, not a heading each.** Pandoc turns
a heading inside a fenced div into a `<section>`, and reveal.js reads every
`<section>` as a slide — so `#### Good` inside a card silently adds four slides
to the deck. The card's class name is a `[Good]{.state-name}` span instead.

**A caption's size has to be set on its paragraph, not on its wrapper.** The
theme sets `font-size` on `.reveal p, .reveal li` directly, so a size set on the
`.figcaption` div never reaches the text inside it and the caption comes out at
full body size — which pushes it below the safe area and prints through the
footer bar. `.figcaption p` is therefore in the selector list. The theme's own
`.smaller` carries `p` for exactly this reason.

**Figures are capped in height, and the hook is their shape, not their path.**
Every figure here is followed by a caption that translates its Czech labels, and
the theme would otherwise let the picture fill the whole safe area and push the
caption under the footer bar. The cap cannot be hung off a `src` match, because
`embed-resources` inlines each picture as a base64 data URI and no `src` in the
built deck contains its path; nor off a `height=` Markdown attribute, which
Pandoc emits as a presentational HTML attribute that reveal's own
`img { height: auto }` outranks. `p > img:only-child` is the shape that survives
both.

**`.aopk-section-photo` puts a photograph across the top of a section divider.**
The divider anchors its heading at 42 % of slide height, so the whole top of
the slide is empty green. The photo band is absolutely positioned rather than
laid out, because an absolutely positioned child of the slide resolves its
offsets against the section's *padding* box — which is the whole 1280 × 720
canvas, the same reason the theme's own footer bar reaches both edges with
`left: 0; right: 0`. So the band is full bleed and the heading anchor never
moves. A gradient over its bottom third carries the picture into the green
rather than ending it on a line.

**`.aopk-pair` is for two figures read against each other**, which the theme's
`.aopk-cols` cannot do: that one is deliberately asymmetric — 42 % text, 54 %
picture — because it reproduces the graphic manual's image block. Two slides
need equal halves (the hillside with and without the mapping layer; one
indicator seen two ways), and both of them also carry a note under the pair, so
`.aopk-pair` has its own height cap with a larger reserve.

**Dense slides carry `{.no-leaf}`.** It drops the dvojlist and returns its 83.5 px
to the content box — the difference between a caption that fits and one that
prints through the bar. Most of the two-column slides need it; the budget is
roughly **15 body lines** in an `.aopk-cols` column with the leaf and **17 or
so** without it, counting a bullet's item gap as most of a line. Anything past
that is laid out below the safe area and prints straight through the footer
bar, with no warning from Quarto.

**The closing slide's logo lockup is exempted from the figure hairline.** The
1 px border above is written for a screenshot on a white ground, but the
lockup's markup has the same shape — a lone image in its own paragraph — so it
was picking the border up too. The lockup's SVG viewBox is cut tight to the
ink, so the frame landed on the leaf and on the baselines of both wordmarks,
and boxed in the rule that divides the wordmark from the slogan: at slide size
the three verticals read as a stray letter next to "OF THE CZECH REPUBLIC". The
override also lifts the height cap, because the theme sizes that lockup itself,
at the 12.09 % of slide height the graphic manual specifies.

---

## Figures

`images/` holds nineteen figures and four photographs, of which **thirteen
figures and three photographs are on a slide**. The rest are kept because the
slide that used them was cut to hold the deck to 24 pages, not because they
were wrong; the table below says which.

With one exception the figures are lifted from the decks in
`Documents/PREZENTACE` rather than redrawn, so they are the framework's real
outputs. Each is a Czech-language screenshot or a chart with Czech labels; the
caption beside it on the slide carries the translation. `aggregation-levels` is
the exception — it is in English and is drawn from the framework's own source,
see below.

| File | Shows | Lifted from | On a slide |
|---|---|---|---|
| `habitat-ortho.jpg` | one hillside as an orthophoto, nothing over it | `2026_MMJP_Téma 2 …_CZ.pptx` | yes |
| `habitat-segments.jpg` | the same extent under the mapping layer, segments labelled with habitat code and quality | `2026_MMJP_Téma 2 …_CZ.pptx` | yes |
| `habitat-segment-attributes.jpg` | one segment selected, with its attribute panel open | `2026_MMJP_Téma 2 …_CZ.pptx` | yes |
| `habitat-quality-crosswalk.png` | the field-attribute → quality lookup | `isop_hodnoceni.pptx` | yes |
| `aggregation-levels.png` | occurrence → subsite → protected area → region → country, in English | `BiodivMonCZ/host_naturecz` | yes |
| `ndop-record-list.png` | a page of records, with the `NEG`, grid-cell and reliability columns | `isop_hodnoceni.pptx` | yes |
| `species-trend.png` | *Barbastella barbastellus* population trend (English labels) | `2023 Theme 2 … status_JG.pptx` | yes |
| `indicator-by-site-size.png` | dead-wood indicator distribution by site area class | `monseminar_hodnoceni.pptx` | yes |
| `indicator-vs-area.png` | dead-wood indicator against site area, with the Spearman fit | `monseminar_hodnoceni.pptx` | yes |
| `portal-results.png` | validated results as published on the ISOP Portal | `2026_MMJP_Téma 2 …_CZ.pptx` | yes |
| `management-planned-realised.jpg` | planned against implemented management | `2026_MMJP_Téma 2 …_CZ.pptx` | yes |
| `habitat-results-forest.png` | forest habitat types by condition class | `monseminar_hodnoceni.pptx` | yes |
| `species-results-amphibians.png` | amphibian target features by condition class | `monseminar_hodnoceni.pptx` | yes |
| `habitat-mapping-districts.png` | mapping districts with their last update year | `isop_hodnoceni.pptx` | no |
| `ndop-record.png` | the head of one NDOP record, cropped to its top 45 % | `2026_MMJP_Téma 2 …_CZ.pptx` | no |
| `monitoring-plot-designations.jpg` | one plot's geometry resolved against twelve designations | `2026_MMJP_Téma 2 …_CZ.pptx` | no |
| `species-subsites.jpg` | monitoring subsites inside one site | `isop_hodnoceni.pptx` | no |
| `quality-by-authority.png` | habitat quality by the body responsible for the sites | `monseminar_hodnoceni.pptx` | no |
| `habitat-results-grassland.png` | grassland habitat types by condition class | `monseminar_hodnoceni.pptx` | no |

The five unused figures are the ones whose slides went: "Geometry is the join"
(`monitoring-plot-designations`), "Who scored it is part of the data"
(`quality-by-authority`), "Results: grassland habitats"
(`habitat-results-grassland`), and the two that were merged away when "The
polygon is half the data" folded into the mapping-layer slide
(`habitat-mapping-districts`) and the two NDOP slides became one
(`ndop-record`, `species-subsites`).

The **photographs** are the author's own, supplied for this deck rather than
lifted from an earlier one. Each one rides the top band of a section divider,
picked so the picture is of what the section is about:

| File | Subject | Divider it sits on |
|---|---|---|
| `photo-dry-grassland.jpg` | feather-grass steppe on a slope above arable land | Why condition is assessed site by site |
| `photo-osmoderma-survey.jpg` | *Osmoderma* larvae in the hand — a record being made | The evidence base |
| `photo-bombina-variegata.jpg` | *Bombina variegata* in a pool | How a site is assessed |
| `photo-dianthus-moravicus.jpg` | *Dianthus moravicus*, a Czech endemic, on rock | none — see below |

Three section dividers survived the cut to 24 slides. "What gets evaluated" and
"From assessment to decision" went, and `photo-dianthus-moravicus.jpg` is
therefore unused; it is kept for whichever divider comes back.

The deck carries no photo credits, because nothing else in it is credited
either. Add a line to each divider if that is not the right call.

### How they were cut

The slide media were extracted straight out of the `.pptx` archives
(`unzip 'ppt/media/*'`), then processed in R with **terra** — flatten the alpha
channel onto white, crop, area-average down to a sensible width, and write PNG
or JPEG. Area-averaging rather than bilinear matters: a bilinear downscale of a
screenshot aliases its one-pixel table rules into a moiré.

- Photographs and orthophotos go out as **JPEG**; screenshots of text and
  charts stay **PNG**, where the palette compresses better than JPEG and does
  not ring around the type. `monitoring-plot-designations` is the exception —
  it is half basemap, so JPEG at quality 90 is a third of the PNG.
- `habitat-quality-crosswalk` is cropped out of its Excel ribbon and taskbar,
  down to the grid and the sheet tabs.
- `management-planned-realised` was cropped to its non-transparent bounding box,
  its canvas being largely empty alpha.
- The `photo-*.jpg` strips are 3:1 crops at 1600 px wide, cut out of 4–16 MB
  camera originals. The divider band is wider than 3:1, so `object-fit: cover`
  does the final trim — the crop only picks the region of interest and gets the
  file down to something that can be inlined. The originals stay in
  `images/_originals/`, which is git-ignored, for when a crop has to be redone.

The deck embeds every one of them as base64 (`embed-resources: true`), which
adds a third to each file, so the built HTML is about 8.5 MB. Keep new figures
under a few hundred kB.

Re-cut any of them if the output it is a picture of changes.

### `aggregation-levels.png` is the one figure not cut from a `.pptx`

The Czech version of the chain diagram was replaced by the English one so the
deck has no untranslated picture left in it. The framework's own repository
keeps both as draw.io sources — `Diagrams/hodnoceni_urovne.drawio` and
`Diagrams/hodnoceni_urovne_en.drawio` — but only exports the Czech one, so the
English PNG had to be produced here.

[`images/aggregation-levels.drawio`](images/aggregation-levels.drawio) is the
upstream English source with three edits, and is checked in so the PNG can be
regenerated:

- the three columns of English bullets under the flow are **removed**, and the
  dashed separators shortened to match, so the diagram crops to the chain — the
  bullets set at a readable size make the picture 1.3:1, and on a 16:9 slide
  under a heading that leaves them about ten pixels tall;
- `EVALUATION WITHIN SITE` is relabelled **`SUBSITE EVALUATION`**. Upstream uses
  "site" for what this deck calls a subsite and "protected area" for what this
  deck calls a site, and the diagram sat next to slides using the other
  vocabulary;
- upstream's two typos in the removed bullets (`INDICATIORS`, `THIR`) went with
  them.

To re-export it without draw.io installed: load
[`viewer-static.min.js`](https://viewer.diagrams.net/js/viewer-static.min.js)
in a local page, hand the XML to `GraphViewer.createViewerForElement`, and take
the SVG back out with `graph.getSvg('#ffffff', 1, 24, true, true)`. The PNG in
`images/` is that SVG rasterised at 1.5× its 2258 × 1049 natural size.

---

## Sources

The content is drawn from the decks in `Documents/PREZENTACE`, most recent
first:

- `2026_MMJP_Téma 2 Monitoring a hodnocení stavu předmětů ochrany_CZ.pptx`
  (8 April 2026) — target-state criteria, validation, and the ISOP screenshots
  of the mapping layer, the record card and the monitoring plot
- `monseminar_hodnoceni.pptx` (4 March 2026) — the two-indicator
  simplification, the aggregation chain, and the exploratory charts behind the
  habitat thresholds
- `hodnoceni_porada_ku_2025.pptx` and `Jedna příroda_hodnoceni_stavu_JG.pptx`
  (December 2025) — the regional-authority round, known weaknesses
- `isop_hodnoceni.pptx` (November 2025) — the fullest methodological account:
  mapping layer, area and quality, target-state derivation with worked examples
- `N2K_evaluation.pptx` (2023) and
  `2023 Theme 2 Monitoring and evaluation of target features status_JG.pptx` —
  the English vocabulary, the adaptive management cycle, the management
  effectiveness matrix

The two slides on the implementation — "The evaluation runs as code" and "What
the repository fixes in place" — are drawn from the code itself, at
[`BiodivMonCZ/host_naturecz`](https://github.com/BiodivMonCZ/host_naturecz):
its README, the shared config `R/00_config/00_n2k_config.R`, the species runner
`R/02_druhy/20_n2k_druhy_run.R` (whose numbered cascade and `nacti_config()`
guard are what those slides describe), and the threshold file
`Data/Input/limity_vse.csv`, whose seven columns are the table on the second of
them. Re-read them if the repository is reorganised — the slides name paths.

One correction was made against the sources: the 2023 English deck lists the
65 bird target features under Annex II of the Birds Directive. Annex I is the
annex that drives SPA designation, and the deck says Annex I.
