#' @srrstats {G2.0, G2.2} Scalar arguments reject vectors and values out of
#'   range.
#' @srrstats {G2.16} Confidence scores with NaN, Inf or values outside 0 to
#'   1 raise an error.
#' @srrstats {G4.0} Output file names get the expected extension.
#' @srrstats {G3.0} Floating-point comparisons use `dplyr::near()`; see
#'   `recall_ceiling.R`, `reviewers.R` and `select_clips.R`.
#' @srrstats {G2.9} `read_validations()` reports clips left out for a
#'   missing score and bounded scores, and `check_validations()` reports
#'   ordered factors used as unordered.
#' @srrstats {BS2.6} `calibration_diagnostics()`, `history_draws()`,
#'   `score_detections()`, `calibration_ppc()` and
#'   `plot_calibration_draws()` check their computational parameters.
#' @srrstats {BS7.4a} `calibration_prior()` warns, and a test checks, when
#'   a covariate with the normal(0, 1) prior is not standardised.
NULL

ex_validations <- function() {
  ex <- system.file("extdata", "example", package = "sheepdog")
  suppressMessages(read_validations(list.files(file.path(ex, "validation"),
                                               full.names = TRUE)))
}

test_that("check_number() and check_prob() reject vectors and bad values", {
  expect_silent(check_number(2, "x", lower = 1, integer = TRUE))
  expect_error(check_number(c(1, 2), "x"), "`x` must be a number")
  expect_error(check_number(NA_real_, "x"), "single value")
  expect_error(check_number(Inf, "x"), "single value")
  expect_error(check_number("1", "x"), "single value")
  expect_error(check_number(1.5, "x", integer = TRUE), "whole number")
  expect_error(check_number(0, "x", lower = 1), "of at least 1")
  expect_error(check_prob(1.2, "p"), "between 0 and 1")
  expect_error(check_prob(1, "p", open = TRUE), "strictly between 0 and 1")
  expect_silent(check_prob(NULL, "p", null_ok = TRUE))
  expect_error(check_flag(NA, "f"), "TRUE or FALSE")
})

test_that("check_confidence() rejects NaN, Inf and values outside 0 to 1", {
  expect_silent(check_confidence(c(0, 0.5, 1, NA)))
  expect_error(check_confidence(c(0.5, NaN)), "NaN or infinite")
  expect_error(check_confidence(c(0.5, Inf)), "NaN or infinite")
  expect_error(check_confidence(c(0.5, 1.5)), "1 value\\(s\\) outside 0 to 1")
  expect_error(check_confidence(c("0.5")), "must be numeric")
})

test_that("check_validations() standardises the table of reviewed clips", {
  val <- ex_validations()
  df <- as.data.frame(val)
  df$site <- as.character(df$site)
  df$tp <- df$tp == 1L
  df$logit_conf <- structure(df$logit_conf, class = "units_like")
  out <- check_validations(df)
  expect_s3_class(out, "tbl_df")
  expect_true(is.factor(out$site))
  expect_identical(class(out$logit_conf), "numeric")
  expect_type(out$tp, "integer")

  df2 <- as.data.frame(val)
  df2$species <- factor(df2$species, ordered = TRUE)
  expect_message(out2 <- check_validations(df2), "ordered factor")
  expect_false(is.ordered(out2$species))

  expect_error(check_validations(as.list(val)), "must be a data frame")
  expect_error(check_validations(val[0, ]), "has no rows")
  expect_error(check_validations(dplyr::select(val, -tp)),
               "lacks the column\\(s\\) tp")
  bad <- val
  bad$tp[1] <- 2L
  expect_error(check_validations(bad), "must be 0 \\(false positive\\)")
  bad <- val
  bad$logit_conf[1] <- Inf
  expect_error(check_validations(bad), "NaN or infinite")
  bad <- val
  bad$site <- as.list(as.character(bad$site))
  expect_error(check_validations(bad), "list columns")
  bad <- val
  bad$site <- seq_len(nrow(bad))
  expect_error(check_validations(bad), "must be a factor or a character")
})

test_that("fit_calibration() checks its input before fitting", {
  val <- ex_validations()
  f <- tp ~ logit_conf
  expect_error(fit_calibration(val, "tp ~ logit_conf"), "two-sided formula")
  expect_error(fit_calibration(val, verdict ~ logit_conf),
               "response of `formula` must be `tp`")
  expect_error(fit_calibration(dplyr::mutate(val, tp = 1L), f),
               "same verdict")
  colin <- dplyr::mutate(val, dobro = 2 * logit_conf)
  expect_error(fit_calibration(colin, tp ~ logit_conf + dobro), "collinear")

  na <- val
  na$logit_conf[1:3] <- NA
  expect_message(fit <- fit_calibration(na, f), "3 row\\(s\\) of `validations`")
  expect_identical(stats::nobs(fit), nrow(val) - 3L)

  sep <- withr::with_seed(1, dplyr::mutate(
    val, logit_conf = ifelse(tp == 1L, 2, -2) +
      stats::runif(dplyr::n(), -0.1, 0.1)))
  w <- testthat::capture_warnings(suppressMessages(fit_calibration(sep, f)))
  expect_true(any(grepl("completely separated", w)))
})

