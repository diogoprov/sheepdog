#' @srrstats {G5.4, G5.6, G5.6a, G5.6b} `fit_calibration()` recovers the
#'   intercept, slope and among-species standard deviation of data
#'   simulated from a known model (`sim_calibration()` in
#'   `helper-calibration.R`), within a tolerance of a few standard errors
#'   and under several seeds.
#' @srrstats {G5.7} The error of the estimated slope and its standard error
#'   shrink as the number of reviewed clips grows.
#' @srrstats {G5.3} Fitted and predicted probabilities have no missing or
#'   undefined values.
#' @srrstats {RE7.2} The fitted model keeps the factor levels of the input
#'   (`attr(fit, "sheepdog_levels")`), unused levels included.
#' @srrstats {RE7.3} The accessor methods of the classes returned by
#'   `fit_calibration()` (`coef()`, `vcov()`, `fitted()`, `predict()`,
#'   `residuals()`, `nobs()`, `logLik()`, `confint()`, `summary()`) work
#'   on the returned objects.
NULL

test_that("fit_calibration() recovers a known intercept and slope", {
  for (s in 1:3) {
    d <- sim_calibration(n = 3000, a = -0.5, b = 1.2, seed = s)
    fit <- suppressMessages(fit_calibration(d, tp ~ logit_conf))
    est <- stats::coef(fit)
    se <- sqrt(diag(stats::vcov(fit)))
    expect_lt(abs(est[["(Intercept)"]] - (-0.5)), 4 * se[["(Intercept)"]])
    expect_lt(abs(est[["logit_conf"]] - 1.2), 4 * se[["logit_conf"]])
  }
})

test_that("fit_calibration() recovers the fixed effects and species variation", {
  skip_if_not_installed("lme4")
  for (s in 1:3) {
    d <- sim_calibration(n = 3000, a = -0.5, b = 1.2, n_species = 12,
                         sd_species = 0.8, seed = 10 + s)
    fit <- suppressMessages(fit_calibration(d, tp ~ logit_conf +
                                              (1 | species)))
    fe <- lme4::fixef(fit)
    se <- sqrt(diag(as.matrix(stats::vcov(fit))))
    expect_lt(abs(fe[["logit_conf"]] - 1.2), 4 * se[[2]])
    expect_lt(abs(fe[["(Intercept)"]] - (-0.5)), 4 * se[[1]])
    sd_sp <- attr(lme4::VarCorr(fit)$species, "stddev")[[1]]
    # 12 species: the standard deviation is estimated loosely
    expect_gt(sd_sp, 0.3)
    expect_lt(sd_sp, 1.6)
  }
})

test_that("estimates improve as the number of reviewed clips grows", {
  erro <- function(n) {
    vapply(1:5, function(s) {
      d <- sim_calibration(n = n, b = 1.2, seed = 100 + s)
      fit <- suppressWarnings(suppressMessages(
        fit_calibration(d, tp ~ logit_conf)))
      c(abs(stats::coef(fit)[["logit_conf"]] - 1.2),
        sqrt(stats::vcov(fit)["logit_conf", "logit_conf"]))
    }, numeric(2))
  }
  pequeno <- erro(200)
  grande <- erro(3200)
  expect_lt(mean(grande[1, ]), mean(pequeno[1, ]))
  # 16 times the clips: standard error about 4 times smaller
  razao <- mean(pequeno[2, ]) / mean(grande[2, ])
  expect_gt(razao, 3)
  expect_lt(razao, 5)
})

test_that("fitted and predicted probabilities have no missing values", {
  skip_if_not_installed("lme4")
  d <- sim_calibration(n = 800, n_species = 6, sd_species = 0.5, seed = 4)
  for (f in list(tp ~ logit_conf, tp ~ logit_conf + (1 | species))) {
    fit <- suppressMessages(fit_calibration(d, f))
    p <- stats::fitted(fit)
    expect_false(anyNA(p))
    expect_true(all(is.finite(p) & p > 0 & p < 1))
    novo <- tibble::tibble(site = factor("novo"), species = factor("sp1"),
                           logit_conf = c(-3, 0, 5))
    pr <- stats::predict(fit, newdata = novo, type = "response",
                         allow.new.levels = TRUE)
    expect_false(anyNA(pr))
  }
})

test_that("the fit keeps the factor levels of the input", {
  d <- sim_calibration(n = 400, n_species = 4, seed = 5)
  d$species <- factor(d$species, levels = c(levels(d$species), "sem_dados"))
  fit <- suppressMessages(fit_calibration(d, tp ~ logit_conf))
  niveis <- attr(fit, "sheepdog_levels")
  expect_identical(niveis$species, levels(d$species))
  expect_identical(niveis$site, levels(d$site))
  d$site <- as.character(d$site)
  fit2 <- suppressMessages(fit_calibration(d, tp ~ logit_conf))
  expect_identical(attr(fit2, "sheepdog_levels")$site, sort(unique(d$site)))
})

test_that("the accessor methods work on the fitted models", {
  skip_if_not_installed("lme4")
  d <- sim_calibration(n = 600, n_species = 6, sd_species = 0.5, seed = 6)
  m_glm <- suppressMessages(fit_calibration(d, tp ~ logit_conf))
  m_mer <- suppressMessages(fit_calibration(d, tp ~ logit_conf +
                                              (1 | species)))
  expect_s3_class(m_glm, "glm")
  expect_s4_class(m_mer, "glmerMod")
  for (m in list(m_glm, m_mer)) {
    expect_identical(stats::nobs(m), nrow(d))
    expect_length(stats::fitted(m), nrow(d))
    expect_length(stats::residuals(m), nrow(d))
    expect_true(is.finite(as.numeric(stats::logLik(m))))
    v <- as.matrix(stats::vcov(m))
    expect_identical(dim(v), c(2L, 2L))
    expect_true(all(diag(v) > 0))
    expect_no_error(summary(m))
  }
  ci <- suppressMessages(stats::confint(m_glm))
  expect_true(all(ci[, 1] < stats::coef(m_glm) & stats::coef(m_glm) < ci[, 2]))
  ci_w <- stats::confint(m_mer, method = "Wald", parm = "beta_")
  expect_true(all(ci_w[, 1] < lme4::fixef(m_mer) &
                    lme4::fixef(m_mer) < ci_w[, 2]))
})
