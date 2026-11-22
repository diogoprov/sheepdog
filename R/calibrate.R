#' Read the validation tables for calibration
#'
#' Stacks the `validation_by_clip.csv` tables of several sites (output of
#' [post_validation()]) and keeps the clips with a positive or negative
#' verdict and a confidence score. Tables written by v1.2.0
#' (`validacao_por_clipe.csv`) are also read. Whole-recording clips of
#' `"random_recordings"` have no confidence and are left out.
#'
#' @param files Character vector, paths to the `validation_by_clip.csv` files.
#'   Missing files are skipped with a warning.
#' @param site_map `NULL` or a named character vector to fix diverging site
#'   names, as `c(old = "new")`, e.g. `c(BEP2 = "BEP")`.
#'
#' @param keep `NULL` or a character vector of input columns to retain, e.g.
#'   `c("source_audio", "night")` for grouped cross-validation. Missing columns
#'   raise an error rather than silently falling back to clip folds.
#'
#' @return A tibble with `site` and `species` (factors; `species` is the
#'   species folder code), `confidence`, `logit_conf` (logit of the
#'   confidence, bounded at 1e-4 and 1 - 1e-4) and `tp` (1 = true
#'   positive, 0 = false positive), plus the columns requested in `keep`.
#'
#' @section Transformations:
#' The confidence is bounded at 1e-4 and 1 - 1e-4 before the logit
#' (`stats::qlogis()`), so that scores of 0 or 1 give finite values;
#' `stats::plogis(logit_conf)` returns the bounded confidence. The verdict
#' becomes the binary response `tp`, and `site` and `species` become
#' factors whose levels (in alphabetical order) are stored by
#' [fit_calibration()] with the model. These transformations are always
#' applied, because the calibration models and [score_detections()]
#' expect them; the original `confidence` is kept alongside `logit_conf`.
#'
#' @srrstats {RE2.0} The section "Transformations" documents the bounded
#'   logit and the factor conversions and why they are always applied.
#' @srrstats {RE4.12} The bounded logit and its inverse are documented in
#'   the section "Transformations".
#' @export
read_validations <- function(files, site_map = NULL, keep = NULL) {
  if (!is.null(keep) && (!is.character(keep) || anyNA(keep) ||
                          any(!nzchar(keep)))) {
    stop("`keep` must be a character vector of column names.", call. = FALSE)
  }
  val <- map(files, function(f) {
    if (!file.exists(f)) { warning("Not found: ", f); return(NULL) }
    tab <- read_csv(f, show_col_types = FALSE, progress = FALSE) |>
      from_legacy()
    missing_cols <- setdiff(keep, names(tab))
    if (length(missing_cols)) {
      stop("Missing columns requested in `keep` in ", f, ": ",
           paste(missing_cols, collapse = ", "), call. = FALSE)
    }
    tab
  }) |>
    list_rbind()
  if (is.null(val) || nrow(val) == 0) {
    stop("No reviewed clip found in `files`.", call. = FALSE)
  }
  check_confidence(val$confidence)
  reviewed <- val$verdict %in% c("positive", "negative")
  no_score <- sum(reviewed & is.na(val$confidence))
  if (no_score > 0) {
    message(no_score, " reviewed clip(s) without a confidence score ",
            "(whole recordings of \"random_recordings\") were left out.")
  }
  n_bounded <- sum(reviewed & !is.na(val$confidence) &
                     (val$confidence < 1e-4 | val$confidence > 1 - 1e-4))
  if (n_bounded > 0) {
    message(n_bounded, " confidence score(s) below 1e-4 or above 1 - 1e-4 ",
            "were bounded before the logit.")
  }
  val <- val |>
    # drawn recordings ("random_recordings" mode) have no confidence
    filter(verdict %in% c("positive", "negative"), !is.na(confidence)) |>
    transmute(
      site       = rename_site(site, site_map),
      species    = species_folder,
      confidence = confidence,
      logit_conf = safe_logit(confidence),
      tp         = as.integer(verdict == "positive"),
      across(all_of(setdiff(keep, c("site", "species", "confidence",
                                    "logit_conf", "tp"))))
    ) |>
    mutate(across(c(site, species), as.factor))

  if (nrow(val) == 0) {
    stop("No clip of `files` has a verdict (positive or negative) and a ",
         "confidence score.", call. = FALSE)
  }
  message(nrow(val), " reviewed clips (", sum(val$tp), " TP / ",
          sum(val$tp == 0), " FP) of ", n_distinct(val$species),
          " species at ", n_distinct(val$site), " sites.")
  val
}

#' Logit bounded away from 0 and 1
#'
#' @param p Numeric vector in \[0, 1\], confidence scores.
#' @return Numeric vector, `stats::qlogis()` of `p` bounded at 1e-4 and
#'   1 - 1e-4.
#' @noRd
safe_logit <- function(p) stats::qlogis(pmin(pmax(p, 1e-4), 1 - 1e-4))

#' Rename sites with a lookup vector
#'
#' @param x Character vector of site names.
#' @param site_map Named character vector `c(old = "new")`, or `NULL`.
#' @return Character vector, `x` with the names in `site_map` replaced.
#' @noRd
rename_site <- function(x, site_map) {
  if (is.null(site_map)) return(x)
  ifelse(x %in% names(site_map), unname(site_map[x]), x)
}

#' Candidate calibration models
#'
#' The family of logistic calibration models compared by
#' [compare_calibration_models()], from a single logistic regression on
#' the logit of the confidence score to a binomial GLMM with random slopes
#' by species and a site x species intercept.
#'
#' The list goes from the simplest to the most complex model; that order is
#' the complexity used by [select_calibration_model()].
#'
#' @param uncorrelated Logical scalar. If `TRUE`, add
#'   `m5_species_x_site_uncorrelated`, the m4 structure without the correlation
#'   between the species intercepts and slopes. It avoids the singular fits of
#'   m4 when that correlation is estimated at +-1. `FALSE` keeps the candidates
#'   of 2.0.0.
#'
#' @param single_species Logical scalar. If `TRUE`, use a family for one
#'   species: global logistic regression, a site intercept, and a site intercept
#'   and slope. With `uncorrelated = TRUE`, also include independent site
#'   intercepts and slopes. `FALSE` preserves the multispecies family.
#'
#' @return A named list of formulas: `m0_global`, `m1_species_intercept`,
#'   `m2_species_slope`, `m3_plus_site`, `m4_species_x_site` and, with
#'   `uncorrelated = TRUE`, `m5_species_x_site_uncorrelated`. With
#'   `single_species = TRUE`: `m0_global`, `m1_site_intercept`,
#'   `m2_site_slope` and optionally `m3_site_slope_uncorrelated`.
#' @export
calibration_models <- function(uncorrelated = FALSE, single_species = FALSE) {
  if (single_species) {
    models <- list(
      m0_global = tp ~ logit_conf,
      m1_site_intercept = tp ~ logit_conf + (1 | site),
      m2_site_slope = tp ~ logit_conf + (logit_conf | site))
    if (uncorrelated) {
      models$m3_site_slope_uncorrelated <-
        tp ~ logit_conf + (1 | site) + (0 + logit_conf | site)
    }
    return(models)
  }
  multi <- list(
    m0_global            = tp ~ logit_conf,
    m1_species_intercept = tp ~ logit_conf + (1 | species),
    m2_species_slope     = tp ~ logit_conf + (logit_conf | species),
    m3_plus_site         = tp ~ logit_conf + (logit_conf | species) +
                                (1 | site),
    m4_species_x_site    = tp ~ logit_conf + (logit_conf | species) +
                                (1 | site:species)
  )
  if (uncorrelated) {
    multi$m5_species_x_site_uncorrelated <-
      tp ~ logit_conf + (1 | species) + (0 + logit_conf | species) +
      (1 | site:species)
  }
  multi
}

#' Candidate calibration models for the observed species and sites
#'
#' The candidate family follows observed levels, not unused factor levels.
#' Explicit model lists in compare_calibration_models() bypass this helper.
#'
#' @param validations A data frame with columns `site` and `species`.
#' @param uncorrelated Logical scalar, passed to calibration_models().
#' @return A named list of formulas: the single-species family with one
#'   species, and without site random effects with one site.
#' @noRd
calibration_candidates <- function(validations, uncorrelated = FALSE) {
  n_species <- n_distinct(validations$species)
  n_sites <- n_distinct(validations$site)
  models <- calibration_models(uncorrelated, single_species = n_species == 1L)
  if (n_sites == 1L) {
    models <- if (n_species == 1L) models[1] else models[seq_len(3)]
  }
  models
}

