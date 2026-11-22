#' Compare the logistic calibration with flexible curves
#'
#' Checks the shape of the calibration curve before a threshold is taken
#' from it. For each group (by default, each species), fits the probability
#' that a reviewed clip is a true positive as a function of the logit of
#' its score with four curves: the logistic of [fit_calibration()] (linear
#' in the logit), a quadratic, a GAM (`mgcv`) and a monotone increasing GAM
#' (`scam`). Each curve is judged where the threshold lies, not on average,
#' and its thresholds are compared with the model-free threshold of the
#' weighted precision ([suggest_thresholds()]).
#'
#' **What is compared.** For each curve:
#'
#' - `cv_logloss`: log-loss of held-out clips in `k_folds`-fold
#'   cross-validation, with folds made of whole recordings (`cluster`), so
#'   that clips of the same recording are not split between fitting and
#'   testing. It is dominated by the bulk of the clips, mostly at low
#'   scores, and may tie across curves even when one is wrong near the
#'   threshold; use it together with `top_error`.
#' - `top_error`: calibration error in the high score bins (width
#'   `bin_width`, from `top_from` to 1): the mean, weighted by the effective
#'   number of clips of each bin, of the absolute difference between the
#'   observed precision of the bin and the mean probability predicted by the
#'   curve for its clips. Part of it is the sampling noise of the bins,
#'   shared by every curve, so `top_error_excess` (the error of the curve
#'   minus the smallest error of the flexible curves) is what the verdict
#'   uses.
#' - `threshold_p_tp`: the lowest score from which the curve stays at or
#'   above `target` (the rule `"probability"` of [calibrated_thresholds()]),
#'   on a grid of step `grid_step`. `max_p` is the highest value of the
#'   curve within the reviewed scores; when it stays below `target`, no score
#'   guarantees the target (`reaches_target = FALSE`).
#' - `threshold_precision`: the lowest score from which the precision of the
#'   clips kept, as predicted by the curve (the mean of the predicted
#'   probabilities of the reviewed clips at or above the cut, weighted by
#'   `1 / inclusion_prob`), stays at or above `target`. It answers the same
#'   question as the weighted count, `threshold_weighted`, so
#'   `diff_weighted` (their difference) is direct evidence on the shape of
#'   the curve.
#'
#' **Verdict.** One per group, following the decision table of the
#' threshold workflow:
#'
#' - `"too_few_clips"`: fewer than `min_n` clips, or fewer than two of
#'   either verdict; no curve is fitted.
#' - `"sample_more_near_threshold"`: fewer than `min_n` effective clips in
#'   the high score bins; a new round there (`sampling_mode =
#'   "score_bands"` in [select_clips()], joined by [combine_rounds()]) is
#'   needed before deciding.
#' - `"no_curve_reaches_target"`: neither the flexible curves nor the
#'   weighted count give a threshold with precision `target` (with at least
#'   `min_n` effective clips above it). The curve levels off before the
#'   target, or reaches it only at the very top, and no usable score
#'   guarantees it: improve the classifier before setting a threshold.
#' - `"keep_logistic"`: the logistic has `top_error_excess <= max_error`
#'   and its `threshold_precision` agrees with the weighted count: within
#'   `tolerance` of it or, with `n_boot > 0`, either within `tolerance` or
#'   with a bootstrap interval of the difference that includes 0 (the two
#'   thresholds do not disagree more than the sample allows). A flexible curve may still fit better in log-loss, but away
#'   from the threshold.
#' - `"use_monotone_or_weighted"`: larger error in the high bins, or
#'   thresholds that disagree; take the threshold from the monotone GAM or
#'   from the weighted precision ([suggest_thresholds()],
#'   [threshold_bootstrap()]).
#'
#' **Bootstrap of the disagreement.** With `n_boot > 0`, the clips are
#' resampled by whole recordings (`cluster`) and, in each replicate, the
#' logistic is refitted and its `threshold_precision` and the weighted
#' count are recomputed. The quantiles of their difference give
#' `diff_weighted_lower` and `diff_weighted_upper` (row of the logistic),
#' so that a difference larger than `tolerance` counts against the logistic
#' only when it is larger than the sampling noise. Only the logistic and
#' the weighted count are resampled, since refitting the GAMs in each
#' replicate would be slow. When fewer than half of the replicates give
#' both thresholds, the interval is `NA` and the fixed `tolerance` is used.
#'
#' **What the verdict detects.** The verdict is built to detect a drop of
#' the precision at the top of the scores, that is false positives with
#' high scores (for instance, a sound similar to the species), where the
#' logistic overestimates the precision near the threshold. It is not a
#' general choice of the best curve: when the shape departs from the
#' logistic in other ways, neither `"keep_logistic"` nor
#' `"use_monotone_or_weighted"` says which threshold has the smaller error,
#' and `cv_logloss` is a weak guide to that choice (see above). In
#' particular, `"keep_logistic"` does not guarantee the target when the
#' precision levels off just above it: the logistic then crosses the target
#' too early, and its threshold can miss it in most samples, while the
#' verdict, above all with the bootstrap interval of `n_boot`, often keeps
#' it. Read the verdict as a check of the shape of the curve, not as the
#' choice of the threshold to apply; for that, use the conservative
#' threshold of [threshold_bootstrap()] (`threshold_conservative`), which
#' also gives the uncertainty of the threshold.
#'
#' **Which clips.** Clips of any probability design can be used:
#' `"random_detections"` and `"score_bands"` clips carry `inclusion_prob`,
#' and are weighted by `1 / inclusion_prob` in the fits and in the
#' precision (`weighted = NULL` does so when every clip of the group has
#' it). Clips of `"top"` have no inclusion probability; with them, the
#' weighted count is not an estimate of the precision of the predictions.
#' Fitting with and without weights (`weighted = TRUE` and `FALSE`) is also
#' a check of the shape: similar thresholds mean the shape is right.
#'
#' @param validation A data frame (or tibble) of the reviewed clips, one row per
#'   clip, as for [suggest_thresholds()]: with `verdict` (`"positive"` or
#'   `"negative"`; others are left out), `confidence` and, for weights,
#'   `inclusion_prob`.
#' @param target Numeric vector of values in (0, 1), target probability
#'   (`threshold_p_tp`) and precision (`threshold_precision`,
#'   `threshold_weighted`). Several targets can be given: the curves and the
#'   cross-validation are fitted once per group, and the result has one row per
#'   group x target x curve.
#' @param by Character vector of columns of `validation` that define the groups
#'   fitted separately. `"species_folder"` by default;
#'   `c("site", "species_folder")` fits each cell.
#' @param curves Character vector, the curves to fit, among `"logistic"`,
#'   `"quadratic"`, `"gam"` and `"monotone_gam"`. `"gam"` needs the package
#'   `mgcv` and `"monotone_gam"` the package `scam`; a curve whose package is
#'   missing is left out with a message.
#' @param weighted `NULL` or a logical scalar: `NULL` (weight by
#'   `1 / inclusion_prob` the groups whose clips all have it), `TRUE` or
#'   `FALSE`.
#' @param k Integer scalar, basis dimension of the GAMs (reduced when the group
#'   has fewer distinct scores).
#' @param k_folds Integer scalar, number of folds of the cross-validation.
#' @param cv Logical scalar. `FALSE` skips the cross-validation (`cv_logloss`,
#'   `cv_logloss_se` and `within_1se` are `NA`), when only the thresholds and
#'   the verdict, which does not use it, are needed.
#' @param cluster Character scalar, the column of `validation` whose levels are
#'   kept together in the folds (`"source_audio"`, the recording, by default).
#'   Without it, clips are split one by one.
#' @param top_from,bin_width Numeric scalars in (0, 1), lower limit and width of
#'   the high score bins of `top_error`.
#' @param min_n Numeric scalar, minimum number of clips of a group, of
#'   (effective) clips at or above a cut for it to count, and of effective clips
#'   in the high bins.
#' @param min_bin Numeric scalar, minimum number of clips of a bin for it to
#'   enter `top_error`.
#' @param max_error,tolerance Numeric scalars, largest `top_error_excess` and
#'   largest difference between the logistic and the weighted thresholds, in
#'   score units, for `"keep_logistic"`.
#' @param n_boot Numeric scalar >= 0, number of bootstrap replicates of the
#'   difference between the logistic and the weighted thresholds (`0`, the
#'   default, skips it).
#' @param conf Numeric scalar in (0, 1), probability of the bootstrap interval
#'   of the difference.
#' @param grid_step Numeric scalar in (0, 1), step of the grid of scores of
#'   `threshold_p_tp` and of the curves returned.
#' @param seed Integer scalar, seed of the folds. The global random number
#'   generator is left as it was.
#'
#' @return A tibble with one row per group x target x curve: the `by`
#'   columns,
#'   `curve`, `target`, `n`, `n_positive`, `cv_logloss`, `cv_logloss_se`,
#'   `within_1se` (log-loss within one standard error of the best curve of
#'   the group), `top_error`, `top_error_excess`, `n_eff_top`, `max_p`,
#'   `reaches_target`,
#'   `threshold_p_tp`, `threshold_precision`, `threshold_weighted`,
#'   `diff_weighted`, `diff_weighted_lower`, `diff_weighted_upper` (bootstrap
#'   interval of `diff_weighted`, logistic only, with `n_boot > 0`),
#'   `above_reviewed` (a threshold above the highest
#'   reviewed score is an extrapolation), `weighted` and `verdict`. The
#'   attribute `"curves"` holds the fitted curves on the grid (`score`,
#'   `p_tp`) and `"bins"` the observed precision by bin, for
#'   [plot_calibration_curves()].
#' @references
#' Wood, C. M. & Kahl, S. (2024). Guidelines for appropriate use of
#' BirdNET scores and other detector outputs. *Journal of Ornithology*,
#' 165, 777-782. \doi{10.1007/s10336-024-02144-5}
#' @seealso [fit_calibration()], [compare_calibration_models()],
#'   [calibrated_thresholds()], [suggest_thresholds()],
#'   [threshold_bootstrap()].
#' @export
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' validation <- read_validation_tables(list.files(file.path(ex, "validation"),
#'                                                 full.names = TRUE))
#' # Two fast curves; "gam" and "monotone_gam" can be added but are slower
#' cmp <- compare_calibration_curves(validation, target = 0.95,
#'                                   curves = c("logistic", "quadratic"),
#'                                   k_folds = 3)
#' cmp[c("species_folder", "curve", "top_error", "threshold_precision",
#'       "threshold_weighted", "verdict")]
#' if (requireNamespace("ggplot2", quietly = TRUE)) plot_calibration_curves(cmp)
compare_calibration_curves <- function(validation, target = 0.95,
                                       by = "species_folder",
                                       curves = c("logistic", "quadratic",
                                                  "gam", "monotone_gam"),
                                       weighted = NULL, k = 5, k_folds = 5,
                                       cv = TRUE, cluster = "source_audio",
                                       top_from = 0.7, bin_width = 0.05,
                                       min_n = 15, min_bin = 5,
                                       max_error = 0.03, tolerance = 0.03,
                                       n_boot = 0, conf = 0.95,
                                       grid_step = 0.01, seed = 2026) {
  valid_curves <- c("logistic", "quadratic", "gam", "monotone_gam")
  if (!is.character(curves) || length(curves) == 0 ||
      !all(curves %in% valid_curves)) {
    stop("`curves` must be among: ", paste(valid_curves, collapse = ", "), ".",
         call. = FALSE)
  }
  if (!is.numeric(target) || length(target) == 0 || anyNA(target) ||
      any(target <= 0) || any(target >= 1)) {
    stop("`target` must be one or more numbers between 0 and 1.",
         call. = FALSE)
  }
  target <- sort(unique(target))
  if (!is.numeric(n_boot) || length(n_boot) != 1 || is.na(n_boot) ||
      n_boot < 0) {
    stop("`n_boot` must be a single number >= 0.", call. = FALSE)
  }
  check_prob(conf, "conf", open = TRUE)
  if (!isTRUE(cv) && !isFALSE(cv)) {
    stop("`cv` must be TRUE or FALSE.", call. = FALSE)
  }
  check_by(validation, by)
  if ("gam" %in% curves && !has_suggested("mgcv")) {
    message("Package mgcv is not installed: the GAM is left out.")
    curves <- setdiff(curves, "gam")
  }
  if ("monotone_gam" %in% curves &&
      !has_suggested("scam")) {
    message("Package scam is not installed: the monotone GAM is left out. ",
            "Install it with install.packages(\"scam\").")
    curves <- setdiff(curves, "monotone_gam")
  }
  reviewed <- reviewed_with_confidence(validation)
  check_reviewed(reviewed)
  has_w <- has_inclusion_prob(reviewed)
  if (!has_w) reviewed$inclusion_prob <- NA_real_
  if (isTRUE(weighted) && !has_w) {
    stop_without_inclusion_prob()
  }
  no_cluster <- !cluster %in% names(reviewed)
  if (no_cluster) {
    message("`cluster` (", cluster, ") is not a column of `validation`: ",
            "the folds split clips one by one.")
  }
  grid <- seq(grid_step * ceiling(min(reviewed$confidence) / grid_step),
               1, by = grid_step)
  groups <- if (length(by) == 0) list(reviewed) else
    split(reviewed, reviewed[by], drop = TRUE)

  results <- withr::with_seed(seed, lapply(groups, function(d) {
    key <- if (length(by) == 0) tibble() else
      as_tibble(d[1, by, drop = FALSE])
    out <- curves_for_group(d, curves, target, weighted, k,
                            if (cv) k_folds else 0L,
                            if (no_cluster) NULL else cluster, top_from,
                            bin_width, min_n, min_bin, max_error, tolerance,
                            grid, n_boot, conf)
    list(tab = bind_cols(key[rep(1, nrow(out$tab)), , drop = FALSE],
                         out$tab),
         curve_tab = if (is.null(out$curve_tab)) NULL else
           bind_cols(key[rep(1, nrow(out$curve_tab)), , drop = FALSE],
                     out$curve_tab),
         bins_tab = if (is.null(out$bins_tab)) NULL else
           bind_cols(key[rep(1, nrow(out$bins_tab)), , drop = FALSE],
                     out$bins_tab))
  }))
  res <- bind_rows(lapply(results, `[[`, "tab"))
  attr(res, "curves") <- bind_rows(lapply(results, `[[`, "curve_tab"))
  attr(res, "bins") <- bind_rows(lapply(results, `[[`, "bins_tab"))
  attr(res, "target") <- target
  attr(res, "by") <- by
  res
}

