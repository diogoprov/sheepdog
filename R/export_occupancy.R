#' Export the data of an occupancy model with false positives
#'
#' Writes, in one folder, everything an occupancy model with false
#' positives needs from a passive acoustic survey: the occasions, the
#' classifier scores, the reviewed clips with their sampling design and,
#' optionally, covariates of the occasions and posterior draws of a
#' Bayesian calibration. The folder follows the `sheepdog-occupancy`
#' schema (version 1.4), described in
#' `vignette("crywolf-integration")`; the crywolf package reads it, but any
#' software can, since every table is a plain CSV file (the calibration
#' draws are a Parquet file).
#'
#' @section Tables:
#' * `occasions.csv`: one row per occasion (a recording, or a minute of a
#'   recording), with or without predictions, with its number of windows
#'   of the classifier (`n_windows`, `NA` when the length of the occasion
#'   is unknown), followed by the columns of `occasion_covariates` and of
#'   the calibration keys.
#' * `detections.csv`: one row per prediction with confidence >=
#'   `min_confidence`.
#' * `scores.csv`: one row per occasion x species with at least one
#'   prediction: the highest score and the number of predictions. Occasion
#'   x species pairs absent from this table had no prediction >=
#'   `min_confidence` (a censored score).
#' * `validation.csv`: the reviewed clips of the `"top"`,
#'   `"random_detections"`, `"directed_pps"` (from [select_directed()]) and
#'   `"score_bands"` designs, with their verdict, inclusion
#'   probability, round and stratum, and what a negative verdict covers
#'   (`review_scope`; only when `validation` is given).
#' * `recordings_verified.csv`: the occasions annotated by ear in the
#'   `"random_recordings"` design, with the state of each occasion (only
#'   when `validation` holds such clips).
#' * `sites.csv`: one row per site, with the covariates of `sites`.
#' * `calibration_draws.parquet`: posterior draws of P(TP) on a grid of
#'   scores for each site x species with predictions, and for each level of
#'   the `calibration_keys` found among the occasions of the site (only
#'   when `fit` is given; needs the 'arrow' package).
#' * `occasion_draws.parquet`: versions of the detections over the
#'   calibration draws, as written by [occasion_draws()] (only with
#'   `n_versions`, or with a calibration on continuous covariates).
#' * `schema.json`: name and version of the schema, the settings of the
#'   export, the lists of sites and species and the number of rows of each
#'   table.
#'
#' **Calibration keys.** A calibration may depend on a property of the
#' occasion besides site and species, such as the month of the recording
#' (`tp ~ logit_conf + (1 | month)`). Name such grouping variables in
#' `calibration_keys`: each becomes a text column of `occasions.csv` and of
#' `calibration_draws.parquet`, so that a reader matches each prediction
#' to the draws of its occasion. A key must be a column of
#' `occasion_covariates`, except `"month"`, which is derived from the
#' recording date (`YYYYMM`) when not given. Levels absent from the
#' calibration data are drawn as new levels of the group (brms
#' `sample_new_levels = "uncertainty"`); occasions without a value of a key
#' are reported, since their predictions cannot be scored.
#'
#' **Continuous covariates (schema 1.3).** A calibration may also depend on
#' a continuous covariate of the occasion, such as the temperature of the
#' night or an acoustic index (`tp ~ logit_conf + temp`). Numeric
#' variables of the model besides `logit_conf` are taken as such
#' covariates; each must be a column of `occasion_covariates`, on the scale
#' used in the model. A grid of scores would then need one point per value
#' of the covariate, so P(TP) is computed for each prediction instead, and
#' the versions of the detections are drawn here, by the rules of
#' [occasion_draws()], and written to `occasion_draws.parquet`;
#' `calibration_draws.parquet` is not written. `schema.json` records the
#' covariates (`calibration$covariates`), their range in the calibration
#' data, the scaling given in `covariate_scaling`, the rule, the seed and
#' the number of versions. Occasions with predictions but without a value
#' of a covariate are not scored (`NA`), and values outside the range of
#' the calibration data are reported. To change the rule or the number of
#' versions, export again; [occasion_draws()] refuses such a folder.
#'
#' Two checks guard against inputs that would inflate the detections:
#' predictions repeating the site, recording, offset and species of another
#' (e.g. a selection table read twice) are dropped with a warning, and a
#' warning is given when most occasion x species with several predictions
#' have the same score in all of them, a sign that one score per occasion
#' was copied to several rows.
#'
#' A clip verdict and the state of an occasion are kept apart on purpose: a
#' positive clip proves that the species called in its occasion, but a
#' negative clip only says that this prediction was a false positive (the
#' species may still have called, with a lower score). A recording
#' annotated by ear gives the state of the whole occasion.
#'
#' @param output_dir Folder to write. Created if needed.
#' @param detections Predictions, as returned by [read_selection_tables()].
#' @param recordings The list of all recordings, as a data frame or the
#'   path to a CSV file with the columns `site` and `source_audio`, as in
#'   [select_clips()]. `NULL` lists the audio files in the folders of the
#'   recordings that have predictions, which then must be reachable (see
#'   `remap_from`).
#' @param validation Reviewed clips, without those with an inherited verdict
#'   (see [select_clips()]): paths to `validation_by_clip.csv`
#'   files (output of [post_validation()]) or a data frame with their
#'   columns, e.g. from [read_validation_tables()] or
#'   [consensus_verdicts()]. `NULL` writes no validation tables.
#' @param fit Optional model from [fit_calibration()] with
#'   `engine = "brms"`, for `calibration_draws.parquet`.
#' @param sites Optional data frame of site covariates, with a `site`
#'   column.
#' @param occasion_covariates Optional data frame of covariates of the
#'   occasions (e.g. temperature or the month), with `site` and either
#'   `occasion_id` or `source_audio` (plus `start`, in s, for minute
#'   occasions). One row per occasion; occasions without a row get `NA`.
#'   Columns named like those of `occasions.csv` are refused.
#' @param calibration_keys Optional grouping variables of the calibration
#'   model, besides `site` and `species`, that vary between occasions (see
#'   Calibration keys). Only used with `fit`.
#' @param occasion_unit The occasion of the occupancy model: `"file"` (a
#'   recording) or `"minute"`. Use the value of the clip extraction, so that
#'   the `occasion_id` of the reviewed clips match.
#' @param recording_duration Length of the recordings (s). Needed for
#'   minute occasions unless the 'av' package can read the files.
#' @param min_confidence Predictions below this confidence are not
#'   written; it is also the lower end of the grid of the calibration
#'   draws. Use the `min_confidence` of the BirdNET run or higher.
#' @param n_draws Number of posterior draws of the calibration.
#' @param grid_step Step of the grid of scores of the calibration draws.
#' @param seed Seed of the choice of draws and, with `n_versions`, of the
#'   versions of the detections (`rule = "sample"`). The global random
#'   number generator is left as it was.
#' @param n_versions Optional number of versions of the detections to
#'   write to `occasion_draws.parquet`, from the first calibration draws.
#'   Without continuous covariates, `occasion_draws()` is called on the
#'   folder. With them, the versions are always written, and
#'   `NULL` means one per calibration draw (`n_draws`).
#' @param rule,p_min Rule of the versions, as in [occasion_draws()].
#' @param covariate_scaling Optional named list recording how each
#'   continuous covariate of the calibration was standardised before the
#'   model was fitted, e.g. `list(temp = c(center = 22.4, scale = 3.1))`
#'   for `(temp_raw - 22.4) / 3.1`. It is written to `schema.json` so that
#'   a reader can map the covariate back; the values of
#'   `occasion_covariates` must already be on the scale of the model.
#' @param min_verified Species with predictions but fewer than this
#'   number of reviewed detection clips (positive or negative), or without
#'   any positive or any negative clip, are named in a warning: their
#'   false-positive rate will rest on the other species (a community
#'   model) or on the prior. The default is a floor, not a sample size
#'   calculation. Only used with `validation`.
#' @param candidates The `candidates.csv` of the first round of a
#'   `"random_detections"` design, as a path or a data frame. It gives the
#'   stratum of each occasion and, in `schema.json`, the threshold and the
#'   strata of the draw. `NULL` looks for it in the folders of `validation`;
#'   without it, `stratum` is empty unless `validation` has that column, as
#'   after [combine_rounds()]. Only used with `validation`.
#' @param window_step Time between the starts of consecutive windows of the
#'   classifier (s), for `n_windows`: 3 for BirdNET without overlap.
#' @param classifier Optional label of the classifier, recorded in
#'   `schema.json`.
#' @param overwrite Replace an existing export in `output_dir`?
#' @inheritParams select_clips
#' @inheritParams score_detections
#'
#' @return Invisibly, a list with the tables written (tibbles) and the
#'   schema (a list).
#' @seealso `vignette("crywolf-integration")` for the columns of each table.
#' @export
export_occupancy_data <- function(output_dir, detections, recordings = NULL,
                                  validation = NULL, fit = NULL, sites = NULL,
                                  occasion_covariates = NULL,
                                  calibration_keys = NULL,
                                  occasion_unit = c("file", "minute"),
                                  recording_duration = NULL,
                                  min_confidence = 0.1, dawn_hour = 12,
                                  species = NULL,
                                  n_draws = 100, grid_step = 0.01, seed = 2026,
                                  n_versions = NULL,
                                  rule = c("sample", "threshold"),
                                  p_min = 0.95, covariate_scaling = NULL,
                                  audio_pattern = "\\.(wav|flac|mp3)$",
                                  remap_from = NULL, remap_to = NULL,
                                  min_verified = 10, candidates = NULL,
                                  window_step = 3,
                                  classifier = NULL, overwrite = FALSE) {
  unidade <- match.arg(occasion_unit)
  rule <- match.arg(rule)
  covs_cal <- character()
  if (!is.null(fit)) {
    if (!inherits(fit, "brmsfit")) {
      stop("`fit` must be a model fitted with engine = \"brms\": the ",
           "calibration draws need a posterior.", call. = FALSE)
    }
    require_suggested("arrow", "to write calibration_draws.parquet")
    check_calibration_keys(fit, calibration_keys)
    covs_cal <- calibration_covariates(fit, calibration_keys)
    check_covariate_scaling(covariate_scaling, covs_cal)
  } else if (length(calibration_keys) > 0) {
    stop("`calibration_keys` need a calibration model in `fit`.", call. = FALSE)
  } else if (!is.null(n_versions)) {
    stop("`n_versions` needs a calibration model in `fit`.", call. = FALSE)
  }
  if (!is.null(n_versions) &&
      (!is.numeric(n_versions) || length(n_versions) != 1 || n_versions < 1)) {
    stop("`n_versions` must be a positive number.", call. = FALSE)
  }
  if (!is.numeric(window_step) || length(window_step) != 1 ||
      is.na(window_step) || window_step <= 0) {
    stop("`window_step` must be a positive number.", call. = FALSE)
  }
  if (file.exists(file.path(output_dir, "schema.json")) && !overwrite) {
    stop("`output_dir` already holds an export; use overwrite = TRUE to ",
         "replace it.", call. = FALSE)
  }
  faltam <- setdiff(c("site", "species_code", "confidence", "begin_path",
                      "file_offset"), names(detections))
  if (length(faltam) > 0) {
    stop("`detections` lacks column(s): ", paste(faltam, collapse = ", "),
         ". Read it with read_selection_tables().", call. = FALSE)
  }

  # Predicoes >= min_confidence, com a ocasiao de cada uma
  det <- detections |>
    filter(confidence >= min_confidence) |>
    mutate(site = as.character(site),
           species = folder_name(species_code),
           source_audio = remap_path(begin_path, remap_from, remap_to),
           occasion_id = make_occasion_id(source_audio, file_offset, unidade))
  if (!is.null(species)) {
    det <- filter(det, str_extract(species_code, "[^_]+$") %in% .env$species)
  }
  if (nrow(det) == 0) stop("No prediction with confidence >= ", min_confidence, ".")
  det <- check_duplicate_predictions(det)

  ocasioes <- export_occasions(det, recordings, unidade, recording_duration,
                               dawn_hour, audio_pattern, remap_from, remap_to,
                               window_step)
  # predicoes em gravacoes fora da lista: a lista esta incompleta
  sem_ocasiao <- anti_join(distinct(det, site, occasion_id), ocasioes,
                           by = c("site", "occasion_id"))
  if (nrow(sem_ocasiao) > 0) {
    warning(nrow(sem_ocasiao), " occasion(s) with predictions are not in ",
            "`recordings`; they were added to occasions.csv without a ",
            "recording time. Is the list of recordings complete?",
            call. = FALSE)
    ocasioes <- bind_rows(ocasioes, sem_ocasiao) |> arrange(site, occasion_id)
  }
  fixas <- names(ocasioes)
  ocasioes <- join_occasion_covariates(ocasioes, occasion_covariates,
                                       remap_from, remap_to)
  ocasioes <- add_calibration_keys(ocasioes, calibration_keys)
  for (v in covs_cal) {
    if (!v %in% names(ocasioes)) {
      stop("Calibration covariate `", v, "` is not a column of ",
           "`occasion_covariates`.", call. = FALSE)
    }
    if (!is.numeric(ocasioes[[v]])) {
      stop("Calibration covariate `", v, "` must be numeric in ",
           "`occasion_covariates`.", call. = FALSE)
    }
  }
  covariaveis <- setdiff(names(ocasioes), fixas)

  tabelas <- list(
    occasions = ocasioes,
    detections = det |>
      select(site, occasion_id, species_code, species, file_offset,
             confidence) |>
      arrange(site, occasion_id, species_code, file_offset),
    scores = det |>
      group_by(site, occasion_id, species_code, species) |>
      summarise(max_score = max(confidence), n_above_min = n(),
                .groups = "drop")
  )
  candidatas <- NULL
  if (!is.null(validation)) {
    candidatas <- read_candidates(candidates, validation)
    tabelas <- c(tabelas, export_validation(validation, ocasioes, candidatas))
    check_verification_by_species(tabelas$validation, unique(det$species),
                                  min_verified)
  }
  tabelas$sites <- export_sites(sites, unique(ocasioes$site))

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  # uma exportacao anterior nao deixa tabelas que esta nao escreve
  unlink(file.path(output_dir, c(paste0(occupancy_tables, ".csv"),
                                 "calibration_draws.parquet",
                                 "occasion_draws.parquet")))
  iwalk(tabelas, \(tab, nome) write_csv(tab, file.path(output_dir,
                                                       paste0(nome, ".csv")),
                                        na = ""))
  arquivos <- map(tabelas, nrow)

  calibracao <- NULL
  versoes <- NULL
  if (!is.null(fit) && length(covs_cal) > 0) {
    n_v <- if (is.null(n_versions)) n_draws else n_versions
    od <- covariate_versions(fit, tabelas$detections, ocasioes,
                             calibration_keys, covs_cal, n_draws, n_v, rule,
                             p_min, seed)
    arrow::write_parquet(od, file.path(output_dir, "occasion_draws.parquet"))
    tabelas$occasion_draws <- od
    arquivos$occasion_draws <- nrow(od)
    formula <- tryCatch(deparse1(stats::formula(fit)$formula),
                        error = function(e) NULL)
    faixa <- map(set_names(covs_cal), \(v) list(
      min = min(fit$data[[v]], na.rm = TRUE),
      max = max(fit$data[[v]], na.rm = TRUE)))
    calibracao <- compact(list(
      engine = "brms", formula = formula,
      n_draws = length(unique(od$draw)),
      keys = I(c("site", "species", calibration_keys)),
      covariates = I(covs_cal), covariate_range = faixa,
      covariate_scaling = if (!is.null(covariate_scaling)) {
        map(covariate_scaling, \(s) list(center = unname(s[["center"]]),
                                         scale = unname(s[["scale"]])))
      },
      new_levels = "uncertainty"))
    versoes <- compact(list(
      file = "occasion_draws.parquet", rule = rule,
      p_min = if (rule == "threshold") p_min,
      seed = if (rule == "sample") seed,
      n_draws = length(unique(od$draw)),
      species = I(sort(unique(od$species)))))
  } else if (!is.null(fit)) {
    draws <- calibration_draws(fit, distinct(tabelas$scores, site, species),
                               min_confidence, grid_step, n_draws, seed,
                               ocasioes, calibration_keys)
    arrow::write_parquet(draws, file.path(output_dir,
                                          "calibration_draws.parquet"))
    tabelas$calibration_draws <- draws
    arquivos$calibration_draws <- nrow(draws)
    formula <- tryCatch(deparse1(stats::formula(fit)$formula),
                        error = function(e) NULL)
    calibracao <- list(engine = "brms", formula = formula,
                       n_draws = length(unique(draws$draw)),
                       grid_step = grid_step, grid_min = min(draws$confidence),
                       keys = I(c("site", "species", calibration_keys,
                                  "grid_index")),
                       new_levels = "uncertainty")
  }

  schema <- list(
    schema = "sheepdog-occupancy",
    schema_version = 1.4,
    created = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    sheepdog_version = as.character(utils::packageVersion("sheepdog")),
    classifier = classifier,
    occasion_unit = unidade,
    min_confidence = min_confidence,
    dawn_hour = dawn_hour,
    window_step = window_step,
    # I(): listas mesmo com um elemento (auto_unbox desfaria o vetor)
    sites = I(sort(unique(ocasioes$site))),
    species = I(sort(unique(det$species_code))),
    occasion_covariates = if (length(covariaveis)) I(covariaveis),
    tables = imap(arquivos, \(n, nome) list(
      file = if (nome %in% c("calibration_draws", "occasion_draws")) {
        paste0(nome, ".parquet")
      } else paste0(nome, ".csv"),
      rows = n)),
    validation_design = validation_design(candidatas),
    calibration = calibracao,
    occasion_draws = versoes
  )
  jsonlite::write_json(compact(schema), file.path(output_dir, "schema.json"),
                       auto_unbox = TRUE, pretty = TRUE, digits = NA)
  message("Export written to ", output_dir, ": ",
          paste(names(arquivos), collapse = ", "), ".")
  # sem covariaveis, as versoes saem da grade, como em occasion_draws()
  if (!is.null(n_versions) && length(covs_cal) == 0) {
    tabelas$occasion_draws <- occasion_draws(
      output_dir, rule = rule, p_min = p_min, n_draws = n_versions,
      seed = seed)
    schema <- jsonlite::read_json(file.path(output_dir, "schema.json"),
                                  simplifyVector = TRUE)
  }
  invisible(list(tables = tabelas, schema = schema))
}

