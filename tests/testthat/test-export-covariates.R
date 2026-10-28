# Esquema 1.3: calibracao com covariavel continua da ocasiao. As versoes
# saem do export, com P(TP) por predicao, e nao ha grade de calibracao.

# ajuste brms falso: P(TP) = plogis(logit_conf + temp), igual em todo draw
fit_temp <- function(especies, faixa = c(-3, 3)) {
  structure(list(data = data.frame(tp = c(0, 1), logit_conf = 0,
                                   temp = faixa)),
            class = "brmsfit",
            sheepdog_levels = list(species = especies,
                                   site = c("ARA", "BAI", "XAR")))
}
mock_predicoes <- function(env = parent.frame()) {
  local_mocked_bindings(
    posterior_size = function(fit) 10L,
    prediction_draws = function(fit, newdata, ids) {
      p <- stats::plogis(newdata$logit_conf + newdata$temp)
      matrix(p, nrow = length(ids), ncol = length(p), byrow = TRUE)
    },
    .env = env)
}
covs_temp <- function() {
  base <- export_sim()$tables$occasions
  dplyr::transmute(base, site, occasion_id,
                   temp = ifelse(seq_len(nrow(base)) %% 2 == 0, 1, -1))
}

test_that("a calibration on a continuous covariate writes schema 1.3", {
  skip_if_not_installed("arrow")
  mock_predicoes()
  especies <- unique(sheepdog:::folder_name(sim_pred()$species_code))
  covs <- covs_temp()
  ex <- export_sim(fit = fit_temp(especies), n_draws = 10,
                   occasion_covariates = covs, n_versions = 4,
                   rule = "threshold", p_min = 0.5,
                   covariate_scaling = list(temp = c(center = 22, scale = 3)))
  sc <- jsonlite::read_json(file.path(ex$dir, "schema.json"),
                            simplifyVector = TRUE)
  expect_identical(sc$schema_version, 1.3)
  expect_identical(sc$calibration$covariates, "temp")
  expect_identical(sc$calibration$keys, c("site", "species"))
  expect_null(sc$calibration$grid_step)
  expect_equal(sc$calibration$covariate_range$temp, list(min = -3, max = 3))
  expect_equal(sc$calibration$covariate_scaling$temp,
               list(center = 22, scale = 3))
  expect_false(file.exists(file.path(ex$dir, "calibration_draws.parquet")))
  expect_identical(sc$occasion_draws$rule, "threshold")
  expect_identical(sc$occasion_draws$p_min, 0.5)
  expect_identical(sc$occasion_draws$n_draws, 4L)

  # regra do limiar: uma deteccao quando alguma predicao tem P(TP) >= p_min
  od <- as.data.frame(arrow::read_parquet(
    file.path(ex$dir, "occasion_draws.parquet")))
  expect_identical(names(od), c("draw", "site", "occasion_id", "species", "y"))
  det <- ex$tables$detections |>
    dplyr::left_join(covs, by = c("site", "occasion_id")) |>
    dplyr::mutate(p = stats::plogis(sheepdog:::safe_logit(confidence) + temp))
  esperado <- dplyr::summarise(det, y = as.integer(any(p >= 0.5)),
                               .by = c(site, occasion_id, species))
  um <- od[od$draw == od$draw[1], ]
  m <- match(paste(um$site, um$occasion_id, um$species),
             paste(esperado$site, esperado$occasion_id, esperado$species))
  expect_false(anyNA(m))
  expect_identical(um$y, esperado$y[m])
  expect_identical(nrow(um), nrow(esperado))
})

test_that("versions with a covariate are reproducible and leave the RNG", {
  skip_if_not_installed("arrow")
  mock_predicoes()
  especies <- unique(sheepdog:::folder_name(sim_pred()$species_code))
  covs <- covs_temp()
  set.seed(1)
  antes <- .Random.seed
  a <- export_sim(fit = fit_temp(especies), n_draws = 10,
                  occasion_covariates = covs)
  expect_identical(.Random.seed, antes)
  b <- export_sim(fit = fit_temp(especies), n_draws = 10,
                  occasion_covariates = covs)
  expect_identical(a$tables$occasion_draws, b$tables$occasion_draws)
  # sem n_versions, uma versao por draw da calibracao
  expect_identical(length(unique(a$tables$occasion_draws$draw)), 10L)
  sc <- jsonlite::read_json(file.path(a$dir, "schema.json"))
  expect_identical(sc$occasion_draws$rule, "sample")
  expect_identical(sc$occasion_draws$seed, 2026L)
  c2 <- export_sim(fit = fit_temp(especies), n_draws = 10,
                   occasion_covariates = covs, seed = 7)
  expect_false(identical(a$tables$occasion_draws$y,
                         c2$tables$occasion_draws$y))
})

