#' @srrstats {RE3.3} `control` reaches `glm()` and `lme4::glmer()`, and
#'   a wrong control object is refused.
#' @srrstats {RE6.2} `plot_calibration(interval = TRUE)` draws pointwise
#'   bands; the interval helper covers the true slope-based P(TP) and its
#'   bounds bracket the fitted values.
#' @noRd
NULL

test_that("fit_calibration() passes `control` to glm()", {
  val <- sim_calibration(n = 400, seed = 11)
  f0 <- fit_calibration(val, tp ~ logit_conf)
  expect_equal(f0$control$maxit, 25)
  f1 <- fit_calibration(val, tp ~ logit_conf,
                        control = list(epsilon = 1e-12, maxit = 50))
  expect_identical(f1$control$maxit, 50)
  expect_identical(f1$control$epsilon, 1e-12)
  expect_equal(stats::coef(f0), stats::coef(f1), tolerance = 1e-6)
  expect_error(fit_calibration(val, tp ~ logit_conf, control = "fast"),
               "list from stats::glm.control")
  expect_error(fit_calibration(val, tp ~ logit_conf,
                               control = list(maxit = -1)),
               "maximum number of iterations")
})

test_that("fit_calibration() passes `control` to lme4::glmer()", {
  skip_if_not_installed("lme4")
  val <- sim_calibration(n = 600, sd_species = 0.8, seed = 12)
  f <- tp ~ logit_conf + (1 | species)
  def <- fit_calibration(val, f)
  expect_identical(def@optinfo$optimizer, "bobyqa")
  ctl <- lme4::glmerControl(optimizer = "Nelder_Mead")
  nm <- fit_calibration(val, f, control = ctl)
  expect_identical(nm@optinfo$optimizer, "Nelder_Mead")
  expect_equal(lme4::fixef(def), lme4::fixef(nm), tolerance = 1e-3)
  expect_error(fit_calibration(val, f, control = list(maxit = 10)),
               "glmerControl object")
  expect_error(fit_calibration(val, tp ~ logit_conf, control = ctl),
               "list from stats::glm.control")
})

test_that("fit_calibration() refuses a non-list brms control", {
  skip_if_not_installed("brms")
  val <- sim_calibration(n = 200, seed = 13)
  pr <- brms::set_prior("normal(0, 1)", class = "b")
  expect_error(fit_calibration(val, tp ~ logit_conf, engine = "brms",
                               prior = pr, control = 0.95),
               "list of sampler settings")
})

test_that("plot_calibration() draws bands with interval = TRUE", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("lme4")
  val <- sim_calibration(n = 600, sd_species = 0.8, seed = 14)
  for (f in list(tp ~ logit_conf, tp ~ logit_conf + (1 | species))) {
    fit <- suppressWarnings(fit_calibration(val, f))
    p0 <- plot_calibration(fit, val)
    p1 <- plot_calibration(fit, val, interval = TRUE, level = 0.9)
    geoms0 <- vapply(p0$layers, function(l) class(l$geom)[1], "")
    geoms1 <- vapply(p1$layers, function(l) class(l$geom)[1], "")
    expect_false("GeomRibbon" %in% geoms0)
    expect_true("GeomRibbon" %in% geoms1)
    expect_true(all(p1$data$lower <= p1$data$p_tp + 1e-12))
    expect_true(all(p1$data$upper >= p1$data$p_tp - 1e-12))
    expect_equal(p1$data$p_tp, p0$data$p_tp, tolerance = 1e-10)
  }
  expect_error(plot_calibration(fit, val, interval = "yes"), "TRUE or FALSE")
  expect_error(plot_calibration(fit, val, interval = TRUE, level = 1),
               "level")
})

test_that("the interval of a glm fit covers the true P(TP)", {
  # 200 replicate surveys; the 90% Wald band at a fixed score should cover
  # the generating P(TP) close to 90% of the time
  x0 <- tibble::tibble(species = factor("sp1"), site = factor("S1"),
                       logit_conf = stats::qlogis(0.7))
  truth <- stats::plogis(-0.5 + 1.2 * x0$logit_conf)
  cov <- vapply(seq_len(200), function(r) {
    val <- sim_calibration(n = 300, seed = 100 + r)
    fit <- stats::glm(tp ~ logit_conf, data = val, family = stats::binomial)
    b <- predict_tp_interval(fit, x0, level = 0.9)
    b$lower <= truth && truth <= b$upper
  }, logical(1))
  expect_gt(mean(cov), 0.84)
  expect_lt(mean(cov), 0.96)
})
