#' @srrstats {G5.10} Tests that fit Stan models run only when
#'   `SHEEPDOG_EXTENDED_TESTS=true` (alias `SHEEPDOG_TEST_BRMS=true`), with
#'   the rest of the suite; the GitHub Actions workflow
#'   `extended-tests.yaml` runs them weekly and on demand.
#' @srrstats {BS7.0, BS7.1} Sampling from the prior alone
#'   (`prior_predictive_calibration()`, which ignores the verdicts)
#'   recovers the mean and standard deviation of the normal priors.
#' @srrstats {BS7.2, G5.6b} With a weakly informative prior, the posterior
#'   of data simulated from a known model covers the true intercept and
#'   slope and is centred near the maximum likelihood estimate, under two
#'   seeds.
#' @srrstats {BS7.3} Eight times more reviewed clips shrink the posterior
#'   standard deviation by about the square root of eight, and the
#'   sampling time grows less than proportionally to it.
NULL

prior_fraco <- function() {
  brms::prior_string("normal(0, 2)", class = "Intercept") +
    brms::prior_string("normal(1, 1)", class = "b")
}

test_that("sampling from the prior alone recovers the prior", {
  skip_if_not_installed("brms")
  skip_if_not_extended()
  d <- sim_calibration(n = 200, seed = 1)
  pr <- brms::prior_string("normal(0.5, 1)", class = "Intercept") +
    brms::prior_string("normal(1, 0.5)", class = "b")
  fit <- suppressMessages(prior_predictive_calibration(
    tp ~ logit_conf, d, pr, chains = 2, iter = 2000, refresh = 0, seed = 1))
  dr <- posterior::as_draws_df(fit)
  expect_equal(mean(dr$b_logit_conf), 1, tolerance = 0.08)
  expect_equal(stats::sd(dr$b_logit_conf), 0.5, tolerance = 0.1)
  # the prior on the intercept is set for centred predictors
  expect_equal(mean(dr$Intercept), 0.5, tolerance = 0.15)
  expect_equal(stats::sd(dr$Intercept), 1, tolerance = 0.1)
})

test_that("the posterior recovers a known intercept and slope", {
  skip_if_not_installed("brms")
  skip_if_not_extended()
  verifica <- function(fit, d) {
    s <- brms::fixef(fit, probs = c(0.005, 0.995))
    expect_true(s["Intercept", "Q0.5"] < -0.5 &&
                  -0.5 < s["Intercept", "Q99.5"])
    expect_true(s["logit_conf", "Q0.5"] < 1.2 &&
                  1.2 < s["logit_conf", "Q99.5"])
    mle <- stats::coef(stats::glm(tp ~ logit_conf, binomial, data = d))
    expect_equal(unname(s[, "Estimate"]), unname(mle), tolerance = 0.05)
  }
  d1 <- sim_calibration(n = 2000, a = -0.5, b = 1.2, seed = 21)
  fit <- suppressWarnings(suppressMessages(fit_calibration(
    d1, tp ~ logit_conf, engine = "brms", prior = prior_fraco(),
    chains = 2, iter = 1500, refresh = 0, seed = 1)))
  verifica(fit, d1)
  d2 <- sim_calibration(n = 2000, a = -0.5, b = 1.2, seed = 22)
  fit2 <- suppressMessages(stats::update(fit, newdata = d2, seed = 2,
                                         refresh = 0))
  verifica(fit2, d2)
})

test_that("posterior precision and sampling time scale with the data", {
  skip_if_not_installed("brms")
  skip_if_not_extended()
  pequeno <- sim_calibration(n = 500, seed = 31)
  grande <- sim_calibration(n = 4000, seed = 32)
  fit <- suppressWarnings(suppressMessages(fit_calibration(
    pequeno, tp ~ logit_conf, engine = "brms", prior = prior_fraco(),
    chains = 2, iter = 1000, refresh = 0, seed = 1)))
  # refits reuse the compiled model, so the times compare sampling only
  tempo <- function(dados) {
    t <- system.time(f <- suppressMessages(stats::update(
      fit, newdata = dados, seed = 3, refresh = 0)))[["elapsed"]]
    list(fit = f, t = t)
  }
  a <- tempo(pequeno)
  b <- tempo(grande)
  sd_a <- brms::fixef(a$fit)["logit_conf", "Est.Error"]
  sd_b <- brms::fixef(b$fit)["logit_conf", "Est.Error"]
  expect_gt(sd_a / sd_b, 2)
  expect_lt(sd_a / sd_b, 4)
  expect_lt(b$t / a$t, 8)
})
