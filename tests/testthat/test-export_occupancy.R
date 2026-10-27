# export_occupancy_data(): tabelas do esquema sheepdog-occupancy v1

sim_pred <- function() {
  suppressMessages(read_selection_tables(file.path(sim_root(), "tabelas")))
}
sim_recordings <- function() file.path(sim_root(), "gravacoes.csv")
remap <- function() list(remap_from = "N:/Arara/",
                         remap_to = paste0(sim_root(), "/"))

# Revisao simulada: veredito pelo score, sem cortar audio
sim_validation <- function(pred, modo = "random_detections", ...) {
  man <- suppressMessages(do.call(select_clips, c(
    list(pred, modo, threshold = 0.5, recordings = sim_recordings(),
         recording_duration = 180, ...), remap())))
  withr::with_seed(5, {
    p <- ifelse(is.na(man$confidence), 0.5, man$confidence)
    man$verdict <- ifelse(stats::runif(nrow(man)) < p, "positive", "negative")
  })
  man$verdict[1] <- "not_reviewed"
  man
}

export_sim <- function(dir = withr::local_tempdir(.local_envir = parent.frame()),
                       ...) {
  out <- suppressMessages(do.call(export_occupancy_data, c(
    list(dir, sim_pred(), recordings = sim_recordings()), remap(),
    list(...))))
  c(out, dir = dir)
}

read_export <- function(dir, tabela) {
  readr::read_csv(file.path(dir, paste0(tabela, ".csv")),
                  col_types = readr::cols(.default = "c"))
}

test_that("export_occupancy_data() writes the tables and the schema", {
  pred <- sim_pred()
  val <- sim_validation(pred)
  ex <- export_sim(validation = val, classifier = "sim v1")
  arquivos <- list.files(ex$dir)
  expect_setequal(arquivos, c("occasions.csv", "detections.csv", "scores.csv",
                              "validation.csv", "sites.csv", "schema.json"))
  sc <- jsonlite::read_json(file.path(ex$dir, "schema.json"))
  expect_identical(sc$schema, "sheepdog-occupancy")
  expect_identical(sc$schema_version, 1.1)
  expect_null(sc$occasion_covariates)
  expect_identical(sc$occasion_unit, "file")
  expect_identical(sc$classifier, "sim v1")
  expect_setequal(unlist(sc$sites), c("ARA", "BAI", "XAR"))
  expect_setequal(unlist(sc$species), unique(pred$species_code))
  for (nome in names(sc$tables)) {
    expect_identical(sc$tables[[nome]]$rows, nrow(ex$tables[[nome]]))
    expect_equal(nrow(read_export(ex$dir, nome)), nrow(ex$tables[[nome]]))
  }
  expect_null(sc$calibration)
})

test_that("sites and species stay JSON arrays with a single element", {
  pred <- dplyr::filter(sim_pred(), site == "ARA",
                        species_code == sim_especies[1])
  dir <- withr::local_tempdir()
  suppressMessages(do.call(export_occupancy_data, c(
    list(dir, pred, recordings = sim_recordings()), remap())))
  sc <- jsonlite::read_json(file.path(dir, "schema.json"))
  expect_type(sc$species, "list")
  expect_identical(unlist(sc$species), sim_especies[1])
  expect_type(sc$sites, "list")
})

test_that("occasions include recordings without predictions", {
  ex <- export_sim()
  oc <- ex$tables$occasions
  # 3 locais x 7 datas x 8 horas, uma ocasiao por gravacao
  expect_identical(nrow(oc), 3L * 7L * 8L)
  expect_false(anyDuplicated(oc[c("site", "occasion_id")]) > 0)
  com_pred <- dplyr::distinct(ex$tables$scores, site, occasion_id)
  expect_lt(nrow(com_pred), nrow(oc))
  expect_identical(nrow(dplyr::anti_join(com_pred, oc,
                                         by = c("site", "occasion_id"))), 0L)
  # noite: as gravacoes antes do meio-dia pertencem a noite anterior
  madrugada <- dplyr::filter(oc, recording_hour == "01")
  expect_true(all(as.Date(madrugada$night, "%Y%m%d") ==
                    as.Date(madrugada$recording_date, "%Y%m%d") - 1))
})

test_that("scores summarise the detections above min_confidence", {
  ex <- export_sim(min_confidence = 0.3)
  det <- ex$tables$detections
  expect_true(all(det$confidence >= 0.3))
  esperado <- det |>
    dplyr::group_by(site, occasion_id, species_code) |>
    dplyr::summarise(max_score = max(confidence), n_above_min = dplyr::n(),
                     .groups = "drop")
  sc <- dplyr::select(ex$tables$scores, site, occasion_id, species_code,
                      max_score, n_above_min)
  expect_equal(dplyr::arrange(sc, site, occasion_id, species_code),
               dplyr::arrange(esperado, site, occasion_id, species_code))
  expect_identical(ex$tables$scores$species,
                   sheepdog:::folder_name(ex$tables$scores$species_code))
})

