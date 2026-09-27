# Builds the one figure in this deck that is computed rather than captured:
# `images/kosovo-record-density.png`, the data-reality map on slide 3.
#
#   Rscript make-figures.R        (from this directory)
#
# It reads the repository's own pipeline outputs, one level up, so it shows
# exactly the extract the Kosovo figures on the slide are quoted from. Re-run it
# whenever the pipeline is re-run, or the map and the numbers beside it drift.
#
# LEGIBILITY. The figure sits in the 54 % image column of `.aopk-cols`, but a
# map of Kosovo is nearly square, so it is the slide's HEIGHT cap that sizes it,
# not the column width: it comes out roughly 370 px tall on the 1280 x 720
# canvas, about 0.3 of its pixel size. The text sizes are set for that. The
# first build used 17 pt and looked right in the PNG, but landed at 11 px on the
# slide – unreadable past the second row. Do not lower `base` without checking
# the rendered deck, not the PNG.
#
# Needs sf and ggplot2.

suppressPackageStartupMessages({
  library(sf)
  library(ggplot2)
})

root <- ".."
out  <- "images/kosovo-record-density.png"
dir.create("images", showWarnings = FALSE)

# A projected CRS for areas. UTM 34N covers the whole country.
crs_m <- 32634

muni <- st_read(file.path(root, "data/kosovo_municipalities.gpkg"), quiet = TRUE) |>
  st_transform(crs_m)
pa_poly <- st_read(file.path(root, "data/kosovo_protected_areas.gpkg"),
                   layer = "protected_area_polygons", quiet = TRUE) |>
  st_transform(crs_m)
pa_pt <- st_read(file.path(root, "data/kosovo_protected_areas.gpkg"),
                 layer = "protected_area_points", quiet = TRUE) |>
  st_transform(crs_m)

occ <- utils::read.csv(file.path(root, "data_exports/kosovo_overall_biodiversity.csv"),
                       colClasses = c(decimalLatitude = "numeric",
                                      decimalLongitude = "numeric"))[
  , c("decimalLatitude", "decimalLongitude")]
occ <- occ[stats::complete.cases(occ), ]
occ <- st_as_sf(occ, coords = c("decimalLongitude", "decimalLatitude"), crs = 4326) |>
  st_transform(crs_m)

n_total <- nrow(occ)

# Records per municipality, per km².
hits <- lengths(st_intersects(muni, occ))
muni$density <- hits / as.numeric(st_area(muni)) * 1e6

# The same class breaks as the choropleth in the published report, so that the
# slide and the website agree about which municipality is "red".
breaks <- c(0, 0.6, 0.9, 2.7, 4.7, Inf)
labels <- c("under 0.6", "0.6 – 0.9", "0.9 – 2.7", "2.7 – 4.7", "over 4.7")
muni$class <- cut(muni$density, breaks, labels = labels, include.lowest = TRUE,
                  right = FALSE)

# Sequential, one hue light to dark, ending on the AOPK dark green (#006B4D) so
# the map sits in the deck's palette. Lightness falls monotonically step to step.
ramp <- c("#EEF5E1", "#C7E29A", "#8CC83C", "#3C9A48", "#006B4D")

# Ligatina e Hencit / Radevës: the single wetland that holds 28 % of the record.
lig <- pa_poly[grepl("Ligatina", pa_poly$site_name), ]
lig_c <- st_coordinates(st_centroid(st_geometry(lig)))
lig_n <- lengths(st_intersects(lig, occ))
lig_share <- round(100 * sum(lig_n) / n_total)

cat(sprintf("Records: %d. Ligatina e Hencit: %d (%d %%).\n",
            n_total, sum(lig_n), lig_share))

bb <- st_bbox(muni)
# Empty ground added west of the country, in metres, to hold the label and
# the legend. Kosovo is about 150 km across. The label also uses the empty
# ground north of the western mountains, which the country leaves free.
margin_w <- 55000

base <- 23
p <- ggplot() +
  geom_sf(data = muni, aes(fill = class), colour = "white", linewidth = 0.35) +
  geom_sf(data = pa_poly, fill = NA, colour = "#1A1A1A", linewidth = 0.45) +
  geom_sf(data = pa_pt, shape = 21, size = 1.4, stroke = 0.45,
          fill = "white", colour = "#1A1A1A") +
  # The ring, and a leader line to a label parked in a margin added to the
  # west of the country (see `coord_sf` below), where it covers nothing.
  annotate("point", x = lig_c[1], y = lig_c[2], shape = 21, size = 12,
           stroke = 1.6, colour = "#C4272E", fill = NA) +
  annotate("segment",
           x = bb[["xmin"]] - 22000, y = bb[["ymax"]] - 21000,
           xend = lig_c[1] - 4200, yend = lig_c[2] + 4200,
           colour = "#C4272E", linewidth = 0.7) +
  annotate("label",
           x = bb[["xmin"]] - margin_w, y = bb[["ymax"]], hjust = 0, vjust = 1,
           label = sprintf(
             "Ligatina e Hencit:\n%d %% of all records",
             lig_share),
           size = base / .pt, lineheight = 0.95, linewidth = 0,
           fill = "white", colour = "#1A1A1A") +
  scale_fill_manual(values = ramp, drop = FALSE,
                    name = "GBIF records\nper km²") +
  coord_sf(datum = NA, expand = FALSE, clip = "off",
           xlim = c(bb[["xmin"]] - margin_w, bb[["xmax"]]),
           ylim = c(bb[["ymin"]], bb[["ymax"]])) +
  theme_void(base_size = base) +
  theme(
    # The legend sits at the foot of the same western margin as the label,
    # so neither of them covers a municipality.
    legend.position = "inside",
    legend.position.inside = c(0, 0),
    legend.justification = c(0, 0),
    legend.title = element_text(size = base, lineheight = 1, margin = margin(b = 6)),
    legend.text  = element_text(size = base * 0.93),
    legend.key.size = unit(1.25, "lines"),
    plot.margin = margin(4, 4, 4, 4)
  )

# 7.9 x 6.0 in at 200 dpi = 1580 x 1200 px. At about 370 px tall on the slide
# that is a scale of 0.31, and 23 pt at 200 dpi is 64 px – so the label and the
# legend land at about 18-20 px on the 1280 px canvas. What the outlines and
# circles mean is said in the slide's caption rather than drawn into the PNG,
# because text drawn into the picture shrinks with it.
ggsave(out, p, width = 7.9, height = 6.0, dpi = 200, bg = "white")
cat("Wrote", out, "\n")
