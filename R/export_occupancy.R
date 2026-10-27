#' Export the data of an occupancy model with false positives
#'
#' Writes, in one folder, everything an occupancy model with false
#' positives needs from a passive acoustic survey: the occasions, the
#' classifier scores, the reviewed clips with their sampling design and,
#' optionally, posterior draws of a Bayesian calibration. The folder
#' follows the `sheepdog-occupancy` schema, version 1, described in
#' `vignette("crywolf-integration")`; the crywolf package reads it, but any
#' software can, since every table is a plain CSV file (the calibration
#' draws are a Parquet file).
#'
#' @section Tables:
#' * `occasions.csv`: one row per occasion (a recording, or a minute of a
#'   recording), with or without predictions.
#' * `detections.csv`: one row per prediction with confidence >=
#'   `min_confidence`.
#' * `scores.csv`: one row per occasion x species with at least one
#'   prediction: the highest score and the number of predictions. Occasion
#'   x species pairs absent from this table had no prediction >=
#'   `min_confidence` (a censored score).
#' * `validation.csv`: the reviewed clips of the `"top"` and
#'   `"random_detections"` designs, with their verdict and inclusion
#'   probability (only when `validation` is given).
#' * `recordings_verified.csv`: the occasions annotated by ear in the
#'   `"random_recordings"` design, with the state of each occasion (only
#'   when `validation` holds such clips).
#' * `sites.csv`: one row per site, with the covariates of `sites`.
#' * `calibration_draws.parquet`: posterior draws of P(TP) on a grid of
#'   scores for each site x species with predictions (only when `fit` is
#'   given; needs the 'arrow' package).
#' * `schema.json`: name and version of the schema, the settings of the
#'   export, the lists of sites and species and the number of rows of each
#'   table.
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
#' @param validation Reviewed clips: paths to `validation_by_clip.csv`
#'   files (output of [post_validation()]) or a data frame with their
#'   columns, e.g. from [read_validation_tables()] or
#'   [consensus_verdicts()]. `NULL` writes no validation tables.
#' @param fit Optional model from [fit_calibration()] with
#'   `engine = "brms"`, for `calibration_draws.parquet`.
#' @param sites Optional data frame of site covariates, with a `site`
#'   column.
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
#' @param seed Seed of the choice of draws. The global random number
#'   generator is left as it was.
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
                                  occasion_unit = c("file", "minute"),
                                  recording_duration = NULL,
                                  min_confidence = 0.1, dawn_hour = 12,
                                  species = NULL,
                                  n_draws = 100, grid_step = 0.01, seed = 2026,
                                  audio_pattern = "\\.(wav|flac|mp3)$",
                                  remap_from = NULL, remap_to = NULL,
                                  classifier = NULL, overwrite = FALSE) {
  unidade <- match.arg(occasion_unit)
  if (!is.null(fit)) {
    if (!inherits(fit, "brmsfit")) {
      stop("`fit` must be a model fitted with engine = \"brms\": the ",
           "calibration draws need a posterior.", call. = FALSE)
    }
    require_suggested("arrow", "to write calibration_draws.parquet")
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
    det <- filter(det, str_extract(species_code, "[^_]+$") %in% species)
  }
  if (nrow(det) == 0) stop("No prediction with confidence >= ", min_confidence, ".")
  det <- check_duplicate_predictions(det)

  ocasioes <- export_occasions(det, recordings, unidade, recording_duration,
                               dawn_hour, audio_pattern, remap_from, remap_to)
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
  if (!is.null(validation)) {
    tabelas <- c(tabelas, export_validation(validation, ocasioes))
  }
  tabelas$sites <- export_sites(sites, unique(ocasioes$site))

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  # uma exportacao anterior nao deixa tabelas que esta nao escreve
  unlink(file.path(output_dir, c(paste0(occupancy_tables, ".csv"),
                                 "calibration_draws.parquet")))
  iwalk(tabelas, \(tab, nome) write_csv(tab, file.path(output_dir,
                                                       paste0(nome, ".csv")),
                                        na = ""))
  arquivos <- map(tabelas, nrow)

  calibracao <- NULL
  if (!is.null(fit)) {
    draws <- calibration_draws(fit, distinct(tabelas$scores, site, species),
                               min_confidence, grid_step, n_draws, seed)
    arrow::write_parquet(draws, file.path(output_dir,
                                          "calibration_draws.parquet"))
    tabelas$calibration_draws <- draws
    arquivos$calibration_draws <- nrow(draws)
    formula <- tryCatch(deparse1(stats::formula(fit)$formula),
                        error = function(e) NULL)
    calibracao <- list(engine = "brms", formula = formula,
                       n_draws = length(unique(draws$draw)),
                       grid_step = grid_step, grid_min = min(draws$confidence))
  }

  schema <- list(
    schema = "sheepdog-occupancy",
    schema_version = 1L,
    created = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    sheepdog_version = as.character(utils::packageVersion("sheepdog")),
    classifier = classifier,
    occasion_unit = unidade,
    min_confidence = min_confidence,
    dawn_hour = dawn_hour,
    # I(): listas mesmo com um elemento (auto_unbox desfaria o vetor)
    sites = I(sort(unique(ocasioes$site))),
    species = I(sort(unique(det$species_code))),
    tables = imap(arquivos, \(n, nome) list(
      file = if (nome == "calibration_draws") "calibration_draws.parquet"
             else paste0(nome, ".csv"),
      rows = n)),
    calibration = calibracao
  )
  jsonlite::write_json(compact(schema), file.path(output_dir, "schema.json"),
                       auto_unbox = TRUE, pretty = TRUE, digits = NA)
  message("Export written to ", output_dir, ": ",
          paste(names(arquivos), collapse = ", "), ".")
  invisible(list(tables = tabelas, schema = schema))
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

# Tabelas CSV do esquema, na ordem de schema.json
occupancy_tables <- c("occasions", "detections", "scores", "validation",
                      "recordings_verified", "sites")

# Todas as ocasioes: gravacoes (ou minutos) com ou sem predicao
export_occasions <- function(det, recordings, unidade, recording_duration,
                             dawn_hour, audio_pattern, remap_from, remap_to) {
  gravacoes <- suppressMessages(
    list_recordings(det, recordings, audio_pattern, remap_from, remap_to))
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
           night = night_of(recording_date, recording_hour, dawn_hour)) |>
    distinct(site, occasion_id, .keep_all = TRUE) |>
    select(site, occasion_id, source_audio, recording_date, recording_hour,
           night, start, duration) |>
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
export_validation <- function(validation, ocasioes) {
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
  for (col in c("confidence", "clip_start", "clip_end", "inclusion_prob",
                "n_detections_occasion")) {
    if (!col %in% names(validation)) validation[[col]] <- NA_real_
  }
  v <- validation |>
    mutate(site = as.character(site),
           species = folder_name(species_code),
           confidence = as.numeric(confidence),
           tp = case_when(verdict == "positive" ~ 1L,
                          verdict == "negative" ~ 0L,
                          .default = NA_integer_))
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
             n_detections_occasion, verdict, tp, all_of(extras)) |>
      arrange(site, occasion_id, species_code, clip_start)
  )
  gravacoes <- filter(v, sampling_mode == "random_recordings")
  if (nrow(gravacoes) > 0) {
    out$recordings_verified <- gravacoes |>
      select(site, occasion_id, species_code, species, inclusion_prob,
             verdict, present = tp, all_of(extras)) |>
      arrange(site, occasion_id, species_code)
  }
  out
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
# local x especie com predicoes
calibration_draws <- function(fit, pares, min_confidence, grid_step, n_draws,
                              seed) {
  niveis <- fit_levels(fit)
  fora <- setdiff(unique(pares$species), niveis$species)
  if (length(fora) > 0) {
    message("Species not in the calibration, left out of the draws: ",
            paste(fora, collapse = ", "))
  }
  pares <- filter(pares, species %in% niveis$species)
  novos <- setdiff(unique(pares$site), niveis$site)
  if (length(novos) > 0) {
    message("Site(s) not in the calibration, drawn with the species ",
            "effects only: ", paste(novos, collapse = ", "))
  }
  ids <- withr::with_seed(seed, sort(sample.int(
    posterior_size(fit), min(n_draws, posterior_size(fit)))))
  n_g <- length(score_grid(min_confidence, grid_step))
  imap(split(pares$species, pares$site), function(especies, loc) {
    especies <- sort(especies)
    gd <-grid_draws(fit, loc, especies, min_confidence, grid_step,
                     draw_ids = ids)
    tibble(draw = rep(ids, times = ncol(gd$draws)),
           site = loc,
           species = rep(as.character(gd$grid$species), each = length(ids)),
           grid_index = rep(rep(seq_len(n_g), length(especies)),
                            each = length(ids)),
           confidence = rep(gd$grid$confidence, each = length(ids)),
           p_tp = as.vector(gd$draws))
  }) |>
    list_rbind() |>
    arrange(site, species, grid_index, draw)
}

# Numero de amostras da posterior (funcao propria para os testes)
posterior_size <- function(fit) brms::ndraws(fit)