test_that("missing or out-of-range covariates are reported", {
  skip_if_not_installed("arrow")
  mock_predicoes()
  especies <- unique(sheepdog:::folder_name(sim_pred()$species_code))
  covs <- covs_temp()
  # uma ocasiao com predicao sem covariavel: NA em todo draw
  det <- export_sim()$tables$detections
  alvo <- det[1, c("site", "occasion_id")]
  sem <- dplyr::anti_join(covs, alvo, by = c("site", "occasion_id"))
  avisos <- capture_warnings(
    ex <- export_sim(fit = fit_temp(especies), n_draws = 10,
                     occasion_covariates = sem))
  expect_true(any(grepl("without a value of the calibration covariates",
                        avisos)))
  od <- ex$tables$occasion_draws
  y_alvo <- od$y[od$site == alvo$site & od$occasion_id == alvo$occasion_id]
  expect_true(length(y_alvo) > 0 && all(is.na(y_alvo)))
  # valores fora da faixa da calibracao
  avisos <- capture_warnings(export_sim(
    fit = fit_temp(especies, faixa = c(-0.5, 0.5)), n_draws = 10,
    occasion_covariates = covs))
  expect_true(all(grepl("outside its range", avisos)))
})

test_that("calibration covariates are checked", {
  skip_if_not_installed("arrow")
  especies <- unique(sheepdog:::folder_name(sim_pred()$species_code))
  fit <- fit_temp(especies)
  expect_error(export_sim(fit = fit, n_draws = 10),
               "`temp` is not a column of `occasion_covariates`")
  covs <- dplyr::mutate(covs_temp(), temp = as.character(temp))
  expect_error(export_sim(fit = fit, n_draws = 10, occasion_covariates = covs),
               "must be numeric")
  expect_error(export_sim(fit = fit, n_draws = 10,
                          occasion_covariates = covs_temp(),
                          covariate_scaling = list(rain = c(center = 1, scale = 1))),
               "named by the continuous covariates")
  expect_error(export_sim(fit = fit, n_draws = 10,
                          occasion_covariates = covs_temp(),
                          covariate_scaling = list(temp = 2)),
               "c\\(center = , scale = \\)")
  expect_error(export_sim(n_versions = 3), "needs a calibration")
})

test_that("occasion_draws() refuses an export calibrated on covariates", {
  skip_if_not_installed("arrow")
  mock_predicoes()
  especies <- unique(sheepdog:::folder_name(sim_pred()$species_code))
  ex <- export_sim(fit = fit_temp(especies), n_draws = 10,
                   occasion_covariates = covs_temp())
  expect_error(occasion_draws(ex$dir), "export again")
})

test_that("n_versions without covariates writes schema 1.2 from the grid", {
  skip_if_not_installed("arrow")
  especies <- unique(sheepdog:::folder_name(sim_pred()$species_code))
  fit <- structure(list(data = data.frame(tp = 1, logit_conf = 0)),
                   class = "brmsfit",
                   sheepdog_levels = list(species = especies,
                                          site = c("ARA", "BAI", "XAR")))
  local_mocked_bindings(
    posterior_size = function(fit) 10L,
    grid_draws = function(fit, site, species, min_confidence, step,
                          draw_ids = NULL, keys = list()) {
      grade <- tidyr::expand_grid(
        species = factor(species),
        confidence = sheepdog:::score_grid(min_confidence, step))
      list(grid = grade,
           draws = matrix(grade$confidence, length(draw_ids), nrow(grade),
                          byrow = TRUE))
    })
  ex <- suppressMessages(export_sim(fit = fit, n_draws = 10, grid_step = 0.05,
                                    n_versions = 3))
  sc <- jsonlite::read_json(file.path(ex$dir, "schema.json"),
                            simplifyVector = TRUE)
  expect_identical(sc$schema_version, 1.2)
  expect_identical(sc$occasion_draws$n_draws, 3L)
  expect_true(file.exists(file.path(ex$dir, "calibration_draws.parquet")))
  # as mesmas versoes de occasion_draws() sobre a pasta
  od <- occasion_draws(ex$dir, n_draws = 3, write = FALSE)
  expect_identical(ex$tables$occasion_draws, od)
})
