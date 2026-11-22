# Internal helper functions

#' Normalise Windows-style paths and remap their prefix
#'
#' Turns Windows-style paths (`N:\Arara\...`) into forward slashes and
#' applies the optional prefix remapping.
#'
#' @param path Character vector of file paths.
#' @param from `NULL` or character scalar, prefix to replace.
#' @param to `NULL` or character scalar, replacement prefix.
#' @return Character vector of the same length as `path`.
#' @noRd
remap_path <- function(path, from = NULL, to = NULL) {
  path <- str_replace_all(path, fixed("\\"), "/")
  if (!is.null(from) && !is.null(to)) {
    from <- str_replace_all(from, fixed("\\"), "/")
    path <- str_replace(path, fixed(from), to)
  }
  path
}

#' Read the date and hour from recording file names
#'
#' Extracts the date (YYYYMMDD) and hour (HH), assuming the recorder pattern
#' `<...>_YYYYMMDD_HHMMSS.<ext>`.
#'
#' @param file_name Character vector of file names.
#' @return A tibble with character columns `recording_date` and
#'   `recording_hour`, one row per file name (`NA` when there is no match).
#' @noRd
parse_date_hour <- function(file_name) {
  m <- str_match(file_name, "(\\d{8})_(\\d{6})")
  tibble(
    recording_date = m[, 2],
    recording_hour = str_sub(m[, 3], 1, 2)
  )
}

#' Short species code for folder names
#'
#' Takes the last part of the classifier label, e.g.
#' `"Adenomera diptyx_ade-dip"` -> `"ade_dip"`; a label that is already
#' short (`"ade-dip"`) works the same way.
#'
#' @param species_code Character vector of species labels.
#' @return Character vector of the same length.
#' @noRd
folder_name <- function(species_code) {
  str_replace_all(str_extract(species_code, "[^_]+$"), "-", "_")
}

#' Is a suggested package installed?
#'
#' One place for the check, so tests can mock it.
#'
#' @param pkg Character scalar, package name.
#' @return Logical scalar.
#' @noRd
has_suggested <- function(pkg) {
  requireNamespace(pkg, quietly = TRUE)
}

#' Require a package from Suggests
#'
#' @param pkg Character scalar, package name.
#' @param purpose Character scalar, completes the error message (e.g.
#'   `"for the posterior predictive checks"`).
#' @return `NULL` invisibly; errors when the package is not installed.
#' @noRd
require_suggested <- function(pkg, purpose) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Package '", pkg, "' is needed ", purpose, ". Install it with ",
         "install.packages(\"", pkg, "\").", call. = FALSE)
  }
}

#' Take the site from file names
#'
#' `pattern` is a regular expression with one capture group, applied to the
#' name without the folder (e.g. `"^[^_]+_([^_]+)_"` for
#' `Campinas_Campus01_20261003_074339.flac`).
#'
#' @param paths Character vector of file paths.
#' @param pattern Character scalar, regular expression with one capture
#'   group around the site.
#' @return Character vector of sites, same length as `paths`; errors when a
#'   name does not match.
#' @noRd
site_from_name <- function(paths, pattern) {
  if (!is.character(pattern) || length(pattern) != 1 || is.na(pattern) ||
      !nzchar(pattern)) {
    stop("`site_pattern` must be a single regular expression.",
         call. = FALSE)
  }
  names_only <- basename(str_replace_all(paths, fixed("\\"), "/"))
  m <- str_match(names_only, pattern)
  if (ncol(m) < 2) {
    stop("`site_pattern` needs a capture group around the site, e.g. ",
         "\"^[^_]+_([^_]+)_\".", call. = FALSE)
  }
  site <- m[, 2]
  failed <- is.na(site) | !nzchar(site)
  if (any(failed)) {
    stop(sum(failed), " file name(s) do not match `site_pattern` ", pattern,
         " (e.g. ", names_only[failed][1], ").", call. = FALSE)
  }
  site
}