#' Assign cross-validation folds for calibration
#'
#' With `fold_group = NULL`, assigns clips within each site x species,
#' reproducing the original fold assignment. For grouped folds, give one
#' or more column names, e.g. `"source_audio"` for recordings or `"night"`
#' for nights. Site is always part of the grouping key. All species and
#' clips sharing that key go into the same fold; groups are shuffled and
#' distributed among folds within site, balancing group counts rather
#' than clip counts. Each site must have at least `k_folds` groups.
#'
#' Grouped folds evaluate new recordings or nights at known sites, not
#' transfer to new sites. Unlike clip folds, they cannot guarantee that
#' each species appears in each training and test set. A test fold with
#' only one verdict has no AUC but still contributes probability scores.
#'
#' @param validations A data frame (or tibble), the calibration data, one row
#'   per reviewed clip, with `site`, `species` and any columns named in
#'   `fold_group`. Use `read_validations(keep = )` to retain metadata from
#'   validation files.
#' @param k_folds Integer scalar >= 2, number of folds.
#' @param seed Integer scalar, seed of the assignment; the caller's random state
#'   is restored.
#' @param fold_group `NULL` or a character vector of grouping columns. Do not
#'   include `species`, verdicts or confidence scores: these would split
#'   recordings or nights by species or by outcome. Group IDs must be nonmissing
#'   and nonempty. `NULL` keeps the original clip folds.
#'
#' @return Integer vector of fold numbers, in the input row order.
#' @export
calibration_folds <- function(validations, k_folds = 5, seed = 2026,
                               fold_group = NULL) {
  if (!is.numeric(k_folds) || length(k_folds) != 1L ||
      !is.finite(k_folds) || k_folds < 2 || k_folds != floor(k_folds)) {
    stop("`k_folds` must be an integer of at least two.", call. = FALSE)
  }
  if (!all(c("site", "species") %in% names(validations)) ||
      nrow(validations) == 0L || anyNA(validations[c("site", "species")])) {
    stop("`validations` needs nonmissing site and species, and at least one row.",
         call. = FALSE)
  }
  if (is.null(fold_group)) {
    return(withr::with_seed(seed, {
      validations |>
        group_by(site, species) |>
        mutate(fold = sample(rep_len(seq_len(k_folds), n()))) |>
        ungroup() |>
        pull(fold)
    }))
  }
  if (!is.character(fold_group) || length(fold_group) == 0L ||
      anyNA(fold_group) || any(!nzchar(fold_group))) {
    stop("`fold_group` must be NULL or a character vector of column names.",
         call. = FALSE)
  }
  if (any(fold_group %in% c("species", "tp", "verdict", "confidence",
                            "logit_conf"))) {
    stop("`fold_group` must identify recordings or nights, not species, ",
         "verdicts or confidence scores.", call. = FALSE)
  }
  cols <- unique(c("site", fold_group))
  if (!all(cols %in% names(validations))) {
    stop("Missing `fold_group` columns: ",
         paste(setdiff(cols, names(validations)), collapse = ", "), call. = FALSE)
  }
  if (any(vapply(validations[cols], function(x) {
    anyNA(x) || any(!nzchar(trimws(as.character(x))))
  }, logical(1)))) {
    stop("`fold_group` columns and site must have no missing or empty IDs.",
         call. = FALSE)
  }
  # Separate integer keys avoid overwriting metadata supplied by the user.
  grouped <- group_by(validations, across(all_of(cols)))
  ids <- group_indices(grouped)
  keys <- tibble(site = validations$site, .fold_id = ids) |>
    distinct() |>
    arrange(.fold_id)
  sizes <- count(keys, site)
  if (any(sizes$n < k_folds)) {
    stop("Grouped folds need at least ", k_folds, " distinct groups per site; ",
         "too few at: ", paste(sizes$site[sizes$n < k_folds], collapse = ", "),
         ". Reduce `k_folds` or choose finer groups.", call. = FALSE)
  }
  keys <- withr::with_seed(seed, {
    keys |>
      group_by(site) |>
      mutate(fold = sample(rep_len(seq_len(k_folds), n()))) |>
      ungroup()
  })
  keys$fold[match(ids, keys$.fold_id)]
}

#' Compare calibration models by cross-validation
#'
#' Fits each candidate model with k-fold cross-validation and scores the
#' predicted probabilities on the held-out folds. Folds are stratified
#' within site x species by default. With `fold_group`, recordings or
#' nights are kept intact across species; see [calibration_folds()].
#' Models with random effects need the 'lme4' package.
#'
#' The AUC measures discrimination (whether true detections get higher
#' probabilities than false ones). The log-loss and the Brier score are
#' proper scoring rules: they reward probabilities close to the observed
#' outcomes, which is what matters when the probabilities are compared
#' with `p_min` (Gneiting & Raftery 2007, \doi{10.1198/016214506000001437}).
#' The calibration intercept and slope come from a logistic regression of
#' the verdicts on the logit of the predicted probabilities in each test
#' fold: a well calibrated model has intercept 0 and slope 1; a slope below
#' 1 means probabilities too extreme (overfitting).
#'
#' @param validations A data frame (or tibble) returned by [read_validations()],
#'   one row per reviewed clip.
#' @param models `NULL` or a named list of model formulas. `NULL` chooses the
#'   family from the observed species and sites: site-effect models for one
#'   species, the original family for multiple species, and no site random
#'   effects when only one site is observed. Supply an explicit list to
#'   reproduce a particular candidate set.
#' @param k_folds Integer scalar >= 2, number of folds.
#' @inheritParams calibration_folds
#' @param seed Integer scalar, seed of the fold assignment. The global random
#'   number generator is left as it was.
#'
#' @return A tibble with `model`, `formula`, `auc_mean`, `auc_sd`,
#'   `n_failed` (folds whose fit failed, left out of the means),
#'   `logloss_mean`, `logloss_sd`, `brier_mean`, `brier_sd`,
#'   `cal_intercept` and `cal_slope` (means over the folds), `prop_singular`
#'   (share of the fold fits that were singular) and `complexity` (position
#'   of the model in `models`), ordered from the highest mean AUC. Failed
#'   folds also raise a warning. A test fold with only one verdict has
#'   missing AUC but contributes log-loss and Brier; it is not a failed fit.
#' @export
compare_calibration_models <- function(validations,
                                       models = NULL,
                                       k_folds = 5, seed = 2026,
                                       fold_group = NULL) {
  if (!is.null(models) &&
      (!is.list(models) || length(models) == 0L || is.null(names(models)) ||
       any(!nzchar(names(models))) ||
       !all(map_lgl(models, inherits, "formula")))) {
    stop("`models` must be a named list of formulas, e.g. from ",
         "calibration_models().", call. = FALSE)
  }
  vars <- unique(c("site", "species", "logit_conf", "tp",
                   unlist(map(models, all.vars))))
  validations <- check_validations(validations, cols = vars) |>
    drop_missing(vars)
  if (is.null(models)) models <- calibration_candidates(validations)
  need_lme4(models)
  val <- validations
  val$fold <- calibration_folds(validations, k_folds, seed, fold_group)

  message("Cross-validation (", k_folds, " folds) of ", length(models),
          " models...")
  empty <- c(auc = NA_real_, logloss = NA_real_, brier = NA_real_,
             cal_intercept = NA_real_, cal_slope = NA_real_,
             singular = NA_real_, failed = 1)
  map(seq_along(models), function(i) {
    nm <- names(models)[i]
    m <- map(seq_len(k_folds), function(k) {
      train <- filter(val, fold != k)
      test  <- filter(val, fold == k)
      fit    <- tryCatch(fit_model(models[[nm]], train),
                         error = function(e) NULL)
      if (is.null(fit)) return(empty)
      p <- predict_tp(fit, test)
      fold_auc <- if (n_distinct(test$tp) == 2L) auc(test$tp, p) else NA_real_
      c(auc = fold_auc, score_probabilities(test$tp, p),
        singular = as.numeric(inherits(fit, "merMod") &&
                                 lme4::isSingular(fit)), failed = 0)
    }) |>
      do.call(what = rbind)
    n_failed_k <- sum(m[, "failed"] > 0)
    if (n_failed_k > 0) {
      warning(nm, ": the fit failed in ", n_failed_k, " of ", k_folds,
              " folds, left out of the mean AUC.", call. = FALSE)
    }
    mean_na <- function(x) mean(x, na.rm = TRUE)
    sd_na   <- function(x) stats::sd(x, na.rm = TRUE)
    tibble(model = nm, formula = deparse1(models[[nm]]),
           auc_mean = mean_na(m[, "auc"]), auc_sd = sd_na(m[, "auc"]),
           n_failed = n_failed_k,
           logloss_mean = mean_na(m[, "logloss"]),
           logloss_sd = sd_na(m[, "logloss"]),
           brier_mean = mean_na(m[, "brier"]), brier_sd = sd_na(m[, "brier"]),
           cal_intercept = mean_na(m[, "cal_intercept"]),
           cal_slope = mean_na(m[, "cal_slope"]),
           prop_singular = mean_na(m[, "singular"]),
           complexity = i)
  }) |>
    list_rbind() |>
    arrange(desc(auc_mean))
}

