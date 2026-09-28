# Builds the species distribution model on the Eros blue slide:
#
#   images/sdm-polyommatus-eros.png   the prediction for Kosovo, with the atlas
#                                     squares and the ground-truth plots
#   data/sdm-ground-truth-plots.csv   the field sample, one row per plot
#
#   Rscript make-sdm-figure.R        (from this directory)
#
# Like `make-eo-figures.R`, it downloads open inputs into `_cache/`
# (git-ignored), so a second run is offline. Delete `_cache/` to fetch afresh.
#
#   Records     GBIF occurrence download, key in data/sdm-gbif-download-key.txt
#               (Polyommatus eros, 18.5-24.5 E, 39.5-44.5 N) – re-used, never
#               re-requested, so the DOI stays the one cited in the deck
#   Kosovo      ../data_exports/kosovo_overall_biodiversity.csv (the pipeline's
#               quality-controlled extract)
#   Climate     WorldClim 2.1, 30 arc-seconds, bio10 and bio12, read as a
#               window from the geodata server's tile 19 – no full download
#   Terrain     WorldClim 2.1 elevation on the same grid, turned into slope
#   Land cover  CORINE Land Cover 2018 vector, EEA map service, classes 321
#               natural grassland, 322 moors and heath, 333 sparse vegetation
#
# WHY THE MODEL IS CALIBRATED OUTSIDE KOSOVO. Kosovo's published record for the
# species is 25 records in 9 places, every one a 10 km UTM atlas square (the
# 7,071 m uncertainty is half a square's diagonal), 24 of them from 1987-2007.
# A 1 km model cannot learn from a 10 km square: the square's centre is as
# likely to sit in a valley as on the ridge the butterfly flies on. So the
# model learns from the neighbours' precise records – the same ranges (Šar,
# Korab, Prokletije, Pirin) run across the borders – and Kosovo's atlas
# squares are kept back as an independent test. That is the interoperability
# argument of the next section, in miniature: Darwin Core records from five
# countries merge without a telephone call.
#
# TAXONOMY – THE TRAP THIS CASE STUDY FELL INTO FIRST. The GBIF backbone
# (checked 28 September 2026) files two other names under P. eros:
#   Aricia anteros, the Blue Argus – a different genus – as a heterotypic
#     synonym. It is 545 of the 980 records the download returns, and 152 of
#     the 171 that are precise to 1 km outside Kosovo. A model fitted to "all
#     P. eros records" is mostly a model of the wrong butterfly, and nothing
#     in the output says so.
#   P. eroides, a Habitats Directive Annex II/IV species, and "P. eros
#     eroides" – 123 records.
# So the records are selected on `verbatimScientificName` – what the recorder
# wrote – and only P. eros itself is kept. The same backbone mapping puts 22
# Kosovo Blue Argus records under the P. eros key in the pipeline export,
# which is why the Kosovo squares are selected on `scientificName`, not on
# `speciesKey`.
#
# PRECISION. Records within 1 km, plus records that state no uncertainty but
# give both coordinates to at least two decimals (about ±500 m). That leaves a
# few dozen records, in the region of 25-30 one-kilometre cells.
#
# THE MODEL. With that few presences, one model with four predictors and
# their squares would be over-fitted. The standard answer for rare species is
# an ensemble of small models (Breiner et al. 2015): every pair of predictors
# gets its own presence-background logistic regression (GLM, linear and
# quadratic terms, background down-weighted to the presences' total weight,
# Barbet-Massin et al. 2012), and the six are averaged, each weighted by its
# Somers' D (2 AUC - 1). Four predictors, chosen for the butterfly rather than
# by a search: summer warmth (bio10), annual precipitation (bio12), open
# alpine habitat share from CORINE, and slope. Background: 10,000 cells within
# 100 km of a presence, or in Kosovo. The output is RELATIVE suitability, not
# a probability of presence – say so.
#
# VALIDATION, in three layers, and only two of them are done:
#   1. Spatial block cross-validation (0.5 degree blocks, 5 folds, 5 repeats):
#      each cell is predicted by an ensemble that never saw its block, and AUC
#      and the continuous Boyce index are computed on those pooled
#      predictions.
#   2. Kosovo's atlas: the 9 squares with the species against the 66 other
#      squares where the same atlas recorded butterflies. Those 66 are not
#      absences – nobody reported looking for this species there.
#   3. Ground-truthing: 30 plots drawn from the prediction, for one flight
#      season. NOT YET VISITED. The slide says so, and so must the talk.
#
# LEGIBILITY. See the README, "Legibility". The figure is drawn 1600 x 1000 px
# for the 54 % column, where it lands about 590 px wide, a scale of 0.37, so
# 46 px text reaches 17 px on the slide.
#
# Needs sf, terra, jsonlite, curl and ggplot2, and rgbif only if the GBIF
# archive is not yet in `_cache/` (fetching an existing download needs no
# account).

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
set.seed(2026)