test_that("minute occasions split each recording", {
  ex <- export_sim(occasion_unit = "minute", recording_duration = 180)
  oc <- ex$tables$occasions
  expect_identical(nrow(oc), 3L * 7L * 8L * 3L)
  expect_true(all(grepl("_m00[0-2]$", oc$occasion_id)))
  expect_setequal(oc$start, c(0, 60, 120))
  expect_true(all(ex$tables$detections$occasion_id %in% oc$occasion_id))
  expect_error(export_sim(occasion_unit = "minute"), "duration")
})

test_that("reviewed clips keep their design; recordings give the state", {
  pred <- sim_pred()
  det_val <- sim_validation(pred)
  rec_val <- sim_validation(pred, "random_recordings", recording_fraction = 0.1)
  ex <- export_sim(validation = dplyr::bind_rows(det_val, rec_val))
  v <- ex$tables$validation
  expect_identical(nrow(v), nrow(det_val))
  expect_true(all(v$sampling_mode == "random_detections"))
  expect_identical(v$tp, c(positive = 1L, negative = 0L)[v$verdict] |> unname())
  expect_true(all(!is.na(v$inclusion_prob)))
  rv <- ex$tables$recordings_verified
  expect_identical(nrow(rv), nrow(rec_val))
  expect_identical(rv$present, c(positive = 1L, negative = 0L)[rv$verdict] |>
                     unname())
  # as ocasioes revisadas existem em occasions.csv
  todas <- dplyr::bind_rows(v, rv) |> dplyr::distinct(site, occasion_id)
  expect_identical(nrow(dplyr::anti_join(todas, ex$tables$occasions,
                                         by = c("site", "occasion_id"))), 0L)
})

test_that("a validation file path is read", {
  pred <- sim_pred()
  f <- withr::local_tempfile(fileext = ".csv")
  readr::write_csv(sim_validation(pred), f)
  ex <- export_sim(validation = f)
  expect_identical(nrow(ex$tables$validation), nrow(readr::read_csv(
    f, show_col_types = FALSE)))
})

test_that("mismatched occasion units are reported", {
  pred <- sim_pred()
  val <- sim_validation(pred, occasion_unit = "minute")
  expect_warning(export_sim(validation = val), "occasion_unit")
})

test_that("site covariates are joined and missing sites reported", {
  cov <- data.frame(site = c("ARA", "XAR"), elevation = c(120, 95))
  expect_warning(ex <- export_sim(sites = cov), "BAI")
  s <- ex$tables$sites
  expect_identical(s$site, c("ARA", "BAI", "XAR"))
  expect_equal(s$elevation, c(120, NA, 95))
  expect_error(export_sim(sites = data.frame(local = "ARA")), "site")
})

test_that("an existing export is not overwritten by default", {
  dir <- withr::local_tempdir()
  export_sim(dir)
  expect_error(export_sim(dir), "overwrite")
  pred <- sim_pred()
  export_sim(dir, validation = sim_validation(pred), overwrite = TRUE)
  expect_true(file.exists(file.path(dir, "validation.csv")))
  # a nova exportacao nao herda tabelas da anterior
  export_sim(dir, overwrite = TRUE)
  expect_false(file.exists(file.path(dir, "validation.csv")))
})

test_that("predictions outside the list of recordings are kept, with a warning", {
  rec <- readr::read_csv(sim_recordings(), show_col_types = FALSE)
  f <- withr::local_tempfile(fileext = ".csv")
  readr::write_csv(rec[rec$local != "BAI", ], f)
  expect_warning(
    ex <- suppressMessages(do.call(export_occupancy_data, c(
      list(withr::local_tempdir(), sim_pred(), recordings = f), remap()))),
    "not in `recordings`")
  expect_true("BAI" %in% ex$tables$occasions$site)
})

test_that("repeated predictions are dropped, with a warning", {
  pred <- sim_pred()
  dobro <- dplyr::bind_rows(pred, pred[1:5, ])
  expect_warning(
    ex <- suppressMessages(do.call(export_occupancy_data, c(
      list(withr::local_tempdir(), dobro, recordings = sim_recordings()),
      remap()))),
    "5 prediction\\(s\\) repeat")
  expect_equal(ex$tables$detections, export_sim()$tables$detections)
})

