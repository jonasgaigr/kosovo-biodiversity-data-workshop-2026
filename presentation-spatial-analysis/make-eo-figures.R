# Builds the three Earth-observation figures in this deck:
#
#   images/eo-change-before.jpg   slide 5  Sentinel-2, 15 August 2016
#   images/eo-change-after.jpg    slide 5  Sentinel-2, 10 August 2025
#   images/fragmentation.png      slide 6  forest patches cut by roads
#
#   Rscript make-eo-figures.R        (from this directory)
#
# Unlike `make-figures.R`, this one downloads its inputs – all open, none
# needing an account – and keeps them in `_cache/` (git-ignored), so a second
# run is offline. Delete `_cache/` to fetch afresh.
#
#   Sentinel-2 L2A     Microsoft Planetary Computer STAC, anonymous SAS token
#   CLC+ Backbone      EEA image service, 2021 raster, 10 m, EPSG:3035
#   Roads              OpenStreetMap via the Overpass API (ODbL)
#   Park boundaries    ../data/kosovo_protected_areas.gpkg (EEA CDDA)
#
# THE CHANGE PAIR. A 5 x 3.125 km window (16:10, the slot's ratio) on the
# eastern edge of Bjeshkët e Nemuna National Park at the mouth of the Rugova
# gorge, directly above Pejë. It was chosen by looking, not by an index: a
# plain NDVI difference over the area is dominated by the 2025 drought on the
# farmland outside the park. What the pair shows inside the boundary is a new
# switchback road cut through the forest and fresh clearings at the edge.
# Both scenes are from the same satellite (S2A) on the same relative orbit
# (R136), five days apart in the calendar, so the view geometry and sun angle
# match. They get the SAME fixed linear stretch – never a per-image one, which
# would manufacture or hide change.
#
# Processing baseline 04.00 (January 2022) added an offset of -1000 to L2A
# digital numbers. The 2016 scene is on baseline 02.12, the 2025 one on 05.11;
# `offset_for()` reads the baseline from the item and corrects for it, or the
# 2025 scene comes out a tenth brighter for no reason on the ground.
#
# THE FRAGMENTATION MAP. Forest (CLC+ classes 2-4: needle-leaved, broadleaved
# deciduous and evergreen trees) around the Kaçanik gorge, where the R6
# motorway, the old main road and the railway share one gorge between the
# eastern tip of Sharri National Park and the Karadak forest. Motorways and
# main roads are burnt into the forest mask as barriers, patches are labelled
# with 4-neighbour connectivity (a diagonal pixel step does not connect), and
# each patch is coloured by its size. The patch count and effective mesh size
# are printed for the notes. Burning the roads in changes the mesh size by
# well under 1 %: at 10 m CLC+ already maps the motorway corridor as a gap in
# the forest, so the barrier is in the land cover itself. Do not quote a
# "with and without roads" difference from this map.
#
# LEGIBILITY. See the README, "Legibility". Both figures are drawn 1600 x 1000
# px. The change pair sits in `.aopk-pair`, where the height cap – not the
# column – sizes it: it lands about 430 px wide on the canvas, a scale of 0.27,
# so its labels are 64 px to reach 17 px. (At 50 px they measured 13 px on the
# rendered slide.) The fragmentation map in `.aopk-cols-wide` lands about
# 590 px wide, a scale of 0.37, so 48-50 px text reaches 18 px.
#
# Needs sf, terra, jsonlite, curl and ggplot2.

suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(jsonlite)
  library(ggplot2)
})

root  <- ".."
cache <- "_cache"
dir.create(cache, showWarnings = FALSE)
dir.create("images", showWarnings = FALSE)

pa <- st_read(file.path(root, "data/kosovo_protected_areas.gpkg"),
              layer = "protected_area_polygons", quiet = TRUE)

# Draw a 1600 x 1000 px figure at 200 dpi. `pt(px)` converts an on-image
# pixel size to the ggplot text size that produces it.
fig_w <- 8; fig_h <- 5; dpi <- 200
pt <- function(px) px / dpi * 72 / .pt

# A terra extent as an sf polygon. `c(xmin = e$xmin)` would name the element
# "xmin.xmin", which st_bbox() does not recognise – hence the unname.
ext_sfc <- function(e, crs) {
  v <- as.vector(e)
  st_as_sfc(st_bbox(c(xmin = v[[1]], ymin = v[[3]], xmax = v[[2]], ymax = v[[4]]),
                    crs = st_crs(crs)))
}

# ---------------------------------------------------------------------------
# 1. Sentinel-2 change pair
# ---------------------------------------------------------------------------