#' Score predicted probabilities against binary verdicts
#'
#' @param tp Integer vector of 0/1 verdicts.
#' @param p Numeric vector of predicted probabilities, same length as `tp`.
#' @return A named numeric vector: `logloss`, `brier`, `cal_intercept` and
#'   `cal_slope` (the last two `NA` when their logistic fit fails or warns).
#' @noRd
score_probabilities <- function(tp, p) {
  p  <- pmin(pmax(p, 1e-6), 1 - 1e-6)
  lp <- stats::qlogis(p)
  slope <- tryCatch(
    unname(stats::coef(stats::glm(tp ~ lp, family = stats::binomial))[2]),
    error = function(e) NA_real_, warning = function(w) NA_real_)
  intercept <- tryCatch(
    unname(stats::coef(stats::glm(tp ~ 1 + offset(lp),
                                  family = stats::binomial))[1]),
    error = function(e) NA_real_, warning = function(w) NA_real_)
  c(logloss = -mean(tp * log(p) + (1 - tp) * log(1 - p)),
    brier = mean((p - tp)^2),
    cal_intercept = intercept, cal_slope = slope)
}

#' Select the calibration model
#'
#' Picks a model from the table of [compare_calibration_models()].
#'
#' * `"best_auc"`: the model with the highest mean AUC (the rule of
#'   [calibrate()] in 2.x).
#' * `"one_se_logloss"`: among the models whose mean log-loss is within one
#'   standard error (`logloss_sd / sqrt(k_folds)`) of the lowest, the
#'   simplest (lowest `complexity`); models singular in most folds are left
#'   out, unless all are, which raises a warning. The log-loss rewards
#'   correct probabilities, not only their ranking, and the one-standard-
#'   error rule prefers the simpler model when the data cannot tell the
#'   candidates apart. This is the default of [calibrate()] since 3.0.0.
#'
#' @param comparison A data frame (or tibble) returned by
#'   [compare_calibration_models()].
#' @param rule Character scalar, the selection rule: `"one_se_logloss"`
#'   (default) or `"best_auc"`.
#' @param k_folds Numeric scalar, number of folds of the comparison (for the
#'   standard error).
#'
#' @return The name of the selected model.
#' @export
select_calibration_model <- function(comparison,
                                     rule = c("one_se_logloss", "best_auc"),
                                     k_folds = 5) {
  rule <- match.arg(rule)
  if (rule == "best_auc") {
    if (!any(is.finite(comparison$auc_mean))) {
      stop("No finite AUC available for model selection.", call. = FALSE)
    }
    return(comparison$model[which.max(comparison$auc_mean)])
  }
  cand <- filter(comparison, is.finite(logloss_mean))
  if (nrow(cand) == 0L) {
    stop("No finite log-loss available for model selection.", call. = FALSE)
  }
  regular <- filter(cand, prop_singular <= 0.5)
  if (nrow(regular) == 0) {
    warning("Every candidate model is singular in most folds; selecting ",
            "among all of them.", call. = FALSE)
  } else {
    cand <- regular
  }
  best <- cand[which.min(cand$logloss_mean), ]
  limit <- best$logloss_mean + best$logloss_sd / sqrt(k_folds)
  cand |>
    filter(logloss_mean <= limit) |>
    arrange(complexity) |>
    pull(model) |>
    first()
}

