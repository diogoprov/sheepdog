dados_suporte <- function() {
  ex <- system.file("extdata", "example", package = "sheepdog")
  arqs <- list.files(file.path(ex, "validation"), full.names = TRUE)
  list(
    raw = purrr::list_rbind(purrr::map(arqs, readr::read_csv,
                                       show_col_types = FALSE)),
    det = suppressMessages(read_selection_tables(file.path(ex, "birdnet"))),
    rec = readr::read_csv(file.path(ex, "recordings.csv"),
                          show_col_types = FALSE))
}

test_that("review_support() counts and labels each site x species cell", {
  d <- dados_suporte()
  s <- review_support(d$raw, d$det, conf_high = 0.7, min_n = 15)
  expect_named(s, c("site", "species_folder", "n_reviewed", "n_fp", "n_high",
                    "prec_high", "n_high_all", "unreviewed_high", "threshold",
                    "diagnosis"))
  expect_identical(nrow(s), 32L)
  expect_true(all(s$diagnosis %in% c("reached", "exhausted", "unreliable",
                                     "review more", "not reviewed")))
  # contagens conferidas direto nas tabelas
  um <- s[s$site == "BAI" & s$species_folder == "pse_pla", ]
  v <- d$raw[d$raw$site == "BAI" & d$raw$species_folder == "pse_pla" &
               d$raw$verdict %in% c("positive", "negative"), ]
  expect_identical(um$n_reviewed, nrow(v))
  expect_identical(um$n_fp, sum(v$verdict == "negative"))
  expect_identical(um$n_high, sum(v$confidence >= 0.7))
  todas <- d$det[d$det$site == "BAI" &
                   sheepdog:::folder_name(d$det$species_code) == "pse_pla", ]
  expect_identical(um$n_high_all, sum(todas$confidence >= 0.7))
  # o limiar e o de suggest_thresholds()
  thr <- suggest_thresholds(d$raw, target_precision = 0.9, min_n = 15)
  m <- match(paste(s$site, s$species_folder),
             paste(thr$site, thr$species_folder))
  expect_identical(s$threshold, thr$threshold[m])
  expect_true(all(s$diagnosis[!is.na(s$threshold)] == "reached"))
  # celulas com deteccoes e sem clipes revisados
  sem <- review_support(d$raw[d$raw$site != "ARA", ], d$det)
  expect_true(all(sem$diagnosis[sem$site == "ARA"] == "not reviewed"))
  expect_true(all(sem$n_reviewed[sem$site == "ARA"] == 0L))
})

test_that("review_support() splits cells by covariate bins", {
  d <- dados_suporte()
  noites <- tibble::tibble(
    site = d$rec$site,
    night = sub("^.*_(\\d{8})_\\d{6}.*$", "\\1",
                basename(gsub("\\\\", "/", d$rec$source_audio)))) |>
    dplyr::distinct() |>
    dplyr::mutate(temp = withr::with_seed(4, stats::rnorm(dplyr::n(), 22, 3)))
  faixas <- covariate_bins(noites, "temp", n_bins = 2)
  s <- review_support(d$raw, d$det, by = "temp_bin", covariates = faixas)
  expect_true("temp_bin" %in% names(s))
  # as faixas somam as celulas
  s0 <- review_support(d$raw, d$det)
  soma <- dplyr::summarise(s, n_reviewed = sum(n_reviewed),
                           n_high_all = sum(n_high_all),
                           .by = c(site, species_folder))
  j <- dplyr::inner_join(soma, s0, by = c("site", "species_folder"))
  expect_identical(nrow(j), nrow(s0))
  expect_identical(j$n_reviewed.x, j$n_reviewed.y)
  expect_identical(j$n_high_all.x, j$n_high_all.y)
  # sem a tabela de covariaveis, a coluna tem de existir nas duas tabelas
  expect_error(review_support(d$raw, d$det, by = "temp_bin"),
               "not in the table")
  expect_error(review_support(d$raw, d$det[, c("site", "confidence")]),
               "lacks column")
})