# Covariaveis continuas da calibracao: variaveis numericas do modelo alem do
# score (as chaves sao agrupamentos)
calibration_covariates <- function(fit, keys) {
  dados <- fit$data
  if (is.null(dados)) return(character())
  numericas <- names(dados)[vapply(dados, is.numeric, logical(1))]
  setdiff(numericas, c("tp", "logit_conf", keys))
}

check_covariate_scaling <- function(scaling, covs) {
  if (is.null(scaling)) return(invisible())
  if (!is.list(scaling) || is.null(names(scaling)) ||
      !all(names(scaling) %in% covs)) {
    stop("`covariate_scaling` must be a list named by the continuous ",
         "covariates of the calibration (", paste(covs, collapse = ", "), ").",
         call. = FALSE)
  }
  for (s in scaling) {
    if (!is.numeric(s) || !all(c("center", "scale") %in% names(s))) {
      stop("Each element of `covariate_scaling` must be c(center = , ",
           "scale = ).", call. = FALSE)
    }
  }
  invisible()
}

# Versoes das deteccoes com covariaveis continuas: P(TP) de cada predicao
# em cada draw (sem grade), sorteadas como em occasion_draws()
covariate_versions <- function(fit, det, ocasioes, keys, covs, n_draws,
                               n_versions, rule, p_min, seed) {
  niveis <- fit_levels(fit)
  fora <- setdiff(unique(det$species), niveis$species)
  if (length(fora) > 0) {
    message("Species not in the calibration, left out of the versions: ",
            paste(fora, collapse = ", "))
  }
  novos <- setdiff(unique(det$site), niveis$site)
  if (length(novos) > 0) {
    message("Site(s) not in the calibration, drawn as new levels of the ",
            "site effect: ", paste(novos, collapse = ", "))
  }
  ids <- withr::with_seed(seed, sort(sample.int(
    posterior_size(fit), min(n_draws, posterior_size(fit)))))
  ids <- utils::head(ids, n_versions)
  occ_key <- paste(ocasioes$site, ocasioes$occasion_id, sep = "\r")
  especies <- sort(intersect(unique(det$species), niveis$species))
  map(especies, function(sp) {
    d <- det[det$species == sp, ]
    o <- match(paste(d$site, d$occasion_id, sep = "\r"), occ_key)
    nd <- tibble(site = d$site, species = d$species,
                 logit_conf = safe_logit(d$confidence))
    for (k in keys) nd[[k]] <- ocasioes[[k]][o]
    for (v in covs) nd[[v]] <- ocasioes[[v]][o]
    pontuar <- !is.na(o) & stats::complete.cases(nd)
    for (v in covs) {
      faixa <- range(fit$data[[v]], na.rm = TRUE)
      fora_faixa <- pontuar & (nd[[v]] < faixa[1] | nd[[v]] > faixa[2])
      if (any(fora_faixa)) {
        warning(sum(fora_faixa), " prediction(s) of ", sp, " have `", v,
                "` outside its range in the calibration data (",
                signif(faixa[1], 3), " to ", signif(faixa[2], 3),
                "); their P(TP) is an extrapolation.", call. = FALSE)
      }
    }
    Pdet <- matrix(NA_real_, nrow(d), length(ids))
    if (any(pontuar)) {
      # niveis novos sao sorteados: mesma semente, mesmo resultado
      Pdet[pontuar, ] <- t(withr::with_seed(seed, prediction_draws(
        fit, nd[pontuar, , drop = FALSE], ids)))
    }
    sample_versions(d, ocasioes, o, Pdet, ids, rule, p_min, seed,
                    motivo = "without a value of the calibration covariates or keys")
  }) |>
    list_rbind()
}

