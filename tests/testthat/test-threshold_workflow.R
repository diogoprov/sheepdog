# Fluxo do limiar: bootstrap por gravacao, limiar por grupo, ficha do
# limiar e revisao cega no app

# Tabela de validacao sintetica: uma celula, 40 gravacoes de 5 clipes, com
# a precisao subindo com o score e pesos de um sorteio por faixa
validacao_sintetica <- function(seed = 1, n_rec = 40) {
  withr::with_seed(seed, {
    conf <- round(stats::runif(n_rec * 5, 0.1, 1), 3)
    tp <- stats::rbinom(length(conf), 1, stats::plogis(-4 + 9 * conf))
    tibble::tibble(
      site = "ARA", species_folder = "boa_ran",
      source_audio = rep(sprintf("/a/rec%02d.wav", seq_len(n_rec)), each = 5),
      night = rep(sprintf("202110%02d", (seq_len(n_rec) - 1) %% 10 + 1),
                  each = 5),
      recording_hour = rep(c("19", "22"), length.out = length(conf)),
      confidence = conf,
      inclusion_prob = ifelse(conf < 0.4, 0.05, ifelse(conf < 0.7, 0.3, 0.9)),
      verdict = ifelse(tp == 1, "positive", "negative"))
  })
}

test_that("threshold_bootstrap() resamples recordings around the threshold", {
  val <- validacao_sintetica()
  ponto <- suggest_thresholds(val, target_precision = 0.9, min_n = 10,
                              sustained = TRUE)
  semente_antes <- if (exists(".Random.seed", globalenv())) {
    get(".Random.seed", globalenv())
  }
  b <- threshold_bootstrap(val, target_precision = 0.9, min_n = 10,
                           n_boot = 200, seed = 3)
  depois <- if (exists(".Random.seed", globalenv())) {
    get(".Random.seed", globalenv())
  }
  expect_identical(depois, semente_antes)
  expect_identical(nrow(b), 1L)
  expect_identical(b$threshold, ponto$threshold)
  expect_identical(b$n_clusters, 40L)
  expect_gte(b$threshold_conservative, b$threshold_median)
  expect_gt(b$share_reached, 0.5)
  # mesma semente, mesmo resultado; por noite, menos unidades
  expect_identical(threshold_bootstrap(val, 0.9, 10, n_boot = 200, seed = 3),
                   b)
  bn <- threshold_bootstrap(val, 0.9, 10, n_boot = 50, cluster = "night")
  expect_identical(bn$n_clusters, 10L)
  expect_error(threshold_bootstrap(val, cluster = "nada"), "not a column")
  expect_error(threshold_bootstrap(val, conf = 1), "between 0 and 1")
})

test_that("threshold_by_group() checks one threshold within each group", {
  val <- tibble::tibble(
    site = "ARA", species_folder = "boa_ran",
    recording_hour = rep(c("19", "22"), each = 4),
    confidence = c(0.9, 0.8, 0.7, 0.3, 0.9, 0.8, 0.7, 0.3),
    inclusion_prob = c(1, 1, 0.5, 0.1, 1, 1, 0.5, 0.1),
    verdict = c("positive", "positive", "positive", "negative",
                "positive", "negative", "negative", "negative"))
  g <- threshold_by_group(val, 0.6, by = "recording_hour",
                          target_precision = 0.9, min_n = 2)
  expect_identical(g$n_above, c(3L, 3L))
  expect_equal(g$precision_above, c(1, 1 / (1 + 1 + 2)))
  expect_identical(g$below_target, c(FALSE, TRUE))
  # limiar por celula, de outra coluna
  lim <- tibble::tibble(site = "ARA", species_folder = "boa_ran",
                        threshold = 0.6, threshold_conservative = 0.85)
  g2 <- threshold_by_group(val, lim, by = "recording_hour", min_n = 1,
                           threshold_column = "threshold_conservative")
  expect_identical(g2$n_above, c(1L, 1L))
  # com poucos clipes acima, sem veredito
  g3 <- threshold_by_group(val, 0.6, by = "recording_hour", min_n = 5)
  expect_true(all(is.na(g3$below_target)))
  expect_error(threshold_by_group(val, 0.6, by = character()), "group")
  expect_error(threshold_by_group(val, lim[, 1:2], by = "recording_hour"),
               "threshold")
})

test_that("threshold_record() joins the pieces and writes Markdown", {
  val <- validacao_sintetica()
  lim <- suggest_thresholds(val, 0.9, 10, sustained = TRUE)
  b <- threshold_bootstrap(val, 0.9, 10, n_boot = 50)
  g <- threshold_by_group(val, lim, by = "recording_hour", min_n = 5)
  info <- tibble::tibble(key = c("classifier", "sampling_mode"),
                         value = c("FrogNet v2", "random_detections"))
  f <- withr::local_tempfile(fileext = ".md")
  expect_message(ficha <- threshold_record(lim, b, g, info, file = f),
                 "written")
  expect_identical(nrow(ficha), 1L)
  expect_true(all(c("threshold_conservative", "n_groups", "n_groups_below",
                    "worst_group_precision", "target_precision") %in%
                    names(ficha)))
  texto <- readLines(f)
  expect_true(any(grepl("FrogNet v2", texto)))
  expect_true(any(grepl("^\\| site \\| species_folder", texto)))
  # sem arquivo, so a tabela
  expect_identical(nrow(threshold_record(lim)), 1L)
  expect_error(threshold_record(lim[, 1:2]), "threshold")
})

test_that("blind review shuffles the queue and hides the score", {
  skip_if_not_installed("shiny")
  expect_identical(blind_order(10, "bia"), blind_order(10, "bia"))
  expect_setequal(blind_order(10, "bia"), 1:10)
  expect_false(identical(blind_order(10, "bia"), 1:10))
  d <- withr::local_tempdir()
  # nomes como os de select_clips(): comecam com o score
  man <- tibble::tibble(
    site = "A", species_code = "Sp a", species_folder = "sp_a",
    night = "20211001", recording_hour = 20,
    confidence = c(0.95, 0.81, 0.62, 0.44, 0.23, 0.12),
    sampling_mode = "random_detections", reviewer = "bia",
    clip_file = sprintf("%.3f_1_rec_%ds.wav",
                        c(0.95, 0.81, 0.62, 0.44, 0.23, 0.12), 1:6))
  dir.create(file.path(d, "clips", "sp_a"), recursive = TRUE)
  file.create(file.path(d, "clips", "sp_a", man$clip_file))
  aberta <- review_queue(man, file.path(d, "clips"), "bia")
  cega <- review_queue(man, file.path(d, "clips"), "bia", blind = TRUE)
  expect_setequal(cega$clip_file, aberta$clip_file)
  expect_identical(cega$clip_file,
                   aberta$clip_file[blind_order(nrow(aberta), "bia")])
  f <- file.path(d, "verdicts.csv")
  shiny::testServer(review_server, args = list(
    fila = cega, verdicts_file = f, reviewer = "bia", blind = TRUE), {
      session$setInputs(species = "", pending = TRUE)
      expect_false(grepl("Score|Design|rec_", output$info))
      expect_match(output$info, "Species")
    })
  shiny::testServer(review_server, args = list(
    fila = aberta, verdicts_file = f, reviewer = "bia"), {
      session$setInputs(species = "", pending = TRUE)
      expect_match(output$info, "Score")
    })
})
