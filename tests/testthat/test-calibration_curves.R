# compare_calibration_curves(): a logistica contra curvas flexiveis

# Clipes revisados simulados: P(TP) logistica no logito do score
# ("certa") ou que estaciona abaixo de 0.95 ("teto")
sim_curvas <- function(n = 400, forma = "certa", seed = 1) {
  withr::with_seed(seed, {
    conf <- stats::runif(n, 0.1, 0.999)
    x <- stats::qlogis(conf)
    p <- switch(forma,
                certa = stats::plogis(-0.5 + 1.6 * x),
                teto = 0.85 * stats::plogis(1 + 2 * x))
    tibble::tibble(
      site = "A", species_folder = forma,
      source_audio = paste0("rec", sample(60, n, replace = TRUE), ".wav"),
      confidence = conf,
      verdict = ifelse(stats::rbinom(n, 1, p) == 1, "positive", "negative"),
      inclusion_prob = 0.5)
  })
}

test_that("a right logistic is kept, and a curve that levels off is not", {
  skip_if_not_installed("mgcv")
  val <- dplyr::bind_rows(sim_curvas(600, "certa"), sim_curvas(600, "teto"))
  cmp <- suppressMessages(compare_calibration_curves(
    val, target = 0.95, curves = c("logistic", "quadratic", "gam")))
  expect_setequal(unique(cmp$curve), c("logistic", "quadratic", "gam"))
  expect_true(all(c("cv_logloss", "top_error", "threshold_p_tp",
                    "threshold_precision", "threshold_weighted",
                    "verdict") %in% names(cmp)))
  certa <- cmp[cmp$species_folder == "certa", ]
  teto <- cmp[cmp$species_folder == "teto", ]
  expect_identical(unique(certa$verdict), "keep_logistic")
  expect_lt(abs(certa$diff_weighted[certa$curve == "logistic"]), 0.03)
  expect_identical(unique(teto$verdict), "no_curve_reaches_target")
  expect_false(any(teto$reaches_target[teto$curve != "logistic"]))
  expect_true(all(is.na(teto$threshold_weighted)))
  # curvas e faixas para o grafico
  expect_true(all(c("species_folder", "curve", "score", "p_tp") %in%
                    names(attr(cmp, "curves"))))
  expect_gt(nrow(attr(cmp, "bins")), 0)
  # a mesma semente da as mesmas dobras
  cmp2 <- suppressMessages(compare_calibration_curves(
    val, target = 0.95, curves = c("logistic", "quadratic", "gam")))
  expect_identical(cmp$cv_logloss, cmp2$cv_logloss)
})

test_that("the logistic is flagged when it misses the top of the curve", {
  skip_if_not_installed("mgcv")
  # verdadeira: P(TP) sobe devagar e so salta perto do topo
  val <- withr::with_seed(3, {
    conf <- stats::runif(1500, 0.1, 0.999)
    p <- ifelse(conf < 0.85, 0.35, 0.99)
    tibble::tibble(site = "A", species_folder = "degrau",
                   source_audio = paste0("r", sample(150, 1500, TRUE)),
                   confidence = conf,
                   verdict = ifelse(stats::rbinom(1500, 1, p) == 1,
                                    "positive", "negative"))
  })
  cmp <- suppressMessages(compare_calibration_curves(
    val, target = 0.95, curves = c("logistic", "gam")))
  log <- cmp[cmp$curve == "logistic", ]
  gam <- cmp[cmp$curve == "gam", ]
  expect_gt(log$top_error, gam$top_error)
  expect_identical(unique(cmp$verdict), "use_monotone_or_weighted")
  expect_false(unique(cmp$weighted))
})

test_that("small groups and sparse tops get their own verdicts", {
  skip_if_not_installed("mgcv")
  pouco <- sim_curvas(10, "certa")
  cmp <- suppressMessages(compare_calibration_curves(
    pouco, curves = c("logistic", "gam")))
  expect_identical(unique(cmp$verdict), "too_few_clips")
  expect_true(all(is.na(cmp$cv_logloss)))
  # muitos clipes, quase nenhum no topo
  baixo <- sim_curvas(300, "certa")
  baixo$confidence <- pmin(baixo$confidence, 0.69)
  baixo$confidence[1:20] <- 0.98
  baixo$verdict[1:20] <- "positive"
  cmp <- suppressMessages(compare_calibration_curves(
    baixo, curves = c("logistic", "gam"), min_n = 25))
  expect_identical(unique(cmp$verdict), "sample_more_near_threshold")
})

test_that("weights follow inclusion_prob and the arguments are checked", {
  val <- sim_curvas(300, "certa")
  val$inclusion_prob <- ifelse(val$confidence > 0.7, 1, 0.2)
  a <- suppressMessages(compare_calibration_curves(
    val, curves = "logistic"))
  b <- suppressMessages(compare_calibration_curves(
    val, curves = "logistic", weighted = FALSE))
  expect_true(a$weighted)
  expect_false(b$weighted)
  expect_error(compare_calibration_curves(val, curves = "spline"),
               "must be among")
  expect_error(compare_calibration_curves(val, target = 1.2),
               "between 0 and 1")
  sem <- val
  sem$inclusion_prob <- NULL
  expect_error(compare_calibration_curves(sem, weighted = TRUE,
                                          curves = "logistic"),
               "needs `inclusion_prob`")
  expect_error(compare_calibration_curves(val[0, ], curves = "logistic"),
               "No reviewed clip")
  sem$source_audio <- NULL
  expect_message(compare_calibration_curves(sem, curves = "logistic"),
                 "split clips one by one")
  expect_error(compare_calibration_curves(val, by = "month",
                                          curves = "logistic"),
               "month")
})

test_that("a missing package drops its curve with a message", {
  val <- sim_curvas(200, "certa")
  local_mocked_bindings(requireNamespace = function(pkg, ...) FALSE,
                        .package = "base")
  expect_message(
    cmp <- compare_calibration_curves(
      val, curves = c("logistic", "gam", "monotone_gam")),
    "mgcv is not installed")
  expect_identical(unique(cmp$curve), "logistic")
})

test_that("the monotone GAM is fitted and never decreases", {
  skip_if_not_installed("scam")
  val <- sim_curvas(500, "certa")
  cmp <- suppressMessages(compare_calibration_curves(
    val, curves = c("logistic", "monotone_gam")))
  expect_true("monotone_gam" %in% cmp$curve)
  curva <- attr(cmp, "curves")
  mono <- curva$p_tp[curva$curve == "monotone_gam"]
  expect_true(all(diff(mono) >= -1e-8))
  expect_false(is.na(cmp$cv_logloss[cmp$curve == "monotone_gam"]))
})

test_that("plot_calibration_curves() draws the curves and the bins", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("mgcv")
  val <- sim_curvas(300, "certa")
  cmp <- suppressMessages(compare_calibration_curves(
    val, curves = c("logistic", "gam")))
  expect_s3_class(plot_calibration_curves(cmp), "ggplot")
  expect_s3_class(plot_calibration_curves(cmp, validation = val), "ggplot")
  vazio <- cmp
  attr(vazio, "curves") <- tibble::tibble()
  expect_error(plot_calibration_curves(vazio), "no fitted curves")
})