#' Fit and judge the calibration curves of one group
#'
#' @param d A data frame of the reviewed clips of one group, with `verdict`,
#'   `confidence`, `inclusion_prob` and, optionally, the `cluster` column.
#' @param curves Character vector, curves to fit.
#' @param target Numeric vector in (0, 1), target probabilities/precisions.
#' @param weighted `NULL`, `TRUE` or `FALSE`; see compare_calibration_curves().
#' @param k Integer scalar, basis dimension of the GAMs.
#' @param k_folds Integer scalar, number of folds; `0` skips the
#'   cross-validation.
#' @param cluster Character scalar or `NULL`, column kept whole in the folds.
#' @param top_from,bin_width Numeric scalars, lower limit and width of the
#'   high score bins.
#' @param min_n Integer scalar, minimum number of (effective) clips.
#' @param min_bin Integer scalar, minimum number of clips of a high bin.
#' @param max_error,tolerance Numeric scalars, limits for `"keep_logistic"`.
#' @param grid Numeric vector, score grid of the thresholds and curves.
#' @param n_boot Integer scalar, number of bootstrap replicates.
#' @param conf Numeric scalar in (0, 1), probability of the bootstrap
#'   interval.
#' @return A list with `tab` (one row per target x curve), `curve_tab`
#'   (fitted curves on the grid; absent with too few clips) and `bins_tab`
#'   (observed precision of the high bins).
#' @noRd
curves_for_group <- function(d, curves, target, weighted, k, k_folds,
                             cluster, top_from, bin_width, min_n, min_bin,
                             max_error, tolerance, grid, n_boot = 0,
                             conf = 0.95) {
  d$tp <- as.integer(d$verdict == "positive")
  d$x <- score_logit(d$confidence)
  complete_w <- !anyNA(d$inclusion_prob)
  use_w <- complete_w && !isFALSE(weighted)
  d$w <- if (use_w) 1 / d$inclusion_prob else rep(1, nrow(d))
  d$w <- d$w / mean(d$w)
  # model-free threshold: the weighted count of suggest_thresholds(), by target
  thr_emp <- vapply(target, function(t) {
    threshold_for(d, t, min_n, has_weights = complete_w,
                  weighted = if (use_w) TRUE else FALSE,
                  sustained = TRUE)$threshold
  }, numeric(1))
  base <- tidyr::expand_grid(target = target, curve = curves) |>
    mutate(n = nrow(d), n_positive = sum(d$tp), .after = curve) |>
    relocate(curve, .before = target)
  empty <- base |>
    mutate(cv_logloss = NA_real_, cv_logloss_se = NA_real_,
           within_1se = NA, top_error = NA_real_,
           top_error_excess = NA_real_, n_eff_top = NA_real_,
           max_p = NA_real_, reaches_target = NA,
           threshold_p_tp = NA_real_, threshold_precision = NA_real_,
           threshold_weighted = thr_emp[match(target, .env$target)],
           diff_weighted = NA_real_, diff_weighted_lower = NA_real_,
           diff_weighted_upper = NA_real_, above_reviewed = NA,
           weighted = use_w, verdict = "too_few_clips")
  if (nrow(d) < min_n || sum(d$tp) < 2 || sum(1 - d$tp) < 2) {
    return(list(tab = empty))
  }

  fits <- lapply(curves, function(cv) fit_curve(cv, d, k))
  names(fits) <- curves
  # cross-validation with folds of whole recordings (k_folds = 0: skip)
  losses <- if (k_folds == 0) {
    matrix(NA_real_, 2, length(curves), dimnames = list(NULL, curves))
  } else {
    folds <- make_folds(d, k_folds, cluster)
    vapply(curves, function(cv) {
      fold_loss <- vapply(seq_len(max(folds)), function(f) {
        train <- d[folds != f, ]
        test <- d[folds == f, ]
        if (sum(train$tp) < 2 || sum(1 - train$tp) < 2) return(NA_real_)
        a <- fit_curve(cv, train, k)
        if (is.null(a)) return(NA_real_)
        p <- clamp_p(predict_curve(a, test$x))
        ll <- -(test$tp * log(p) + (1 - test$tp) * log(1 - p))
        sum(test$w * ll) / sum(test$w)
      }, numeric(1))
      ok <- !is.na(fold_loss)
      c(if (any(ok)) mean(fold_loss[ok]) else NA_real_,
        if (sum(ok) > 1) stats::sd(fold_loss[ok]) / sqrt(sum(ok)) else
          NA_real_)
    }, numeric(2))
  }

  # high score bins, observed vs predicted
  breaks <- unique(c(seq(top_from, 1, by = bin_width), 1))
  d$.bin <- cut(d$confidence, breaks, include.lowest = TRUE,
                 right = FALSE)
  high <- d[!is.na(d$.bin), ]
  bins_obs <- high |>
    group_by(.bin) |>
    summarise(n = n(), n_eff = sum(w)^2 / sum(w^2),
              observed = sum(w * tp) / sum(w),
              score = mean(confidence), .groups = "drop") |>
    mutate(bin = as.character(.bin), .before = 1) |>
    select(-.bin)
  n_eff_top <- if (nrow(high) == 0) 0 else sum(high$w)^2 / sum(high$w^2)

  max_rev <- max(d$confidence)
  cuts <- sort(unique(round(d$confidence, 2)))
  cuts <- cuts[cuts <= max_rev]
  grid_rev <- grid[grid <= max_rev + 1e-9]
  rows <- lapply(curves, function(cv) {
    a <- fits[[cv]]
    if (is.null(a)) {
      return(tibble(curve = cv, target = target, top_error = NA_real_,
                    max_p = NA_real_, threshold_p_tp = NA_real_,
                    threshold_precision = NA_real_))
    }
    d$p <- predict_curve(a, d$x)
    # calibration error in the high bins
    err <- if (nrow(high) == 0) NA_real_ else {
      e <- d[!is.na(d$.bin), ] |>
        group_by(.bin) |>
        summarise(n = n(), n_eff = sum(w)^2 / sum(w^2),
                  obs = sum(w * tp) / sum(w), pred = sum(w * p) / sum(w),
                  .groups = "drop") |>
        filter(n >= min_bin)
      if (nrow(e) == 0) NA_real_ else
        sum(e$n_eff * abs(e$obs - e$pred)) / sum(e$n_eff)
    }
    p_grid <- predict_curve(a, score_logit(grid_rev))
    # predicted precision of the clips above each cut (weighted)
    prec <- vapply(cuts, function(c0) {
      s <- d$confidence >= c0
      if (sum(d$w[s])^2 / sum(d$w[s]^2) < min_n) return(NA_real_)
      sum(d$w[s] * d$p[s]) / sum(d$w[s])
    }, numeric(1))
    bind_rows(lapply(target, function(t) {
      i <- first_sustained(p_grid, t)
      j <- first_sustained(prec, t)
      tibble(curve = cv, target = t, top_error = err, max_p = max(p_grid),
             threshold_p_tp = if (is.na(i)) NA_real_ else grid_rev[i],
             threshold_precision = if (is.na(j)) NA_real_ else cuts[j])
    }))
  })
  tab <- base |>
    mutate(cv_logloss = losses[1, curve], cv_logloss_se = losses[2, curve]) |>
    left_join(bind_rows(rows), by = c("curve", "target")) |>
    group_by(target) |>
    mutate(within_1se = {
             best <- which.min(cv_logloss)
             if (length(best) == 0) NA else
               cv_logloss <= cv_logloss[best] +
                 dplyr::coalesce(cv_logloss_se[best], 0)
           },
           top_error_excess = top_error - suppressWarnings(min(
             top_error[curve %in% c("quadratic", "gam", "monotone_gam")],
             na.rm = TRUE)),
           top_error_excess = ifelse(is.finite(top_error_excess),
                                     top_error_excess, NA_real_),
           n_eff_top = n_eff_top,
           reaches_target = max_p >= target,
           threshold_weighted = thr_emp[match(target, .env$target)],
           diff_weighted = threshold_precision - threshold_weighted,
           diff_weighted_lower = NA_real_, diff_weighted_upper = NA_real_,
           above_reviewed = pmax(threshold_p_tp, threshold_precision,
                                 na.rm = TRUE) > max_rev,
           weighted = use_w) |>
    ungroup()
  if (n_boot > 0 && "logistic" %in% curves) {
    ci <- boot_diff_weighted(d, target, min_n, complete_w, use_w, k,
                             n_boot, cluster, conf)
    is_log <- tab$curve == "logistic"
    i <- match(tab$target[is_log], target)
    tab$diff_weighted_lower[is_log] <- ci[1, i]
    tab$diff_weighted_upper[is_log] <- ci[2, i]
  }
  tab <- tab |>
    group_by(target) |>
    mutate(verdict = curve_verdict(pick(everything()), .env$n_eff_top, min_n,
                                   max_error, tolerance)) |>
    ungroup()

  curve_tab <- bind_rows(lapply(curves, function(cv) {
    a <- fits[[cv]]
    if (is.null(a)) return(NULL)
    tibble(curve = cv, score = grid,
           p_tp = predict_curve(a, score_logit(grid)))
  }))
  list(tab = tab, curve_tab = curve_tab, bins_tab = bins_obs)
}