# P(TP) de cada linha de `newdata` nos draws `ids` (draws x linhas); funcao
# propria para os testes
prediction_draws <- function(fit, newdata, ids) {
  brms::posterior_epred(fit, newdata = newdata, allow_new_levels = TRUE,
                        draw_ids = ids)
}

# Predicoes repetidas: a mesma janela lida duas vezes (tabelas de selecao
# duplicadas) sai com um aviso; ocasioes cujas predicoes tem todas o mesmo
# score sugerem um score copiado entre linhas (o erro do artigo do JAV) e
# so geram um aviso
check_duplicate_predictions <- function(det) {
  chave <- c("site", "source_audio", "file_offset", "species_code")
  repetidas <- duplicated(det[chave])
  if (any(repetidas)) {
    warning(sum(repetidas), " prediction(s) repeat the site, recording, ",
            "offset and species of another and were dropped. Was a ",
            "selection table read twice?", call. = FALSE)
    det <- det[!repetidas, ]
  }
  grupos <- det |>
    group_by(site, occasion_id, species_code) |>
    summarise(n = n(), .n_scores = n_distinct(confidence), .groups = "drop") |>
    filter(n >= 2)
  iguais <- sum(grupos$.n_scores == 1)
  if (iguais >= 10 && iguais / nrow(grupos) > 0.5) {
    warning(iguais, " of ", nrow(grupos), " occasion x species with several ",
            "predictions have the same score in all of them. Were the ",
            "scores of an occasion copied to several rows? Then each ",
            "prediction is not a separate detection window.", call. = FALSE)
  }
  det
}