stac  <- "https://planetarycomputer.microsoft.com/api/stac/v1"
scenes <- c(
  before = "S2A_MSIL2A_20160815T093042_R136_T34TDN_20210212T143547",
  after  = "S2A_MSIL2A_20250810T093051_R136_T34TDN_20250810T125901"
)

# The window, in UTM 34N (the tile's own CRS, so no pixel is resampled twice).
win <- ext(437300, 442300, 4723200, 4726325)

offset_for <- function(item) {
  if (as.numeric(item$properties$`s2:processing_baseline`) >= 4) -1000 else 0
}

s2_window <- function(id) {
  f <- file.path(cache, paste0(id, ".tif"))
  if (file.exists(f)) return(rast(f))
  token <- fromJSON(paste0("https://planetarycomputer.microsoft.com/api/sas/v1/",
                           "token/sentinel-2-l2a"))$token
  item  <- fromJSON(sprintf("%s/collections/sentinel-2-l2a/items/%s", stac, id),
                    simplifyVector = FALSE)
  bands <- lapply(c("B04", "B03", "B02"), function(b) {
    r <- rast(paste0("/vsicurl/", item$assets[[b]]$href, "?", token))
    (crop(r, win, snap = "out") + offset_for(item)) / 10000
  })
  s <- rast(bands)
  names(s) <- c("red", "green", "blue")
  writeRaster(s, f, overwrite = TRUE)
  s
}

# Park boundary, and the part of it inside the window.
np_nem <- st_transform(pa[grepl("Nemuna", pa$site_name), ], 32634)
win_sf <- ext_sfc(win, 32634)
edge   <- st_intersection(st_boundary(st_geometry(np_nem)), win_sf)

# One stretch for both: reflectance 0-0.16 to 0-1, gamma 0.8. Upsampled to the
# output size bilinearly so the 10 m pixels do not show as blocks.
stretch <- function(s) {
  tmpl <- rast(win, ncols = 1600, nrows = 1000, crs = crs(s))
  s <- resample(s, tmpl, method = "bilinear")
  a <- as.array(s)
  pmin(pmax(a / 0.16, 0), 1)^0.8
}

draw_scene <- function(key, out) {
  img <- stretch(s2_window(scenes[[key]]))
  sb_x <- win$xmin + 200; sb_y <- win$ymin + 220      # scale bar, 1 km
  p <- ggplot() +
    annotation_raster(img, win$xmin, win$xmax, win$ymin, win$ymax,
                      interpolate = TRUE) +
    geom_sf(data = edge, colour = "#FFE14D", linewidth = 1.1) +
    annotate("rect", xmin = sb_x - 120, xmax = sb_x + 1120,
             ymin = sb_y - 120, ymax = sb_y + 400, fill = "white", alpha = 0.85) +
    annotate("segment", x = sb_x, xend = sb_x + 1000, y = sb_y, yend = sb_y,
             linewidth = 2.2, colour = "#1A1A1A") +
    annotate("text", x = sb_x + 500, y = sb_y + 70, label = "1 km",
             vjust = 0, size = pt(64), colour = "#1A1A1A") +
    annotate("label", x = win$xmin + 150, y = win$ymax - 150,
             hjust = 0, vjust = 1, label = "National park",
             size = pt(64), fill = "white", alpha = 0.85,
             linewidth = 0, colour = "#1A1A1A") +
    annotate("label", x = win$xmax - 150, y = win$ymin + 150,
             hjust = 1, vjust = 0, label = "Pejë",
             size = pt(64), fill = "white", alpha = 0.85,
             linewidth = 0, colour = "#1A1A1A") +
    coord_sf(crs = 32634, datum = NA, expand = FALSE,
             xlim = c(win$xmin, win$xmax), ylim = c(win$ymin, win$ymax)) +
    theme_void() +
    theme(plot.margin = margin(0, 0, 0, 0))
  ggsave(out, p, width = fig_w, height = fig_h, dpi = dpi, bg = "white",
         quality = 92)
  cat("Wrote", out, "\n")
}

draw_scene("before", "images/eo-change-before.jpg")
draw_scene("after",  "images/eo-change-after.jpg")

# ---------------------------------------------------------------------------
# 2. Fragmentation
# ---------------------------------------------------------------------------

# 30 x 18.75 km (16:10) in LAEA Europe, the CLC+ grid, snapped to 10 m.
frag <- ext(5232000, 5262000, 2181000, 2199750)