#' Verdict of one group from the decision table of the threshold workflow
#'
#' @param tab A data frame with the rows of one group and target, one per
#'   curve, with `curve`, `threshold_precision`, `threshold_weighted`,
#'   `top_error`, `top_error_excess`, `diff_weighted`, `diff_weighted_lower`
#'   and `diff_weighted_upper`.
#' @param n_eff_top Numeric scalar, effective number of clips in the high
#'   bins.
#' @param min_n Integer scalar, minimum number of effective clips.
#' @param max_error,tolerance Numeric scalars, limits for `"keep_logistic"`.
#' @return Character vector of length `nrow(tab)`, the verdict repeated.
#' @noRd
curve_verdict <- function(tab, n_eff_top, min_n, max_error, tolerance) {
  # target reached: some precision threshold (flexible curve or weighted
  # count); without a flexible curve, the logistic counts
  flex <- tab$curve %in% c("monotone_gam", "gam", "quadratic")
  if (!any(flex)) flex <- rep(TRUE, nrow(tab))
  reaches <- any(!is.na(tab$threshold_precision[flex])) ||
    !is.na(tab$threshold_weighted[1])
  log <- tab[tab$curve == "logistic", ]
  verdict_val <- if (n_eff_top < min_n) {
    "sample_more_near_threshold"
  } else if (!reaches) {
    "no_curve_reaches_target"
  } else if (nrow(log) == 1 &&
             isTRUE(dplyr::coalesce(log$top_error_excess, log$top_error) <=
                      max_error) &&
             (isTRUE(abs(log$diff_weighted) <= tolerance + 1e-8) ||
                isTRUE(log$diff_weighted_lower <= 0 &
                         log$diff_weighted_upper >= 0))) {
    "keep_logistic"
  } else {
    "use_monotone_or_weighted"
  }
  rep(verdict_val, nrow(tab))
}