# As chaves da calibracao sao fatores de agrupamento do modelo, alem de
# local e especie
check_calibration_keys <- function(fit, keys) {
  if (length(keys) == 0) return(invisible())
  if (!is.character(keys) || anyNA(keys) || anyDuplicated(keys)) {
    stop("`calibration_keys` must be distinct column names.", call. = FALSE)
  }
  if (any(keys %in% c("site", "species", "grid_index"))) {
    stop("`calibration_keys` must not include site, species or grid_index, ",
         "which are always keys.", call. = FALSE)
  }
  vars <- names(fit$data)
  if (!is.null(vars) && !all(keys %in% vars)) {
    stop("Calibration key(s) not in the model: ",
         paste(setdiff(keys, vars), collapse = ", "), ".", call. = FALSE)
  }
  invisible()
}

# Covariaveis de ocasiao, casadas por occasion_id ou pela gravacao (e o
# inicio do minuto)
join_occasion_covariates <- function(ocasioes, covs, remap_from, remap_to) {
  if (is.null(covs)) return(ocasioes)
  if (!is.data.frame(covs) || !"site" %in% names(covs)) {
    stop("`occasion_covariates` must be a data frame with a `site` column.",
         call. = FALSE)
  }
  por <- if ("occasion_id" %in% names(covs)) c("site", "occasion_id")
         else if ("source_audio" %in% names(covs)) {
           c("site", "source_audio", if ("start" %in% names(covs)) "start")
         } else {
           stop("`occasion_covariates` needs `occasion_id` or `source_audio`.",
                call. = FALSE)
         }
  if (identical(por, c("site", "source_audio")) &&
      anyDuplicated(ocasioes[c("site", "source_audio")])) {
    stop("Minute occasions: `occasion_covariates` needs a `start` column, ",
         "or `occasion_id`.", call. = FALSE)
  }
  extras <- setdiff(names(covs), por)
  colide <- intersect(extras, names(ocasioes))
  if (length(colide) > 0) {
    stop("`occasion_covariates` has column(s) named like those of ",
         "occasions.csv: ", paste(colide, collapse = ", "), ".", call. = FALSE)
  }
  if (length(extras) == 0) {
    stop("`occasion_covariates` has no covariate column.", call. = FALSE)
  }
  covs <- mutate(covs, site = as.character(site))
  if ("source_audio" %in% por) {
    covs$source_audio <- remap_path(covs$source_audio, remap_from, remap_to)
  }
  if ("occasion_id" %in% por) covs$occasion_id <- as.character(covs$occasion_id)
  if ("start" %in% por) covs$start <- as.numeric(covs$start)
  if (anyDuplicated(covs[por])) {
    stop("`occasion_covariates` has more than one row for some occasion.",
         call. = FALSE)
  }
  fora <- nrow(anti_join(covs, ocasioes, by = por))
  if (fora > 0) {
    warning(fora, " row(s) of `occasion_covariates` match no occasion.",
            call. = FALSE)
  }
  left_join(ocasioes, covs[c(por, extras)], by = por)
}

