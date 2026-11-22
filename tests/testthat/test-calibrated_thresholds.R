example_validations <- function() {
  ex <- system.file("extdata", "example", "validation", package = "sheepdog")
  suppressMessages(read_validations(list.files(ex, full.names = TRUE)))
}

test_that("first_sustained() finds where a curve stays above the target", {
  fs <- sheepdog:::first_sustained
  expect_identical(fs(c(0.5, 0.96, 0.8, 0.97, 0.98), 0.95), 4L)
  expect_identical(fs(c(0.96, 0.97), 0.95), 1L)
  expect_identical(fs(c(0.96, 0.90), 0.95), NA_integer_)
  # pontos sem deteccoes (NA) nao contam
  expect_identical(fs(c(0.5, 0.96, NA, 0.97, NA), 0.95), 2L)
  expect_identical(fs(c(NA, NA), 0.95), NA_integer_)
})

test_that("the probability rule inverts a global logistic calibration", {
  val <- example_validations()
  fit <- fit_calibration(val, calibration_models()$m0_global)
  thr <- calibrated_thresholds(fit, target = 0.9, grid_step = 0.01)
  expect_identical(nrow(thr), length(levels(val$site)) *
                     length(levels(val$species)))
  # sem efeitos aleatorios, o limiar e o mesmo em todas as celulas e e o
  # primeiro ponto da grade acima da inversa da curva logistica
  b <- stats::coef(fit)
  analitico <- stats::plogis((stats::qlogis(0.9) - b[1]) / b[2])
  expect_true(all(thr$threshold == thr$threshold[1]))
  expect_gte(thr$threshold[1], analitico - 1e-8)
  expect_lt(thr$threshold[1] - analitico, 0.01 + 1e-8)
  expect_true(all(thr$p_tp_at_threshold >= 0.9))
  expect_false("threshold_lower" %in% names(thr))
})

test_that("a target the calibration never reaches gives NA", {
  val <- example_validations()
  fit <- fit_calibration(val, calibration_models()$m0_global)
  thr <- calibrated_thresholds(fit, target = 0.999999)
  expect_true(all(is.na(thr$threshold)))
})

test_that("species effects give different thresholds per species", {
  skip_if_not_installed("lme4")
  val <- example_validations()
  fit <- fit_calibration(val, calibration_models()$m2_species_slope)
  thr <- calibrated_thresholds(fit, target = 0.9,
                               cells = data.frame(site = "ARA",
                                                  species = levels(val$species)))
  expect_identical(nrow(thr), length(levels(val$species)))
  expect_gt(length(unique(stats::na.omit(thr$threshold))), 1)
})

test_that("cells outside the calibration are thresholded with a warning", {
  val <- example_validations()
  fit <- fit_calibration(val, calibration_models()$m0_global)
  expect_warning(
    thr <- calibrated_thresholds(fit, cells = data.frame(site = "NOVO",
                                                         species = "boa_ran")),
    "not in the calibration")
  expect_identical(nrow(thr), 1L)
  expect_error(calibrated_thresholds(fit, cells = data.frame(site = "ARA")),
               "species")
  expect_error(calibrated_thresholds(fit, target = 1), "between 0 and 1")
})

test_that("the precision rule averages P(TP) above each candidate", {
  val <- example_validations()
  fit <- fit_calibration(val, calibration_models()$m0_global)
  scored <- tibble::tibble(
    site = "ARA", species = "boa_ran",
    confidence = c(0.2, 0.4, 0.6, 0.8, 0.95),
    p_tp       = c(0.1, 0.5, 0.9, 1.0, 1.0))
  thr <- calibrated_thresholds(fit, target = 0.9, rule = "precision",
                               scored = scored, grid_step = 0.1)
  # acima de 0.4: (0.5 + 0.9 + 1 + 1) / 4 = 0.85; acima de 0.5: 0.967
  expect_equal(thr$threshold, 0.5)
  expect_equal(thr$precision_at_threshold, (0.9 + 1 + 1) / 3)
  expect_identical(thr$n_above, 3L)
  expect_identical(thr$n_detections, 5L)
  expect_error(calibrated_thresholds(fit, rule = "precision"), "scored")
  expect_error(calibrated_thresholds(fit, rule = "precision",
                                     scored = scored[, 1:3]), "p_tp")
})

test_that("the precision threshold is not above the probability one", {
  val <- example_validations()
  fit <- fit_calibration(val, calibration_models()$m0_global)
  conf <- seq(0.1, 0.99, by = 0.01)
  scored <- tibble::tibble(
    site = "ARA", species = "boa_ran", confidence = conf,
    p_tp = sheepdog:::predict_tp(fit, data.frame(
      logit_conf = sheepdog:::safe_logit(conf))))
  p <- calibrated_thresholds(fit, target = 0.9, scored = scored)
  q <- calibrated_thresholds(fit, target = 0.9, rule = "precision",
                             scored = scored)
  expect_identical(nrow(p), 1L)
  expect_lte(q$threshold, p$threshold)
})

test_that("the brms backend adds a conservative threshold", {
  skip_if_not_installed("brms")
  skip_if_not_extended()
  val <- example_validations()
  f <- tp ~ logit_conf + (1 | species)
  fit <- suppressWarnings(fit_calibration(
    val, f, engine = "brms", prior = calibration_prior(f, val),
    chains = 2, iter = 1000, refresh = 0, seed = 1))
  thr <- calibrated_thresholds(fit, target = 0.9,
                               cells = data.frame(site = "ARA",
                                                  species = "boa_ran"))
  expect_true("threshold_lower" %in% names(thr))
  expect_gte(thr$threshold_lower, thr$threshold)
})