win <- ext(18.5, 24.5, 39.5, 44.5)     # the download polygon, lon/lat

kosovo <- st_read(file.path(root, "data/kosovo_boundary.gpkg"), quiet = TRUE)
pa <- st_read(file.path(root, "data/kosovo_protected_areas.gpkg"),
              layer = "protected_area_polygons", quiet = TRUE)
parks <- pa[grepl("Sharri|Nemuna", pa$site_name), ]

# ---------------------------------------------------------------------------
# 1. Existing occurrence
# ---------------------------------------------------------------------------

key <- readLines("data/sdm-gbif-download-key.txt", warn = FALSE)[1]
zip <- file.path(cache, paste0(key, ".zip"))
if (!file.exists(zip)) rgbif::occ_download_get(key, path = cache)
occ <- read.delim(unz(zip, paste0(key, ".csv")), quote = "", na.strings = "",
                  encoding = "UTF-8", stringsAsFactors = FALSE)

vn <- occ$verbatimScientificName
is_anteros <- grepl("^Aricia anteros", vn)
is_eroides <- grepl("eroides", vn, ignore.case = TRUE)
is_eros    <- grepl("^Polyommatus eros( [(]Ochsenheimer.*)?$", vn)
two_dp <- function(v) abs(v * 10 - round(v * 10)) > 1e-6
precise <- ifelse(is.na(occ$coordinateUncertaintyInMeters),
                  two_dp(occ$decimalLatitude) & two_dp(occ$decimalLongitude),
                  occ$coordinateUncertaintyInMeters <= 1000)
cal <- occ[is_eros & precise & occ$countryCode != "XK" &
             occ$basisOfRecord != "FOSSIL_SPECIMEN", ]
cat(sprintf(paste0("GBIF download %s: %d records under the P. eros key – ",
                   "%d Aricia anteros, %d eroides, %d P. eros, %d other names ",
                   "(BOLD bins). %d P. eros records outside Kosovo are precise ",
                   "enough to calibrate on.\n"),
            key, nrow(occ), sum(is_anteros), sum(is_eroides), sum(is_eros),
            sum(!(is_anteros | is_eroides | is_eros)), nrow(cal)))
print(table(cal$countryCode))

# Kosovo: the atlas squares. Every HabiProt record sits on the centre of a
# 10 km UTM 34N square; the stopifnot proves it before the squares are drawn.
ks <- read.csv(file.path(root, "data_exports/kosovo_overall_biodiversity.csv"),
               encoding = "UTF-8", stringsAsFactors = FALSE)
atlas <- ks[ks$order == "Lepidoptera" & ks$institutionCode == "HabiProt", ]
atlas$eros <- grepl("^Polyommatus eros [(]", atlas$scientificName)
sq <- aggregate(cbind(eros = eros, year = ifelse(eros, year, NA)) ~
                  decimalLongitude + decimalLatitude,
                data = atlas, FUN = function(v) max(v, na.rm = TRUE),
                na.action = na.pass)