#' Fit the calibration model
#'
#' Fits a calibration model to all the reviewed clips. The species and
#' site levels of `validations` are stored with the model, so that
#' [score_detections()] can score new detections.
#'
#' With `engine = "lme4"` (default), the model is fitted by maximum
#' likelihood ('lme4' for random effects, `glm()` otherwise). A model with
#' random effects whose fit is singular (a variance estimated at zero or a
#' correlation at +-1) raises a warning: the fixed effects and the
#' predictions can still be used, but the variance components on the
#' boundary should not be interpreted, and a simpler model may predict as
#' well. Check them with `lme4::VarCorr()`. The other messages of
#' `lme4::glmer()` are passed on, prefixed by `lme4:`, and every message of
#' the fit is kept in the attribute `sheepdog_messages` of the model
#' (convergence warnings of 'lme4' are warnings and are passed on as such).
#'
#' With `engine = "brms"`, the model is fitted in a Bayesian framework
#' with 'brms' (Bernoulli family, logit link). The prior must be given
#' explicitly; [calibration_prior()] builds an example centred on an
#' already calibrated score. After the fit, [calibration_diagnostics()]
#' runs and a warning is raised when R-hat, the effective sample sizes or
#' the divergent transitions fail the usual limits. Check the prior with
#' [prior_predictive_calibration()], the fit with `brms::pp_check()` and
#' the sensitivity to the prior with [calibration_sensitivity()].
#'
#' @section Formula and model matrix:
#' The formula uses the syntax of 'lme4' for random effects (`(term |
#' group)`) and is turned into model matrices by the fitting function
#' itself: `stats::glm()` for a formula without random effects,
#' `lme4::glmer()` otherwise, or `brms::brm()`. sheepdog does not build
#' the matrices. The response is `tp` (1 = true positive, 0 = false
#' positive) and the predictor of the score is `logit_conf`, the logit of
#' the BirdNET confidence bounded at 1e-4 and 1 - 1e-4 (see
#' [read_validations()]); the inverse transform, from the linear
#' predictor to P(TP), is `stats::plogis()`. Only the columns named in the
#' formula enter the model: the other columns of `validations` (for
#' example those kept with `keep` in [read_validations()]) are neither
#' used nor stored in the fitted object. The species and site levels are
#' stored in the attribute `sheepdog_levels`.
#'
#' @section Input checks and missing values:
#' `validations` must be a data frame (a tibble, `data.frame` or
#' `data.table`; it is converted to a tibble) with the columns `site` and
#' `species` (factors or character vectors; ordered factors are used as
#' unordered), `tp` (0/1, or logical) and every variable of `formula`,
#' usually `logit_conf` (numeric, without NaN or infinite values; extra
#' classes such as 'units' are dropped). The response of `formula` must be
#' `tp`. Rows with a missing value in a variable of the formula are left
#' out with a message; this policy is fixed, the same in both engines,
#' and no missing value reaches the fitting function. Before the fit, an
#' error is raised when all the clips have the same verdict or when the
#' fixed effects are collinear (rank-deficient model matrix), a warning
#' when the verdicts are completely separated by the score (the maximum
#' likelihood slope is then infinite), and a message lists species with a
#' single verdict class or separated verdicts. With `engine = "brms"`,
#' `prior` must be a `brmsprior` object.
#'
#' @section Maximum likelihood fit:
#' Models with random effects are fitted by `lme4::glmer()` with
#' `lme4::glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun =
#' 1e5))`: the bound optimisation by quadratic approximation, with up to
#' 100000 function evaluations, a larger budget than the 'lme4' default,
#' for the correlated random slopes of the larger calibration models. The
#' convergence tolerances are those of 'lme4' unless `control` is given;
#' convergence warnings of 'lme4' are passed on. Models without random
#' effects use the iteratively reweighted least squares of `stats::glm()`,
#' with the default `stats::glm.control()` (`epsilon = 1e-8`, `maxit =
#' 25`) unless `control` is given.
#'
#' `control` replaces these settings: a `lme4::glmerControl()` object for
#' a formula with random effects (for example another optimiser, a larger
#' `optCtrl = list(maxfun = )` or other `check.conv.grad` tolerances), or
#' a list of `stats::glm.control()` arguments (`epsilon`, `maxit`) for a
#' formula without them. With `engine = "brms"`, `control` is passed to
#' `brms::brm()` as its list of sampler settings (for example
#' `list(adapt_delta = 0.95, max_treedepth = 12)`).
#'
#' @section Bayesian computation:
#' With `engine = "brms"`, the posterior is sampled with the No-U-Turn
#' Sampler (NUTS) of Stan (Carpenter et al. 2017,
#' \doi{10.18637/jss.v076.i01}) through 'brms' (Bürkner 2017,
#' \doi{10.18637/jss.v080.i01}). The computational settings are those of
#' `brms::brm()` unless they are given in `...`: 4 chains of 2000
#' iterations each, of which the first half (`warmup = floor(iter / 2)`)
#' is warmup, without thinning (`thin = 1`), and random initial values
#' (`init = NULL`). Initial values can be set with `init`, passed on to
#' `brms::brm()`; to start from a previous fit, pass its posterior means
#' as `init` or refit the model. `stats::update()` on the returned
#' `brmsfit` runs the sampler again but returns an object without the
#' attributes `sheepdog_levels` and `sheepdog_seed`, so a model refitted
#' that way cannot be passed to [score_detections()]; call
#' `fit_calibration()` again instead.
#'
#' Only NUTS is supported. Other algorithms of `brms::brm()` (`algorithm =
#' "meanfield"`, for instance) can be passed through `...`, but
#' [calibration_diagnostics()], which reads the NUTS parameters, then
#' fails. The convergence checks of [calibration_diagnostics()] always run
#' after the fit and cannot be switched off; a model that fails them
#' raises a warning, which `suppressWarnings()` silences. sheepdog has no
#' verbosity argument of its own: the progress output of Stan is
#' controlled by `refresh` (e.g. `refresh = 0`, passed on to the Stan
#' backend) and `silent` (e.g. `silent = 2`) of `brms::brm()`, and the
#' messages of sheepdog by `suppressMessages()`.
#'
#' @section Methods for the fitted model:
#' The returned object keeps the class of the fitting function, so the
#' methods of `stats`, 'lme4' and 'brms' apply. Confidence intervals of
#' the coefficients come from `stats::confint()` for `glm` and `glmerMod`
#' models (profile likelihood by default; `method = "Wald"` for a
#' faster approximation of a `glmerMod`), and credible intervals from
#' `brms::posterior_interval()` or `summary()` for a `brmsfit`.
#' `stats::residuals()` returns deviance residuals for `glm` and
#' `glmerMod` models and, for a `brmsfit`, the posterior summary of the
#' response residuals (observed minus fitted probability). With a binary response, residuals take
#' two values for each fitted probability and say little one by one; check
#' the fit with the calibration intercept and slope of
#' [compare_calibration_models()], with [calibration_quality()], or with the
#' binned posterior predictive check of [calibration_ppc()] for a
#' `brmsfit`.
#'
#' @srrstats {G2.1, G2.5, RE1.2, RE2.1, BS2.1, BS3.0} The section "Input checks and missing values" documents the
#'   expected classes and columns, checked by `check_validations()`, and
#'   the fixed missing-value policy (rows left out with a message before
#'   the fit).
#' @srrstats {RE2.4, RE2.4a, RE2.4b, BS3.1} `check_calibration_data()`
#'   checks the rank of the fixed-effects model matrix and the separation
#'   of `tp` by `logit_conf`, globally and by species, before the fit.
#' @srrstats {BS2.2} The class of `prior` is checked.
#' @srrstats {RE1.1} The section "Formula and model matrix" states that
#'   the matrices are built by `stats::glm()`, `lme4::glmer()` or
#'   `brms::brm()`.
#' @srrstats {RE1.3, RE1.3a} The section "Formula and model matrix" states
#'   which attributes are transferred (`sheepdog_levels`,
#'   `sheepdog_seed`) and that columns outside the formula are not kept.
#' @srrstats {RE3.2} The section "Maximum likelihood fit" documents the
#'   default `glmerControl()` and `glm.control()` settings.
#' @srrstats {RE3.3} The argument `control` sets the optimiser,
#'   evaluation budget and convergence tolerances of 'lme4' and `glm()`,
#'   or the sampler settings of 'brms'.
#' @srrstats {RE4.3} The section "Methods for the fitted model" points to
#'   `confint()` and `brms::posterior_interval()`.
#' @srrstats {RE4.10} The section "Methods for the fitted model"
#'   describes the residuals of each class and how to interpret them for
#'   a binary response.
#' @srrstats {RE4.12} The bounded logit of the score and its inverse
#'   (`stats::plogis()`) are documented here and in [read_validations()].
#' @srrstats {BS1.2c} The examples show how to specify the prior.
#' @srrstats {BS1.3, BS1.3a, BS2.7, BS2.8} The section "Bayesian
#'   computation" documents the defaults passed to `brms::brm()`, initial
#'   values through `init`, and why `update()` should not be used to
#'   continue a fit.
#' @srrstats {BS1.3b} Only NUTS is supported; the section "Bayesian
#'   computation" says what happens with other algorithms.
#' @srrstats {BS1.4} The convergence checks always run; the section
#'   "Bayesian computation" says how to silence the warning.
#' @srrstats {BS2.12} Verbosity is controlled by the `refresh` and
#'   `silent` arguments of `brms::brm()` and by `suppressMessages()`.
#' @srrstats {BS4.0} The section "Bayesian computation" states that the
#'   sampler is the NUTS of Stan through 'brms', with references.
#'
#' @inheritParams compare_calibration_models
#' @param formula A model formula, usually the best one of
#'   [compare_calibration_models()].
#' @param engine Character scalar, one of `"lme4"` (default) or `"brms"`.
#' @param prior `NULL` or a `brmsprior` object. With `engine = "brms"`, the
#'   prior, e.g. from [calibration_prior()]. Required.
#' @param control `NULL` or a single object with settings of the fitting
#'   algorithm: a `lme4::glmerControl()` object (formula with random effects) or
#'   a list of `stats::glm.control()` arguments (formula without them) with
#'   `engine = "lme4"`; a list of sampler settings passed to `brms::brm()` with
#'   `engine = "brms"`. `NULL` (default) keeps the settings described in
#'   "Maximum likelihood fit" and the 'brms' defaults. See the section "Maximum
#'   likelihood fit".
#' @param ... `engine = "brms"`: further arguments for `brms::brm()` (e.g.
#'   `chains`, `iter`, `cores`, `backend`, `seed`). Without `seed`, one is
#'   drawn from R's random number generator (so `set.seed()` before the
#'   call makes the fit reproducible) and passed to `brms::brm()`.
#'
#' @return A `glm`, `glmerMod` or `brmsfit` model, with the attribute
#'   `sheepdog_levels` (the species and site levels), used by
#'   [score_detections()] and [plot_calibration()]. A `brmsfit` also
#'   carries the attribute `sheepdog_seed`, the seed given to Stan, so that
#'   the fit can be repeated.
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read_validations(list.files(file.path(ex, "validation"),
#'                                    full.names = TRUE))
#' # Maximum likelihood, one species-level random intercept
#' if (requireNamespace("lme4", quietly = TRUE)) {
#'   fit <- fit_calibration(val, tp ~ logit_conf + (1 | species))
#'   print(lme4::fixef(fit))
#'   confint(fit, method = "Wald", parm = "beta_")
#' }
#'
#' # Bayesian fit: the prior is always given explicitly. Fitting compiles a
#' # Stan model, which takes minutes, so this part is not run here.
#' \dontrun{
#' f <- tp ~ logit_conf + (1 | species)
#' prior <- calibration_prior(f, val)
#' fit_b <- fit_calibration(val, f, engine = "brms", prior = prior,
#'                          chains = 4, iter = 2000, seed = 1,
#'                          refresh = 0)
#' calibration_diagnostics(fit_b)
#' brms::posterior_interval(fit_b)
#' }
#' @export
fit_calibration <- function(validations, formula,
                            engine = c("lme4", "brms"), prior = NULL,
                            control = NULL, ...) {
  engine <- match.arg(engine)
  if (engine == "brms") {
    require_suggested("brms", "for Bayesian calibration models")
    if (is.null(prior)) {
      stop("engine = \"brms\" needs an explicit `prior`; ",
           "calibration_prior() builds an example centred on an already ",
           "calibrated score.", call. = FALSE)
    }
    if (!inherits(prior, "brmsprior")) {
      stop("`prior` must be a brmsprior object, e.g. from ",
           "calibration_prior() or brms::prior().", call. = FALSE)
    }
    validations <- check_calibration_input(validations, formula)
    dots <- list(...)
    if (!is.null(control)) {
      if (!is.list(control)) {
        stop("With engine = \"brms\", `control` must be a list of sampler ",
             "settings for brms::brm(), e.g. list(adapt_delta = 0.95).",
             call. = FALSE)
      }
      dots$control <- control
    }
    if (is.null(dots$seed) || is.na(dots$seed)) {
      dots$seed <- sample.int(.Machine$integer.max, 1)
    }
    fit <- do.call(brms::brm,
                   c(list(formula, data = validations,
                          family = brms::bernoulli(), prior = prior), dots))
    attr(fit, "sheepdog_seed") <- dots$seed
    attr(fit, "sheepdog_levels") <- list(
      species = levels(validations$species), site = levels(validations$site))
    diag <- calibration_diagnostics(fit)
    if (!diag$ok) {
      warning("The Bayesian calibration model did not pass the convergence ",
              "checks (max R-hat ", signif(diag$max_rhat, 4),
              ", min bulk/tail ESS ", round(diag$min_ess_bulk), "/",
              round(diag$min_ess_tail), ", ", diag$n_divergent,
              " divergent transitions). Run longer chains or revise the ",
              "model before using it.", call. = FALSE)
    }
    return(fit)
  }
  validations <- check_calibration_input(validations, formula)
  control <- check_fit_control(control, formula)
  fit <- fit_model(formula, validations, quiet = FALSE, control = control)
  if (inherits(fit, "merMod") && lme4::isSingular(fit)) {
    warning("Singular fit (boundary) of the calibration model ",
            deparse1(formula), ": a variance component is estimated at ",
            "zero or a correlation at +-1. Check lme4::VarCorr(fit) and ",
            "consider a simpler model.", call. = FALSE)
  }
  attr(fit, "sheepdog_levels") <- list(species = levels(validations$species),
                                       site    = levels(validations$site))
  fit
}

#' Add the seed of calibrate() to the brms arguments
#'
#' The seed of calibrate() is used for the Bayesian refit when `brms_args`
#' has none of its own.
#'
#' @param brms_args A list of arguments for `brms::brm()`.
#' @param seed Integer scalar, the seed of calibrate().
#' @return `brms_args`, with `seed` added when it was absent.
#' @noRd
brms_args_with_seed <- function(brms_args, seed) {
  if (is.null(brms_args$seed)) brms_args$seed <- seed
  brms_args
}

#' Check the input of fit_calibration()
#'
#' Checks a formula with response `tp` and the columns it uses, drops rows
#' with missing values with a message, then checks collinearity, a single
#' verdict class and separation.
#'
#' @param validations A data frame of calibration data.
#' @param formula A two-sided model formula with response `tp`.
#' @return A tibble, `validations` without the rows with missing values in
#'   the variables of `formula`.
#' @noRd
check_calibration_input <- function(validations, formula) {
  if (!inherits(formula, "formula") || length(formula) != 3L) {
    stop("`formula` must be a two-sided formula, e.g. one of ",
         "calibration_models().", call. = FALSE)
  }
  if (!identical(all.vars(formula[[2]]), "tp")) {
    stop("The response of `formula` must be `tp` (1 = true positive, ",
         "0 = false positive).", call. = FALSE)
  }
  vars <- all.vars(formula)
  val <- check_validations(validations,
                           cols = unique(c("site", "species", vars)))
  val <- drop_missing(val, vars)
  check_calibration_data(val, formula)
  val
}

#' Whether a formula has random effects
#'
#' Looks for the bar `|` of the lme4 syntax; lme4 is in Suggests, so
#' `lme4::findbars()` cannot be used here.
#'
#' @param formula A model formula.
#' @return Logical scalar.
#' @noRd
has_random_effects <- function(formula) {
  grepl("|", deparse1(formula), fixed = TRUE)
}

#' Require lme4 when any formula has random effects
#'
#' Called before fits wrapped in tryCatch(), which would otherwise turn
#' into silent `NA`s.
#'
#' @param formulas A list of model formulas.
#' @return `NULL`, invisibly; called for the error when lme4 is missing.
#' @noRd
need_lme4 <- function(formulas) {
  if (any(map_lgl(formulas, has_random_effects))) {
    require_suggested("lme4", "to fit calibration models with random effects")
  }
}

#' Species and site levels stored by fit_calibration()
#'
#' @param fit A model returned by fit_calibration().
#' @return A list with character vectors `species` and `site`.
#' @noRd
fit_levels <- function(fit) {
  lvls <- attr(fit, "sheepdog_levels")
  if (is.null(lvls)) stop("`fit` must come from fit_calibration().")
  lvls
}

#' Default control of lme4::glmer() in sheepdog
#'
#' @return A `glmerControl` object: bobyqa with up to 1e5 evaluations.
#' @noRd
default_glmer_control <- function() {
  lme4::glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5))
}

