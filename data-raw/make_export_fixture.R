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
