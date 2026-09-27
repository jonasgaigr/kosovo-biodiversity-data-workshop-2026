# Builds OUTLINE.md – the slide-by-slide plan: for each slide its title, time,
# key message, what is on the slide, the visual, and the full speaker notes;
# then the Mermaid source of the data-flow diagram.
#
# WHY THIS IS GENERATED RATHER THAN WRITTEN. The outline and the deck say the
# same thing twice, and two hand-kept copies drift within a week – a note
# reworded on the slide and not in the outline. The outline is the document
# somebody rehearses from, so a stale one is worse than none. So:
#
#   db-architecture.qmd  – titles, on-slide text, speaker notes
#   data/slide-plan.csv  – timings, key messages, visuals
#   data-flow.mmd        – the diagram
#
# and nothing in OUTLINE.md is authored in OUTLINE.md. Edit one of those and
# re-run:
#
#   Rscript build-outline.R

source("parse-deck.R")

deck <- read_deck()
plan <- utils::read.csv("data/slide-plan.csv", stringsAsFactors = FALSE,
                        encoding = "UTF-8")
if (nrow(plan) != nrow(deck)) {
  stop(sprintf("slide-plan.csv has %d rows but the deck has %d slides.",
               nrow(plan), nrow(deck)))
}

mmd <- readLines("data-flow.mmd", encoding = "UTF-8", warn = FALSE)

# The on-slide Markdown, made readable outside Quarto: fenced-div fences go,
# `[text]{.class}` spans keep their text (a placeholder keeps its brackets, so
# it still reads as a blank to fill), and the Mermaid chunk becomes a pointer
# to the one copy of the diagram, at the end of the outline.
on_slide <- function(md) {
  if (!nzchar(md)) return("*(title slide – no content beyond the title)*")
  x <- strsplit(md, "\n", fixed = TRUE)[[1]]
  chunk <- grep("^```\\{mermaid\\}", x)
  if (length(chunk)) {
    end <- chunk + which(x[(chunk + 1):length(x)] == "```")[1]
    x <- c(x[seq_len(chunk - 1)],
           "*The data-flow diagram – rendered, with its Mermaid source, at the end of this outline.*",
           x[(end + 1):length(x)])
  }
  x <- x[!grepl("^:::", x)]
  x <- gsub("\\[([^]]*)\\]\\{\\.placeholder\\}", "[\\1]", x)
  x <- gsub("\\[([^]]*)\\]\\{[^}]*\\}", "\\1", x)
  x <- sub("^\\\\\\*", "*", x)
  txt <- paste(x, collapse = "\n")
  txt <- gsub("\n{3,}", "\n\n", txt)
  trimws(txt)
}

fmt_min <- function(m) {
  if (m == floor(m)) sprintf("%d min", as.integer(m)) else sprintf("%.1f min", m)
}

words <- vapply(deck$notes, spoken_words, numeric(1), USE.NAMES = FALSE)

md <- c(
  "<!-- GENERATED FILE - DO NOT EDIT.",
  "     Built by build-outline.R from db-architecture.qmd (titles, slide text,",
  "     speaker notes), data/slide-plan.csv (timings, key messages, visuals)",
  "     and data-flow.mmd. Edit one of those and re-run: Rscript build-outline.R -->",
  "",
  "# Data flow, quality and standards",
  "",
  "**Biodiversity Database Architecture and Data Modelling – Part 2.**",
  "Slide-by-slide outline, visual plan and speaker notes.",
  "",
  paste0(
    "TAIEX Expert Mission on GIS and biodiversity data management, Pristina, ",
    "case ID ETT IND/EXP 82606. Day 1, Monday 28 September 2026, 11:50-12:30, ",
    "shared with Part 1 (Karel Chobot). Speaker: Jonáš Gaigr, AOPK ČR."),
  "",
  sprintf(paste0(
    "**%d spoken words** over %s of planned slide time – %.1f min at a calm ",
    "125 words per minute, %.1f min at 135."),
    sum(words), fmt_min(sum(plan$minutes)), sum(words) / 125, sum(words) / 135),
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
  "| # | Slide | Time | Words |",
  "|---|---|---|---|",
  sprintf("| %d | %s | %s | %d |", plan$slide, deck$title,
          vapply(plan$minutes, fmt_min, character(1)), words),
  "",
  "---",
  ""
)

for (i in seq_len(nrow(deck))) {
  md <- c(md,
    sprintf("## Slide %d – %s", plan$slide[i], deck$title[i]),
    "",
    sprintf("**Time:** %s &nbsp;·&nbsp; **Spoken words:** %d",
            fmt_min(plan$minutes[i]), words[i]),
    "",
    sprintf("**Key message:** %s", plan$key_message[i]),
    "",
    "**On the slide:**",
    "",
    on_slide(deck$on[i]),
    "",
    sprintf("**Visual:** %s", plan$visual[i]),
    "",
    if (!plan$visual_upgrade[i] %in% c("none", "none needed"))
      c(sprintf("**Possible upgrade:** %s", plan$visual_upgrade[i]), "") else NULL,
    "**Speaker notes:**",
    "",
    if (is.na(deck$notes[i])) "*(none in the deck)*" else deck$notes[i],
    "",
    "---",
    ""
  )
}

md <- c(md,
  "## The data-flow diagram (slide 4) as Mermaid",
  "",
  paste0(
    "The source is `data-flow.mmd`; the deck includes it with `%%| file:`, ",
    "so this is exactly the diagram the slide shows. GitHub renders the block ",
    "below as a diagram; open the raw file, or `data-flow.mmd`, for the code. ",
    "The `%%{init}%%` first line only sizes it for the slide – see ",
    "\"The data-flow diagram\" in the README."),
  "",
  "```mermaid", mmd, "```",
  ""
)

writeLines(md, "OUTLINE.md", useBytes = TRUE)
cat(sprintf("Wrote OUTLINE.md - %d slides, %d spoken words.\n",
            nrow(deck), sum(words)))
