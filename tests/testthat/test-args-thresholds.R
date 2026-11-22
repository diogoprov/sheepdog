# Argument checks of the threshold and post-validation functions: scalars
# given as vectors, and column names that are not a single string

val_ara <- function() {
  ex <- system.file("extdata", "example", package = "sheepdog")
  read_validation_tables(file.path(ex, "validation",
                                   "validation_by_clip_ARA.csv"))
}

test_that("precision_by_bin() checks min_n", {
  expect_error(precision_by_bin(val_ara(), min_n = c(5, 10)),
               "`min_n` must be a whole number of at least 1")
})

test_that("plot_precision() checks target_precision and min_n", {
  expect_error(plot_precision(data.frame(), target_precision = c(0.8, 0.9)),
               "`target_precision` must be a number strictly between 0 and 1")
  expect_error(plot_precision(data.frame(), min_n = c(5, 10)),
               "`min_n` must be a whole number of at least 1")
})

test_that("review_support() checks min_precision", {
  expect_error(review_support(data.frame(), data.frame(),
                              min_precision = c(0.4, 0.6)),
               "`min_precision` must be a number between 0 and 1")
  expect_error(review_support(data.frame(), data.frame(),
                              min_precision = 1.5),
               "`min_precision` must be a number between 0 and 1")
})

test_that("compare_thresholds() checks tolerance and lower_prob", {
  expect_error(compare_thresholds(data.frame(), NULL,
                                  tolerance = c(0.05, 0.1)),
               "`tolerance` must be a number of at least 0")
  expect_error(compare_thresholds(data.frame(), NULL, tolerance = -0.1),
               "`tolerance` must be a number of at least 0")
  expect_error(compare_thresholds(data.frame(), NULL,
                                  lower_prob = c(0.05, 0.1)),
               "`lower_prob` must be a number strictly between 0 and 1")
})

test_that("threshold_history() checks min_detections_night", {
  expect_error(threshold_history(data.frame(), data.frame(),
                                 min_detections_night = c(1, 2)),
               "`min_detections_night` must be a whole number of at least 1")
  expect_error(threshold_history(data.frame(), data.frame(),
                                 min_detections_night = 0),
               "`min_detections_night` must be a whole number of at least 1")
})

test_that("threshold_bootstrap() checks seed", {
  expect_error(threshold_bootstrap(val_ara(), sustained = TRUE,
                                   n_boot = 2, seed = c(1, 2)),
               "`seed` must be a whole number")
  expect_error(threshold_bootstrap(val_ara(), sustained = TRUE,
                                   n_boot = 2, seed = 1.5),
               "`seed` must be a whole number")
})

test_that("threshold_by_group() checks its scalars and threshold_column", {
  val <- val_ara()
  val$month <- substr(val$recording_date, 1, 6)
  expect_error(threshold_by_group(val, 0.5, by = "month",
                                  target_precision = c(0.8, 0.9)),
               "`target_precision` must be a number strictly between 0 and 1")
  expect_error(threshold_by_group(val, 0.5, by = "month", min_n = c(5, 10)),
               "`min_n` must be a whole number of at least 1")
  expect_error(threshold_by_group(val, 0.5, by = "month",
                                  threshold_column = c("a", "b")),
               "`threshold_column` must be a single character string")
  thr <- data.frame(site = "ARA", species_folder = "x", threshold = 0.5)
  expect_error(threshold_by_group(val, thr, by = "month",
                                  threshold_column = "no_such_column"),
               "lacks the column\\(s\\): no_such_column. See `threshold_col")
  # several `by` columns are allowed
  val$hour2 <- as.integer(substr(val$recording_hour, 1, 2)) %/% 2
  expect_no_error(threshold_by_group(val, 0.5, by = c("month", "hour2"),
                                     min_n = 5))
})

test_that("recall_ceiling() checks n_boot, seed, threshold_column, cluster", {
  expect_error(recall_ceiling(data.frame(), data.frame(), n_boot = c(0, 10)),
               "`n_boot` must be a whole number of at least 0")
  expect_error(recall_ceiling(data.frame(), data.frame(), seed = c(1, 2)),
               "`seed` must be a whole number")
  expect_error(recall_ceiling(data.frame(), data.frame(),
                              threshold_column = c("a", "b")),
               "`threshold_column` must be a single character string")
  expect_error(recall_ceiling(data.frame(), data.frame(),
                              cluster = c("source_audio", "night")),
               "`cluster` must be a single character string")
  expect_error(recall_ceiling(data.frame(), data.frame(), cluster = 1),
               "`cluster` must be a single character string")
})

test_that("warning_signs() checks cluster", {
  expect_error(warning_signs(data.frame(), 0.5,
                             cluster = c("source_audio", "night")),
               "`cluster` must be a single character string")
  expect_error(warning_signs(data.frame(), 0.5, cluster = NA_character_),
               "`cluster` must be a single character string")
})

test_that("retraining_clips() returns a tibble for a data.frame input", {
  ex <- system.file("extdata", "validation_by_clip.csv", package = "sheepdog")
  val <- as.data.frame(read_validation_tables(ex))
  out <- retraining_clips(val)
  expect_s3_class(out, "tbl_df")
  expect_true(all(out$clip_file %in% val$clip_file[val$verdict == "positive"]))
})
