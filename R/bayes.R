#' Example prior for a Bayesian calibration model
#'
#' Builds a weakly informative prior for a calibration formula, centred on
#' the hypothesis that the BirdNET score is already calibrated: on the
#' model scale (`tp ~ logit_conf`), intercept 0 and slope 1 mean
#' P(TP) = score. The data then show how far the classifier departs from
#' it. Only the classes present in the formula are returned:
#'
#' * `Intercept`: `normal(m, 1.5)`, where `m` is the mean of `logit_conf`
#'   among the reviewed clips. 'brms' centres the predictors, so its
#'   intercept is the logit of P(TP) at the mean logit score; with a slope
#'   of 1, an intercept equal to that mean gives P(TP) = score;
#' * `b` (slope of `logit_conf`): `normal(1, 1)` truncated at 0, centred on
#'   a calibrated score, wide enough to allow slopes from near 0 to near 3,
#'   and assuming that a higher score never lowers P(TP);
#' * `sd` (standard deviations of the random effects): `exponential(1)`;
#' * `cor` (correlations between random effects): `lkj(2)`, which pulls
#'   the correlations away from +-1 (the singular fits of m4 with 'lme4').
#'
#' This is an example, not a default: [fit_calibration()] with
#' `engine = "brms"` requires the prior to be given explicitly. Check what
#' it implies on the probability scale with
#' [prior_predictive_calibration()] before fitting, and its influence on
#' the posterior with [calibration_sensitivity()]. On weakly informative
#' priors and prior predictive checks see McElreath (2020,
#' \doi{10.1201/9780429029608}) and Gelman et al. (2026, *Bayesian
#' Workflow*, Chapman & Hall).
#'
#' @param formula Calibration formula (see [calibration_models()]).
#' @param validations Table returned by [read_validations()].
#'
#' @return A `brmsprior` object.
#' @export
calibration_prior <- function(formula, validations) {
  require_suggested("brms", "for Bayesian calibration models")
  classes <- unique(brms::get_prior(formula, data = validations,
                                    family = brms::bernoulli())$class)
  m <- round(mean(validations$logit_conf), 3)
  priors <- list(
    Intercept = brms::prior_string(paste0("normal(", m, ", 1.5)"),
                                   class = "Intercept"),
    b         = brms::prior_string("normal(1, 1)", class = "b", lb = 0),
    sd        = brms::prior_string("exponential(1)", class = "sd"),
    cor       = brms::prior_string("lkj(2)", class = "cor")
  )
  do.call(c, unname(priors[intersect(names(priors), classes)]))
}

#' Convergence diagnostics of a Bayesian calibration model
#'
#' Reports the largest R-hat, the smallest bulk and tail effective sample
#' sizes and the number of divergent transitions of a model fitted with
#' `engine = "brms"`, and whether they pass the usual limits.
#'
#' @param fit Model returned by [fit_calibration()] with `engine = "brms"`.
#' @param rhat_max Largest acceptable R-hat.
#' @param ess_min Smallest acceptable bulk and tail effective sample size.
#'
#' @return A one-row tibble with `max_rhat`, `min_ess_bulk`, `min_ess_tail`,
#'   `n_divergent` and `ok`.
#' @export
calibration_diagnostics <- function(fit, rhat_max = 1.01, ess_min = 400) {
  if (!inherits(fit, "brmsfit")) {
    stop("`fit` must be a model fitted with engine = \"brms\".")
  }
  require_suggested("posterior", "for the convergence diagnostics")
  resumo <- posterior::summarise_draws(posterior::as_draws_df(fit),
                                       "rhat", "ess_bulk", "ess_tail")
  np <- brms::nuts_params(fit)
  n_div <- sum(np$Value[np$Parameter == "divergent__"])
  out <- tibble(max_rhat = max(resumo$rhat, na.rm = TRUE),
                min_ess_bulk = min(resumo$ess_bulk, na.rm = TRUE),
                min_ess_tail = min(resumo$ess_tail, na.rm = TRUE),
                n_divergent = as.integer(n_div))
  mutate(out, ok = max_rhat <= rhat_max & min_ess_bulk >= ess_min &
           min_ess_tail >= ess_min & n_divergent == 0)
}

