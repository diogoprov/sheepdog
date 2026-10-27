# Contrato de dados com o crywolf: todo export segue o esquema
# sheepdog-occupancy descrito em vignette("crywolf-integration"). Espelho de
# tests/testthat/test-read_sheepdog.R do crywolf: aqui se confere o que o
# sheepdog escreve; quando o crywolf esta instalado, que ele le cada export.

colunas <- list(
  occasions = c("site", "occasion_id", "source_audio", "recording_date",
                "recording_hour", "night", "start", "duration"),
  detections = c("site", "occasion_id", "species_code", "species",
                 "file_offset", "confidence"),
  scores = c("site", "occasion_id", "species_code", "species", "max_score",
             "n_above_min"),
  validation = c("site", "occasion_id", "species_code", "species",
                 "clip_start", "clip_end", "confidence", "sampling_mode",
                 "inclusion_prob", "n_detections_occasion", "verdict", "tp"),
  recordings_verified = c("site", "occasion_id", "species_code", "species",
                          "inclusion_prob", "verdict", "present")
)
veredito <- c(positive = 1L, negative = 0L)

ler_tabela <- function(dir, nome) {
  readr::read_csv(file.path(dir, paste0(nome, ".csv")),
                  col_types = readr::cols(.default = "c"), na = "")
}
numero <- function(x) as.numeric(x)
par <- function(d) paste(d$site, d$occasion_id, sep = "\r")