#' Bootstrap interval of the logistic minus weighted-count threshold
#'
#' Resamples whole recordings (`cluster`) and, in each replicate, refits the
#' logistic and recomputes its precision threshold and the weighted count.
#'
#' @param d A data frame of the clips of one group, with `tp`, `x`, `w`,
#'   `confidence` and `inclusion_prob`.
#' @param target Numeric vector in (0, 1), targets.
#' @param min_n Integer scalar, minimum number of effective clips above a cut.
#' @param complete_w Logical scalar, whether every clip has `inclusion_prob`.
#' @param use_w Logical scalar, whether the weighted count uses weights.
#' @param k Integer scalar, passed to fit_curve().
#' @param n_boot Integer scalar, number of replicates.
#' @param cluster Character scalar or `NULL`, column resampled as a unit.
#' @param conf Numeric scalar in (0, 1), probability of the interval.
#' @return A numeric matrix with 2 rows (lower, upper) and one column per
#'   target; `NA` when fewer than half of the replicates give both
#'   thresholds.
#' @noRd
boot_diff_weighted <- function(d, target, min_n, complete_w, use_w, k,
                               n_boot, cluster, conf) {
  units <- if (is.null(cluster)) seq_len(nrow(d)) else
    as.character(d[[cluster]])
  groups <- split(seq_len(nrow(d)), units)
  diffs <- vapply(seq_len(n_boot), function(b) {
    db <- d[unlist(groups[sample(length(groups), replace = TRUE)],
                   use.names = FALSE), ]
    na <- rep(NA_real_, length(target))
    if (sum(db$tp) < 2 || sum(1 - db$tp) < 2) return(na)
    a <- fit_curve("logistic", db, k)
    if (is.null(a)) return(na)
    log_thr <- predicted_precision_thresholds(db, predict_curve(a, db$x),
                                              target, min_n)
    emp <- vapply(target, function(t) {
      threshold_for(db, t, min_n, has_weights = complete_w,
                    weighted = if (use_w) TRUE else FALSE,
                    sustained = TRUE)$threshold
    }, numeric(1))
    log_thr - emp
  }, numeric(length(target)))
  diffs <- matrix(diffs, nrow = length(target))
  apply(diffs, 1, function(x) {
    ok <- !is.na(x)
    if (mean(ok) < 0.5) return(c(NA_real_, NA_real_))
    unname(stats::quantile(x[ok], c((1 - conf) / 2, 1 - (1 - conf) / 2),
                           names = FALSE))
  })
}

