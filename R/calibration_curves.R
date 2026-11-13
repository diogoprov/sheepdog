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
#'   and its `threshold_precision` is within `tolerance` of the weighted
#'   count. A flexible curve may still fit better in log-loss, but away
#'   from the threshold.
#' - `"use_monotone_or_weighted"`: larger error in the high bins, or
#'   thresholds that disagree; take the threshold from the monotone GAM or
#'   from the weighted precision ([suggest_thresholds()],
#'   [threshold_bootstrap()]).
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
#' @param validation Reviewed clips, as for [suggest_thresholds()]: with
#'   `verdict` (`"positive"` or `"negative"`; others are left out),
#'   `confidence` and, for weights, `inclusion_prob`.
#' @param target Target probability (`threshold_p_tp`) and precision
#'   (`threshold_precision`, `threshold_weighted`).
#' @param by Columns of `validation` that define the groups fitted
#'   separately. `"species_folder"` by default; `c("site",
#'   "species_folder")` fits each cell.
#' @param curves Curves to fit, among `"logistic"`, `"quadratic"`, `"gam"`
#'   and `"monotone_gam"`. `"gam"` needs the package `mgcv` and
#'   `"monotone_gam"` the package `scam`; a curve whose package is missing
#'   is left out with a message.
#' @param weighted `NULL` (weight by `1 / inclusion_prob` the groups whose
#'   clips all have it), `TRUE` or `FALSE`.
#' @param k Basis dimension of the GAMs (reduced when the group has fewer
#'   distinct scores).
#' @param k_folds Number of folds of the cross-validation.
#' @param cluster Column of `validation` whose levels are kept together in
#'   the folds (`"source_audio"`, the recording, by default). Without it,
#'   clips are split one by one.
#' @param top_from,bin_width Lower limit and width of the high score bins
#'   of `top_error`.
#' @param min_n Minimum number of clips of a group, of (effective) clips at
#'   or above a cut for it to count, and of effective clips in the high
#'   bins.
#' @param min_bin Minimum number of clips of a bin for it to enter
#'   `top_error`.
#' @param max_error,tolerance Largest `top_error_excess` and largest
#'   difference between the logistic and the weighted thresholds, in score
#'   units, for `"keep_logistic"`.
#' @param grid_step Step of the grid of scores of `threshold_p_tp` and of
#'   the curves returned.
#' @param seed Seed of the folds. The global random number generator is
#'   left as it was.
#'
#' @return A tibble with one row per group x curve: the `by` columns,
#'   `curve`, `n`, `n_positive`, `cv_logloss`, `cv_logloss_se`,
#'   `within_1se` (log-loss within one standard error of the best curve of
#'   the group), `top_error`, `top_error_excess`, `n_eff_top`, `max_p`,
#'   `reaches_target`,
#'   `threshold_p_tp`, `threshold_precision`, `threshold_weighted`,
#'   `diff_weighted`, `above_reviewed` (a threshold above the highest
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
#' \dontrun{
#' cmp <- compare_calibration_curves(validation, target = 0.95)
#' cmp[c("species_folder", "curve", "top_error", "threshold_precision",
#'       "threshold_weighted", "verdict")]
#' plot_calibration_curves(cmp)
#' }
compare_calibration_curves <- function(validation, target = 0.95,
                                       by = "species_folder",
                                       curves = c("logistic", "quadratic",
                                                  "gam", "monotone_gam"),
                                       weighted = NULL, k = 5, k_folds = 5,
                                       cluster = "source_audio",
                                       top_from = 0.7, bin_width = 0.05,
                                       min_n = 15, min_bin = 5,
                                       max_error = 0.03, tolerance = 0.03,
                                       grid_step = 0.01, seed = 2026) {
  curvas_ok <- c("logistic", "quadratic", "gam", "monotone_gam")
  if (!is.character(curves) || length(curves) == 0 ||
      !all(curves %in% curvas_ok)) {
    stop("`curves` must be among: ", paste(curvas_ok, collapse = ", "), ".",
         call. = FALSE)
  }
  if (!is.numeric(target) || length(target) != 1 || target <= 0 ||
      target >= 1) {
    stop("`target` must be a single number between 0 and 1.", call. = FALSE)
  }
  check_by(validation, by)
  if ("gam" %in% curves && !requireNamespace("mgcv", quietly = TRUE)) {
    message("Package mgcv is not installed: the GAM is left out.")
    curves <- setdiff(curves, "gam")
  }
  if ("monotone_gam" %in% curves &&
      !requireNamespace("scam", quietly = TRUE)) {
    message("Package scam is not installed: the monotone GAM is left out. ",
            "Install it with install.packages(\"scam\").")
    curves <- setdiff(curves, "monotone_gam")
  }
  validados <- reviewed_with_confidence(validation)
  if (nrow(validados) == 0) {
    stop("No reviewed clip with a confidence in `validation`.",
         call. = FALSE)
  }
  pesos <- has_inclusion_prob(validados)
  if (!pesos) validados$inclusion_prob <- NA_real_
  if (isTRUE(weighted) && !pesos) {
    stop("`weighted = TRUE` needs `inclusion_prob`, which no reviewed clip ",
         "has.", call. = FALSE)
  }
  sem_cluster <- !cluster %in% names(validados)
  if (sem_cluster) {
    message("`cluster` (", cluster, ") is not a column of `validation`: ",
            "the folds split clips one by one.")
  }
  grade <- seq(grid_step * ceiling(min(validados$confidence) / grid_step),
               1, by = grid_step)
  grupos <- if (length(by) == 0) list(validados) else
    split(validados, validados[by], drop = TRUE)

  resultados <- withr::with_seed(seed, lapply(grupos, function(d) {
    chave <- if (length(by) == 0) tibble() else
      as_tibble(d[1, by, drop = FALSE])
    out <- curves_for_group(d, curves, target, weighted, k, k_folds,
                            if (sem_cluster) NULL else cluster, top_from,
                            bin_width, min_n, min_bin, max_error, tolerance,
                            grade)
    list(tabela = bind_cols(chave[rep(1, nrow(out$tabela)), , drop = FALSE],
                            out$tabela),
         curvas = if (is.null(out$curvas)) NULL else
           bind_cols(chave[rep(1, nrow(out$curvas)), , drop = FALSE],
                     out$curvas),
         faixas = if (is.null(out$faixas)) NULL else
           bind_cols(chave[rep(1, nrow(out$faixas)), , drop = FALSE],
                     out$faixas))
  }))
  saida <- bind_rows(lapply(resultados, `[[`, "tabela"))
  attr(saida, "curves") <- bind_rows(lapply(resultados, `[[`, "curvas"))
  attr(saida, "bins") <- bind_rows(lapply(resultados, `[[`, "faixas"))
  attr(saida, "target") <- target
  attr(saida, "by") <- by
  saida
}