sq$year[!is.finite(sq$year)] <- NA
cen <- st_transform(st_as_sf(sq, coords = c("decimalLongitude", "decimalLatitude"),
                             crs = 4326), 32634)
xy <- st_coordinates(cen)
stopifnot(all(abs(xy %% 10000 - 5000) < 1))
sq_poly <- st_sf(eros = sq$eros == 1, year = sq$year,
                 geometry = st_sfc(lapply(seq_len(nrow(xy)), function(i)
                   st_polygon(list(cbind(xy[i, 1] + c(-5, 5, 5, -5, -5) * 1000,
                                         xy[i, 2] + c(-5, -5, 5, 5, -5) * 1000)))),
                   crs = 32634))
cat(sprintf("Kosovo: %d P. eros records in %d atlas squares (%d confirmed since 2007); %d other butterfly squares.\n",
            sum(atlas$eros), sum(sq_poly$eros), sum(sq_poly$year > 2007, na.rm = TRUE),
            sum(!sq_poly$eros)))

# ---------------------------------------------------------------------------
# 2. Predictors on the WorldClim 30 arc-second grid
# ---------------------------------------------------------------------------

wc_window <- function(var) {
  f <- file.path(cache, sprintf("wc2.1_30s_%s_balkans.tif", var))
  if (file.exists(f)) return(rast(f))
  r <- rast(paste0("/vsicurl/https://geodata.ucdavis.edu/climate/worldclim/",
                   "2_1/tiles/tile/tile_19_wc2.1_30s_", var, ".tif"))
  writeRaster(crop(r, win), f, overwrite = TRUE)
  rast(f)
}
bio  <- wc_window("bio")
elev <- wc_window("elev")

# CORINE 2018 open habitat, only the three classes, as polygons. The service
# returns 1,000 features a request, so it is paged; a 50 m generalisation keeps
# the transfer small and is invisible at a 1 km cell.
clc_open <- function() {
  f <- file.path(cache, "clc2018_open_balkans.gpkg")
  if (file.exists(f)) return(vect(f))
  q <- paste0("https://image.discomap.eea.europa.eu/arcgis/rest/services/",
              "Corine/CLC2018_LAEA/MapServer/0/query")
  parts <- list(); off <- 0
  repeat {
    args <- c(where = "Code_18 IN ('321','322','333')",
              geometry = paste(as.vector(win)[c(1, 3, 2, 4)], collapse = ","),
              geometryType = "esriGeometryEnvelope", inSR = "4326",
              spatialRel = "esriSpatialRelIntersects", outFields = "Code_18",
              outSR = "4326", maxAllowableOffset = "0.0005",
              orderByFields = "OBJECTID", resultOffset = off,
              resultRecordCount = "1000", f = "geojson")
    tf <- tempfile(fileext = ".geojson")
    curl::curl_download(paste0(q, "?", paste0(names(args), "=",
                                              curl::curl_escape(args), collapse = "&")), tf)
    v <- st_read(tf, quiet = TRUE)
    if (!nrow(v)) break
    parts[[length(parts) + 1]] <- v[, "Code_18"]
    off <- off + nrow(v)
    if (nrow(v) < 1000) break
  }
  x <- do.call(rbind, parts)
  st_write(x, f, quiet = TRUE)
  cat("CORINE: fetched", nrow(x), "polygons\n")
  vect(f)
}

# Share of each 30" cell that is open habitat: rasterise on a grid ten times
# finer (about 90 m), then average back.
grid <- bio[[1]]
fine <- disagg(rast(grid), 10)
open <- rasterize(clc_open(), fine, background = 0, touches = FALSE)
open <- aggregate(open, 10, "mean")
open <- mask(open, grid)

preds <- c(bio[["bio_10"]], bio[["bio_12"]], open,
           terrain(elev, "slope", unit = "degrees"))
names(preds) <- c("bio10", "bio12", "open", "slope")