#' Thresholds from the predicted precision of the clips kept
#'
#' The lowest cut from which the weighted mean of `p` over the clips at or
#' above it stays at the target, as `threshold_precision`.
#'
#' @param d A data frame of clips with `confidence` and `w`.
#' @param p Numeric vector, predicted P(TP) of each row of `d`.
#' @param target Numeric vector in (0, 1), targets.
#' @param min_n Integer scalar, minimum number of effective clips above a cut.
#' @return Numeric vector with one threshold per target (`NA` if none).
#' @noRd
predicted_precision_thresholds <- function(d, p, target, min_n) {
  cuts <- sort(unique(round(d$confidence, 2)))
  cuts <- cuts[cuts <= max(d$confidence)]
  prec <- vapply(cuts, function(c0) {
    s <- d$confidence >= c0
    if (sum(d$w[s])^2 / sum(d$w[s]^2) < min_n) return(NA_real_)
    sum(d$w[s] * p[s]) / sum(d$w[s])
  }, numeric(1))
  vapply(target, function(t) {
    j <- first_sustained(prec, t)
    if (is.na(j)) NA_real_ else cuts[j]
  }, numeric(1))
}

#' Logit of the score, with the extremes clamped
#'
#' @param conf Numeric vector in \[0, 1\], confidence scores.
#' @return Numeric vector of logits.
#' @noRd
score_logit <- function(conf) {
  stats::qlogis(pmin(pmax(conf, 1e-4), 1 - 1e-4))
}

