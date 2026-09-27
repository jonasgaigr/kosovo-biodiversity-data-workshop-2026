# Speaker-notes pacing check: spoken words per allotted minute, per slide.
#
# The notes in this deck are written as full spoken prose, so their word count is
# a direct estimate of how long the talk runs. The slot is 35 minutes and the
# target is 120-140 words per minute – slower than a native-speaker default,
# because this audience hears the talk in a second language.
#
# This is not a nicety. The first complete draft of these notes ran to 5,784
# words, which is 165 wpm across the deck: at a realistic delivery speed that is
# a 45-minute talk in a 35-minute slot, and nothing about reading the .qmd makes
# that visible. Re-run this after any edit to the notes.
#
#   Rscript check-pacing.R
#
# Base R only. The parse mirrors build-outline.R; if one breaks, so has the other.

lines <- readLines("spatial-analysis.qmd", encoding = "UTF-8", warn = FALSE)
fences <- which(lines == "---")
if (length(fences) >= 2) lines <- lines[(fences[2] + 1):length(lines)]

heading_at <- grep("^## ", lines)
clean <- function(x) trimws(sub("\\s*\\{[^}]*\\}\\s*$", "", sub("^## ", "", x)))

notes_for <- function(from, to) {
  seg <- lines[from:to]
  s <- grep("^::: *\\{?\\.?notes\\}? *$", seg)
  if (!length(s)) return("")
  rest <- seg[(s[1] + 1):length(seg)]
  e <- which(trimws(rest) == ":::")
  if (!length(e)) return("")
  paste(rest[seq_len(e[1] - 1)], collapse = " ")
}

bounds <- c(heading_at, length(lines) + 1)
titles <- vapply(lines[heading_at], clean, character(1), USE.NAMES = FALSE)
notes  <- vapply(seq_along(heading_at),
                 function(i) notes_for(heading_at[i], bounds[i + 1] - 1),
                 character(1))

keep   <- !(titles %in% c("Sources", ""))
titles <- titles[keep]; notes <- notes[keep]

plan <- utils::read.csv("data/slide-plan.csv", stringsAsFactors = FALSE,
                        encoding = "UTF-8")
stopifnot(nrow(plan) == length(titles))

# Markdown emphasis and the [VERIFY]{.verify} spans are not spoken, so they are
# stripped before counting rather than inflating the estimate.
wc <- function(s) {
  s <- gsub("\\[|\\]\\{[^}]*\\}", "", s)
  s <- gsub("\\*\\*|\\*|`", "", s)
  length(strsplit(trimws(s), "\\s+")[[1]])
}

words <- vapply(notes, wc, numeric(1), USE.NAMES = FALSE)
wpm   <- round(words / plan$minutes)

res <- data.frame(n = plan$slide, min = plan$minutes, words = words, wpm = wpm,
                  slide = substr(titles, 1, 44))
print(res, row.names = FALSE)

overall <- round(sum(words) / sum(plan$minutes))
cat(sprintf("\n%d words over %g min = %d wpm overall (target 120-140).\n",
            sum(words), sum(plan$minutes), overall))

hot <- res[res$wpm > 150, ]
if (nrow(hot)) {
  cat("\nSlides above 150 wpm - dense, and the first place to cut if the",
      "rehearsal overruns:\n")
  print(hot, row.names = FALSE)
}
if (overall > 140) cat("\nOVER BUDGET: trim the notes, or re-cut the timings in data/slide-plan.csv.\n")
