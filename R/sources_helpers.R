# ------------------------------------------------------------------------------
# R/sources_helpers.R
#
# Small helpers for the "Data sources" pages under sources/. Each page is one
# candidate dataset; each reads its own row of `sources/registry.csv` and draws
# the same furniture around it: the metadata table, the status badge and the
# "To be completed" checklist.
#
# Two rules are enforced here rather than left to the pages.
#
#   1. A registry value that has no row in `sources/registry_evidence.csv` is
#      unverified, and `read_registry()` blanks it. A page therefore cannot
#      show a value nobody checked, however it got into the CSV.
#   2. `try_access()` never throws. A dead link or a blocked domain becomes a
#      recorded outcome on the page, never a failed `quarto render`.
#
# Sourced by every page in sources/ as `source("../R/sources_helpers.R")`.
# Nothing in pipeline.R depends on it.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Paths
# ------------------------------------------------------------------------------

#' The project root: the nearest directory upwards holding `_quarto.yml`
#'
#' Quarto runs each page's code in the page's own directory, so `sources/`
#' when rendering a source page, and the project root when the helpers are
#' used from a script. Resolving paths from the root keeps both working.
sources_root <- function(start = getwd()) {
  dir <- normalizePath(start, winslash = "/", mustWork = FALSE)
  repeat {
    if (file.exists(file.path(dir, "_quarto.yml"))) return(dir)
    parent <- dirname(dir)
    if (identical(parent, dir)) {
      stop("No _quarto.yml above ", start, "; run from inside the project.",
           call. = FALSE)
    }
    dir <- parent
  }
}

#' A path relative to the project root
sources_path <- function(...) file.path(sources_root(), ...)

