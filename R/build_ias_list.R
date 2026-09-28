# ==============================================================================
# R/build_ias_list.R
#
# Builds `data/eu_ias_union_list.csv` — the list of invasive alien species of
# Union concern (the "Union list") under Regulation (EU) No 1143/2014 — by
# parsing the legal texts that establish it and resolving every name against
# the GBIF backbone taxonomy.
#
# Run with:  Rscript R/build_ias_list.R
#
# Only needs re-running when the Commission updates the list. `pipeline.R`
# reads the resulting CSV.
#
# ------------------------------------------------------------------------------
# THE LEGAL TEXT, AND WHERE TO GET IT
# ------------------------------------------------------------------------------
#
# The Union list is the Annex to Commission Implementing Regulation (EU)
# 2016/1141, amended four times since:
#
#   2016/1141  37 species   the list as adopted
#   2017/1263  12 species
#   2019/1262  17 species
#   2022/1203  22 species   one of them, Celastrus orbiculatus, deferred to 2027
#   2025/1422  26 species   two of them, Castor canadensis and Neogale vison,
#                           deferred to 2027
#
# The consolidated text shows the list as it applies today, and marks every row
# with the act that inserted it. It does NOT show the three deferred species,
# because a consolidated version only carries what already applies; those are
# read from Article 2 and the Annex of the act that listed them. Together they
# give all 114 species, each with the date its listing applies from.
#
# The texts are fetched from Cellar, the Publications Office repository behind
# EUR-Lex, rather than from EUR-Lex itself. EUR-Lex now puts a bot challenge in
# front of its pages, and a script is answered with HTTP 202 and an EMPTY BODY.
# That is not an error status, so `download.file()` writes an empty file and
# reports success. Cellar serves the same documents by content negotiation,
# with no challenge. Every download is checked for the text it should contain
# before it is cached, so an empty or substituted page stops the build instead
# of being parsed into an empty list.
#
# ------------------------------------------------------------------------------
# WHY THE LEGAL TEXT, WHEN A CHECKLIST EXISTS ON GBIF
# ------------------------------------------------------------------------------
#
# Unlike the per-annex Nature Directive checklists (see
# `R/build_directive_list.R`), the Union list checklist on GBIF is complete: the
# Research Institute for Nature and Forest (INBO) publishes all 114 species,
# with their dates and English names, as dataset 79d65658-526c-4c78-9d24-
# 1870d67f8439 (https://doi.org/10.15468/97aucj). It is used here, for the
# English names and as an independent cross-check, but not as the source,
# because its taxa are linked to the backbone less well than its species are
# chosen: two of its species carry no backbone key at all. One is a
# transcription slip ("Triadica sebífera"); the other is the American mink,
# which is the next point.
#
# ------------------------------------------------------------------------------
# NAMES THE BACKBONE DOES NOT KNOW
# ------------------------------------------------------------------------------
#
# The 2025 amendment lists the American mink as *Neogale vison*, the genus it
# was moved to in 2021. The GBIF backbone does not carry that combination: asked
# for it, the matching service returns matchType HIGHERRANK and the genus
# *Neogale*. The build treats HIGHERRANK as a failure, never as a match, so the
# listing is not quietly promoted to a genus; the name the backbone does know is
# supplied instead, below. The mink is held there as *Mustela vison*, with
# *Neovison vison* as a synonym.
#
# ------------------------------------------------------------------------------
# KNOWN LIMITATIONS
# ------------------------------------------------------------------------------
#
# * *Lampropeltis getula* is listed "sensu lato", and a note to the table names
#   the species it covers (L. californiae, L. nigra and others). Only the listed
#   name is matched. None of these kingsnakes has any record in Kosovo.
# * Three listings are below species rank: *Vespa velutina nigrithorax*,
#   *Procambarus fallax* f. *virginalis* and *Pueraria montana* var. *lobata*.
#   Each is the form of its species that is established in Europe, so the
#   pipeline matches records of the whole species — see `ias_lookup()` in
#   `pipeline.R`.
# ==============================================================================

suppressPackageStartupMessages({
  library(rgbif)
  library(dplyr)
  library(readr)
  library(stringr)
})

source("R/functions.R")

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

# The consolidated Implementing Regulation. Its date is the last amendment's
# entry into force; a newer consolidation means a newer list.
consolidated_celex <- "02016R1141-20250807"

