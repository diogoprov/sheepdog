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
#' * other population-level terms, such as a continuous covariate of the
#'   occasion (`tp ~ logit_conf + temp`): `normal(0, 1)`, which suits a
#'   standardised covariate. 'brms' bounds a whole class, not a single
#'   coefficient, so with such terms the slope of `logit_conf` keeps
#'   `normal(1, 1)` without the truncation at 0. A warning is raised when
#'   such a numeric covariate is not standardised (absolute mean above
#'   0.25 or standard deviation outside 0.5 to 2);
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
#' @param formula A model formula, the calibration formula (see
#'   [calibration_models()]).
#' @param validations A data frame (or tibble) returned by [read_validations()],
#'   one row per reviewed clip.
#'
#' @return A `brmsprior` object.
#' @srrstats {BS1.2c} The prior is always explicit; this function
#'   documents an example and the examples show how to build, inspect and
#'   modify it.
#' @examples
#' if (requireNamespace("brms", quietly = TRUE)) {
#'   ex <- system.file("extdata", "example", package = "sheepdog")
#'   val <- read_validations(list.files(file.path(ex, "validation"),
#'                                      full.names = TRUE))
#'   f <- tp ~ logit_conf + (1 | species)
#'   prior <- calibration_prior(f, val)
#'   print(prior)
#'   # Any brmsprior can replace it, e.g. a narrower prior on the slope
#'   prior[prior$class == "b", "prior"] <- "normal(1, 0.5)"
#'   prior
#' }
#' @export
calibration_prior <- function(formula, validations) {
  require_suggested("brms", "for Bayesian calibration models")
  tab <- brms::get_prior(formula, data = validations,
                         family = brms::bernoulli())
  classes <- unique(tab$class)
  coefs_b <- setdiff(tab$coef[tab$class == "b"], "")
  m <- round(mean(validations$logit_conf), 3)
  others <- intersect(setdiff(coefs_b, "logit_conf"), names(validations))
  not_std <- others[map_lgl(others, function(v) {
    x <- validations[[v]]
    is.numeric(x) && (abs(mean(x, na.rm = TRUE)) > 0.25 ||
                        !dplyr::between(stats::sd(x, na.rm = TRUE), 0.5, 2))
  })]
  if (length(not_std) > 0) {
    warning("The normal(0, 1) prior on the other population-level terms ",
            "assumes standardised covariates, but ",
            paste(not_std, collapse = ", "), " are not (mean far from 0 ",
            "or standard deviation far from 1). Standardise them, e.g. ",
            "with scale(), or set their prior by hand.", call. = FALSE)
  }
  # with other population-level terms (e.g. a covariate), the bound at 0
  # cannot apply only to the score slope: brms bounds the whole class
  b <- if (all(coefs_b %in% "logit_conf")) {
    brms::prior_string("normal(1, 1)", class = "b", lb = 0)
  } else {
    c(brms::prior_string("normal(0, 1)", class = "b"),
      if ("logit_conf" %in% coefs_b) {
        brms::prior_string("normal(1, 1)", class = "b", coef = "logit_conf")
      })
  }
  priors <- list(
    Intercept = brms::prior_string(paste0("normal(", m, ", 1.5)"),
                                   class = "Intercept"),
    b         = b,
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
#' @param fit A `brmsfit` returned by [fit_calibration()] with
#'   `engine = "brms"`.
#' @param rhat_max Numeric scalar >= 1, largest acceptable R-hat.
#' @param ess_min Numeric scalar >= 0, smallest acceptable bulk and tail
#'   effective sample size.
#'
#' @details R-hat is the rank-normalised, folded split-R-hat and the effective
#' sample sizes are the bulk and tail ESS of Vehtari et al. (2021,
#' \doi{10.1214/20-BA1221}), computed by `posterior::summarise_draws()`
#' over all the parameters of the model. The defaults (R-hat <= 1.01,
#' bulk and tail ESS >= 400) are the limits recommended in that paper for
#' 4 chains. Divergent transitions are read from the NUTS parameters of
#' the fit (`brms::nuts_params()`), so only models sampled with NUTS can be
#' checked.
#'
#' The diagnostics are summaries; inspect the chains as well. `plot(fit)`
#' (a method of 'brms') draws the trace and the density of the
#' post-warmup draws of each population-level parameter. To see the
#' warmup next to the sampling phase, use `bayesplot::mcmc_trace()` with
#' its `n_warmup` argument on `brms::as_draws_array(fit, inc_warmup =
#' TRUE)`, which requires the warmup draws to have been saved by the Stan
#' backend.
#'
#' @srrstats {BS4.3} The R-hat and ESS of Vehtari et al. (2021) are
#'   documented with their reference.
#' @srrstats {BS6.2} Trace plots, with and without the warmup, are
#'   documented here.
#' @return A one-row tibble with `max_rhat`, `min_ess_bulk`, `min_ess_tail`,
#'   `n_divergent` and `ok`.
#' @examples
#' # Fitting a Bayesian calibration compiles a Stan model, which takes
#' # minutes, so this example is not run here.
#' \dontrun{
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read_validations(list.files(file.path(ex, "validation"),
#'                                    full.names = TRUE))
#' f <- tp ~ logit_conf + (1 | species)
#' fit <- fit_calibration(val, f, engine = "brms",
#'                        prior = calibration_prior(f, val),
#'                        chains = 4, iter = 2000, seed = 1, refresh = 0)
#' calibration_diagnostics(fit)
#' # Stricter limits
#' calibration_diagnostics(fit, rhat_max = 1.005, ess_min = 1000)
#' plot(fit)
#' }
#' @export
calibration_diagnostics <- function(fit, rhat_max = 1.01, ess_min = 400) {
  check_brmsfit(fit)
  check_number(rhat_max, "rhat_max", lower = 1)
  check_number(ess_min, "ess_min", lower = 0)
  require_suggested("posterior", "for the convergence diagnostics")
  smry <- posterior::summarise_draws(posterior::as_draws_df(fit),
                                     "rhat", "ess_bulk", "ess_tail")
  np <- brms::nuts_params(fit)
  n_div <- sum(np$Value[np$Parameter == "divergent__"])
  out <- tibble(max_rhat = max(smry$rhat, na.rm = TRUE),
                min_ess_bulk = min(smry$ess_bulk, na.rm = TRUE),
                min_ess_tail = min(smry$ess_tail, na.rm = TRUE),
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
#' @param prior A `brmsprior` object, the prior, e.g. from
#'   [calibration_prior()].
#' @param ... Further arguments for `brms::brm()` (e.g. `chains`, `iter`,
#'   `backend`, `seed`).
#'
#' @return A `brmsfit` sampled from the prior, usable in
#'   [plot_calibration()].
#' @examples
#' # Sampling from the prior compiles a Stan model, which takes minutes
#' \dontrun{
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read_validations(list.files(file.path(ex, "validation"),
#'                                    full.names = TRUE))
#' f <- tp ~ logit_conf + (1 | species)
#' prior_fit <- prior_predictive_calibration(f, val, calibration_prior(f, val),
#'                                           chains = 2, seed = 1,
#'                                           refresh = 0)
#' plot_calibration_draws(prior_fit)
#' }
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
#' @param fit A `brmsfit` returned by [fit_calibration()] with
#'   `engine = "brms"`.
#' @param variable `NULL` or a character vector of the names of the parameters
#'   to analyse. `NULL` takes the population-level effects and the standard
#'   deviations and correlations of the random effects (`b_`, `sd_`, `cor_`),
#'   leaving out the individual random effects.
#' @param ... Further arguments for `priorsense::powerscale_sensitivity()`.
#'
#' @return The table of `priorsense::powerscale_sensitivity()`.
#' @examples
#' # Fitting a Bayesian calibration compiles a Stan model, which takes
#' # minutes, so this example is not run here.
#' \dontrun{
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read_validations(list.files(file.path(ex, "validation"),
#'                                    full.names = TRUE))
#' f <- tp ~ logit_conf + (1 | species)
#' fit <- fit_calibration(val, f, engine = "brms",
#'                        prior = calibration_prior(f, val),
#'                        chains = 4, iter = 2000, seed = 1, refresh = 0)
#' calibration_sensitivity(fit)
#' # Only the slope on the logit of the score
#' calibration_sensitivity(fit, variable = "b_logit_conf")
#' }
#' @export
calibration_sensitivity <- function(fit, variable = NULL, ...) {
  check_brmsfit(fit)
  require_suggested("priorsense", "for the prior sensitivity analysis")
  if (is.null(variable)) {
    all_vars <- posterior::variables(fit)
    variable <- grep("^(b|sd|cor)_", all_vars, value = TRUE)
  }
  priorsense::powerscale_sensitivity(fit, variable = variable, ...)
}

#' Grid of scores from `min_confidence` in steps of `step`
#'
#' @param min_confidence Numeric scalar in \[0, 1\], the lowest score.
#' @param step Numeric scalar, the grid step.
#' @return Numeric vector of grid points below 1.
#' @noRd
score_grid <- function(min_confidence, step) {
  seq(floor(min_confidence / step) * step, 1 - step / 2, by = step)
}

#' Snap scores to the nearest point of the score grid
#'
#' @param confidence Numeric vector of scores in \[0, 1\].
#' @param min_confidence Numeric scalar in \[0, 1\], the lowest score.
#' @param step Numeric scalar, the grid step.
#' @return Integer-valued numeric vector of grid indices, same length as
#'   `confidence`, clamped to the grid.
#' @noRd
snap_to_grid <- function(confidence, min_confidence, step) {
  g <- score_grid(min_confidence, step)
  idx <- round((confidence - g[1]) / step) + 1
  pmin(pmax(idx, 1), length(g))
}

#' Posterior draws of P(TP) on the score grid of one site
#'
#' Computes the draws for every species x grid point of one site.
#'
#' @param fit A `brmsfit` calibration model.
#' @param site Character scalar, the site.
#' @param species Character vector of species.
#' @param min_confidence Numeric scalar in \[0, 1\], the lowest score.
#' @param step Numeric scalar, the grid step.
#' @param draw_ids Integer vector or `NULL`, the posterior draws to use.
#' @param keys Named list of levels of other grouping variables (e.g.
#'   `list(month = "202406")`), constant over the grid.
#' @return A list with `grid` (a tibble, one row per species x grid point)
#'   and `draws` (a matrix, draws x grid rows).
#' @noRd
grid_draws <- function(fit, site, species, min_confidence, step,
                       draw_ids = NULL, keys = list()) {
  lvls <- fit_levels(fit)
  grid <- expand_grid(species = species,
                      confidence = score_grid(min_confidence, step)) |>
    mutate(site = factor(site, levels = lvls$site),
           species = factor(species, levels = lvls$species),
           logit_conf = safe_logit(confidence))
  for (k in names(keys)) grid[[k]] <- keys[[k]]
  draws <- brms::posterior_epred(fit, newdata = grid, allow_new_levels = TRUE,
                                 draw_ids = draw_ids)
  list(grid = grid, draws = draws)
}

#' Summarise grid draws by grid point
#'
#' @param draws Numeric matrix of P(TP), draws x grid points.
#' @param p_min Numeric scalar in \[0, 1\], reliability threshold.
#' @param lower_prob Numeric scalar in \[0, 1\], probability of the lower
#'   quantile.
#' @return A tibble with `p_tp` (mean), `p_tp_lower` (lower quantile) and
#'   `pr_reliable` (Pr(P(TP) >= p_min)), one row per grid point.
#' @noRd
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
#' @param fit A `brmsfit` returned by [fit_calibration()] with
#'   `engine = "brms"`.
#' @param scored A data frame (or tibble) returned by [score_detections()], one
#'   row per detection.
#' @param n_draws Integer scalar >= 1, number of posterior draws (at most the
#'   number of draws in `fit`).
#' @param seed Integer scalar, seed of the choice of draws. The global random
#'   number generator is left as it was.
#' @inheritParams detection_history
#' @inheritParams score_detections
#'
#' @return A tibble with `draw`, `site`, `species`, `night`,
#'   `n_detections`, `n_reliable`, `detection_k1` to `detection_k3` and
#'   `detection`.
#' @examples
#' # Fitting a Bayesian calibration compiles a Stan model, which takes
#' # minutes, so this example is not run here.
#' \dontrun{
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read_validations(list.files(file.path(ex, "validation"),
#'                                    full.names = TRUE))
#' f <- tp ~ logit_conf + (1 | species)
#' fit <- fit_calibration(val, f, engine = "brms",
#'                        prior = calibration_prior(f, val),
#'                        chains = 4, iter = 2000, seed = 1, refresh = 0)
#' sites <- c("ARA", "BAI", "NHE", "XAR")
#' tables <- setNames(file.path(ex, "birdnet", sites,
#'                              "BirdNET_SelectionTable.txt"), sites)
#' scored <- score_detections(tables, fit, p_min = 0.95)
#' hd <- history_draws(fit, scored, p_min = 0.95, n_draws = 200)
#' community_matrices_draws(hd, core_species = c("boa_ran", "phy_cuv"))
#' }
#' @export
history_draws <- function(fit, scored, p_min = 0.95, n_draws = 200,
                          min_detections_night = 1, min_confidence = 0.1,
                          grid_step = 0.01, seed = 2026) {
  check_brmsfit(fit)
  check_prob(p_min, "p_min")
  check_number(n_draws, "n_draws", lower = 1, integer = TRUE)
  check_number(min_detections_night, "min_detections_night", lower = 1,
               integer = TRUE)
  check_prob(min_confidence, "min_confidence")
  check_number(grid_step, "grid_step", 0, 0.5, open = TRUE)
  check_number(seed, "seed", integer = TRUE)
  n_total <- brms::ndraws(fit)
  ids <- withr::with_seed(seed, sort(sample.int(n_total, min(n_draws, n_total))))
  scored <- mutate(scored, species = as.character(species),
                   .g = snap_to_grid(confidence, min_confidence, grid_step))
  n_g <- length(score_grid(min_confidence, grid_step))

  map(split(scored, scored$site), function(sc) {
    spp <- sort(unique(sc$species))
    gd <- grid_draws(fit, sc$site[1], spp, min_confidence, grid_step,
                     draw_ids = ids)
    reliable <- t(gd$draws >= p_min)        # grid points x draws
    counts <- count(sc, species, night, .g)
    col_idx <- (match(counts$species, spp) - 1) * n_g + counts$.g
    key <- paste(counts$species, counts$night, sep = "\r")
    n_rel <- rowsum(reliable[col_idx, , drop = FALSE] * counts$n,
                    group = key, reorder = FALSE)
    n_det <- rowsum(counts$n, group = key, reorder = FALSE)[, 1]
    parts <- strsplit(rownames(n_rel), "\r", fixed = TRUE)
    tibble(site = sc$site[1],
           species = rep(map_chr(parts, 1), times = ncol(n_rel)),
           night = rep(map_chr(parts, 2), times = ncol(n_rel)),
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
#' @param history A data frame (or tibble) returned by [history_draws()].
#' @param probs Numeric vector of length 2 in \[0, 1\], probabilities of the
#'   lower and upper limits of the interval.
#' @inheritParams community_matrices
#'
#' @return A list with `summary` (`site`, `month`, `species`,
#'   `n_nights_recorded`, `frequency_mean`, `frequency_lower`,
#'   `frequency_upper`) and `draws` (`draw`, `site`, `month`, `species`,
#'   `frequency`).
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' history <- read.csv(file.path(ex, "nightly_detection_history.csv"),
#'                     colClasses = c(night = "character"))
#' # history_draws() needs a Bayesian calibration (see its example). As a
#' # stand-in, three "draws" in which each reliable detection of the
#' # example history is kept with probability 0.8
#' set.seed(1)
#' draws <- do.call(rbind, lapply(1:3, function(d) {
#'   h <- history
#'   h$n_reliable <- rbinom(nrow(h), h$n_reliable, 0.8)
#'   h$detection_k1 <- as.integer(h$n_reliable >= 1)
#'   h$detection_k2 <- as.integer(h$n_reliable >= 2)
#'   h$detection_k3 <- as.integer(h$n_reliable >= 3)
#'   cbind(draw = d, h)
#' }))
#' mats <- community_matrices_draws(draws,
#'                                  core_species = c("boa_ran", "phy_cuv"),
#'                                  k_min = 2)
#' mats$summary
#' @export
community_matrices_draws <- function(history, core_species, k_min = 2,
                                     min_nights_month = 5,
                                     probs = c(0.05, 0.95)) {
  by_draw <- history |>
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
  smry <- by_draw |>
    group_by(site, month, species, n_nights_recorded) |>
    summarise(frequency_mean = mean(frequency),
              frequency_lower = stats::quantile(frequency, probs[1],
                                                names = FALSE),
              frequency_upper = stats::quantile(frequency, probs[2],
                                                names = FALSE),
              .groups = "drop")
  list(summary = smry,
       draws = select(by_draw, draw, site, month, species, frequency))
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
#' @param fit A `brmsfit` returned by [fit_calibration()] with `engine = "brms"`
#'   or by [prior_predictive_calibration()].
#' @param n_draws Integer scalar >= 1, number of curves (at most the number of
#'   draws in `fit`).
#' @param p_min Numeric scalar in \[0, 1\], threshold drawn as a dashed line.
#' @param seed Integer scalar, seed of the choice of draws. The global random
#'   number generator is left as it was.
#'
#' @return A ggplot object.
#' @examples
#' # Sampling from the prior or the posterior compiles a Stan model, which
#' # takes minutes, so this example is not run here.
#' \dontrun{
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read_validations(list.files(file.path(ex, "validation"),
#'                                    full.names = TRUE))
#' f <- tp ~ logit_conf + (1 | species)
#' prior <- calibration_prior(f, val)
#' # Prior predictive check
#' prior_fit <- prior_predictive_calibration(f, val, prior, chains = 2,
#'                                           seed = 1, refresh = 0)
#' plot_calibration_draws(prior_fit, n_draws = 100)
#' # Uncertainty of the fitted curve
#' fit <- fit_calibration(val, f, engine = "brms", prior = prior,
#'                        chains = 4, iter = 2000, seed = 1, refresh = 0)
#' plot_calibration_draws(fit, n_draws = 100, p_min = 0.95)
#' }
#' @export
plot_calibration_draws <- function(fit, n_draws = 100, p_min = 0.95,
                                   seed = 2026) {
  require_suggested("ggplot2", "to plot the calibration curves")
  check_brmsfit(fit)
  check_number(n_draws, "n_draws", lower = 1, integer = TRUE)
  check_prob(p_min, "p_min")
  check_number(seed, "seed", integer = TRUE)
  ids <- withr::with_seed(seed, sample.int(brms::ndraws(fit),
                                           min(n_draws, brms::ndraws(fit))))
  grid <- tibble(confidence = seq(0.01, 0.99, by = 0.01)) |>
    mutate(logit_conf = safe_logit(confidence))
  p <- brms::posterior_epred(fit, newdata = grid, re_formula = NA,
                             draw_ids = ids)
  curves <- tibble(draw = rep(seq_along(ids), times = ncol(p)),
                   confidence = rep(grid$confidence, each = nrow(p)),
                   p_tp = as.vector(p))
  ggplot2::ggplot(curves, ggplot2::aes(confidence, p_tp, group = draw)) +
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