# ---------------------------------------------------------------------------
# 3. Presences, background, model
# ---------------------------------------------------------------------------

pres_cell <- unique(na.omit(cellFromXY(grid, cbind(cal$decimalLongitude,
                                                   cal$decimalLatitude))))
pres_cell <- pres_cell[complete.cases(preds[pres_cell])]

pres_sf <- st_as_sf(as.data.frame(xyFromCell(grid, pres_cell)),
                    coords = c("x", "y"), crs = 4326)
area_m  <- st_union(st_buffer(pres_sf, 100000), st_geometry(kosovo))
cand    <- cells(mask(grid, vect(area_m)))
cand    <- setdiff(cand[complete.cases(preds[cand])], pres_cell)
bg_cell <- sample(cand, min(10000, length(cand)))

dat <- rbind(data.frame(pa = 1, preds[pres_cell]),
             data.frame(pa = 0, preds[bg_cell]))
xy_all <- xyFromCell(grid, c(pres_cell, bg_cell))
cat(sprintf("Model: %d presence cells, %d background cells.\n",
            length(pres_cell), length(bg_cell)))
print(round(cor(dat[dat$pa == 0, -1]), 2))

# The ensemble of small models. `.w` travels inside the data frame because
# glm() looks its weights up there, not in the calling function.
vars  <- names(preds)
pairs <- combn(vars, 2, simplify = FALSE)
esm <- function(d) {
  d$.w <- ifelse(d$pa == 1, 1, sum(d$pa == 1) / sum(d$pa == 0))
  ms <- lapply(pairs, function(v) suppressWarnings(glm(
    as.formula(sprintf("pa ~ %1$s + I(%1$s^2) + %2$s + I(%2$s^2)", v[1], v[2])),
    binomial, d, weights = .w)))
  sd <- sapply(ms, function(m) {
    p <- fitted(m); max(0, 2 * auc(p[d$pa == 1], p[d$pa == 0]) - 1)
  })
  list(ms = ms, wt = sd / sum(sd))
}
esm_predict <- function(e, newdata)
  Reduce(`+`, Map(function(m, w) w * predict(m, newdata, type = "response"),
                  e$ms, e$wt))

auc <- function(p, a) {
  r <- rank(c(p, a))
  (sum(r[seq_along(p)]) - length(p) * (length(p) + 1) / 2) / (length(p) * length(a))
}
# Continuous Boyce index (Hirzel et al. 2006): predicted-to-expected ratio of
# presences in a moving window along the suitability axis, Spearman-correlated
# with suitability. 1 = the model ranks exactly as the presences say.
boyce <- function(p, a) {
  lo <- min(a, p); hi <- max(a, p); w <- (hi - lo) / 10
  v  <- seq(lo, hi - w, length.out = 100)
  f  <- sapply(v, function(s) mean(p >= s & p <= s + w) / mean(a >= s & a <= s + w))
  ok <- is.finite(f)
  suppressWarnings(cor(f[ok], (v + w / 2)[ok], method = "spearman"))
}

block <- paste(floor(xy_all[, 1] / 0.5), floor(xy_all[, 2] / 0.5))
ub <- unique(block)
cv <- t(sapply(1:5, function(r) {
  fold <- setNames(sample(rep_len(1:5, length(ub))), ub)[block]
  held <- numeric(nrow(dat))
  for (k in 1:5) held[fold == k] <- esm_predict(esm(dat[fold != k, ]), dat[fold == k, ])
  y <- dat$pa
  c(auc = auc(held[y == 1], held[y == 0]), boyce = boyce(held[y == 1], held[y == 0]))
}))
print(round(cv, 2))
cat(sprintf("Spatial CV, 5 repeats: AUC %.2f (%.2f-%.2f), Boyce %.2f (%.2f-%.2f).\n",
            mean(cv[, "auc"]), min(cv[, "auc"]), max(cv[, "auc"]),
            mean(cv[, "boyce"]), min(cv[, "boyce"]), max(cv[, "boyce"])))

