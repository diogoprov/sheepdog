#' @srrstats {G5.8, G5.8a, G5.8b, G5.8c, G5.8d} Edge conditions of the
#'   calibration functions: zero-row tables, unsupported types, all-missing
#'   or constant columns, a single verdict class, and more random-effect
#'   levels than reviewed clips (an error before the fit).
#' @srrstats {RE7.0, RE7.0a} Exactly collinear predictors are rejected
#'   before the fit.
#' @srrstats {RE7.1} Verdicts exactly determined by the score (complete
#'   separation) raise a warning before the fit.
#' @srrstats {G5.9, G5.9a} Adding noise at the scale of machine precision
#'   to the scores does not change the fit.
#' @srrstats {G5.9b} Different seeds for the cross-validation folds give
#'   similar measures of predictive performance.
NULL

test_that("zero-row tables raise clear errors", {
  d <- sim_calibration(n = 200, seed = 1)
  expect_error(fit_calibration(d[0, ], tp ~ logit_conf), "has no rows")
  expect_error(compare_calibration_models(d[0, ],
                                          list(m = tp ~ logit_conf)),
               "has no rows")
  expect_error(calibration_quality(d[0, ], tp ~ logit_conf),
               "at least one row")
})

test_that("unsupported types raise clear errors", {
  d <- sim_calibration(n = 200, seed = 2)
  bad <- d
  bad$logit_conf <- as.character(bad$logit_conf)
  expect_error(fit_calibration(bad, tp ~ logit_conf), "must be numeric")
  bad <- d
  bad$logit_conf <- complex(real = bad$logit_conf, imaginary = 1)
  expect_error(fit_calibration(bad, tp ~ logit_conf), "must be numeric")
  bad <- d
  bad$tp <- ifelse(bad$tp == 1L, "positive", "negative")
  expect_error(fit_calibration(bad, tp ~ logit_conf),
               "must be 0 \\(false positive\\) or 1")
  bad <- d
  bad$tp[1] <- 3L
  expect_error(fit_calibration(bad, tp ~ logit_conf),
               "must be 0 \\(false positive\\) or 1")
  expect_error(check_confidence(complex(real = 0.5, imaginary = 0)),
               "must be numeric")
})

test_that("all-missing, constant and single-class columns are rejected", {
  d <- sim_calibration(n = 200, seed = 3)
  expect_error(suppressMessages(fit_calibration(
    dplyr::mutate(d, logit_conf = NA_real_), tp ~ logit_conf)),
    "No row of `validations` is complete")
  expect_error(fit_calibration(dplyr::mutate(d, tp = 0L), tp ~ logit_conf),
               "same verdict \\(tp = 0\\)")
  expect_error(fit_calibration(dplyr::mutate(d, tp = 1L), tp ~ logit_conf),
               "same verdict \\(tp = 1\\)")
  expect_error(fit_calibration(dplyr::mutate(d, logit_conf = 0.3),
                               tp ~ logit_conf),
               "collinear")
})

test_that("exactly collinear predictors are rejected", {
  d <- sim_calibration(n = 300, seed = 4)
  d$x1 <- d$logit_conf * 2 + 1
  expect_error(fit_calibration(d, tp ~ logit_conf + x1),
               "model matrix of rank 2 with 3 columns")
  d$x2 <- stats::rnorm(nrow(d))
  d$x3 <- d$x2 - d$logit_conf
  expect_error(fit_calibration(d, tp ~ logit_conf + x2 + x3), "collinear")
})

test_that("verdicts determined exactly by the score raise a warning", {
  d <- sim_calibration(n = 300, seed = 5)
  d$tp <- as.integer(d$logit_conf > 0)
  w <- testthat::capture_warnings(suppressMessages(
    fit_calibration(d, tp ~ logit_conf)))
  expect_true(any(grepl("completely separated by the score", w)))
})

test_that("a random-effect level per reviewed clip is rejected", {
  d <- sim_calibration(n = 40, seed = 6)
  d$site <- factor(seq_len(nrow(d)))
  expect_error(fit_calibration(d, tp ~ logit_conf + (1 | site)),
               "Each level of `site` has a single reviewed clip")
  expect_error(fit_calibration(d, tp ~ logit_conf + (logit_conf || site)),
               "Each level of `site`")
})

test_that("noise at machine precision does not change the fit", {
  skip_if_not_installed("lme4")
  d <- sim_calibration(n = 600, n_species = 6, sd_species = 0.5, seed = 7)
  ruido <- withr::with_seed(1, stats::runif(nrow(d), -1, 1)) *
    .Machine$double.eps
  d2 <- dplyr::mutate(d, logit_conf = logit_conf + ruido)
  for (f in list(tp ~ logit_conf, tp ~ logit_conf + (1 | species))) {
    c1 <- stats::coef(summary(suppressMessages(fit_calibration(d, f))))
    c2 <- stats::coef(summary(suppressMessages(fit_calibration(d2, f))))
    expect_equal(c1, c2, tolerance = 1e-6)
  }
})

test_that("different fold seeds give similar predictive measures", {
  d <- sim_calibration(n = 1500, seed = 8)
  m <- list(m = tp ~ logit_conf)
  r <- do.call(rbind, lapply(1:4, function(s) {
    compare_calibration_models(d, m, seed = s)
  }))
  expect_lt(diff(range(r$auc_mean)), 0.01)
  expect_lt(diff(range(r$logloss_mean)), 0.01)
  expect_lt(diff(range(r$brier_mean)), 0.005)
})
