# Footer-bar overflow check.
#
# A slide whose content runs past the safe area is not warned about by Quarto,
# and it took two wrong detectors to find out what the failure actually looks
# like, so both dead ends are recorded here.
#
# WHAT DOES NOT WORK, ATTEMPT 1: scoring the bar region against a clean
# reference by RMS. The band is mostly uniform green, so a thin intrusion – one
# clipped line of small grey `.note` text – moves the RMS by almost nothing and
# sorts inside the spread of the clean pages.
#
# WHAT DOES NOT WORK, ATTEMPT 2: counting pixels inside the bar that deviate
# from a reference bar. This is the right idea for the wrong failure. THE BAR IS
# OPAQUE AND IS PAINTED ON TOP OF THE CONTENT. Overflowing text is therefore not
# printed through the bar – it is CUT OFF by it, and the bar itself comes out
# pixel-perfect. A detector looking inside the bar is blind to the thing it was
# written to find, by construction.
#
# WHAT WORKS: look at the strip immediately ABOVE the bar. A slide laid out
# inside the safe area leaves that strip empty. A slide whose last line is being
# guillotined has dark pixels sitting right on the boundary. The dvojlist leaf
# legitimately occupies that strip on every non-`.no-leaf` slide, and it lives in
# the bottom right corner, so the right-hand fifth of the width is masked out.
#
# Geometry, from `_extensions/aopk/aopk.scss`: the bar is $aopk-footer-h, 65.3 px
# of the 720 px canvas, i.e. the bottom 9.07 %.

library(png)

dir <- commandArgs(trailingOnly = TRUE)[1]
files <- sort(list.files(dir, pattern = "^page-\\d+\\.png$", full.names = TRUE))

# How far above the bar to look, as a fraction of page height. 0.018 of 450 px at
# 60 dpi is 8 px, which is about half a line of `.note` text – enough to catch a
# line resting on the boundary, tight enough not to trip on a line that has
# cleared it properly.
STRIP <- 0.018
# Anything darker than this on the white ground counts as content. The slides are
# black or dark-green text on white, so the gap is wide and the value is not
# delicate.
INK <- 0.75
# The dvojlist leaf sits in the bottom right and legitimately fills this strip.
LEAF_FROM <- 0.78

probe <- function(f) {
  img <- readPNG(f)
  g <- if (length(dim(img)) == 3) apply(img[, , 1:3, drop = FALSE], c(1, 2), mean) else img
  h <- nrow(g); w <- ncol(g)
  bar_top <- round(h * (1 - 0.0907))
  rows <- seq(max(1, bar_top - round(h * STRIP)), bar_top)
  cols <- seq_len(round(w * LEAF_FROM))
  sum(g[rows, cols, drop = FALSE] < INK)
}

res <- data.frame(
  page    = basename(files),
  ink_px  = vapply(files, probe, numeric(1), USE.NAMES = FALSE)
)
res <- res[order(-res$ink_px), ]
print(res, row.names = FALSE)

cat("\nA clean slide scores 0, or a handful from antialiasing.\n")
cat("Tens or hundreds mean the last line is sitting on the bar - open that page.\n")
cat("The .aopk-section dividers are a solid dark-green field and always score high.\n")
