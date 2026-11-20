# Exports the Curiango data in the sheepdog-occupancy schema (version 1.1),
# one folder per classifier, with the calibration draws of a Bayesian
# calibration fitted to the ground-truth test set. This is the test case
# of phase 1 of dev/roadmap-integration.md (Monte Carlo propagation of
# the calibration into the occupancy model).
# Run from the repository root:
#   Rscript dev/benchmarks/curiango-export.R [DATA_DIR OUTPUT_DIR]
# DATA_DIR holds the Zenodo files of inst/benchmarks/curiango-source-manifest.json
# (downloaded and checked if absent). OUTPUT_DIR defaults to
# dev/benchmarks/results/curiango-export (ignored by git).
# Dependencies: devtools, dplyr, readr, tibble, brms (with cmdstanr or rstan),
# posterior, arrow, jsonlite.
#
# What the deposit has, and how it maps on the schema:
# * df_night_clean.txt: one to 20 rows per one-minute recording, with the
#   scores of both classifiers, but no window offset. The recording is the
#   occasion (occasion_unit = "file"). Within a minute, every row with a
#   score holds the SAME value (all minutes, both classifiers): the rows are
#   copies of one score, not independent windows. Each minute therefore
#   gives at most one detection per distinct score (file_offset = 0 for the
#   first, 3 s for the next, a placeholder); exporting every row would count
#   the same evidence several times when detections are drawn one by one
#   (crywolf::fp_draws_data(rule = "sample")). scores.csv is exact.
# * CM-<classifier>.txt: the ground-truth test set, about 1% of the
#   recordings drawn in proportion to the effort of each site and annotated
#   by ear in 3-s windows. Every recording becomes a row of
#   recordings_verified.csv (present if any window holds the species). The
#   calibration has to be on the unit of the occasion: the score exported
#   per minute is the minute score of df_night_clean.txt (it matches the
#   highest window score of the test set in only about half of the
#   minutes), so a window-level calibration would give the minute far too
#   low a probability. Each test minute with a minute score >=
#   min_confidence therefore becomes one reviewed clip of validation.csv
#   (the whole minute, verdict = the state of the minute), and the
#   calibration is fitted to these clips. Since the recordings were drawn
#   without looking at the scores, the clips follow the "random_detections"
#   design (observation confirmation); the inclusion probability is the
#   share of the recordings of the site in the test set.
# * Nightly weather (means of the night at each recorder) and minute
#   acoustic indices are occasion covariates (schema 1.1): columns
#   night_site_id, temp, rh, moon, bio and aci of occasions.csv.
#
# Seasonal sensitivity analysis (third argument "season"): the posterior
# predictive check (curiango-ppc.R) showed that P(TP | score) changes with
# the month, since a calibration also absorbs the calling activity of the
# species. With "season", the candidates gain a random intercept of the
# month of the recording (YYYYMM): logit_conf + (1 | month) and
# logit_conf + (1 | site) + (1 | month); the choice by log-loss is made
# among them (the comparison table keeps the models without month). The
# calibration draws then depend on the month, a calibration key of the
# export (calibration_keys = "month", schema 1.1): calibration_draws.parquet
# and occasions.csv gain a `month` column (YYYYMM of the recording date).
# Months without test minutes take a new level drawn from the month
# variance. This
# is a sensitivity analysis, not the recommended calibration: a month effect
# mixes calling activity into P(TP) and uses the test minutes twice (see
# dev/roadmap-integration.md, phase 2).
#   Rscript dev/benchmarks/curiango-export.R DATA_DIR OUTPUT_DIR season
# CALIB_MODEL=<model> forces one of the candidates instead of the
# one-standard-error rule (e.g. CALIB_MODEL=m3_site_month).
#
# Calibration on a night covariate (CALIB_COVARIATE=temp, rh or moon): the
# chosen model gains the night mean of that covariate, standardised over
# the site-nights as in the occupancy model (moon on the log scale), as a
# continuous covariate (`<covariate>_z`, schema 1.3). A calibration that
# ignores a covariate of occupancy gives the same P(TP | score) to nights
# with few and many calling animals, which can leak into the occupancy
# coefficient of that covariate. The versions of the detections are then
# drawn at export (N_VERSIONS, default 20, rule "sample"); reading them
# needs crywolf >= 2.1.0.9000. ADAPT_DELTA (default 0.8) is passed to brms.
#   CALIB_COVARIATE=temp Rscript dev/benchmarks/curiango-export.R DATA_DIR OUTPUT_DIR
args <- commandArgs(trailingOnly = TRUE)
data_dir <- if (length(args)) args[1] else "dev/benchmarks/data/curiango"
out <- if (length(args) > 1) args[2] else "dev/benchmarks/results/curiango-export"
season <- length(args) > 2 && args[3] == "season"
devtools::load_all(".", quiet = TRUE)
suppressPackageStartupMessages({library(dplyr); library(readr); library(tibble)})

