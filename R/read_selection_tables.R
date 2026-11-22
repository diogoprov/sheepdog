#' Read BirdNET selection tables
#'
#' Finds the BirdNET selection tables (Raven format, tab-separated) under
#' `data_dir`, reads them and stacks them in one table. The site is the name
#' of the folder that contains the tables. The `output_` prefix of BirdNET
#' output folders is removed, so `output_UEM/` becomes site `UEM`.
#'
#' The BirdNET GUI writes the Raven selection tables in one of two ways, and
#' both are read:
#'
#' - **combined**: one `BirdNET_SelectionTable.txt` per site folder, written
#'   when "Combine selection tables" is checked in the output settings
#'   (result type "Raven selection table");
#' - **one table per audio file** (the default of the GUI), named
#'   `<audio file>.BirdNET.selection.table.txt`. The tables of a folder are
#'   stacked in the order of their file names, and the `Selection` column
#'   is renumbered from 1, as in the combined table. The tables have the
#'   same columns as the combined one; in them, `Begin Time (s)` counts
#'   from the start of the audio file, like `File Offset (s)`, which is
#'   the column sheepdog uses to place a detection.
#'
#' Run BirdNET once per site, so that the tables of each site end up in
#' their own folder: per-audio tables in subfolders of a site folder would be
#' read as separate sites. A folder that holds a combined table is read from
#' it alone, and its per-audio tables are ignored, with a message. When the
#' tables of several sites share a folder, `site_pattern` takes the site
#' from the name of the audio file of each prediction (`Begin Path`)
#' instead.
#'
#' Column names are standardised to lower case without units or punctuation,
#' e.g. `Begin Time (s)` becomes `begin_time` and `File Offset (s)` becomes
#' `file_offset`.
#'
#' @param data_dir Character scalar, path to the root folder, searched
#'   recursively.
#' @param table_pattern Character scalar, regular expression for the file
#'   names of combined
#'   tables.
#' @param per_audio_pattern `NULL` or character scalar, regular expression
#'   for the file names of
#'   per-audio tables. `NULL` reads only combined tables.
#' @param site_pattern `NULL` or character scalar, regular expression with
#'   one capture group
#'   that takes the site from the name of the audio file in `Begin Path`,
#'   instead of from the folder of the table. For example,
#'   `"^[^_]+_([^_]+)_"` reads `Campus01` from
#'   `Campinas_Campus01_20261003_074339.flac`. Use the same pattern in
#'   [list_recordings()].
#'
#' @return A tibble with one row per prediction, the column `site` first,
#'   followed by the standardised table columns. The columns `begin_time`,
#'   `end_time`, `species_code`, `confidence`, `begin_path` and `file_offset`
#'   are required.
#' @export
read_selection_tables <- function(data_dir,
                                  table_pattern = "^BirdNET_SelectionTable\\.txt$",
                                  per_audio_pattern = "\\.BirdNET\\.selection\\.table\\.txt$",
                                  site_pattern = NULL) {
  sources <- find_selection_tables(data_dir, table_pattern, per_audio_pattern)
  if (length(sources) == 0) {
    others <- list.files(data_dir, pattern = "(?i)selection.?table.*\\.txt$",
                         recursive = TRUE)
    hint <- if (length(others) > 0) {
      paste0("\n", length(others), " other selection table(s) found, e.g. ",
             others[1], ". Set `table_pattern` (combined tables) or ",
             "`per_audio_pattern` (one table per audio file) to match them.")
    } else ""
    stop("No selection table found in ", data_dir, " matching ",
         table_pattern,
         if (!is.null(per_audio_pattern)) paste0(" or ", per_audio_pattern),
         hint)
  }

  predictions <- imap(sources, function(files, folder) {
    tb <- read_site_tables(files)
    if (is.null(tb)) return(NULL)
    mutate(tb, site = str_remove(basename(folder), "^output_?"), .before = 1)
  }) |>
    list_rbind()

  if (is.null(predictions) || nrow(predictions) == 0) {
    stop("No prediction read - were all the tables found empty?")
  }
  check_confidence(predictions$confidence, "Confidence")
  if (!is.null(site_pattern)) {
    predictions$site <- site_from_name(predictions$begin_path, site_pattern)
  }
  message(nrow(predictions), " predictions read from ",
          n_distinct(predictions$site), " site(s).")
  predictions
}

