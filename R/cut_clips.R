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
#' @param manifest Clip manifest, as returned by [select_clips()].
#' @param output_dir Output folder; created if needed.
#' @param simulate If `TRUE`, no audio is cut (the empty species folders
#'   are still created), but `status` tells what would be done. Useful to
#'   check a selection before cutting.
#'
#' @return The manifest with the column `status` after `begin_path`: one of
#'   `"ok"`, `"already_exists"`, `"audio_not_found"`, `"simulated"` or
#'   `"error: <message>"`.
#' @export
cut_clips <- function(manifest, output_dir, simulate = FALSE) {
  if (!simulate) require_suggested("av", "to cut the clips")
  dir_clipes <- file.path(output_dir, "clips")
  dir.create(dir_clipes, recursive = TRUE, showWarnings = FALSE)

  destino <- file.path(dir_clipes, manifest$species_folder, manifest$clip_file)
  walk(unique(dirname(destino)),
       dir.create, recursive = TRUE, showWarnings = FALSE)

  processar_linha <- function(origem, destino, inicio, duracao, herdado) {
    if (herdado)                    return("inherited")
    if (file.exists(destino))       return("already_exists")
    if (!file.exists(origem))       return("audio_not_found")
    if (simulate)                   return("simulated")
    tryCatch({
      cut_clip(origem, destino, inicio, duracao)
      "ok"
    }, error = function(e) paste0("error: ", conditionMessage(e)))
  }

  message(if (simulate) "Simulating the cut of " else "Cutting ",
          nrow(manifest), " clips...")

  manifest$status <- pmap_chr(
    list(manifest$source_audio, destino,
         manifest$clip_start, manifest$duration, is_inherited(manifest)),
    processar_linha,
    .progress = "clips"
  )

  contagem <- count(manifest, status)
  message(paste0("  ", contagem$status, ": ", contagem$n, collapse = "\n"))
  if (any(str_starts(manifest$status, "error|audio_not"))) {
    warning("Some clips were not created - check the `status` column of ",
            "the manifest and the path remapping (remap_from/remap_to).")
  }
  relocate(manifest, status, .after = begin_path)
}

# Corta um clipe com o ffmpeg embutido no pacote 'av' (duracao NA = ate o
# fim do arquivo)
cut_clip <- function(origem, destino, inicio, duracao) {
  av::av_audio_convert(origem, destino,
                       start_time = inicio,
                       total_time = if (is.na(duracao)) NULL else duracao,
                       verbose = FALSE)
}

#' Pack the clips into one zip per species
#'
#' Zips each species folder of `<output_dir>/clips` into
#' `<output_dir>/packages/<species_folder>.zip`: light validation packages
#' to send to the reviewers.
#'
#' @param manifest Clip manifest, as returned by [cut_clips()].
#' @param output_dir The `output_dir` given to [cut_clips()].
#'
#' @return The paths of the zip files, invisibly.
#' @export
pack_clips <- function(manifest, output_dir) {
  dir_clipes  <- file.path(output_dir, "clips")
  dir_pacotes <- file.path(output_dir, "packages")
  dir.create(dir_pacotes, recursive = TRUE, showWarnings = FALSE)

  especies <- sort(unique(manifest$species_folder))
  zips <- map_chr(especies, function(sp) {
    zip_sp <- file.path(dir_pacotes, paste0(sp, ".zip"))
    zip::zip(zipfile = zip_sp, files = sp, root = dir_clipes,
             mode = "mirror")
    message("Package ", basename(zip_sp), ": ",
            round(file.size(zip_sp) / 1024^2, 1), " MB")
    zip_sp
  })
  message(length(especies), " validation package(s) in ", dir_pacotes)
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
#' @param ... Sampling design, passed to [select_clips()] (e.g.
#'   `sampling_mode`, `n_top`, `threshold`, `target_total`, `remap_from`,
#'   `remap_to`, and `previous` for a further round, in a new `output_dir`).
#' @param make_zip Zip one package per species (skipped when `simulate` is
#'   `TRUE`).
#' @param classifier Label of the classifier that produced the selection
#'   tables (e.g. `"FrogNet v2, BirdNET-Analyzer 2.4.0"`), recorded in
#'   `extraction_info.csv`. `NULL` records `NA`.
#'
#' @return The manifest written to `clip_manifest.csv`, invisibly.
#' @export
#' @examples
#' \dontrun{
#' # Check the selection first, then cut
#' extract_validation_clips("N:/Arara", "N:/Arara/validation",
#'                          remap_from = "N:/", remap_to = "/Volumes/Arara/",
#'                          simulate = TRUE)
#' }
extract_validation_clips <- function(data_dir, output_dir, ...,
                                     table_pattern = "^BirdNET_SelectionTable\\.txt$",
                                     per_audio_pattern = "\\.BirdNET\\.selection\\.table\\.txt$",
                                     site_pattern = NULL,
                                     make_zip = TRUE, simulate = FALSE,
                                     classifier = NULL) {
  caminho <- file.path(output_dir, "clip_manifest.csv")
  anteriores <- list(...)$previous
  if (is.character(anteriores) && file.exists(caminho) &&
      normalizePath(caminho) %in% normalizePath(anteriores, mustWork = FALSE)) {
    stop("`output_dir` holds the manifest of an earlier round: use another ",
         "folder for this round.", call. = FALSE)
  }
  selecao <- read_selection_tables(data_dir, table_pattern,
                                   per_audio_pattern, site_pattern) |>
    select_clips(...)
  candidatas <- attr(selecao, "candidates")
  manifesto <- cut_clips(selecao, output_dir, simulate = simulate)

  write_csv(manifesto, caminho)
  message("Manifest written to ", caminho)
  if (!is.null(candidatas)) {
    write_csv(candidatas, file.path(output_dir, "candidates.csv"))
  }
  write_csv(extraction_info(data_dir, classifier, simulate, list(...)),
            file.path(output_dir, "extraction_info.csv"))

  if (make_zip && !simulate) pack_clips(manifesto, output_dir)

  message("Done! The clips in ", file.path(output_dir, "clips"),
          " are ready for validation in the BirdNET GUI (review).")
  invisible(manifesto)
}

# Proveniencia da rodada de extracao: uma linha chave/valor por item
extraction_info <- function(data_dir, classifier, simulate, args) {
  valor <- function(x) {
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
                         value = map_chr(args, valor)))
}
