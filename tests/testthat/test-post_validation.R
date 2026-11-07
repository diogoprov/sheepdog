saidas_pv <- c(validation_by_clip.csv = "validacao_por_clipe.csv",
               precision_by_bin.csv = "precisao_por_faixa.csv",
               suggested_thresholds.csv = "thresholds_sugeridos.csv",
               nightly_presence.csv = "presenca_por_noite.csv",
               retraining_clips.csv = "clipes_para_retreino.csv")

# Manifesto da referencia (formato v1.2.0) com a raiz simulada e a revisao
# simulada no mesmo lugar e com a mesma semente de make_reference_v1.2.0.R
preparar_pv <- function(nm) {
  raiz <- sim_root()
  man <- file.path(raiz, paste0("manifesto_", nm, ".csv"))
  writeLines(gsub("<ROOT>", raiz, readLines(ref_path(nm, "manifesto_clipes.csv")),
                  fixed = TRUE), man)
  dir_rev <- file.path(raiz, "runs", paste0("pv_", nm), "revisado")
  unlink(dir_rev, recursive = TRUE)
  m <- utils::read.csv(man)
  simulate_review(m$arquivo_clipe, m$pasta_especie, m$confidence, dir_rev)
  list(manifesto = man, revisado = dir_rev)
}

comparar_pv <- function(saida, nm) {
  for (f in names(saidas_pv)) {
    novo <- read_as_text(file.path(saida, f))
    novo[] <- lapply(novo, \(x) gsub(sim_root(), "<ROOT>", x, fixed = TRUE))
    ref <- ref_table(paste0("pv_", nm), saidas_pv[[f]], rec_prefix = FALSE)
    # unico desvio intencional da v1.2.0: sem clipes com confidence, ela
    # escrevia uma linha toda NA nos thresholds
    if (f == "suggested_thresholds.csv") ref <- ref[ref$site != "NA", ]
    expect_same_table(novo, ref, label = f)
  }
}

for (nm in c("top_default", "rec_file")) {
  test_that(paste("post_validation() reproduces v1.2.0:", nm), {
    pv <- preparar_pv(nm)
    saida <- withr::local_tempdir()
    suppressMessages(post_validation(pv$revisado, pv$manifesto, saida))
    comparar_pv(saida, nm)
  })
}

test_that("post_validation() reads the new manifest format the same way", {
  pv <- preparar_pv("top_default")
  novo <- withr::local_tempfile(fileext = ".csv")
  readr::write_csv(sheepdog:::from_legacy(readr::read_csv(
    pv$manifesto, show_col_types = FALSE)), novo)
  saida <- withr::local_tempdir()
  suppressMessages(post_validation(pv$revisado, novo, saida))
  comparar_pv(saida, "top_default")
})

test_that("a manifest without confidence leaves precision and thresholds empty", {
  pv <- preparar_pv("rec_file")
  val <- suppressMessages(classify_review(pv$manifesto, pv$revisado))
  expect_true(all(is.na(val$confidence)))
  expect_true(any(val$verdict %in% c("positive", "negative")))
  expect_identical(nrow(precision_by_bin(val)), 0L)
  expect_identical(nrow(suggest_thresholds(val)), 0L)
  pres <- nightly_presence(val)
  expect_true(any(pres$presence == "confirmed"))
  expect_true(all(is.na(pres$max_confidence_positive)))
})

test_that("old manifests without `noite` use the recording date", {
  pv <- preparar_pv("top_default")
  m <- readr::read_csv(pv$manifesto, show_col_types = FALSE)
  m$noite <- NULL
  val <- suppressMessages(classify_review(m, pv$revisado))
  expect_identical(val$night, val$recording_date)
})

test_that("post_validation() stops when nothing was reviewed", {
  pv <- preparar_pv("top_default")
  expect_error(suppressMessages(post_validation(
    pv$revisado, pv$manifesto, withr::local_tempdir(),
    positive_pattern = "^$", negative_pattern = "^$")), "No clip with")
})

test_that("verdict patterns are case-insensitive and ignore review_dir", {
  d <- file.path(withr::local_tempdir(), "Positive_run")
  dir.create(file.path(d, "boa_ran", "NEGATIVE"), recursive = TRUE)
  dir.create(file.path(d, "boa_ran", "Pos"), recursive = TRUE)
  file.create(file.path(d, "boa_ran", "NEGATIVE", "a.wav"),
              file.path(d, "boa_ran", "Pos", "b.wav"),
              file.path(d, "boa_ran", "c.wav"))
  man <- tibble::tibble(site = "S", species_folder = "boa_ran",
                        clip_file = c("a.wav", "b.wav", "c.wav", "d.wav"),
                        recording_date = "20220110", confidence = 0.5)
  val <- suppressMessages(classify_review(man, d, positive_pattern = "POS"))
  expect_identical(val$verdict,
                   c("negative", "positive", "not_reviewed", "clip_missing"))
})

