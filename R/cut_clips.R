#' Cut the selected clips
#'
#' Cuts each clip of the manifest from its source recording into
#' `<output_dir>/clips/<species_folder>/<clip_file>`, one folder per species,
#' ready for the review tab of the BirdNET GUI. Clips that already exist are
#' not cut again, so an interrupted run resumes where it stopped. Missing or
#' unreadable recordings do not stop the run; they are flagged in `status`.
#'
#' Cutting uses the 'ffmpeg' library bundled with the 'av' package.
#'
#' @param manifest A data frame, the clip manifest (one row per clip), as
#'   returned by [select_clips()].
#' @param output_dir Character scalar, path to the output folder; created if
#'   needed.
#' @param simulate Logical scalar. If `TRUE`, no audio is cut (the empty
#'   species folders
#'   are still created), but `status` tells what would be done. Useful to
#'   check a selection before cutting.
#'
#' @return The manifest with the column `status` after `begin_path`: one of
#'   `"ok"`, `"already_exists"`, `"audio_not_found"`, `"simulated"` or
#'   `"error: <message>"`.
#' @export
cut_clips <- function(manifest, output_dir, simulate = FALSE) {
  if (!simulate) require_suggested("av", "to cut the clips")
  clips_dir <- file.path(output_dir, "clips")
  dir.create(clips_dir, recursive = TRUE, showWarnings = FALSE)

  dest <- file.path(clips_dir, manifest$species_folder, manifest$clip_file)
  walk(unique(dirname(dest)),
       dir.create, recursive = TRUE, showWarnings = FALSE)

  process_row <- function(src, dest, start, duration, inherited) {
    if (inherited)                  return("inherited")
    if (file.exists(dest))          return("already_exists")
    if (!file.exists(src))          return("audio_not_found")
    if (simulate)                   return("simulated")
    tryCatch({
      cut_clip(src, dest, start, duration)
      "ok"
    }, error = function(e) paste0("error: ", conditionMessage(e)))
  }

  message(if (simulate) "Simulating the cut of " else "Cutting ",
          nrow(manifest), " clips...")

  manifest$status <- pmap_chr(
    list(manifest$source_audio, dest,
         manifest$clip_start, manifest$duration, is_inherited(manifest)),
    process_row,
    .progress = "clips"
  )

  counts <- count(manifest, status)
  message(paste0("  ", counts$status, ": ", counts$n, collapse = "\n"))
  if (any(str_starts(manifest$status, "error|audio_not"))) {
    warning("Some clips were not created - check the `status` column of ",
            "the manifest and the path remapping (remap_from/remap_to).")
  }
  relocate(manifest, status, .after = begin_path)
}

#' Cut one clip with the ffmpeg bundled in the 'av' package
#'
#' @param src Character scalar, path to the source recording.
#' @param dest Character scalar, path to the clip to write.
#' @param start Numeric scalar, clip start in seconds.
#' @param duration Numeric scalar, clip duration in seconds; `NA` cuts to
#'   the end of the file.
#' @return Called for its side effect (writes `dest`); returns the value of
#'   [av::av_audio_convert()].
#' @noRd
cut_clip <- function(src, dest, start, duration) {
  av::av_audio_convert(src, dest,
                       start_time = start,
                       total_time = if (is.na(duration)) NULL else duration,
                       verbose = FALSE)
}

#' Pack the clips into one zip per species
#'
#' Zips each species folder of `<output_dir>/clips` into
#' `<output_dir>/packages/<species_folder>.zip`: light validation packages
#' to send to the reviewers.
#'
#' @param manifest A data frame, the clip manifest (one row per clip), as
#'   returned by [cut_clips()].
#' @param output_dir Character scalar, the `output_dir` given to
#'   [cut_clips()].
#'
#' @return The paths of the zip files, invisibly.
#' @export
pack_clips <- function(manifest, output_dir) {
  clips_dir    <- file.path(output_dir, "clips")
  packages_dir <- file.path(output_dir, "packages")
  dir.create(packages_dir, recursive = TRUE, showWarnings = FALSE)

  species <- sort(unique(manifest$species_folder))
  zips <- map_chr(species, function(sp) {
    zip_sp <- file.path(packages_dir, paste0(sp, ".zip"))
    zip::zip(zipfile = zip_sp, files = sp, root = clips_dir,
             mode = "mirror")
    message("Package ", basename(zip_sp), ": ",
            round(file.size(zip_sp) / 1024^2, 1), " MB")
    zip_sp
  })
  message(length(species), " validation package(s) in ", packages_dir)
  invisible(zips)
}