# Ajusta e julga as curvas de um grupo
curves_for_group <- function(d, curves, target, weighted, k, k_folds,
                             cluster, top_from, bin_width, min_n, min_bin,
                             max_error, tolerance, grade) {
  d$tp <- as.integer(d$verdict == "positive")
  d$x <- score_logit(d$confidence)
  completa <- !anyNA(d$inclusion_prob)
  ponderar <- completa && !isFALSE(weighted)
  d$w <- if (ponderar) 1 / d$inclusion_prob else rep(1, nrow(d))
  d$w <- d$w / mean(d$w)
  # limiar sem modelo: a contagem ponderada de suggest_thresholds()
  empirico <- threshold_for(d, target, min_n, pesos = completa,
                            weighted = if (ponderar) TRUE else FALSE,
                            sustained = TRUE)$threshold
  base <- tibble(curve = curves, n = nrow(d), n_positive = sum(d$tp))
  vazio <- base |>
    mutate(cv_logloss = NA_real_, cv_logloss_se = NA_real_,
           within_1se = NA, top_error = NA_real_,
           top_error_excess = NA_real_, n_eff_top = NA_real_,
           max_p = NA_real_, reaches_target = NA,
           threshold_p_tp = NA_real_, threshold_precision = NA_real_,
           threshold_weighted = empirico,
           diff_weighted = NA_real_, above_reviewed = NA,
           weighted = ponderar, verdict = "too_few_clips")
  if (nrow(d) < min_n || sum(d$tp) < 2 || sum(1 - d$tp) < 2) {
    return(list(tabela = vazio))
  }

  ajustes <- lapply(curves, function(cv) fit_curve(cv, d, k))
  names(ajustes) <- curves
  # validacao cruzada com dobras de gravacoes inteiras
  dobras <- make_folds(d, k_folds, cluster)
  perdas <- vapply(curves, function(cv) {
    por_dobra <- vapply(seq_len(max(dobras)), function(f) {
      treino <- d[dobras != f, ]
      teste <- d[dobras == f, ]
      if (sum(treino$tp) < 2 || sum(1 - treino$tp) < 2) return(NA_real_)
      a <- fit_curve(cv, treino, k)
      if (is.null(a)) return(NA_real_)
      p <- clamp_p(predict_curve(a, teste$x))
      ll <- -(teste$tp * log(p) + (1 - teste$tp) * log(1 - p))
      sum(teste$w * ll) / sum(teste$w)
    }, numeric(1))
    ok <- !is.na(por_dobra)
    c(if (any(ok)) mean(por_dobra[ok]) else NA_real_,
      if (sum(ok) > 1) stats::sd(por_dobra[ok]) / sqrt(sum(ok)) else
        NA_real_)
  }, numeric(2))

  # faixas altas de score, observado x previsto
  quebras <- unique(c(seq(top_from, 1, by = bin_width), 1))
  d$faixa <- cut(d$confidence, quebras, include.lowest = TRUE,
                 right = FALSE)
  altas <- d[!is.na(d$faixa), ]
  faixas_obs <- altas |>
    group_by(faixa) |>
    summarise(n = n(), n_eff = sum(w)^2 / sum(w^2),
              observed = sum(w * tp) / sum(w),
              score = mean(confidence), .groups = "drop") |>
    mutate(bin = as.character(faixa), .before = 1) |>
    select(-faixa)
  n_eff_top <- if (nrow(altas) == 0) 0 else sum(altas$w)^2 / sum(altas$w^2)

  max_rev <- max(d$confidence)
  cortes <- sort(unique(round(d$confidence, 2)))
  cortes <- cortes[cortes <= max_rev]
  linhas <- lapply(curves, function(cv) {
    a <- ajustes[[cv]]
    if (is.null(a)) {
      return(tibble(curve = cv, top_error = NA_real_, max_p = NA_real_,
                    threshold_p_tp = NA_real_,
                    threshold_precision = NA_real_))
    }
    d$p <- predict_curve(a, d$x)
    # erro de calibracao nas faixas altas
    erro <- if (nrow(altas) == 0) NA_real_ else {
      e <- d[!is.na(d$faixa), ] |>
        group_by(faixa) |>
        summarise(n = n(), n_eff = sum(w)^2 / sum(w^2),
                  obs = sum(w * tp) / sum(w), pred = sum(w * p) / sum(w),
                  .groups = "drop") |>
        filter(n >= min_bin)
      if (nrow(e) == 0) NA_real_ else
        sum(e$n_eff * abs(e$obs - e$pred)) / sum(e$n_eff)
    }
    na_grade <- grade[grade <= max_rev + 1e-9]
    p_grade <- predict_curve(a, score_logit(na_grade))
    i <- first_sustained(p_grade, target)
    # precisao prevista dos clipes acima de cada corte (ponderada)
    prec <- vapply(cortes, function(c0) {
      s <- d$confidence >= c0
      if (sum(d$w[s])^2 / sum(d$w[s]^2) < min_n) return(NA_real_)
      sum(d$w[s] * d$p[s]) / sum(d$w[s])
    }, numeric(1))
    j <- first_sustained(prec, target)
    tibble(curve = cv, top_error = erro, max_p = max(p_grade),
           threshold_p_tp = if (is.na(i)) NA_real_ else na_grade[i],
           threshold_precision = if (is.na(j)) NA_real_ else cortes[j])
  })
  tabela <- base |>
    mutate(cv_logloss = perdas[1, ], cv_logloss_se = perdas[2, ]) |>
    left_join(bind_rows(linhas), by = "curve")
  melhor <- which.min(tabela$cv_logloss)
  tabela <- tabela |>
    mutate(within_1se = if (length(melhor) == 0) NA else
             cv_logloss <= cv_logloss[melhor] +
               dplyr::coalesce(cv_logloss_se[melhor], 0),
           top_error_excess = top_error - suppressWarnings(min(
             top_error[curve %in% c("quadratic", "gam", "monotone_gam")],
             na.rm = TRUE)),
           top_error_excess = ifelse(is.finite(top_error_excess),
                                     top_error_excess, NA_real_),
           n_eff_top = n_eff_top,
           reaches_target = max_p >= target,
           threshold_weighted = empirico,
           diff_weighted = threshold_precision - threshold_weighted,
           above_reviewed = pmax(threshold_p_tp, threshold_precision,
                                 na.rm = TRUE) > max_rev,
           weighted = ponderar)
  tabela$verdict <- curve_verdict(tabela, n_eff_top, min_n, max_error,
                                  tolerance)

  curvas <- bind_rows(lapply(curves, function(cv) {
    a <- ajustes[[cv]]
    if (is.null(a)) return(NULL)
    tibble(curve = cv, score = grade,
           p_tp = predict_curve(a, score_logit(grade)))
  }))
  list(tabela = tabela, curvas = curvas, faixas = faixas_obs)
}

