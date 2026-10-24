saidas_cal <- c(
  model_comparison.csv = "comparacao_modelos.csv",
  effort_curve.csv = "curva_esforco.csv",
  nightly_detection_history.csv = "historico_deteccao_noite.csv",
  detection_summary.csv = "resumo_deteccao_especie_local.csv",
  calibrated_detections_ARA.csv = "deteccoes_calibradas_ARA.csv",
  calibrated_detections_XAR.csv = "deteccoes_calibradas_XAR.csv",
  calibrated_detections_BAI.csv = "deteccoes_calibradas_BAI.csv"
)

# Mesmas entradas da referencia: validacoes no formato v1.2.0 (com o local
# XAR2 renomeado para XAR) e as tabelas de predicao simuladas
rodar_calibracao <- function(saida, ...) {
  raiz <- sim_root()
  suppressMessages(calibrate(
    validation_files = ref_path("cal", paste0("validacao_por_clipe_",
                                              c("ARA", "XAR2", "BAI"), ".csv")),
    prediction_tables = c(
      ARA = file.path(raiz, "tabelas/output_ARA/BirdNET_SelectionTable.txt"),
      XAR = file.path(raiz, "tabelas/output_XAR/BirdNET_SelectionTable.txt"),
      BAI = file.path(raiz, "tabelas/BAI/BirdNET_SelectionTable.txt")),
    output_dir = saida, site_map = c(XAR2 = "XAR"), ...))
}

test_that("calibrate() reproduces v1.2.0", {
  skip_if_not_installed("lme4")
  saida <- withr::local_tempdir()
  # o m4 refeito sobre estes dados e singular; o aviso e testado a parte
  res <- withCallingHandlers(
    rodar_calibracao(saida, select = "best_auc", effort_curve = TRUE,
                     effort_n = c(5, 10), effort_reps = 3),
    warning = function(w) {
      if (grepl("Singular fit", conditionMessage(w))) {
        invokeRestart("muffleWarning")
      }
    })
  for (f in names(saidas_cal)) {
    ref <- ref_table("cal", saidas_cal[[f]])
    if (f == "model_comparison.csv") {
      ref$formula <- gsub("local", "site", gsub("especie", "species",
                                                ref$formula))
    }
    # o lme4 converge em valores que diferem por volta da 6a casa entre
    # plataformas (otimizador e BLAS); 1e-3 relativo basta para dizer que
    # o resultado e o mesmo
    # colunas novas (n_failed, n_train_mean, n_test_mean) nao existiam na
    # v1.2.0: compara so as colunas da referencia
    novo <- read_as_text(file.path(saida, f))
    expect_true(all(names(ref) %in% names(novo)), label = f)
    # auc_sd da curva de esforco e o desvio-padrao de 3 ajustes em amostras
    # pequenas e amplia essas diferencas: com o lme4 2.1-0 ele muda ~0,4 %
    # (as outras colunas seguem dentro de 1e-3), entao vale 1e-2 so para ele
    colunas <- names(ref)
    if (f == "effort_curve.csv") {
      expect_same_table(novo["auc_sd"], ref["auc_sd"], label = f,
                        tolerance = 1e-2)
      colunas <- setdiff(colunas, "auc_sd")
    }
    expect_same_table(novo[colunas], ref[colunas], label = f, tolerance = 1e-3)
  }
  expect_true(file.exists(file.path(saida, "calibration_model.rds")))
  expect_s4_class(res$fit, "glmerMod")
})

test_that("score_detections() needs a model from fit_calibration()", {
  fit <- stats::glm(tp ~ 1, family = stats::binomial,
                    data = data.frame(tp = c(0, 1)))
  expect_error(score_detections(c(A = "x.txt"), fit), "fit_calibration")
})

test_that("a global model scores without lme4-specific levels", {
  val <- suppressMessages(read_validations(
    ref_path("cal", paste0("validacao_por_clipe_", c("ARA", "XAR2", "BAI"),
                           ".csv")), site_map = c(XAR2 = "XAR")))
  expect_setequal(levels(val$site), c("ARA", "XAR", "BAI"))
  fit <- fit_calibration(val, calibration_models()$m0_global)
  sc <- suppressMessages(score_detections(
    c(ARA = file.path(sim_root(), "tabelas/output_ARA/BirdNET_SelectionTable.txt")),
    fit))
  expect_true(all(sc$p_tp > 0 & sc$p_tp < 1))
  expect_true(all(sc$confidence >= 0.1))
  # p_tp cresce com a confidence no modelo global
  expect_true(stats::cor(sc$confidence, sc$p_tp, method = "spearman") > 0.99)
})

test_that("calibration functions leave the global RNG untouched", {
  skip_if_not_installed("lme4")
  val <- suppressMessages(read_validations(
    ref_path("cal", "validacao_por_clipe_ARA.csv")))
  set.seed(1)
  antes <- .Random.seed
  suppressMessages(compare_calibration_models(
    val, calibration_models()["m0_global"], k_folds = 2))
  expect_identical(.Random.seed, antes)
})

