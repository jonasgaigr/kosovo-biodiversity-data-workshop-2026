# Accessing and utilising GBIF data — TAIEX deck

The slides for **Day 2, 15:15–16:00** of the TAIEX Expert Mission on GIS and
biodiversity data management, Pristina, 28–30 September 2026
(case ID ETT IND/EXP 82606).

| | |
|---|---|
| Source | [`gbif-data-access.qmd`](gbif-data-access.qmd) |
| Slides | `gbif-data-access.html` — reveal.js, 16:9, one self-contained file |
| Handout | `gbif-data-access.pdf` — 31 pages, one slide per page |
| Template | AOPK ČR reveal.js extension, from *Grafický manuál AOPK ČR 2026* |

The deck runs the workshop slot end to end: what GBIF holds for Kosovo, the four
routes into it, how to read occurrence records honestly, the reproducible site
built on them, and five failure modes that return a plausible answer and no
error message.

---

## Building it

### Slides

```bash
cd presentation
quarto render gbif-data-access.qmd --to aopk-revealjs
```

`presentation/` carries its own `_quarto.yml`, so it is a **separate Quarto
project** from the website in the repository root. Rendering it does not touch
`docs/`, and `quarto render` at the root skips it — see the `render:` list in
the root `_quarto.yml`.

### Handout

Quarto has no reveal.js → PDF converter. reveal.js prints itself when the page
is opened with `?print-pdf`, so the handout is produced by driving a headless
browser over the rendered slides:

```bash
chrome --headless=new --disable-gpu --no-pdf-header-footer \
       --allow-file-access-from-files \
       --run-all-compositor-stages-before-draw \
       --virtual-time-budget=60000 \
       --print-to-pdf=gbif-data-access.pdf \
       "file:///ABSOLUTE/PATH/TO/gbif-data-access.html?print-pdf"
```

Points that are not optional:

- **`?print-pdf`** is what puts reveal.js into print layout. Without it the
  browser prints the current slide and nothing else.
- **`--no-pdf-header-footer`** suppresses Chrome's own page furniture. The page
  size comes from reveal's `@page` rule, which is the 1280 × 720 slide.
- **`--run-all-compositor-stages-before-draw`** makes the result deterministic.
  Without it the print occasionally fires mid-layout and yields a single blank
  page.
- **`--allow-file-access-from-files`** is needed only while the slides are being
  opened from disk rather than served.

Render the slides first: the PDF is printed *from* the HTML, so it can never be
newer than it.

---

## Notes on the template

The AOPK extension in [`_extensions/aopk/`](_extensions/aopk) is vendored from
the graphic manual and is not modified here. Three adjustments live in
[`custom.scss`](custom.scss) instead, each for a reason worth knowing if the
deck is ever reworked:

**The title is set at 58 px, not the manual's 74.2 px.** The manual's figure is
measured off a mockup carrying a three-word name. This deck's title is the
session title from the agenda — 63 characters — which wraps to three lines at
full size and runs into the AUTOR line anchored at 57.02 % of slide height. The
title's own anchor is computed from its size, so stepping the size down keeps
every measured position where the manual puts it.

**Print mode needs the layout re-asserted.** reveal.js's `?print-pdf` re-parents
each slide into a `.pdf-page` wrapper and then flattens it with
`section { margin: 0 !important; padding: 0 !important }`. The theme builds the
entire content column out of that padding and pins the slide to 720 px, so in
the printed deck both vanish: copy starts at the top of the page and runs under
the absolutely positioned heading, and a slide whose content is all absolutely
positioned — the title slide — collapses to a couple of hundred pixels, dragging
the footer bar and the dvojlist up to a third of the page. `custom.scss`
restores the padding and the height for the wrapped shape, with the specificity
and the `!important` needed to win.

**`auto-stretch` is off.** Quarto wraps a slide's lone image in `.r-stretch`,
whose reveal rule is `max-width: none; max-height: none`. That overrides both
the theme's height cap — measured from the safe area so a picture cannot reach
the footer bar — and any width set on the image. The theme already sizes
pictures; auto-stretch only fights it.

One more, unrelated to the manual: Quarto emits its own reveal defaults
*after* the theme block, including `.reveal ol { list-style-type: decimal }`.
The theme suppresses the native marker and draws its own counter, so an ordered
list would otherwise be numbered twice. `custom.scss` wins that back on
specificity.

---

## Screenshots

`images/` holds six captures of the rendered report in `docs/`, taken with
headless Chrome against the local build rather than the live site, so they match
the run the figures in the deck come from (GBIF download
[10.15468/dl.wzpexq](https://doi.org/10.15468/dl.wzpexq), rendered 9 September
2026). Re-cut them if the report's figures change.