# Colunas das chaves em occasions.csv, como texto; "month" vem da data da
# gravacao quando nao foi dada
add_calibration_keys <- function(ocasioes, keys) {
  for (k in keys) {
    if (!k %in% names(ocasioes)) {
      if (k != "month") {
        stop("Calibration key `", k, "` is not a column of ",
             "`occasion_covariates`.", call. = FALSE)
      }
      ocasioes$month <- substr(ocasioes$recording_date, 1, 6)
    }
    ocasioes[[k]] <- as.character(ocasioes[[k]])
    sem <- is.na(ocasioes[[k]]) | !nzchar(ocasioes[[k]])
    if (any(sem)) {
      warning(sum(sem), " occasion(s) have no value of the calibration key `",
              k, "`; their predictions cannot be scored.", call. = FALSE)
      ocasioes[[k]][sem] <- NA_character_
    }
  }
  ocasioes
}

# Tabelas CSV do esquema, na ordem de schema.json
occupancy_tables <- c("occasions", "detections", "scores", "validation",
                      "recordings_verified", "sites")

# Todas as ocasioes: gravacoes (ou minutos) com ou sem predicao
export_occasions <- function(det, recordings, unidade, recording_duration,
                             dawn_hour, audio_pattern, remap_from, remap_to,
                             window_step) {
  gravacoes <- suppressMessages(
    get_recordings(det, recordings, audio_pattern, remap_from, remap_to))
  if (unidade == "minute") {
    gravacoes <- gravacoes |>
      mutate(.dur = audio_duration(source_audio, recording_duration))
    if (anyNA(gravacoes$.dur)) {
      stop(sum(is.na(gravacoes$.dur)), " recording(s) without a readable ",
           "duration; set `recording_duration`.", call. = FALSE)
    }
    gravacoes <- gravacoes |>
      mutate(start = map(.dur, \(d) (seq_len(ceiling(d / 60)) - 1) * 60)) |>
      unnest(start) |>
      mutate(duration = pmin(60, .dur - start)) |>
      select(-.dur)
  } else {
    gravacoes <- mutate(gravacoes, start = 0,
                        duration = if (is.null(recording_duration)) NA_real_
                                   else recording_duration)
  }
  gravacoes |>
    mutate(site = as.character(site),
           occasion_id = make_occasion_id(source_audio, start, unidade),
           night = night_of(recording_date, recording_hour, dawn_hour),
           # round(): 0.3 / 0.1 nao pode virar 4 janelas
           n_windows = as.integer(ceiling(round(duration / window_step, 6)))) |>
    distinct(site, occasion_id, .keep_all = TRUE) |>
    select(site, occasion_id, source_audio, recording_date, recording_hour,
           night, start, duration, n_windows) |>
    arrange(site, occasion_id)
}

