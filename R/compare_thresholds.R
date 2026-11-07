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
#' @param validation Reviewed clips, as for [suggest_thresholds()]. For
#'   `random_detections` clips, the empirical threshold uses the weighted
#'   precision.
#' @param fit Model returned by [fit_calibration()].
#' @param scored Table returned by [score_detections()]. Needed for
#'   `thr_model_precision`, `model_precision_at_empirical` and `flag`.
#' @param target_p Target of the `"probability"` rule.
#' @param target_precision Target precision of the empirical threshold and
#'   of the `"precision"` rule.
#' @param min_n Passed to [suggest_thresholds()].
#' @param tolerance Largest difference between `thr_empirical` and
#'   `thr_model_precision`, in score units, for `"agree"`.
#' @param quality Optional table of [calibration_quality()], joined by the
#'   columns `site` and `species` that it has.
#' @param weighted,sustained Passed to [suggest_thresholds()].
#' @inheritParams calibrated_thresholds
#'
#' @return A tibble with one row per site x species: `site`, `species`,
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
#' \dontrun{
#' fit <- fit_calibration(read_validations(files),
#'                        calibration_models()$m4_species_x_site)
#' scored <- score_detections(tables, fit)
#' compare_thresholds(read_validation_tables(files), fit, scored)
#' }
compare_thresholds <- function(validation, fit, scored = NULL,
                               target_p = 0.95, target_precision = 0.90,
                               min_n = 15, tolerance = 0.05, quality = NULL,
                               weighted = NULL, sustained = FALSE,
                               min_confidence = 0.1,
                               grid_step = 0.01, lower_prob = 0.05) {
  celula <- c("site", "species")
  empirico <- suggest_thresholds(validation, target_precision, min_n,
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
  revisados <- reviewed_with_confidence(validation) |>
    group_by(site = as.character(site), species = species_folder) |>
    summarise(max_reviewed = max(confidence), .groups = "drop")

  celulas <- distinct(empirico, site, species)
  if (!is.null(scored)) {
    celulas <- bind_rows(celulas,
                         distinct(scored, site = as.character(site),
                                  species = as.character(species))) |>
      distinct()
  }
  probabilidade <- calibrated_thresholds(
    fit, target = target_p, rule = "probability", cells = celulas,
    min_confidence = min_confidence, grid_step = grid_step,
    lower_prob = lower_prob) |>
    rename(thr_p_tp = threshold)
  if ("threshold_lower" %in% names(probabilidade)) {
    probabilidade <- rename(probabilidade, thr_p_tp_lower = threshold_lower)
  }

  saida <- celulas |>
    left_join(empirico, by = celula) |>
    left_join(revisados, by = celula) |>
    left_join(probabilidade, by = celula)
  if (is.null(scored)) {
    message("Without `scored`, there is no thr_model_precision and no `flag`.")
    saida <- mutate(saida, thr_model_precision = NA_real_,
                    model_precision_at_empirical = NA_real_,
                    flag = NA_character_)
  } else {
    pontos <- mutate(scored, site = as.character(site),
                     species = as.character(species))
    precisao <- calibrated_thresholds(
      fit, target = target_precision, rule = "precision", scored = pontos,
      min_confidence = min_confidence, grid_step = grid_step) |>
      transmute(site = as.character(site), species = as.character(species),
                thr_model_precision = threshold)
    no_corte <- pontos |>
      inner_join(select(empirico, all_of(celula), thr_empirical), by = celula) |>
      filter(!is.na(thr_empirical), confidence >= thr_empirical) |>
      group_by(across(all_of(celula))) |>
      summarise(model_precision_at_empirical = mean(p_tp), .groups = "drop")
    saida <- saida |>
      left_join(precisao, by = celula) |>
      left_join(no_corte, by = celula) |>
      mutate(flag = case_when(
        is.na(thr_empirical) & is.na(thr_model_precision) ~ "none",
        is.na(thr_model_precision)                        ~ "empirical_only",
        is.na(thr_empirical)                              ~ "model_only",
        abs(thr_empirical - thr_model_precision) <= tolerance + 1e-8 ~ "agree",
        .default = "disagree"))
  }
  saida <- mutate(saida, above_reviewed =
                    pmax(thr_model_precision, thr_p_tp, na.rm = TRUE) >
                    max_reviewed)
  if (!is.null(quality)) {
    chave <- intersect(celula, names(quality))
    if (!"species" %in% chave || !"status" %in% names(quality)) {
      stop("`quality` must be a table of calibration_quality(), by species.",
           call. = FALSE)
    }
    saida <- quality |>
      mutate(across(all_of(chave), as.character)) |>
      select(all_of(chave), quality = status) |>
      right_join(saida, by = chave)
  }
  select(saida, all_of(celula), thr_empirical, prec_empirical, n_support,
         thr_model_precision, thr_p_tp, p_tp_at_threshold,
         any_of("thr_p_tp_lower"), model_precision_at_empirical, max_reviewed,
         above_reviewed, any_of("quality"), flag) |>
    arrange(species, site)
}
