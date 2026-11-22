#' Classify the reviewed clips
#'
#' Reads the result of the manual review done in the BirdNET GUI and joins
#' it to the clip manifest. The GUI organises the review by moving each
#' clip into subfolders such as `<species>/Positive` and
#' `<species>/Negative`, so the verdict of each clip comes from the path
#' where it is found. Clips still in the species folder are not reviewed.
#'
#' @param manifest A data frame (or tibble) or a character scalar. The clip
#'   manifest, one row per clip, or the path to `clip_manifest.csv`.
#'   Manifests written by v1.2.0 (`manifesto_clipes.csv`) are also read.
#' @param review_dir Character scalar, path to the folder with the reviewed
#'   clips (the `clips` folder of the validation package, after the review).
#' @param positive_pattern,negative_pattern Character scalars, regular
#'   expressions (case-insensitive) that identify the positive and negative
#'   folders in the path of each clip.
#'
#' @return The manifest with two more columns: `verdict` (`"positive"`,
#'   `"negative"`, `"not_reviewed"` or `"clip_missing"`) and
#'   `reviewed_path`, the path where the clip was found. This is the table
#'   written to `validation_by_clip.csv`.
#' @examples
#' # The review in the BirdNET GUI leaves each clip in a Positive or Negative
#' # subfolder. Recreate that layout with empty files from a reviewed table
#' man <- system.file("extdata", "clip_manifest.csv", package = "sheepdog")
#' done <- read.csv(system.file("extdata", "validation_by_clip.csv",
#'                              package = "sheepdog"))
#' review_dir <- file.path(tempdir(), "clips_reviewed")
#' sub <- ifelse(done$verdict == "positive", "Positive",
#'               ifelse(done$verdict == "negative", "Negative", ""))
#' dest <- file.path(review_dir, done$species_folder, sub)
#' for (d in unique(dest)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
#' invisible(file.create(file.path(dest, done$clip_file)))
#'
#' val <- classify_review(man, review_dir)
#' table(val$verdict)
#' unlink(review_dir, recursive = TRUE)
#' @export
classify_review <- function(manifest, review_dir,
                            positive_pattern = "positiv",
                            negative_pattern = "negativ") {
  clip_tbl <- read_manifest(manifest)

  wavs <- list.files(review_dir, pattern = "\\.wav$",
                     recursive = TRUE, full.names = TRUE)
  if (length(wavs) == 0) stop("No .wav found in ", review_dir)

  # the verdict comes only from the subfolders below review_dir (on
  # Windows dirname() turns \\ into /, so the slashes are matched first)
  root <- chartr("\\", "/", review_dir)
  review <- tibble(reviewed_path = wavs) |>
    mutate(
      clip_file = basename(reviewed_path),
      subfolder = str_remove(chartr("\\", "/", dirname(reviewed_path)),
                            fixed(root)),
      verdict   = case_when(
        str_detect(subfolder, regex(positive_pattern, ignore_case = TRUE)) ~ "positive",
        str_detect(subfolder, regex(negative_pattern, ignore_case = TRUE)) ~ "negative",
        .default = "not_reviewed"
      )
    )

  result <- clip_tbl |>
    left_join(select(review, clip_file, verdict, reviewed_path),
              by = "clip_file") |>
    mutate(verdict = replace_na(verdict, "clip_missing")) |>
    fill_inherited()

  tally <- count(result, verdict)
  message("Clips in the manifest: ", nrow(clip_tbl), "\n",
          paste0("  ", tally$verdict, ": ", tally$n, collapse = "\n"))
  if (any(duplicated(review$clip_file))) {
    warning("There are duplicated clip names in the review folder - check ",
            "for copies in more than one subfolder.")
  }
  result
}

#' Read a clip manifest
#'
#' Accepts a data frame or a CSV path, also in the v1.2.0 format.
#'
#' @param manifest A data frame, or character scalar with the path to a
#'   CSV file.
#' @return A tibble with the current column names, a `night` column when
#'   `recording_date` exists, and a numeric `confidence`.
#' @noRd
read_manifest <- function(manifest) {
  if (is.character(manifest)) {
    path <- manifest
    if (!file.exists(path)) {
      stop("`manifest` not found: ", path, call. = FALSE)
    }
    # 0-byte file or header only: incomplete copy
    empty <- file.size(path) == 0
    if (!empty) {
      manifest <- read_csv(path, show_col_types = FALSE)
      empty <- nrow(manifest) == 0
    }
    if (empty) {
      stop("`manifest` is empty (0 rows): ", path,
           ". Check that the file was copied correctly.", call. = FALSE)
    }
  }
  clip_tbl <- from_legacy(manifest)
  # old manifests lack the 'night' column
  if (!"night" %in% names(clip_tbl) &&
      "recording_date" %in% names(clip_tbl)) {
    clip_tbl$night <- clip_tbl$recording_date
  }
  # in mode "random_recordings" the column is all NA (read as logical)
  if (!"confidence" %in% names(clip_tbl)) clip_tbl$confidence <- NA_real_
  clip_tbl$confidence <- as.numeric(clip_tbl$confidence)
  clip_tbl
}

