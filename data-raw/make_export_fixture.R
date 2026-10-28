# Fixture of the sheepdog-occupancy schema, version 1.1, shared with crywolf:
# an export of the example data with an occasion covariate and a calibration
# by month (tp ~ logit_conf + (1 | month)), written to
# tests/testthat/fixtures/export-1.1/. crywolf copies the folder to its own
# tests, so that both packages test the same files.
# Run from the repository root (needs brms with a Stan backend and arrow):
#   Rscript data-raw/make_export_fixture.R
devtools::load_all(quiet = TRUE)
suppressPackageStartupMessages(library(dplyr))

ex <- system.file("extdata", "example", package = "sheepdog")
out <- "tests/testthat/fixtures/export-1.1"
especie <- "phy_cuv"

det <- read_selection_tables(file.path(ex, "birdnet")) |>
  filter(folder_name(species_code) == especie)
val <- read_validations(list.files(file.path(ex, "validation"), full.names = TRUE),
                        keep = "source_audio") |>
  filter(species == especie) |>
  mutate(month = substr(regmatches(source_audio,
                                   regexpr("[0-9]{8}", source_audio)), 1, 6))
f <- tp ~ logit_conf + (1 | month)
fit <- fit_calibration(val, f, engine = "brms",
                       prior = calibration_prior(f, val),
                       chains = 4, iter = 2000, refresh = 0, seed = 2026,
                       control = list(adapt_delta = 0.99))

# covariavel de ocasiao: hora da gravacao como numero (so para o teste)
rec <- readr::read_csv(file.path(ex, "recordings.csv"), show_col_types = FALSE)
covs <- tibble(site = rec$site, source_audio = rec$source_audio,
               hour = as.integer(substr(regmatches(rec$source_audio,
                                                   regexpr("_[0-9]{6}\\.", rec$source_audio)),
                                        2, 3)))

unlink(out, recursive = TRUE)
export_occupancy_data(out, det, recordings = file.path(ex, "recordings.csv"),
                      validation = list.files(file.path(ex, "validation"),
                                              full.names = TRUE),
                      fit = fit, occasion_covariates = covs,
                      calibration_keys = "month",
                      n_draws = 20, grid_step = 0.05, classifier = "example",
                      overwrite = TRUE)
# a data de criacao e a versao mudariam a cada execucao
sc <- jsonlite::read_json(file.path(out, "schema.json"))
sc$created <- "2026-10-27T00:00:00-0400"
sc$sites <- I(unlist(sc$sites)); sc$species <- I(unlist(sc$species))
sc$occasion_covariates <- I(unlist(sc$occasion_covariates))
sc$calibration$keys <- I(unlist(sc$calibration$keys))
jsonlite::write_json(sc, file.path(out, "schema.json"), auto_unbox = TRUE,
                     pretty = TRUE, digits = NA)

# Fixture 1.2: a 1.1 com occasion_draws.parquet ("sample", seed 2026, 20
# draws), escrita em tests/testthat/fixtures/export-1.2/. Para exercitar a
# ordem do sorteio, os pontos da grade acima de 0,5 de NHE x 202112 foram
# apagados do parquet da calibracao: ocasioes desse mes tem predicoes com e
# sem draws (e ficam nao pontuadas). Isso nao acontece num export real.
out2 <- "tests/testthat/fixtures/export-1.2"
unlink(out2, recursive = TRUE)
dir.create(out2)
file.copy(list.files(out, full.names = TRUE), out2)
cal <- arrow::read_parquet(file.path(out2, "calibration_draws.parquet"))
cal <- filter(cal, !(site == "NHE" & month == "202112" & confidence > 0.5))
arrow::write_parquet(cal, file.path(out2, "calibration_draws.parquet"))
# so a especie da fixture nos clipes revisados, para caber no tarball
v <- readr::read_csv(file.path(out2, "validation.csv"), na = "",
                     col_types = readr::cols(.default = "c"))