test_that("one score copied to several rows of an occasion is reported", {
  # um score por gravacao x especie, copiado para tres linhas
  um <- dplyr::filter(sim_pred(), confidence >= 0.1) |>
    dplyr::distinct(site, begin_path, species_code, .keep_all = TRUE)
  copias <- dplyr::bind_rows(lapply(0:2, function(k) {
    dplyr::mutate(um, file_offset = file_offset + k * 3)
  }))
  expect_warning(
    suppressMessages(do.call(export_occupancy_data, c(
      list(withr::local_tempdir(), copias, recordings = sim_recordings()),
      remap()))),
    "same score in all of them")
  # dados sem copias nao geram o aviso
  expect_no_warning(export_sim())
})

test_that("invalid inputs are refused", {
  pred <- sim_pred()
  expect_error(export_occupancy_data(withr::local_tempdir(),
                                     dplyr::select(pred, -file_offset)),
               "file_offset")
  expect_error(export_sim(fit = stats::glm(am ~ wt, binomial, mtcars)),
               "brms")
  expect_error(export_sim(min_confidence = 1.1), "No prediction")
})

test_that("calibration draws cover every site x species on the grid", {
  skip_if_not_installed("arrow")
  pred <- sim_pred()
  especies <- unique(sheepdog:::folder_name(pred$species_code))
  # ajuste brms falso: so os niveis e as amostras importam
  fit <- structure(list(), class = "brmsfit",
                   sheepdog_levels = list(species = especies[-3],
                                          site = c("ARA", "XAR")))
  local_mocked_bindings(
    posterior_size = function(fit) 400L,
    grid_draws = function(fit, site, species, min_confidence, step,
                          draw_ids = NULL, keys = list()) {
      grade <- tidyr::expand_grid(
        species = factor(species),
        confidence = sheepdog:::score_grid(min_confidence, step))
      list(grid = grade,
           draws = outer(draw_ids / 1000, seq_len(nrow(grade)) / 1e4, "+"))
    })
  ex <- export_sim(fit = fit, n_draws = 50, grid_step = 0.05)
  dr <- arrow::read_parquet(file.path(ex$dir, "calibration_draws.parquet"))
  n_g <- length(sheepdog:::score_grid(0.1, 0.05))
  expect_identical(names(dr), c("draw", "site", "species", "grid_index",
                                "confidence", "p_tp"))
  # especie fora da calibracao fica de fora; local novo entra (BAI)
  pares <- dplyr::distinct(ex$tables$scores, site, species) |>
    dplyr::filter(species %in% especies[-3])
  expect_identical(nrow(dr), nrow(pares) * 50L * n_g)
  expect_identical(length(unique(dr$draw)), 50L)
  expect_true("BAI" %in% dr$site)
  expect_false(especies[3] %in% dr$species)
  expect_true(all(dplyr::count(dr, site, species, grid_index)$n == 50L))
  # amostra i, ponto k: o valor do mock
  um <- dplyr::filter(dr, site == "ARA", species == especies[1],
                      grid_index == 2)
  expect_equal(um$p_tp, um$draw / 1000 + 2 / 1e4)
  sc <- jsonlite::read_json(file.path(ex$dir, "schema.json"))
  expect_identical(sc$calibration$n_draws, 50L)
  expect_identical(sc$tables$calibration_draws$file, "calibration_draws.parquet")
  expect_identical(sc$tables$calibration_draws$rows, nrow(dr))
  # mesma semente, mesmas amostras; o RNG global fica intacto
  set.seed(1)
  antes <- .Random.seed
  ex2 <- export_sim(fit = fit, n_draws = 50, grid_step = 0.05)
  expect_identical(.Random.seed, antes)
  expect_identical(ex2$tables$calibration_draws$draw, dr$draw)
})

test_that("occasion covariates are joined by occasion_id or by recording", {
  base <- export_sim()$tables$occasions
  covs <- dplyr::transmute(base[-1, ], site, occasion_id,
                           temp = seq_len(nrow(base) - 1), period = "early")
  ex <- export_sim(occasion_covariates = covs)
  oc <- ex$tables$occasions
  expect_identical(names(oc), c(names(base), "temp", "period"))
  expect_true(is.na(oc$temp[1]))
  expect_equal(oc$temp[-1], seq_len(nrow(base) - 1))
  sc <- jsonlite::read_json(file.path(ex$dir, "schema.json"))
  expect_identical(unlist(sc$occasion_covariates), c("temp", "period"))
  # NA vazio no CSV
  expect_true(is.na(read_export(ex$dir, "occasions")$temp[1]))
  # pela gravacao, com o caminho do estilo Windows remapeado
  rec <- readr::read_csv(sim_recordings(), show_col_types = FALSE)
  pela_gravacao <- tibble::tibble(site = rec$local, source_audio = rec$caminho_audio,
                                  rain = 1)
  oc2 <- export_sim(occasion_covariates = pela_gravacao)$tables$occasions
  expect_true(all(oc2$rain == 1))
})