# Noite de uma gravacao: o dia anterior antes de `dawn_hour`, como em
# score_detections()
night_of <- function(recording_date, recording_hour, dawn_hour) {
  hora <- suppressWarnings(as.integer(recording_hour))
  anterior <- format(as.Date(recording_date, "%Y%m%d") - 1, "%Y%m%d")
  if_else(!is.na(hora) & hora < dawn_hour, anterior, recording_date)
}

# Clipes revisados: os de deteccoes (validation) e as gravacoes anotadas
# de ouvido (recordings_verified), que dao o estado da ocasiao
export_validation <- function(validation, ocasioes, candidatas = NULL) {
  if (is.character(validation)) {
    validation <- read_validation_tables(validation)
  }
  validation <- from_legacy(validation)
  faltam <- setdiff(c("site", "species_code", "occasion_id", "sampling_mode",
                      "verdict"), names(validation))
  if (length(faltam) > 0) {
    stop("`validation` lacks column(s): ", paste(faltam, collapse = ", "),
         ". Was it written by post_validation()?", call. = FALSE)
  }
  # um veredito herdado e o mesmo julgamento do outro desenho: exporta-lo daria
  # ao modelo duas observacoes dele
  herdados <- is_inherited(validation)
  if (any(herdados)) {
    warning(sum(herdados), " clip(s) with an inherited verdict left out, as ",
            "they repeat a judgement. They are chosen by their verdict, which ",
            "can bias the rates that an occupancy model estimates from these ",
            "tables; review them (`inherit = FALSE` in select_clips()) if ",
            "they are many.", call. = FALSE)
    validation <- validation[!herdados, ]
  }
  for (col in c("confidence", "clip_start", "clip_end", "inclusion_prob",
                "n_detections_occasion", "round", "n_candidates", "n_drawn")) {
    if (!col %in% names(validation)) validation[[col]] <- NA_real_
  }
  if (!"stratum" %in% names(validation)) validation$stratum <- NA_character_
  validation <- join_candidates(validation, candidatas)
  v <- validation |>
    mutate(site = as.character(site),
           species = folder_name(species_code),
           confidence = as.numeric(confidence),
           tp = case_when(verdict == "positive" ~ 1L,
                          verdict == "negative" ~ 0L,
                          .default = NA_integer_),
           across(c(round, n_candidates, n_drawn), as.integer),
           stratum = as.character(stratum)) |>
    mutate(review_scope = review_scope(sampling_mode, tp,
                                       n_detections_occasion),
           .by = c(site, occasion_id, species_code, sampling_mode))
  fora <- anti_join(distinct(v, site, occasion_id), ocasioes,
                    by = c("site", "occasion_id"))
  if (nrow(fora) > 0) {
    warning(nrow(fora), " reviewed occasion(s) do not match any occasion; ",
            "check that `occasion_unit` is the one of the clip extraction.",
            call. = FALSE)
  }
  extras <- intersect(c("reviewer", "n_reviewers"), names(v))
  out <- list(
    validation = v |>
      filter(sampling_mode != "random_recordings") |>
      select(site, occasion_id, species_code, species, clip_start, clip_end,
             confidence, sampling_mode, inclusion_prob,
             n_detections_occasion, verdict, tp, round, stratum,
             n_candidates, n_drawn, review_scope, all_of(extras)) |>
      arrange(site, occasion_id, species_code, clip_start)
  )
  check_clips_in_both_designs(out$validation)
  faixas <- sum(out$validation$sampling_mode %in% "score_bands")
  if (faixas > 0) {
    warning(faixas, " reviewed clip(s) of sampling_mode = \"score_bands\" ",
            "are written to validation.csv. They were chosen by their score, ",
            "so they serve thresholds and calibration but not the ",
            "false-positive rate of an occupancy model: crywolf drops them. ",
            "Use \"random_detections\" or \"random_recordings\" clips for ",
            "the occupancy model.", call. = FALSE)
  }
  gravacoes <- filter(v, sampling_mode == "random_recordings")
  nas_duas <- semi_join(
    distinct(filter(out$validation, sampling_mode %in%
                      c("random_detections", "directed_pps")),
             site, species_code, occasion_id),
    gravacoes, by = c("site", "species_code", "occasion_id"))
  if (nrow(nas_duas) > 0) {
    warning(nrow(nas_duas), " occasion(s) are in both `validation` and ",
            "`recordings_verified`. A model that reads both takes them as ",
            "two independent reviews; say so if the clips also set the ",
            "thresholds, and check that one verdict was not copied from the ",
            "other.", call. = FALSE)
  }
  if (nrow(gravacoes) > 0) {
    out$recordings_verified <- gravacoes |>
      select(site, occasion_id, species_code, species, inclusion_prob,
             verdict, present = tp, all_of(extras)) |>
      arrange(site, occasion_id, species_code)
  }
  out
}

