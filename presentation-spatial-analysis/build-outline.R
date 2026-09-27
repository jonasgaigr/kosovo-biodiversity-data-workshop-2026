# Builds OUTLINE.md – the slide-by-slide plan with timings, key messages, visual
# suggestions and the full speaker notes.
#
# WHY THIS IS GENERATED RATHER THAN WRITTEN.
#
# The outline and the deck say the same thing twice: the outline needs each
# slide's title and its speaker notes, and the deck already holds both. Kept as
# two hand-written documents they drift within a week – a note reworded on the
# slide and not in the outline, or the reverse – and the outline is exactly the
# document somebody rehearses from, so a stale one is worse than none.
#
# So `spatial-analysis.qmd` is the single source of truth for the titles and the
# notes, `data/slide-plan.csv` is the single source of truth for the timings, key
# messages and visuals, and this script joins them. Nothing in OUTLINE.md is
# authored in OUTLINE.md. Edit the .qmd or the CSV and re-run:
#
#   Rscript build-outline.R
#
# Base R only, deliberately: the deck itself needs nothing but Quarto, and a
# planning document should not be the thing that introduces a dependency.

qmd_path  <- "spatial-analysis.qmd"
plan_path <- "data/slide-plan.csv"
out_path  <- "OUTLINE.md"

lines <- readLines(qmd_path, encoding = "UTF-8", warn = FALSE)

# Strip the YAML header, so a `## ` inside a comment there cannot be read as a
# slide. The header is the block between the first two `---` lines.
fences <- which(lines == "---")
if (length(fences) >= 2) lines <- lines[(fences[2] + 1):length(lines)]

# Slide headings are level two; `slide-level: 2` in the extension. The trailing
# `{.class}` is attributes, not title, and is dropped.
is_heading <- grepl("^## ", lines)
heading_at <- which(is_heading)

clean_title <- function(x) {
  x <- sub("^## ", "", x)
  x <- sub("\\s*\\{[^}]*\\}\\s*$", "", x)
  trimws(x)
}

# The notes are the `::: notes` block inside a slide. Quarto closes divs with a
# bare `:::`, and the notes blocks in this deck contain no nested divs, so the
# first closing fence ends the block.
notes_for <- function(from, to) {
  seg   <- lines[from:to]
  start <- grep("^::: *\\{?\\.?notes\\}? *$|^::: *notes *$", seg)
  if (!length(start)) return(NA_character_)
  rest <- seg[(start[1] + 1):length(seg)]
  end  <- which(trimws(rest) == ":::")
  if (!length(end)) return(NA_character_)
  paste(rest[seq_len(end[1] - 1)], collapse = "\n")
}

bounds <- c(heading_at, length(lines) + 1)
slides <- data.frame(
  title = vapply(lines[heading_at], clean_title, character(1), USE.NAMES = FALSE),
  notes = vapply(seq_along(heading_at),
                 function(i) notes_for(heading_at[i], bounds[i + 1] - 1),
                 character(1)),
  stringsAsFactors = FALSE
)

# The furniture – the Sources slide and the closing slide – is not part of the
# plan and has no timing. It is identified by title rather than by position so
# that inserting a slide cannot silently shift the join.
furniture <- slides$title %in% c("Sources", "")
content   <- slides[!furniture, ]

plan <- utils::read.csv(plan_path, stringsAsFactors = FALSE, encoding = "UTF-8")

if (nrow(plan) != nrow(content)) {
  stop(sprintf(
    "slide-plan.csv has %d rows but the deck has %d content slides.\nDeck titles:\n  %s",
    nrow(plan), nrow(content), paste(content$title, collapse = "\n  ")
  ))
}

fmt_min <- function(m) {
  if (m == floor(m)) sprintf("%d min", as.integer(m)) else sprintf("%.1f min", m)
}

total <- sum(plan$minutes)