# Veredito do grupo, pela tabela de decisao do fluxo de limiares
curve_verdict <- function(tabela, n_eff_top, min_n, max_error, tolerance) {
  # alcanca o alvo: algum limiar de precisao (curva flexivel ou contagem
  # ponderada); sem curva flexivel, vale a logistica
  flex <- tabela$curve %in% c("monotone_gam", "gam", "quadratic")
  if (!any(flex)) flex <- rep(TRUE, nrow(tabela))
  alcanca <- any(!is.na(tabela$threshold_precision[flex])) ||
    !is.na(tabela$threshold_weighted[1])
  log <- tabela[tabela$curve == "logistic", ]
  veredito <- if (n_eff_top < min_n) {
    "sample_more_near_threshold"
  } else if (!alcanca) {
    "no_curve_reaches_target"
  } else if (nrow(log) == 1 &&
             isTRUE(dplyr::coalesce(log$top_error_excess, log$top_error) <=
                      max_error) &&
             isTRUE(abs(log$diff_weighted) <= tolerance + 1e-8)) {
    "keep_logistic"
  } else {
    "use_monotone_or_weighted"
  }
  rep(veredito, nrow(tabela))
}

# Logito do score, com os extremos contidos
score_logit <- function(conf) {
  stats::qlogis(pmin(pmax(conf, 1e-4), 1 - 1e-4))
}