v <- filter(v, species == especie)
readr::write_csv(v, file.path(out2, "validation.csv"), na = "")
sc <- jsonlite::read_json(file.path(out2, "schema.json"))
sc$tables$calibration_draws$rows <- nrow(cal)
sc$tables$validation$rows <- nrow(v)
sc$sites <- I(unlist(sc$sites)); sc$species <- I(unlist(sc$species))
sc$occasion_covariates <- I(unlist(sc$occasion_covariates))
sc$calibration$keys <- I(unlist(sc$calibration$keys))
jsonlite::write_json(sc, file.path(out2, "schema.json"), auto_unbox = TRUE,
                     pretty = TRUE, digits = NA)
suppressWarnings(occasion_draws(out2, rule = "sample", n_draws = 20,
                                seed = 2026))

# Fixture 1.3: calibracao com covariavel continua da ocasiao
# (tp ~ logit_conf + temp_z), escrita em tests/testthat/fixtures/export-1.3/.
# A temperatura e simulada por data de gravacao (so para o teste) e
# padronizada antes do ajuste; a padronizacao vai para o schema.json. Sem
# grade de calibracao: as versoes (20, "sample", seed 2026) saem do export.
out3 <- "tests/testthat/fixtures/export-1.3"
datas <- sort(unique(regmatches(rec$source_audio,
                                regexpr("[0-9]{8}", rec$source_audio))))
temp_dia <- withr::with_seed(2026, tibble(
  data = datas, temp = round(stats::rnorm(length(datas), 22, 3), 1)))
centro <- mean(temp_dia$temp)
escala <- stats::sd(temp_dia$temp)
covs3 <- tibble(site = rec$site, source_audio = rec$source_audio,
                data = regmatches(rec$source_audio,
                                  regexpr("[0-9]{8}", rec$source_audio))) |>
  left_join(temp_dia, by = "data") |>
  mutate(temp_z = round((temp - centro) / escala, 4)) |>
  select(site, source_audio, temp_z)
val3 <- read_validations(list.files(file.path(ex, "validation"), full.names = TRUE),
                         keep = "source_audio") |>
  filter(species == especie) |>
  mutate(source_audio = gsub("\\\\", "/", source_audio),
         data = regmatches(source_audio, regexpr("[0-9]{8}", source_audio))) |>
  left_join(temp_dia, by = "data") |>
  mutate(temp_z = (temp - centro) / escala)
f3 <- tp ~ logit_conf + temp_z
fit3 <- fit_calibration(val3, f3, engine = "brms",
                        prior = calibration_prior(f3, val3),
                        chains = 4, iter = 2000, refresh = 0, seed = 2026)

unlink(out3, recursive = TRUE)
export_occupancy_data(out3, det, recordings = file.path(ex, "recordings.csv"),
                      validation = list.files(file.path(ex, "validation"),
                                              full.names = TRUE),
                      fit = fit3, occasion_covariates = covs3,
                      n_draws = 20, n_versions = 20, rule = "sample",
                      covariate_scaling = list(temp_z = c(center = centro,
                                                          scale = escala)),
                      classifier = "example", overwrite = TRUE)
# so a especie da fixture nos clipes revisados, como na 1.2
v <- readr::read_csv(file.path(out3, "validation.csv"), na = "",
                     col_types = readr::cols(.default = "c"))
v <- filter(v, species == especie)
readr::write_csv(v, file.path(out3, "validation.csv"), na = "")
sc <- jsonlite::read_json(file.path(out3, "schema.json"))
sc$tables$validation$rows <- nrow(v)
sc$created <- "2026-10-28T00:00:00-0400"
sc$sites <- I(unlist(sc$sites)); sc$species <- I(unlist(sc$species))
sc$occasion_covariates <- I(unlist(sc$occasion_covariates))
sc$calibration$keys <- I(unlist(sc$calibration$keys))
sc$calibration$covariates <- I(unlist(sc$calibration$covariates))
sc$occasion_draws$species <- I(unlist(sc$occasion_draws$species))
jsonlite::write_json(sc, file.path(out3, "schema.json"), auto_unbox = TRUE,
                     pretty = TRUE, digits = NA)