#' Check `control` of fit_calibration() against the model being fitted
#'
#' @param control `NULL`, a `glmerControl` object (formula with random
#'   effects) or a list of `stats::glm.control()` arguments (otherwise).
#' @param formula A model formula.
#' @return `NULL`, the `glmerControl` object, or the output of
#'   `stats::glm.control()`.
#' @noRd
check_fit_control <- function(control, formula) {
  if (is.null(control)) return(NULL)
  if (has_random_effects(formula)) {
    if (!inherits(control, "glmerControl")) {
      stop("`control` must be a glmerControl object from ",
           "lme4::glmerControl() for a formula with random effects.",
           call. = FALSE)
    }
    return(control)
  }
  if (!is.list(control) || inherits(control, "merControl")) {
    stop("`control` must be a list from stats::glm.control() for a ",
         "formula without random effects.", call. = FALSE)
  }
  do.call(stats::glm.control, control)
}

#' Fit a glm (no random effects) or a glmer
#'
#' The messages of glmer are kept in the attribute `sheepdog_messages`;
#' with `quiet = FALSE`, those not about a singular fit (which becomes a
#' warning in fit_calibration()) are passed on. In the folds and in the
#' repetitions of the effort curve they stay quiet, so that the same
#' message is not repeated dozens of times.
#'
#' @param formula A model formula with response `tp`.
#' @param data A data frame with the variables of `formula`.
#' @param quiet Logical scalar; `FALSE` passes on the lme4 messages.
#' @param control `NULL` or a control object for `stats::glm()` or
#'   `lme4::glmer()`.
#' @return A `glm` or `glmerMod` model.
#' @noRd
fit_model <- function(formula, data, quiet = TRUE, control = NULL) {
  if (!has_random_effects(formula)) {
    if (is.null(control)) control <- stats::glm.control()
    return(stats::glm(formula, data = data, family = stats::binomial,
                      control = control))
  }
  require_suggested("lme4", "to fit calibration models with random effects")
  if (is.null(control)) control <- default_glmer_control()
  msgs <- character()
  fit <- withCallingHandlers(
    lme4::glmer(formula, data = data, family = stats::binomial,
                control = control),
    message = function(m) {
      msgs <<- c(msgs, trimws(conditionMessage(m)))
      invokeRestart("muffleMessage")
    })
  attr(fit, "sheepdog_messages") <- msgs
  if (!quiet) {
    others <- msgs[!grepl("singular", msgs, ignore.case = TRUE)]
    for (m in others) message("lme4: ", m)
  }
  fit
}

#' Predicted P(TP)
#'
#' New species or site levels use the fixed effects only (lme4) or draws
#' from the random-effects distribution (brms).
#'
#' @param model A `glm`, `glmerMod` or `brmsfit` model.
#' @param data A data frame of new data.
#' @return Numeric vector with one P(TP) per row of `data` (the posterior
#'   mean for a `brmsfit`).
#' @noRd
predict_tp <- function(model, data) {
  if (inherits(model, "brmsfit")) {
    colMeans(brms::posterior_epred(model, newdata = data,
                                   allow_new_levels = TRUE))
  } else if (inherits(model, "merMod")) {
    stats::predict(model, newdata = data, type = "response",
                   allow.new.levels = TRUE)
  } else {
    stats::predict(model, newdata = data, type = "response")
  }
}

#' P(TP) with a pointwise interval
#'
#' Wald on the link scale for glm and, from the fixed effects only, for
#' glmerMod; posterior quantiles for brms.
#'
#' @param model A `glm`, `glmerMod` or `brmsfit` model.
#' @param data A data frame of new data.
#' @param level Numeric scalar in (0, 1), coverage of the interval.
#' @return A tibble with `p_tp`, `lower` and `upper`, one row per row of
#'   `data`.
#' @noRd
predict_tp_interval <- function(model, data, level = 0.95) {
  a <- (1 - level) / 2
  if (inherits(model, "brmsfit")) {
    ep <- brms::posterior_epred(model, newdata = data,
                                allow_new_levels = TRUE)
    return(tibble(p_tp = colMeans(ep),
                  lower = apply(ep, 2, stats::quantile, probs = a),
                  upper = apply(ep, 2, stats::quantile, probs = 1 - a)))
  }
  if (inherits(model, "merMod")) {
    eta <- stats::predict(model, newdata = data, type = "link",
                          allow.new.levels = TRUE)
    fixed_f <- stats::formula(model, fixed.only = TRUE)
    X <- stats::model.matrix(stats::delete.response(stats::terms(fixed_f)),
                             data)
    V <- as.matrix(stats::vcov(model))
    se <- sqrt(rowSums((X %*% V) * X))
  } else {
    pr <- stats::predict(model, newdata = data, type = "link",
                         se.fit = TRUE)
    eta <- pr$fit
    se <- pr$se.fit
  }
  z <- stats::qnorm(1 - a)
  tibble(p_tp = stats::plogis(eta), lower = stats::plogis(eta - z * se),
         upper = stats::plogis(eta + z * se))
}

#' Area under the ROC curve
#'
#' @param tp Integer vector of 0/1 verdicts.
#' @param p Numeric vector of predicted probabilities or scores.
#' @return Numeric scalar, the AUC (direction chosen by `pROC::roc()`).
#' @noRd
auc <- function(tp, p) {
  as.numeric(pROC::auc(pROC::roc(tp, p, quiet = TRUE)))
}

