// =============================================================================
// The site report's colours
// =============================================================================
//
// The website is the reference. Every colour below does the same job in this
// PDF that it does on the page, and carries the value `custom.scss` gives it
// there, so that a site report and the national report it was generated
// alongside read as one publication rather than two.
//
// The values are restated here rather than shared because nothing can share
// them: Typst cannot read SCSS, and a `_brand.yml` — Quarto's own answer to
// this — would restyle the website as well as the report, which is the one
// thing this file must not do. The duplication is guarded instead, by the
// colour checks in `run_test_site_report.R`, which read `custom.scss`,
// `R/site_report.R` and this file and fail if a value drifts out of step.
//
// The green is split in two, and the split is the page's: GBIF green carries
// 3.35:1 on white, which clears the 3:1 asked of rules and borders but not the
// 4.5:1 that body-sized text needs. Rules therefore wear `gbif-green`, and
// text that has to be green wears `gbif-ink` — the same hue stepped down in
// OKLCH lightness until it clears the threshold at 4.77:1. See the README
// section "Following GBIF's cartography".

#let gbif-black  = rgb("#231F20")  // $body-color  — body text, 16.3:1 on white
#let gbif-green  = rgb("#509E2F")  // $primary     — rules and borders only
#let gbif-ink    = rgb("#358305")  // $primary-ink — brand green at text size
#let gbif-azure  = rgb("#175CA1")  // $secondary   — the citation block's edge
#let rule-grey   = rgb("#dbe3e7")  // every bordered surface on the page
#let caption-ink = rgb("#666666")  // captions, meta lines, figure notes
#let box-ground  = rgb("#f7f9fa")  // the ground under `.citation-box`
#let code-ink    = rgb("#296604")  // `code`, as the page renders it: Quarto
                                   // shades $link-color by 22 per cent

// --- Text ---------------------------------------------------------------------
//
// Typst sets body text in pure black. The page sets it in GBIF black, which is
// the only ink it uses for reading text, so the report does too.

#set text(fill: gbif-black)
#show link: set text(fill: gbif-ink)

// Every piece of code in this report is a file name, a column name or a
// command — never a highlighted listing — so one ink covers all of it, and it
// is the ink the page gives `code`.
#show raw: set text(fill: code-ink)

// --- Headings -----------------------------------------------------------------
//
// `h2 { border-bottom: 2px solid rgba(80, 158, 47, 0.25); padding-bottom: 0.3rem }`
// is the page's one piece of standing brand furniture, and the section breaks
// it draws are exactly the ones this report has. Level 1 is the site's name
// and takes no rule, as the page's title takes none.

#show heading.where(level: 2): it => block(
  width: 100%,
  above: 1.6em,
  below: 0.75em,
  inset: (bottom: 0.3em),
  stroke: (bottom: 1pt + gbif-green.transparentize(75%)),
  it,
)

// --- Tables -------------------------------------------------------------------
//
// Pandoc emits one `table.hline()` beneath the header row of every table and
// Typst draws it in black, which is heavier than anything on the page. Bordered
// surfaces there are drawn in `rule-grey` — the cards, the map frames, and
// Bootstrap's own table rules, which sit within a hair of the same value.

#set table.hline(stroke: 0.8pt + rule-grey)

// --- Captions -----------------------------------------------------------------
//
// The page sets every table caption in `caption-ink`, and the report's live
// captions are the ones drawn inside the maps, where `site_theme()` sets them
// in the same grey from R. This rule covers the other kind: Quarto keeps a
// table caption in Typst output only where the table carries a `{#tbl-...}`
// label, and the one this report writes is unlabelled and therefore dropped.
// The rule is what keeps such a caption in step the day one is labelled.

#show figure.caption: set text(fill: caption-ink)

// --- The citation block -------------------------------------------------------
//
// `.citation-box`: a pale ground behind the text and an azure edge down the
// left of it. Azure rather than green, because a citation is not a finding —
// it is the one place the page uses its secondary colour.

#show quote.where(block: true): it => block(
  width: 100%,
  fill: box-ground,
  stroke: (left: 3pt + gbif-azure),
  inset: (x: 10pt, y: 8pt),
  it.body,
)

// --- Pieces the template asks for by name -------------------------------------

// `.swatch`: a category's colour beside its label, never instead of it. The
// colour comes from `map_palette` in R/functions.R, the same list the page
// draws its own swatches from, so a Red List category is one colour in both.
// The hairline is what keeps the palest categories visible on white.
#let swatch(colour) = box(
  width: 0.62em,
  height: 0.62em,
  radius: 1pt,
  fill: colour,
  stroke: 0.4pt + rgb(11, 11, 11, 46),
)

// `.keyfigure .value`: the page sets its key figures in the brand green, at a
// size where 3.35:1 is enough. In a printed table they are body-sized, so they
// take the ink step instead — the same hue, and readable at 10pt.
#let keyfigure(value) = text(fill: gbif-ink, weight: 600, value)