# Confere um export contra o contrato; devolve o schema lido
expect_contract <- function(dir) {
  sc <- jsonlite::read_json(file.path(dir, "schema.json"), simplifyVector = TRUE)
  expect_identical(sc$schema, "sheepdog-occupancy")
  expect_identical(floor(sc$schema_version), 1)
  expect_true(all(c("created", "sheepdog_version", "occasion_unit",
                    "min_confidence", "dawn_hour", "sites", "species",
                    "tables") %in% names(sc)))
  expect_true(sc$occasion_unit %in% c("file", "minute"))
  # cada tabela listada existe, com o numero de linhas declarado
  for (nome in names(sc$tables)) {
    f <- file.path(dir, sc$tables[[nome]]$file)
    expect_true(file.exists(f), label = f)
    if (grepl("\\.csv$", f)) {
      expect_identical(nrow(ler_tabela(dir, nome)),
                       as.integer(sc$tables[[nome]]$rows), label = nome)
    }
  }
  expect_true(all(c("occasions", "detections", "scores") %in% names(sc$tables)))

  # occasions.csv: colunas fixas, depois as covariaveis declaradas
  oc <- ler_tabela(dir, "occasions")
  fixas <- colunas$occasions
  expect_identical(names(oc)[seq_along(fixas)], fixas)
  extras <- setdiff(names(oc), fixas)
  expect_identical(extras, as.character(sc$occasion_covariates))
  expect_false(anyDuplicated(par(oc)) > 0)
  expect_setequal(unique(oc$site), sc$sites)
  ok <- !is.na(oc$recording_date)
  expect_true(all(grepl("^\\d{8}$", oc$recording_date[ok])))
  expect_true(all(grepl("^\\d{8}$", oc$night[ok])))
  expect_true(all(grepl("^\\d{2}$", oc$recording_hour[ok])))

  # detections.csv e scores.csv
  det <- ler_tabela(dir, "detections")
  expect_identical(names(det), colunas$detections)
  expect_true(all(par(det) %in% par(oc)))
  expect_true(all(numero(det$confidence) >= sc$min_confidence))
  expect_true(all(det$species_code %in% sc$species))
  expect_identical(det$species, folder_name(det$species_code))
  sco <- ler_tabela(dir, "scores")
  expect_identical(names(sco), colunas$scores)
  resumo <- det |>
    dplyr::mutate(confidence = numero(confidence)) |>
    dplyr::summarise(max_score = max(confidence), n_above_min = dplyr::n(),
                     .by = c(site, occasion_id, species_code, species))
  m <- match(paste(par(sco), sco$species_code),
             paste(par(resumo), resumo$species_code))
  expect_false(anyNA(m))
  expect_identical(nrow(sco), nrow(resumo))
  expect_equal(numero(sco$max_score), resumo$max_score[m])
  expect_equal(as.integer(sco$n_above_min), resumo$n_above_min[m])

  # validation.csv e recordings_verified.csv
  if ("validation" %in% names(sc$tables)) {
    val <- ler_tabela(dir, "validation")
    expect_identical(names(val)[seq_along(colunas$validation)], colunas$validation)
    expect_true(all(setdiff(names(val), colunas$validation) %in%
                      c("reviewer", "n_reviewers")))
    expect_true(all(val$sampling_mode %in% c("top", "random_detections")))
    expect_true(all(val$verdict %in% c(names(veredito), "not_reviewed",
                                       "clip_missing", "disagreement")))
    expect_identical(as.integer(val$tp), unname(veredito[val$verdict]))
    aleat <- val$sampling_mode == "random_detections"
    expect_false(anyNA(val$inclusion_prob[aleat]))
    expect_true(all(is.na(val$inclusion_prob[!aleat])))
    expect_true(all(par(val) %in% par(oc)))
  }
  if ("recordings_verified" %in% names(sc$tables)) {
    rv <- ler_tabela(dir, "recordings_verified")
    expect_identical(names(rv), colunas$recordings_verified)
    expect_identical(as.integer(rv$present), unname(veredito[rv$verdict]))
    expect_true(all(par(rv) %in% par(oc)))
  }
  if ("sites" %in% names(sc$tables)) {
    s <- ler_tabela(dir, "sites")
    expect_identical(names(s)[1], "site")
    expect_setequal(s$site, sc$sites)
  }

  # calibration_draws.parquet: chaves de texto que cobrem as ocasioes
  if (!is.null(sc$calibration) && requireNamespace("arrow", quietly = TRUE)) {
    cal <- as.data.frame(arrow::read_parquet(
      file.path(dir, "calibration_draws.parquet")))
    chaves <- sc$calibration$keys
    expect_identical(chaves[c(1, 2, length(chaves))],
                     c("site", "species", "grid_index"))
    expect_identical(names(cal), c("draw", chaves, "confidence", "p_tp"))
    extras_cal <- setdiff(chaves, c("site", "species", "grid_index"))
    for (k in c("site", "species", extras_cal)) expect_type(cal[[k]], "character")
    expect_true(all(extras_cal %in% extras))
    expect_false(anyDuplicated(cal[c("draw", chaves)]) > 0)
    expect_true(all(cal$p_tp >= 0 & cal$p_tp <= 1))
    expect_identical(length(unique(cal$draw)), as.integer(sc$calibration$n_draws))
    expect_equal(min(cal$confidence), sc$calibration$grid_min)
    # cada nivel de chave das ocasioes de um local com predicoes tem draws
    for (k in extras_cal) {
      precisa <- dplyr::distinct(oc[oc$site %in% sco$site, ], site, nivel = .data[[k]])
      tem <- dplyr::distinct(cal, site, nivel = .data[[k]])
      expect_identical(nrow(dplyr::anti_join(precisa, tem, by = c("site", "nivel"))),
                       0L, label = paste("levels of", k))
    }
  }

  # occasion_draws.parquet (esquema 1.2)
  if (!is.null(sc$occasion_draws) && requireNamespace("arrow", quietly = TRUE)) {
    expect_gte(sc$schema_version, 1.2)
    # como data frame: uma Table do arrow manteria o arquivo mapeado, e o
    # Windows nao deixaria o occasion_draws() seguinte sobrescreve-lo
    od <- as.data.frame(arrow::read_parquet(file.path(dir, sc$occasion_draws$file)))
    expect_identical(names(od), c("draw", "site", "occasion_id", "species", "y"))
    # int32 vira integer; int64 viraria double ou integer64
    expect_true(is.integer(od$y) && !inherits(od$y, "integer64"))
    expect_true(sc$occasion_draws$rule %in% c("sample", "threshold"))
    expect_identical(length(unique(od$draw)), as.integer(sc$occasion_draws$n_draws))
    expect_setequal(unique(od$species), sc$occasion_draws$species)
    expect_true(all(od$y %in% c(0L, 1L, NA)))
    # uma linha por ocasiao com predicao da especie, em cada draw
    com_pred <- unique(par(det[det$species %in% sc$occasion_draws$species, ]))
    for (d in unique(od$draw)) {
      expect_setequal(par(od[od$draw == d, ]), com_pred)
    }
  }
  invisible(sc)
}

# Exports a conferir: o do exemplo (sem calibracao), um simulado com os tres
# desenhos e as fixtures compartilhadas com o crywolf (1.1 e 1.2)
export_exemplo <- function(env = parent.frame()) {
  ex <- system.file("extdata", "example", package = "sheepdog")
  dir <- withr::local_tempdir(.local_envir = env)
  det <- suppressMessages(read_selection_tables(file.path(ex, "birdnet")))
  suppressMessages(export_occupancy_data(
    dir, det, recordings = file.path(ex, "recordings.csv"),
    validation = list.files(file.path(ex, "validation"), full.names = TRUE),
    overwrite = TRUE))
  dir
}
export_simulado <- function(env = parent.frame()) {
  pred <- sim_pred()
  val <- dplyr::bind_rows(
    sim_validation(pred),
    sim_validation(pred, "random_recordings", recording_fraction = 0.1))
  sites <- data.frame(site = sort(unique(pred$site)), forest = c(0.2, 0.5, 0.9))
  export_sim(withr::local_tempdir(.local_envir = env), validation = val,
             sites = sites)$dir
}
fixture <- function(nome) test_path("fixtures", nome)

