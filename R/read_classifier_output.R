#' Read the predictions of other classifiers
#'
#' Reads the prediction files of classifiers other than BirdNET and returns
#' them in the shape of [read_selection_tables()], so that they can go to
#' [select_clips()], [select_directed()], [threshold_history()],
#' [export_occupancy_data()] and [score_detections()].
#'
#' @section Formats:
#'
#' **`"perch"`**: the inference CSV of Perch, written by
#' `write_inference_csv()` of perch-hoplite (`perch_hoplite.agile.classifier`)
#' or of the earlier perch repository (`chirp.inference.classify`). One row
#' per window and label whose logit exceeds the threshold chosen when the
#' file was written. Three headers are recognised:
#'
#' | Header | Writer |
#' |---|---|
#' | `idx,project,filename,window_start,window_end,label,logits` | perch-hoplite, from December 2025 |
#' | `idx,dataset_name,source_id,offset,label,logits` | perch-hoplite, 2025 |
#' | `filename, timestamp_s, label, logit` | perch (chirp) |
#'
#' The file of the audio (`filename` or `source_id`) is relative to the
#' folder the embeddings were computed from: give that folder in
#' `audio_root`. The two older headers do not store the end of the window,
#' which is taken as the start plus `window_s` seconds (5 s, the window of
#' the Perch models).
#'
#' **`"opensoundscape"`**: the table returned by `predict()` of an
#' OpenSoundscape model (`CNN` or the models of the bioacoustics model zoo,
#' e.g. BirdNET and Perch) and saved with `to_csv()`: the columns `file`,
#' `start_time` and `end_time`, then one column of scores per class. Windows
#' whose scores are missing (audio that could not be read) are left out.
#'
#' @section Scores:
#'
#' sheepdog works with scores between 0 and 1, as BirdNET writes them.
#' Perch writes logits, and OpenSoundscape returns logits unless `predict()`
#' was called with `activation_layer = "sigmoid"` or `"softmax"`. Neither
#' file records the scale, so it is given in `score_scale`: with `"logit"`
#' (the default of both classifiers), `confidence` is the logistic function
#' of the score, `plogis(score)`; with `"probability"`, the score is used as
#' it is and must lie between 0 and 1. The calibration models work on the
#' logit of `confidence`, which for logits is the score itself, so no
#' information is lost. The original score is kept in `score`.
#'
#' Rows with `confidence` below `min_confidence` are left out (0.1, the
#' default minimum confidence of BirdNET). A Perch file already lacks the
#' windows below the logit threshold used to write it; a logit of 0 is a
#' confidence of 0.5.
#'
#' @section Sites and labels:
#'
#' The site is the folder that holds each audio file (`site_A/rec.wav`
#' gives `site_A`), or is taken from the file name with `site_pattern`, as
#' in [read_selection_tables()]. The date and hour of a recording are read
#' from its file name (`YYYYMMDD_HHMMSS`) by the functions downstream, as for
#' BirdNET.
#'
#' sheepdog names the folder of a species after the part of `species_code`
#' after the last underscore. Labels of other classifiers are names or codes
#' without that part, so `species_code` is built as the label and its
#' lower-case form with every run of other characters replaced by a hyphen:
#' `"Boana raniceps"` gives `"Boana raniceps_boana-raniceps"`, whose folder
#' is `boana_raniceps`. The label is kept in `label`.
#'
#' @param files Character vector of paths to prediction files (CSV), or to
#'   folders searched recursively for `.csv` files.
#' @param format Character scalar, one of `"perch"` or `"opensoundscape"`.
#' @param score_scale Character scalar, one of `"logit"` (default) or
#'   `"probability"`: the scale of the scores in the files.
#' @param min_confidence Numeric scalar in \[0, 1\]. Rows with a lower
#'   `confidence` are left out.
#' @param site_pattern `NULL` or character scalar, regular expression with
#'   one capture group that takes the site from the name of the audio file,
#'   as in [read_selection_tables()]. `NULL` takes the folder of the audio
#'   file.
#' @param audio_root `NULL` or character scalar, folder that relative audio
#'   paths are resolved against (for Perch, the folder the embeddings were
#'   computed from). Absolute paths and URLs are kept as they are.
#' @param window_s Numeric scalar > 0, length of the window in seconds,
#'   used for the Perch files that do not store its end.
#'
#' @return A tibble with one row per prediction: `site`, `begin_time`,
#'   `end_time`, `species_code`, `confidence`, `begin_path` and
#'   `file_offset` (the columns required by [select_clips()]), plus `label`,
#'   `score` (as in the file) and `classifier`.
#' @seealso [read_selection_tables()] for BirdNET, [read_pamdp()] for pamDP
#'   data packages.
#' @references
#' Ghani, B., Denton, T., Kahl, S. and Klinck, H. (2023). Global birdsong
#' embeddings enable superior transfer learning for bioacoustic
#' classification. *Scientific Reports*, 13, 22876.
#' \doi{10.1038/s41598-023-49989-z}
#'
#' Lapp, S., Rhinehart, T., Freeland-Haynes, L., Khilnani, J., Syunkova, A.
#' and Kitzes, J. (2023). OpenSoundscape: an open-source bioacoustics
#' analysis package for Python. *Methods in Ecology and Evolution*, 14(9),
#' 2321-2328. \doi{10.1111/2041-210X.14196}
#' @export
read_classifier_output <- function(files,
                                   format = c("perch", "opensoundscape"),
                                   score_scale = c("logit", "probability"),
                                   min_confidence = 0.1,
                                   site_pattern = NULL,
                                   audio_root = NULL,
                                   window_s = 5) {
  format <- match.arg(format)
  score_scale <- match.arg(score_scale)
  check_prob(min_confidence, "min_confidence")
  check_number(window_s, "window_s", 0, Inf, open = TRUE)
  if (!is.null(audio_root) &&
      (!is.character(audio_root) || length(audio_root) != 1)) {
    stop("`audio_root` must be NULL or a single path.", call. = FALSE)
  }
  paths <- classifier_files(files)

  reader <- switch(format, perch = read_perch_csv,
                   opensoundscape = read_opensoundscape_csv)
  preds <- map(paths, function(p) {
    reader(p, score_scale = score_scale, min_confidence = min_confidence,
           window_s = window_s)
  }) |>
    list_rbind()
  if (is.null(preds) || nrow(preds) == 0) {
    stop("No prediction at or above `min_confidence` = ", min_confidence,
         " in ", length(paths), " file(s).", call. = FALSE)
  }
  n_low <- sum(attr(preds, "n_low"), 0)

  preds$begin_path <- pamdp_resolve(preds$begin_path, audio_root)
  preds$site <- if (is.null(site_pattern)) {
    site_from_folder(preds$begin_path)
  } else {
    site_from_name(preds$begin_path, site_pattern)
  }
  out <- preds |>
    mutate(species_code = label_species_code(label),
           file_offset = begin_time, classifier = format) |>
    select(site, begin_time, end_time, species_code, confidence,
           begin_path, file_offset, label, score, classifier) |>
    arrange(site, begin_path, begin_time, species_code)
  message(nrow(out), " predictions read from ", length(paths), " file(s), ",
          n_distinct(out$site), " site(s) and ", n_distinct(out$label),
          " label(s).")
  out
}