md <- c(
  "<!-- GENERATED FILE - DO NOT EDIT.",
  "     Built by build-outline.R from spatial-analysis.qmd (titles, speaker notes)",
  "     and data/slide-plan.csv (timings, key messages, visuals).",
  "     Edit one of those and re-run: Rscript build-outline.R -->",
  "",
  "# Analysing Spatial Data for Biodiversity Conservation",
  "",
  "**Slide-by-slide outline, visual plan and speaker notes.**",
  "",
  sprintf(paste0(
    "TAIEX Expert Mission on GIS and biodiversity data management, Pristina, ",
    "case ID ETT IND/EXP 82606. Day 1, Monday 28 September 2026, 14:00-14:45. ",
    "**%s of delivery**, leaving the balance of the 45-minute slot for questions."),
    fmt_min(total)),
  "",
  paste0(
    "Speaker: Jonáš Gaigr, Biodiversity Monitoring Specialist, Nature ",
    "Conservation Agency of the Czech Republic (AOPK ČR)."),
  "",
  paste0(
    "Kosovo\\* - this designation is without prejudice to positions on status, ",
    "and is in line with UNSCR 1244/1999 and the ICJ Opinion on the Kosovo ",
    "declaration of independence."),
  "",
  "---",
  "",
  "## At a glance",
  "",
  "| # | Slide | Time | Visual |",
  "|---|---|---|---|",
  sprintf("| %d | %s | %s | %s |",
          plan$slide, content$title, vapply(plan$minutes, fmt_min, character(1)),
          plan$visual_status),
  "",
  "`exists` = ready to drop in. `partly exists` = a figure in this repository ",
  "needs annotating or extending. `to produce` = must be made. `optional` = the ",
  "slide works as text. `n/a` = deliberately no figure.",
  "",
  "---",
  ""
)

for (i in seq_len(nrow(content))) {
  md <- c(md,
    sprintf("## Slide %d - %s", plan$slide[i], content$title[i]),
    "",
    sprintf("**Time:** %s", fmt_min(plan$minutes[i])),
    "",
    sprintf("**Key message:** %s", plan$key_message[i]),
    "",
    sprintf("**Visual:** %s", plan$visual[i]),
    "",
    sprintf("**Source:** %s &nbsp;&middot;&nbsp; **Status:** `%s`",
            plan$visual_source[i], plan$visual_status[i]),
    "",
    "**Speaker notes:**",
    "",
    if (is.na(content$notes[i])) "*(none in the deck)*" else content$notes[i],
    "",
    "---",
    ""
  )
}

# The likely-questions section is authored prose with no structure to generate,
# so it lives in its own file and is appended verbatim. Its leading HTML comment
# says so, and is dropped here.
questions <- readLines("questions.md", encoding = "UTF-8", warn = FALSE)
questions <- questions[-seq_len(max(grep("-->", questions, fixed = TRUE)))]
md <- c(md, questions, "", "---", "")

# ── The reference list, read out of references.bib ──────────────────────────
#
# Generated rather than retyped, for the same reason the speaker notes are: the
# .bib is what the deck actually cites, so a hand-kept second copy here would
# describe a bibliography the deck does not have. The parse is deliberately
# shallow – these entries are flat, one field per line, no nested braces beyond
# the value itself – and it is checked: if it finds fewer entries than there are
# @ lines in the file, it stops rather than writing a short list.

bib <- readLines("references.bib", encoding = "UTF-8", warn = FALSE)
bib <- bib[!grepl("^\\s*%", bib)]          # comments
raw <- paste(bib, collapse = "\n")

entry_starts <- grep("^@", bib)
chunks <- lapply(seq_along(entry_starts), function(i) {
  from <- entry_starts[i]
  to   <- if (i < length(entry_starts)) entry_starts[i + 1] - 1 else length(bib)
  paste(bib[from:to], collapse = " ")
})

