# ==============================================================================
# R/build_directive_list.R
#
# Builds `data/eu_directives_species.csv` — the species listed on the annexes of
# the two EU Nature Directives — by parsing the consolidated legal texts on
# EUR-Lex and resolving every name against the GBIF backbone taxonomy.
#
# Run with:  Rscript R/build_directive_list.R
#
# Only needs re-running when the directives are amended, or to change which
# annexes are covered. `pipeline.R` reads the resulting CSV.
#
# ------------------------------------------------------------------------------
# WHY THE LEGAL TEXT, AND NOT A PUBLISHED CHECKLIST
# ------------------------------------------------------------------------------
#
# The annexes are legally binding lists, and the consolidated texts on EUR-Lex
# are the authoritative version:
#
#   Birds Directive    2009/147/EC  — CELEX 02009L0147-20190626
#   Habitats Directive 92/43/EEC    — CELEX 01992L0043-20130701
#
# The EU publishes neither in a machine-readable form. The EEA's EUNIS
# application, historically the usual route, has been retired; its content moved
# to BISE (biodiversity.europa.eu), which exposes no public API.
#
# Per-annex checklists do exist on GBIF, but the ones available are geographic
# transcriptions rather than complete annexes. The Birds Annex I checklist there
# holds 128 of the 193 listed taxa, and the omissions are precisely the ones that
# matter here: *Alectoris graeca* is absent, as are Balkan endemics. Building the
# list from a geographically filtered source would silently under-report the most
# conservation-relevant taxa in Kosovo.
#
# Parsing the legal text avoids that. The structure is stable and regular:
# species names sit in <span class="italics"> elements between the annex
# headings, priority species carry a leading asterisk, and section headings are
# in capitals.
#
# ------------------------------------------------------------------------------
# KNOWN LIMITATIONS
# ------------------------------------------------------------------------------
#
# * Geographic and population qualifiers ("except the Estonian, Finnish and
#   Swedish populations") sit outside the italic element and are not captured.
#   Every listing is therefore treated as applying in full. For screening
#   occurrence data in Kosovo this is the safe direction to err in.
# * Habitats Annex IV(b) incorporates the Annex II(b) plants by reference rather
#   than repeating them. The Annex IV rows below are the explicitly named taxa
#   only; the cross-referenced plants are present under Annex II.
# * Taxonomy has moved on since 1992. Names are resolved against the current
#   GBIF backbone, so synonyms are followed automatically, but taxa that have
#   since been split (*Triturus karelinii*, for example) are matched as the
#   original listed concept.
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

sources <- list(
  birds = list(
    celex = "02009L0147-20190626",
    label = "Birds Directive 2009/147/EC",
    cache = "data/eurlex/birds_directive.html"
  ),
  habitats = list(
    celex = "01992L0043-20130701",
    label = "Habitats Directive 92/43/EEC",
    cache = "data/eurlex/habitats_directive.html"
  )
)

# Only annexes that list species are parsed. Excluded by design: Habitats
# Annex I (habitat types), Habitats Annex III and Birds Annex III (criteria and
# trade rules), Birds Annexes IV and V (methods and research topics).
targets <- tibble::tribble(
  ~source,     ~directive,  ~annex, ~reference_total,
  "birds",     "Birds",     "I",    193L,
  "birds",     "Birds",     "II",    82L,
  "habitats",  "Habitats",  "II",    NA_integer_,
  "habitats",  "Habitats",  "IV",    NA_integer_,
  "habitats",  "Habitats",  "V",     NA_integer_
)

out_path <- "data/eu_directives_species.csv"

# ------------------------------------------------------------------------------
# Fetch and cache the legal texts
# ------------------------------------------------------------------------------

#' Download a consolidated EUR-Lex document, caching it on disk
#'
#' @param celex CELEX identifier of the consolidated act.
#' @param cache Local path to cache the HTML.
#' @return Character vector of the document's lines.
fetch_eurlex <- function(celex, cache) {

  if (!file.exists(cache)) {
    dir.create(dirname(cache), recursive = TRUE, showWarnings = FALSE)
    url <- paste0("https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:",
                  celex)
    say("Downloading ", celex, " from EUR-Lex ...")
    utils::download.file(url, cache, quiet = TRUE, mode = "wb")
  } else {
    say("Using cached copy of ", celex)
  }

  readLines(cache, warn = FALSE, encoding = "UTF-8")
}