clcplus <- function() {
  f <- file.path(cache, "clcplus_2021_kacanik.tif")
  if (file.exists(f)) return(rast(f))
  svc  <- paste0("https://image.discomap.eea.europa.eu/arcgis/rest/services/",
                 "CLC_plus/CLMS_CLCplus_RASTER_2021_010m_eu/ImageServer/exportImage")
  tile <- 15000                                     # m; the service caps at 4100 px
  parts <- list()
  for (x0 in seq(frag$xmin, frag$xmax - 1, by = tile))
    for (y0 in seq(frag$ymin, frag$ymax - 1, by = tile)) {
      x1 <- min(x0 + tile, frag$xmax); y1 <- min(y0 + tile, frag$ymax)
      tf <- tempfile(fileext = ".tif")
      download.file(sprintf(paste0(
        "%s?bbox=%s&bboxSR=3035&imageSR=3035&size=%d,%d&format=tiff",
        "&pixelType=U8&interpolation=RSP_NearestNeighbor&f=image"),
        svc, paste(c(x0, y0, x1, y1), collapse = ","),
        round((x1 - x0) / 10), round((y1 - y0) / 10)), tf, mode = "wb", quiet = TRUE)
      r <- rast(tf); crs(r) <- "EPSG:3035"; ext(r) <- ext(x0, x1, y0, y1)
      parts[[length(parts) + 1]] <- r
    }
  m <- if (length(parts) == 1) parts[[1]] else do.call(merge, parts)
  writeRaster(m, f, overwrite = TRUE, datatype = "INT1U")
  rast(f)
}

roads <- function() {
  f <- file.path(cache, "osm_roads_kacanik.gpkg")
  if (file.exists(f)) return(st_read(f, quiet = TRUE))
  bb <- st_bbox(st_transform(ext_sfc(frag, 3035), 4326))
  q <- sprintf(paste0('[out:json][timeout:180];way["highway"~"^(motorway|trunk|primary)$"]',
                      '(%f,%f,%f,%f);out tags geom;'), bb$ymin, bb$xmin, bb$ymax, bb$xmax)
  tf <- tempfile(fileext = ".json")
  h <- curl::new_handle(useragent = "kosovo-workshop-maps/1.0")
  # Overpass wants a url-encoded `data=` body; a multipart form gets a 400.
  curl::handle_setopt(h, postfields = paste0("data=", curl::curl_escape(q)))
  curl::curl_download("https://overpass-api.de/api/interpreter", tf, handle = h)
  el <- fromJSON(tf, simplifyVector = FALSE)$elements
  tag <- function(e, k) if (is.null(e$tags[[k]])) NA_character_ else e$tags[[k]]
  rd <- st_sf(
    highway = vapply(el, tag, "", k = "highway"),
    ref     = vapply(el, tag, "", k = "ref"),
    geometry = st_sfc(lapply(el, function(e) st_linestring(
      do.call(rbind, lapply(e$geometry, function(p) c(p$lon, p$lat))))), crs = 4326))
  st_write(rd, f, quiet = TRUE)
  rd
}

lc <- crop(clcplus(), frag)
rd <- st_transform(roads(), 3035)
rd$class <- ifelse(rd$highway == "motorway", "Motorway", "Main road")

forest <- lc %in% c(2, 3, 4)

# Roads as barriers: a motorway corridor 30 m wide, a main road 12 m.
barrier <- rasterize(vect(st_buffer(rd, ifelse(rd$class == "Motorway", 15, 6))),
                     forest, touches = TRUE)
cut <- forest
cut[!is.na(barrier)] <- FALSE

# Patch areas in hectares. `patches()` then `zonal()` on a ones layer is much
# faster than `freq()` on a raster with tens of thousands of IDs.
patch_area <- function(m) {
  p <- patches(classify(m, cbind(0, NA)), directions = 4, zeroAsNA = TRUE)
  z <- zonal(!is.na(p), p, "sum")
  list(id = p, ha = setNames(z[[2]] * 0.01, z[[1]]))
}
meff <- function(ha) sum((ha / 100)^2) / (as.numeric(ncell(forest)) * 1e-4)  # km²

after <- patch_area(cut)
cat(sprintf(paste0("Forest %.0f %% of %.0f km², in %d patches; %d under 10 ha.\n",
                   "Largest %.0f km². Effective mesh size %.0f km².\n"),
            100 * global(forest, "mean")[[1]], ncell(forest) * 1e-4,
            length(after$ha), sum(after$ha < 10), max(after$ha) / 100,
            meff(after$ha)))