test_that("a manifest without a confidence column is read", {
  d <- withr::local_tempdir()
  dir.create(file.path(d, "boa_ran", "Positive"), recursive = TRUE)
  file.create(file.path(d, "boa_ran", "Positive", "a.wav"))
  man <- tibble::tibble(site = "S", species_folder = "boa_ran",
                        clip_file = "a.wav", recording_date = "20220110")
  val <- suppressMessages(classify_review(man, d))
  expect_true(is.na(val$confidence))
  expect_identical(nrow(precision_by_bin(val)), 0L)
})

test_that("precision is also weighted by 1 / inclusion_prob", {
  val <- tibble::tibble(
    site = "A", species_folder = "sp",
    confidence = c(0.55, 0.56, 0.57, 0.58, 0.95, 0.96),
    verdict = c("positive", "negative", "negative", "negative",
                "positive", "positive"),
    inclusion_prob = c(0.1, 1, 1, 1, 0.5, 0.5))
  p <- precision_by_bin(val, min_n = 1)
  expect_named(p, c("site", "species_folder", "bin", "n_reviewed",
                    "n_positive", "precision", "precision_weighted",
                    "low_support"))
  b5 <- p[p$bin == "[0.5,0.6)", ]
  expect_equal(b5$precision, 0.25)
  expect_equal(b5$precision_weighted, 10 / 13)
  expect_equal(p$precision_weighted[p$bin == "[0.9,1]"], 1)
  th <- suggest_thresholds(val, target_precision = 0.5, min_n = 1,
                           weighted = FALSE)
  expect_equal(th$threshold, 0.55)
  expect_identical(th$precision_used, "unweighted")
  expect_equal(th$precision_at_threshold, 0.5)
  expect_equal(th$precision_weighted_at_threshold, (10 + 4) / (10 + 3 + 4))
  # um clipe sem inclusion_prob (de "top") deixa a faixa sem a ponderada
  val$inclusion_prob[1] <- NA
  p2 <- precision_by_bin(val, min_n = 1)
  expect_true(is.na(p2$precision_weighted[p2$bin == "[0.5,0.6)"]))
  # sem inclusion_prob, as tabelas ficam como antes
  val$inclusion_prob <- NULL
  expect_false("precision_weighted" %in% names(precision_by_bin(val)))
  expect_false("precision_weighted_at_threshold" %in%
                 names(suggest_thresholds(val, min_n = 1)))
  vazio <- suggest_thresholds(val[0, ] |>
                                dplyr::mutate(inclusion_prob = numeric()))
  expect_identical(nrow(vazio), 0L)
})

# Dois estratos de uma celula, como no exemplo da issue #103: a hora quieta
# foi revista por inteiro (precisao 0,6) e o coro em 1/10 (precisao 0,95)
two_strata <- function(n_q = 20, n_c = 20, prob_c = 0.1) {
  tibble::tibble(
    site = "A", species_folder = "sp",
    confidence = rep(0.5, n_q + n_c),
    verdict = c(rep(c("positive", "negative"), c(0.6 * n_q, 0.4 * n_q)),
                rep(c("positive", "negative"), c(0.95 * n_c, 0.05 * n_c))),
    inclusion_prob = rep(c(1, prob_c), c(n_q, n_c)))
}

test_that("suggest_thresholds() chooses the cut with the design weights", {
  val <- two_strata()
  # sem peso, 0,775 < 0,9; com peso, (12 + 190) / 220 = 0,918
  sem <- suggest_thresholds(val, min_n = 5, weighted = FALSE)
  expect_true(is.na(sem$threshold))
  com <- suggest_thresholds(val, min_n = 5)
  expect_equal(com$threshold, 0.5)
  expect_equal(com$precision_at_threshold, 0.775)
  expect_equal(com$precision_weighted_at_threshold, 202 / 220)
  expect_identical(com$precision_used, "weighted")
  expect_equal(com$n_eff, 220^2 / (20 + 20 * 100))
  expect_identical(com$n_support, 40L)
  expect_equal(com, suggest_thresholds(val, min_n = 5, weighted = TRUE))
  # o padrao oposto: a precisao sem peso aceita um corte que nao atinge
  inv <- val
  inv$inclusion_prob <- rep(c(0.1, 1), each = 20)
  expect_equal(suggest_thresholds(inv, target_precision = 0.75,
                                  min_n = 5, weighted = FALSE)$threshold, 0.5)
  expect_true(is.na(suggest_thresholds(inv, target_precision = 0.75,
                                       min_n = 5)$threshold))
})

