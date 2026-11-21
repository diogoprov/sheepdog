#' @srrstats {G5.2} Errors and warnings without a test elsewhere are
#'   triggered here and matched against their text (every error and
#'   warning of the package is now matched by a test).
#'   `dev/ropensci-stats/conditions.R` lists every condition of the package
#'   and whether a test matches it.
#' @srrstats {G5.2a} Each condition message is raised from one place:
#'   shared checks (`check_columns()`, `check_data_frame()`,
#'   `check_brmsfit()`, `check_reviewed()`) give the messages common to
#'   several functions.
NULL

test_that("the shared checks give one message for each condition", {
  expect_error(check_columns(data.frame(a = 1), c("a", "b", "c"), "tab"),
               "^`tab` lacks the column\\(s\\): b, c\\.$")
  expect_error(check_columns(data.frame(a = 1), "b", "tab", hint = "Dica."),
               "lacks the column\\(s\\): b\\. Dica\\.$")
  expect_silent(check_columns(data.frame(a = 1), "a", "tab"))
  expect_error(check_data_frame(list(a = 1), "units"),
               "`units` must be a data frame")
  expect_error(check_brmsfit(lm(1 ~ 1)), "must be a model fitted with engine")
  expect_error(check_reviewed(data.frame()), "No reviewed clip with a")
  expect_error(stop_without_inclusion_prob(), "needs `inclusion_prob`")
  expect_error(require_suggested("pacoteinexistente123", "for a test"),
               "Package 'pacoteinexistente123' is needed for a test")
})

test_that("calibration functions report folds that failed", {
  d <- sim_calibration(n = 400, seed = 1)
  d$cte <- factor("a")
  calls <- 0L
  local_mocked_bindings(fit_model = function(formula, dados, quiet = TRUE) {
    calls <<- calls + 1L
    if (calls == 1L) stop("falha simulada")
    stats::glm(formula, data = dados, family = stats::binomial)
  })
  expect_warning(calibration_quality(d, tp ~ logit_conf, k_folds = 3,
                                     min_class = 1),
                 "The fit failed in 1 of 3 folds, left out of the measures")
})

test_that("score_detections() warns about tables it cannot read", {
  fit <- suppressMessages(fit_calibration(sim_calibration(n = 300, seed = 2),
                                          tp ~ logit_conf))
  vazio <- withr::local_tempdir()
  expect_warning(suppressMessages(score_detections(c(S1 = vazio), fit)),
                 "No table read for S1")
})

test_that("plot_calibration_ppc() names the checks that exist", {
  skip_if_not_installed("ggplot2")
  ppc <- tibble::tibble(check = c("overall", "score"))
  expect_error(plot_calibration_ppc(ppc, check = "site"),
               "No check \"site\" in `ppc`; available: overall, score")
})

test_that("occasion covariates are checked against occasions.csv", {
  oc <- tibble::tibble(site = "A", occasion_id = c("o1", "o2"), night = "1")
  expect_error(check_calibration_keys(NULL, c("month", "month")),
               "`calibration_keys` must be distinct column names")
  expect_error(join_occasion_covariates(
    oc, tibble::tibble(site = "A", occasion_id = "o1", night = "2"),
    NULL, NULL),
    "has column\\(s\\) named like those of occasions.csv: night")
  expect_error(join_occasion_covariates(
    oc, tibble::tibble(site = "A", occasion_id = "o1"), NULL, NULL),
    "`occasion_covariates` has no covariate column")
  expect_warning(out <- join_occasion_covariates(
    oc, tibble::tibble(site = "A", occasion_id = c("o1", "o9"), temp = 1:2),
    NULL, NULL),
    "1 row\\(s\\) of `occasion_covariates` match no occasion")
  expect_identical(out$temp, c(1L, NA))
})

test_that("occasion_draws() checks the calibration keys and the occasions", {
  skip_if_not_installed("arrow")
  dir <- withr::local_tempdir()
  file.copy(list.files(test_path("fixtures", "export-1.2"),
                       full.names = TRUE), dir)
  sc <- jsonlite::read_json(file.path(dir, "schema.json"))
  sc$calibration$keys <- c(unlist(sc$calibration$keys), "habitat")
  jsonlite::write_json(sc, file.path(dir, "schema.json"), auto_unbox = TRUE,
                       pretty = TRUE, digits = NA)
  expect_error(occasion_draws(dir, n_draws = 2, write = FALSE),
               "Calibration key `habitat` is not a column of occasions.csv")

  file.copy(list.files(test_path("fixtures", "export-1.2"),
                       full.names = TRUE), dir, overwrite = TRUE)
  oc <- readr::read_csv(file.path(dir, "occasions.csv"),
                        col_types = readr::cols(.default = "c"))
  det <- readr::read_csv(file.path(dir, "detections.csv"),
                         col_types = readr::cols(.default = "c"))
  fora <- det$occasion_id[1]
  readr::write_csv(oc[oc$occasion_id != fora, ], file.path(dir,
                                                           "occasions.csv"),
                   na = "")
  w <- testthat::capture_warnings(occasion_draws(dir, n_draws = 2,
                                                 write = FALSE))
  expect_true(any(grepl("are not in occasions.csv and were left out", w)))
})

test_that("review and sampling helpers stop on empty or incomplete input", {
  vazio <- withr::local_tempdir()
  man <- file.path(vazio, "manifest.csv")
  readr::write_csv(tibble::tibble(clip_file = "a.wav", species_folder = "x"),
                   man)
  expect_error(classify_review(man, vazio), "No .wav found in")
  expect_error(split_by_reviewer(tibble::tibble(clip_file = "a.wav"),
                                 vazio, vazio),
               "`manifest` lacks the column\\(s\\): reviewer, second_reviewer")
  expect_error(read_previous(tibble::tibble(site = "A")),
               "`previous` lacks the column\\(s\\)")
  expect_error(get_recordings(tibble::tibble(site = "A"),
                              tibble::tibble(site = character(),
                                             source_audio = character()),
                              "[.]wav$", NULL, NULL),
               "No recording found")
  df <- tibble::tibble(recording_hour = c("10", "11"),
                       hour_int = c(10L, 11L),
                       recording_date = "20240101", night = "20240101")
  expect_error(suppressMessages(filter_time(
    df, list(hour_start = 20, hour_end = 22), "predictions")),
    "No predictions within the hour window")
  expect_error(suppressMessages(filter_time(
    df, list(date_start = "20250101"), "predictions")),
    "No predictions within the date window")
  expect_error(threshold_bootstrap(
    tibble::tibble(site = "A", species_folder = "x", verdict = "positive",
                   confidence = 0.5, source_audio = "a"),
    cluster = c("a", "b")),
    "`cluster` must be the name of one column")
})

test_that("read_validations() tells empty files from clips without a verdict", {
  d <- withr::local_tempdir()
  expect_error(suppressWarnings(read_validations(file.path(d, "nada.csv"))),
               "No reviewed clip found in `files`")
  ex <- system.file("extdata", "example", "validation", package = "sheepdog")
  tab <- readr::read_csv(list.files(ex, full.names = TRUE)[1],
                         show_col_types = FALSE)
  tab$verdict <- "uncertain"
  f <- file.path(d, "v.csv")
  readr::write_csv(tab, f)
  expect_error(suppressMessages(read_validations(f)),
               "No clip of `files` has a verdict \\(positive or negative\\)")
})

test_that("calibration_sensitivity() needs a brms fit", {
  expect_error(calibration_sensitivity(stats::lm(1 ~ 1)),
               "must be a model fitted with engine")
})