#' Effort curve of the calibration
#'
#' How many reviewed clips per site x species are needed to calibrate
#' well? For each training size, draws that many clips per cell (keeping
#' at least five for testing), fits the model and computes the AUC on the
#' remaining clips. Repetitions with fewer than 50 test clips, or whose
#' fit fails, are dropped.
#'
#' Cells with fewer than `n_train + 5` clips contribute all but five of
#' their clips, so the training size actually used can be below
#' `n_train`; it is reported in `n_train_mean`, with a warning. The test
#' set shrinks as `n_train` grows (`n_test_mean`), which widens `auc_sd`.
#'
#' @inheritParams fit_calibration
#' @param n_train Numeric vector of whole numbers, training sizes (clips) per
#'   site x species.
#' @param n_reps Integer scalar >= 1, repetitions per training size.
#' @param seed Integer scalar, seed of the draws. The global random number
#'   generator is left as it was.
#'
#' @return A tibble with `n_per_cell` (the requested training size),
#'   `auc_mean`, `auc_sd`, `n_train_mean` (mean clips per cell actually
#'   used for training), `n_test_mean` (mean size of the test set) and
#'   `n_failed` (repetitions dropped).
#' @export
calibration_effort <- function(validations, formula,
                               n_train = c(5, 10, 15, 20, 25, 30),
                               n_reps = 50, seed = 2026) {
  need_lme4(list(formula))
  smallest <- min(count(validations, site, species)$n)
  above <- n_train[n_train > smallest - 5]
  if (length(above) > 0) {
    warning("n_train = ", paste(above, collapse = ", "), " exceeds the ",
            "smallest site x species cell (", smallest, " clips) minus the 5 ",
            "kept for testing; see n_train_mean for the size actually used.",
            call. = FALSE)
  }
  message("Effort curve (", n_reps, " repetitions per n)...")
  withr::with_seed(seed, {
    map(n_train, function(n_tr) {
      reps <- map(seq_len(n_reps), function(r) {
        sampled <- validations |>
          group_by(site, species) |>
          mutate(.train = seq_len(n()) %in%
                   sample(seq_len(n()), min(n_tr, max(n() - 5, 1)))) |>
          ungroup()
        train <- filter(sampled, .train)
        test  <- filter(sampled, !.train)
        n_cell  <- nrow(train) / n_distinct(train$site, train$species)
        failed  <- c(auc = NA_real_, n_train = n_cell, n_test = nrow(test))
        if (nrow(test) < 50) return(failed)
        fit <- tryCatch(fit_model(formula, train), error = function(e) NULL)
        if (is.null(fit)) return(failed)
        c(auc = auc(test$tp, predict_tp(fit, test)), n_train = n_cell,
          n_test = nrow(test))
      }) |>
        do.call(what = rbind)
      tibble(n_per_cell = n_tr,
             auc_mean = mean(reps[, "auc"], na.rm = TRUE),
             auc_sd = stats::sd(reps[, "auc"], na.rm = TRUE),
             n_train_mean = mean(reps[, "n_train"]),
             n_test_mean = mean(reps[, "n_test"]),
             n_failed = sum(is.na(reps[, "auc"])))
    }) |>
      list_rbind()
  })
}

#' Score every detection with the calibration model
#'
#' Reads the complete BirdNET selection tables (not only the reviewed
#' clips) and predicts, for each detection, the probability that it is a
#' true positive. Only species present in the calibration are scored. The
#' night of each detection is its recording date, or the day before for
#' recordings that start before `dawn_hour`.
#'
#' @param tables Named character vector, one element per site, named by site
#'   (the site names of the calibration): the path of the combined selection
#'   table of each site, or the folder of its per-audio tables (see
#'   [read_selection_tables()]).
#' @param fit A `glm`, `glmerMod` or `brmsfit` returned by [fit_calibration()].
#' @param min_confidence Numeric scalar in \[0, 1\]. Detections below this
#'   confidence are not scored.
#' @param dawn_hour Numeric scalar in \[0, 24\]. Recordings that start before
#'   this hour belong to the night before.
#' @param p_min,lower_prob Numeric scalars, `p_min` in \[0, 1\] and `lower_prob`
#'   in (0, 1). Models fitted with `engine = "brms"`: the threshold of
#'   `pr_reliable` and the probability of the lower quantile `p_tp_lower`.
#' @param grid_step Numeric scalar in (0, 0.5). Models fitted with
#'   `engine = "brms"`: step of the grid of scores on which the posterior is
#'   computed.
#'
#' @details With a model fitted with `engine = "brms"`, the posterior of P(TP) is
#' computed once on a grid of scores (step `grid_step`) for each site x
#' species and assigned to the detections by their score rounded to the
#' grid, so that the cost does not depend on the number of detections;
#' the rounding error is small next to the uncertainty of the calibration.
#' Each detection then gets the posterior mean (`p_tp`), a lower quantile
#' (`p_tp_lower`) and the posterior probability that P(TP) >= `p_min`
#' (`pr_reliable`). [detection_history()] can use either rule.
#'
#' Sites or species levels absent from the calibration are new levels for
#' the model. Detections of species that were not calibrated are dropped
#' (with a message giving their number). Detections at a site that was not
#' in the calibration are scored with a warning. With a `glm` or
#' `glmerMod` model (`allow.new.levels = TRUE` of 'lme4'), the effects of
#' the new site are set to zero, so P(TP) comes from the fixed and
#' species effects only. With a `brmsfit` (`allow_new_levels = TRUE` of
#' 'brms'), the effects of the new site are drawn from the fitted
#' random-effects distribution, which widens the posterior of P(TP).
#'
#' @srrstats {RE4.16} New site levels are predicted from the fixed and
#'   species effects, as documented here, with a warning.
#'
#' @return A tibble with `site`, `species`, `date`, `night`, `hour`,
#'   `confidence`, `p_tp`, `begin_path` and `file_offset`; with a model
#'   fitted with `engine = "brms"`, also `p_tp_lower` and `pr_reliable`.
#' @export
score_detections <- function(tables, fit, min_confidence = 0.1,
                             dawn_hour = 12, p_min = 0.95, lower_prob = 0.05,
                             grid_step = 0.01) {
  if (!is.character(tables) || length(tables) == 0L ||
      is.null(names(tables)) || any(!nzchar(names(tables)))) {
    stop("`tables` must be a character vector of paths named by site.",
         call. = FALSE)
  }
  check_prob(min_confidence, "min_confidence")
  check_number(dawn_hour, "dawn_hour", 0, 24)
  check_prob(p_min, "p_min")
  check_prob(lower_prob, "lower_prob", open = TRUE)
  check_number(grid_step, "grid_step", 0, 0.5, open = TRUE)
  bayes <- inherits(fit, "brmsfit")
  lvls <- fit_levels(fit)
  new_sites <- setdiff(names(tables), lvls$site)
  if (length(new_sites) > 0) {
    warning("Site(s) not in the calibration, scored with the species ",
            "effects only: ", paste(new_sites, collapse = ", "))
  }
  imap(tables, function(path, loc) {
    if (!file.exists(path)) {
      warning("Table not found for ", loc, ": ", path)
      return(NULL)
    }
    message("Scoring ", loc, " (", path, ")...")
    tb <- read_score_columns(path)
    if (is.null(tb)) {
      warning("No table read for ", loc, ": ", path)
      return(NULL)
    }
    m <- str_match(basename(tb$begin_path), "(\\d{8})_(\\d{6})")
    tb <- tb |>
      mutate(
        species = folder_name(species_code),
        date    = m[, 2],
        hour    = as.integer(str_sub(m[, 3], 1, 2)),
        night   = if_else(hour < dawn_hour,
                          format(as.Date(date, "%Y%m%d") - 1, "%Y%m%d"),
                          date),
        site    = loc
      ) |>
      filter(confidence >= min_confidence)

    n_out <- sum(!tb$species %in% lvls$species)
    tb <- filter(tb, species %in% lvls$species)
    message("  ", nrow(tb), " detections of calibrated species (", n_out,
            " of species NOT calibrated were dropped).")
    if (nrow(tb) == 0) return(NULL)

    if (bayes) {
      spp <- sort(unique(tb$species))
      gd <- grid_draws(fit, loc, spp, min_confidence, grid_step)
      draw_summary <- bind_cols(
        mutate(gd$grid, species = as.character(species),
               .g = rep(seq_along(score_grid(min_confidence, grid_step)),
                        length(spp))) |>
          select(species, .g),
        summarise_grid_draws(gd$draws, p_min, lower_prob))
      return(tb |>
        mutate(.g = snap_to_grid(confidence, min_confidence, grid_step)) |>
        left_join(draw_summary, by = c("species", ".g")) |>
        select(site, species, date, night, hour, confidence, p_tp,
               p_tp_lower, pr_reliable, begin_path, file_offset))
    }

    tb |>
      mutate(logit_conf = safe_logit(confidence),
             species = factor(species, levels = lvls$species),
             site    = factor(site, levels = lvls$site),
             p_tp    = predict_tp(fit, pick(everything())),
             # site absent from the calibration is NA as factor: keep name
             site    = loc) |>
      select(site, species, date, night, hour, confidence, p_tp,
             begin_path, file_offset)
  }) |>
    compact() |>
    list_rbind()
}

#' Read the columns used for scoring
#'
#' From a combined selection table (a file) or from the per-audio tables
#' of a folder.
#'
#' @param path Character scalar, path to a combined selection table or to
#'   a folder of per-audio tables.
#' @return A tibble with `species_code`, `confidence`, `begin_path` and
#'   `file_offset`, or `NULL` when no table is found.
#' @noRd
read_score_columns <- function(path) {
  cols <- c("species_code", "confidence", "begin_path", "file_offset")
  if (!dir.exists(path)) {
    tb <- read_tsv(path, show_col_types = FALSE, progress = FALSE,
                   col_select = c(`Species Code`, Confidence,
                                  `Begin Path`, `File Offset (s)`))
    names(tb) <- cols
    return(tb)
  }
  sources <- suppressMessages(find_selection_tables(
    path, "^BirdNET_SelectionTable\\.txt$",
    "\\.BirdNET\\.selection\\.table\\.txt$"))
  if (length(sources) == 0) return(NULL)
  if (length(sources) > 1) {
    stop("The folder ", path, " holds tables in ", length(sources),
         " folders; give one folder per site.", call. = FALSE)
  }
  tb <- read_site_tables(sources[[1]])
  if (is.null(tb)) return(NULL)
  select(tb, all_of(cols))
}