#' List the prediction files to read
#'
#' @param files Character vector of file or folder paths.
#' @return Character vector of existing file paths, folders expanded to
#'   their `.csv` files (recursively), without duplicates.
#' @noRd
classifier_files <- function(files) {
  if (!is.character(files) || length(files) == 0 || anyNA(files)) {
    stop("`files` must be a character vector of paths.", call. = FALSE)
  }
  absent <- files[!file.exists(files)]
  if (length(absent) > 0) {
    stop("Not found: ", paste(absent, collapse = ", "), call. = FALSE)
  }
  is_dir <- dir.exists(files)
  found <- unlist(lapply(files[is_dir], list.files, pattern = "(?i)\\.csv$",
                         recursive = TRUE, full.names = TRUE))
  out <- unique(c(files[!is_dir], sort(found)))
  if (length(out) == 0) {
    stop("No .csv file found in ", paste(files, collapse = ", "),
         call. = FALSE)
  }
  out
}

#' Convert classifier scores to confidences in \[0, 1\]
#'
#' @param score Numeric vector of scores as written by the classifier.
#' @param score_scale Character scalar, `"logit"` or `"probability"`.
#' @param file Character scalar, file name for the messages.
#' @return Numeric vector of confidences, same length as `score`.
#' @noRd
score_to_confidence <- function(score, score_scale, file) {
  if (score_scale == "probability") {
    outside <- !is.na(score) & (score < 0 | score > 1)
    if (any(outside)) {
      stop(file, ": ", sum(outside), " score(s) outside 0 to 1 (e.g. ",
           signif(score[outside][1], 4), "); these look like logits, use ",
           "score_scale = \"logit\".", call. = FALSE)
    }
    return(score)
  }
  if (length(score) >= 10 && all(score >= 0 & score <= 1, na.rm = TRUE)) {
    message(file, ": every score lies between 0 and 1; if the classifier ",
            "applied a sigmoid or softmax, use score_scale = \"probability\".")
  }
  stats::plogis(score)
}