test_that("min_n applies to the effective sample size when weighted", {
  val <- two_strata()
  n_eff <- 220^2 / (20 + 20 * 100)
  expect_lt(n_eff, 40)
  expect_true(is.na(suggest_thresholds(val, min_n = 30)$threshold))
  expect_equal(suggest_thresholds(val, target_precision = 0.7, min_n = 30,
                                  weighted = FALSE)$threshold, 0.5)
})

test_that("equal inclusion probabilities give the unweighted threshold", {
  set.seed(1)
  val <- tibble::tibble(site = "A", species_folder = "sp",
                        confidence = round(runif(200), 2))
  val$verdict <- ifelse(runif(200) < val$confidence, "positive", "negative")
  for (p in c(1, 0.3)) {
    val$inclusion_prob <- p
    a <- suggest_thresholds(val, min_n = 10)
    b <- suggest_thresholds(val, min_n = 10, weighted = FALSE)
    expect_false(is.na(a$threshold))
    expect_equal(a$threshold, b$threshold)
    expect_equal(a$n_support, b$n_support)
    expect_equal(a$n_eff, a$n_support)
  }
})

test_that("cells mixing clips with and without inclusion_prob warn", {
  val <- two_strata()
  val$inclusion_prob[1] <- NA
  expect_warning(m <- suggest_thresholds(val, target_precision = 0.7,
                                         min_n = 5),
                 "unweighted precision")
  expect_equal(m$threshold, 0.5)
  expect_identical(m$precision_used, "unweighted")
  expect_true(is.na(m$precision_weighted_at_threshold))
  expect_true(is.na(m$n_eff))
  expect_warning(t <- suggest_thresholds(val, target_precision = 0.7,
                                         min_n = 5, weighted = TRUE),
                 "no threshold")
  expect_true(is.na(t$threshold))
  expect_no_warning(suggest_thresholds(val, target_precision = 0.7, min_n = 5,
                                       weighted = FALSE))
  # uma celula so com clipes de "top" nao e mista: fica sem peso, sem aviso
  top <- two_strata()
  top$site <- "B"
  top$inclusion_prob <- NA_real_
  ambas <- dplyr::bind_rows(two_strata(), top)
  expect_no_warning(r <- suggest_thresholds(ambas, target_precision = 0.7,
                                            min_n = 5))
  expect_identical(r$precision_used, c("weighted", "unweighted"))
})

test_that("suggest_thresholds() checks `weighted`", {
  val <- two_strata()
  expect_error(suggest_thresholds(val, weighted = "yes"), "NULL, TRUE or FALSE")
  val$inclusion_prob <- NULL
  expect_error(suggest_thresholds(val, weighted = TRUE), "no reviewed clip")
  expect_named(suggest_thresholds(val, min_n = 5),
               c("site", "species_folder", "threshold", "n_support",
                 "precision_at_threshold"))
})

test_that("suggest_thresholds() copes with a top score that rounds up", {
  v <- tibble::tibble(site = "A", species_folder = "Sp",
                      confidence = c(rep(0.8, 20), 0.996),
                      verdict = "positive", inclusion_prob = 0.5)
  thr <- suggest_thresholds(v, min_n = 5)
  expect_equal(thr$threshold, 0.8)
})

test_that("`sustained` needs the target at every supported higher cut", {
  # acima de 0,5 a precisao acumulada cai abaixo do alvo em 0,6 e volta em 0,7
  v <- tibble::tibble(
    site = "A", species_folder = "Sp",
    confidence = rep(c(0.5, 0.6, 0.7), c(30, 10, 20)),
    verdict = c(rep("positive", 30), rep("negative", 10), rep("positive", 20)))
  # cortes: 0,5 -> 50/60 = 0,83; 0,6 -> 20/30 = 0,67; 0,7 -> 1
  expect_equal(suggest_thresholds(v, target_precision = 0.8, min_n = 5,
                                  sustained = TRUE)$threshold, 0.7)
  expect_equal(suggest_thresholds(v, target_precision = 0.8,
                                  min_n = 5)$threshold, 0.5)
  # um falso positivo no topo, sem apoio, nao tira o limiar
  topo <- tibble::tibble(
    site = "A", species_folder = "Sp",
    confidence = c(rep(0.5, 30), 0.9),
    verdict = c(rep("positive", 30), "negative"))
  expect_equal(suggest_thresholds(topo, target_precision = 0.9, min_n = 5,
                                  sustained = TRUE)$threshold, 0.5)
})