#' Prior predictive calibration curves
#'
#' Samples the calibration model from the prior only (no data enter the
#' likelihood), so that the curves it implies on the probability scale
#' can be checked before the model is fitted. Plot them with
#' [plot_calibration()].
#'
#' @inheritParams calibration_prior
#' @param prior Prior, e.g. from [calibration_prior()].
#' @param ... Further arguments for `brms::brm()` (e.g. `chains`, `iter`,
#'   `backend`, `seed`).
#'
#' @return A `brmsfit` sampled from the prior, usable in
#'   [plot_calibration()].
#' @export
prior_predictive_calibration <- function(formula, validations, prior, ...) {
  require_suggested("brms", "for Bayesian calibration models")
  fit <- brms::brm(formula, data = validations, family = brms::bernoulli(),
                   prior = prior, sample_prior = "only", ...)
  attr(fit, "sheepdog_levels") <- list(species = levels(validations$species),
                                       site    = levels(validations$site))
  fit
}

#' Prior and likelihood sensitivity of a Bayesian calibration model
#'
#' Power-scaling sensitivity analysis with 'priorsense' (Kallioinen et al.
#' 2024, \doi{10.1007/s11222-023-10366-5}): how much the posterior changes
#' when the prior or the likelihood is up- or down-weighted. A
#' prior-data conflict or a strongly informative prior shows up as
#' sensitivity to both.
#'
#' @param fit Model returned by [fit_calibration()] with `engine = "brms"`.
#' @param variable Parameters to analyse. `NULL` takes the population-level
#'   effects and the standard deviations and correlations of the random
#'   effects (`b_`, `sd_`, `cor_`), leaving out the individual random
#'   effects.
#' @param ... Further arguments for `priorsense::powerscale_sensitivity()`.
#'
#' @return The table of `priorsense::powerscale_sensitivity()`.
#' @export
calibration_sensitivity <- function(fit, variable = NULL, ...) {
  require_suggested("priorsense", "for the prior sensitivity analysis")
  if (!inherits(fit, "brmsfit")) {
    stop("`fit` must be a model fitted with engine = \"brms\".")
  }
  if (is.null(variable)) {
    todas <- posterior::variables(fit)
    variable <- grep("^(b|sd|cor)_", todas, value = TRUE)
  }
  priorsense::powerscale_sensitivity(fit, variable = variable, ...)
}

# Grade de scores (passo `step`) a partir de `min_confidence`
score_grid <- function(min_confidence, step) {
  seq(floor(min_confidence / step) * step, 1 - step / 2, by = step)
}

# Score arredondado para a grade
snap_to_grid <- function(confidence, min_confidence, step) {
  g <- score_grid(min_confidence, step)
  idx <- round((confidence - g[1]) / step) + 1
  pmin(pmax(idx, 1), length(g))
}

# Amostras da posterior de P(TP) num local, para todas as especies x
# pontos da grade: matriz amostras x (especie, ponto), com a tabela da grade.
# `keys`: niveis de outras variaveis de agrupamento (ex. list(month =
# "202406")), constantes na grade
grid_draws <- function(fit, site, species, min_confidence, step,
                       draw_ids = NULL, keys = list()) {
  niveis <- fit_levels(fit)
  grade <- expand_grid(species = species,
                       confidence = score_grid(min_confidence, step)) |>
    mutate(site = factor(site, levels = niveis$site),
           species = factor(species, levels = niveis$species),
           logit_conf = safe_logit(confidence))
  for (k in names(keys)) grade[[k]] <- keys[[k]]
  draws <- brms::posterior_epred(fit, newdata = grade, allow_new_levels = TRUE,
                                 draw_ids = draw_ids)
  list(grid = grade, draws = draws)
}

