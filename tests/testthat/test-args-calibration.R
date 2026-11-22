# Argument checks of the calibration functions (single values, flags and
# column names), found by autotest. None of these tests fits a Stan model.

ex_dir <- function() system.file("extdata", "example", package = "sheepdog")

ex_val <- function() {
  files <- list.files(file.path(ex_dir(), "validation"), full.names = TRUE)
  suppressMessages(read_validations(files))
}

test_that("calibrate() rejects vectors and non-flags in scalar arguments", {
  tab <- c(A = "a.txt")
  expect_error(calibrate("x.csv", tab, c("a", "b")),
               "`output_dir` must be a single character string")
  expect_error(calibrate("x.csv", tab, "out", min_confidence = c(0.1, 0.2)),
               "`min_confidence` must be a number between 0 and 1")
  expect_error(calibrate("x.csv", tab, "out", p_min = c(0.9, 0.95)),
               "`p_min` must be a number between 0 and 1")
  expect_error(calibrate("x.csv", tab, "out", min_detections_night = 1:2),
               "`min_detections_night` must be a whole number")
  expect_error(calibrate("x.csv", tab, "out", dawn_hour = c(12, 13)),
               "`dawn_hour` must be a number between 0 and 24")
  expect_error(calibrate("x.csv", tab, "out", k_folds = c(3, 5)),
               "`k_folds` must be a whole number of at least 2")
  expect_error(calibrate("x.csv", tab, "out", uncorrelated = 1L),
               "`uncorrelated` must be TRUE or FALSE")
  expect_error(calibrate("x.csv", tab, "out", effort_curve = "a"),
               "`effort_curve` must be TRUE or FALSE")
  expect_error(calibrate("x.csv", tab, "out", effort_curve = c(TRUE, FALSE)),
               "`effort_curve` must be TRUE or FALSE")
  expect_error(calibrate("x.csv", tab, "out", effort_reps = c(10, 20)),
               "`effort_reps` must be a whole number of at least 1")
  expect_error(calibrate("x.csv", tab, "out", prob_min = c(0.8, 0.9)),
               "`prob_min` must be a number between 0 and 1")
  expect_error(calibrate("x.csv", tab, "out", seed = c(1, 2)),
               "`seed` must be a whole number")
})

test_that("calibration_models() needs TRUE or FALSE flags", {
  expect_error(calibration_models(uncorrelated = 1L),
               "`uncorrelated` must be TRUE or FALSE")
  expect_error(calibration_models(single_species = "a"),
               "`single_species` must be TRUE or FALSE")
})

test_that("calibration_folds() needs a single seed", {
  val <- data.frame(site = "A", species = "x", tp = 1)
  expect_error(calibration_folds(val, seed = c(1, 2)),
               "`seed` must be a whole number")
})

test_that("select_calibration_model() needs a single k_folds", {
  expect_error(select_calibration_model(data.frame(), k_folds = c(5, 5)),
               "`k_folds` must be a whole number of at least 2")
})

test_that("detection_history() needs single thresholds", {
  scored <- data.frame(site = "A", species = "x", night = "20250101",
                       p_tp = 0.99)
  expect_error(detection_history(scored, p_min = c(0.9, 0.95)),
               "`p_min` must be a number between 0 and 1")
  expect_error(detection_history(scored, min_detections_night = c(1, 2)),
               "`min_detections_night` must be a whole number")
  expect_error(detection_history(scored, prob_min = c(0.8, 0.9)),
               "`prob_min` must be a number between 0 and 1")
})

test_that("plot_calibration() needs a single p_min and model_name", {
  skip_if_not_installed("ggplot2")
  expect_error(plot_calibration(NULL, NULL, p_min = c(0.9, 0.95)),
               "`p_min` must be a number between 0 and 1")
  expect_error(plot_calibration(NULL, NULL, model_name = c("a", "b")),
               "`model_name` must be a single character string")
})

test_that("calibrated_thresholds() checks lower_prob and keeps tibbles", {
  val <- ex_val()
  fit <- fit_calibration(val, tp ~ logit_conf + species)
  expect_error(calibrated_thresholds(fit, lower_prob = c(0.05, 0.1)),
               "`lower_prob` must be a number strictly between 0 and 1")
  expect_error(calibrated_thresholds(fit, scored = list(site = "A")),
               "`scored` must be a data frame")
  expect_error(calibrated_thresholds(fit, cells = "A"),
               "`cells` must be a data frame")
  cells <- data.frame(site = levels(val$site)[1:2],
                      species = levels(val$species)[1:2])
  thr_df <- calibrated_thresholds(fit, cells = cells)
  thr_tb <- calibrated_thresholds(fit, cells = tibble::as_tibble(cells))
  expect_s3_class(thr_df, "tbl_df")
  expect_identical(thr_df, thr_tb)
  expect_null(names(thr_df$p_tp_at_threshold))
  skip_if_not_installed("data.table")
  thr_dt <- calibrated_thresholds(fit,
                                  cells = data.table::as.data.table(cells))
  expect_identical(thr_df, thr_dt)
})

test_that("compare_calibration_curves() needs single tuning values", {
  v <- data.frame(verdict = "positive", confidence = 0.9,
                  species_folder = "x")
  expect_error(compare_calibration_curves(v, k = c(5, 6)),
               "`k` must be a whole number of at least 1")
  expect_error(compare_calibration_curves(v, cluster = c("a", "b")),
               "`cluster` must be a single character string")
  expect_error(compare_calibration_curves(v, max_error = c(0.03, 0.05)),
               "`max_error` must be a number of at least 0")
  expect_error(compare_calibration_curves(v, tolerance = c(0.03, 0.05)),
               "`tolerance` must be a number of at least 0")
  expect_error(compare_calibration_curves(v, seed = c(1, 2)),
               "`seed` must be a whole number")
})

test_that("plot_calibration_curves() needs a single bin_width", {
  skip_if_not_installed("ggplot2")
  expect_error(plot_calibration_curves(data.frame(), bin_width = c(0.1, 0.2)),
               "`bin_width` must be a number strictly between 0 and 1")
})

test_that("calibration_quality() needs single limits and seed", {
  val <- ex_val()
  f <- tp ~ logit_conf + species
  expect_error(calibration_quality(val, f, seed = c(1, 2)),
               "`seed` must be a whole number")
  expect_error(calibration_quality(val, f, auc_min = c(0.6, 0.7)),
               "`auc_min` must be a number between 0 and 1")
  expect_error(calibration_quality(val, f, intercept_max = c(1, 2)),
               "`intercept_max` must be a number of at least 0")
})

test_that("community_matrices_draws() needs a single min_nights_month", {
  h <- data.frame(draw = 1, site = "A", species = "x", night = "20250101",
                  detection_k1 = 1, detection_k2 = 0, detection_k3 = 0)
  expect_error(community_matrices_draws(h, "x", min_nights_month = c(5, 6)),
               "`min_nights_month` must be a number of at least 0")
})