# Clipes revisados por especie: com poucos, ou sem positivo ou sem
# negativo, a taxa de falso positivo da especie nao vem dos dados dela
# Estrato e N das ocasioes sorteadas, quando a tabela nao os traz; os outros
# desenhos ficam sem eles, mesmo numa ocasiao que tambem foi candidata
join_candidates <- function(validation, candidatas) {
  if (is.null(candidatas)) return(validation)
  validation |>
    mutate(across(all_of(ocasiao_chave), as.character)) |>
    left_join(candidatas |>
                mutate(across(all_of(ocasiao_chave), as.character)) |>
                select(all_of(ocasiao_chave), .estrato = stratum,
                       .n = n_candidates),
              by = ocasiao_chave) |>
    mutate(.sorteada = sampling_mode == "random_detections",
           stratum = if_else(.sorteada,
                             coalesce(as.character(stratum), .estrato),
                             as.character(stratum)),
           n_candidates = if_else(.sorteada,
                                  coalesce(as.integer(n_candidates), .n),
                                  as.integer(n_candidates))) |>
    select(-.estrato, -.n, -.sorteada)
}

# Um mesmo clipe nos dois desenhos e um julgamento so, ou dois que um modelo
# leria como independentes
check_clips_in_both_designs <- function(validation) {
  nos_dois <- validation |>
    distinct(site, occasion_id, species_code, clip_start, sampling_mode) |>
    count(site, occasion_id, species_code, clip_start) |>
    filter(n > 1)
  if (nrow(nos_dois) > 0) {
    desenhos <- validation |>
      semi_join(nos_dois, by = c("site", "occasion_id", "species_code",
                                 "clip_start")) |>
      pull(sampling_mode) |>
      unique() |>
      sort()
    warning(nrow(nos_dois), " clip(s) are in more than one design (",
            paste0("\"", desenhos, "\"", collapse = ", "), "). A model that ",
            "reads both designs takes them as two reviews; keep one of each.",
            call. = FALSE)
  }
}

