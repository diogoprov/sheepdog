noites_cov <- function() {
  tibble::tibble(
    site  = rep(c("A", "B"), each = 6),
    night = rep(sprintf("202110%02d", 1:6), 2),
    temp  = c(18, 20, 22, 24, 26, 28, 15, 16, 17, 18, 19, 20))
}

test_that("covariate_bins() cuts quantiles within each site", {
  b <- covariate_bins(noites_cov(), "temp", n_bins = 3)
  expect_named(b, c("site", "night", "temp_bin"))
  expect_true(is.ordered(b$temp_bin))
  expect_identical(levels(b$temp_bin), c("q1", "q2", "q3"))
  # dois por faixa em cada local, apesar das escalas diferentes
  expect_true(all(dplyr::count(b, site, temp_bin)$n == 2))
  # a menor temperatura de cada local fica na primeira faixa
  expect_identical(as.character(b$temp_bin[c(1, 7)]), c("q1", "q1"))
  # quantis sobre todos os locais: B fica nas faixas baixas
  g <- covariate_bins(noites_cov(), "temp", n_bins = 3, within = NULL)
  expect_false(any(g$temp_bin[g$site == "B"] == "q3"))
})

test_that("covariate_bins() takes fixed breaks and a name", {
  b <- covariate_bins(noites_cov(), "temp", breaks = c(15, 20, 25, 30),
                      name = "faixa")
  expect_named(b, c("site", "night", "faixa"))
  temp <- noites_cov()$temp
  expect_identical(as.character(b$faixa[temp == 20]),
                   c("[20,25)", "[20,25)"))
  expect_identical(as.character(b$faixa[temp == 15]), "[15,20)")
  expect_error(covariate_bins(noites_cov(), "temp", breaks = c(16, 20)),
               "outside `breaks`")
})

test_that("covariate_bins() validates its input", {
  x <- noites_cov()
  expect_error(covariate_bins(x, "nada"), "not in `covariates`")
  expect_error(covariate_bins(dplyr::mutate(x, temp = as.character(temp)),
                              "temp"), "must be numeric")
  expect_error(covariate_bins(rbind(x, x), "temp"), "identify one row")
  empatado <- dplyr::mutate(x, temp = 1)
  expect_error(covariate_bins(empatado, "temp"), "Too many ties")
  expect_error(covariate_bins(x, "temp", n_bins = 1), "`n_bins`")
  # valores ausentes ficam sem faixa
  com_na <- x
  com_na$temp[1] <- NA
  expect_true(is.na(covariate_bins(com_na, "temp")$temp_bin[1]))
})

test_that("select_clips() stratifies the draw by covariate bins", {
  det <- suppressMessages(read_selection_tables(
    system.file("extdata", "example", "birdnet", package = "sheepdog")))
  datas <- unique(sub("^.*_(\\d{8})_\\d{6}.*$", "\\1",
                      basename(gsub("\\\\", "/", det$begin_path))))
  noites <- tidyr::expand_grid(site = unique(det$site), night = datas)
  noites$temp <- withr::with_seed(1, stats::rnorm(nrow(noites), 22, 3))
  faixas <- covariate_bins(noites, "temp", n_bins = 2)

  expect_message(
    m <- suppressWarnings(select_clips(
      det, "random_detections", threshold = 0.5, n_top = 2,
      strata = "temp_bin", covariates = faixas)),
    "include it in the calibration")
  # o manifesto mantem as colunas de sempre; a faixa volta pela mesma
  # tabela de covariate_bins()
  expect_false("temp_bin" %in% names(m))
  oc <- dplyr::distinct(m, site, species_code, occasion_id, night) |>
    dplyr::left_join(faixas, by = c("site", "night"))
  # no maximo 2 ocasioes por local x especie x faixa, e as duas faixas
  # aparecem
  expect_true(all(dplyr::count(oc, site, species_code, temp_bin)$n <= 2))
  expect_setequal(as.character(unique(oc$temp_bin)), c("q1", "q2"))
  expect_true(all(m$inclusion_prob > 0 & m$inclusion_prob <= 1))

  # ocasioes sem covariavel formam um estrato proprio, com aviso
  expect_warning(suppressMessages(select_clips(
    det, "random_detections", threshold = 0.5, n_top = 2,
    strata = "temp_bin", covariates = faixas[-1, ])), "without a value")
  # chave ausente ou coluna repetida
  expect_error(suppressMessages(select_clips(
    det, "random_detections", threshold = 0.5, strata = "temp_bin",
    covariates = faixas["temp_bin"])), "share at least one")
  expect_error(suppressMessages(select_clips(
    det, "random_detections", threshold = 0.5, strata = "temp_bin",
    covariates = dplyr::mutate(faixas, confidence = 1))), "already in")
})