#' Nightly detection history
#'
#' Aggregates the scored detections by site x species x night. A night has
#' a detection when at least `min_detections_night` detections have a
#' calibrated probability >= `p_min`; the columns `detection_k1` to
#' `detection_k3` give the same rule with k = 1, 2 and 3, as a
#' sensitivity analysis.
#'
#' @param scored A data frame (or tibble) returned by [score_detections()], one
#'   row per detection.
#' @param p_min Numeric scalar in \[0, 1\], threshold on the calibrated
#'   probability (not on the confidence score).
#' @param min_detections_night Integer scalar >= 1, repetition rule: minimum
#'   number of reliable detections for a night with detection.
#' @param rule Character scalar, one of `"mean"` (default) or `"probability"`:
#'   when a detection is reliable. `"mean"`, its calibrated probability (the
#'   posterior mean with `engine = "brms"`) is >= `p_min`; `"probability"`, the
#'   posterior probability that P(TP) >= `p_min` (the `pr_reliable` of a model
#'   fitted with `engine = "brms"`) is >= `prob_min`. The second rule propagates
#'   the uncertainty of the calibration and is more conservative where few clips
#'   were reviewed.
#' @param prob_min Numeric scalar in \[0, 1\]. With `rule = "probability"`,
#'   threshold on `pr_reliable`. `pr_reliable` is computed in
#'   [score_detections()] for its `p_min`; use the same `p_min` in both.
#'
#' @return A tibble with `site`, `species`, `night`, `n_detections`,
#'   `n_reliable`, `p_tp_max`, `detection_k1`, `detection_k2`,
#'   `detection_k3` and `detection`.
#' @export
detection_history <- function(scored, p_min = 0.95,
                              min_detections_night = 1,
                              rule = c("mean", "probability"),
                              prob_min = 0.9) {
  rule <- match.arg(rule)
  if (rule == "probability") {
    if (!"pr_reliable" %in% names(scored)) {
      stop("rule = \"probability\" needs `pr_reliable`, from ",
           "score_detections() with a model fitted with engine = \"brms\".",
           call. = FALSE)
    }
    scored <- mutate(scored, .reliable = pr_reliable >= prob_min)
  } else {
    scored <- mutate(scored, .reliable = p_tp >= p_min)
  }
  scored |>
    group_by(site, species, night) |>
    summarise(
      n_detections = n(),
      n_reliable   = sum(.reliable),
      p_tp_max     = max(p_tp),
      detection_k1 = as.integer(n_reliable >= 1),
      detection_k2 = as.integer(n_reliable >= 2),
      detection_k3 = as.integer(n_reliable >= 3),
      .groups = "drop"
    ) |>
    mutate(detection = as.integer(n_reliable >= min_detections_night))
}

#' Summarise the detection history by site and species
#'
#' @param history A data frame (or tibble) returned by [detection_history()].
#'
#' @return A tibble with `site`, `species`, `nights` (nights with any
#'   scored detection) and `nights_k1` to `nights_k3` (nights with
#'   detection under each repetition rule).
#' @export
summarise_history <- function(history) {
  history |>
    group_by(site, species) |>
    summarise(nights = n(),
              nights_k1 = sum(detection_k1), nights_k2 = sum(detection_k2),
              nights_k3 = sum(detection_k3), .groups = "drop")
}

#' Plot the calibration curves
#'
#' Calibrated probability of a true detection against the confidence
#' score, one panel per species and one line per site, with the observed
#' precision by confidence bin as points. Needs the 'ggplot2' package.
#'
#' @inheritParams compare_calibration_models
#' @inheritParams score_detections
#' @inheritParams detection_history
#' @param model_name Character scalar, name shown in the subtitle.
#' @param interval Logical scalar. If `TRUE`, draw a band around each curve: a
#'   pointwise confidence interval of P(TP) for `glm` and `glmerMod` fits, a
#'   credible interval for `brmsfit` fits. `FALSE` (default) draws the curves
#'   only.
#' @param level Numeric scalar in (0, 1), coverage of the band.
#'
#' @details For a `glm` fit the band is the Wald interval of the linear
#'   predictor (`predict(se.fit = TRUE)`) transformed by `plogis()`. For a
#'   `glmerMod` fit it is the same interval computed from the covariance
#'   matrix of the fixed effects only: the predicted random effects are
#'   treated as known, so the band is narrower than one that also carried
#'   their uncertainty, and levels not seen in the fit get the
#'   fixed-effects interval. For a `brmsfit` the band holds the central
#'   quantiles of the posterior draws of P(TP) (`brms::posterior_epred()`)
#'   and carries all the parameter uncertainty.
#'
#' @srrstats {RE6.2} The curves are the fitted P(TP) over a grid of
#'   scores; `interval = TRUE` adds pointwise confidence or credible bands.
#' @return A ggplot object.
#' @export
plot_calibration <- function(fit, validations, min_confidence = 0.1,
                             p_min = 0.95, model_name = "",
                             interval = FALSE, level = 0.95) {
  require_suggested("ggplot2", "to plot the calibration curves")
  check_flag(interval, "interval")
  check_prob(level, "level", open = TRUE)
  lvls <- fit_levels(fit)
  grid <- expand_grid(
    species    = factor(lvls$species, levels = lvls$species),
    site       = factor(lvls$site, levels = lvls$site),
    confidence = seq(min_confidence, 0.99, by = 0.01)
  ) |>
    mutate(logit_conf = safe_logit(confidence))
  if (interval) {
    band <- predict_tp_interval(fit, grid, level)
    grid <- dplyr::bind_cols(grid, band)
  } else {
    grid$p_tp <- predict_tp(fit, grid)
  }

  obs_bin <- validations |>
    mutate(bin = pmin(floor(confidence * 10) / 10 + 0.05, 0.95)) |>
    group_by(species, site, bin) |>
    summarise(prec = mean(tp), n = n(), .groups = "drop")

  ggplot2::ggplot(grid, ggplot2::aes(confidence, p_tp, colour = site)) +
    ggplot2::geom_hline(yintercept = p_min, linetype = "dashed",
                        colour = "grey50") +
    (if (interval) {
      ggplot2::geom_ribbon(ggplot2::aes(ymin = lower, ymax = upper,
                                        fill = site),
                           alpha = 0.15, colour = NA)
    }) +
    ggplot2::geom_line(linewidth = 0.5) +
    ggplot2::geom_point(data = obs_bin,
                        ggplot2::aes(bin, prec, size = n, colour = site),
                        alpha = 0.4) +
    ggplot2::scale_size_continuous(range = c(0.5, 3),
                                   name = "reviewed clips") +
    ggplot2::facet_wrap(~ species) +
    ggplot2::labs(x = "BirdNET confidence",
                  y = "Calibrated P(true detection)",
                  title = "Score-to-probability calibration, by species and site",
                  subtitle = paste0("Model: ", model_name,
                                    " | dashed line: p_min = ", p_min)) +
    ggplot2::theme_minimal(base_size = 10)
}

