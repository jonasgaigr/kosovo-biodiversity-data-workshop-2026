# ------------------------------------------------------------------------------
# publish_slides.R
#
# Copies each workshop deck, slides and handout side by side, into
# docs/slides/<slug>/. Run by Quarto after every render of the website (see
# `post-render` in _quarto.yml); it can also be run on its own after a deck has
# been rebuilt:
#
#   Rscript publish_slides.R
#
# The decks are separate Quarto projects and are never rendered by the website,
# so without this step the copies in docs/ are whatever was last copied by hand
# — and the landing page would link to them regardless. The list of decks is
# data/workshop_decks.csv, which index.qmd reads too, so the page and the files
# it links to cannot drift apart.
#
# A deck that has not been built stops the script rather than being skipped:
# the landing page would otherwise publish a link to a file that is not there.
# So does a deck still showing a placeholder for a missing figure (the red box
# presentation-spatial-analysis/image-slot.lua draws), which its README says
# must never be published.
# ------------------------------------------------------------------------------

decks <- read.csv("data/workshop_decks.csv", encoding = "UTF-8")

for (i in seq_len(nrow(decks))) {
  src <- file.path(decks$folder[i], paste0(decks$file[i], c(".html", ".pdf")))
  missing <- src[!file.exists(src)]
  if (length(missing) > 0) {
    stop("Deck not built: ", paste(missing, collapse = ", "),
         ". Render it in its own folder first (see its README).", call. = FALSE)
  }

  html <- readChar(src[1], file.size(src[1]), useBytes = TRUE)
  if (grepl('class="img-slot"', html, fixed = TRUE, useBytes = TRUE)) {
    stop(src[1], " still shows a figure placeholder; supply the image and ",
         "re-render the deck before publishing it.", call. = FALSE)
  }

  # A deck with a separate one-page handout links to it from its title slide
  # by a relative path, so the handout travels with the slides when it exists.
  handout <- file.path(decks$folder[i], paste0(decks$file[i], "-handout.pdf"))
  if (file.exists(handout)) src <- c(src, handout)

  dest <- file.path("docs", "slides", decks$slug[i])
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  ok <- file.copy(src, dest, overwrite = TRUE, copy.date = TRUE)
  if (!all(ok)) stop("Could not copy into ", dest, call. = FALSE)

  message("slides: ", decks$slug[i], " <- ", decks$folder[i])
}
