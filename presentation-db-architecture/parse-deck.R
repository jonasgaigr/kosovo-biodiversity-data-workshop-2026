# Reads db-architecture.qmd into one row per slide: title, the on-slide
# Markdown, and the speaker notes. Sourced by check-pacing.R and
# build-outline.R, so the two can never disagree about what a slide says.
#
# Base R only, deliberately: the deck needs nothing but Quarto, and a planning
# script should not be what introduces a dependency.
#
# Two things are read from outside a `## ` slide:
#
# - The TITLE SLIDE is a template partial, so its title is the YAML `title:`
#   and its notes are the YAML `title-slide-attributes: data-notes:` block
#   (see the comment in the .qmd header for why they live there).
# - The closing slide, `## {.aopk-closing}`, has an empty title. It is
#   furniture, not part of the talk, and is dropped.

read_deck <- function(path = "db-architecture.qmd") {
  lines  <- readLines(path, encoding = "UTF-8", warn = FALSE)
  fences <- which(lines == "---")
  yaml   <- lines[(fences[1] + 1):(fences[2] - 1)]
  body   <- lines[(fences[2] + 1):length(lines)]

  # ── The title slide, from the YAML header ────────────────────────────────
  title <- sub('^title:\\s*"?(.*?)"?\\s*$', "\\1", grep("^title:", yaml, value = TRUE)[1])
  at    <- grep("^\\s+data-notes:", yaml)
  title_notes <- NA_character_
  if (length(at)) {
    ind  <- nchar(sub("\\S.*$", "", yaml[at]))
    rest <- yaml[(at + 1):length(yaml)]
    # The folded block runs until the first line indented no deeper than the
    # `data-notes:` key itself.
    stop_at <- which(nchar(sub("\\S.*$", "", rest)) <= ind & nzchar(trimws(rest)))
    block <- if (length(stop_at)) rest[seq_len(stop_at[1] - 1)] else rest
    title_notes <- paste(trimws(block), collapse = " ")
  }

  # ── The `## ` slides ─────────────────────────────────────────────────────
  heads  <- grep("^## ", body)
  bounds <- c(heads, length(body) + 1)

  clean_title <- function(x) trimws(sub("\\s*\\{[^}]*\\}\\s*$", "", sub("^## ", "", x)))

  split_slide <- function(i) {
    seg <- body[(heads[i] + 1):(bounds[i + 1] - 1)]
    s <- grep("^::: *\\{?\\.?notes\\}? *$", seg)
    if (!length(s)) return(list(on = seg, notes = NA_character_))
    rest <- seg[(s[1] + 1):length(seg)]
    e <- which(trimws(rest) == ":::")[1]
    list(on    = seg[seq_len(s[1] - 1)],
         notes = paste(rest[seq_len(e - 1)], collapse = "\n"))
  }

  parts <- lapply(seq_along(heads), split_slide)
  slides <- data.frame(
    title = vapply(body[heads], clean_title, character(1), USE.NAMES = FALSE),
    on    = vapply(parts, function(p) paste(p$on, collapse = "\n"), character(1)),
    notes = vapply(parts, `[[`, character(1), "notes"),
    stringsAsFactors = FALSE
  )
  slides <- slides[nzchar(slides$title), ]

  rbind(data.frame(title = title, on = "", notes = title_notes,
                   stringsAsFactors = FALSE),
        slides)
}

# Spoken words in a block of notes. Markdown emphasis and span attributes are
# not spoken, so they are stripped before counting rather than inflating it.
spoken_words <- function(s) {
  if (is.na(s)) return(0)
  s <- gsub("\\]\\{[^}]*\\}", "", s)
  s <- gsub("[][*`]", "", s)
  length(strsplit(trimws(s), "\\s+")[[1]])
}