#' Locate the line range of one annex within a EUR-Lex document
#'
#' Annex headings are marked up as `<p class="title-annex-1">ANNEX N</p>`. The
#' annex runs from its own heading to the start of the next one.
#'
#' @param lines The document.
#' @param annex Annex number in Roman numerals, e.g. "II".
#' @return An integer vector of length two: first and last line.
annex_range <- function(lines, annex) {

  heads <- grep('class="title-annex-1"', lines)
  if (length(heads) == 0) stop("No annex headings found in document.", call. = FALSE)

  labels <- str_match(lines[heads], ">ANNEX\\s+([IVX]+)<")[, 2]

  idx <- which(labels == annex)
  if (length(idx) == 0) {
    stop("Annex ", annex, " not found. Available: ",
         paste(stats::na.omit(labels), collapse = ", "), call. = FALSE)
  }
  idx <- idx[1]

  start <- heads[idx]
  end   <- if (idx < length(heads)) heads[idx + 1] - 1L else length(lines)

  c(start, end)
}

# ------------------------------------------------------------------------------
# Parse the species entries of one annex
# ------------------------------------------------------------------------------

#' Extract the taxon entries from an annex
#'
#' @param lines The document.
#' @param annex Annex number in Roman numerals.
#' @return A tibble of parsed entries.
parse_annex <- function(lines, annex, default_kingdom = NA_character_) {

  rng     <- annex_range(lines, annex)
  section <- paste(lines[rng[1]:rng[2]], collapse = " ")

  # ONE ENTRY IS ONE BLOCK, NOT ONE ITALIC ELEMENT.
  #
  # A single listing is frequently split across several <span class="italics">
  # elements, because the exclusions are italicised too:
  #
  #   <div class="list">
  #     <span class="italics">Rupicapra rupicapra (except</span>
  #     <span class="italics">Rupicapra rupicapra balcanica,</span>
  #     <span class="italics">Rupicapra rupicapra ornata and</span>
  #     <span class="italics">Rupicapra rupicapra tatrica)</span>
  #   </div>
  #
  # Reading each span as its own listing would turn three EXCLUDED subspecies
  # into three Annex V listings — an error in the worst possible direction.
  # Splitting on block boundaries first keeps each listing whole, so the
  # "(except ...)" clause can then be discarded as a unit.
  blocks <- unlist(strsplit(section, "</div>|</p>", perl = TRUE))

  entries <- vapply(blocks, function(b) {
    italics <- regmatches(
      b, gregexpr('(?<=<span class="italics">)[^<]+', b, perl = TRUE)
    )[[1]]
    if (length(italics) == 0) return(NA_character_)
    paste(italics, collapse = " ")
  }, character(1), USE.NAMES = FALSE)

  entries <- entries[!is.na(entries)] |>
    str_replace_all("&nbsp;", " ") |>
    str_replace_all("[\u2018\u2019\u201C\u201D]", "") |>
    str_replace_all("\\s+", " ") |>
    str_trim()

  entries <- entries[nzchar(entries)]
  if (length(entries) == 0) return(NULL)

  # Track the "(a) ANIMALS" / "(b) PLANTS" headings as we go, so that every
  # entry carries a kingdom hint.
  #
  # This is not cosmetic. GBIF refuses to match a name that is ambiguous across
  # kingdoms, returning matchType "NONE" with the note "Multiple equal matches":
  # *Coronella austriaca* is both a snake and a plant homonym, and *Liparis*
  # is an orchid, a fish and a moth. Without the hint those listings silently
  # drop out of the matched list. With it they resolve correctly.
  current_kingdom <- default_kingdom
  keep_raw <- character(0)
  keep_kingdom <- character(0)

  for (e in entries) {
    if (str_detect(e, "^[A-Z][A-Z \\(\\)]+$")) {
      if (str_detect(e, "ANIMAL"))     current_kingdom <- "Animalia"
      else if (str_detect(e, "PLANT")) current_kingdom <- "Plantae"
      next   # headings are not listings
    }
    keep_raw     <- c(keep_raw, e)
    keep_kingdom <- c(keep_kingdom, current_kingdom %||% NA_character_)
  }

  if (length(keep_raw) == 0) return(NULL)

  # A few listings join two subspecies with Latin "et", for example
  # "Lagopus lagopus scoticus et hibernicus" on Birds Annex II. That is two
  # listed taxa written as one line; expand it so neither is lost.
  expanded_raw <- character(0)
  expanded_kingdom <- character(0)

  for (j in seq_along(keep_raw)) {
    e <- keep_raw[j]
    m <- str_match(e, "^(\\*?\\s*[A-Z][[:alpha:]]+ [[:alpha:]]+) ([[:alpha:]]+) et ([[:alpha:]]+)$")
    if (!is.na(m[1, 1])) {
      e <- c(paste(m[1, 2], m[1, 3]), paste(m[1, 2], m[1, 4]))
    }
    expanded_raw     <- c(expanded_raw, e)
    expanded_kingdom <- c(expanded_kingdom, rep(keep_kingdom[j], length(e)))
  }

  keep_raw     <- expanded_raw
  keep_kingdom <- expanded_kingdom

  # Words that begin a sentence of prose rather than a taxon name.
  prose_openers <- c("All", "Any", "Other", "Species", "The", "Where",
                     "Note", "This", "These", "Annex")

  tibble::tibble(raw_entry = keep_raw, kingdom_hint = keep_kingdom) |>
    dplyr::mutate(
      # A leading asterisk marks a priority species (Habitats Annex II).
      priority = str_detect(.data$raw_entry, "^\\s*\\*"),
      cleaned  = str_trim(str_replace(.data$raw_entry, "^\\s*\\*\\s*", "")),

      # Discard exclusion clauses and trailing qualifiers. The listing is
      # whatever precedes them; the excluded taxa are not listings themselves.
      cleaned = str_trim(str_replace(.data$cleaned, "\\s*\\(except\\b.*$", "")),
      cleaned = str_trim(str_replace(.data$cleaned, "\\s*\u2014.*$", "")),

      # An alternative name may follow in brackets, e.g. "Egretta alba
      # (Ardea alba)". It is often the name GBIF now accepts.
      alternative_name = str_match(.data$cleaned, "\\(([^)]+)\\)")[, 2],
      primary          = str_trim(str_replace_all(.data$cleaned,
                                                  "\\s*\\([^)]*\\)", "")),

      # "spp." after a genus or family means every species within it.
      listing_type = dplyr::if_else(str_detect(.data$primary, "\\bspp\\.\\s*$"),
                                    "genus_or_family", "taxon"),
      scientific_name = str_trim(str_replace(.data$primary,
                                             "\\s*\\bspp\\.\\s*$", "")),

      # Strip stray trailing punctuation left by the original layout.
      scientific_name = str_trim(str_replace(.data$scientific_name,
                                             "[,;:.]+$", ""))
    ) |>
    # Keep bracketed text only where it looks like a scientific name;
    # "(except the Estonian population)" is a qualifier, not a synonym.
    dplyr::mutate(
      alternative_name = dplyr::if_else(
        !is.na(.data$alternative_name) &
          str_detect(.data$alternative_name, "^[A-Z][a-z]+( [a-z-]+){1,2}$"),
        .data$alternative_name, NA_character_
      )
    ) |>
    dplyr::filter(
      nzchar(.data$scientific_name),
      # A taxon name: capitalised genus, then at most two lowercase epithets.
      str_detect(.data$scientific_name,
                 "^[A-Z][[:alpha:]]+([ -][[:alpha:]]+){0,2}$"),
      # ... and not the opening of a sentence of prose.
      !str_extract(.data$scientific_name, "^[A-Za-z]+") %in% prose_openers
    ) |>
    dplyr::distinct(.data$scientific_name, .keep_all = TRUE) |>
    dplyr::select("scientific_name", "priority", "listing_type", "kingdom_hint",
                  "alternative_name", "raw_entry")
}