test_that("read_validations() reads the new format like the v1.2.0 one", {
  antigo <- ref_path("cal", "validacao_por_clipe_ARA.csv")
  novo <- withr::local_tempfile(fileext = ".csv")
  readr::write_csv(sheepdog:::from_legacy(readr::read_csv(
    antigo, show_col_types = FALSE)), novo)
  expect_identical(suppressMessages(read_validations(novo)),
                   suppressMessages(read_validations(antigo)))
})

test_that("score_detections() assigns small hours to the night before", {
  val <- suppressMessages(read_validations(ref_path(
    "cal", "validacao_por_clipe_ARA.csv")))
  fit <- fit_calibration(val, calibration_models()$m0_global)
  d <- withr::local_tempdir()
  tab <- file.path(d, "t.txt")
  writeLines(c(
    "Species Code\tConfidence\tBegin Path\tFile Offset (s)",
    "Boana raniceps_boa-ran\t0.9\tA_20220110_013000.wav\t0",
    "Boana raniceps_boa-ran\t0.9\tA_20220110_193000.wav\t0",
    "Boana raniceps_boa-ran\t0.05\tA_20220110_193000.wav\t3"), tab)
  expect_warning(
    sc <- suppressMessages(score_detections(c(NOVO = tab), fit)),
    "not in the calibration")
  expect_identical(sc$night, c("20220109", "20220110"))
  expect_identical(sc$site, c("NOVO", "NOVO"))
})

test_that("detection_history() applies the repetition rule", {
  sc <- tibble::tibble(site = "S", species = "a",
                       night = c("1", "1", "1", "2", "3", "3"),
                       p_tp = c(0.99, 0.97, 0.5, 0.96, 0.99, 0.2))
  h <- detection_history(sc, p_min = 0.95, min_detections_night = 2)
  expect_identical(h$n_reliable, c(2L, 1L, 1L))
  expect_identical(h$detection_k1, c(1L, 1L, 1L))
  expect_identical(h$detection_k2, c(1L, 0L, 0L))
  expect_identical(h$detection_k3, c(0L, 0L, 0L))
  expect_identical(h$detection, h$detection_k2)
  expect_identical(summarise_history(h)$nights_k2, 1L)
})

test_that("compare_calibration_models() counts and warns about failed folds", {
  val <- suppressMessages(read_validations(
    ref_path("cal", paste0("validacao_por_clipe_", c("ARA", "XAR2", "BAI"),
                           ".csv")), site_map = c(XAR2 = "XAR")))
  # uma formula com variavel inexistente falha em todos os folds
  modelos <- list(ok = tp ~ logit_conf, ruim = tp ~ logit_conf + nao_existe)
  expect_warning(
    cv <- suppressMessages(compare_calibration_models(val, modelos,
                                                      k_folds = 3)),
    "ruim: the fit failed in 3 of 3 folds")
  expect_identical(cv$n_failed[cv$model == "ok"], 0L)
  expect_identical(cv$n_failed[cv$model == "ruim"], 3L)
})

test_that("calibration_effort() reports the sizes actually used", {
  val <- suppressMessages(read_validations(
    ref_path("cal", paste0("validacao_por_clipe_", c("ARA", "XAR2", "BAI"),
                           ".csv")), site_map = c(XAR2 = "XAR")))
  menor <- min(dplyr::count(val, site, species)$n)
  expect_warning(
    ef <- suppressMessages(calibration_effort(
      val, tp ~ logit_conf, n_train = c(5, menor), n_reps = 2)),
    "exceeds the smallest")
  expect_named(ef, c("n_per_cell", "auc_mean", "auc_sd", "n_train_mean",
                     "n_test_mean", "n_failed"))
  expect_equal(ef$n_train_mean[1], 5)
  expect_lt(ef$n_train_mean[2], menor)
  expect_true(all(diff(ef$n_test_mean) < 0))
})

test_that("fit_calibration() warns about a singular fit", {
  skip_if_not_installed("lme4")
  # no exemplo, o m4 tem a correlacao intercepto-inclinacao de especie em +1
  ex <- system.file("extdata", "example", "validation", package = "sheepdog")
  val <- suppressMessages(read_validations(list.files(ex, full.names = TRUE)))
  expect_warning(
    fit <- fit_calibration(val, calibration_models()$m4_species_x_site),
    "Singular fit")
  expect_true(lme4::isSingular(fit))
  expect_no_warning(fit_calibration(val, calibration_models()$m0_global))
})

test_that("score_probabilities() scores perfect and calibrated predictions", {
  sc <- sheepdog:::score_probabilities(c(0, 1, 1, 0), c(0, 1, 1, 0))
  expect_lt(sc[["logloss"]], 1e-4)
  expect_equal(sc[["brier"]], 0, tolerance = 1e-8)
  # previsoes calibradas: intercepto ~0 e inclinacao ~1
  withr::with_seed(1, {
    p  <- stats::runif(5000)
    tp <- stats::rbinom(5000, 1, p)
  })
  sc <- sheepdog:::score_probabilities(tp, p)
  expect_equal(sc[["cal_intercept"]], 0, tolerance = 0.1)
  expect_equal(sc[["cal_slope"]], 1, tolerance = 0.1)
})