model <- esm(dat)
print(data.frame(pair = sapply(pairs, paste, collapse = " + "),
                 weight = round(model$wt, 2)))
suit <- Reduce(`+`, Map(function(m, w) w * predict(preds, m, type = "response",
                                                   na.rm = TRUE),
                        model$ms, model$wt))

p_train <- esm_predict(model, dat[dat$pa == 1, ])
thr  <- quantile(p_train, 0.10)    # 10th-percentile training presence
high <- quantile(p_train, 0.50)    # median presence: "most suitable"
cat(sprintf("Thresholds: suitable >= %.3f (P10), most suitable >= %.3f.\n", thr, high))

# ---------------------------------------------------------------------------
# 4. Kosovo: the independent check, and the area predicted
# ---------------------------------------------------------------------------

kv   <- vect(kosovo)
suit_k <- mask(crop(suit, kv, snap = "out"), kv)
km2  <- mask(cellSize(suit_k, unit = "km"), suit_k)
ok_k <- suit_k >= thr
area_suit <- global(km2 * ok_k, "sum", na.rm = TRUE)[[1]]
area_high <- global(km2 * (suit_k >= high), "sum", na.rm = TRUE)[[1]]
in_parks  <- global(mask(km2 * ok_k, vect(parks)), "sum", na.rm = TRUE)[[1]]
cat(sprintf(paste0("Kosovo: %.0f km² suitable (%.1f %% of the territory), ",
                   "%.0f km² most suitable; %.0f %% of the suitable area inside ",
                   "Sharri and Bjeshkët e Nemuna NPs.\n"),
            area_suit, 100 * area_suit / global(km2, "sum", na.rm = TRUE)[[1]],
            area_high, 100 * in_parks / area_suit))

sqv <- vect(st_transform(sq_poly, 4326))
sq_max  <- extract(suit, sqv, fun = max, na.rm = TRUE)[, 2]
sq_frac <- extract(suit >= thr, sqv, fun = mean, na.rm = TRUE)[, 2]
cat(sprintf(paste0("Atlas check: %d of %d squares with the species contain ",
                   "suitable habitat (median %.0f %% of the square), against ",
                   "%d of %d other butterfly squares (median %.0f %%). ",
                   "AUC of the square maximum: %.2f.\n"),
            sum(sq_max[sq_poly$eros] >= thr), sum(sq_poly$eros),
            100 * median(sq_frac[sq_poly$eros]),
            sum(sq_max[!sq_poly$eros] >= thr), sum(!sq_poly$eros),
            100 * median(sq_frac[!sq_poly$eros]),
            auc(sq_max[sq_poly$eros], sq_max[!sq_poly$eros])))

known_k <- st_union(st_transform(sq_poly[sq_poly$eros, ], 4326))
outside <- mask(ok_k, vect(known_k), inverse = TRUE)
cat(sprintf("Suitable area outside the 9 known squares: %.0f km².\n",
            global(km2 * outside, "sum", na.rm = TRUE)[[1]]))

# ---------------------------------------------------------------------------
# 5. Ground-truthing: the field sample
# ---------------------------------------------------------------------------
#
# Thirty plots, one flight season for one team. Each plot is one 30" cell.
#   new      15 predicted suitable, outside every known square – finds new sites
#   revisit   9 the most suitable cell in each known square – is it still there?
#   absence   6 predicted unsuitable but at least half open habitat – tests
#             what the model rules out, where a butterfly survey is still
#             meaningful
# New and absence plots are at least 5 km apart, so they do not cluster on
# one ridge.