#' Reviewed clips with a positive or negative verdict and a confidence
#'
#' Entry routine of the threshold functions (as_input_table()). Whole
#' recordings (mode "random_recordings") stay out of the precision and the
#' thresholds. A missing confidence marks such a clip, so it is not a
#' missing value; only when the table says how each clip was drawn
#' (`sampling_mode`) are the other clips without a confidence missing
#' values, which follow missing_policy().
#'
#' @param validation A data frame of reviewed clips with `verdict` and
#'   `confidence`.
#' @param arg Character scalar, argument name used in the messages.
#' @param quiet Logical scalar; if `TRUE`, skips the missing-value policy
#'   for clips without confidence.
#' @return A tibble of the positive and negative clips with a confidence.
#' @noRd
reviewed_with_confidence <- function(validation, arg = "validation",
                                     quiet = FALSE) {
  val <- as_input_table(validation, c("verdict", "confidence"), arg,
                        numeric = c("confidence", "inclusion_prob"))
  val <- filter(val, verdict %in% c("positive", "negative"))
  if (!quiet && "sampling_mode" %in% names(val)) {
    is_rec <- val$sampling_mode %in% "random_recordings"
    val <- bind_rows(val[is_rec, ],
                     drop_missing(val[!is_rec, ], "confidence", arg,
                                  allow_empty = TRUE))
  }
  filter(val, !is.na(confidence))
}

#' Whether a table has inclusion probabilities
#'
#' True for clips of "random_detections" and the other probability
#' designs.
#'
#' @param validation A data frame of reviewed clips.
#' @return Logical scalar, `TRUE` if `inclusion_prob` exists and is not
#'   all missing.
#' @noRd
has_inclusion_prob <- function(validation) {
  "inclusion_prob" %in% names(validation) &&
    any(!is.na(validation$inclusion_prob))
}

#' Precision weighted by 1 / inclusion_prob
#'
#' Ratio estimator; `NA` when some clip of the group has no inclusion
#' probability (clips of "top").
#'
#' @param verdict Character vector of verdicts.
#' @param prob Numeric vector of inclusion probabilities, same length.
#' @return Numeric scalar in \[0, 1\], or `NA`.
#' @noRd
weighted_precision <- function(verdict, prob) {
  prob <- as.numeric(prob)
  if (anyNA(prob)) return(NA_real_)
  w <- 1 / prob
  sum(w[verdict == "positive"]) / sum(w)
}

#' Kish effective sample size with weights 1 / inclusion_prob
#'
#' @param prob Numeric vector of inclusion probabilities in (0, 1\].
#' @return Numeric scalar.
#' @noRd
kish_n <- function(prob) {
  w <- 1 / as.numeric(prob)
  sum(w)^2 / sum(w^2)
}

