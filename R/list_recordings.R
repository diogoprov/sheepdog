#' List every recording made, from the audio folders
#'
#' Builds the table of all recordings that `"random_recordings"` in
#' [select_clips()], [export_occupancy_data()] and [run_app()] take as
#' `recordings`, by listing the audio files under `audio_dir`. Unlike the
#' list that those functions build when `recordings = NULL`, it includes
#' the recordings of folders without any prediction, which the
#' multiple-method design and the occasions of the occupancy models need.
#'
#' The site of each recording is the first folder below `audio_dir`, so
#' both `audio_dir/<site>/<file>` and `audio_dir/<site>/<card or
#' date>/<file>` work. Files directly in `audio_dir` need `site`.
#'
#' The paths must match those in the `Begin Path` column of the selection
#' tables, because the recordings are matched to the predictions by path.
#' When the audio was analysed on another computer (for instance, from a
#' network drive mapped as `N:`), list the files where they are and rewrite
#' the prefix with `remap_from` and `remap_to`, or pass the same
#' `remap_from` and `remap_to` to [select_clips()] so that `Begin Path` is
#' rewritten to the local prefix instead. With `predictions`, the function
#' reports how many of the audio files of the predictions are in the list.
#'
#' File names are expected to carry the date and time as `YYYYMMDD_HHMMSS`,
#' as most recorders write them; the files whose names do not are reported.
#'
#' @param audio_dir Character scalar, path to the root folder of the audio
#'   files, searched recursively.
#' @param audio_pattern Character scalar, regular expression for the audio
#'   file names (case
#'   insensitive).
#' @param site `NULL` (the site is the first folder below `audio_dir`) or a
#'   character scalar, a single site name for every file.
#' @param site_pattern `NULL` or character scalar, regular expression with
#'   one capture group
#'   that takes the site from the file name, for recordings of several sites
#'   in the same folder. For example, `"^[^_]+_([^_]+)_"` reads `Campus01`
#'   from `Campinas_Campus01_20261003_074339.flac`. It replaces the folder
#'   rule and cannot be combined with `site`.
#' @param remap_from,remap_to `NULL` or character scalars. Replace the
#'   prefix `remap_from` of the listed
#'   paths by `remap_to`, e.g. `"/Volumes/NAS/"` and `"N:/"`, so that the
#'   paths match `Begin Path`. Backslashes are turned into forward slashes
#'   first.
#' @param predictions `NULL` or a data frame of predictions (one row per
#'   prediction) from
#'   [read_selection_tables()], to check that its audio files are in the
#'   list.
#' @param file `NULL` or character scalar, path of a CSV file to write the
#'   table to (e.g.
#'   `"recordings.csv"`).
#'
#' @return A tibble with `site` and `source_audio`, one row per recording,
#'   sorted by site and path (invisibly when `file` is given).
#' @seealso [select_clips()], `vignette("organising-data")`.
#' @export
#' @examples
#' audio <- file.path(tempdir(), "audio")
#' for (s in c("ARA", "BAI")) dir.create(file.path(audio, s), recursive = TRUE)
#' file.create(file.path(audio, "ARA", c("ARA01_20211001_190000.wav",
#'                                      "ARA01_20211001_200000.wav")))
#' file.create(file.path(audio, "BAI", "BAI01_20211001_190000.wav"))
#' list_recordings(audio)
list_recordings <- function(audio_dir,
                            audio_pattern = "\\.(wav|flac|mp3)$",
                            site = NULL, site_pattern = NULL,
                            remap_from = NULL, remap_to = NULL,
                            predictions = NULL, file = NULL) {
  if (!is.null(file)) file <- check_file_ext(file, "csv")
  if (!is.character(audio_dir) || length(audio_dir) != 1 ||
      !dir.exists(audio_dir)) {
    stop("`audio_dir` must be an existing folder.", call. = FALSE)
  }
  if (!is.null(site) && (!is.character(site) || length(site) != 1)) {
    stop("`site` must be NULL or a single site name.", call. = FALSE)
  }
  if (!is.null(site) && !is.null(site_pattern)) {
    stop("Give `site` or `site_pattern`, not both.", call. = FALSE)
  }
  rel_paths <- list.files(audio_dir, pattern = audio_pattern,
                          recursive = TRUE, ignore.case = TRUE)
  if (length(rel_paths) == 0) {
    stop("No audio file matching ", audio_pattern, " found in ", audio_dir,
         ".", call. = FALSE)
  }

  sites <- if (!is.null(site_pattern)) {
    site_from_name(rel_paths, site_pattern)
  } else if (is.null(site)) {
    parts <- strsplit(rel_paths, "/", fixed = TRUE)
    loose <- lengths(parts) == 1
    if (any(loose)) {
      stop(sum(loose), " audio file(s) directly in `audio_dir` (e.g. ",
           rel_paths[loose][1], "): put them in a folder per site or give ",
           "`site` or `site_pattern`.", call. = FALSE)
    }
    vapply(parts, `[`, character(1), 1)
  } else {
    site
  }
  root <- sub("/+$", "", str_replace_all(audio_dir, fixed("\\"), "/"))
  recordings <- tibble(
    site = sites,
    source_audio = remap_path(file.path(root, rel_paths), remap_from,
                              remap_to)
  ) |>
    arrange(site, source_audio)

  no_date <- is.na(
    parse_date_hour(basename(recordings$source_audio))$recording_date
  )
  if (any(no_date)) {
    warning(sum(no_date), " file name(s) without a date and time as ",
            "YYYYMMDD_HHMMSS (e.g. ",
            basename(recordings$source_audio[no_date][1]),
            "): their night and hour cannot be read.", call. = FALSE)
  }
  message(nrow(recordings), " recordings listed at ",
          n_distinct(recordings$site), " site(s).")

  if (!is.null(predictions)) {
    if (!"begin_path" %in% names(predictions)) {
      stop("`predictions` lacks the column begin_path; read it with ",
           "read_selection_tables().", call. = FALSE)
    }
    audio_files <- unique(
      str_replace_all(predictions$begin_path, fixed("\\"), "/")
    )
    absent <- setdiff(audio_files, recordings$source_audio)
    message(length(audio_files) - length(absent), " of ", length(audio_files),
            " audio files of the predictions are in the list.")
    if (length(absent) > 0) {
      warning(length(absent), " audio file(s) of the predictions are not in ",
              "the list, e.g. ", absent[1], ". Check `remap_from` and ",
              "`remap_to`.", call. = FALSE)
    }
  }

  if (!is.null(file)) {
    write_csv(recordings, file)
    return(invisible(recordings))
  }
  recordings
}