# ------------------------------------------------------------------------------
# Build the combined list
# ------------------------------------------------------------------------------

say("Building the EU Nature Directives species list from the EUR-Lex texts ...")

documents <- lapply(sources, function(s) fetch_eurlex(s$celex, s$cache))

collected <- list()

for (i in seq_len(nrow(targets))) {

  tgt   <- targets[i, ]
  label <- paste0(tgt$directive, " Annex ", tgt$annex)

  # The Birds Directive annexes carry no ANIMALS/PLANTS headings; everything
  # on them is a bird.
  parsed <- parse_annex(
    documents[[tgt$source]], tgt$annex,
    default_kingdom = if (tgt$directive == "Birds") "Animalia" else NA_character_
  )

  if (is.null(parsed) || nrow(parsed) == 0) {
    warning("No entries parsed for ", label, call. = FALSE)
    next
  }

  parsed <- parsed |>
    dplyr::mutate(
      directive = tgt$directive,
      annex     = tgt$annex,
      celex     = sources[[tgt$source]]$celex
    )

  say("  ", format(label, width = 20), " ",
      format(nrow(parsed), width = 4), " taxa",
      if (!is.na(tgt$reference_total))
        paste0("  (published total: ", tgt$reference_total, ")") else "",
      if (sum(parsed$priority)) paste0("  priority: ", sum(parsed$priority)) else "")

  collected[[label]] <- parsed
}

