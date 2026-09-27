# Logo provenance and trademark status

Every file here is the vendor's own published brand asset, downloaded from the
URL given below on **21 September 2026**, used unmodified and at its own
aspect ratio. None has been recoloured, cropped or redrawn.

They are used **nominatively** — to identify the products the deck compares.
The deck states no affiliation with, and no endorsement by, any of them, and
the Sources slide carries a notice to that effect.

| File | Product | Downloaded from |
|---|---|---|
| `kobotoolbox.svg` | KoboToolbox | `kobotoolbox.org/assets/images/common/kobotoolbox_logo_default_for-light-bg.svg` |
| `odk.png` | ODK | `getodk.org/assets/zip/odk-brand-assets.zip` (the official brand-assets zip) |
| `epicollect5.png` | Epicollect5 | `five.epicollect.net/images/brand.png` |
| `qfield.svg` | QField | `github.com/opengisch/QField`, `images/icons/qfield_logo.svg` |
| `merginmaps.svg` | Mergin Maps | `merginmaps.com/docs/MM_logo_HORIZ_COLOR_VECTOR_no_padding.svg` |
| `survey123.png` | ArcGIS Survey123 | Google Play listing for `com.esri.survey123` (official app icon) |
| `fieldmaps.png` | ArcGIS Field Maps | Google Play listing for `com.esri.fieldmaps` (official app icon) |
| `fulcrum.svg` | Fulcrum | `fulcrumapp.com/wp-content/themes/fulcrum/images/fulcrum-logo.svg` |

## What each owner's policy actually says

This was checked before anything was downloaded, because a trademark is not
covered by a project's code licence: ODK is Apache-2.0 and KoboToolbox is
AGPL-3.0, and neither licence says anything about the logo.

**Explicit permission for presentations and course material, with attribution:**

- **ODK** — "you do not need permission to use ODK Marks" for books, articles,
  tutorials and courses. Attribution to `getodk.org` is required, and the deck
  carries it on the Sources slide. `getodk.org/legal/brand/`
- **QField** — "If you present a course on QField, in either an academic, free,
  or commercial context, you can use the logo and name in course material",
  conditional on explaining that QField is free and open-source software. The
  deck does, on the slide the logo appears on. `qfield.org/guidelines/`
- **QGIS** — same clause, for completeness; the QGIS logo is not currently used
  in the deck. `qgis.org/community/organisation/guidelines/`

**No permission granted; used nominatively:**

- **KoboToolbox** — Terms of Service reserve the marks and bar use "in printed
  brochures, press releases, or in any other form of advertising … without the
  prior written consent of Kobo". `kobotoolbox.org/terms/`
- **Epicollect5** — "Users are not granted rights or licenses to the trademarks
  of the CGPS … including without limitation the Epicollect5 name or logo".
- **Fulcrum** — written permission required for any use of the name or logo.
- **Esri (Survey123, Field Maps)** — third-party editorial use is not granted,
  and "images may not be used to advertise or promote products or companies
  other than Esri". `esri.com/en-us/legal/copyright-trademarks`
- **Mergin Maps** — publishes a brand-assets page with SVG and PNG downloads
  and states no terms of use at all. `merginmaps.com/brand-assets`

Those four reservations are anti-advertising and anti-endorsement clauses. A
deck that names and compares products, attributes each mark to its owner and
claims no endorsement is nominative use, not advertising, which is the basis
this deck uses them on. **That was the author's call, taken knowingly.** If it
has to be revisited, the logos are confined to four slides and one SCSS block
and can be removed without touching anything else.

## If a logo needs replacing

Keep the vendor's own file rather than tracing or recolouring one, keep its
aspect ratio, and add the row above. The sizing is by height only — see
`.logo` and `.logo-icon` in `spatial-data-collection.scss` — so a replacement
of any width drops in without a layout change.