# O que um negativo cobre, dentro de uma ocasiao x especie: "occasion" quando
# todas as predicoes acima do limiar do sorteio tem veredito; senao, so o clipe
review_scope <- function(sampling_mode, tp, n_detections_occasion) {
  completa <- sampling_mode %in% c("random_detections", "directed_pps") &
    sum(!is.na(tp)) == n_detections_occasion
  if_else(coalesce(completa, FALSE), "occasion", "clip")
}

# Desenho do sorteio, de candidates.csv
validation_design <- function(candidatas) {
  if (is.null(candidatas)) return(NULL)
  campos <- list(threshold = candidatas$threshold[1],
                 strata = candidatas$strata[1],
                 occasion_unit = candidatas$occasion_unit[1],
                 capped = candidatas$capped[1])
  discard(campos, \(x) is.null(x) || is.na(x))
}

check_verification_by_species <- function(validation, especies, min_verified) {
  por_sp <- tibble(species = especies) |>
    left_join(validation |> filter(!is.na(tp)) |>
                group_by(species) |>
                summarise(n = n(), pos = sum(tp), .groups = "drop"),
              by = "species") |>
    mutate(n = coalesce(n, 0L), pos = coalesce(pos, 0L), neg = n - pos) |>
    filter(n < min_verified | pos == 0 | neg == 0) |>
    arrange(n, species)
  if (nrow(por_sp) == 0) return(invisible())
  warning(nrow(por_sp), " species with fewer than ", min_verified,
          " reviewed clips, or without a positive or a negative one: ",
          paste0(por_sp$species, " (", por_sp$n, ": ", por_sp$pos, "+ ",
                 por_sp$neg, "-)", collapse = ", "),
          ". Their false-positive rates will rest on the other species ",
          "(a community model) or on the prior.", call. = FALSE)
}

# Covariaveis de local; os locais sem linha ficam com NA
export_sites <- function(sites, nomes) {
  base <- tibble(site = sort(nomes))
  if (is.null(sites)) return(base)
  if (!"site" %in% names(sites)) {
    stop("`sites` must have a `site` column.", call. = FALSE)
  }
  sites <- mutate(sites, site = as.character(site))
  sem <- setdiff(nomes, sites$site)
  if (length(sem) > 0) {
    warning("Site(s) without covariates in `sites`: ",
            paste(sem, collapse = ", "), call. = FALSE)
  }
  left_join(base, sites, by = "site")
}

# Amostras da posterior de P(TP) na grade de scores, para os pares
# local x especie com predicoes e, com chaves, para cada combinacao de
# niveis das chaves entre as ocasioes do local
calibration_draws <- function(fit, pares, min_confidence, grid_step, n_draws,
                              seed, ocasioes = NULL, keys = NULL) {
  niveis <- fit_levels(fit)
  fora <- setdiff(unique(pares$species), niveis$species)
  if (length(fora) > 0) {
    message("Species not in the calibration, left out of the draws: ",
            paste(fora, collapse = ", "))
  }
  pares <- filter(pares, species %in% niveis$species)
  novos <- setdiff(unique(pares$site), niveis$site)
  if (length(novos) > 0) {
    message("Site(s) not in the calibration, drawn as new levels of the ",
            "site effect: ", paste(novos, collapse = ", "))
  }
  ids <- withr::with_seed(seed, sort(sample.int(
    posterior_size(fit), min(n_draws, posterior_size(fit)))))
  n_g <- length(score_grid(min_confidence, grid_step))
  combos <- if (length(keys)) {
    distinct(ocasioes[c("site", keys)]) |>
      filter(if_all(all_of(keys), \(x) !is.na(x)))
  } else {
    tibble(site = unique(pares$site))
  }
  # niveis novos das chaves sao sorteados: mesma semente, mesmo resultado
  withr::with_seed(seed, {
    pmap(combos, function(site, ...) {
      nivel <- list(...)
      especies <- sort(pares$species[pares$site == site])
      if (length(especies) == 0) return(NULL)
      gd <- grid_draws(fit, site, especies, min_confidence, grid_step,
                       draw_ids = ids, keys = nivel)
      out <- tibble(draw = rep(ids, times = ncol(gd$draws)),
                    site = site,
                    species = rep(as.character(gd$grid$species),
                                  each = length(ids)))
      for (k in names(nivel)) out[[k]] <- nivel[[k]]
      out$grid_index <- rep(rep(seq_len(n_g), length(especies)),
                            each = length(ids))
      out$confidence <- rep(gd$grid$confidence, each = length(ids))
      out$p_tp <- as.vector(gd$draws)
      out
    })
  }) |>
    list_rbind() |>
    arrange(site, species, across(all_of(keys)), grid_index, draw)
}

# Numero de amostras da posterior (funcao propria para os testes)
posterior_size <- function(fit) brms::ndraws(fit)