# What the map has to show. At this extent the forest falls into two large
# patches – the Sharri side and the Karadak side – and thousands of small
# ones, and the line between the two large ones is the gorge carrying the R6,
# the old main road and the railway. A size-class ramp hides that, because
# both large patches land in the same top class and come out the same green.
# So the two largest patches each get their own colour and a direct label
# with their area, and everything else is one pale "smaller patches" tone.
big <- as.numeric(names(sort(after$ha, decreasing = TRUE))[1:2])
cen <- lapply(big, function(i) colMeans(crds(as.points(after$id == i &
                                                       !is.na(after$id)))))
names(cen) <- big
cat(sprintf("Two largest patches: %.0f and %.0f km².
",
            after$ha[as.character(big[1])] / 100, after$ha[as.character(big[2])] / 100))
# West first, whichever is larger.
big <- big[order(sapply(cen, `[`, 1))]

# `others` would also turn the non-forest NA cells into class 3 – mask them back.
cls <- mask(classify(after$id, rbind(cbind(big, 1:2)), others = 3), after$id)
# Aggregate to 20 m for drawing – 1500 px across on a 1600 px figure.
cls <- aggregate(cls, 2, "modal", na.rm = TRUE)
df  <- as.data.frame(cls, xy = TRUE, na.rm = TRUE)
names(df)[3] <- "k"
df$k <- factor(df$k, levels = 1:3)

# Dark AOPK green for the west, a lighter yellow-green for the east, pale for
# the rest: three steps of lightness, so the split survives greyscale and
# colour-vision deficiency, not only hue.
fills <- c("1" = "#006B4D", "2" = "#7FAE3A", "3" = "#B9D48C")

frag_sf <- ext_sfc(frag, 3035)
sharri <- st_intersection(st_transform(pa[grepl("Sharri", pa$site_name), ], 3035),
                          frag_sf)
rd_in  <- st_intersection(rd, frag_sf)

# Direct labels, placed by hand and checked: the park label must fall inside
# the park (a first draft put it across the border in North Macedonia).
lab_r6 <- c(5249500, 2197300)
lab_np <- c(5237300, 2192600)
lab_w  <- c(5244600, 2187000)
lab_e  <- c(5257000, 2191500)
stopifnot(lengths(st_intersects(st_sfc(st_point(lab_np), crs = 3035), sharri)) > 0)
area_lab <- function(i) sprintf("%.0f km²", after$ha[as.character(i)] / 100)

sb_x <- frag$xmax - 6800; sb_y <- frag$ymin + 900      # scale bar, 5 km

lbl <- function(xy, text, colour, ...)
  annotate("label", x = xy[1], y = xy[2], label = text, size = pt(50),
           fill = "white", linewidth = 0, colour = colour, fontface = "bold",
           lineheight = 0.9, ...)

p <- ggplot() +
  geom_raster(data = df, aes(x, y, fill = k)) +
  geom_sf(data = sharri, fill = NA, colour = "#6A1B9A", linewidth = 0.9,
          linetype = "22") +
  geom_sf(data = rd_in[rd_in$class == "Main road", ], colour = "#1A1A1A",
          linewidth = 0.55) +
  geom_sf(data = rd_in[rd_in$class == "Motorway", ], colour = "white",
          linewidth = 2.6) +
  geom_sf(data = rd_in[rd_in$class == "Motorway", ], colour = "#C4272E",
          linewidth = 1.6) +
  lbl(lab_r6, "R6 motorway", "#C4272E", hjust = 0) +
  lbl(lab_np, "Sharri
National Park", "#6A1B9A") +
  lbl(lab_w, area_lab(big[1]), fills[["1"]]) +
  lbl(lab_e, area_lab(big[2]), "#4E7A1C") +
  annotate("rect", xmin = sb_x - 500, xmax = sb_x + 5500,
           ymin = sb_y - 500, ymax = sb_y + 1700, fill = "white") +
  annotate("segment", x = sb_x, xend = sb_x + 5000, y = sb_y, yend = sb_y,
           linewidth = 2.2, colour = "#1A1A1A") +
  annotate("text", x = sb_x + 2500, y = sb_y + 350, label = "5 km",
           vjust = 0, size = pt(48), colour = "#1A1A1A") +
  scale_fill_manual(values = fills, guide = "none") +
  coord_sf(crs = 3035, datum = NA, expand = FALSE,
           xlim = c(frag$xmin, frag$xmax), ylim = c(frag$ymin, frag$ymax)) +
  theme_void() +
  theme(
    panel.background = element_rect(fill = "#F3EFE0", colour = NA),
    plot.margin = margin(0, 0, 0, 0)
  )

ggsave("images/fragmentation.png", p, width = fig_w, height = fig_h, dpi = dpi,
       bg = "white")
cat("Wrote images/fragmentation.png\n")