#' Clamp probabilities away from 0 and 1
#'
#' @param p Numeric vector of probabilities.
#' @return Numeric vector, `p` limited to \[1e-6, 1 - 1e-6\].
#' @noRd
clamp_p <- function(p) pmin(pmax(p, 1e-6), 1 - 1e-6)

#' Cross-validation folds keeping whole levels of a cluster
#'
#' @param d A data frame of clips.
#' @param k_folds Integer scalar, number of folds (reduced to the number of
#'   levels).
#' @param cluster Character scalar or `NULL`, column whose levels are kept
#'   whole; `NULL` splits rows one by one.
#' @return Integer vector with the fold of each row of `d`.
#' @noRd
make_folds <- function(d, k_folds, cluster) {
  units <- if (is.null(cluster)) seq_len(nrow(d)) else
    as.character(d[[cluster]])
  lvls <- unique(units)
  k_folds <- min(k_folds, length(lvls))
  draw <- sample(rep_len(seq_len(k_folds), length(lvls)))
  draw[match(units, lvls)]
}

#' Fit a curve of P(TP) on the logit of the score
#'
#' @param curve Character scalar, `"logistic"`, `"quadratic"`, `"gam"` or
#'   `"monotone_gam"`.
#' @param d A data frame with columns `tp`, `x` (logit of the score) and `w`
#'   (weights).
#' @param k Integer scalar, basis dimension of the GAMs.
#' @return The fitted model, or `NULL` when the fit fails.
#' @noRd
fit_curve <- function(curve, d, k) {
  kk <- max(3, min(k, length(unique(d$x)) - 1))
  fit_obj <- tryCatch(suppressWarnings(switch(
    curve,
    logistic = stats::glm(tp ~ x, family = stats::quasibinomial(),
                          data = d, weights = w),
    quadratic = stats::glm(tp ~ x + I(x^2), family = stats::quasibinomial(),
                           data = d, weights = w),
    gam = mgcv::gam(tp ~ s(x, k = kk), family = stats::quasibinomial(),
                    data = d, weights = w, method = "REML"),
    monotone_gam = scam::scam(tp ~ s(x, k = kk, bs = "mpi"),
                              family = stats::binomial(), data = d,
                              weights = w)
  )), error = function(e) NULL)
  fit_obj
}