test_that("exports follow the documented contract", {
  expect_contract(export_exemplo())
  sc <- expect_contract(export_simulado())
  expect_true(all(c("validation", "recordings_verified", "sites") %in%
                    names(sc$tables)))
  sc <- expect_contract(fixture("export-1.1"))
  expect_identical(sc$schema_version, 1.1)
  expect_identical(sc$calibration$keys, c("site", "species", "month", "grid_index"))
  sc <- expect_contract(fixture("export-1.2"))
  expect_identical(sc$schema_version, 1.2)
})

test_that("occasion_draws() keeps an export within the contract", {
  skip_if_not_installed("arrow")
  dir <- withr::local_tempdir()
  file.copy(list.files(fixture("export-1.1"), full.names = TRUE), dir)
  for (regra in c("threshold", "sample")) {
    suppressMessages(suppressWarnings(occasion_draws(dir, rule = regra, p_min = 0.5,
                                                     n_draws = 5, seed = 3)))
    sc <- expect_contract(dir)
    expect_identical(sc$occasion_draws$rule, regra)
  }
})

# Lado do crywolf: le cada export, com os identificadores como texto e uma
# linha de fp_aggregate() por ocasiao
test_that("crywolf reads every export", {
  skip_if_not_installed("crywolf")
  skip_if(!"fp_read_sheepdog" %in% getNamespaceExports("crywolf"),
          "this crywolf has no fp_read_sheepdog()")
  dirs <- list(exemplo = export_exemplo(), simulado = export_simulado(),
               `1.1` = fixture("export-1.1"), `1.2` = fixture("export-1.2"))
  for (nome in names(dirs)) {
    dir <- dirs[[nome]]
    sp <- ler_tabela(dir, "detections")$species[1]
    x <- tryCatch(suppressWarnings(suppressMessages(
      crywolf::fp_read_sheepdog(dir, species = sp))), error = identity)
    skip_if(inherits(x, "error") && grepl("[Vv]ersion", conditionMessage(x)),
            paste("the installed crywolf does not read schema", nome))
    expect_s3_class(x, "fp_sheepdog")
    oc <- ler_tabela(dir, "occasions")
    expect_identical(x$occasions$site, oc$site, label = nome)
    expect_identical(x$occasions$occasion_id, oc$occasion_id, label = nome)
    expect_true(all(x$detections$species == sp))
    auto <- crywolf::fp_aggregate(x$occasions, x$detections, threshold = 0.5,
                                  by = c("site", "occasion_id"),
                                  validation = x$validation)
    expect_identical(nrow(auto), nrow(oc), label = nome)
  }
})

test_that("crywolf reads the calibration keys and occasion_draws.parquet", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("crywolf", minimum_version = "2.0.0.9000")
  dir <- fixture("export-1.2")
  sc <- jsonlite::read_json(file.path(dir, "schema.json"), simplifyVector = TRUE)
  x <- suppressWarnings(crywolf::fp_read_sheepdog(dir, species = "phy_cuv"))
  expect_type(x$occasions$month, "character")
  expect_true(is.numeric(x$occasions$hour))
  # com as configuracoes gravadas, as versoes sao as do parquet
  v <- suppressWarnings(crywolf::fp_draws_data(
    x, rule = sc$occasion_draws$rule, n_draws = sc$occasion_draws$n_draws,
    seed = sc$occasion_draws$seed))
  od <- as.data.frame(arrow::read_parquet(file.path(dir, "occasion_draws.parquet")))
  expect_identical(attr(v, "draws"), sort(unique(od$draw)))
  for (j in seq_along(v)) {
    cw <- v[[j]]$auto
    g <- od[od$draw == attr(v, "draws")[j], ]
    # pontuadas: o mesmo y; nao pontuadas (y vazio): fora do crywolf ou NA
    pont <- g[!is.na(g$y), ]
    m <- match(par(pont), par(cw))
    expect_false(anyNA(m))
    expect_identical(as.integer(cw$y[m]), pont$y)
    expect_true(all(is.na(cw$y[match(par(g[is.na(g$y), ]), par(cw))])))
    expect_true(all(cw$y[!par(cw) %in% par(g)] == 0))
  }
})
