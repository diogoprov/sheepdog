# Clipes revisados e deteccoes de duas celulas. `shift` desloca a curva de
# cada local, o que um modelo global nao ve
cells_sim <- function(shift = c(A = 0, B = 0), n = 1500, seed = 1) {
  withr::with_seed(seed, {
    d <- tibble::tibble(site = rep(names(shift), each = n),
                        confidence = stats::runif(2 * n, 0.1, 0.99))
    d$p <- stats::plogis(-1 + 1.2 * stats::qlogis(d$confidence) +
                           shift[d$site])
    d$tp <- stats::rbinom(nrow(d), 1, d$p)
    d
  })
}
as_validation <- function(d) {
  dplyr::transmute(d, site, species_folder = "sp", confidence,
                   verdict = ifelse(tp == 1, "positive", "negative"))
}
fit_global <- function(d) {
  val <- dplyr::transmute(d, site = factor(site), species = factor("sp"),
                          confidence, tp,
                          logit_conf = stats::qlogis(confidence))
  fit_calibration(val, calibration_models()$m0_global)
}
as_scored <- function(d, fit) {
  nd <- dplyr::transmute(d, site, species = "sp", confidence,
                         logit_conf = stats::qlogis(confidence))
  nd$p_tp <- sheepdog:::predict_tp(fit, nd)
  nd
}

test_that("a correct model agrees with the empirical thresholds", {
  d <- cells_sim()
  fit <- fit_global(d)
  cmp <- compare_thresholds(as_validation(d), fit, as_scored(d, fit),
                            target_p = 0.95, target_precision = 0.9,
                            min_n = 15, tolerance = 0.1)
  expect_identical(nrow(cmp), 2L)
  expect_true(all(cmp$flag == "agree"))
  expect_true(all(cmp$thr_p_tp > cmp$thr_model_precision))
  expect_true(all(abs(cmp$model_precision_at_empirical - 0.9) < 0.05))
  expect_false(any(cmp$above_reviewed))
})

test_that("a missing covariate shows as a disagreement", {
  d <- cells_sim(c(A = 2, B = -1.5))
  fit <- fit_global(d)
  cmp <- compare_thresholds(as_validation(d), fit, as_scored(d, fit),
                            min_n = 15, tolerance = 0.05)
  expect_true(any(cmp$flag == "disagree"))
})

test_that("a cell with few clips is model_only", {
  d <- cells_sim()
  fit <- fit_global(d)
  val <- as_validation(d)
  val <- val[val$site == "A" | seq_len(nrow(val)) %% 300 == 0, ]
  cmp <- compare_thresholds(val, fit, as_scored(d, fit), min_n = 15)
  b <- cmp[cmp$site == "B", ]
  expect_true(is.na(b$thr_empirical))
  expect_false(is.na(b$thr_model_precision))
  expect_identical(b$flag, "model_only")
})

test_that("flags cover the empty cases, quality and the reviewed range", {
  d <- cells_sim()
  fit <- fit_global(d)
  sc <- as_scored(d, fit)
  # alvo inatingivel nos dois lados
  none <- compare_thresholds(as_validation(d), fit, sc, target_p = 0.9999,
                             target_precision = 0.9999, min_n = 15)
  expect_true(all(none$flag == "none"))
  # sem `scored`, nao ha flag
  expect_message(sem <- compare_thresholds(as_validation(d), fit), "flag")
  expect_true(all(is.na(sem$flag)))
  expect_false(anyNA(sem$thr_p_tp))
  # o status da calibracao vem junto
  q <- tibble::tibble(species = "sp", status = "poor")
  com <- compare_thresholds(as_validation(d), fit, sc, quality = q)
  expect_true(all(com$quality == "poor"))
  expect_error(compare_thresholds(as_validation(d), fit, sc,
                                  quality = data.frame(site = "A")), "quality")
  # limiar do modelo acima do maior score revisado
  baixa <- as_validation(d)
  baixa <- baixa[baixa$confidence < 0.3, ]
  fora <- compare_thresholds(baixa, fit, sc, min_n = 15)
  expect_true(all(fora$above_reviewed))
})

test_that("post_validation() writes the comparison with `fit`", {
  d <- cells_sim(n = 300)
  fit <- fit_global(d)
  val <- as_validation(d)
  dir <- withr::local_tempdir()
  man <- dplyr::mutate(val, species_code = "Sp_sp", clip_file = paste0(dplyr::row_number(), ".wav"),
                       night = "20240101", recording_date = "20240101",
                       recording_hour = "20", rank = 1L, source_audio = "a.wav",
                       sampling_mode = "top", occasion_id = "a")
  verd <- dplyr::transmute(man, species_folder, clip_file, reviewer = "x",
                           verdict, time = "2024-01-01 00:00:00")
  m <- dplyr::select(man, -verdict)
  readr::write_csv(m, file.path(dir, "m.csv"))
  readr::write_csv(verd, file.path(dir, "v.csv"))
  out <- suppressMessages(post_validation(
    manifest_path = file.path(dir, "m.csv"),
    verdicts_file = file.path(dir, "v.csv"),
    output_dir = file.path(dir, "out"), fit = fit, scored = as_scored(d, fit)))
  expect_true(file.exists(file.path(dir, "out", "thresholds_compared.csv")))
  expect_identical(nrow(out$compared), 2L)
})

test_that("the empirical column uses the weighted precision", {
  d <- cells_sim()
  fit <- fit_global(d)
  val <- as_validation(d)
  val$inclusion_prob <- ifelse(val$confidence > 0.5, 0.2, 0.8)
  cmp <- compare_thresholds(val, fit, as_scored(d, fit))
  thr <- suggest_thresholds(val)
  expect_identical(unique(thr$precision_used), "weighted")
  expect_equal(cmp$prec_empirical[order(cmp$site)],
               thr$precision_weighted_at_threshold[order(thr$site)])
  # `sustained` chega a suggest_thresholds()
  com <- compare_thresholds(val, fit, as_scored(d, fit), sustained = TRUE)
  esperado <- suggest_thresholds(val, sustained = TRUE)
  expect_equal(com$thr_empirical[order(com$site)],
               esperado$threshold[order(esperado$site)])
})

test_that("an empirical threshold without a model one is empirical_only", {
  d <- cells_sim()
  fit <- fit_global(d)
  sc <- as_scored(d, fit)
  # o modelo nunca chega ao alvo, e os clipes chegam
  sc$p_tp <- 0.5
  cmp <- compare_thresholds(as_validation(d), fit, sc)
  expect_true(all(cmp$flag == "empirical_only"))
})