#' Predict P(TP) from a fitted curve
#'
#' @param fit A model returned by fit_curve().
#' @param x Numeric vector, logits of the scores.
#' @return Numeric vector of predicted probabilities.
#' @noRd
predict_curve <- function(fit, x) {
  as.numeric(stats::predict(fit, newdata = data.frame(x = x),
                            type = "response"))
}

#' Plot the calibration curves of compare_calibration_curves()
#'
#' Observed precision by score bin (points, sized by the number of clips)
#' and the fitted curves, by group, with the target as a dashed line. The
#' curves should pass through the points near the target.
#'
#' @param x A data frame (tibble), the output of [compare_calibration_curves()].
#' @param bin_width Numeric scalar in (0, 1), width of the bins of the observed
#'   precision, over the whole score range.
#' @param validation `NULL` or a data frame (or tibble) of the reviewed clips,
#'   one row per clip, to show bins over the whole score range. Without it, only
#'   the high bins of `top_error` are shown.
#' @return A ggplot object.
#' @export
plot_calibration_curves <- function(x, validation = NULL, bin_width = 0.1) {
  require_suggested("ggplot2", "to plot the calibration curves")
  curve_tab <- attr(x, "curves")
  by <- attr(x, "by")
  if (is.null(curve_tab) || nrow(curve_tab) == 0) {
    stop("`x` has no fitted curves.", call. = FALSE)
  }
  bins_tab <- if (is.null(validation)) attr(x, "bins") else {
    v <- reviewed_with_confidence(validation)
    has_w <- has_inclusion_prob(v) && !anyNA(v$inclusion_prob)
    v$w <- if (has_w) 1 / v$inclusion_prob else 1
    v$bin <- cut(v$confidence, seq(0, 1, by = bin_width),
                 include.lowest = TRUE, right = FALSE)
    v |>
      group_by(across(all_of(c(by, "bin")))) |>
      summarise(n = n(),
                observed = sum(w * (verdict == "positive")) / sum(w),
                score = mean(confidence), .groups = "drop")
  }
  panel <- if (length(by) == 0) NULL else
    interaction(curve_tab[by], sep = " | ", drop = TRUE)
  curve_tab$panel <- if (is.null(panel)) "all" else panel
  bins_tab$panel <- if (length(by) == 0) "all" else
    interaction(bins_tab[by], sep = " | ", drop = TRUE)
  ggplot2::ggplot(curve_tab, ggplot2::aes(.data$score, .data$p_tp)) +
    ggplot2::geom_hline(yintercept = attr(x, "target"), linetype = 2,
                        colour = "grey50") +
    ggplot2::geom_point(data = bins_tab,
                        ggplot2::aes(.data$score, .data$observed,
                                     size = .data$n),
                        inherit.aes = FALSE, colour = "grey30") +
    ggplot2::geom_line(ggplot2::aes(colour = .data$curve)) +
    ggplot2::facet_wrap(~panel) +
    ggplot2::coord_cartesian(ylim = c(0, 1)) +
    ggplot2::labs(x = "Score", y = "P(true positive)", colour = "Curve",
                  size = "Clips") +
    ggplot2::theme_bw()
}