spread <- function(cells, n, min_km = 5) {
  cells <- cells[sample.int(length(cells))]
  xy <- xyFromCell(suit_k, cells); keep <- integer(0)
  for (i in seq_along(cells)) {
    if (length(keep) == n) break
    d <- if (length(keep)) terra::distance(xy[i, , drop = FALSE],
                                           xy[keep, , drop = FALSE], lonlat = TRUE) else Inf
    if (all(d >= min_km * 1000)) keep <- c(keep, i)
  }
  cells[keep]
}
open_k <- crop(open, suit_k)
new_cells <- spread(cells(classify(outside, cbind(0, NA))), 15)
abs_cells <- spread(cells(classify((suit_k < thr) & (open_k >= 0.5), cbind(0, NA))), 6)
rev_cells <- sapply(which(sq_poly$eros), function(i) {
  e <- extract(suit_k, sqv[i], cells = TRUE)
  e$cell[which.max(e[[2]])]
})

plots <- data.frame(
  stratum = rep(c("new", "revisit", "absence"),
                c(length(new_cells), length(rev_cells), length(abs_cells))),
  cell = c(new_cells, rev_cells, abs_cells))
plots <- cbind(plots, xyFromCell(suit_k, plots$cell))
plots$suitability <- round(suit_k[plots$cell][[1]], 3)
plots$elevation_m <- round(extract(elev, plots[, c("x", "y")])[[2]])
plots <- plots[order(match(plots$stratum, c("new", "revisit", "absence")), -plots$y), ]
pl_sf <- st_as_sf(plots, coords = c("x", "y"), crs = 4326, remove = FALSE)
in_pa <- st_intersects(pl_sf, st_make_valid(pa))
plots$protectedArea <- vapply(in_pa, function(i) paste(pa$site_name[i], collapse = "; "), "")

# Darwin Core-shaped, so a survey result goes into the national system as it
# stands – including the absences.
sheet <- data.frame(
  eventID = sprintf("PEROS-GT-%02d", seq_len(nrow(plots))),
  stratum = plots$stratum,
  decimalLatitude = round(plots$y, 5),
  decimalLongitude = round(plots$x, 5),
  coordinateUncertaintyInMeters = 600,
  elevation_m = plots$elevation_m,
  predictedSuitability = plots$suitability,
  protectedArea = plots$protectedArea,
  samplingProtocol = "timed search, 30 minutes, whole cell, sunny, July-August",
  eventDate = "", recordedBy = "", occurrenceStatus = "", individualCount = "",
  stringsAsFactors = FALSE)
write.csv(sheet, "data/sdm-ground-truth-plots.csv", row.names = FALSE,
          fileEncoding = "UTF-8")
cat("Wrote data/sdm-ground-truth-plots.csv:", nrow(sheet), "plots\n")
print(table(sheet$stratum))

# ---------------------------------------------------------------------------
# 6. The figure
# ---------------------------------------------------------------------------

fig_w <- 8; fig_h <- 5; dpi <- 200
pt <- function(px) px / dpi * 72 / .pt

kos_utm <- st_transform(kosovo, 32634)
sq_u    <- sq_poly[sq_poly$eros, ]
# Frame Kosovo AND the atlas squares: the northernmost and southernmost
# squares run past the border and were clipped on the first draft.
bb  <- st_bbox(st_union(c(st_geometry(kos_utm), st_geometry(sq_u))))
pad <- 5000
y0 <- bb$ymin - pad; y1 <- bb$ymax + pad
x0 <- bb$xmin - pad; x1 <- x0 + (y1 - y0) * 1.6        # 16:10, legend at right

cls <- classify(suit_k, rbind(c(-Inf, thr, 1), c(thr, high, 2), c(high, Inf, 3)))
cls_u <- project(cls, "EPSG:32634", method = "near", res = 500)
df  <- as.data.frame(cls_u, xy = TRUE, na.rm = TRUE)
names(df)[3] <- "k"
df$k <- factor(df$k, levels = 1:3)
fills <- c("1" = "#E9E6DC", "2" = "#9CC46A", "3" = "#006B4D")

parks_u <- st_transform(parks, 32634)
pl_u   <- st_transform(st_as_sf(plots, coords = c("x", "y"), crs = 4326), 32634)
pl_xy   <- cbind(st_drop_geometry(pl_u), st_coordinates(pl_u))