#' Build the validation clip set
#'
#' Runs the whole first stage: reads the selection tables, selects the
#' clips, cuts them, writes `clip_manifest.csv` and zips one package per
#' species. This is the function form of the v1.2.0 script
#' `extrair_clipes_validacao.R`.
#'
#' Output structure:
#' ```
#' <output_dir>/clips/<species_folder>/*.wav
#' <output_dir>/packages/<species_folder>.zip
#' <output_dir>/clip_manifest.csv
#' <output_dir>/extraction_info.csv
#' <output_dir>/candidates.csv
#' ```
#'
#' `extraction_info.csv` records the provenance of the run (one `key`,
#' `value` row per item): the date, the versions of sheepdog and R, the
#' folder of the selection tables, the `classifier` label and every
#' argument passed to [select_clips()]. Keep it with the manifest: it tells
#' later rounds which classifier produced the clips (for instance, to leave
#' out of a validation round the clips used to retrain that classifier).
#'
#' `candidates.csv` (`"random_detections"`) lists the candidate occasions
#' with their stratum: later rounds draw from it and [combine_rounds()]
#' reads it, so keep it with the manifest.
#'
#' @inheritParams read_selection_tables
#' @inheritParams cut_clips
#' @param ... Further arguments passed to [select_clips()]: the sampling
#'   design (e.g.
#'   `sampling_mode`, `n_top`, `threshold`, `target_total`, `remap_from`,
#'   `remap_to`, and `previous` for a further round, in a new `output_dir`).
#' @param make_zip Logical scalar. If `TRUE`, zip one package per species
#'   (skipped when `simulate` is
#'   `TRUE`).
#' @param classifier `NULL` or character scalar, label of the classifier
#'   that produced the selection
#'   tables (e.g. `"DiverSons v2, BirdNET-Analyzer 2.4.0"`), recorded in
#'   `extraction_info.csv`. `NULL` records `NA`.
#'
#' @return The manifest written to `clip_manifest.csv`, invisibly.
#' @export
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' # Check the selection first (no audio is read), then cut
#' man <- extract_validation_clips(file.path(ex, "birdnet"),
#'                                 file.path(tempdir(), "validation"),
#'                                 simulate = TRUE)
#' table(man$status)
extract_validation_clips <- function(data_dir, output_dir, ...,
                                     table_pattern = "^BirdNET_SelectionTable\\.txt$",
                                     per_audio_pattern = "\\.BirdNET\\.selection\\.table\\.txt$",
                                     site_pattern = NULL,
                                     make_zip = TRUE, simulate = FALSE,
                                     classifier = NULL) {
  manifest_path <- file.path(output_dir, "clip_manifest.csv")
  previous <- list(...)$previous
  if (is.character(previous) && file.exists(manifest_path) &&
      normalizePath(manifest_path) %in%
        normalizePath(previous, mustWork = FALSE)) {
    stop("`output_dir` holds the manifest of an earlier round: use another ",
         "folder for this round.", call. = FALSE)
  }
  selection <- read_selection_tables(data_dir, table_pattern,
                                     per_audio_pattern, site_pattern) |>
    select_clips(...)
  candidates <- attr(selection, "candidates")
  manifest <- cut_clips(selection, output_dir, simulate = simulate)

  write_csv(manifest, manifest_path)
  message("Manifest written to ", manifest_path)
  if (!is.null(candidates)) {
    write_csv(candidates, file.path(output_dir, "candidates.csv"))
  }
  write_csv(extraction_info(data_dir, classifier, simulate, list(...)),
            file.path(output_dir, "extraction_info.csv"))

  if (make_zip && !simulate) pack_clips(manifest, output_dir)

  message("Done! The clips in ", file.path(output_dir, "clips"),
          " are ready for validation in the BirdNET GUI (review).")
  invisible(manifest)
}

#' Provenance of an extraction run
#'
#' @param data_dir Character scalar, folder of the selection tables.
#' @param classifier Character scalar or `NULL`, label of the classifier.
#' @param simulate Logical scalar, whether the cut was simulated.
#' @param args Named list of the arguments passed to [select_clips()].
#' @return A tibble with character columns `key` and `value`, one row per
#'   item.
#' @noRd
extraction_info <- function(data_dir, classifier, simulate, args) {
  as_value <- function(x) {
    if (is.null(x)) return("NULL")
    if (is.data.frame(x)) return(paste0("<data frame, ", nrow(x), " rows>"))
    paste(format(x), collapse = ", ")
  }
  base <- tibble(
    key = c("date", "sheepdog_version", "r_version", "data_dir",
            "classifier", "simulate"),
    value = c(format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
              as.character(utils::packageVersion("sheepdog")),
              paste(R.version$major, R.version$minor, sep = "."),
              data_dir, if (is.null(classifier)) NA_character_ else classifier,
              as.character(simulate)))
  if (length(args) == 0) return(base)
  bind_rows(base, tibble(key = paste0("select_clips.", names(args)),
                         value = map_chr(args, as_value)))
}