manifest <- jsonlite::fromJSON("inst/benchmarks/curiango-source-manifest.json")
for (i in seq_len(nrow(manifest$files))) {
  f <- manifest$files[i, ]
  path <- file.path(data_dir, f$file)
  if (!file.exists(path)) {
    dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
    download.file(f$url, path, mode = "wb", method = "libcurl")
  }
  stopifnot(paste0("md5:", tools::md5sum(path)) == f$checksum)
}

species_code <- "Nyctidromus albicollis_nyc-alb"
min_confidence <- 0.1
seed <- 2026
audio <- function(site, key) file.path("curiango", site, paste0(site, "_", key, ".wav"))

raw <- read_tsv(file.path(data_dir, "df_night_clean.txt"), show_col_types = FALSE,
                col_types = cols(DataHora_Formatada = "c"))
recordings <- raw |>
  distinct(site = Site, key = DataHora_Formatada) |>
  mutate(source_audio = audio(site, key))
covariates <- raw |>
  distinct(Site, DataHora_Formatada, .keep_all = TRUE) |>
  group_by(night_site_id) |>
  mutate(temp = mean(Temp), rh = mean(RH), moon = mean(moon_illumination)) |>
  ungroup() |>
  transmute(site = Site, source_audio = audio(Site, DataHora_Formatada),
            night_site_id, temp, rh, moon, bio = BIO, aci = ACI)

# covariavel da noite na calibracao (schema 1.3), padronizada sobre as
# noites-local como no modelo de ocupacao
calib_cov <- Sys.getenv("CALIB_COVARIATE")
cov_scaling <- NULL
if (nzchar(calib_cov)) {
  stopifnot(calib_cov %in% c("temp", "rh", "moon"))
  tr <- if (calib_cov == "moon") log else identity
  noites <- distinct(covariates, night_site_id, .keep_all = TRUE)
  centro <- mean(tr(noites[[calib_cov]]))
  escala <- sd(tr(noites[[calib_cov]]))
  cov_z <- paste0(calib_cov, "_z")
  covariates[[cov_z]] <- (tr(covariates[[calib_cov]]) - centro) / escala
  cov_scaling <- stats::setNames(list(c(center = centro, scale = escala)), cov_z)
}
n_versions <- as.integer(Sys.getenv("N_VERSIONS", "20"))

# Conjunto de teste (PI_FILE, TEST_SET): o arquivo pi_verificados.csv de
# dev/fase2/curiango_pi_ct03.R tem, por minuto verificado, o conjunto
# (stage: "ct12" = sorteio ct01+ct02, "ct03" = complementacao) e as
# probabilidades de inclusao estimadas (pi1 do sorteio; pi do conjunto todo).
# TEST_SET = "ct12" (padrao com PI_FILE) usa so o sorteio, com pi1;
# TEST_SET = "all" usa os 1.199 minutos, com pi. Sem PI_FILE, o
# comportamento antigo (todos os minutos, inclusao = fracao do local).
pi_file <- Sys.getenv("PI_FILE")
if (nzchar(pi_file)) {
  test_set <- Sys.getenv("TEST_SET", "ct12")
  pis <- read_csv(pi_file, show_col_types = FALSE,
                  col_types = cols(time = "c")) |>
    mutate(key = format(as.POSIXct(time, tz = "UTC"), "%Y%m%d_%H%M%S"))
  if (test_set != "all") pis <- filter(pis, stage == test_set)
  pis <- transmute(pis, site, key,
                   pi_minute = if (test_set == "all") pi else pi1)
  message("Test set ", test_set, ": ", nrow(pis), " minutes")
}