test_that("invalid occasion covariates are refused or reported", {
  base <- export_sim()$tables$occasions
  covs <- dplyr::transmute(base, site, occasion_id, temp = 1)
  expect_error(export_sim(occasion_covariates = dplyr::mutate(covs, night = "x")),
               "named like those of occasions.csv: night")
  expect_error(export_sim(occasion_covariates = rbind(covs, covs[1, ])),
               "more than one row")
  expect_error(export_sim(occasion_covariates = covs["site"]),
               "occasion_id` or `source_audio")
  extra <- rbind(covs, tibble::tibble(site = "ARA", occasion_id = "nope", temp = 2))
  expect_warning(export_sim(occasion_covariates = extra), "1 row\\(s\\)")
})

test_that("calibration keys reach occasions.csv and the draws, as text", {
  skip_if_not_installed("arrow")
  pred <- sim_pred()
  especies <- unique(sheepdog:::folder_name(pred$species_code))
  fit <- structure(list(data = data.frame(tp = 1, logit_conf = 0, month = "202201",
                                          period = "early")),
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
      # valor distinto por nivel de period, para conferir o casamento
      add <- if (identical(keys$period, "late")) 0.5 else 0
      list(grid = grade, draws = matrix(add, length(draw_ids), nrow(grade)))
    })
  base <- export_sim()$tables$occasions
  covs <- dplyr::transmute(base, site, occasion_id,
                           period = ifelse(night < "20220115", "early", "late"))
  ex <- export_sim(fit = fit, n_draws = 10, grid_step = 0.1,
                   occasion_covariates = covs,
                   calibration_keys = c("month", "period"))
  oc <- read_export(ex$dir, "occasions")
  expect_identical(unique(oc$month), "202201")
  expect_true(all(c("period", "month") %in% names(oc)))
  dr <- arrow::read_parquet(file.path(ex$dir, "calibration_draws.parquet"))
  expect_identical(names(dr), c("draw", "site", "species", "month", "period",
                                "grid_index", "confidence", "p_tp"))
  expect_type(dr$month, "character")
  # cada local x especie com predicoes tem todos os niveis das suas ocasioes
  niveis <- dplyr::distinct(ex$tables$occasions, site, month, period)
  pares <- dplyr::distinct(ex$tables$scores, site, species)
  esperado <- dplyr::inner_join(pares, niveis, by = "site",
                                relationship = "many-to-many")
  coberto <- dplyr::distinct(dr, site, species, month, period)
  expect_equal(nrow(dplyr::anti_join(esperado, coberto,
                                     by = names(esperado))), 0L)
  expect_true(all(dr$p_tp[dr$period == "late"] == 0.5))
  sc <- jsonlite::read_json(file.path(ex$dir, "schema.json"))
  expect_identical(unlist(sc$calibration$keys),
                   c("site", "species", "month", "period", "grid_index"))
  expect_identical(sc$calibration$new_levels, "uncertainty")
  expect_identical(unlist(sc$occasion_covariates), c("period", "month"))
})

test_that("calibration keys are checked", {
  fit <- structure(list(data = data.frame(tp = 1, logit_conf = 0, month = "1")),
                   class = "brmsfit")
  skip_if_not_installed("arrow")
  expect_error(export_sim(calibration_keys = "month"), "need a calibration")
  expect_error(export_sim(fit = fit, calibration_keys = "season"),
               "not in the model: season")
  expect_error(export_sim(fit = fit, calibration_keys = "site"),
               "always keys")
  fit2 <- fit; fit2$data$season <- "dry"
  expect_error(export_sim(fit = fit2, calibration_keys = "season"),
               "not a column of `occasion_covariates`")
})

test_that("the shared 1.1 fixture keeps its contract", {
  skip_if_not_installed("arrow")
  dir <- test_path("fixtures", "export-1.1")
  sc <- jsonlite::read_json(file.path(dir, "schema.json"), simplifyVector = TRUE)
  expect_identical(sc$schema_version, 1.1)
  chaves <- setdiff(sc$calibration$keys, c("site", "species", "grid_index"))
  expect_identical(chaves, "month")
  oc <- read_export(dir, "occasions")
  expect_true(all(c(sc$occasion_covariates, chaves) %in% names(oc)))
  dr <- arrow::read_parquet(file.path(dir, "calibration_draws.parquet"))
  expect_type(dr$month, "character")
  # toda ocasiao com predicao acha suas amostras pela chave
  com_pred <- dplyr::semi_join(oc, read_export(dir, "scores"),
                               by = c("site", "occasion_id"))
  falta <- dplyr::anti_join(dplyr::distinct(com_pred, site, month),
                            dplyr::distinct(dr, site, month),
                            by = c("site", "month"))
  expect_equal(nrow(falta), 0L)
  expect_equal(nrow(dr), sc$tables$calibration_draws$rows)
})