species_list <- dplyr::bind_rows(collected)

# ------------------------------------------------------------------------------
# Resolve every name against the GBIF backbone
# ------------------------------------------------------------------------------

say("")
say("Resolving ",
    fmt_int(dplyr::n_distinct(c(species_list$scientific_name,
                                stats::na.omit(species_list$alternative_name)))),
    " distinct names against the GBIF backbone ...")

# Each name is submitted with the kingdom it was listed under, which is what
# resolves the cross-kingdom homonyms. Alternative names inherit the hint of the
# entry they belong to.
name_hints <- dplyr::bind_rows(
  species_list |> dplyr::select(name = "scientific_name", kingdom = "kingdom_hint"),
  species_list |>
    dplyr::filter(!is.na(.data$alternative_name)) |>
    dplyr::select(name = "alternative_name", kingdom = "kingdom_hint")
) |>
  dplyr::filter(!is.na(.data$name)) |>
  dplyr::distinct(.data$name, .keep_all = TRUE)

#' Resolve names against the backbone, returning a tidy tibble
resolve_names <- function(df) {
  res <- rgbif::name_backbone_checklist(df)
  res$verbatim_name <- df$name
  res |>
    dplyr::mutate(
      usageKey   = suppressWarnings(as.integer(.data$usageKey)),
      speciesKey = suppressWarnings(as.integer(.data$speciesKey))
    ) |>
    dplyr::select(dplyr::any_of(c("verbatim_name", "usageKey", "speciesKey",
                                  "acceptedUsageKey", "scientificName", "rank",
                                  "status", "matchType", "confidence",
                                  "kingdom", "class", "family", "genus")))
}

matched <- resolve_names(name_hints)

# A kingdom hint occasionally works against us — lichens are listed under
# PLANTS in the directive but sit in Fungi in the GBIF backbone. Retry anything
# that failed without the hint, and keep the better of the two outcomes.
failed <- matched$verbatim_name[
  is.na(matched$matchType) | matched$matchType %in% c("NONE", "HIGHERRANK")
]

if (length(failed) > 0) {
  say("Retrying ", length(failed), " unresolved names without a kingdom hint ...")
  retry <- resolve_names(dplyr::tibble(name = failed))

  improved <- retry |>
    dplyr::filter(!is.na(.data$matchType),
                  !.data$matchType %in% c("NONE", "HIGHERRANK"))

  if (nrow(improved) > 0) {
    say("  recovered ", nrow(improved), " of them")
    matched <- dplyr::bind_rows(
      matched |> dplyr::filter(!.data$verbatim_name %in% improved$verbatim_name),
      improved
    )
  }
}

# The annexes write trinomials without a rank marker ("Pulsatilla vulgaris
# gotlandica"), whereas the GBIF backbone often stores them as
# "Pulsatilla vulgaris subsp. gotlandica". Retry the remaining three-word
# failures in that form.
still_failing <- matched$verbatim_name[
  is.na(matched$matchType) | matched$matchType %in% c("NONE", "HIGHERRANK")
]
trinomials <- still_failing[str_count(still_failing, "\\S+") == 3]

if (length(trinomials) > 0) {
  say("Retrying ", length(trinomials), " trinomials with an explicit subspecies rank ...")

  as_subsp <- str_replace(trinomials, "^(\\S+ \\S+) (\\S+)$", "\\1 subsp. \\2")
  retry2   <- resolve_names(dplyr::tibble(name = as_subsp))
  retry2$verbatim_name <- trinomials   # map back to the name as listed

  improved2 <- retry2 |>
    dplyr::filter(!is.na(.data$matchType),
                  !.data$matchType %in% c("NONE", "HIGHERRANK"))

  if (nrow(improved2) > 0) {
    say("  recovered ", nrow(improved2), " of them")
    matched <- dplyr::bind_rows(
      matched |> dplyr::filter(!.data$verbatim_name %in% improved2$verbatim_name),
      improved2
    )
  }
}

good <- function(mt) !is.na(mt) & !mt %in% c("NONE", "HIGHERRANK")