test_that("fit_calibration(engine = 'brms') checks the class of the prior", {
  skip_if_not_installed("brms")
  val <- ex_validations()
  expect_error(fit_calibration(val, tp ~ logit_conf, engine = "brms",
                               prior = "normal(0, 1)"),
               "must be a brmsprior")
})

test_that("calibration_prior() warns about unstandardised covariates", {
  skip_if_not_installed("brms")
  val <- ex_validations()
  val$temp <- seq(20, 30, length.out = nrow(val))
  expect_warning(calibration_prior(tp ~ logit_conf + temp, val),
                 "temp are not")
  val$temp_z <- as.numeric(scale(val$temp))
  expect_no_warning(calibration_prior(tp ~ logit_conf + temp_z, val))
})

test_that("read_validations() reports clips without a score and rejects bad scores", {
  d <- withr::local_tempdir()
  ex <- system.file("extdata", "example", package = "sheepdog")
  tab <- readr::read_csv(list.files(file.path(ex, "validation"),
                                    full.names = TRUE)[1],
                         show_col_types = FALSE)
  tab$confidence[1] <- NA
  tab$verdict[1] <- "positive"
  f <- file.path(d, "v.csv")
  readr::write_csv(tab, f)
  msgs <- testthat::capture_messages(read_validations(f))
  expect_true(any(grepl("1 reviewed clip\\(s\\) without a confidence", msgs)))

  tab$confidence[2] <- 1.3
  readr::write_csv(tab, f)
  expect_error(suppressMessages(read_validations(f)), "outside 0 to 1")
})

test_that("score_detections() checks its arguments", {
  fit <- structure(list(), sheepdog_levels = list(species = "a", site = "A"))
  expect_error(score_detections("x.txt", fit), "named by site")
  expect_error(score_detections(c(A = "x.txt"), fit, p_min = 2), "`p_min`")
  expect_error(score_detections(c(A = "x.txt"), fit, grid_step = 0),
               "`grid_step`")
  expect_error(score_detections(c(A = "x.txt"), fit, dawn_hour = c(1, 2)),
               "`dawn_hour`")
})

test_that("check_file_ext() adds a missing extension and warns on another", {
  expect_message(p <- check_file_ext("out", "csv"), "no extension")
  expect_identical(p, "out.csv")
  expect_identical(check_file_ext("out.CSV", "csv"), "out.CSV")
  expect_warning(p <- check_file_ext("out.txt", "md"), "does not end in .md")
  expect_identical(p, "out.txt")
  expect_error(check_file_ext(c("a", "b"), "csv"), "single file path")
})

test_that("list_recordings() adds .csv to the output file", {
  d <- withr::local_tempdir()
  dir.create(file.path(d, "A"))
  file.create(file.path(d, "A", "A01_20240101_200000.wav"))
  expect_message(list_recordings(d, file = file.path(d, "rec")),
                 "no extension")
  expect_true(file.exists(file.path(d, "rec.csv")))
})

test_that("the remaining branches of the shared checks raise their messages", {
  val <- ex_validations()
  expect_error(check_number(5, "x", upper = 3), "of at most 3")
  bad <- val
  bad$logit_conf <- as.character(bad$logit_conf)
  expect_error(check_validations(bad), "`logit_conf` of `validations` must be numeric")
  bad <- val
  bad$confidence[1] <- 2
  expect_error(check_validations(bad, cols = c("site", "species", "tp",
                                               "confidence")),
               "outside 0 to 1")
  expect_error(suppressMessages(drop_missing(
    dplyr::mutate(val, logit_conf = NA_real_), "logit_conf")),
               "No row of `validations` is complete")
  expect_identical(deparse1(fixed_formula(tp ~ (1 | species))), "tp ~ 1")

  um <- dplyr::mutate(val, tp = ifelse(species == levels(species)[1], 1L, tp))
  msgs <- testthat::capture_messages(suppressWarnings(
    fit_calibration(um, tp ~ logit_conf)))
  expect_true(any(grepl("single verdict class", msgs)))

  expect_error(compare_calibration_models(val, list(tp ~ logit_conf)),
               "named list of formulas")
})

test_that("Bayesian helpers check their computational parameters", {
  fit <- structure(list(), class = "brmsfit")
  expect_error(calibration_diagnostics(fit, rhat_max = 0.9), "`rhat_max`")
  expect_error(calibration_diagnostics(fit, ess_min = -1), "`ess_min`")
  expect_error(history_draws(fit, scored = NULL, p_min = 2), "`p_min`")
  expect_error(history_draws(fit, scored = NULL, n_draws = 0), "`n_draws`")
  expect_error(history_draws(fit, scored = NULL, grid_step = 1), "`grid_step`")
  expect_error(history_draws(fit, scored = NULL, seed = 1.5), "`seed`")
  skip_if_not_installed("ggplot2")
  expect_error(plot_calibration_draws(fit, n_draws = 0), "`n_draws`")
  expect_error(plot_calibration_draws(fit, p_min = -1), "`p_min`")
  expect_error(plot_calibration_draws(fit, seed = NA), "`seed`")
})

test_that("check_string() accepts one non-empty string only", {
  expect_silent(check_string("a", "x"))
  expect_silent(check_string(NULL, "x", null_ok = TRUE))
  for (bad in list(c("a", "b"), NA_character_, "", 1, NULL)) {
    expect_error(check_string(bad, "x"),
                 "`x` must be a single character string")
  }
})
