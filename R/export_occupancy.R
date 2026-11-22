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
#' @param output_dir Character scalar, path to the folder to write. Created
#'   if needed.
#' @param detections A data frame of predictions, one row per BirdNET
#'   prediction, as returned by [read_selection_tables()] (columns `site`,
#'   `species_code`, `confidence`, `begin_path` and `file_offset`).
#' @param recordings `NULL`, a data frame (one row per recording) or a
#'   character scalar, path to a CSV file: the list of all recordings, with
#'   the columns `site` and `source_audio`, as in
#'   [select_clips()]. `NULL` lists the audio files in the folders of the
#'   recordings that have predictions, which then must be reachable (see
#'   `remap_from`).
#' @param validation `NULL`, a character vector of paths or a data frame
#'   (one row per reviewed clip): reviewed clips, without those with an
#'   inherited verdict (see [select_clips()]): paths to
#'   `validation_by_clip.csv`
#'   files (output of [post_validation()]) or a data frame with their
#'   columns, e.g. from [read_validation_tables()] or
#'   [consensus_verdicts()]. `NULL` writes no validation tables.
#' @param fit `NULL` or a `brmsfit` from [fit_calibration()] with
#'   `engine = "brms"`, for `calibration_draws.parquet`.
#' @param sites `NULL` or a data frame of site covariates, one row per
#'   site, with a `site` column.
#' @param occasion_covariates `NULL` or a data frame of covariates of the
#'   occasions (e.g. temperature or the month), with `site` and either
#'   `occasion_id` or `source_audio` (plus `start`, in s, for minute
#'   occasions). One row per occasion; occasions without a row get `NA`.
#'   Columns named like those of `occasions.csv` are refused.
#' @param calibration_keys `NULL` or character vector, grouping variables of
#'   the calibration
#'   model, besides `site` and `species`, that vary between occasions (see
#'   Calibration keys). Only used with `fit`.
#' @param occasion_unit Character scalar, the occasion of the occupancy
#'   model: `"file"` (a
#'   recording) or `"minute"`. Use the value of the clip extraction, so that
#'   the `occasion_id` of the reviewed clips match.
#' @param recording_duration `NULL` or numeric scalar, length of the
#'   recordings (s). Needed for
#'   minute occasions unless the 'av' package can read the files.
#' @param min_confidence Numeric scalar in \[0, 1\]. Predictions below this
#'   confidence are not
#'   written; it is also the lower end of the grid of the calibration
#'   draws. Use the `min_confidence` of the BirdNET run or higher.
#' @param n_draws Integer scalar >= 1, number of posterior draws of the
#'   calibration.
#' @param grid_step Numeric scalar > 0, step of the grid of scores of
#'   the calibration draws.
#' @param seed Integer scalar, seed of the choice of draws and, with
#'   `n_versions`, of the
#'   versions of the detections (`rule = "sample"`). The global random
#'   number generator is left as it was.
#' @param n_versions `NULL` or integer scalar >= 1, number of versions of
#'   the detections to
#'   write to `occasion_draws.parquet`, from the first calibration draws.
#'   Without continuous covariates, `occasion_draws()` is called on the
#'   folder. With them, the versions are always written, and
#'   `NULL` means one per calibration draw (`n_draws`).
#' @param rule,p_min Character scalar (`"sample"` or `"threshold"`) and
#'   numeric scalar in \[0, 1\]: rule of the versions, as in
#'   [occasion_draws()].
#' @param covariate_scaling `NULL` or a list named by covariate, each
#'   element a numeric vector with `center` and `scale`, recording how each
#'   continuous covariate of the calibration was standardised before the
#'   model was fitted, e.g. `list(temp = c(center = 22.4, scale = 3.1))`
#'   for `(temp_raw - 22.4) / 3.1`. It is written to `schema.json` so that
#'   a reader can map the covariate back; the values of
#'   `occasion_covariates` must already be on the scale of the model.
#' @param min_verified Integer scalar. Species with predictions but
#'   fewer than this
#'   number of reviewed detection clips (positive or negative), or without
#'   any positive or any negative clip, are named in a warning: their
#'   false-positive rate will rest on the other species (a community
#'   model) or on the prior. The default is a floor, not a sample size
#'   calculation. Only used with `validation`.
#' @param candidates `NULL`, a character scalar (path) or a data frame: the
#'   `candidates.csv` of the first round of a `"random_detections"`
#'   design. It gives the
#'   stratum of each occasion and, in `schema.json`, the threshold and the
#'   strata of the draw. `NULL` looks for it in the folders of `validation`;
#'   without it, `stratum` is empty unless `validation` has that column, as
#'   after [combine_rounds()]. Only used with `validation`.
#' @param window_step Numeric scalar > 0, time between the starts of
#'   consecutive windows of the
#'   classifier (s), for `n_windows`: 3 for BirdNET without overlap.
#' @param classifier `NULL` or character scalar, label of the classifier,
#'   recorded in `schema.json`.
#' @param overwrite Logical scalar. If `TRUE`, replace an existing export in
#'   `output_dir`.
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
  unit <- match.arg(occasion_unit)
  rule <- match.arg(rule)
  cal_covs <- character()
  if (!is.null(fit)) {
    if (!inherits(fit, "brmsfit")) {
      stop("`fit` must be a model fitted with engine = \"brms\": the ",
           "calibration draws need a posterior.", call. = FALSE)
    }
    require_suggested("arrow", "to write calibration_draws.parquet")
    check_calibration_keys(fit, calibration_keys)
    cal_covs <- calibration_covariates(fit, calibration_keys)
    check_covariate_scaling(covariate_scaling, cal_covs)
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
  check_columns(detections,
                c("site", "species_code", "confidence", "begin_path",
                  "file_offset"),
                "detections", hint = "Read it with read_selection_tables().")

  # Predictions >= min_confidence, each with its occasion
  det <- detections |>
    filter(confidence >= min_confidence) |>
    mutate(site = as.character(site),
           species = folder_name(species_code),
           source_audio = remap_path(begin_path, remap_from, remap_to),
           occasion_id = make_occasion_id(source_audio, file_offset, unit))
  if (!is.null(species)) {
    det <- filter(det, str_extract(species_code, "[^_]+$") %in% .env$species)
  }
  if (nrow(det) == 0) stop("No prediction with confidence >= ", min_confidence, ".")
  det <- check_duplicate_predictions(det)

  occasions <- export_occasions(det, recordings, unit, recording_duration,
                                dawn_hour, audio_pattern, remap_from, remap_to,
                                window_step)
  # predictions in recordings not in the list: the list is incomplete
  no_occasion <- anti_join(distinct(det, site, occasion_id), occasions,
                           by = c("site", "occasion_id"))
  if (nrow(no_occasion) > 0) {
    warning(nrow(no_occasion), " occasion(s) with predictions are not in ",
            "`recordings`; they were added to occasions.csv without a ",
            "recording time. Is the list of recordings complete?",
            call. = FALSE)
    occasions <- bind_rows(occasions, no_occasion) |> arrange(site, occasion_id)
  }
  fixed_cols <- names(occasions)
  occasions <- join_occasion_covariates(occasions, occasion_covariates,
                                        remap_from, remap_to)
  occasions <- add_calibration_keys(occasions, calibration_keys)
  for (v in cal_covs) {
    if (!v %in% names(occasions)) {
      stop("Calibration covariate `", v, "` is not a column of ",
           "`occasion_covariates`.", call. = FALSE)
    }
    if (!is.numeric(occasions[[v]])) {
      stop("Calibration covariate `", v, "` must be numeric in ",
           "`occasion_covariates`.", call. = FALSE)
    }
  }
  covariates <- setdiff(names(occasions), fixed_cols)

  tables <- list(
    occasions = occasions,
    detections = det |>
      select(site, occasion_id, species_code, species, file_offset,
             confidence) |>
      arrange(site, occasion_id, species_code, file_offset),
    scores = det |>
      group_by(site, occasion_id, species_code, species) |>
      summarise(max_score = max(confidence), n_above_min = n(),
                .groups = "drop")
  )
  candidates_tab <- NULL
  if (!is.null(validation)) {
    candidates_tab <- read_candidates(candidates, validation)
    tables <- c(tables,
                export_validation(validation, occasions, candidates_tab))
    check_verification_by_species(tables$validation, unique(det$species),
                                  min_verified)
  }
  tables$sites <- export_sites(sites, unique(occasions$site))

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  # a previous export leaves no tables that this one does not write
  unlink(file.path(output_dir, c(paste0(occupancy_tables, ".csv"),
                                 "calibration_draws.parquet",
                                 "occasion_draws.parquet")))
  iwalk(tables, \(tab, name) write_csv(tab, file.path(output_dir,
                                                      paste0(name, ".csv")),
                                       na = ""))
  table_rows <- map(tables, nrow)

  calibration <- NULL
  versions <- NULL
  if (!is.null(fit) && length(cal_covs) > 0) {
    n_v <- if (is.null(n_versions)) n_draws else n_versions
    od <- covariate_versions(fit, tables$detections, occasions,
                             calibration_keys, cal_covs, n_draws, n_v, rule,
                             p_min, seed)
    arrow::write_parquet(od, file.path(output_dir, "occasion_draws.parquet"))
    tables$occasion_draws <- od
    table_rows$occasion_draws <- nrow(od)
    formula <- tryCatch(deparse1(stats::formula(fit)$formula),
                        error = function(e) NULL)
    cov_range <- map(set_names(cal_covs), \(v) list(
      min = min(fit$data[[v]], na.rm = TRUE),
      max = max(fit$data[[v]], na.rm = TRUE)))
    calibration <- compact(list(
      engine = "brms", formula = formula,
      n_draws = length(unique(od$draw)),
      keys = I(c("site", "species", calibration_keys)),
      covariates = I(cal_covs), covariate_range = cov_range,
      covariate_scaling = if (!is.null(covariate_scaling)) {
        map(covariate_scaling, \(s) list(center = unname(s[["center"]]),
                                         scale = unname(s[["scale"]])))
      },
      new_levels = "uncertainty"))
    versions <- compact(list(
      file = "occasion_draws.parquet", rule = rule,
      p_min = if (rule == "threshold") p_min,
      seed = if (rule == "sample") seed,
      n_draws = length(unique(od$draw)),
      species = I(sort(unique(od$species)))))
  } else if (!is.null(fit)) {
    draws <- calibration_draws(fit, distinct(tables$scores, site, species),
                               min_confidence, grid_step, n_draws, seed,
                               occasions, calibration_keys)
    arrow::write_parquet(draws, file.path(output_dir,
                                          "calibration_draws.parquet"))
    tables$calibration_draws <- draws
    table_rows$calibration_draws <- nrow(draws)
    formula <- tryCatch(deparse1(stats::formula(fit)$formula),
                        error = function(e) NULL)
    calibration <- list(engine = "brms", formula = formula,
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
    occasion_unit = unit,
    min_confidence = min_confidence,
    dawn_hour = dawn_hour,
    window_step = window_step,
    # I(): arrays even with one element (auto_unbox would unbox the vector)
    sites = I(sort(unique(occasions$site))),
    species = I(sort(unique(det$species_code))),
    occasion_covariates = if (length(covariates)) I(covariates),
    tables = imap(table_rows, \(n, name) list(
      file = if (name %in% c("calibration_draws", "occasion_draws")) {
        paste0(name, ".parquet")
      } else paste0(name, ".csv"),
      rows = n)),
    validation_design = validation_design(candidates_tab),
    calibration = calibration,
    occasion_draws = versions
  )
  jsonlite::write_json(compact(schema), file.path(output_dir, "schema.json"),
                       auto_unbox = TRUE, pretty = TRUE, digits = NA)
  message("Export written to ", output_dir, ": ",
          paste(names(table_rows), collapse = ", "), ".")
  # without covariates, the versions come from the grid, as in
  # occasion_draws()
  if (!is.null(n_versions) && length(cal_covs) == 0) {
    tables$occasion_draws <- occasion_draws(
      output_dir, rule = rule, p_min = p_min, n_draws = n_versions,
      seed = seed)
    schema <- jsonlite::read_json(file.path(output_dir, "schema.json"),
                                  simplifyVector = TRUE)
  }
  invisible(list(tables = tables, schema = schema))
}

#' Continuous covariates of a calibration model
#'
#' The numeric variables of the model data other than the score (the keys
#' are grouping factors).
#'
#' @param fit A `brmsfit` calibration model.
#' @param keys Character vector of calibration keys.
#' @return Character vector of covariate names, possibly empty.
#' @noRd
calibration_covariates <- function(fit, keys) {
  model_data <- fit$data
  if (is.null(model_data)) return(character())
  numeric_vars <- names(model_data)[vapply(model_data, is.numeric,
                                           logical(1))]
  setdiff(numeric_vars, c("tp", "logit_conf", keys))
}

#' Check the `covariate_scaling` argument
#'
#' @param scaling `NULL` or a list named by covariate, each element a numeric
#'   vector with `center` and `scale`.
#' @param covs Character vector of the continuous covariates of the
#'   calibration.
#' @return `NULL`, invisibly; errors when `scaling` is malformed.
#' @noRd
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

#' Detection versions under a calibration with continuous covariates
#'
#' Computes P(TP) of each prediction in each draw (without a grid) and draws
#' the versions as in [occasion_draws()].
#'
#' @param fit A `brmsfit` calibration model.
#' @param det A data frame of predictions with `site`, `occasion_id`,
#'   `species` and `confidence`.
#' @param occasions A data frame of occasions with `site`, `occasion_id`, the
#'   keys and the covariates.
#' @param keys Character vector of calibration keys.
#' @param covs Character vector of continuous covariates of the calibration.
#' @param n_draws Integer scalar, number of posterior draws to choose.
#' @param n_versions Integer scalar, number of versions kept (the first
#'   chosen draws).
#' @param rule Character scalar, `"sample"` or `"threshold"`.
#' @param p_min Numeric scalar in \[0, 1\], threshold of `rule = "threshold"`.
#' @param seed Numeric scalar, seed of the draws.
#' @return A tibble with `draw`, `site`, `occasion_id`, `species` and `y`.
#' @noRd
covariate_versions <- function(fit, det, occasions, keys, covs, n_draws,
                               n_versions, rule, p_min, seed) {
  lvls <- fit_levels(fit)
  absent <- setdiff(unique(det$species), lvls$species)
  if (length(absent) > 0) {
    message("Species not in the calibration, left out of the versions: ",
            paste(absent, collapse = ", "))
  }
  message_new_sites(det$site, lvls$site)
  ids <- withr::with_seed(seed, sort(sample.int(
    posterior_size(fit), min(n_draws, posterior_size(fit)))))
  ids <- utils::head(ids, n_versions)
  occ_key <- paste(occasions$site, occasions$occasion_id, sep = "\r")
  spp <- sort(intersect(unique(det$species), lvls$species))
  map(spp, function(sp) {
    d <- det[det$species == sp, ]
    o <- match(paste(d$site, d$occasion_id, sep = "\r"), occ_key)
    nd <- tibble(site = d$site, species = d$species,
                 logit_conf = safe_logit(d$confidence))
    for (k in keys) nd[[k]] <- occasions[[k]][o]
    for (v in covs) nd[[v]] <- occasions[[v]][o]
    scorable <- !is.na(o) & stats::complete.cases(nd)
    for (v in covs) {
      cov_range <- range(fit$data[[v]], na.rm = TRUE)
      out_of_range <- scorable &
        (nd[[v]] < cov_range[1] | nd[[v]] > cov_range[2])
      if (any(out_of_range)) {
        warning(sum(out_of_range), " prediction(s) of ", sp, " have `", v,
                "` outside its range in the calibration data (",
                signif(cov_range[1], 3), " to ", signif(cov_range[2], 3),
                "); their P(TP) is an extrapolation.", call. = FALSE)
      }
    }
    Pdet <- matrix(NA_real_, nrow(d), length(ids))
    if (any(scorable)) {
      # new levels are drawn at random: same seed, same result
      Pdet[scorable, ] <- t(withr::with_seed(seed, prediction_draws(
        fit, nd[scorable, , drop = FALSE], ids)))
    }
    sample_versions(d, occasions, o, Pdet, ids, rule, p_min, seed,
                    reason = "without a value of the calibration covariates or keys")
  }) |>
    list_rbind()
}

#' P(TP) of each row of `newdata` in the chosen draws
#'
#' A separate function so that the tests can mock it.
#'
#' @param fit A `brmsfit` calibration model.
#' @param newdata A data frame of predictor values.
#' @param ids Integer vector of posterior draw identifiers.
#' @return Numeric matrix, draws x rows of `newdata`.
#' @noRd
prediction_draws <- function(fit, newdata, ids) {
  brms::posterior_epred(fit, newdata = newdata, allow_new_levels = TRUE,
                        draw_ids = ids)
}

#' Check for repeated predictions
#'
#' The same window read twice (duplicated selection tables) is dropped with
#' a warning; occasions whose predictions all share one score suggest a
#' score copied between rows (the error of the JAV article) and only raise
#' a warning.
#'
#' @param det A data frame of predictions with `site`, `source_audio`,
#'   `file_offset`, `species_code`, `occasion_id` and `confidence`.
#' @return `det` without the repeated rows.
#' @noRd
check_duplicate_predictions <- function(det) {
  key <- c("site", "source_audio", "file_offset", "species_code")
  repeated <- duplicated(det[key])
  if (any(repeated)) {
    warning(sum(repeated), " prediction(s) repeat the site, recording, ",
            "offset and species of another and were dropped. Was a ",
            "selection table read twice?", call. = FALSE)
    det <- det[!repeated, ]
  }
  groups <- det |>
    group_by(site, occasion_id, species_code) |>
    summarise(n = n(), .n_scores = n_distinct(confidence), .groups = "drop") |>
    filter(n >= 2)
  same_score <- sum(groups$.n_scores == 1)
  if (same_score >= 10 && same_score / nrow(groups) > 0.5) {
    warning(same_score, " of ", nrow(groups),
            " occasion x species with several ",
            "predictions have the same score in all of them. Were the ",
            "scores of an occasion copied to several rows? Then each ",
            "prediction is not a separate detection window.", call. = FALSE)
  }
  det
}

#' Check the calibration keys
#'
#' The calibration keys are grouping factors of the model, besides site and
#' species.
#'
#' @param fit A `brmsfit` calibration model, or `NULL`.
#' @param keys Character vector of calibration keys, or `NULL`.
#' @return `NULL`, invisibly; errors when the keys are invalid.
#' @noRd
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

#' Join occasion covariates to the occasions
#'
#' Matches by `occasion_id`, or by the recording (and the start of the
#' minute).
#'
#' @param occasions A data frame of occasions with `site`, `occasion_id` and
#'   `source_audio`.
#' @param covs `NULL` or a data frame with `site` and `occasion_id` or
#'   `source_audio` (and optionally `start`), plus covariate columns.
#' @param remap_from,remap_to Character scalars or `NULL`, passed to
#'   `remap_path()` for `source_audio`.
#' @return `occasions` with the covariate columns added.
#' @noRd
join_occasion_covariates <- function(occasions, covs, remap_from, remap_to) {
  if (is.null(covs)) return(occasions)
  if (!is.data.frame(covs) || !"site" %in% names(covs)) {
    stop("`occasion_covariates` must be a data frame with a `site` column.",
         call. = FALSE)
  }
  by <- if ("occasion_id" %in% names(covs)) c("site", "occasion_id")
        else if ("source_audio" %in% names(covs)) {
          c("site", "source_audio", if ("start" %in% names(covs)) "start")
        } else {
          stop("`occasion_covariates` needs `occasion_id` or `source_audio`.",
               call. = FALSE)
        }
  if (identical(by, c("site", "source_audio")) &&
      anyDuplicated(occasions[c("site", "source_audio")])) {
    stop("Minute occasions: `occasion_covariates` needs a `start` column, ",
         "or `occasion_id`.", call. = FALSE)
  }
  extras <- setdiff(names(covs), by)
  clash <- intersect(extras, names(occasions))
  if (length(clash) > 0) {
    stop("`occasion_covariates` has column(s) named like those of ",
         "occasions.csv: ", paste(clash, collapse = ", "), ".", call. = FALSE)
  }
  if (length(extras) == 0) {
    stop("`occasion_covariates` has no covariate column.", call. = FALSE)
  }
  covs <- mutate(covs, site = as.character(site))
  if ("source_audio" %in% by) {
    covs$source_audio <- remap_path(covs$source_audio, remap_from, remap_to)
  }
  if ("occasion_id" %in% by) covs$occasion_id <- as.character(covs$occasion_id)
  if ("start" %in% by) covs$start <- as.numeric(covs$start)
  if (anyDuplicated(covs[by])) {
    stop("`occasion_covariates` has more than one row for some occasion.",
         call. = FALSE)
  }
  absent <- nrow(anti_join(covs, occasions, by = by))
  if (absent > 0) {
    warning(absent, " row(s) of `occasion_covariates` match no occasion.",
            call. = FALSE)
  }
  left_join(occasions, covs[c(by, extras)], by = by)
}

#' Add the calibration key columns to the occasions
#'
#' The key columns are stored as text; `month` is taken from the recording
#' date when it was not given.
#'
#' @param occasions A data frame of occasions with `recording_date`.
#' @param keys Character vector of calibration keys, or `NULL`.
#' @return `occasions` with the key columns as character.
#' @noRd
add_calibration_keys <- function(occasions, keys) {
  for (k in keys) {
    if (!k %in% names(occasions)) {
      if (k != "month") {
        stop("Calibration key `", k, "` is not a column of ",
             "`occasion_covariates`.", call. = FALSE)
      }
      occasions$month <- substr(occasions$recording_date, 1, 6)
    }
    occasions[[k]] <- as.character(occasions[[k]])
    no_value <- is.na(occasions[[k]]) | !nzchar(occasions[[k]])
    if (any(no_value)) {
      warning(sum(no_value),
              " occasion(s) have no value of the calibration key `",
              k, "`; their predictions cannot be scored.", call. = FALSE)
      occasions[[k]][no_value] <- NA_character_
    }
  }
  occasions
}

#' CSV tables of the export schema, in the order of schema.json
#' @noRd
occupancy_tables <- c("occasions", "detections", "scores", "validation",
                      "recordings_verified", "sites")

#' Build the table of all occasions
#'
#' Every recording (or minute) is an occasion, with or without predictions.
#'
#' @param det A data frame of predictions.
#' @param recordings `NULL`, a data frame or a folder of recordings, passed to
#'   `get_recordings()`.
#' @param unit Character scalar, `"file"` or `"minute"`.
#' @param recording_duration Numeric scalar or `NULL`, duration of the
#'   recordings in seconds.
#' @param dawn_hour Integer scalar, hour that ends a night.
#' @param audio_pattern Character scalar, regular expression of audio files.
#' @param remap_from,remap_to Character scalars or `NULL`, path remapping.
#' @param window_step Numeric scalar, step of the detection windows in
#'   seconds.
#' @return A tibble with `site`, `occasion_id`, `source_audio`,
#'   `recording_date`, `recording_hour`, `night`, `start`, `duration` and
#'   `n_windows`, one row per occasion.
#' @noRd
export_occasions <- function(det, recordings, unit, recording_duration,
                             dawn_hour, audio_pattern, remap_from, remap_to,
                             window_step) {
  recs <- suppressMessages(
    get_recordings(det, recordings, audio_pattern, remap_from, remap_to))
  if (unit == "minute") {
    recs <- recs |>
      mutate(.dur = audio_duration(source_audio, recording_duration))
    if (anyNA(recs$.dur)) {
      stop(sum(is.na(recs$.dur)), " recording(s) without a readable ",
           "duration; set `recording_duration`.", call. = FALSE)
    }
    recs <- recs |>
      mutate(start = map(.dur, \(d) (seq_len(ceiling(d / 60)) - 1) * 60)) |>
      unnest(start) |>
      mutate(duration = pmin(60, .dur - start)) |>
      select(-.dur)
  } else {
    recs <- mutate(recs, start = 0,
                   duration = if (is.null(recording_duration)) NA_real_
                              else recording_duration)
  }
  recs |>
    mutate(site = as.character(site),
           occasion_id = make_occasion_id(source_audio, start, unit),
           night = night_of(recording_date, recording_hour, dawn_hour),
           # round(): 0.3 / 0.1 must not become 4 windows
           n_windows = as.integer(ceiling(round(duration / window_step, 6)))) |>
    distinct(site, occasion_id, .keep_all = TRUE) |>
    select(site, occasion_id, source_audio, recording_date, recording_hour,
           night, start, duration, n_windows) |>
    arrange(site, occasion_id)
}

#' Night of a recording
#'
#' Recordings before `dawn_hour` belong to the night of the previous day, as
#' in [score_detections()].
#'
#' @param recording_date Character vector of dates as `YYYYMMDD`.
#' @param recording_hour Vector of hours, coercible to integer.
#' @param dawn_hour Integer scalar, hour that ends a night.
#' @return Character vector of nights as `YYYYMMDD`.
#' @noRd
night_of <- function(recording_date, recording_hour, dawn_hour) {
  hour <- suppressWarnings(as.integer(recording_hour))
  previous <- format(as.Date(recording_date, "%Y%m%d") - 1, "%Y%m%d")
  if_else(!is.na(hour) & hour < dawn_hour, previous, recording_date)
}

#' Build the tables of reviewed clips
#'
#' Splits the reviewed clips into those of detections (`validation`) and the
#' recordings annotated by ear (`recordings_verified`), which give the state
#' of the occasion.
#'
#' @param validation A data frame of reviewed clips, or a character vector
#'   of validation table paths.
#' @param occasions A data frame of occasions with `site` and `occasion_id`.
#' @param candidates `NULL` or a data frame read from `candidates.csv`.
#' @return A list with the tibble `validation` and, when there are
#'   recordings reviewed by ear, `recordings_verified`.
#' @noRd
export_validation <- function(validation, occasions, candidates = NULL) {
  if (is.character(validation)) {
    validation <- read_validation_tables(validation)
  }
  validation <- from_legacy(validation)
  check_columns(validation,
                c("site", "species_code", "occasion_id", "sampling_mode",
                  "verdict"),
                "validation", hint = "Was it written by post_validation()?")
  # an inherited verdict is the same judgement of the other design: exporting
  # it would give the model two observations of it
  inherited <- is_inherited(validation)
  if (any(inherited)) {
    warning(sum(inherited), " clip(s) with an inherited verdict left out, as ",
            "they repeat a judgement. They are chosen by their verdict, which ",
            "can bias the rates that an occupancy model estimates from these ",
            "tables; review them (`inherit = FALSE` in select_clips()) if ",
            "they are many.", call. = FALSE)
    validation <- validation[!inherited, ]
  }
  for (col in c("confidence", "clip_start", "clip_end", "inclusion_prob",
                "n_detections_occasion", "round", "n_candidates", "n_drawn")) {
    if (!col %in% names(validation)) validation[[col]] <- NA_real_
  }
  if (!"stratum" %in% names(validation)) validation$stratum <- NA_character_
  validation <- join_candidates(validation, candidates)
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
  absent <- anti_join(distinct(v, site, occasion_id), occasions,
                    by = c("site", "occasion_id"))
  if (nrow(absent) > 0) {
    warning(nrow(absent), " reviewed occasion(s) do not match any occasion; ",
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
  n_bands <- sum(out$validation$sampling_mode %in% "score_bands")
  if (n_bands > 0) {
    warning(n_bands, " reviewed clip(s) of sampling_mode = \"score_bands\" ",
            "are written to validation.csv. They were chosen by their score, ",
            "so they serve thresholds and calibration but not the ",
            "false-positive rate of an occupancy model: crywolf drops them. ",
            "Use \"random_detections\" or \"random_recordings\" clips for ",
            "the occupancy model.", call. = FALSE)
  }
  recs <- filter(v, sampling_mode == "random_recordings")
  in_both <- semi_join(
    distinct(filter(out$validation, sampling_mode %in%
                      c("random_detections", "directed_pps")),
             site, species_code, occasion_id),
    recs, by = c("site", "species_code", "occasion_id"))
  if (nrow(in_both) > 0) {
    warning(nrow(in_both), " occasion(s) are in both `validation` and ",
            "`recordings_verified`. A model that reads both takes them as ",
            "two independent reviews; say so if the clips also set the ",
            "thresholds, and check that one verdict was not copied from the ",
            "other.", call. = FALSE)
  }
  if (nrow(recs) > 0) {
    out$recordings_verified <- recs |>
      select(site, occasion_id, species_code, species, inclusion_prob,
             verdict, present = tp, all_of(extras)) |>
      arrange(site, occasion_id, species_code)
  }
  out
}

#' Add the stratum and N of the drawn occasions from the candidates
#'
#' Fills `stratum` and `n_candidates` of `"random_detections"` clips when the
#' table lacks them; the other designs stay without them, even in an
#' occasion that was also a candidate.
#'
#' @param validation A data frame of reviewed clips with the occasion key
#'   columns, `sampling_mode`, `stratum` and `n_candidates`.
#' @param candidates `NULL` or a data frame of candidate occasions with the
#'   occasion key columns, `stratum` and `n_candidates`.
#' @return `validation` with `stratum` and `n_candidates` filled.
#' @noRd
join_candidates <- function(validation, candidates) {
  if (is.null(candidates)) return(validation)
  validation |>
    mutate(across(all_of(occasion_key), as.character)) |>
    left_join(candidates |>
                mutate(across(all_of(occasion_key), as.character)) |>
                select(all_of(occasion_key), .cand_stratum = stratum,
                       .n = n_candidates),
              by = occasion_key) |>
    mutate(.drawn = sampling_mode == "random_detections",
           stratum = if_else(.drawn,
                             coalesce(as.character(stratum), .cand_stratum),
                             as.character(stratum)),
           n_candidates = if_else(.drawn,
                                  coalesce(as.integer(n_candidates), .n),
                                  as.integer(n_candidates))) |>
    select(-.cand_stratum, -.n, -.drawn)
}

#' Warn about clips reviewed in more than one design
#'
#' The same clip in two designs is a single judgement, or two that a model
#' would read as independent.
#'
#' @param validation A data frame of reviewed clips with `site`,
#'   `occasion_id`, `species_code`, `clip_start` and `sampling_mode`.
#' @return Called for its side effect (a warning).
#' @noRd
check_clips_in_both_designs <- function(validation) {
  in_both <- validation |>
    distinct(site, occasion_id, species_code, clip_start, sampling_mode) |>
    count(site, occasion_id, species_code, clip_start) |>
    filter(n > 1)
  if (nrow(in_both) > 0) {
    designs <- validation |>
      semi_join(in_both, by = c("site", "occasion_id", "species_code",
                                 "clip_start")) |>
      pull(sampling_mode) |>
      unique() |>
      sort()
    warning(nrow(in_both), " clip(s) are in more than one design (",
            paste0("\"", designs, "\"", collapse = ", "), "). A model that ",
            "reads both designs takes them as two reviews; keep one of each.",
            call. = FALSE)
  }
}

#' What a negative verdict covers within an occasion x species
#'
#' `"occasion"` when every prediction above the threshold of the draw has a
#' verdict; otherwise only the clip.
#'
#' @param sampling_mode Character vector of sampling modes of one occasion x
#'   species.
#' @param tp Integer vector of verdicts (1, 0 or `NA`), same length.
#' @param n_detections_occasion Numeric vector, the number of predictions of
#'   the occasion above the threshold.
#' @return Character vector of `"occasion"` or `"clip"`, same length.
#' @noRd
review_scope <- function(sampling_mode, tp, n_detections_occasion) {
  complete <- sampling_mode %in% c("random_detections", "directed_pps") &
    sum(!is.na(tp)) == n_detections_occasion
  if_else(coalesce(complete, FALSE), "occasion", "clip")
}

#' Design of the draw, from candidates.csv
#'
#' @param candidates `NULL` or a data frame read from `candidates.csv`.
#' @return `NULL` or a list with the non-missing `threshold`, `strata`,
#'   `occasion_unit` and `capped`.
#' @noRd
validation_design <- function(candidates) {
  if (is.null(candidates)) return(NULL)
  fields <- list(threshold = candidates$threshold[1],
                 strata = candidates$strata[1],
                 occasion_unit = candidates$occasion_unit[1],
                 capped = candidates$capped[1])
  discard(fields, \(x) is.null(x) || is.na(x))
}

#' Warn about species with few reviewed clips
#'
#' With few clips, or without a positive or a negative one, the
#' false-positive rate of a species does not come from its own data.
#'
#' @param validation A data frame with `species` and `tp`.
#' @param spp Character vector of the exported species.
#' @param min_verified Integer scalar, the minimum number of reviewed clips.
#' @return `NULL`, invisibly; called for its warning.
#' @noRd
check_verification_by_species <- function(validation, spp, min_verified) {
  by_sp <- tibble(species = spp) |>
    left_join(validation |> filter(!is.na(tp)) |>
                group_by(species) |>
                summarise(n = n(), pos = sum(tp), .groups = "drop"),
              by = "species") |>
    mutate(n = coalesce(n, 0L), pos = coalesce(pos, 0L), neg = n - pos) |>
    filter(n < min_verified | pos == 0 | neg == 0) |>
    arrange(n, species)
  if (nrow(by_sp) == 0) return(invisible())
  warning(nrow(by_sp), " species with fewer than ", min_verified,
          " reviewed clips, or without a positive or a negative one: ",
          paste0(by_sp$species, " (", by_sp$n, ": ", by_sp$pos, "+ ",
                 by_sp$neg, "-)", collapse = ", "),
          ". Their false-positive rates will rest on the other species ",
          "(a community model) or on the prior.", call. = FALSE)
}

#' Build the table of site covariates
#'
#' Sites without a row in `sites` get `NA`.
#'
#' @param sites `NULL` or a data frame with a `site` column.
#' @param site_names Character vector of the exported sites.
#' @return A tibble with `site` and the covariates, one row per site.
#' @noRd
export_sites <- function(sites, site_names) {
  base <- tibble(site = sort(site_names))
  if (is.null(sites)) return(base)
  if (!"site" %in% names(sites)) {
    stop("`sites` must have a `site` column.", call. = FALSE)
  }
  sites <- mutate(sites, site = as.character(site))
  no_covs <- setdiff(site_names, sites$site)
  if (length(no_covs) > 0) {
    warning("Site(s) without covariates in `sites`: ",
            paste(no_covs, collapse = ", "), call. = FALSE)
  }
  left_join(base, sites, by = "site")
}

#' Posterior draws of P(TP) on the score grid
#'
#' Draws for every site x species pair with predictions and, with keys, for
#' every combination of key levels among the occasions of the site.
#'
#' @param fit A `brmsfit` calibration model.
#' @param pairs A data frame with `site` and `species`.
#' @param min_confidence Numeric scalar in \[0, 1\], the lowest score.
#' @param grid_step Numeric scalar, the grid step.
#' @param n_draws Integer scalar, number of posterior draws.
#' @param seed Numeric scalar, seed of the choice of draws and of new levels.
#' @param occasions `NULL` or a data frame of occasions with `site` and the
#'   keys.
#' @param keys Character vector of calibration keys, or `NULL`.
#' @return A tibble with `draw`, `site`, `species`, the keys, `grid_index`,
#'   `confidence` and `p_tp`.
#' @noRd
calibration_draws <- function(fit, pairs, min_confidence, grid_step, n_draws,
                              seed, occasions = NULL, keys = NULL) {
  lvls <- fit_levels(fit)
  absent <- setdiff(unique(pairs$species), lvls$species)
  if (length(absent) > 0) {
    message("Species not in the calibration, left out of the draws: ",
            paste(absent, collapse = ", "))
  }
  pairs <- filter(pairs, species %in% lvls$species)
  message_new_sites(pairs$site, lvls$site)
  ids <- withr::with_seed(seed, sort(sample.int(
    posterior_size(fit), min(n_draws, posterior_size(fit)))))
  n_g <- length(score_grid(min_confidence, grid_step))
  combos <- if (length(keys)) {
    distinct(occasions[c("site", keys)]) |>
      filter(if_all(all_of(keys), \(x) !is.na(x)))
  } else {
    tibble(site = unique(pairs$site))
  }
  # new key levels are drawn at random: same seed, same result
  withr::with_seed(seed, {
    pmap(combos, function(site, ...) {
      key_levels <- list(...)
      spp <- sort(pairs$species[pairs$site == site])
      if (length(spp) == 0) return(NULL)
      gd <- grid_draws(fit, site, spp, min_confidence, grid_step,
                       draw_ids = ids, keys = key_levels)
      out <- tibble(draw = rep(ids, times = ncol(gd$draws)),
                    site = site,
                    species = rep(as.character(gd$grid$species),
                                  each = length(ids)))
      for (k in names(key_levels)) out[[k]] <- key_levels[[k]]
      out$grid_index <- rep(rep(seq_len(n_g), length(spp)),
                            each = length(ids))
      out$confidence <- rep(gd$grid$confidence, each = length(ids))
      out$p_tp <- as.vector(gd$draws)
      out
    })
  }) |>
    list_rbind() |>
    arrange(site, species, across(all_of(keys)), grid_index, draw)
}

#' Number of posterior draws of a model
#'
#' A separate function so that the tests can mock it.
#'
#' @param fit A `brmsfit` model.
#' @return Integer scalar.
#' @noRd
posterior_size <- function(fit) brms::ndraws(fit)

#' Report sites absent from the calibration
#'
#' These sites are drawn as new levels of the site effect.
#'
#' @param sites Character vector of the sites of the predictions.
#' @param calibrated Character vector of the sites in the calibration.
#' @return The new sites, invisibly.
#' @noRd
message_new_sites <- function(sites, calibrated) {
  new_sites <- setdiff(unique(sites), calibrated)
  if (length(new_sites) > 0) {
    message("Site(s) not in the calibration, drawn as new levels of the ",
            "site effect: ", paste(new_sites, collapse = ", "))
  }
  invisible(new_sites)
}