field <- function(chunk, name) {
  m <- regmatches(chunk, regexpr(
    sprintf("%s\\s*=\\s*\\{", name), chunk, ignore.case = TRUE))
  if (!length(m)) return(NA_character_)
  at <- regexpr(sprintf("%s\\s*=\\s*\\{", name), chunk, ignore.case = TRUE)
  s  <- at + attr(at, "match.length")
  # Walk the braces, so a value containing {Kosovo} is not cut at the first }.
  ch <- strsplit(substring(chunk, s), "")[[1]]
  depth <- 1L; out <- character(0)
  for (k in seq_along(ch)) {
    if (ch[k] == "{") depth <- depth + 1L
    if (ch[k] == "}") { depth <- depth - 1L; if (depth == 0L) break }
    out <- c(out, ch[k])
  }
  v <- paste(out, collapse = "")
  v <- gsub("[{}]", "", v)
  # BibTeX escapes, which are invisible in a rendered bibliography but print
  # literally in Markdown: a tied space, an escaped percent or ampersand, and an
  # en dash written as two hyphens.
  v <- gsub("\\\\emph|\\\\texttt", "", v)
  v <- gsub("\\\\ ", " ", v)
  v <- gsub("\\\\([%&_$#])", "\\1", v)
  v <- gsub("--", "–", v, fixed = TRUE)
  v <- gsub("\\s+", " ", v)
  trimws(v)
}

refs <- data.frame(
  author = vapply(chunks, field, character(1), "author"),
  title  = vapply(chunks, field, character(1), "title"),
  year   = vapply(chunks, field, character(1), "year"),
  how    = vapply(chunks, field, character(1), "howpublished"),
  doi    = vapply(chunks, field, character(1), "doi"),
  url    = vapply(chunks, field, character(1), "url"),
  note   = vapply(chunks, field, character(1), "note"),
  urldate = vapply(chunks, field, character(1), "urldate"),
  stringsAsFactors = FALSE
)

if (nrow(refs) != length(entry_starts) || any(is.na(refs$title))) {
  stop("references.bib did not parse cleanly - check the entry formatting.")
}

refs <- refs[order(refs$author, refs$title), ]

md <- c(md,
  "## References",
  "",
  paste0(
    "Generated from `references.bib`, which is what the deck cites. ",
    "An entry marked **Checked** was opened and the claim the deck takes from ",
    "it verified on that date; the rest are standing references (a directive, ",
    "a standard) - see the head of the .bib and the register in the README."),
  "")

for (i in seq_len(nrow(refs))) {
  head_line <- paste0(
    "- **", refs$title[i], "**",
    if (!is.na(refs$author[i])) paste0(" – ", refs$author[i]) else "",
    if (!is.na(refs$year[i]))   paste0(", ", refs$year[i]) else ""
  )
  md <- c(md, head_line)
  if (!is.na(refs$how[i]))  md <- c(md, paste0("  ", refs$how[i], "."))
  doi_url <- if (is.na(refs$doi[i])) NA_character_ else paste0("https://doi.org/", refs$doi[i])
  if (!is.na(refs$doi[i]))  md <- c(md, paste0("  DOI: <", doi_url, ">"))
  # An entry whose `url` is only the resolver for its own DOI would otherwise
  # print the same link twice; the EEA dataset is one.
  if (!is.na(refs$url[i]) && (is.na(doi_url) || refs$url[i] != doi_url)) {
    md <- c(md, paste0("  <", refs$url[i], ">"))
  }
  if (!is.na(refs$urldate[i])) md <- c(md, paste0("  **Checked** ", refs$urldate[i], "."))
  if (!is.na(refs$note[i])) md <- c(md, paste0("  *", refs$note[i], "*"))
}

writeLines(md, out_path, useBytes = TRUE)
cat(sprintf("Wrote %s - %d content slides, %s total, %d references.\n",
            out_path, nrow(content), fmt_min(total), nrow(refs)))