#' Read one Perch inference CSV
#'
#' Recognises the three headers written by `write_inference_csv()` of
#' perch-hoplite (current and 2025) and of perch (chirp).
#'
#' @param path Character scalar, path to the CSV.
#' @param score_scale Character scalar, `"logit"` or `"probability"`.
#' @param min_confidence Numeric scalar in \[0, 1\].
#' @param window_s Numeric scalar, window length for headers without its end.
#' @return A tibble with `begin_path`, `begin_time`, `end_time`, `label`,
#'   `score` and `confidence`, with the attribute `n_low` (rows below
#'   `min_confidence`).
#' @noRd
read_perch_csv <- function(path, score_scale, min_confidence, window_s) {
  raw <- read_csv(path, col_types = cols(.default = col_character()),
                  show_col_types = FALSE, progress = FALSE, trim_ws = TRUE)
  names(raw) <- str_trim(names(raw))
  num <- function(x) suppressWarnings(as.numeric(x))
  headers <- list(
    hoplite = c("filename", "window_start", "window_end", "label", "logits"),
    hoplite_2025 = c("source_id", "offset", "label", "logits"),
    chirp = c("filename", "timestamp_s", "label", "logit"))
  variant <- names(headers)[vapply(headers, function(h) all(h %in% names(raw)),
                                   logical(1))][1]
  if (is.na(variant)) {
    stop(path, " is not a Perch inference CSV: its header (",
         paste(names(raw), collapse = ", "), ") has none of the column ",
         "sets ", paste(vapply(headers, paste, "", collapse = ","),
                        collapse = " | "), ".", call. = FALSE)
  }
  tb <- switch(variant,
    hoplite = tibble(begin_path = raw$filename,
                     begin_time = num(raw$window_start),
                     end_time = num(raw$window_end),
                     label = raw$label, score = num(raw$logits)),
    hoplite_2025 = tibble(begin_path = raw$source_id,
                          begin_time = num(raw$offset),
                          end_time = num(raw$offset) + window_s,
                          label = raw$label, score = num(raw$logits)),
    chirp = tibble(begin_path = raw$filename,
                   begin_time = num(raw$timestamp_s),
                   end_time = num(raw$timestamp_s) + window_s,
                   label = raw$label, score = num(raw$logit)))
  bad <- is.na(tb$score) | is.na(tb$begin_time) | is.na(tb$label) |
    is.na(tb$begin_path)
  if (any(bad)) {
    message(sum(bad), " row(s) without a file, time, label or score left ",
            "out of ", path, ".")
    tb <- tb[!bad, ]
  }
  tb$confidence <- score_to_confidence(tb$score, score_scale, path)
  keep <- tb$confidence >= min_confidence
  structure(tb[keep, ], n_low = sum(!keep))
}