clamp_p <- function(p) pmin(pmax(p, 1e-6), 1 - 1e-6)

# Dobras da validacao cruzada: niveis de `cluster` inteiros em cada dobra
make_folds <- function(d, k_folds, cluster) {
  unidades <- if (is.null(cluster)) seq_len(nrow(d)) else
    as.character(d[[cluster]])
  niveis <- unique(unidades)
  k_folds <- min(k_folds, length(niveis))
  sorteio <- sample(rep_len(seq_len(k_folds), length(niveis)))
  sorteio[match(unidades, niveis)]
}

# Ajusta uma curva de P(TP) no logito do score; NULL quando o ajuste falha
fit_curve <- function(curve, d, k) {
  kk <- max(3, min(k, length(unique(d$x)) - 1))
  ajuste <- tryCatch(suppressWarnings(switch(
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
  ajuste
}

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
#' @param x Output of [compare_calibration_curves()].
#' @param bin_width Width of the bins of the observed precision, over the
#'   whole score range.
#' @param validation Optional: the reviewed clips, to show bins over the
#'   whole score range. Without it, only the high bins of `top_error` are
#'   shown.
#' @return A ggplot object.
#' @export
plot_calibration_curves <- function(x, validation = NULL, bin_width = 0.1) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("plot_calibration_curves() needs the package ggplot2.",
         call. = FALSE)
  }
  curvas <- attr(x, "curves")
  by <- attr(x, "by")
  if (is.null(curvas) || nrow(curvas) == 0) {
    stop("`x` has no fitted curves.", call. = FALSE)
  }
  faixas <- if (is.null(validation)) attr(x, "bins") else {
    v <- reviewed_with_confidence(validation)
    pesos <- has_inclusion_prob(v) && !anyNA(v$inclusion_prob)
    v$w <- if (pesos) 1 / v$inclusion_prob else 1
    v$bin <- cut(v$confidence, seq(0, 1, by = bin_width),
                 include.lowest = TRUE, right = FALSE)
    v |>
      group_by(across(all_of(c(by, "bin")))) |>
      summarise(n = n(),
                observed = sum(w * (verdict == "positive")) / sum(w),
                score = mean(confidence), .groups = "drop")
  }
  painel <- if (length(by) == 0) NULL else
    interaction(curvas[by], sep = " | ", drop = TRUE)
  curvas$panel <- if (is.null(painel)) "all" else painel
  faixas$panel <- if (length(by) == 0) "all" else
    interaction(faixas[by], sep = " | ", drop = TRUE)
  ggplot2::ggplot(curvas, ggplot2::aes(.data$score, .data$p_tp)) +
    ggplot2::geom_hline(yintercept = attr(x, "target"), linetype = 2,
                        colour = "grey50") +
    ggplot2::geom_point(data = faixas,
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
