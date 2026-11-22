#' Check the quality of the calibrated probabilities by species
#'
#' [compare_calibration_models()] scores each model over all the clips,
#' which can hide a species whose probabilities should not be trusted: the
#' mean AUC rises when species differ in precision, even if the score says
#' little within a species, and partial pooling lends such a species the
#' curve of the others. This function refits one model by cross-validation
#' and scores the held-out predictions within each group, asking three
#' questions before the probabilities are used:
#'
#' * Does the model add information? `logloss_gain` is the log-loss of a
#'   null model, the share of true positives of the group in the training
#'   folds, minus the log-loss of the model. It plays the part of a
#'   comparison with an intercept-only model, on held-out clips.
#' * Does it discriminate? `auc` is the AUC of the held-out probabilities
#'   within the group, and `auc_score` that of the raw confidence score.
#'   An `auc` well above `auc_score` means that the discrimination comes
#'   from other terms of the model (e.g. site effects, when `by = "species"`),
#'   not from the score, so both must reach `auc_min`. Unlike the AUC of
#'   [compare_calibration_models()], these are not reversed when the
#'   ranking is inverted, so values below 0.5 can occur.
#' * Are the probabilities correct? `cal_intercept` and `cal_slope` come
#'   from a logistic regression of the verdicts on the logit of the
#'   held-out probabilities (intercept 0 and slope 1 when well calibrated).
#'   AUC alone does not answer this: a model can rank clips well and still
#'   give wrong probabilities.
#'
#' The default limits behind `status` (`auc_min`, `slope_range`,
#' `intercept_max` and `min_class`) are provisional screening values. They
#' were chosen by judgement, and were neither derived from the literature
#' nor validated on data, so a group near a limit is not a clear pass or
#' fail. They are meant to direct attention to a group, and should be
#' reviewed and set for each project. Read the measures along with `status`.
#' A group marked `"poor"` needs more clips, a different model or a decision
#' to leave the species out of the analyses that use P(TP).
#'
#' The results depend on the design of the review. Discrimination is
#' measured over the scores that were reviewed, so the `"top"` design, which
#' concentrates the clips at high scores (see `conf_min` and `conf_max`),
#' can give a low AUC even with a good classifier. The clips of
#' `"random_detections"` cover the range of scores of the predictions.
#'
#' The fits use maximum likelihood, also when the final model is fitted with
#' `engine = "brms"`. Use `fold_group` to keep the clips of a recording or
#' night on the same side of the split.
#'
#' @inheritParams compare_calibration_models
#' @param formula A model formula, the formula of the model to check, e.g. the
#'   one chosen by [select_calibration_model()].
#' @param by Character vector (one or more elements) of columns of `validations`
#'   that define the groups: `"species"`, or `c("site", "species")` for the
#'   cells of the calibration, which hold fewer clips each.
#' @param min_class Numeric scalar, least number of true positives and of false
#'   positives for a group to be judged. With fewer, `status` is
#'   `"insufficient"`.
#' @param auc_min Numeric scalar in \[0, 1\], lowest acceptable `auc` and
#'   `auc_score`.
#' @param slope_range Numeric vector of length 2, increasing: acceptable range
#'   of `cal_slope`.
#' @param intercept_max Numeric scalar >= 0, largest acceptable absolute
#'   `cal_intercept`.
#'
#' @return A tibble (class `tbl_df`) with one row per group: the `by` columns,
#'   `n`, `n_tp`, `n_fp`, `conf_min`, `conf_max`, `auc`, `auc_score`, `logloss`,
#'   `logloss_null`, `logloss_gain`, `cal_intercept`, `cal_slope`, `status`
#'   (`"ok"`, `"poor"` or `"insufficient"`) and `reason`. Measures that cannot
#'   be computed (e.g. the AUC of a group with one verdict) are `NA`. Folds
#'   whose fit failed are left out, with a warning.
#' @seealso [compare_calibration_models()], [calibration_ppc()]
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read_validations(list.files(file.path(ex, "validation"),
#'                                    full.names = TRUE))
#' # Species intercepts as fixed effects, so that lme4 is not needed
#' q <- calibration_quality(val, tp ~ logit_conf + species, k_folds = 3)
#' q[c("species", "n", "auc", "auc_score", "logloss_gain", "cal_slope",
#'     "status")]
#' @export
calibration_quality <- function(validations, formula, k_folds = 5,
                                seed = 2026, fold_group = NULL,
                                by = "species", min_class = 10,
                                auc_min = 0.7, slope_range = c(0.5, 1.5),
                                intercept_max = 1) {
  if (!inherits(formula, "formula")) {
    stop("`formula` must be a model formula.", call. = FALSE)
  }
  if (!is.character(by) || length(by) == 0L || anyNA(by) ||
      !all(by %in% names(validations))) {
    stop("`by` must name columns of `validations`.", call. = FALSE)
  }
  if (anyNA(validations[by])) {
    stop("The `by` columns must have no missing values.", call. = FALSE)
  }
  if (!is.numeric(slope_range) || length(slope_range) != 2L ||
      anyNA(slope_range) || slope_range[1] >= slope_range[2]) {
    stop("`slope_range` must be two increasing numbers.", call. = FALSE)
  }
  check_number(seed, "seed", integer = TRUE)
  check_prob(auc_min, "auc_min")
  check_number(intercept_max, "intercept_max", lower = 0)
  need_lme4(list(formula))

  val <- validations
  val$.fold <- calibration_folds(validations, k_folds, seed, fold_group)
  val$.group <- do.call(paste, c(lapply(val[by], as.character), sep = "\r"))
  val$.p <- NA_real_
  val$.p_null <- NA_real_
  n_failed <- 0L
  for (k in seq_len(k_folds)) {
    test_idx <- which(val$.fold == k)
    train <- val[val$.fold != k, ]
    fit <- tryCatch(fit_model(formula, train), error = function(e) NULL)
    if (is.null(fit)) {
      n_failed <- n_failed + 1L
      next
    }
    val$.p[test_idx] <- predict_tp(fit, val[test_idx, ])
    # group rate in the training folds, smoothed to avoid 0 or 1; a group
    # absent from training (grouped folds) gets the overall rate
    rate <- tapply(train$tp, train$.group,
                   function(x) (sum(x) + 1) / (length(x) + 2))
    p_null <- unname(rate[val$.group[test_idx]])
    p_null[is.na(p_null)] <- mean(train$tp)
    val$.p_null[test_idx] <- p_null
  }
  if (n_failed == k_folds) {
    stop("The fit failed in all the folds.", call. = FALSE)
  }
  if (n_failed > 0L) {
    warning("The fit failed in ", n_failed, " of ", k_folds,
            " folds, left out of the measures.", call. = FALSE)
  }

  val |>
    filter(!is.na(.p)) |>
    group_by(across(all_of(by))) |>
    group_modify(function(d, key) {
      quality_row(d, min_class, auc_min, slope_range, intercept_max)
    }) |>
    ungroup()
}

#' Quality measures of one group from held-out predictions
#'
#' @param d A data frame of the clips of one group, with columns `tp`,
#'   `confidence`, `.p` (held-out P(TP)) and `.p_null` (null-model
#'   probability).
#' @param min_class Integer scalar, least number of true and of false
#'   positives for the group to be judged.
#' @param auc_min Numeric scalar, lowest acceptable AUC.
#' @param slope_range Numeric vector of length 2, acceptable range of the
#'   calibration slope.
#' @param intercept_max Numeric scalar, largest acceptable absolute
#'   calibration intercept.
#' @return A one-row tibble with `n`, `n_tp`, `n_fp`, `conf_min`, `conf_max`,
#'   `auc`, `auc_score`, `logloss`, `logloss_null`, `logloss_gain`,
#'   `cal_intercept`, `cal_slope`, `status` and `reason`.
#' @noRd
quality_row <- function(d, min_class, auc_min, slope_range, intercept_max) {
  measures <- score_probabilities(d$tp, d$.p)
  ll_null <- score_probabilities(d$tp, d$.p_null)[["logloss"]]
  gain <- ll_null - measures[["logloss"]]
  n_tp <- sum(d$tp == 1L)
  n_fp <- sum(d$tp == 0L)
  auc_p <- auc_ordered(d$tp, d$.p)
  auc_sc <- auc_ordered(d$tp, d$confidence)
  slope <- measures[["cal_slope"]]
  intercept <- measures[["cal_intercept"]]

  is_out <- function(x) isTRUE(x)
  reasons <- c(
    if (is_out(gain <= 0)) "no gain over the null model",
    if (is_out(auc_p < auc_min)) "low AUC",
    if (is_out(auc_sc < auc_min)) "low AUC of the score",
    if (is_out(slope < slope_range[1] || slope > slope_range[2])) {
      "calibration slope out of range"
    },
    if (is_out(abs(intercept) > intercept_max)) {
      "calibration intercept out of range"
    })
  too_few <- n_tp < min_class || n_fp < min_class
  tibble(n = nrow(d), n_tp = n_tp, n_fp = n_fp,
         conf_min = min(d$confidence), conf_max = max(d$confidence),
         auc = auc_p, auc_score = auc_sc,
         logloss = measures[["logloss"]], logloss_null = ll_null,
         logloss_gain = gain, cal_intercept = intercept,
         cal_slope = slope,
         status = if (too_few) "insufficient"
                  else if (length(reasons) > 0) "poor" else "ok",
         reason = if (too_few) {
           paste0("fewer than ", min_class, " clips of a verdict")
         } else {
           paste(reasons, collapse = "; ")
         })
}

#' AUC with a fixed direction
#'
#' By default `pROC::roc()` reverses the ordering when it gives an area
#' below 0.5, which would hide an inverted score; here the direction is
#' fixed.
#'
#' @param tp Integer vector of 0/1 verdicts.
#' @param p Numeric vector of the same length, probabilities or scores.
#' @return Numeric scalar, the AUC, or `NA` when `tp` has a single value.
#' @noRd
auc_ordered <- function(tp, p) {
  if (n_distinct(tp) < 2L) return(NA_real_)
  as.numeric(pROC::auc(pROC::roc(tp, p, levels = c(0, 1), direction = "<",
                                 quiet = TRUE)))
}