species_list <- species_list |>
  dplyr::left_join(matched, by = c("scientific_name" = "verbatim_name")) |>
  dplyr::left_join(
    matched |>
      dplyr::select(alt_name = "verbatim_name", alt_usageKey = "usageKey",
                    alt_speciesKey = "speciesKey", alt_matchType = "matchType",
                    alt_rank = "rank"),
    by = c("alternative_name" = "alt_name")
  ) |>
  # Where the listed name no longer resolves but its bracketed alternative
  # does, fall back to the alternative.
  dplyr::mutate(
    used_alternative = !good(.data$matchType) & good(.data$alt_matchType),
    gbif_usage_key   = dplyr::if_else(.data$used_alternative,
                                      .data$alt_usageKey, .data$usageKey),
    gbif_species_key = dplyr::if_else(.data$used_alternative,
                                      .data$alt_speciesKey, .data$speciesKey),
    match_type       = dplyr::if_else(.data$used_alternative,
                                      .data$alt_matchType, .data$matchType),
    matched_rank     = dplyr::if_else(.data$used_alternative,
                                      .data$alt_rank, .data$rank)
  ) |>
  # A HIGHERRANK match means GBIF could not find the listed species and fell
  # back to its genus. Keeping that genus key would quietly promote one listed
  # species into every species of the genus, so the keys are cleared and the
  # entry is reported as unresolved. Genuine "spp." listings are the exception:
  # for those a genus-level match is exactly what is wanted.
  dplyr::mutate(
    .keys_valid = good(.data$match_type) |
      (.data$listing_type == "genus_or_family" &
         .data$match_type %in% c("EXACT", "FUZZY")),
    gbif_usage_key   = dplyr::if_else(.data$.keys_valid,
                                      .data$gbif_usage_key, NA_integer_),
    gbif_species_key = dplyr::if_else(.data$.keys_valid,
                                      .data$gbif_species_key, NA_integer_)
  ) |>
  dplyr::select(-".keys_valid")

# ------------------------------------------------------------------------------
# Validation
# ------------------------------------------------------------------------------

say("")
say("Match quality")
print(as.data.frame(dplyr::count(species_list, .data$match_type,
                                 name = "n", sort = TRUE)), row.names = FALSE)

unresolved <- species_list |> dplyr::filter(!good(.data$match_type))

if (nrow(unresolved) > 0) {
  say("")
  say(nrow(unresolved), " entries did not resolve to a GBIF taxon:")
  print(as.data.frame(unresolved |>
                        dplyr::select("scientific_name", "directive", "annex",
                                      "listing_type", "match_type") |>
                        head(30)), row.names = FALSE)
}

say("")
say("Per-annex totals")
print(as.data.frame(
  species_list |>
    dplyr::group_by(.data$directive, .data$annex) |>
    dplyr::summarise(
      taxa     = dplyr::n(),
      resolved = sum(good(.data$match_type)),
      priority = sum(.data$priority),
      genus_level = sum(.data$listing_type == "genus_or_family"),
      .groups  = "drop"
    )
), row.names = FALSE)

say("")
say("Total rows (taxon x annex): ", fmt_int(nrow(species_list)))
say("Distinct taxa:              ",
    fmt_int(dplyr::n_distinct(species_list$scientific_name)))

say("")
say("Rank composition of matched taxa:")
print(as.data.frame(dplyr::count(species_list, .data$matched_rank,
                                 name = "n", sort = TRUE)), row.names = FALSE)

# ------------------------------------------------------------------------------
# Write
# ------------------------------------------------------------------------------

output <- species_list |>
  dplyr::transmute(
    scientific_name  = .data$scientific_name,
    directive        = .data$directive,
    annex            = .data$annex,
    priority         = .data$priority,
    listing_type     = .data$listing_type,
    gbif_usage_key   = .data$gbif_usage_key,
    gbif_species_key = .data$gbif_species_key,
    match_type       = .data$match_type,
    matched_rank     = .data$matched_rank,
    kingdom          = .data$kingdom,
    class            = .data$class,
    genus            = .data$genus,
    alternative_name = .data$alternative_name,
    source_celex     = .data$celex,
    verbatim_entry   = .data$raw_entry
  ) |>
  dplyr::arrange(.data$directive, .data$annex, .data$scientific_name)

dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
readr::write_csv(output, out_path, na = "")

say("")
say("Written: ", out_path)
say("Re-run `Rscript pipeline.R` to rebuild the subsets against this list.")