# Resumo das amostras por ponto da grade: media, quantil inferior e
# Pr(P(TP) >= p_min)
summarise_grid_draws <- function(draws, p_min, lower_prob) {
  tibble(p_tp = colMeans(draws),
         p_tp_lower = apply(draws, 2, stats::quantile, probs = lower_prob,
                            names = FALSE),
         pr_reliable = colMeans(draws >= p_min))
}

#' Nightly detection histories over posterior draws
#'
#' Propagates the uncertainty of a Bayesian calibration model to the
#' detection histories: for each of `n_draws` draws of the posterior, a
#' detection is reliable when its probability in that draw is >= `p_min`,
#' and the nightly history is rebuilt. The histories can then be turned
#' into community matrices with uncertainty by
#' [community_matrices_draws()].
#'
#' As in [score_detections()], the probabilities are computed on a grid of
#' scores (step `grid_step`) for each site x species and assigned to the
#' detections by their rounded score, which keeps the cost independent of
#' the number of detections.
#'
#' @param fit Model returned by [fit_calibration()] with `engine = "brms"`.
#' @param scored Table returned by [score_detections()].
#' @param n_draws Number of posterior draws.
#' @param seed Seed of the choice of draws. The global random number
#'   generator is left as it was.
#' @inheritParams detection_history
#' @inheritParams score_detections
#'
#' @return A tibble with `draw`, `site`, `species`, `night`,
#'   `n_detections`, `n_reliable`, `detection_k1` to `detection_k3` and
#'   `detection`.
#' @export
history_draws <- function(fit, scored, p_min = 0.95, n_draws = 200,
                          min_detections_night = 1, min_confidence = 0.1,
                          grid_step = 0.01, seed = 2026) {
  if (!inherits(fit, "brmsfit")) {
    stop("`fit` must be a model fitted with engine = \"brms\".")
  }
  n_total <- brms::ndraws(fit)
  ids <- withr::with_seed(seed, sort(sample.int(n_total, min(n_draws, n_total))))
  scored <- mutate(scored, species = as.character(species),
                   .g = snap_to_grid(confidence, min_confidence, grid_step))
  n_g <- length(score_grid(min_confidence, grid_step))

  map(split(scored, scored$site), function(sc) {
    especies <- sort(unique(sc$species))
    gd <- grid_draws(fit, sc$site[1], especies, min_confidence, grid_step,
                     draw_ids = ids)
    confiavel <- t(gd$draws >= p_min)        # pontos da grade x amostras
    contagem <- count(sc, species, night, .g)
    coluna <- (match(contagem$species, especies) - 1) * n_g + contagem$.g
    chave <- paste(contagem$species, contagem$night, sep = "\r")
    n_rel <- rowsum(confiavel[coluna, , drop = FALSE] * contagem$n,
                    group = chave, reorder = FALSE)
    n_det <- rowsum(contagem$n, group = chave, reorder = FALSE)[, 1]
    partes <- strsplit(rownames(n_rel), "\r", fixed = TRUE)
    tibble(site = sc$site[1],
           species = rep(map_chr(partes, 1), times = ncol(n_rel)),
           night = rep(map_chr(partes, 2), times = ncol(n_rel)),
           n_detections = rep(as.integer(n_det), times = ncol(n_rel)),
           draw = rep(ids, each = nrow(n_rel)),
           n_reliable = as.integer(n_rel))
  }) |>
    list_rbind() |>
    mutate(detection_k1 = as.integer(n_reliable >= 1),
           detection_k2 = as.integer(n_reliable >= 2),
           detection_k3 = as.integer(n_reliable >= 3),
           detection = as.integer(n_reliable >= min_detections_night)) |>
    relocate(draw) |>
    arrange(draw, site, species, night)
}