test_that("stage 1 checks split cells by a covariate bin", {
  ex <- system.file("extdata", "example", "validation", package = "sheepdog")
  arqs <- list.files(ex, full.names = TRUE)
  raw <- purrr::list_rbind(purrr::map(arqs, readr::read_csv,
                                      show_col_types = FALSE))
  noites <- dplyr::distinct(raw, site, night) |>
    dplyr::mutate(temp = withr::with_seed(2, stats::rnorm(dplyr::n(), 22, 3)))
  faixas <- covariate_bins(noites, "temp", n_bins = 2)
  raw_b <- raw |>
    dplyr::mutate(night = as.character(night)) |>
    dplyr::left_join(faixas, by = c("site", "night"))

  p <- precision_by_bin(raw_b, min_n = 15, by = "temp_bin")
  expect_true("temp_bin" %in% names(p))
  # somar as faixas devolve a tabela sem `by`
  sem <- precision_by_bin(raw_b, min_n = 15)
  soma <- dplyr::summarise(p, n = sum(n_reviewed),
                           .by = c(site, species_folder, bin))
  junto <- dplyr::inner_join(soma, sem, by = c("site", "species_folder", "bin"))
  expect_identical(nrow(junto), nrow(sem))
  expect_identical(junto$n, junto$n_reviewed)

  t <- suggest_thresholds(raw_b, by = "temp_bin")
  expect_true("temp_bin" %in% names(t))
  expect_identical(nrow(t), nrow(dplyr::distinct(
    dplyr::filter(raw_b, verdict %in% c("positive", "negative"),
                  !is.na(confidence)),
    site, species_folder, temp_bin)))
  vazio <- suggest_thresholds(raw_b[0, ], by = "temp_bin")
  expect_named(vazio, c("site", "species_folder", "temp_bin", "threshold",
                        "n_support", "precision_at_threshold"))
  expect_error(precision_by_bin(raw_b, by = "nada"), "not in the table")
})

test_that("cell_status() splits cells by a covariate bin", {
  skip_if_not_installed("lme4")
  ex <- system.file("extdata", "example", "validation", package = "sheepdog")
  val <- suppressMessages(read_validations(list.files(ex, full.names = TRUE),
                                           keep = "night"))
  noites <- dplyr::distinct(val, site, night) |>
    dplyr::mutate(site = as.character(site),
                  temp = withr::with_seed(3, stats::rnorm(dplyr::n(), 22, 3)))
  faixas <- covariate_bins(noites, "temp", n_bins = 2)
  val_b <- val |>
    dplyr::mutate(night = as.character(night), site_chr = as.character(site)) |>
    dplyr::left_join(faixas, by = c(site_chr = "site", "night")) |>
    dplyr::select(-site_chr)
  fit <- fit_calibration(val, calibration_models()$m3_plus_site)
  st <- cell_status(fit, val_b, by = "temp_bin")
  expect_identical(nrow(st), 8L * 4L * 2L)
  expect_true("temp_bin" %in% names(st))
  # as contagens por faixa somam as da celula
  st0 <- cell_status(fit, val)
  soma <- dplyr::summarise(st, n = sum(n_reviewed), .by = c(site, species))
  junto <- dplyr::inner_join(soma, st0, by = c("site", "species"))
  expect_identical(junto$n, junto$n_reviewed)
})