# The acts that built the list, in order. The consolidated text says which of
# them inserted each row; each act gives the date its listings apply from.
acts <- tibble::tribble(
  ~celex,        ~act,
  "32016R1141",  "2016/1141",
  "32017R1263",  "2017/1263",
  "32019R1262",  "2019/1262",
  "32022R1203",  "2022/1203",
  "32025R1422",  "2025/1422"
)

# The number of species each act listed, as its recitals state. Used only to
# check the parse.
expected_total <- 114L

# Listed names the GBIF backbone cannot resolve, mapped to the name it holds
# the same species under. See the header.
backbone_names <- c("Neogale vison" = "Neovison vison")

# The Union list as a checklist dataset on GBIF, published by INBO.
gbif_checklist <- "79d65658-526c-4c78-9d24-1870d67f8439"

cache_dir <- "data/eurlex"
out_path  <- "data/eu_ias_union_list.csv"

# ------------------------------------------------------------------------------
# Fetch and cache the legal texts
# ------------------------------------------------------------------------------

#' Fetch a document from Cellar by its CELEX number, caching it on disk
#'
#' @param celex CELEX identifier, of an act or of a consolidated version.
#' @param must_contain A string the genuine document is certain to contain.
#' @return The document as a single string.
fetch_cellar <- function(celex, must_contain) {

  cache <- file.path(cache_dir, paste0("ias_", celex, ".html"))

  if (!file.exists(cache)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    say("Downloading ", celex, " from Cellar ...")

    h <- curl::new_handle(followlocation = TRUE)
    curl::handle_setheaders(h, Accept = "application/xhtml+xml",
                            `Accept-Language` = "eng")
    res <- curl::curl_fetch_memory(
      paste0("https://publications.europa.eu/resource/celex/", celex), h)

    body <- rawToChar(res$content)
    Encoding(body) <- "UTF-8"

    # Checked before it is cached: a challenge page, an empty 202 or a notice
    # in place of the act would otherwise be parsed as an act with no species.
    if (res$status_code != 200 || !grepl(must_contain, body, fixed = TRUE)) {
      stop("Cellar did not return ", celex, " (HTTP ", res$status_code, ", ",
           nchar(body), " characters).", call. = FALSE)
    }
    writeLines(body, cache, useBytes = TRUE)
  } else {
    say("Using cached copy of ", celex)
  }

  paste(readLines(cache, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

#' Reduce a fragment of markup to plain, single-spaced text
plain_text <- function(x) {
  x <- gsub("<[^>]+>", " ", x)
  x <- gsub("&nbsp;| ", " ", x)
  x <- gsub("&amp;", "&", x, fixed = TRUE)
  str_squish(x)
}

#' Parse an English date such as "2 August 2027"
#'
#' Not `as.Date(format = "%d %B %Y")`: `%B` reads month names in the session's
#' locale, so the same script parses on one machine and returns NA on another.
parse_en_date <- function(x) {
  p <- str_match(x, "^(\\d{1,2}) ([A-Z][a-z]+) (\\d{4})$")
  as.Date(sprintf("%s-%02d-%02d", p[, 4], match(p[, 3], month.name),
                  as.integer(p[, 2])))
}

# ------------------------------------------------------------------------------
# Each act: when its listings apply, and which it deferred
# ------------------------------------------------------------------------------

#' Read the dates out of one amending act
#'
#' Every act enters into force "on the twentieth day following that of its
#' publication", and the publication date is the first date in the Official
#' Journal header. An act may defer part of its Annex ("Point (3) of the Annex
#' shall apply from 2 August 2027"); the species in that point are returned
#' with their own date.
#'
#' @return A list with `in_force` (a Date) and `deferred` (a tibble of
#'   `scientific_name`, `applies_from`, `point`).
parse_act <- function(doc, celex) {

  txt <- plain_text(doc)

  if (!grepl("twentieth day following that of its publication", txt,
             fixed = TRUE)) {
    stop(celex, ": entry-into-force clause not found; the date rule below ",
         "would not hold.", call. = FALSE)
  }

  pub <- str_match(txt, "\\b(\\d{1,2})\\.(\\d{1,2})\\.(\\d{4})\\b")
  in_force <- as.Date(sprintf("%s-%02d-%02d", pub[, 4], as.integer(pub[, 3]),
                              as.integer(pub[, 2]))) + 20

  clauses <- str_match_all(
    txt, "Point \\((\\d+)\\) of the Annex shall apply from (\\d{1,2} [A-Z][a-z]+ \\d{4})")[[1]]

  deferred <- dplyr::bind_rows(lapply(seq_len(nrow(clauses)), function(i) {

    point <- clauses[i, 2]

    # The point runs from its own number to the next point of the Annex. A
    # table note such as "(4)’" closing a row is not a point: points are
    # followed by a space and then "in" or an opening quote.
    from <- regexpr(sprintf("\\(%s\\) in the table", point), txt)
    if (from < 0) stop(celex, ": Annex point (", point, ") not found.",
                       call. = FALSE)
    rest <- substring(txt, from + 1)
    to   <- regexpr("\\(\\d+\\) (in|‘)", rest)
    seg  <- if (to > 0) substring(rest, 1, to - 1) else rest

    # Each inserted row opens with a quotation mark and the binomial.
    names <- str_match_all(seg, "‘\\s*([A-Z][a-z]+ [a-z]+)")[[1]][, 2]

    dplyr::tibble(scientific_name = names, point = point,
                  applies_from = parse_en_date(clauses[i, 3]))
  }))

  # A deferral can also sit in a note to the table rather than in Article 2.
  # The 2017 act does it that way: "(*1) The inclusion of Nyctereutes
  # procyonoides Gray, 1834 shall apply as of 2 February 2019."
  notes <- str_match_all(
    txt, paste0("The inclusion of ([A-Z][a-z]+ [a-z]+)[^.]*? shall apply ",
                "(?:as of|from) (\\d{1,2} [A-Z][a-z]+ \\d{4})"))[[1]]

  deferred <- dplyr::bind_rows(
    deferred,
    dplyr::tibble(scientific_name = notes[, 2], point = "note",
                  applies_from = parse_en_date(notes[, 3]))
  )

  list(in_force = in_force, deferred = deferred)
}

# ------------------------------------------------------------------------------
# The consolidated table
# ------------------------------------------------------------------------------

#' Split one table cell into the listed name and any alternative given
#'
#' The species column italicises every name, and a row may carry more than one:
#'
#'   Pueraria montana (Lour.) Merr. var. lobata (Willd.) (Pueraria lobata ...)
#'   Procambarus fallax (Hagen, 1870) f. virginalis (Procambarus virginalis ...)
#'
#' The first italic run is the listed species. An italic run that begins in
#' lower case continues it below species rank, with the rank marker either
#' inside the run ("var. lobata") or in the plain text before it ("f."). The
#' next run that begins with a capital is the alternative name, which the
#' Commission gives in brackets and which is often the name GBIF holds.
parse_species_cell <- function(cell) {

  # Inline amendment markers ("►M4 ... ◄") and their links are not names.
  cell <- gsub("<a [^>]*>[^<]*</a>", "", cell)
  cell <- gsub("[►◄]", "", cell)

  m <- gregexpr('<span class="italics">[^<]*</span>', cell)[[1]]
  if (m[1] < 0) return(NULL)

  starts  <- as.integer(m)
  ends    <- starts + attr(m, "match.length")
  italics <- plain_text(regmatches(cell, list(m))[[1]])
  italics <- str_trim(gsub("^\\(|\\)$", "", italics))
  gaps    <- c("", vapply(seq_along(starts)[-1], function(i) {
    plain_text(substring(cell, ends[i - 1], starts[i] - 1))
  }, character(1)))

  # A lower-case run continues the name before it, below species rank.
  continue <- function(name, i) {
    if (i > length(italics) || !grepl("^(var\\.|subsp\\.|f\\.)?\\s*[a-z]", italics[i]))
      return(list(name = name, next_i = i))
    rank <- if (grepl("^(var|subsp|f)\\.", italics[i])) "" else
      paste0(str_match(gaps[i], "\\b(var|subsp|f)\\.\\s*$")[, 2], ". ")
    list(name = str_squish(paste0(name, " ", sub("^NA\\. ", "", rank), italics[i])),
         next_i = i + 1)
  }

  primary <- continue(italics[1], 2)

  alternative <- NA_character_
  if (primary$next_i <= length(italics) &&
      grepl("^[A-Z]", italics[primary$next_i])) {
    alternative <- continue(italics[primary$next_i], primary$next_i + 1)$name
  }

  # "Lithobates (Rana) catesbeianus": a subgenus in brackets is not part of the
  # binomial the backbone matches on.
  name <- str_squish(gsub("\\s*\\([A-Z][a-z]+\\)", "", primary$name))

  dplyr::tibble(scientific_name  = name,
                alternative_name = alternative,
                verbatim_entry   = plain_text(cell))
}

#' Read every species row out of the consolidated Annex
#'
#' Rows are grouped under amendment markers: a row of its own holding a link
#' such as `title="32019R1262: INSERTED">▼M2`, after which every species row
#' was inserted by that act until the next marker.
parse_union_list <- function(doc) {

  start <- regexpr('class="title-annex-1"', doc, fixed = TRUE)
  if (start < 0) stop("No Annex found in the consolidated text.", call. = FALSE)
  annex <- substring(doc, start)

  rows <- regmatches(annex, gregexpr("(?s)<tr>.*?</tr>", annex, perl = TRUE))[[1]]

  act <- NA_character_
  out <- list()

  for (r in rows) {
    cells  <- regmatches(r, gregexpr("(?s)<td[^>]*>.*?</td>", r, perl = TRUE))[[1]]
    marker <- str_match(r, 'title="(3\\d{4}R\\d{4})(: INSERTED)?">▼')[, 2]

    if (length(cells) == 1) {
      # A marker that is not an act on the list (a corrigendum, say) must not
      # silently carry the previous act forward.
      act <- if (!is.na(marker) && marker %in% acts$celex) marker else NA_character_
      next
    }
    if (length(cells) < 2) next

    entry <- parse_species_cell(cells[1])
    if (is.null(entry)) next   # the header rows carry no italic name

    out[[length(out) + 1]] <- dplyr::mutate(entry, listing_celex = act)
  }

  dplyr::bind_rows(out)
}

# ------------------------------------------------------------------------------
# Build the list
# ------------------------------------------------------------------------------

say("Building the Union list of invasive alien species from the legal texts ...")

consolidated <- fetch_cellar(consolidated_celex,
                             "LIST OF INVASIVE ALIEN SPECIES OF UNION CONCERN")

in_force_rows <- parse_union_list(consolidated)

if (anyNA(in_force_rows$listing_celex)) {
  stop("Rows with no recognised inserting act: ",
       paste(in_force_rows$scientific_name[is.na(in_force_rows$listing_celex)],
             collapse = ", "), call. = FALSE)
}

parsed_acts <- lapply(acts$celex, function(celex) {
  parse_act(fetch_cellar(celex, "invasive alien species"), celex)
})
names(parsed_acts) <- acts$celex

acts$in_force <- do.call(c, lapply(parsed_acts, `[[`, "in_force"))

deferred <- dplyr::bind_rows(lapply(acts$celex, function(celex) {
  d <- parsed_acts[[celex]]$deferred
  if (nrow(d)) d$listing_celex <- celex
  d
}))

say("  Consolidated text ", consolidated_celex, ": ", nrow(in_force_rows),
    " species applying")

# A deferred listing either already applies — it is then in the consolidated
# table, and only the date needs correcting — or it does not, and it is added
# from the act. Pistia stratiotes is the first kind (it applied from 2 August
# 2024); Celastrus orbiculatus is the second.
union_list <- in_force_rows |>
  dplyr::left_join(acts |> dplyr::select("celex", "act", "in_force"),
                   by = c("listing_celex" = "celex")) |>
  dplyr::left_join(deferred |> dplyr::select("scientific_name", deferred_from = "applies_from"),
                   by = "scientific_name") |>
  dplyr::mutate(applies_from = dplyr::coalesce(.data$deferred_from, .data$in_force)) |>
  dplyr::select(-"deferred_from", -"in_force")

not_yet <- deferred |>
  dplyr::filter(!.data$scientific_name %in% union_list$scientific_name) |>
  dplyr::left_join(acts |> dplyr::select("celex", "act"),
                   by = c("listing_celex" = "celex")) |>
  dplyr::mutate(alternative_name = NA_character_,
                verbatim_entry   = .data$scientific_name) |>
  dplyr::select(dplyr::any_of(names(union_list)))

union_list <- dplyr::bind_rows(union_list, not_yet) |>
  dplyr::arrange(.data$scientific_name)

say("  Listed, not yet applying: ", nrow(not_yet), " (",
    paste(sprintf("%s from %s", not_yet$scientific_name,
                  format(not_yet$applies_from)), collapse = "; "), ")")

print(as.data.frame(dplyr::count(union_list, act = .data$act,
                                 applies_from = .data$applies_from)),
      row.names = FALSE)

if (nrow(union_list) != expected_total) {
  stop("Parsed ", nrow(union_list), " species; the acts list ", expected_total,
       ".", call. = FALSE)
}

# ------------------------------------------------------------------------------
# Resolve every name against the GBIF backbone
# ------------------------------------------------------------------------------

good <- function(mt) !is.na(mt) & !mt %in% c("NONE", "HIGHERRANK")

#' Resolve names against the backbone, one row per name
resolve_names <- function(names) {
  res <- rgbif::name_backbone_checklist(dplyr::tibble(name = names))
  res$verbatim_name <- names
  res |>
    dplyr::mutate(
      usageKey   = suppressWarnings(as.integer(.data$usageKey)),
      speciesKey = suppressWarnings(as.integer(.data$speciesKey))
    ) |>
    dplyr::select(dplyr::any_of(c("verbatim_name", "usageKey", "speciesKey",
                                  "scientificName", "species", "rank",
                                  "status", "matchType", "kingdom", "phylum",
                                  "class", "order", "family")))
}

say("")
say("Resolving ", nrow(union_list), " names against the GBIF backbone ...")

# Three candidate names per listing, tried in order: as listed, the alternative
# the Commission gives, and the name the backbone is known to hold it under.
candidates <- union_list |>
  dplyr::transmute(
    scientific_name = .data$scientific_name,
    c1 = .data$scientific_name,
    c2 = .data$alternative_name,
    c3 = unname(backbone_names[.data$scientific_name])
  ) |>
  tidyr::pivot_longer(c("c1", "c2", "c3"), names_to = "try",
                      values_to = "name") |>
  dplyr::filter(!is.na(.data$name))

matched <- resolve_names(unique(candidates$name))

resolved <- candidates |>
  dplyr::left_join(matched, by = c("name" = "verbatim_name")) |>
  dplyr::filter(good(.data$matchType)) |>
  dplyr::arrange(.data$scientific_name, .data$try) |>
  dplyr::distinct(.data$scientific_name, .keep_all = TRUE)

union_list <- union_list |>
  dplyr::left_join(
    resolved |>
      dplyr::transmute(
        scientific_name  = .data$scientific_name,
        matched_name     = .data$name,
        gbif_usage_key   = .data$usageKey,
        gbif_species_key = .data$speciesKey,
        gbif_species     = .data$species,
        match_type       = .data$matchType,
        matched_rank     = .data$rank,
        kingdom = .data$kingdom, phylum = .data$phylum, class = .data$class,
        order = .data$order, family = .data$family
      ),
    by = "scientific_name")

unresolved <- union_list |> dplyr::filter(is.na(.data$gbif_usage_key))
if (nrow(unresolved)) {
  stop("No backbone match for: ", paste(unresolved$scientific_name,
                                        collapse = ", "),
       ". Add the name the backbone holds to `backbone_names`.", call. = FALSE)
}

via_other <- union_list |>
  dplyr::filter(.data$matched_name != .data$scientific_name)
if (nrow(via_other)) {
  say("  Resolved through another name:")
  print(as.data.frame(via_other |>
                        dplyr::select("scientific_name", "matched_name",
                                      "gbif_species")), row.names = FALSE)
}

# ------------------------------------------------------------------------------
# Cross-check against the Union list checklist on GBIF
# ------------------------------------------------------------------------------
#
# Compared by the accepted species each side resolves to, so that a renaming
# (Eichhornia to Pontederia, Pennisetum to Cenchrus) is not reported as a
# difference. The checklist's own backbone links are NOT used for this — see
# the header for why — but the names it carries are resolved afresh here.

say("")
say("Cross-checking against the checklist on GBIF (", gbif_checklist, ") ...")

checklist <- jsonlite::fromJSON(
  paste0("https://api.gbif.org/v1/species/search?datasetKey=", gbif_checklist,
         "&limit=1000"),
  simplifyVector = FALSE)$results

checklist <- dplyr::bind_rows(lapply(checklist, function(r) {
  eng <- Filter(function(v) identical(v$language, "eng"), r$vernacularNames)
  dplyr::tibble(
    scientific  = r$scientificName %||% NA_character_,
    canonical   = r$canonicalName %||% NA_character_,
    rank        = r$rank %||% NA_character_,
    status      = r$taxonomicStatus %||% NA_character_,
    nub_key     = r$nubKey %||% NA_integer_,
    english     = if (length(eng)) eng[[1]]$vernacularName else NA_character_,
    applies     = if (length(r$descriptions)) r$descriptions[[1]]$description
                  else NA_character_
  )
})) |>
  dplyr::filter(.data$status == "ACCEPTED", !.data$rank %in% "KINGDOM")

# A transcription slip in the checklist is not a taxonomic difference. One
# accent — "Triadica sebífera" — is enough for GBIF's name parser to give up on
# the epithet, so the checklist's own canonical name for that entry is
# "Triadica spec.". The full name is used for such entries instead, with its
# diacritics folded. Diacritics only: an ASCII transliteration would also turn
# the hybrid sign in "Reynoutria × bohemica" into a letter x.
fold <- function(x) stringi::stri_trans_general(x, "NFD; [:Nonspacing Mark:] Remove; NFC")
checklist$lookup <- ifelse(is.na(checklist$canonical) |
                             grepl("\\bspec\\.$", checklist$canonical),
                           fold(checklist$scientific), fold(checklist$canonical))
checklist$lookup <- dplyr::coalesce(
  unname(backbone_names[checklist$canonical]), checklist$lookup)

cl_matched <- resolve_names(checklist$lookup)
checklist$species_key <- cl_matched$speciesKey

union_list <- union_list |>
  dplyr::left_join(
    checklist |>
      dplyr::filter(!is.na(.data$species_key)) |>
      dplyr::distinct(.data$species_key, .keep_all = TRUE) |>
      dplyr::transmute(gbif_species_key = .data$species_key,
                       english_name = .data$english,
                       checklist_applies = as.Date(.data$applies),
                       in_gbif_checklist = TRUE),
    by = "gbif_species_key") |>
  dplyr::mutate(in_gbif_checklist = dplyr::coalesce(.data$in_gbif_checklist,
                                                    FALSE))

only_legal <- union_list |> dplyr::filter(!.data$in_gbif_checklist)
only_checklist <- checklist |>
  dplyr::filter(!.data$species_key %in% union_list$gbif_species_key)
date_differs <- union_list |>
  dplyr::filter(!is.na(.data$checklist_applies),
                .data$checklist_applies != .data$applies_from)

say("  Checklist: ", nrow(checklist), " accepted taxa, ",
    sum(is.na(checklist$nub_key)), " without a backbone key of their own (",
    paste(checklist$canonical[is.na(checklist$nub_key)], collapse = ", "), ")")
say("  In the legal text, not the checklist: ",
    if (nrow(only_legal)) paste(only_legal$scientific_name, collapse = ", ") else "none")
say("  In the checklist, not the legal text: ",
    if (nrow(only_checklist)) paste(only_checklist$canonical, collapse = ", ") else "none")
say("  Dates that differ:                    ",
    if (nrow(date_differs)) paste(sprintf("%s (%s vs %s)",
                                          date_differs$scientific_name,
                                          date_differs$applies_from,
                                          date_differs$checklist_applies),
                                  collapse = ", ") else "none")

# ------------------------------------------------------------------------------
# Write
# ------------------------------------------------------------------------------

output <- union_list |>
  dplyr::transmute(
    scientific_name   = .data$scientific_name,
    english_name      = .data$english_name,
    listing_act       = paste0("Implementing Regulation (EU) ", .data$act),
    applies_from      = .data$applies_from,
    gbif_usage_key    = .data$gbif_usage_key,
    gbif_species_key  = .data$gbif_species_key,
    gbif_species      = .data$gbif_species,
    match_type        = .data$match_type,
    matched_rank      = .data$matched_rank,
    matched_name      = .data$matched_name,
    kingdom = .data$kingdom, phylum = .data$phylum, class = .data$class,
    order = .data$order, family = .data$family,
    alternative_name  = .data$alternative_name,
    in_gbif_checklist = .data$in_gbif_checklist,
    source_celex      = dplyr::if_else(.data$applies_from <= as.Date(
                          sub("^.*-(\\d{4})(\\d{2})(\\d{2})$", "\\1-\\2-\\3",
                              consolidated_celex)),
                          consolidated_celex, .data$listing_celex),
    verbatim_entry    = .data$verbatim_entry
  ) |>
  dplyr::arrange(.data$scientific_name)

readr::write_csv(output, out_path, na = "")

say("")
say("Written: ", out_path, " (", nrow(output), " species)")
say("Re-run `Rscript pipeline.R` to rebuild the subsets against this list.")