#' Community matrices over posterior draws
#'
#' Builds the community matrices of [community_matrices()] for each draw
#' of [history_draws()] and summarises the frequency of each site x month
#' x species cell by its posterior mean and an interval, so that the
#' uncertainty of the calibration reaches the matrices. The per-draw
#' frequencies are also returned, e.g. to repeat an ordination on each
#' draw.
#'
#' @param history Table returned by [history_draws()].
#' @param probs Probabilities of the interval.
#' @inheritParams community_matrices
#'
#' @return A list with `summary` (`site`, `month`, `species`,
#'   `n_nights_recorded`, `frequency_mean`, `frequency_lower`,
#'   `frequency_upper`) and `draws` (`draw`, `site`, `month`, `species`,
#'   `frequency`).
#' @export
community_matrices_draws <- function(history, core_species, k_min = 2,
                                     min_nights_month = 5,
                                     probs = c(0.05, 0.95)) {
  por_amostra <- history |>
    group_split(draw) |>
    map(function(h) {
      m <- suppressWarnings(community_matrices(
        select(h, -draw), core_species, k_min, min_nights_month))
      m$frequency |>
        pivot_longer(any_of(core_species), names_to = "species",
                     values_to = "frequency") |>
        mutate(draw = h$draw[1], .before = 1)
    }) |>
    list_rbind()
  resumo <- por_amostra |>
    group_by(site, month, species, n_nights_recorded) |>
    summarise(frequency_mean = mean(frequency),
              frequency_lower = stats::quantile(frequency, probs[1],
                                                names = FALSE),
              frequency_upper = stats::quantile(frequency, probs[2],
                                                names = FALSE),
              .groups = "drop")
  list(summary = resumo,
       draws = select(por_amostra, draw, site, month, species, frequency))
}

#' Calibration curves of posterior (or prior) draws
#'
#' Draws the population-level calibration curve, P(TP) against the score,
#' for `n_draws` draws of a Bayesian calibration model, without the
#' species and site effects. With a model from
#' [prior_predictive_calibration()] it shows what the prior implies on the
#' probability scale (a prior predictive check); with a fitted model, the
#' uncertainty of the curve. Needs the 'ggplot2' package.
#'
#' @param fit Model returned by [fit_calibration()] with `engine = "brms"`
#'   or by [prior_predictive_calibration()].
#' @param n_draws Number of curves.
#' @param p_min Threshold drawn as a dashed line.
#' @param seed Seed of the choice of draws. The global random number
#'   generator is left as it was.
#'
#' @return A ggplot object.
#' @export
plot_calibration_draws <- function(fit, n_draws = 100, p_min = 0.95,
                                   seed = 2026) {
  require_suggested("ggplot2", "to plot the calibration curves")
  if (!inherits(fit, "brmsfit")) {
    stop("`fit` must be a model fitted with engine = \"brms\".")
  }
  ids <- withr::with_seed(seed, sample.int(brms::ndraws(fit),
                                           min(n_draws, brms::ndraws(fit))))
  grade <- tibble(confidence = seq(0.01, 0.99, by = 0.01)) |>
    mutate(logit_conf = safe_logit(confidence))
  p <- brms::posterior_epred(fit, newdata = grade, re_formula = NA,
                             draw_ids = ids)
  curvas <- tibble(draw = rep(seq_along(ids), times = ncol(p)),
                   confidence = rep(grade$confidence, each = nrow(p)),
                   p_tp = as.vector(p))
  ggplot2::ggplot(curvas, ggplot2::aes(confidence, p_tp, group = draw)) +
    ggplot2::geom_abline(slope = 1, intercept = 0, colour = "grey60",
                         linetype = "dotted") +
    ggplot2::geom_hline(yintercept = p_min, linetype = "dashed",
                        colour = "grey50") +
    ggplot2::geom_line(alpha = 0.15, colour = "#2a7fbf") +
    ggplot2::coord_cartesian(xlim = c(0, 1), ylim = c(0, 1)) +
    ggplot2::labs(x = "BirdNET confidence",
                  y = "P(true detection), population level",
                  subtitle = paste0(length(ids), " draws; dotted line: ",
                                    "calibrated score; dashed line: p_min = ",
                                    p_min)) +
    ggplot2::theme_minimal(base_size = 11)
}