#' Precision by confidence bin
#'
#' Precision (share of positive verdicts) of the reviewed clips, by site,
#' species and confidence bin. Clips without confidence (whole recordings
#' of `"random_recordings"`) are left out.
#'
#' When `validation` has `inclusion_prob` (clips drawn with
#' `"random_detections"` in [select_clips()]), the table also gets
#' `precision_weighted`, the precision weighted by `1 / inclusion_prob`.
#' It estimates the precision among all the predictions of the bin from
#' which the clips were drawn, not only among the reviewed ones; the two
#' differ when the clips of a bin come from strata drawn with different
#' probabilities. It is `NA` in bins with any clip without
#' `inclusion_prob` (clips of `"top"`). A blind review manifest may lack
#' `inclusion_prob`: join it back from the full manifest first.
#'
#' @param validation A data frame (or tibble) returned by [classify_review()],
#'   with columns `site`, `species_folder`, `verdict` and `confidence`. One
#'   row per clip.
#' @param bins Numeric vector of length >= 2, increasing breaks of the
#'   confidence bins (left-closed).
#' @param min_n Integer scalar >= 1. Minimum of reviewed clips for a bin to
#'   be taken seriously; bins with fewer are flagged in `low_support`.
#' @param by `NULL` or a character vector of column names of `validation`
#'   that split each site x species cell further, e.g. the bin of an
#'   environmental gradient or of an acoustic index joined from
#'   [covariate_bins()]. They show which
#'   parts of the gradient lack reviewed clips.
#'
#' @return A tibble with `site`, `species_folder`, the `by` columns, `bin`,
#'   `n_reviewed`, `n_positive`, `precision`, `precision_weighted` (only
#'   with `inclusion_prob`) and `low_support`.
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read_validation_tables(list.files(file.path(ex, "validation"),
#'                                          full.names = TRUE))
#' prec <- precision_by_bin(val, min_n = 10)
#' head(prec)
#' @export
precision_by_bin <- function(validation, bins = seq(0.1, 1, by = 0.1),
                             min_n = 15, by = NULL) {
  check_by(validation, by)
  val <- reviewed_with_confidence(validation)
  has_weights <- has_inclusion_prob(val)
  if (!has_weights) val$inclusion_prob <- NA_real_
  out <- val |>
    mutate(bin = cut(confidence, breaks = bins,
                     include.lowest = TRUE, right = FALSE)) |>
    group_by(site, species_folder, across(all_of(by)), bin) |>
    summarise(n_reviewed = n(),
              n_positive = sum(verdict == "positive"),
              precision  = n_positive / n_reviewed,
              precision_weighted = weighted_precision(verdict,
                                                      inclusion_prob),
              .groups = "drop") |>
    mutate(low_support = n_reviewed < min_n)
  if (!has_weights) out$precision_weighted <- NULL
  out
}

#' Suggest a confidence threshold per species
#'
#' For each site and species (and each level of the `by` columns), the
#' lowest confidence `c` such that the
#' precision among the reviewed clips with confidence >= `c` reaches
#' `target_precision`, with at least `min_n` clips. Candidate cuts are the
#' observed confidences rounded to two decimals.
#'
#' **Sustained target.** With `sustained = TRUE`, the target must also hold
#' at every higher cut with at least `min_n` clips, the rule of
#' [calibrated_thresholds()]. This is not the default: the curve of the model
#' is smooth, while the empirical precision of a high cut rests on few clips,
#' so a cut can fail by chance, and the failure of the highest supported cut
#' leaves the cell without a threshold. In a simulation with 300 clips per
#' cell, the share of cells without a threshold rose from 0.09 to 0.24, and
#' the true precision of the cuts from 0.888 to 0.896
#' (`dev/sustained-threshold-rule.R`).
#'
#' **Point or conservative threshold.** The threshold is an estimate from a
#' sample of clips. It is nearly unbiased, but its sampling variation is
#' large: a new sample of the same size would often give a lower cut, whose
#' true precision misses the target. For the threshold that is actually
#' applied, use `threshold_conservative` of [threshold_bootstrap()], which
#' meets the target in about `conf` of the bootstrap replicates, at the cost
#' of a higher cut and some recall.
#'
#' The precision is computed from the reviewed clips of each cell alone, so
#' it is reliable only when the clips were drawn at random within the cell
#' and are numerous. [calibrated_thresholds()] derives the thresholds from
#' the calibration model of stage 2 instead.
#'
#' **Design weights.** Clips of `"random_detections"` have unequal
#' `inclusion_prob`: quiet strata are reviewed almost in full and choruses
#' lightly. The plain share of positive clips then estimates the precision
#' of the reviewed sample, not that of the predictions kept by the cut. So,
#' by default, a cell whose clips all have `inclusion_prob` is judged by the
#' precision weighted by `1 / inclusion_prob`, as in [precision_by_bin()],
#' and `min_n` applies to Kish's effective sample size,
#' \eqn{(\sum w)^2 / \sum w^2}, so that a cut resting on a few heavily
#' weighted clips is not accepted. With equal inclusion probabilities, both
#' choices give the same threshold. The weights cost variance: when
#' precision does not vary between strata, the unweighted estimate is also
#' unbiased and less variable (`weighted = FALSE`).
#'
#' A cell that mixes clips with and without `inclusion_prob` (`"top"` and
#' `"random_detections"`, say) cannot be weighted: it gets the unweighted
#' precision, with a warning, since `"top"` clips are not a probability
#' sample and should not set thresholds.
#'
#' @inheritParams precision_by_bin
#' @param target_precision Numeric scalar in (0, 1). Target precision.
#' @param weighted `NULL`, `TRUE` or `FALSE`. Which precision chooses the
#'   cut. `NULL` (default): the
#'   weighted one in the cells whose clips all have `inclusion_prob`, the
#'   unweighted one elsewhere. `TRUE`: always the weighted one; cells with
#'   clips without `inclusion_prob` get no threshold, with a warning, and
#'   it is an error if no clip has it. `FALSE`: always the unweighted one,
#'   and `n_support` for `min_n`.
#' @param sustained Logical scalar. If `TRUE`, the target must also hold at
#'   every higher cut with at least `min_n` clips. See Sustained target.
#'
#' @return A tibble with `site`, `species_folder`, the `by` columns,
#'   `threshold`, `n_support`, `precision_at_threshold` (unweighted; `NA`
#'   when no cut reaches the target). With `inclusion_prob`, also
#'   `precision_weighted_at_threshold`, `n_eff` (Kish's effective sample
#'   size at the threshold) and `precision_used` (`"weighted"` or
#'   `"unweighted"`, the precision that chose the cut). Without any
#'   reviewed clip with a confidence, the tibble has no rows.
#' @seealso [threshold_bootstrap()] for the conservative threshold to apply;
#'   [calibrated_thresholds()] for thresholds from the calibration model.
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read_validation_tables(list.files(file.path(ex, "validation"),
#'                                          full.names = TRUE))
#' suggest_thresholds(val, target_precision = 0.9, min_n = 10)
#' # the target must also hold at every higher cut
#' suggest_thresholds(val, target_precision = 0.9, min_n = 10,
#'                    sustained = TRUE)
#' @export
suggest_thresholds <- function(validation, target_precision = 0.90,
                               min_n = 15, by = NULL, weighted = NULL,
                               sustained = FALSE) {
  check_by(validation, by)
  check_prob(target_precision, "target_precision", open = TRUE)
  check_number(min_n, "min_n", lower = 1, integer = TRUE)
  check_flag(sustained, "sustained")
  if (!is.null(weighted) && !(isTRUE(weighted) || isFALSE(weighted))) {
    stop("`weighted` must be NULL, TRUE or FALSE.", call. = FALSE)
  }
  reviewed <- reviewed_with_confidence(validation)
  warn_uncombined(reviewed)
  has_weights <- has_inclusion_prob(reviewed)
  if (isTRUE(weighted) && nrow(reviewed) > 0 && !has_weights) {
    stop_without_inclusion_prob()
  }
  # without clips with confidence, group_modify() would create a row of
  # NA (what v1.2.0 wrote)
  if (nrow(reviewed) == 0) {
    empty <- tibble(site = character(), species_folder = character())
    for (col in by) empty[[col]] <- validation[[col]][0]
    return(bind_cols(empty,
                     tibble(threshold = numeric(), n_support = integer(),
                            precision_at_threshold = numeric())))
  }
  cells <- group_by(reviewed, site, species_folder, across(all_of(by)))
  if (has_weights && !isFALSE(weighted)) {
    n_mixed <- cells |>
      summarise(mixed = anyNA(inclusion_prob) && !all(is.na(inclusion_prob)),
                .groups = "drop") |>
      pull(mixed) |>
      sum()
    if (n_mixed > 0) {
      warning(n_mixed, " cell(s) mix clips with and without `inclusion_prob` ",
              "(\"top\" clips?), which are not a probability sample and ",
              "should not set thresholds; ",
              if (isTRUE(weighted)) "they get no threshold."
              else "they use the unweighted precision.", call. = FALSE)
    }
  }
  cells |>
    group_modify(~ threshold_for(.x, target_precision, min_n, has_weights,
                                 weighted, sustained)) |>
    ungroup()
}

#' Review support of each cell: is more validation worth it?
#'
#' For each site x species cell (and each level of the `by` columns, such as
#' the bin of an environmental gradient or of an acoustic index), counts the
#' reviewed clips at high scores, their precision, and the high-score
#' detections of the selection tables that were not reviewed, and labels the
#' cell:
#'
#' * `"reached"`: [suggest_thresholds()] found a threshold that reaches
#'   `target_precision` with at least `min_n` clips;
#' * `"exhausted"`: fewer than `min_n` high-score detections are left to
#'   review, so more effort cannot add support;
#' * `"unreliable"`: precision at high scores is below `min_precision`, so
#'   more review would only confirm it (retrain the classifier instead);
#' * `"review more"`: high-score detections remain and precision there is
#'   intermediate, so a further round of review may reach a threshold;
#' * `"not reviewed"`: the cell has detections but no reviewed clip.
#'
#' The cut-offs (`conf_high`, `min_n`, `min_precision`) are illustrative
#' defaults: set them from the precision the study needs. Splitting cells by
#' `by` lowers the number of clips per cell, so more cells fall short of
#' `min_n`; compare with the reading without `by`. These labels interpret
#' counts; they are not a statistical test.
#'
#' @param validation A data frame (or tibble) of reviewed clips, as for
#'   [precision_by_bin()] (the `validation_by_clip.csv` tables). One row per
#'   clip.
#' @param detections A data frame (or tibble) of predictions, as returned by
#'   [read_selection_tables()], with columns `site`, `species_code`,
#'   `confidence`, `begin_path` and `file_offset`. One row per prediction.
#' @param conf_high Numeric scalar, score from which a prediction counts as
#'   high.
#' @param min_n Integer scalar >= 1. Minimum number of clips, as in
#'   [suggest_thresholds()], and of unreviewed high-score detections for
#'   `"review more"`.
#' @param min_precision Numeric scalar in \[0, 1\]. Precision at high scores
#'   below which a cell is `"unreliable"`.
#' @param target_precision Numeric scalar in (0, 1). Target precision of
#'   [suggest_thresholds()].
#' @param weighted `NULL`, `TRUE` or `FALSE`. Passed to
#'   [suggest_thresholds()], so that `"reached"` follows the same rule.
#'   `prec_high` stays unweighted.
#' @param by `NULL` or a character vector of column names that split each
#'   cell, e.g. `"temp_bin"`. They must be columns of `covariates` (joined
#'   to both tables) or of both tables.
#' @param covariates `NULL` or a data frame (or tibble) of occasion
#'   covariates, such as the
#'   output of [covariate_bins()], joined to the clips and to the
#'   predictions by the columns it shares with them among `site`, `night`,
#'   `recording_date`, `recording_hour`, `source_audio` and `occasion_id`,
#'   as in [select_clips()].
#' @inheritParams select_clips
#'
#' @return A tibble with `site`, `species_folder`, the `by` columns,
#'   `n_reviewed`, `n_fp` (false positives among them), `n_high`
#'   (reviewed clips with score >= `conf_high`), `prec_high` (their
#'   precision), `n_high_all` (predictions with score >= `conf_high`),
#'   `unreviewed_high`, `threshold` and `diagnosis`, ordered by diagnosis.
#'   With a table of [combine_rounds()], also `n_rounds` and
#'   `reached_last_round`: the cell has a threshold now but had none before
#'   its last round.
#' @seealso `vignette("validation-effort")`.
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read_validation_tables(list.files(file.path(ex, "validation"),
#'                                          full.names = TRUE))
#' det <- read_selection_tables(file.path(ex, "birdnet"))
#' sup <- review_support(val, det, conf_high = 0.7, min_n = 10)
#' sup[, c("site", "species_folder", "n_reviewed", "prec_high",
#'         "unreviewed_high", "threshold", "diagnosis")]
#' @export
review_support <- function(validation, detections, conf_high = 0.7,
                           min_n = 15, min_precision = 0.5,
                           target_precision = 0.90, by = NULL,
                           covariates = NULL,
                           occasion_unit = c("file", "minute"),
                           remap_from = NULL, remap_to = NULL,
                           weighted = NULL) {
  unit <- match.arg(occasion_unit)
  check_columns(detections,
                c("site", "species_code", "confidence", "begin_path",
                  "file_offset"),
                "detections", hint = "Read it with read_selection_tables().")
  # the predictions get the occasion identification columns, as in
  # select_clips()
  det <- detections |>
    mutate(site = as.character(site),
           species_folder = folder_name(species_code),
           source_audio = remap_path(begin_path, remap_from, remap_to),
           occasion_id = make_occasion_id(source_audio, file_offset, unit))
  det <- bind_cols(det, parse_date_hour(basename(det$begin_path))) |>
    mutate(night = recording_date)
  val <- reviewed_with_confidence(validation) |>
    mutate(site = as.character(site))
  if (!is.null(covariates)) {
    val <- join_covariates(val, covariates, character())
    det <- join_covariates(det, covariates, character())
  }
  check_by(val, by)
  check_by(det, by)
  for (col in by) {
    n_na <- sum(is.na(det[[col]]))
    if (n_na > 0) {
      warning(n_na, " prediction(s) without a value of `", col, "`; they ",
              "form a group of their own.", call. = FALSE)
    }
  }
  # the `by` columns get the same type in both tables
  for (col in by) {
    val[[col]] <- as.character(val[[col]])
    det[[col]] <- as.character(det[[col]])
  }
  cell <- c("site", "species_folder", by)

  rev_summary <- val |>
    group_by(across(all_of(cell))) |>
    summarise(n_reviewed = n(),
              n_fp = sum(verdict == "negative"),
              n_high = sum(confidence >= conf_high),
              prec_high = if (n_high > 0) {
                mean(verdict[confidence >= conf_high] == "positive")
              } else NA_real_,
              .groups = "drop")
  all_det <- det |>
    group_by(across(all_of(cell))) |>
    summarise(n_high_all = sum(confidence >= conf_high), .groups = "drop")
  thr <- suggest_thresholds(val, target_precision = target_precision,
                            min_n = min_n, by = by,
                            weighted = weighted) |>
    select(all_of(cell), threshold)
  rounds <- rounds_by_cell(val, cell, target_precision, min_n, by, weighted)

  out <- full_join(rev_summary, all_det, by = cell) |>
    left_join(thr, by = cell) |>
    mutate(
      n_reviewed = replace_na(n_reviewed, 0L),
      n_fp = replace_na(n_fp, 0L),
      n_high = replace_na(n_high, 0L),
      n_high_all = replace_na(n_high_all, 0L),
      unreviewed_high = pmax(n_high_all - n_high, 0L),
      diagnosis = case_when(
        n_reviewed == 0                                  ~ "not reviewed",
        !is.na(threshold)                                ~ "reached",
        unreviewed_high < min_n                          ~ "exhausted",
        !is.na(prec_high) & prec_high < min_precision    ~ "unreliable",
        .default = "review more"
      )) |>
    select(all_of(cell), n_reviewed, n_fp, n_high, prec_high, n_high_all,
           unreviewed_high, threshold, diagnosis) |>
    arrange(diagnosis, species_folder, site, across(all_of(by)))
  if (is.null(rounds)) return(out)
  out <- left_join(out, rounds, by = cell) |>
    mutate(reached_last_round = diagnosis == "reached" & !replace_na(.prior, FALSE) &
             replace_na(n_rounds, 1L) > 1L) |>
    select(-.prior)
  if (any(out$reached_last_round)) {
    message(sum(out$reached_last_round), " cell(s) reached the target only ",
            "in their last round: their precision tends to be too high if ",
            "that is why the rounds stopped.")
  }
  out
}

#' Rounds per cell and whether the cell had a threshold before the last
#' round
#'
#' @param val A data frame of reviewed clips with confidence.
#' @param cell Character vector, columns that define a cell.
#' @param target_precision,min_n,by,weighted Passed to
#'   suggest_thresholds().
#' @return `NULL` for tables without combine_rounds() (no `n_rounds`
#'   column); otherwise a tibble with the `cell` columns, `n_rounds` and
#'   `.prior` (logical).
#' @noRd
rounds_by_cell <- function(val, cell, target_precision, min_n, by, weighted) {
  if (!"n_rounds" %in% names(val)) return(NULL)
  val <- filter(val, !is.na(n_rounds))
  by_cell <- val |>
    group_by(across(all_of(cell))) |>
    summarise(n_rounds = n_distinct(round), .groups = "drop")
  before <- before_last_round(val)
  if (nrow(before) == 0) return(mutate(by_cell, .prior = FALSE))
  thr <- suggest_thresholds(before, target_precision = target_precision,
                            min_n = min_n, by = by, weighted = weighted) |>
    transmute(across(all_of(cell)), .prior = !is.na(threshold))
  left_join(by_cell, thr, by = cell)
}

#' Check the extra grouping columns (argument `by`)
#'
#' @param val A data frame.
#' @param by `NULL` or a character vector of column names of `val`.
#' @return `NULL`, invisibly; stops if `by` is invalid.
#' @noRd
check_by <- function(val, by) {
  if (is.null(by)) return(invisible())
  if (!is.character(by) || anyNA(by)) {
    stop("`by` must be a character vector of column names.", call. = FALSE)
  }
  absent <- setdiff(by, names(val))
  if (length(absent) > 0) {
    stop("Column(s) of `by` not in the table: ",
         paste(absent, collapse = ", "), call. = FALSE)
  }
  invisible()
}

#' Empirical threshold of one cell
#'
#' The lowest cut c such that the precision of the clips with
#' confidence >= c reaches the target. With weights, the precision and the support of
#' the decision are the weighted ones in cells where every clip has
#' `inclusion_prob`.
#'
#' @param df A data frame of reviewed clips of one cell, with `confidence`,
#'   `verdict` and, with weights, `inclusion_prob`.
#' @param target Numeric scalar in (0, 1), target precision.
#' @param n_min Numeric scalar, minimum number of clips (or effective
#'   sample size, with weights) at or above a cut for it to count.
#' @param has_weights Logical scalar, whether the table has `inclusion_prob`
#'   (adds the weighted columns to the output).
#' @param weighted `NULL`, `TRUE` or `FALSE`, as in suggest_thresholds().
#' @param sustained Logical scalar; if `TRUE`, the target must hold at
#'   every supported cut above the threshold.
#' @return A one-row tibble with `threshold`, `n_support`,
#'   `precision_at_threshold` and, with `has_weights`,
#'   `precision_weighted_at_threshold`, `n_eff` and `precision_used`.
#' @noRd
threshold_for <- function(df, target, n_min, has_weights = FALSE, weighted = NULL,
                          sustained = FALSE) {
  cuts <- sort(unique(round(df$confidence, 2)))
  out <- tibble(threshold = NA_real_, n_support = NA_integer_,
                precision_at_threshold = NA_real_)
  if (has_weights) {
    out$precision_weighted_at_threshold <- NA_real_
    out$n_eff <- NA_real_
    out$precision_used <- NA_character_
  }
  complete <- has_weights && !anyNA(df$inclusion_prob)
  if (isTRUE(weighted) && !complete) return(out)
  use_weights <- complete && !isFALSE(weighted)
  # one pass: clips sorted by score, sums from the top; the clips at or above
  # a cut are the first n_ge of the sorted clips
  ord <- order(df$confidence, decreasing = TRUE)
  conf <- df$confidence[ord]
  pos <- df$verdict[ord] == "positive"
  n_ge <- length(conf) - findInterval(cuts, rev(conf), left.open = TRUE)
  cuts <- cuts[n_ge > 0]
  n_ge <- n_ge[n_ge > 0]
  measures <- if (use_weights) {
    w <- 1 / as.numeric(df$inclusion_prob[ord])
    sw <- cumsum(w)[n_ge]
    rbind(cumsum(w * pos)[n_ge] / sw, sw^2 / cumsum(w^2)[n_ge])
  } else {
    rbind(cumsum(pos)[n_ge] / n_ge, n_ge)
  }
  # the target holds at this cut and at every supported cut above it, as in
  # calibrated_thresholds(); cuts with fewer than min_n clips do not count
  supported <- which(measures[2, ] >= n_min)
  failing <- supported[measures[1, supported] < target]
  valid <- supported[measures[1, supported] >= target]
  if (sustained && length(failing) > 0) valid <- valid[valid > max(failing)]
  if (length(valid) == 0) return(out)

  c0 <- cuts[valid[1]]
  sub <- filter(df, confidence >= c0)
  out$threshold <- c0
  out$n_support <- nrow(sub)
  out$precision_at_threshold <- mean(sub$verdict == "positive")
  if (has_weights) {
    out$precision_weighted_at_threshold <-
      weighted_precision(sub$verdict, sub$inclusion_prob)
    out$n_eff <- if (anyNA(sub$inclusion_prob)) {
      NA_real_
    } else {
      kish_n(sub$inclusion_prob)
    }
    out$precision_used <- if (use_weights) "weighted" else "unweighted"
  }
  out
}

#' Confirmed presence by night
#'
#' Summarises the verdicts by site, species and night. A night is
#' `"confirmed"` when at least one clip is positive,
#' `"not_detected_in_reviewed"` when clips were reviewed but none was
#' positive, and `"not_reviewed"` otherwise.
#'
#' @inheritParams precision_by_bin
#'
#' @return A tibble with `site`, `species_folder`, `night`, `n_clips`,
#'   `n_reviewed`, `n_positive`, `presence` and `max_confidence_positive`.
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read_validation_tables(list.files(file.path(ex, "validation"),
#'                                          full.names = TRUE))
#' pres <- nightly_presence(val)
#' table(pres$species_folder, pres$presence)
#' @export
nightly_presence <- function(validation) {
  validation |>
    group_by(site, species_folder, night) |>
    summarise(
      n_clips    = n(),
      n_reviewed = sum(verdict %in% c("positive", "negative")),
      n_positive = sum(verdict == "positive"),
      presence   = case_when(
        n_positive > 0 ~ "confirmed",
        n_reviewed > 0 ~ "not_detected_in_reviewed",
        .default       = "not_reviewed"
      ),
      max_confidence_positive = ifelse(
        n_positive > 0, max(confidence[verdict == "positive"]), NA_real_),
      .groups = "drop"
    )
}

#' Positive clips for retraining
#'
#' Lists the clips confirmed as positive, ready to retrain the classifier.
#'
#' @inheritParams precision_by_bin
#'
#' @return A tibble with `site`, `species_code`, `species_folder`,
#'   `clip_file`, `reviewed_path`, `confidence`, `night`, `recording_hour`
#'   and `source_audio`.
#' @examples
#' val <- read.csv(system.file("extdata", "validation_by_clip.csv",
#'                             package = "sheepdog"))
#' retraining_clips(val)
#' @export
retraining_clips <- function(validation) {
  validation[!is_inherited(validation), ] |>
    filter(verdict == "positive") |>
    select(site, species_code, species_folder, clip_file, reviewed_path,
           confidence, night, recording_hour, source_audio)
}

#' Plot the precision curves
#'
#' One panel per species: precision by confidence bin, with the target
#' precision as a dashed line and bins with low support shown faded. With
#' more than one site, each site is a line of its own colour.
#' Needs the 'ggplot2' package.
#'
#' @param precision A data frame (or tibble) returned by
#'   [precision_by_bin()].
#' @inheritParams precision_by_bin
#' @inheritParams suggest_thresholds
#'
#' @return A ggplot object.
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read_validation_tables(list.files(file.path(ex, "validation"),
#'                                          full.names = TRUE))
#' prec <- precision_by_bin(val, min_n = 10)
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   plot_precision(prec, target_precision = 0.9, min_n = 10)
#' }
#' @export
plot_precision <- function(precision, bins = seq(0.1, 1, by = 0.1),
                           target_precision = 0.90, min_n = 15) {
  require_suggested("ggplot2", "to plot the precision curves")
  # with several sites, one line per site (lines of different sites were
  # once joined in the same panel)
  multi_site <- n_distinct(precision$site) > 1
  layers <- if (multi_site) {
    list(ggplot2::geom_line(ggplot2::aes(colour = site, group = site)),
         ggplot2::geom_point(ggplot2::aes(size = n_reviewed,
                                          alpha = !low_support,
                                          colour = site)))
  } else {
    list(ggplot2::geom_line(colour = "#2a7fbf"),
         ggplot2::geom_point(ggplot2::aes(size = n_reviewed,
                                          alpha = !low_support),
                             colour = "#2a7fbf"))
  }
  precision |>
    mutate(bin_mid = bins[as.integer(bin)] + 0.05) |>
    ggplot2::ggplot(ggplot2::aes(bin_mid, precision)) +
    ggplot2::geom_hline(yintercept = target_precision,
                        linetype = "dashed", colour = "grey50") +
    layers +
    ggplot2::scale_alpha_manual(values = c(`TRUE` = 1, `FALSE` = 0.3),
                                guide = "none") +
    ggplot2::scale_size_continuous(name = "reviewed clips") +
    ggplot2::scale_x_continuous(limits = c(0.1, 1),
                                breaks = seq(0.1, 1, 0.2)) +
    ggplot2::scale_y_continuous(limits = c(0, 1)) +
    ggplot2::facet_wrap(~ species_folder) +
    ggplot2::labs(x = "Confidence (bin centre)", y = "Precision",
                  title = "Precision of the predictions by confidence bin",
                  subtitle = paste0("Dashed line: target precision (",
                                    target_precision, "); faded points: < ",
                                    min_n, " clips in the bin")) +
    ggplot2::theme_minimal(base_size = 11)
}

#' Summarise the manual validation
#'
#' Runs the whole post-validation step: reads the verdicts of the reviewed
#' clips and writes, to `output_dir`:
#' * `validation_by_clip.csv`: manifest + verdict of each clip
#'   ([classify_review()] for a review in the BirdNET GUI, [app_verdicts()]
#'   for a review in [run_app()]);
#' * `precision_by_bin.csv`: precision by species x confidence bin
#'   ([precision_by_bin()]);
#' * `suggested_thresholds.csv`: lowest confidence reaching the target
#'   precision, by species ([suggest_thresholds()]);
#' * `nightly_presence.csv`: confirmed presence by site x species x night
#'   ([nightly_presence()]);
#' * `retraining_clips.csv`: positive clips for retraining
#'   ([retraining_clips()]);
#' * `thresholds_compared.csv`: empirical and model thresholds, with `fit`
#'   ([compare_thresholds()]);
#' * `precision_by_bin.png`: precision curves ([plot_precision()]), when
#'   'ggplot2' is installed.
#'
#' The verdicts come from the folders of a review in the BirdNET GUI
#' (`review_dir`) or from the verdicts file of [run_app()]
#' (`verdicts_file`). In the second case, a clip marked more than once
#' keeps the last verdict of each reviewer, and clips reviewed by more than
#' one reviewer are combined with [consensus_verdicts()]: conflicting
#' verdicts become `"disagreement"` and, like `"uncertain"`, are left out of
#' the precision and the thresholds.
#'
#' With `inclusion_prob` in the manifest (clips of `"random_detections"`),
#' the precision tables also give the precision weighted by
#' `1 / inclusion_prob` (see [precision_by_bin()]), and that precision
#' chooses the thresholds, unless `weighted = FALSE`; see
#' [suggest_thresholds()].
#'
#' This is the function form of the v1.2.0 script `pos_validacao.R`.
#'
#' @inheritParams classify_review
#' @param review_dir `NULL` or a character scalar, path to the folder with
#'   the reviewed clips. For a review in the
#'   BirdNET GUI, the `clips` folder after the review, whose subfolders
#'   give the verdicts. With `verdicts_file`, optional: the folder of the
#'   clips, used to fill `reviewed_path` (needed by [retraining_clips()]
#'   and [build_training_set()]).
#' @inheritParams precision_by_bin
#' @inheritParams suggest_thresholds
#' @param manifest_path Character scalar, path to the manifest of the same
#'   run as the reviewed clips (`clip_manifest.csv`, or a v1.2.0
#'   `manifesto_clipes.csv`).
#' @param output_dir Character scalar, path to the output folder; created if
#'   needed.
#' @param verdicts_file `NULL` or a character scalar, path to the verdicts
#'   file written by [run_app()], used instead of the subfolders of
#'   `review_dir`.
#' @param reviewer `NULL` or a character vector of reviewer names. With
#'   `verdicts_file`, the reviewer(s) whose verdicts are used, as in
#'   [app_verdicts()].
#' @param weighted,sustained `NULL`, `TRUE` or `FALSE` (`weighted`) and
#'   logical scalar (`sustained`). Passed to [suggest_thresholds()].
#' @param fit `NULL` or a model returned by [fit_calibration()] (`glm`,
#'   `glmerMod` or `brmsfit`). With it, [compare_thresholds()] writes
#'   `thresholds_compared.csv`.
#' @param scored,quality `NULL` or data frames (or tibbles). With `fit`,
#'   passed to [compare_thresholds()].
#' @param previous `NULL`, a character vector of paths, a data frame, or a
#'   list of data frames. For a later round of a design: the
#'   `validation_by_clip.csv` of the earlier rounds. `validation_by_clip.csv`
#'   keeps the clips of this round only; the summaries and
#'   `validation_combined.csv` cover all rounds, from [combine_rounds()].
#' @param candidates `NULL`, a data frame, or a character scalar path. With
#'   `previous`, the `candidates.csv` of the first round. `NULL` looks for
#'   it beside `manifest_path` and `previous`.
#'
#' @return A list with the tables `validation`, `precision`, `thresholds`,
#'   `presence` and `retraining` (and `compared`, with `fit`), invisibly.
#' @examples
#' # Recreate the folders left by a review in the BirdNET GUI, with empty files
#' man <- system.file("extdata", "clip_manifest.csv", package = "sheepdog")
#' done <- read.csv(system.file("extdata", "validation_by_clip.csv",
#'                              package = "sheepdog"))
#' review_dir <- file.path(tempdir(), "clips_post")
#' sub <- ifelse(done$verdict == "positive", "Positive",
#'               ifelse(done$verdict == "negative", "Negative", ""))
#' dest <- file.path(review_dir, done$species_folder, sub)
#' for (d in unique(dest)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
#' invisible(file.create(file.path(dest, done$clip_file)))
#'
#' out_dir <- file.path(tempdir(), "post_validation")
#' res <- post_validation(review_dir, manifest_path = man,
#'                        output_dir = out_dir, min_n = 3)
#' res$thresholds
#' list.files(out_dir)
#' unlink(c(review_dir, out_dir), recursive = TRUE)
#' @export
post_validation <- function(review_dir = NULL, manifest_path, output_dir,
                            positive_pattern = "positiv",
                            negative_pattern = "negativ",
                            bins = seq(0.1, 1, by = 0.1),
                            target_precision = 0.90,
                            min_n = 15, verdicts_file = NULL,
                            reviewer = NULL, weighted = NULL,
                            previous = NULL, candidates = NULL, fit = NULL,
                            scored = NULL, quality = NULL, sustained = FALSE) {
  if (is.null(verdicts_file)) {
    if (is.null(review_dir)) {
      stop("Give `review_dir` (review in the BirdNET GUI) or ",
           "`verdicts_file` (review in run_app()).", call. = FALSE)
    }
    result <- classify_review(manifest_path, review_dir,
                              positive_pattern, negative_pattern)
  } else {
    result <- app_verdicts(manifest_path, verdicts_file,
                           clips_dir = review_dir, reviewer = reviewer)
    if (anyDuplicated(result[c("species_folder", "clip_file")])) {
      message("Clips reviewed by more than one reviewer are combined with ",
              "consensus_verdicts().")
      result <- consensus_verdicts(result)
    }
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  write_csv(result, file.path(output_dir, "validation_by_clip.csv"))
  if (!is.null(previous)) {
    if (is.null(candidates)) {
      candidates <- read_candidates(NULL, c(manifest_path, previous))
    }
    # without the `round` column, this round comes after the previous ones
    prev <- if (is.data.frame(previous)) list(previous) else as.list(previous)
    result <- combine_rounds(c(prev, list(result)), candidates)
    write_csv(result, file.path(output_dir, "validation_combined.csv"))
    message("Rounds combined: ", n_distinct(result$round),
            "; see validation_combined.csv")
  }

  reviewed <- filter(result, verdict %in% c("positive", "negative"))
  if (nrow(reviewed) == 0) {
    stop("No clip with a positive/negative verdict - was the review ",
         "done? ", if (is.null(verdicts_file)) {
           "Check positive_pattern/negative_pattern."
         } else {
           "Check `verdicts_file` and `reviewer`."
         }, call. = FALSE)
  }
  if (has_inclusion_prob(reviewed_with_confidence(result, quiet = TRUE))) {
    message("The manifest has inclusion_prob: the precision tables also ",
            "give the precision weighted by 1 / inclusion_prob.")
  }
  n_no_conf <- sum(is.na(reviewed$confidence))
  if (n_no_conf > 0) {
    message(n_no_conf, " reviewed clip(s) without confidence (drawn ",
            "recordings) left out of the precision by bin and the ",
            "thresholds.")
  }

  precision_tbl <- precision_by_bin(result, bins, min_n)
  write_csv(precision_tbl, file.path(output_dir, "precision_by_bin.csv"))

  thresholds <- suggest_thresholds(result, target_precision, min_n,
                                   weighted = weighted, sustained = sustained)
  write_csv(thresholds, file.path(output_dir, "suggested_thresholds.csv"))
  message("Suggested thresholds (target precision ", target_precision,
          "): see suggested_thresholds.csv")

  compared <- NULL
  if (!is.null(fit)) {
    compared <- compare_thresholds(result, fit, scored,
                                   target_precision = target_precision,
                                   min_n = min_n, quality = quality,
                                   weighted = weighted,
                                   sustained = sustained)
    write_csv(compared, file.path(output_dir, "thresholds_compared.csv"))
    message("Empirical and model thresholds: see thresholds_compared.csv")
  }

  presence <- nightly_presence(result)
  write_csv(presence, file.path(output_dir, "nightly_presence.csv"))

  retrain <- retraining_clips(result)
  write_csv(retrain, file.path(output_dir, "retraining_clips.csv"))
  message(nrow(retrain), " positive clips listed for retraining.")

  if (nrow(precision_tbl) > 0) {
    if (has_suggested("ggplot2")) {
      g <- plot_precision(precision_tbl, bins, target_precision, min_n)
      ggplot2::ggsave(file.path(output_dir, "precision_by_bin.png"), g,
                      width = 11, height = 8, dpi = 200)
    } else {
      message("Package 'ggplot2' not installed: precision_by_bin.png ",
              "was not drawn.")
    }
  }

  message("Done! Results in ", output_dir)
  invisible(c(list(validation = result, precision = precision_tbl,
                   thresholds = thresholds, presence = presence,
                   retraining = retrain),
              if (!is.null(compared)) list(compared = compared)))
}