#' List the selection tables of each folder
#'
#' Takes the combined table of a folder when there is one, otherwise its
#' per-audio tables.
#'
#' @param data_dir Character scalar, root folder searched recursively.
#' @param table_pattern Character scalar, regular expression for the file
#'   names of combined tables.
#' @param per_audio_pattern Character scalar or `NULL`, regular expression for
#'   the file names of per-audio tables.
#' @return A list named by folder, each element a character vector of table
#'   paths, ordered by folder name.
#' @noRd
find_selection_tables <- function(data_dir, table_pattern, per_audio_pattern) {
  combined <- list.files(data_dir, pattern = table_pattern,
                         recursive = TRUE, full.names = TRUE)
  per_audio <- if (is.null(per_audio_pattern)) character() else
    list.files(data_dir, pattern = per_audio_pattern,
               recursive = TRUE, full.names = TRUE)
  per_audio <- setdiff(per_audio, combined)

  combined_dirs <- dirname(combined)
  ignored <- per_audio[dirname(per_audio) %in% combined_dirs]
  if (length(ignored) > 0) {
    message(length(ignored), " per-audio table(s) ignored in folder(s) ",
            "that also hold a combined table: ",
            paste(unique(dirname(ignored)), collapse = ", "))
  }
  per_audio <- setdiff(per_audio, ignored)

  sources <- c(split(combined, combined_dirs),
               split(sort(per_audio), dirname(sort(per_audio))))
  if (length(sources) == 0) return(sources)

  message(length(combined), " combined table(s) and ", length(per_audio),
          " per-audio table(s) found in ", length(sources), " folder(s):")
  iwalk(sources, \(x, folder) message("  - ", folder, ": ",
                                     if (length(x) == 1) basename(x) else
                                       paste(length(x), "per-audio tables")))
  sources[order(names(sources))]
}

#' Read the selection tables of one folder
#'
#' Reads one combined table, or stacks several per-audio tables with the
#' `selection` column renumbered, as in the combined table. Empty files are
#' skipped with a warning.
#'
#' @param files Character vector of table paths from one folder.
#' @return A tibble of predictions, or `NULL` when every file is empty.
#' @noRd
read_site_tables <- function(files) {
  empty <- file.size(files) == 0
  if (any(empty)) {
    warning("Empty table(s) skipped: ",
            paste(files[empty], collapse = ", "))
  }
  files <- files[!empty]
  if (length(files) == 0) return(NULL)
  if (length(files) == 1) return(read_selection_table(files))

  # read everything as text and convert afterwards: a table without
  # predictions has only the header, and readr would guess other types for it
  tb <- map(files, read_selection_table, as_text = TRUE) |>
    list_rbind() |>
    type_convert(col_types = cols(), na = c("", "NA"))
  if ("selection" %in% names(tb)) tb$selection <- seq_len(nrow(tb))
  tb
}

#' Read one selection table and standardise its column names
#'
#' Names become lower case, without units or punctuation, with spaces
#' replaced by `_`.
#'
#' @param path Character scalar, path to a tab-separated selection table.
#' @param as_text Logical scalar; if `TRUE`, read every column as character.
#' @return A tibble with standardised column names; errors when a required
#'   column is missing.
#' @noRd
read_selection_table <- function(path, as_text = FALSE) {
  tb <- read_tsv(path, show_col_types = FALSE,
                 col_types = if (as_text) cols(.default = col_character()),
                 na = c("", "NA"), progress = FALSE)

  col_names <- names(tb) |>
    str_to_lower() |>
    str_remove_all("\\((s|hz)\\)") |>
    str_trim() |>
    str_replace_all("[^a-z0-9]+", "_") |>
    str_remove("_$")
  names(tb) <- col_names

  required <- c("begin_time", "end_time", "species_code",
                "confidence", "begin_path", "file_offset")
  absent <- setdiff(required, names(tb))
  if (length(absent) > 0) {
    stop("Table ", path, " lacks the columns: ",
         paste(absent, collapse = ", "),
         "\nColumns found: ", paste(names(tb), collapse = ", "))
  }
  tb
}
