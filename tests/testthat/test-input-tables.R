#' @srrstats {G2.6, G2.7, G2.8, G2.11, G2.12} The entry routine of the
#'   sampling and threshold functions turns a data.frame, tibble or
#'   data.table into a tibble, drops extra classes of numeric columns and
#'   refuses list columns; the results do not depend on the input class.
#' @srrstats {G2.13, G2.14, G2.14a, G2.14b, G2.15} Rows with missing values
#'   are left out with a message, or stop with an error under
#'   `options(sheepdog.missing = "error")`, before any summary is computed.
#' @noRd
NULL

historico <- function() {
  list(
    det = data.frame(
      site = "A",
      species_code = c(rep("Boana raniceps_boa-ran", 4),
                       rep("Dendropsophus nanus_den-nan", 2)),
      confidence = c(0.9, 0.8, 0.3, 0.75, 0.95, 0.05),
      begin_path = c("x/A_20240110_200000.wav", "x/A_20240110_210000.wav",
                     "x/A_20240111_200000.wav", "x/A_20240112_020000.wav",
                     "x/A_20240113_200000.wav", "x/A_20240114_200000.wav")),
    thr = data.frame(site = "A", species_folder = "boa_ran", threshold = 0.7))
}

test_that("as_input_table() converts tables and drops extra classes", {
  df <- data.frame(confidence = c(0.2, 0.8), verdict = c("positive", "negative"))
  df$confidence <- structure(df$confidence, class = "units_like")
  out <- as_input_table(df, c("verdict", "confidence"), "x",
                        numeric = "confidence")
  expect_s3_class(out, "tbl_df")
  expect_identical(class(out$confidence), "numeric")
  df$verdict <- I(list("positive", "negative"))
  expect_error(as_input_table(df, c("verdict", "confidence"), "x"),
               "are list columns")
  expect_error(as_input_table(df, "begin_path", "x"), "lacks the column")
  expect_error(as_input_table(1:3, "a", "x"), "must be a data frame")
  bad <- data.frame(confidence = c("a", "b"))
  expect_error(as_input_table(bad, "confidence", "x", numeric = "confidence"),
               "must be numeric")
})

test_that("threshold functions give the same result for any table class", {
  val <- withr::with_seed(5, {
    conf <- stats::runif(600, 0.1, 0.99)
    tp <- stats::rbinom(600, 1, stats::plogis(-1 + 1.2 * stats::qlogis(conf)))
    data.frame(site = rep(c("A", "B"), each = 300), species_folder = "sp",
               confidence = conf,
               verdict = ifelse(tp == 1, "positive", "negative"))
  })
  ref <- suggest_thresholds(val)
  expect_equal(suggest_thresholds(tibble::as_tibble(val)), ref)
  u <- val
  u$confidence <- structure(u$confidence, class = "units_like")
  expect_equal(suggest_thresholds(u), ref)
  expect_equal(precision_by_bin(u), precision_by_bin(val))
  skip_if_not_installed("data.table")
  expect_equal(suggest_thresholds(data.table::as.data.table(val)), ref)
  l <- val
  l$confidence <- as.list(l$confidence)
  expect_error(suggest_thresholds(l), "list columns")
})

test_that("threshold_history() accepts any table class and units", {
  d <- historico()
  ref <- suppressMessages(threshold_history(d$det, d$thr))
  u <- d$det
  u$confidence <- structure(u$confidence, class = "units_like")
  expect_equal(suppressMessages(threshold_history(u, d$thr)), ref)
  skip_if_not_installed("data.table")
  expect_equal(suppressMessages(
    threshold_history(data.table::as.data.table(d$det), d$thr)), ref)
})

test_that("missing values follow the sheepdog.missing option", {
  d <- historico()
  d$det$confidence[3] <- NA
  expect_message(h <- threshold_history(d$det, d$thr),
                 "1 row\\(s\\) of `detections` with missing values in confidence")
  expect_false(anyNA(h$confidence_max))
  withr::local_options(sheepdog.missing = "error")
  expect_error(threshold_history(d$det, d$thr),
               "`detections` has 1 row\\(s\\) with missing values")
  withr::local_options(sheepdog.missing = "impute")
  expect_error(threshold_history(d$det, d$thr), "must be \"omit\" or \"error\"")
})

test_that("calibration fits follow the sheepdog.missing option", {
  val <- sim_calibration(n = 200, seed = 3)
  val$logit_conf[1:2] <- NA
  expect_message(fit_calibration(val, tp ~ logit_conf),
                 "2 row\\(s\\) of `validations` with missing values")
  withr::local_options(sheepdog.missing = "error")
  expect_error(fit_calibration(val, tp ~ logit_conf),
               "`validations` has 2 row\\(s\\) with missing values")
})

test_that("reviewed clips without a confidence are missing only outside whole recordings", {
  val <- tibble::tibble(
    site = "A", species_folder = "sp",
    verdict = c("positive", "negative", "positive", "positive"),
    confidence = c(0.9, 0.2, NA, NA),
    sampling_mode = c("top", "top", "random_recordings", "top"))
  expect_message(r <- reviewed_with_confidence(val),
                 "1 row\\(s\\) of `validation` with missing values")
  expect_identical(nrow(r), 2L)
  # without sampling_mode a missing confidence marks a whole recording
  expect_silent(r2 <- reviewed_with_confidence(val[-5]))
  expect_identical(nrow(r2), 2L)
  withr::local_options(sheepdog.missing = "error")
  expect_error(reviewed_with_confidence(val), "with missing values")
  expect_silent(reviewed_with_confidence(val[1:3, ]))
})