shapes  <- c(new = 21, revisit = 22, absence = 24)
pfill   <- c(new = "#F28C00", revisit = "white", absence = "white")

# Legend, drawn by hand so every label is a known size.
lx <- bb$xmax + 12000; ly <- y1 - 9000; step <- 11500
leg_txt <- function(i, s, bold = FALSE)
  annotate("text", x = lx + 9000, y = ly - i * step, label = s, hjust = 0,
           size = pt(46), colour = "#1A1A1A",
           fontface = if (bold) "bold" else "plain")
leg_box <- function(i, fill)
  annotate("rect", xmin = lx, xmax = lx + 6000, ymin = ly - i * step - 3000,
           ymax = ly - i * step + 3000, fill = fill, colour = "#8A8A8A", linewidth = 0.3)
leg_pt <- function(i, s)
  annotate("point", x = lx + 3000, y = ly - i * step, shape = shapes[[s]],
           fill = pfill[[s]], colour = "#1A1A1A", size = 5, stroke = 1.2)

sb_x <- bb$xmin + 2000; sb_y <- bb$ymin + 1500          # scale bar, 20 km

p <- ggplot() +
  geom_raster(data = df, aes(x, y, fill = k)) +
  geom_sf(data = kos_utm, fill = NA, colour = "#4A4A4A", linewidth = 0.5) +
  geom_sf(data = parks_u, fill = NA, colour = "#6A1B9A", linewidth = 0.8,
          linetype = "22") +
  geom_sf(data = sq_u, fill = NA, colour = "#1A1A1A", linewidth = 1.0) +
  geom_point(data = pl_xy, aes(X, Y, shape = stratum, fill = stratum),
             colour = "#1A1A1A", size = 4.2, stroke = 1.1) +
  scale_fill_manual(values = c(fills, pfill), guide = "none") +
  scale_shape_manual(values = shapes, guide = "none") +
  leg_txt(0, "Predicted habitat", bold = TRUE) +
  leg_box(1, fills[["3"]]) + leg_txt(1, "Most suitable") +
  leg_box(2, fills[["2"]]) + leg_txt(2, "Suitable") +
  leg_box(3, fills[["1"]]) + leg_txt(3, "Unsuitable") +
  annotate("rect", xmin = lx, xmax = lx + 6000, ymin = ly - 4 * step - 3000,
           ymax = ly - 4 * step + 3000, fill = NA, colour = "#1A1A1A", linewidth = 1.0) +
  leg_txt(4, "Record, 10 km square") +
  annotate("segment", x = lx, xend = lx + 6000, y = ly - 5 * step, yend = ly - 5 * step,
           colour = "#6A1B9A", linewidth = 0.8, linetype = "22") +
  leg_txt(5, "National park") +
  leg_txt(6.4, "Ground-truth plots", bold = TRUE) +
  leg_pt(7.4, "new") + leg_txt(7.4, "Never recorded") +
  leg_pt(8.4, "revisit") + leg_txt(8.4, "Revisit a record") +
  leg_pt(9.4, "absence") + leg_txt(9.4, "Test an absence") +
  annotate("segment", x = sb_x, xend = sb_x + 20000, y = sb_y, yend = sb_y,
           linewidth = 1.6, colour = "#1A1A1A") +
  annotate("text", x = sb_x + 10000, y = sb_y + 1800, label = "20 km",
           vjust = 0, size = pt(44), colour = "#1A1A1A") +
  coord_sf(crs = 32634, datum = NA, expand = FALSE,
           xlim = c(x0, x1), ylim = c(y0, y1)) +
  theme_void() +
  theme(plot.margin = margin(0, 0, 0, 0))

ggsave("images/sdm-polyommatus-eros.png", p, width = fig_w, height = fig_h,
       dpi = dpi, bg = "white")
cat("Wrote images/sdm-polyommatus-eros.png\n")