test_that("compare_calibration_models() reports the scoring metrics", {
  val <- suppressMessages(read_validations(
    ref_path("cal", paste0("validacao_por_clipe_", c("ARA", "XAR2", "BAI"),
                           ".csv")), site_map = c(XAR2 = "XAR")))
  cv <- suppressMessages(compare_calibration_models(
    val, calibration_models()[1], k_folds = 3))
  expect_named(cv, c("model", "formula", "auc_mean", "auc_sd", "n_failed",
                     "logloss_mean", "logloss_sd", "brier_mean", "brier_sd",
                     "cal_intercept", "cal_slope", "prop_singular",
                     "complexity"))
  expect_true(cv$logloss_mean > 0 && cv$brier_mean > 0)
  expect_identical(cv$prop_singular, 0)
})

test_that("calibration_models() adds the uncorrelated m4 on request", {
  expect_length(calibration_models(), 5)
  m <- calibration_models(uncorrelated = TRUE)
  expect_identical(names(m)[6], "m5_species_x_site_uncorrelated")
  expect_false(grepl("(logit_conf | species)", deparse1(m[[6]]), fixed = TRUE))
})

test_that("select_calibration_model() applies the two rules", {
  cv <- tibble::tibble(
    model = c("m0", "m1", "m2"), auc_mean = c(0.80, 0.90, 0.91),
    logloss_mean = c(0.50, 0.402, 0.40), logloss_sd = c(0.02, 0.02, 0.02),
    prop_singular = c(0, 0, 1), complexity = 1:3)
  expect_identical(select_calibration_model(cv, "best_auc"), "m2")
  # m2 e singular; m1 e o melhor entre os regulares
  expect_identical(select_calibration_model(cv, "one_se_logloss"), "m1")
  # sem singularidade: m1 esta a menos de 1 EP de m2 e e mais simples
  cv$prop_singular <- 0
  expect_identical(select_calibration_model(cv, "one_se_logloss"), "m1")
  # todos singulares: avisa e escolhe entre todos
  cv$prop_singular <- 1
  expect_warning(select_calibration_model(cv, "one_se_logloss"),
                 "Every candidate")
})

test_that("fit_calibration() keeps the glmer messages and passes them on", {
  skip_if_not_installed("lme4")
  ex <- system.file("extdata", "example", "validation", package = "sheepdog")
  val <- suppressMessages(read_validations(list.files(ex, full.names = TRUE)))
  # o m4 e singular nestes dados: o glmer emite "boundary (singular) fit"
  msgs <- testthat::capture_messages(
    fit <- suppressWarnings(fit_calibration(
      val, calibration_models()$m4_species_x_site)))
  guardadas <- attr(fit, "sheepdog_messages")
  expect_true(any(grepl("singular", guardadas)))
  # a mensagem de ajuste singular nao e repetida (ja vira aviso)
  expect_false(any(grepl("singular", msgs)))
  # um modelo sem efeitos aleatorios nao tem mensagens
  expect_null(attr(fit_calibration(val, tp ~ logit_conf), "sheepdog_messages"))
})

test_that("fit_model() passes on messages other than singular fits", {
  skip_if_not_installed("lme4")
  # glmer simulado que emite uma mensagem qualquer
  local_mocked_bindings(
    glmer = function(...) { message("some lme4 note"); structure(list(), class = "merMod") },
    .package = "lme4")
  msgs <- testthat::capture_messages(
    fit <- sheepdog:::fit_model(tp ~ logit_conf + (1 | species),
                                data.frame(), quiet = FALSE))
  expect_true(any(grepl("lme4: some lme4 note", msgs)))
  expect_identical(attr(fit, "sheepdog_messages"), "some lme4 note")
  expect_length(testthat::capture_messages(
    sheepdog:::fit_model(tp ~ logit_conf + (1 | species), data.frame())), 0)
})

test_that("the default selection uses log-loss rather than AUC ranking", {
  cv <- tibble::tibble(
    model = c("m1_species_intercept", "m0_global"), auc_mean = c(0.95, 0.8),
    logloss_mean = c(0.6, 0.4), logloss_sd = c(0.01, 0.01),
    prop_singular = c(0, 0), complexity = c(2L, 1L))
  expect_identical(select_calibration_model(cv), "m0_global")
  expect_identical(select_calibration_model(cv, "best_auc"), "m1_species_intercept")

  selected <- NULL
  local_mocked_bindings(
    read_validations = function(...) NULL,
    compare_calibration_models = function(...) cv,
    fit_calibration = function(validations, formula, ...) {
      selected <<- formula
      stop("stop after selection")
    })
  out <- withr::local_tempdir()
  expect_error(suppressMessages(calibrate(NULL, NULL, out)),
               "stop after selection")
  expect_identical(selected, calibration_models()$m0_global)
  expect_error(suppressMessages(calibrate(NULL, NULL, out, select = "best_auc")),
               "stop after selection")
  expect_identical(selected, calibration_models()$m1_species_intercept)
})
