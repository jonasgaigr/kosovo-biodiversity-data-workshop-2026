# Speaker-notes pacing check: spoken words per allotted minute, per slide.
#
# The notes are written as full spoken prose, so their word count is a direct
# estimate of how long the talk runs. The target is 120-140 words per minute –
# slower than a native-speaker default, because this audience hears the talk in
# a second language – and about 2,000 words in total. Part 2 has 15-17 minutes
# of a shared 40-minute slot, so an overrun is taken from Karel's time or from
# the discussion. Re-run after any edit to the notes:
#
#   Rscript check-pacing.R
#
# The timings are data/slide-plan.csv; the notes are read out of the deck by
# parse-deck.R, which build-outline.R uses too.

source("parse-deck.R")

deck <- read_deck()
plan <- utils::read.csv("data/slide-plan.csv", stringsAsFactors = FALSE,
                        encoding = "UTF-8")
if (nrow(plan) != nrow(deck)) {
  stop(sprintf("slide-plan.csv has %d rows but the deck has %d slides.",
               nrow(plan), nrow(deck)))
}

words <- vapply(deck$notes, spoken_words, numeric(1), USE.NAMES = FALSE)
res <- data.frame(n = plan$slide, min = plan$minutes, words = words,
                  wpm = round(words / plan$minutes),
                  slide = substr(deck$title, 1, 46))
print(res, row.names = FALSE)

total_w <- sum(words); total_m <- sum(plan$minutes)
cat(sprintf("\n%d words over %g min of plan = %d wpm (target 120-140).\n",
            total_w, total_m, round(total_w / total_m)))
cat(sprintf("At a calm 125 wpm the talk runs %.1f min; at 135 wpm, %.1f min.\n",
            total_w / 125, total_w / 135))

hot <- res[res$wpm > 150, ]
if (nrow(hot)) {
  cat("\nSlides above 150 wpm – the first place to cut if the rehearsal overruns:\n")
  print(hot, row.names = FALSE)
}
if (total_w > 2150) cat("\nOVER BUDGET: the brief is about 2,000 words. Trim the notes.\n")