#' Read one OpenSoundscape prediction CSV
#'
#' The wide table of `predict()` (columns `file`, `start_time`, `end_time`
#' and one per class), filtered class by class so that the long table is
#' never built in full.
#'
#' @param path Character scalar, path to the CSV.
#' @param score_scale Character scalar, `"logit"` or `"probability"`.
#' @param min_confidence Numeric scalar in \[0, 1\].
#' @param window_s Unused; kept for a common signature with
#'   read_perch_csv().
#' @return A tibble with `begin_path`, `begin_time`, `end_time`, `label`,
#'   `score` and `confidence`, with the attribute `n_low`.
#' @noRd
read_opensoundscape_csv <- function(path, score_scale, min_confidence,
                                    window_s = NULL) {
  raw <- read_csv(path, show_col_types = FALSE, progress = FALSE,
                  col_types = cols(file = col_character(),
                                   .default = readr::col_double()))
  index <- c("file", "start_time", "end_time")
  absent <- setdiff(index, names(raw))
  if (length(absent) > 0) {
    stop(path, " is not an OpenSoundscape prediction table: it lacks ",
         paste(absent, collapse = ", "), ".", call. = FALSE)
  }
  classes <- setdiff(names(raw), index)
  if (length(classes) == 0) {
    stop(path, " has no class columns.", call. = FALSE)
  }
  failed <- is.na(raw$start_time) | is.na(raw$end_time) |
    rowSums(!is.na(as.matrix(raw[classes]))) == 0
  if (any(failed)) {
    message(sum(failed), " window(s) without scores (audio that could not ",
            "be read) left out of ", path, ".")
    raw <- raw[!failed, ]
  }
  all_scores <- unlist(raw[classes], use.names = FALSE)
  conf_all <- score_to_confidence(all_scores, score_scale, path)
  n_low <- sum(!is.na(conf_all) & conf_all < min_confidence)
  rm(all_scores, conf_all)
  tb <- map(classes, function(cl) {
    s <- raw[[cl]]
    conf <- suppressMessages(score_to_confidence(s, score_scale, path))
    keep <- !is.na(conf) & conf >= min_confidence
    if (!any(keep)) return(NULL)
    tibble(begin_path = raw$file[keep], begin_time = raw$start_time[keep],
           end_time = raw$end_time[keep], label = cl, score = s[keep],
           confidence = conf[keep])
  }) |>
    list_rbind()
  if (is.null(tb)) {
    tb <- tibble(begin_path = character(), begin_time = numeric(),
                 end_time = numeric(), label = character(), score = numeric(),
                 confidence = numeric())
  }
  structure(tb, n_low = n_low)
}

#' Build sheepdog species codes from classifier labels
#'
#' @param label Character vector of labels.
#' @return Character vector, same length: the label, an underscore and its
#'   lower-case form with runs of other characters replaced by a hyphen.
#' @noRd
label_species_code <- function(label) {
  slug <- str_replace_all(str_to_lower(str_squish(label)), "[^a-z0-9]+", "-")
  paste0(str_squish(label), "_", str_remove_all(slug, "^-+|-+$"))
}

#' Take the site from the folder of each audio file
#'
#' @param paths Character vector of audio paths.
#' @return Character vector of folder names, same length as `paths`.
#' @noRd
site_from_folder <- function(paths) {
  folders <- dirname(str_replace_all(paths, fixed("\\"), "/"))
  if (any(folders %in% c(".", "", "/"))) {
    stop("Some audio paths have no folder (e.g. ",
         paths[folders %in% c(".", "", "/")][1], "), so the site cannot ",
         "be taken from it; give `site_pattern`.", call. = FALSE)
  }
  basename(folders)
}