#' Calibrate confidence scores and build detection histories
#'
#' Runs the whole calibration stage: reads the reviewed clips, compares the
#' candidate models by cross-validation, refits the best one to all the
#' clips, optionally draws the effort curve, scores every detection of the
#' complete selection tables and builds the nightly detection history.
#' Writes to `output_dir`:
#' * `model_comparison.csv` ([compare_calibration_models()]);
#' * `calibration_folds.csv`, when `fold_group` is supplied: validation
#'   row number, site, species, grouping columns and assigned fold;
#' * `calibration_model.rds` and `calibration_model.txt` (the refitted
#'   best model and its summary);
#' * `calibration_curves.png` ([plot_calibration()]), when 'ggplot2' is
#'   installed;
#' * `effort_curve.csv` ([calibration_effort()]), when `effort_curve` is
#'   `TRUE`;
#' * `calibrated_detections_<site>.csv`, one per site
#'   ([score_detections()]);
#' * `thresholds.csv` ([calibrated_thresholds()] with
#'   `rule = "probability"` and `target = p_min`): for each site x species,
#'   the lowest confidence score at which P(TP) reaches `p_min`, the score
#'   equivalent of the cut on P(TP) used by the detection history. Useful to
#'   filter detections in software that only takes a score threshold;
#' * `nightly_detection_history.csv` ([detection_history()]);
#' * `detection_summary.csv` ([summarise_history()]).
#'
#' The candidate family follows the observed species and sites: one
#' species uses the site-effect family of [calibration_models()], and
#' a single site omits non-estimable site random effects.
#'
#' The model is chosen by [select_calibration_model()] with the rule
#' `select`: by default, the simplest model within one standard error of
#' the lowest log-loss, leaving out models singular in most folds
#' (`"one_se_logloss"`). Use `select = "best_auc"` to reproduce the 2.x
#' selection by highest mean AUC. When the refit is singular,
#' [fit_calibration()] warns; read `calibration_model.txt` and the
#' comparison before using the probabilities.
#'
#' Wood & Kahl (2024, \doi{10.1007/s10336-024-02144-5}) describe the
#' conversion of BirdNET confidence scores into probabilities for studies in
#' which the predictions cannot all be reviewed;
#' calibration by logistic regression on logit(score) is applied, for
#' instance, by Owens et al. (2026, \doi{10.64898/2026.06.01.729442}).
#' This function extends that approach with a hierarchical multi-species
#' structure. This is the function form of the v1.2.0 script
#' `calibracao.R`.
#'
#' @param validation_files Character vector, paths to the
#'   `validation_by_clip.csv` files of the sites (v1.2.0
#'   `validacao_por_clipe.csv` files are also read).
#' @param prediction_tables Named character vector of the complete selection
#'   tables, one element per site, named by site: the path of each combined
#'   table, or the folder of the per-audio tables of each site (see
#'   [score_detections()]).
#' @param output_dir Character scalar, output folder; created if needed. The
#'   calibrated detections of a large project can take hundreds of MB.
#' @inheritParams read_validations
#' @inheritParams score_detections
#' @inheritParams detection_history
#' @inheritParams compare_calibration_models
#' @param select Character scalar, one of `"one_se_logloss"` (default) or
#'   `"best_auc"`: the rule to choose the model; see
#'   [select_calibration_model()].
#' @param engine Character scalar, one of `"lme4"` (default) or `"brms"`: the
#'   engine of the final fit (see [fit_calibration()]). The comparison of the
#'   candidate models always uses maximum likelihood (fast); with `"brms"`, the
#'   selected model is then refitted in a Bayesian framework, its convergence
#'   diagnostics are written to `calibration_diagnostics.csv`, and the scored
#'   detections carry `p_tp_lower` and `pr_reliable`.
#' @param prior `NULL`, a `brmsprior` object or a function. With
#'   `engine = "brms"`, the prior, as a `brmsprior` object or as a function of
#'   the selected formula and the validations that returns one, e.g.
#'   `calibration_prior` (whose classes then match the selected model). Required
#'   with `"brms"`.
#' @param brms_args A list. With `engine = "brms"`, list of further arguments
#'   for `brms::brm()` (e.g.
#'   `list(chains = 4, cores = 4, backend = "cmdstanr")`). Without `seed` in
#'   this list, `seed` is also the seed of the Bayesian refit, so the whole run
#'   is reproducible; it is written to `calibration_model.txt`.
#' @inheritParams detection_history
#' @param uncorrelated Logical scalar. If `TRUE`, include the m4 variant without
#'   the species intercept-slope correlation among the candidates; see
#'   [calibration_models()].
#' @param effort_curve Logical scalar. If `TRUE`, draw the effort curve (slow).
#' @param effort_n,effort_reps Numeric vector of training sizes and integer
#'   scalar >= 1 of repetitions of the effort curve.
#'
#' @return A list with `comparison`, `quality` (from
#'   [calibration_quality()], by species, or by site with one species, also
#'   written to `calibration_quality.csv`), `fit`, `effort` (or `NULL`),
#'   `scored`, `thresholds` and `history`, invisibly.
#' @export
calibrate <- function(validation_files, prediction_tables, output_dir,
                      site_map = NULL, min_confidence = 0.1, p_min = 0.95,
                      min_detections_night = 1, dawn_hour = 12,
                      k_folds = 5,
                      select = c("one_se_logloss", "best_auc"),
                      uncorrelated = FALSE, effort_curve = FALSE,
                      effort_n = c(5, 10, 15, 20, 25, 30),
                      effort_reps = 50, engine = c("lme4", "brms"),
                      prior = NULL, brms_args = list(),
                      rule = c("mean", "probability"), prob_min = 0.9,
                      seed = 2026, fold_group = NULL) {
  select <- match.arg(select)
  engine <- match.arg(engine)
  rule   <- match.arg(rule)
  if (engine == "brms" && is.null(prior)) {
    stop("engine = \"brms\" needs an explicit `prior` (e.g. ",
         "prior = calibration_prior).", call. = FALSE)
  }
  val <- if (is.null(fold_group)) {
    read_validations(validation_files, site_map)
  } else {
    read_validations(validation_files, site_map, keep = fold_group)
  }
  models <- calibration_candidates(val, uncorrelated)

  cv <- compare_calibration_models(val, models, k_folds, seed,
                                    fold_group = fold_group)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  write_csv(cv, file.path(output_dir, "model_comparison.csv"))
  if (!is.null(fold_group)) {
    assignment <- val |> select(any_of(c("site", "species", fold_group)))
    assignment$validation_row <- seq_len(nrow(val))
    assignment$fold <- calibration_folds(val, k_folds, seed, fold_group)
    write_csv(assignment, file.path(output_dir, "calibration_folds.csv"))
  }
  best <- select_calibration_model(cv, select, k_folds)
  message("Selected model (", select, "): ", best)

  quality <- tryCatch(
    calibration_quality(val, models[[best]], k_folds, seed, fold_group,
                        by = if (n_distinct(val$species) > 1L) "species"
                             else "site"),
    error = function(e) {
      message("calibration_quality.csv was not written: ",
              conditionMessage(e))
      NULL
    })
  if (!is.null(quality)) {
    write_csv(quality, file.path(output_dir, "calibration_quality.csv"))
    poor <- filter(quality, status == "poor")
    if (nrow(poor) > 0) {
      message("Check these groups in calibration_quality.csv before using ",
              "their probabilities: ",
              paste(poor[[1]], collapse = ", "), ".")
    }
  }

  if (engine == "brms") {
    prior_final <- if (is.function(prior)) prior(models[[best]], val) else prior
    fit_final <- do.call(fit_calibration,
                         c(list(val, models[[best]], engine = "brms",
                                prior = prior_final),
                           brms_args_with_seed(brms_args, seed)))
    write_csv(calibration_diagnostics(fit_final),
              file.path(output_dir, "calibration_diagnostics.csv"))
  } else {
    fit_final <- fit_calibration(val, models[[best]])
  }
  saveRDS(fit_final, file.path(output_dir, "calibration_model.rds"))
  utils::capture.output(summary(fit_final),
                        file = file.path(output_dir, "calibration_model.txt"))
  # messages of the fit (lme4) at the end of the model summary
  if (!is.null(attr(fit_final, "sheepdog_seed"))) {
    cat("\nStan seed: ", attr(fit_final, "sheepdog_seed"), "\n", sep = "",
        file = file.path(output_dir, "calibration_model.txt"), append = TRUE)
  }
  msgs <- attr(fit_final, "sheepdog_messages")
  if (length(msgs) > 0) {
    cat("\nMessages of the fit:\n", paste0("  ", msgs, "\n"), sep = "",
        file = file.path(output_dir, "calibration_model.txt"), append = TRUE)
  }

  if (has_suggested("ggplot2")) {
    g <- plot_calibration(fit_final, val, min_confidence, p_min, best)
    ggplot2::ggsave(file.path(output_dir, "calibration_curves.png"), g,
                    width = 13, height = 9, dpi = 200, bg = "white")
  } else {
    message("Package 'ggplot2' not installed: calibration_curves.png was ",
            "not drawn.")
  }

  effort <- NULL
  if (isTRUE(effort_curve)) {
    effort <- calibration_effort(val, models[[best]], effort_n,
                                  effort_reps, seed)
    write_csv(effort, file.path(output_dir, "effort_curve.csv"))
  }

  scored <- score_detections(prediction_tables, fit_final,
                                min_confidence, dawn_hour, p_min = p_min)
  # score threshold equivalent to the p_min cut on P(TP), by cell
  thresholds <- tryCatch(
    calibrated_thresholds(fit_final, target = p_min,
                          scored = if (nrow(scored) > 0) scored,
                          min_confidence = min_confidence),
    error = function(e) {
      message("thresholds.csv was not written: ", conditionMessage(e))
      NULL
    })
  if (!is.null(thresholds)) {
    write_csv(thresholds, file.path(output_dir, "thresholds.csv"))
  }

  history <- NULL
  if (nrow(scored) > 0) {
    walk(split(scored, scored$site, drop = TRUE), function(d) {
      write_csv(d, file.path(output_dir, paste0("calibrated_detections_",
                                                d$site[1], ".csv")))
    })
    history <- detection_history(scored, p_min, min_detections_night,
                                   rule = rule, prob_min = prob_min)
    write_csv(history,
              file.path(output_dir, "nightly_detection_history.csv"))
    write_csv(summarise_history(history),
              file.path(output_dir, "detection_summary.csv"))
    message("Nights with a reliable detection (p_tp >= ", p_min, "): ",
            sum(history$detection_k1), " (k = 1), ",
            sum(history$detection_k2), " (k = 2), ",
            sum(history$detection_k3), " (k = 3).")
  }

  message("Done! Outputs in ", output_dir,
          "\nnightly_detection_history.csv is the input of the analyses; ",
          "the column 'detection' uses k = ", min_detections_night,
          "; detection_k1/k2/k3 give the sensitivity to the rule.")
  invisible(list(comparison = cv, quality = quality, fit = fit_final,
                 effort = effort, scored = scored, thresholds = thresholds,
                 history = history))
}
