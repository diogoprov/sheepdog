#' Compare the empirical and the model-based thresholds
#'
#' Puts side by side, for each site x species, the threshold from the
#' reviewed clips ([suggest_thresholds()]) and the ones from the calibration
#' model ([calibrated_thresholds()]). The first needs no model but needs a
#' random sample and many clips per cell; the second reaches cells with few
#' clips, through partial pooling, but rests on the form of the model.
#'
#' **What to compare.** The two rules of the model answer different
#' questions. `thr_empirical` and `thr_model_precision` both ask what share
#' of the detections kept are true, so their agreement is direct evidence
#' that the calibration fits the data, and `flag` compares these two. A large
#' difference points to the model (form, missing covariate) or to the sample
#' (few clips, missing weights); check it before using the threshold. The
#' model thresholds require the target at every higher score, and the
#' empirical one by default does not; `sustained = TRUE` applies the same
#' rule, at the cost described in [suggest_thresholds()].
#' `thr_p_tp`, the score from which a detection is at least `target_p` likely
#' to be true, is higher for the same target, is the cut on P(TP) of
#' [detection_history()], and does not enter `flag`.
#'
#' **Before using the model.** Use a calibration whose candidates were
#' compared by cross-validation and whose [calibration_quality()] status is
#' `"ok"` for the species; give that table in `quality` to carry the status
#' into the output. A model threshold above the highest reviewed score of the
#' cell (`above_reviewed`) is an extrapolation.
#'
#' **Reuse.** Clips used here to set the threshold should not be reused as
#' confirmation data in the occupancy model without saying so.
#'
#' @param validation A data frame (or tibble) of reviewed clips, as for
#'   [suggest_thresholds()]. One row per clip. For `random_detections`
#'   clips, the empirical threshold uses the weighted precision.
#' @param fit A model returned by [fit_calibration()] (`glm`, `glmerMod` or
#'   `brmsfit`).
#' @param scored `NULL` or a data frame (or tibble) returned by
#'   [score_detections()]. Needed for `thr_model_precision`,
#'   `model_precision_at_empirical` and `flag`.
#' @param target_p Numeric scalar in (0, 1). Target of the `"probability"`
#'   rule.
#' @param target_precision Numeric scalar in (0, 1). Target precision of the
#'   empirical threshold and of the `"precision"` rule.
#' @param min_n Integer scalar >= 1. Passed to [suggest_thresholds()].
#' @param tolerance Numeric scalar >= 0, in score units. Largest difference
#'   between `thr_empirical` and `thr_model_precision` for `"agree"`.
#' @param quality `NULL` or a data frame (or tibble) returned by
#'   [calibration_quality()], joined by the columns `site` and `species`
#'   that it has.
#' @param weighted,sustained `NULL`, `TRUE` or `FALSE` (`weighted`) and
#'   logical scalar (`sustained`). Passed to [suggest_thresholds()].
#' @inheritParams calibrated_thresholds
#'
#' @return A tibble (class `tbl_df`) with one row per site x species:
#'   `site`, `species`,
#'   `thr_empirical`, `prec_empirical` (the precision that chose the cut),
#'   `n_support`, `thr_model_precision`, `thr_p_tp`, `p_tp_at_threshold`,
#'   `thr_p_tp_lower` (with a `brms` model), `model_precision_at_empirical`
#'   (the expected precision of the model at `thr_empirical`),
#'   `max_reviewed`, `above_reviewed`, `quality` (with `quality`) and `flag`:
#'   `"agree"`, `"disagree"`, `"model_only"`, `"empirical_only"` or `"none"`;
#'   `NA` without `scored`.
#' @seealso [post_validation()], which writes this table with `fit`.
#' @export
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' files <- list.files(file.path(ex, "validation"), full.names = TRUE)
#' sites <- c("ARA", "BAI", "NHE", "XAR")
#' tables <- setNames(file.path(ex, "birdnet", sites,
#'                              "BirdNET_SelectionTable.txt"), sites)
#' fit <- fit_calibration(read_validations(files),
#'                        calibration_models()$m2_species_slope)
#' scored <- score_detections(tables, fit)
#' compare_thresholds(read_validation_tables(files), fit, scored)
compare_thresholds <- function(validation, fit, scored = NULL,
                               target_p = 0.95, target_precision = 0.90,
                               min_n = 15, tolerance = 0.05, quality = NULL,
                               weighted = NULL, sustained = FALSE,
                               min_confidence = 0.1,
                               grid_step = 0.01, lower_prob = 0.05) {
  check_number(tolerance, "tolerance", lower = 0)
  check_prob(lower_prob, "lower_prob", open = TRUE)
  cell <- c("site", "species")
  empirical <- suggest_thresholds(validation, target_precision, min_n,
                                 weighted = weighted, sustained = sustained) |>
    mutate(site = as.character(site),
           prec_empirical = if ("precision_used" %in% names(pick(everything()))) {
             if_else(precision_used %in% "weighted",
                     precision_weighted_at_threshold, precision_at_threshold)
           } else {
             precision_at_threshold
           }) |>
    transmute(site, species = species_folder, thr_empirical = threshold,
              prec_empirical, n_support)
  reviewed <- reviewed_with_confidence(validation) |>
    group_by(site = as.character(site), species = species_folder) |>
    summarise(max_reviewed = max(confidence), .groups = "drop")

  cells <- distinct(empirical, site, species)
  if (!is.null(scored)) {
    cells <- bind_rows(cells,
                         distinct(scored, site = as.character(site),
                                  species = as.character(species))) |>
      distinct()
  }
  prob_thr <- calibrated_thresholds(
    fit, target = target_p, rule = "probability", cells = cells,
    min_confidence = min_confidence, grid_step = grid_step,
    lower_prob = lower_prob) |>
    rename(thr_p_tp = threshold)
  if ("threshold_lower" %in% names(prob_thr)) {
    prob_thr <- rename(prob_thr, thr_p_tp_lower = threshold_lower)
  }

  out <- cells |>
    left_join(empirical, by = cell) |>
    left_join(reviewed, by = cell) |>
    left_join(prob_thr, by = cell)
  if (is.null(scored)) {
    message("Without `scored`, there is no thr_model_precision and no `flag`.")
    out <- mutate(out, thr_model_precision = NA_real_,
                  model_precision_at_empirical = NA_real_,
                  flag = NA_character_)
  } else {
    scored_chr <- mutate(scored, site = as.character(site),
                         species = as.character(species))
    prec_thr <- calibrated_thresholds(
      fit, target = target_precision, rule = "precision", scored = scored_chr,
      min_confidence = min_confidence, grid_step = grid_step) |>
      transmute(site = as.character(site), species = as.character(species),
                thr_model_precision = threshold)
    at_cut <- scored_chr |>
      inner_join(select(empirical, all_of(cell), thr_empirical), by = cell) |>
      filter(!is.na(thr_empirical), confidence >= thr_empirical) |>
      group_by(across(all_of(cell))) |>
      summarise(model_precision_at_empirical = mean(p_tp), .groups = "drop")
    out <- out |>
      left_join(prec_thr, by = cell) |>
      left_join(at_cut, by = cell) |>
      mutate(flag = case_when(
        is.na(thr_empirical) & is.na(thr_model_precision) ~ "none",
        is.na(thr_model_precision)                        ~ "empirical_only",
        is.na(thr_empirical)                              ~ "model_only",
        abs(thr_empirical - thr_model_precision) <= tolerance + 1e-8 ~ "agree",
        .default = "disagree"))
  }
  out <- mutate(out, above_reviewed =
                  pmax(thr_model_precision, thr_p_tp, na.rm = TRUE) >
                  max_reviewed)
  if (!is.null(quality)) {
    key_cols <- intersect(cell, names(quality))
    if (!"species" %in% key_cols || !"status" %in% names(quality)) {
      stop("`quality` must be a table of calibration_quality(), by species.",
           call. = FALSE)
    }
    out <- quality |>
      mutate(across(all_of(key_cols), as.character)) |>
      select(all_of(key_cols), quality = status) |>
      right_join(out, by = key_cols)
  }
  select(out, all_of(cell), thr_empirical, prec_empirical, n_support,
         thr_model_precision, thr_p_tp, p_tp_at_threshold,
         any_of("thr_p_tp_lower"), model_precision_at_empirical, max_reviewed,
         above_reviewed, any_of("quality"), flag) |>
    arrange(species, site)
}