#' The download cache of one dataset, `data/sources/<slug>/`, created if needed
cache_dir <- function(slug) {
  d <- sources_path("data", "sources", slug)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

# ------------------------------------------------------------------------------
# The registry
# ------------------------------------------------------------------------------

#' Registry columns, in order
registry_fields <- c(
  "slug", "title", "category", "custodian", "url", "doi", "licence", "access",
  "format", "access_method", "spatial_resolution", "temporal_coverage",
  "latest_version", "kosovo_coverage", "kosovo_codes_seen", "tier",
  "n2k_question", "effort", "sensitivity", "status", "last_checked", "notes"
)

#' Bookkeeping columns: the project's own filing, not claims about a dataset
#'
#' These need no evidence row and are not counted towards completeness. The
#' title is the working name from the desk review until a page confirms the
#' custodian's own, which the page then says.
bookkeeping_fields <- c("slug", "title", "category", "status",
                        "last_checked", "notes")

#' The fields a page has to verify, and that completeness is measured over
verifiable_fields <- setdiff(registry_fields, bookkeeping_fields)

#' Labels for the "At a glance" table and the checklist
field_labels <- c(
  custodian          = "Custodian",
  url                = "Primary URL",
  doi                = "DOI",
  licence            = "Licence",
  access             = "Access",
  format             = "Format",
  access_method      = "Access method",
  spatial_resolution = "Spatial resolution",
  temporal_coverage  = "Temporal coverage",
  latest_version     = "Latest version",
  kosovo_coverage    = "Kosovo coverage",
  kosovo_codes_seen  = "Kosovo codes seen",
  tier               = "Precision tier",
  n2k_question       = "Natura 2000 question",
  effort             = "Integration effort",
  sensitivity        = "Sensitivity"
)

#' What each blank field asks for, used when a page gives no specific hint
#'
#' `%s` is replaced by the custodian's name, or by "the custodian" when that
#' is itself unknown.
field_hints <- c(
  custodian          = "Identify the organisation that publishes and maintains the data",
  url                = "Find the primary landing page at %s, not an aggregator's copy",
  doi                = "Look for a DOI on the landing page or in DataCite; ask %s if none is shown",
  licence            = "Find the licence or terms of use on the landing page; ask %s if none is stated",
  access             = "Establish whether the data are open, behind registration, on request or paid",
  format             = "Establish the file or service format %s distributes",
  access_method      = "Establish how the data are reached: download, API, WMS/WFS, R package or PDF",
  spatial_resolution = "Find the stated grid size, scale or minimum mapping unit in the documentation from %s",
  temporal_coverage  = "Find the years the data describe in the documentation from %s",
  latest_version     = "Find the date or number of the latest release from %s",
  kosovo_coverage    = "Run the Kosovo coverage check, or find what the documentation says about Kosovo",
  kosovo_codes_seen  = "Record which country codes the data use for Kosovo (XK, XKX, XKO, KOS, RKS, KV) or whether Kosovo is filed under RS/SRB",
  tier               = "Decide the precision tier once the resolution is known",
  n2k_question       = "State which Natura 2000 question the data answer once their content is confirmed",
  effort             = "Estimate the integration effort once format and access are confirmed",
  sensitivity        = "Check whether the data locate persecuted or collected species more finely than 10 km"
)

#' Status values, in the order the hub's legend lists them
status_levels <- c(
  "Complete", "Partial", "Documented only", "Awaiting request",
  "Lead, not verified", "Not applicable to Kosovo"
)

#' Category names, keyed by number
category_labels <- c(
  "1" = "Species occurrence data not yet in GBIF",
  "2" = "National and regional reference lists",
  "3" = "Habitats and ecosystems",
  "4" = "Site prioritisation and prior Natura 2000 work",
  "5" = "Cross-border context",
  "6" = "Environmental covariates",
  "7" = "Pressures and threats",
  "8" = "Teaching resources"
)

#' Read the evidence table
read_evidence <- function(path = sources_path("sources", "registry_evidence.csv")) {
  ev <- utils::read.csv(path, colClasses = "character", na.strings = character(),
                        encoding = "UTF-8", check.names = FALSE)
  ev[] <- lapply(ev, trimws)
  ev
}

#' Read the registry, blanking every value that has no evidence row
#'
#' A value counts as verified only when the evidence table holds a row with
#' the same slug, field and value. Anything else is replaced by "" and listed
#' in the `unverified` attribute, so the hub can show what was dropped.
#'
#' @return A data frame of character columns, one row per dataset.
read_registry <- function(path = sources_path("sources", "registry.csv"),
                          evidence = read_evidence()) {
  reg <- utils::read.csv(path, colClasses = "character", na.strings = character(),
                         encoding = "UTF-8", check.names = FALSE)
  missing <- setdiff(registry_fields, names(reg))
  if (length(missing)) {
    stop("sources/registry.csv lacks column(s): ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  reg <- reg[, registry_fields]
  reg[] <- lapply(reg, trimws)

  key <- paste(evidence$slug, evidence$field, evidence$value, sep = "\r")
  dropped <- character()
  for (f in verifiable_fields) {
    filled <- nzchar(reg[[f]])
    ok <- paste(reg$slug, f, reg[[f]], sep = "\r") %in% key
    bad <- filled & !ok
    if (any(bad)) {
      dropped <- c(dropped, paste0(reg$slug[bad], ": ", f))
      reg[[f]][bad] <- ""
    }
  }
  if (length(dropped)) {
    warning("Blanked ", length(dropped), " registry value(s) with no evidence ",
            "row: ", paste(dropped, collapse = "; "), call. = FALSE)
  }
  attr(reg, "unverified") <- dropped
  reg
}

#' One dataset's row of the registry, as a named list
source_row <- function(slug) {
  reg <- read_registry()
  row <- reg[reg$slug == slug, , drop = FALSE]
  if (nrow(row) != 1) {
    stop("'", slug, "' is not in sources/registry.csv (or is there twice).",
         call. = FALSE)
  }
  as.list(row)
}

#' Share of the verifiable fields that are filled, 0 to 100
completeness <- function(row) {
  vals <- unlist(row[verifiable_fields])
  round(100 * mean(nzchar(vals)))
}

# ------------------------------------------------------------------------------
# Page furniture
# ------------------------------------------------------------------------------

placeholder <- "&mdash; to be completed"

#' Escape the characters that would break a Markdown table cell
md_cell <- function(x) {
  x <- gsub("|", "\\|", x, fixed = TRUE)
  gsub("\n", " ", x, fixed = TRUE)
}

#' The "At a glance" table
#'
#' Blank fields read "— to be completed", so a gap is visible where a reader
#' looks for the value rather than silently absent. URLs and DOIs are links;
#' the tier links to the Natura 2000 page, which defines the three tiers.
metadata_table <- function(row) {
  val <- vapply(verifiable_fields, function(f) row[[f]] %||% "", character(1))

  shown <- md_cell(val)
  is_url <- grepl("^https?://", val)
  shown[is_url] <- sprintf("<%s>", val[is_url])
  if (nzchar(val[["doi"]]) && grepl("^10\\.", val[["doi"]])) {
    shown[["doi"]] <- sprintf("[%s](https://doi.org/%s)", val[["doi"]], val[["doi"]])
  }
  if (nzchar(val[["tier"]])) {
    shown[["tier"]] <- sprintf("[%s](../natura2000.qmd#q1)", md_cell(val[["tier"]]))
  }
  shown[!nzchar(val)] <- placeholder

  out <- data.frame(Field = unname(field_labels[verifiable_fields]),
                    Value = unname(shown), check.names = FALSE)
  knitr::kable(out, format = "pipe", escape = FALSE, align = "ll")
}

#' The status badge, as inline HTML
#'
#' The label is always written out; the colour only repeats it.
status_badge <- function(status) {
  if (is.list(status)) status <- status$status
  if (!status %in% status_levels) {
    stop("Unknown status '", status, "'. Use one of: ",
         paste(status_levels, collapse = "; "), call. = FALSE)
  }
  cls <- tolower(gsub("[^A-Za-z]+", "-", status))
  cls <- sub("-$", "", cls)
  sprintf('<span class="status-badge status-%s">%s</span>', cls, status)
}

#' "29 September 2026", or a placeholder
checked_date <- function(row) {
  d <- row$last_checked %||% ""
  if (!nzchar(d)) return(placeholder)
  x <- as.Date(d)
  months_en <- c("January", "February", "March", "April", "May", "June",
                 "July", "August", "September", "October", "November",
                 "December")
  sprintf("%d %s %s", as.integer(format(x, "%d")),
          months_en[as.integer(format(x, "%m"))], format(x, "%Y"))
}

#' The line under the title: badge and date checked
status_line <- function(row) {
  sprintf('%s &middot; Last checked: %s', status_badge(row$status),
          checked_date(row))
}

# ------------------------------------------------------------------------------
# Open actions
# ------------------------------------------------------------------------------

#' A page's own front matter
#'
#' Each page keeps its open actions (`actions:`) and its field-specific hints
#' (`todo:`) in its YAML header, so the page stays self-contained and the hub
#' can still gather every request in one list.
page_meta <- function(slug) {
  path <- sources_path("sources", paste0(slug, ".qmd"))
  if (!file.exists(path)) return(list())
  rmarkdown::yaml_front_matter(path)
}

#' The open actions of a page, as a data frame
#'
#' @return Columns `slug`, `kind` ("request" or "check"), `what` and `contact`.
page_actions <- function(slug) {
  acts <- page_meta(slug)$actions
  if (!length(acts)) {
    return(data.frame(slug = character(), kind = character(),
                      what = character(), contact = character()))
  }
  data.frame(
    slug    = slug,
    kind    = vapply(acts, function(a) a$kind %||% "check", character(1)),
    what    = vapply(acts, function(a) a$what %||% "", character(1)),
    contact = vapply(acts, function(a) a$contact %||% "", character(1))
  )
}

#' The "To be completed" checklist
#'
#' One item per blank registry field, worded from the page's own `todo:` hint
#' where it gives one and from `field_hints` otherwise, followed by the page's
#' open actions. Written as a Markdown task list; call it from a chunk with
#' `output: asis`.
#'
#' @param row The page's registry row.
#' @param extra Open actions, as returned by `page_actions()`.
#' @param hints Named list of field-specific wording; defaults to the page's
#'   `todo:` front matter.
todo_list <- function(row, extra = page_actions(row$slug),
                      hints = page_meta(row$slug)$todo) {
  who <- if (nzchar(row$custodian %||% "")) row$custodian else "the custodian"
  blank <- verifiable_fields[!nzchar(unlist(row[verifiable_fields]))]

  items <- vapply(blank, function(f) {
    h <- hints[[f]] %||% sprintf(field_hints[[f]], who)
    sprintf("- [ ] **%s**: %s.", field_labels[[f]], sub("\\.$", "", h))
  }, character(1))

  if (nrow(extra)) {
    acts <- sprintf("- [ ] **%s**: %s.%s",
                    ifelse(extra$kind == "request", "Request", "Check"),
                    sub("\\.$", "", extra$what),
                    ifelse(nzchar(extra$contact),
                           paste0(" *Route:* ", sub("\\.$", "", extra$contact),
                                  "."), ""))
    items <- c(items, acts)
  }

  if (!length(items)) {
    cat("Nothing is outstanding for this dataset.\n")
  } else {
    cat(items, sep = "\n")
    cat("\n")
  }
  invisible(items)
}

# ------------------------------------------------------------------------------
# Access
# ------------------------------------------------------------------------------

#' Try to reach a URL, and report what happened without ever throwing
#'
#' With no `dest`, a HEAD request, retried as a one-kilobyte ranged GET when a
#' server refuses HEAD (many answer 403 or 405 to it). With `dest`, a download
#' to a `.part` file that is renamed into place only on success, so a broken
#' transfer never leaves a truncated file where a page would read it.
#'
#' `ssl_verify = FALSE` exists for one case only: a public document on a
#' server whose certificate has expired (ammk-rks.net, September 2026). The
#' page that uses it must say so, and record the file's SHA-256, since without
#' the certificate nothing vouches for what arrived.
#'
#' @param url The address to try.
#' @param dest Local path to download to, or `NULL` for a check only.
#' @param timeout Seconds before giving up.
#' @param ssl_verify Verify the server's certificate.
#' @return A one-row data frame: `url`, `method`, `success`, `http_code`,
#'   `size_bytes`, `content_type`, `final_url`, `error`, `checked_at`,
#'   `elapsed_s`.
try_access <- function(url, dest = NULL, timeout = 60, ssl_verify = TRUE) {
  started <- Sys.time()
  out <- data.frame(
    url = url, method = if (is.null(dest)) "HEAD" else "download",
    success = FALSE, http_code = NA_integer_, size_bytes = NA_real_,
    content_type = NA_character_, final_url = NA_character_,
    error = NA_character_,
    checked_at = format(started, "%Y-%m-%d %H:%M %Z"), elapsed_s = NA_real_
  )
  if (!ssl_verify) out$method <- paste(out$method, "(certificate not verified)")

  handle <- function(...) {
    h <- curl::new_handle(timeout = timeout, connecttimeout = min(timeout, 30),
                          followlocation = TRUE,
                          ssl_verifypeer = ssl_verify, ssl_verifyhost = ssl_verify,
                          ...)
    curl::handle_setheaders(h, `User-Agent` = paste(
      "kosovo-biodiversity-data-workshop (R curl;",
      "https://github.com/jonasgaigr/kosovo-biodiversity-data-workshop-2026)"))
    h
  }
  header_value <- function(res, name) {
    hd <- curl::parse_headers_list(res$headers)
    v <- hd[[tolower(name)]]
    if (is.null(v)) NA_character_ else as.character(v)[length(v)]
  }

  res <- tryCatch({
    if (is.null(dest)) {
      r <- curl::curl_fetch_memory(url, handle = handle(nobody = TRUE))
      if (r$status_code %in% c(400, 403, 405, 501)) {
        r <- curl::curl_fetch_memory(url, handle = handle(range = "0-1023"))
        out$method <- sub("^HEAD", "GET (first 1 kB)", out$method)
      }
      len <- suppressWarnings(as.numeric(header_value(r, "content-length")))
      range <- header_value(r, "content-range")
      if (!is.na(range) && grepl("/[0-9]+$", range)) {
        len <- as.numeric(sub(".*/", "", range))
      }
      out$size_bytes <- len
    } else {
      dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
      part <- paste0(dest, ".part")
      r <- curl::curl_fetch_disk(url, part, handle = handle())
      if (r$status_code < 400) {
        file.rename(part, dest)
        out$size_bytes <- file.size(dest)
      } else {
        unlink(part)
      }
    }
    out$http_code    <- r$status_code
    out$content_type <- header_value(r, "content-type")
    out$final_url    <- r$url
    out$success      <- r$status_code < 400
    out
  }, error = function(e) {
    # Windows reports TLS failures in the machine's own language after the
    # error code; the code is what a reader can look up, so the text stops
    # there.
    msg <- gsub("\\s+", " ", conditionMessage(e))
    out$error <- sub("(\\(0x[0-9A-Fa-f]+\\)).*$", "\\1", msg)
    out
  })

  res$elapsed_s <- round(as.numeric(difftime(Sys.time(), started,
                                             units = "secs")), 1)
  res
}

#' Read a web page's text, or `NA` if it cannot be read; never throws
fetch_text <- function(url, timeout = 60) {
  tryCatch({
    h <- curl::new_handle(timeout = timeout, followlocation = TRUE)
    r <- curl::curl_fetch_memory(url, handle = h)
    if (r$status_code >= 400) return(NA_character_)
    txt <- rawToChar(r$content)
    Encoding(txt) <- "UTF-8"
    txt
  }, error = function(e) NA_character_)
}

#' Integer with thousands separators, as `fmt_int()` in R/functions.R
fmt_int <- function(x) formatC(round(x), format = "d", big.mark = ",")

#' Human-readable size
fmt_size <- function(bytes) {
  ifelse(is.na(bytes), "size not reported",
    ifelse(bytes >= 1024^3, sprintf("%.1f GB", bytes / 1024^3),
      ifelse(bytes >= 1024^2, sprintf("%.1f MB", bytes / 1024^2),
        ifelse(bytes >= 1024, sprintf("%.0f kB", bytes / 1024),
               sprintf("%.0f B", bytes)))))
}

#' Access outcomes as a small Markdown table
access_table <- function(x) {
  x <- do.call(rbind, x)
  shown <- data.frame(
    Address = sprintf("<%s>", x$url),
    Request = x$method,
    Outcome = ifelse(!is.na(x$error), paste("Failed:", md_cell(x$error)),
                     ifelse(x$success, sprintf("HTTP %d", x$http_code),
                            sprintf("HTTP %d (refused)", x$http_code))),
    Type    = ifelse(is.na(x$content_type), "&mdash;",
                     sub(";.*", "", x$content_type)),
    Size    = ifelse(is.na(x$error), fmt_size(x$size_bytes), "&mdash;"),
    Checked = x$checked_at,
    check.names = FALSE
  )
  knitr::kable(shown, format = "pipe", escape = FALSE)
}

#' Size, SHA-256 and date of a cached file, for the page to record
file_fingerprint <- function(path) {
  if (!file.exists(path)) return(NULL)
  data.frame(
    file   = basename(path),
    size   = fmt_size(file.size(path)),
    sha256 = unname(tools::sha256sum(path)),
    downloaded = format(file.mtime(path), "%Y-%m-%d")
  )
}

# ------------------------------------------------------------------------------
# Geography
# ------------------------------------------------------------------------------

#' The national outline, as pipeline.R builds and caches it
#'
#' Read from `data/kosovo_boundary.gpkg`, the OpenStreetMap outline that every
#' figure in the report is screened against; see `kosovo_boundary()` in
#' R/functions.R for why that outline and not GADM's. If the cache is missing,
#' the same function rebuilds it, so a source page never derives a border of
#' its own.
#'
#' @return An `sf` polygon in EPSG:4326.
kosovo_outline <- function() {
  path <- sources_path("data", "kosovo_boundary.gpkg")
  if (file.exists(path)) return(sf::st_read(path, quiet = TRUE))
  env <- new.env()
  sys.source(sources_path("R", "functions.R"), envir = env)
  env$kosovo_boundary(cache_path = path,
                      osm_path   = sources_path("data", "osm_kosovo.gpkg"),
                      gadm_path  = sources_path("data", "gadm41_XKO.gpkg"))
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x