# mes da gravacao (YYYYMM), a partir do nome do arquivo
month_of <- function(path) {
  substr(regmatches(path, regexpr("[0-9]{8}_[0-9]{6}", path)), 1, 6)
}

classifiers <- c(Custom = "conf_div", BirdNET = "conf_preb")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
summary_rows <- list()

for (cl in names(classifiers)) {
  message("== ", cl)
  score <- classifiers[[cl]]
  detections <- raw |>
    filter(.data[[score]] >= min_confidence) |>
    # linhas repetidas do mesmo minuto sao copias do mesmo score
    distinct(Site, DataHora_Formatada, across(all_of(score)), .keep_all = TRUE) |>
    group_by(Site, DataHora_Formatada) |>
    mutate(window = row_number()) |>
    ungroup() |>
    transmute(site = Site, species_code = species_code,
              confidence = .data[[score]],
              begin_path = audio(Site, DataHora_Formatada),
              file_offset = 3 * (window - 1))

  cm <- read_csv(file.path(data_dir, paste0("CM-", if (cl == "BirdNET") "BirdNet" else cl, ".txt")),
                 show_col_types = FALSE)
  cm$key <- vapply(strsplit(cm$filename, "_"),
                   function(p) paste(p[length(p) - 1], p[length(p)], sep = "_"),
                   character(1))
  cm <- cm |>
    mutate(site = Site, source_audio = audio(Site, key),
           occasion_id = tools::file_path_sans_ext(basename(source_audio))) |>
    semi_join(recordings, by = c("site", "key"))
  # probabilidade de inclusao: gravacoes do conjunto de teste / gravacoes do local
  inclusion <- cm |>
    distinct(site, key) |>
    count(site, name = "n_test") |>
    left_join(count(recordings, site, name = "n_total"), by = "site") |>
    mutate(inclusion_prob = n_test / n_total)
  if (nzchar(pi_file)) {
    # conjuntos de teste reconstruidos (dev/fase2/PLANO-v1-markov.md,
    # 19/11/2026): so os minutos do conjunto pedido, com a probabilidade de
    # inclusao estimada de cada minuto
    cm <- cm |>
      inner_join(pis, by = c("site", "key")) |>
      mutate(inclusion_prob = pi_minute)
    inclusion <- distinct(cm, site, key, inclusion_prob)
  }
  annotated <- cm |>
    group_by(site, occasion_id, source_audio) |>
    summarise(present = any(compau_annotation == 1), .groups = "drop") |>
    left_join(if (nzchar(pi_file)) {
      cm |> distinct(site, occasion_id, inclusion_prob)
    } else select(inclusion, site, inclusion_prob),
    by = if (nzchar(pi_file)) c("site", "occasion_id") else "site") |>
    transmute(site, species_code = species_code, occasion_id, source_audio,
              clip_start = 0, clip_end = 60, confidence = NA_real_,
              sampling_mode = "random_recordings", inclusion_prob,
              n_detections_occasion = NA_integer_,
              verdict = if_else(present, "positive", "negative"))
  # um clipe por minuto de teste com score do minuto >= min_confidence
  minutes <- annotated |>
    inner_join(transmute(detections, site, source_audio = begin_path,
                         minute_score = confidence),
               by = c("site", "source_audio")) |>
    mutate(confidence = minute_score, sampling_mode = "random_detections",
           n_detections_occasion = 1L) |>
    select(-minute_score)
  validation <- bind_rows(minutes, annotated)

  # calibracao: modelo escolhido por log-loss com folds por gravacao, depois
  # ajustado com brms e a priori explicita de calibration_prior()
  val_cal <- minutes |>
    transmute(site = factor(site), species = factor(folder_name(species_code)),
              confidence, logit_conf = safe_logit(confidence),
              tp = as.integer(verdict == "positive"), source_audio,
              month = factor(month_of(source_audio)))
  if (nzchar(calib_cov)) {
    val_cal <- left_join(val_cal, distinct(covariates, source_audio,
                                           across(all_of(cov_z))),
                         by = "source_audio")
    stopifnot(!anyNA(val_cal[[cov_z]]))
  }
  if (season) {
    models <- list(m0_global = tp ~ logit_conf,
                   m1_site_intercept = tp ~ logit_conf + (1 | site),
                   m2_month = tp ~ logit_conf + (1 | month),
                   m3_site_month = tp ~ logit_conf + (1 | site) + (1 | month))
    comparison <- suppressWarnings(compare_calibration_models(
      val_cal, models = models, fold_group = "source_audio", seed = seed))
    chosen <- select_calibration_model(
      filter(comparison, grepl("month", model)), rule = "one_se_logloss")
  } else {
    comparison <- suppressWarnings(compare_calibration_models(
      val_cal, fold_group = "source_audio", seed = seed))
    chosen <- select_calibration_model(comparison, rule = "one_se_logloss")
  }
  # CALIB_MODEL forces a candidate (e.g. m3_site_month), overriding the rule.
  forced <- Sys.getenv("CALIB_MODEL")
  if (nzchar(forced)) {
    stopifnot(forced %in% comparison$model)
    chosen <- forced
  }
  formula <- stats::as.formula(comparison$formula[comparison$model == chosen])
  if (nzchar(calib_cov)) formula <- stats::update(formula, paste(". ~ . +", cov_z))
  message("Calibration model: ", chosen, " (", deparse1(formula), ")")
  backend <- if (requireNamespace("cmdstanr", quietly = TRUE)) "cmdstanr" else "rstan"
  fit <- fit_calibration(val_cal, formula, engine = "brms",
                         prior = calibration_prior(formula, val_cal),
                         chains = 4, iter = 2000, cores = 4, seed = seed,
                         backend = backend, refresh = 0,
                         control = list(adapt_delta = as.numeric(
                           Sys.getenv("ADAPT_DELTA", "0.8"))))
  diagnostics <- calibration_diagnostics(fit)

  dir_cl <- file.path(out, tolower(cl))
  res <- export_occupancy_data(
    dir_cl, detections, recordings = select(recordings, site, source_audio),
    validation = validation, fit = fit, occasion_covariates = covariates,
    calibration_keys = if (season) "month",
    min_confidence = min_confidence,
    classifier = paste("Curiango", cl, "(Piatti et al., Zenodo 10.5281/zenodo.21795898)",
                       if (season) "- seasonal calibration (sensitivity)"),
    n_draws = 100, seed = seed, overwrite = TRUE,
    n_versions = if (nzchar(calib_cov)) n_versions,
    covariate_scaling = cov_scaling)
  write_csv(comparison, file.path(dir_cl, "curiango_calibration_comparison.csv"))
  write_csv(diagnostics, file.path(dir_cl, "curiango_calibration_diagnostics.csv"))
  # ajuste e dados da calibracao, para o posterior predictive check
  # (dev/benchmarks/curiango-ppc.R)
  saveRDS(fit, file.path(dir_cl, "curiango_calibration_fit.rds"))
  write_csv(val_cal, file.path(dir_cl, "curiango_calibration_data.csv"))

  summary_rows[[cl]] <- tibble(
    classifier = cl, model = chosen,
    occasions = nrow(res$tables$occasions),
    detections = nrow(res$tables$detections),
    occasions_with_score = nrow(res$tables$scores),
    clips_reviewed = nrow(res$tables$validation),
    recordings_verified = nrow(res$tables$recordings_verified),
    calibration_draws = nrow(res$tables$calibration_draws),
    max_rhat = diagnostics$max_rhat, min_ess_bulk = diagnostics$min_ess_bulk,
    n_divergent = diagnostics$n_divergent)
}

summary_tab <- bind_rows(summary_rows)
write_csv(summary_tab, file.path(out, "summary.csv"))
writeLines(capture.output(sessionInfo()), file.path(out, "session-info.txt"))
print(summary_tab, width = Inf)

# leitura de volta pelo crywolf, quando ele tem fp_read_sheepdog()
if (requireNamespace("crywolf", quietly = TRUE) &&
    "fp_read_sheepdog" %in% getNamespaceExports("crywolf")) {
  for (cl in tolower(names(classifiers))) {
    d <- crywolf::fp_read_sheepdog(file.path(out, cl))
    message("crywolf read ", cl, ": ", paste(names(d), collapse = ", "))
  }
}
