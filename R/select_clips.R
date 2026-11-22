#' Select the clips to validate
#'
#' Applies the sampling design to the predictions read by
#' [read_selection_tables()] and returns the clip manifest: one row per clip
#' to cut, with its site, species, night, source audio, start and end. No
#' audio is read or written; cut the clips with [cut_clips()].
#'
#' @section Sampling modes:
#' * `"top"` keeps the `n_top` predictions with the highest confidence per
#'   site x species x night x hour. It serves classifier retraining and the
#'   score-to-probability calibration of [calibrate()]. Do not use it to
#'   estimate false-positive rates: top-score clips hold fewer false
#'   positives than a random sample.
#' * `"random_detections"` draws, at random, `n_top` occasions per
#'   stratum (by default site x species x night x hour; see `strata`)
#'   among the occasions with at least one
#'   prediction of the species with confidence >= `threshold`, and keeps
#'   every prediction >= `threshold` of each drawn occasion. This is the
#'   observation-confirmation design of Chambert et al. (2015,
#'   \doi{10.1890/14-1507.1}).
#' * `"random_recordings"` draws recordings (or minutes) among all those
#'   recorded, with or without predictions, in proportion to the effort of
#'   each site, for annotation by ear. This is the multiple-method design of
#'   Miller et al. (2011, \doi{10.1890/10-1396.1}). The clip is the whole
#'   recording (or minute), copied once per species to annotate, and
#'   `confidence` is `NA`.
#' * `"score_bands"` draws, at random, `n_top` predictions per stratum and
#'   score band (`score_breaks`, by default 0.1 to 0.4, 0.4 to 0.7 and 0.7 to 1),
#'   with `inclusion_prob = n_drawn / n_candidates` in each stratum x band.
#'   The same number of clips per band covers the whole score range, which
#'   is where a threshold and a calibration curve are estimated, and the
#'   weights `1 / inclusion_prob` restore the true proportions when bands
#'   are pooled (Wood & Kahl 2024, \doi{10.1007/s10336-024-02144-5}).
#'
#' In the random modes, use the same `threshold` as the occupancy analysis.
#'
#' @section Which design for which use:
#' The draw decides what the reviewed clips can be used for:
#'
#' | Use | `"top"` | `"random_detections"` | `"random_recordings"` | `"score_bands"` |
#' |---|---|---|---|---|
#' | retraining the classifier | yes | yes | yes | yes |
#' | calibration curve ([calibrate()], [fit_calibration()]) | high scores only | yes | no score | yes, best near the threshold |
#' | threshold by weighted precision ([suggest_thresholds()]) | no (no `inclusion_prob`) | yes | no score | yes |
#' | false-positive occupancy models (crywolf) | dropped | yes | yes (annotated occasions) | **no** |
#'
#' The clips of `"score_bands"` are chosen by their score, so they cannot
#' estimate the false-positive rate of the observation-confirmation design,
#' which needs clips chosen independently of the score:
#' [export_occupancy_data()] writes them to `validation.csv` with a warning,
#' and `crywolf::fp_read_sheepdog()` drops them with a warning, or stops
#' when they are the only reviewed clips. For both uses in one project,
#' draw a `"random_detections"` round for the occupancy model and a
#' `"score_bands"` round for the threshold; a clip drawn by both is
#' reviewed once (`previous`, `inherit`).
#'
#' @section Review rounds:
#' `previous` draws one more round of a design without repeating what was
#' reviewed. In `"random_detections"`, the occasions drawn earlier leave the
#' pool and `n_top` occasions are drawn per stratum among the rest. Drawing
#' `n1` occasions of `N` and then `n2` of the `N - n1` left gives a simple
#' random sample of `n1 + n2`, so after each round every clip has the
#' inclusion probability `n_drawn / n_candidates`, whatever its round. This
#' needs the same candidates, strata, threshold and occasion unit in every
#' round. The first round therefore keeps a list of its candidates, in the
#' attribute `"candidates"` of the manifest, written to `candidates.csv` by
#' [extract_validation_clips()]; later rounds draw from that list, and a
#' warning says when the predictions have changed. A different `threshold`,
#' `occasion_unit` or `strata` is refused, and so are `target_total` and
#' `max_per_species`, whose second stage depends on the counts of each
#' round. Round `k` uses the seed `seed + k - 1`.
#'
#' The tables of earlier rounds keep the probability of their own round:
#' use [combine_rounds()] to stack them. In `"top"`, there is no inclusion
#' probability, and `previous` only leaves out the clips already reviewed.
#' `previous` is not available for `"random_recordings"`, and a
#' `"score_bands"` round has no later rounds of its own; to add clips near
#' the threshold after `"random_detections"` rounds, draw a `"score_bands"`
#' round with those rounds as `previous` of the other design, and stack all
#' of them with [combine_rounds()], which keeps the `inclusion_prob` of the
#' `"score_bands"` clips.
#'
#' Choosing the cells of a round from their verdicts, and stopping when a
#' cell reaches a target, makes the stopping depend on the results; see
#' `vignette("validation-effort")`.
#'
#' @section Reusing the other design:
#' A study can draw both `"random_detections"` and `"random_recordings"`.
#' With `previous` of the other design, the occasions reviewed there stay in
#' the pool, so that this draw remains independent and its inclusion
#' probabilities do not change, and `previously_reviewed` marks the clips
#' that overlap an earlier review, matching site, species, recording and
#' time, so that minutes and files can be mixed. With `inherit = TRUE`, what
#' the earlier review already tells is reused:
#'
#' | Earlier review | This draw | Inherited | Still to review |
#' | --- | --- | --- | --- |
#' | recording absent | `"random_detections"` | every prediction is negative | nothing |
#' | recording present | `"random_detections"` | nothing | the clips |
#' | a positive prediction | `"random_recordings"` | the recording is present | nothing |
#' | only negative predictions | `"random_recordings"` | nothing | the recording |
#'
#' The species may have called below the threshold, so negative predictions
#' say nothing about the recording. [cut_clips()] skips the clips with an
#' `inherited_verdict`, the review app leaves them out, and
#' [post_validation()] fills them in, so that the table of each design is
#' complete for its precision and thresholds.
#' [export_occupancy_data()] leaves them out: an inherited verdict is the
#' same judgement as the earlier one, and exporting it would give a model two
#' observations of it.
#'
#' `inherit` is `FALSE` by default because of that last step. The occasions
#' left out are chosen by their verdict (present recordings, negative clips),
#' which can bias what an occupancy model estimates from those tables. The
#' overlap between two random draws is usually small, so reviewing it costs
#' little; use `inherit = TRUE` when the tables will not go to an occupancy
#' model.
#'
#' @param detections A data frame of predictions, one row per BirdNET
#'   prediction, as returned by [read_selection_tables()] (columns `site`,
#'   `begin_path`, `begin_time`, `end_time`, `file_offset`, `confidence`
#'   and `species_code`).
#' @param sampling_mode Character scalar, one of `"top"`,
#'   `"random_detections"`, `"random_recordings"` or `"score_bands"`. See
#'   *Sampling modes* and
#'   *Which design for which use*.
#' @param occasion_unit Character scalar, the occasion of the occupancy
#'   model: `"file"` (the whole recording) or `"minute"` (minute of the
#'   file, from
#'   `file_offset`).
#' @param threshold `NULL` or numeric scalar in \[0, 1\], confidence
#'   threshold of the occupancy analysis. It
#'   defines the candidate occasions of `"random_detections"` and the
#'   `n_detections_occasion` column. `NULL` leaves that column `NA`.
#' @param n_top Integer scalar >= 1. `"top"`: predictions kept per site x
#'   species x night x
#'   hour. `"random_detections"`: occasions drawn per stratum (`strata`).
#'   `"score_bands"`: predictions drawn per stratum and score band.
#' @param score_breaks Numeric vector of length >= 2, strictly increasing,
#'   within 0 and 1. `"score_bands"`: the limits of the score bands.
#'   Predictions below the first limit are not
#'   drawn; the last band includes its upper limit.
#' @param strata Character scalar (a preset name) or character vector (column
#'   names). `"random_detections"` and `"score_bands"`: the strata of
#'   the draw (within each, `"score_bands"` also splits by score band)
#'   (ignored by the other modes). Either one of the presets, all within
#'   site x species:
#'   * `"night_hour"`: night x hour (the rule of 2.0.0);
#'   * `"night"`: night;
#'   * `"hour"`: hour of the day, pooling the nights (covers the diel
#'     cycle without fixing the night);
#'   * `"week"`: ISO week of the night (`YYYY-Www`);
#'   * `"month"`: month of the night (`YYYY-MM`), which spreads the draw
#'     over the season;
#'   * `"site_species"`: no further stratification;
#'   * `"species"` (`"score_bands"` only): the species alone, pooling the
#'     sites, for a threshold of the species when the cut per site x band
#'     would be too coarse (with 60 sites and 3 bands, the smallest step is
#'     180 clips); `inclusion_prob` is then the share drawn among the
#'     predictions of the species in the band;
#'
#'   or a character vector of column names of `detections`, e.g.
#'   `c("site", "species_code", "habitat", "night")`, for strata defined by
#'   the user. Columns can be added to `detections` before the call; since
#'   site and species are always part of the strata, useful columns vary
#'   within a site (the moon phase, the rain of the night, a recorder when
#'   a site has several). `month` and `week` can also be used and are
#'   derived from the night when absent.
#'   Except for `"species"`, `site` and `species_code` are always added to
#'   the strata, which keeps
#'   `inclusion_prob` exact when `target_total` or `max_per_species` draw
#'   again within site x species. Columns that depend on the score
#'   (`confidence`, `rank`) are refused, since the observation-confirmation
#'   design needs strata independent of the score, and every stratum
#'   column must be constant within an occasion.
#'
#'   With one recording per hour and `occasion_unit = "file"`,
#'   `"night_hour"` holds a single occasion per stratum and draws nothing
#'   (every `inclusion_prob` is 1); a coarser stratum makes the draw
#'   random. With strata without the hour and `balance_by_hour = TRUE`
#'   under `target_total` or `max_per_species`, `inclusion_prob` is
#'   conditional on the first draw (a warning says so).
#' @param covariates `NULL` or a data frame of occasion covariates.
#'   `"random_detections"`: its columns can be used in `strata`, such as
#'   the bins of an environmental gradient or of an acoustic index made by
#'   [covariate_bins()]. It is joined to the predictions by the columns it
#'   shares with them among `site`, `night`, `recording_date`,
#'   `recording_hour`, `source_audio` and `occasion_id` (compared as
#'   character; `night` and `recording_date` are `YYYYMMDD`). Occasions
#'   without a match form a stratum of their own, with a warning. A
#'   stratum other than site, species and time may be related to the
#'   verdict, so the calibration should include it or weight the clips by
#'   `inclusion_prob` (a message says so).
#' @param recording_fraction Numeric scalar in \[0, 1\].
#'   `"random_recordings"`: fraction of the
#'   recordings (or minutes) drawn at each site, rounded, with at least one
#'   per site. The default (1 %) suits large projects: with fewer than 150
#'   recordings per site it draws a single recording; raise it or use
#'   `n_recordings_per_site` in small projects.
#' @param n_recordings_per_site `NULL` or integer scalar >= 1.
#'   `"random_recordings"`: fixed number of
#'   recordings (or minutes) per site, used instead of `recording_fraction`.
#' @param recordings `NULL`, a data frame (one row per recording) or a
#'   character scalar, path to a CSV file. `"random_recordings"`: the list
#'   of all recordings, with the columns `site` and
#'   `source_audio` (the v1.2.0 columns `local` and `caminho_audio` are
#'   also read). `NULL` lists the files matching `audio_pattern` in the
#'   audio folders that appear in `begin_path`; folders without any
#'   prediction are then left out.
#' @param audio_pattern Character scalar, regular expression for the audio
#'   files listed when
#'   `recordings` is `NULL`.
#' @param recording_duration `NULL` or numeric scalar, length of the
#'   recordings (s), for
#'   `occasion_unit = "minute"` in `"random_recordings"` and for the end of
#'   whole-recording clips. `NULL` reads each file with the 'av' package
#'   when needed (minute occasions) and leaves `clip_end` as `NA` otherwise.
#' @param min_confidence `NULL` or numeric scalar in \[0, 1\], minimum
#'   confidence of a candidate prediction in
#'   `"top"`. `NULL` applies no filter. The random modes use `threshold`.
#' @param sites `NULL` or character vector of site names. Restrict to these
#'   sites (the predictions and, in
#'   `"random_recordings"`, the list of recordings). `NULL` keeps all.
#' @param date_start,date_end `NULL` or character scalars, date window of
#'   the recordings (`"YYYYMMDD"`). `NULL` leaves that side open.
#' @param species `NULL` or character vector. Restrict to these short
#'   species codes (the last part of
#'   `species_code`, e.g. `"boa-ran"`). `NULL` keeps all.
#' @param hour_start,hour_end `NULL` or integer scalars in 0-23, hour
#'   window. It can cross midnight:
#'   `hour_start = 17, hour_end = 2` keeps 17h-23h and 0h-2h, and the
#'   grouping becomes by night (small hours count as the night before).
#'   `NULL` applies no filter.
#' @param alternate_days Logical scalar. If `TRUE`, keep alternate days (or
#'   nights), anchored on the
#'   first date of each site.
#' @param target_total `NULL` or integer scalar >= 1, total clips per site,
#'   split evenly among species by
#'   water filling: species with fewer clips than the quota enter whole and
#'   the surplus goes to the others. In `"random_detections"` it counts
#'   occasions. Ignored in `"random_recordings"`. `NULL` sets no target.
#'   Because the target is split evenly, rare species have higher
#'   inclusion probabilities than common ones: estimates pooled across
#'   species must weight the clips by `1 / inclusion_prob`.
#' @param balance_by_hour Logical scalar. If `TRUE`, within each species,
#'   draw round-robin across the
#'   hours of the day (covers the diel cycle) when applying `target_total`
#'   or `max_per_species`.
#' @param max_per_species `NULL` or integer scalar >= 1. Simpler
#'   alternative to `target_total`: a fixed
#'   limit per site x species. Ignored when `target_total` is set.
#' @param remap_from,remap_to `NULL` or character scalars. Replace the
#'   prefix `remap_from` of the
#'   `begin_path` paths by `remap_to`, e.g. `"N:/"` and `"/Volumes/Arara/"`.
#'   Backslashes are turned into forward slashes first.
#' @param previous `NULL`, a character vector of paths, a data frame, or a
#'   list of these. Earlier reviews: paths to their `clip_manifest.csv` or
#'   `validation_by_clip.csv`, or their tables. Rounds of the
#'   same design give another round (see Review rounds); reviews of the other
#'   random design, which need `validation_by_clip.csv`, give their verdicts
#'   (see Reusing the other design).
#' @param candidates `NULL`, a character scalar (path) or a data frame. With
#'   `previous`, the `candidates.csv` of the first round. `NULL` looks for
#'   it in the folders of
#'   `previous`.
#' @param cells `NULL` or a data frame, one row per cell. With `previous`,
#'   restrict the round to these cells: a data
#'   frame with `site` and `species_folder` or `species_code`, such as the
#'   rows of [review_support()] with `diagnosis == "review more"`.
#' @param inherit Logical scalar. With `previous` of the other design, give
#'   the clips the
#'   verdict that the earlier review implies, so that they need no review.
#'   See Reusing the other design.
#' @param seed Integer scalar, seed of every random draw. The global random
#'   number
#'   generator is left as it was.
#'
#' @return A tibble, the clip manifest without `status`, with the columns
#'   `site`, `species_code`, `species_folder`, `recording_date`, `night`,
#'   `recording_hour`, `rank`, `confidence`, `clip_file`, `clip_start`,
#'   `clip_end`, `duration`, `source_audio`, `begin_path`, `sampling_mode`,
#'   `occasion_id`, `n_detections_occasion`, `inclusion_prob` (cumulative
#'   over the rounds), `round`, `n_candidates` (`N` of the stratum), `n_drawn`
#'   (occasions drawn in the stratum, all rounds so far; both `NA` outside
#'   `"random_detections"` and under a cap) and `inclusion_prob_round` (the
#'   draw of that round alone), `previously_reviewed`, `inherited_verdict`
#'   and `source_design` (see Reusing the other design). See
#'   `vignette("crywolf-integration")` for their definitions.
#' @export
select_clips <- function(detections,
                         sampling_mode = c("top", "random_detections",
                                           "random_recordings",
                                           "score_bands"),
                         occasion_unit = c("file", "minute"),
                         threshold = NULL,
                         n_top = 2,
                         strata = "night_hour",
                         score_breaks = c(0.1, 0.4, 0.7, 1),
                         covariates = NULL,
                         recording_fraction = 0.01,
                         n_recordings_per_site = NULL,
                         recordings = NULL,
                         audio_pattern = "\\.(wav|flac|mp3)$",
                         recording_duration = NULL,
                         min_confidence = 0.1,
                         sites = NULL,
                         date_start = NULL,
                         date_end = NULL,
                         species = NULL,
                         hour_start = NULL,
                         hour_end = NULL,
                         alternate_days = FALSE,
                         target_total = NULL,
                         balance_by_hour = TRUE,
                         max_per_species = NULL,
                         remap_from = NULL,
                         remap_to = NULL,
                         seed = 2026,
                         previous = NULL,
                         candidates = NULL,
                         cells = NULL,
                         inherit = FALSE) {
  samp_mode    <- match.arg(sampling_mode)
  strata_cols <- resolve_strata(strata, samp_mode)
  strata_label  <- paste(strata_cols, collapse = " x ")
  occ_unit <- match.arg(occasion_unit)
  check_prob(threshold, "threshold", null_ok = TRUE)
  check_number(n_top, "n_top", lower = 1, integer = TRUE)
  check_prob(recording_fraction, "recording_fraction")
  check_number(n_recordings_per_site, "n_recordings_per_site", lower = 1,
               integer = TRUE, null_ok = TRUE)
  check_prob(min_confidence, "min_confidence", null_ok = TRUE)
  check_number(hour_start, "hour_start", 0, 23, integer = TRUE,
               null_ok = TRUE)
  check_number(hour_end, "hour_end", 0, 23, integer = TRUE, null_ok = TRUE)
  check_flag(alternate_days, "alternate_days")
  check_number(target_total, "target_total", lower = 1, integer = TRUE,
               null_ok = TRUE)
  check_flag(balance_by_hour, "balance_by_hour")
  check_number(max_per_species, "max_per_species", lower = 1,
               integer = TRUE, null_ok = TRUE)
  check_number(seed, "seed", integer = TRUE)
  check_flag(inherit, "inherit")
  time_window  <- list(hour_start = hour_start, hour_end = hour_end,
                       alternate_days = alternate_days,
                       date_start = date_start, date_end = date_end)

  detections <- check_detections(
    detections, c("site", "begin_path", "begin_time", "end_time",
                  "file_offset"))

  # Earlier rounds of the same design
  prev_rounds <- NULL
  other_design <- NULL
  round_no <- 1L
  if (!is.null(previous)) {
    earlier <- read_previous(previous)
    modes <- setdiff(unique(earlier$sampling_mode), samp_mode)
    random_modes <- c("random_detections", "random_recordings", "score_bands")
    if (length(modes) > 0 && !all(c(samp_mode, modes) %in% random_modes)) {
      stop("`previous` has clips of ", paste(modes, collapse = ", "),
           ", and this draw is ", samp_mode, ": `previous` takes rounds of ",
           "the same design, or another random design.", call. = FALSE)
    }
    other_design <- filter(earlier, sampling_mode != samp_mode)
    if (nrow(other_design) == 0) other_design <- NULL
    same <- filter(earlier, sampling_mode == samp_mode)
    if (nrow(same) > 0) prev_rounds <- same
  }
  if (!is.null(prev_rounds)) {
    if (samp_mode == "random_recordings") {
      stop("Later rounds are not available for \"random_recordings\".",
           call. = FALSE)
    }
    if (!is.null(target_total) || !is.null(max_per_species)) {
      stop("`target_total` and `max_per_species` cannot be used with ",
           "earlier rounds: the second stage would depend on the counts of ",
           "each round.", call. = FALSE)
    }
    round_no <- max(prev_rounds$round) + 1L
    message("`previous`: earlier rounds of this design, so their occasions ",
            "leave the pool.")
  } else if (!is.null(candidates) || !is.null(cells)) {
    stop("`candidates` and `cells` are for later rounds: give `previous` ",
         "with the earlier rounds of this design.", call. = FALSE)
  }
  if (!is.null(other_design)) {
    message("`previous`: reviews of another design, so the draw stays ",
            "independent", if (inherit) " and their verdicts are reused",
            ".")
  }
  if (!is.null(cells) && samp_mode != "random_detections") {
    stop("`cells` is for \"random_detections\".", call. = FALSE)
  }
  if (samp_mode == "score_bands") {
    if (!is.numeric(score_breaks) || length(score_breaks) < 2 ||
        anyNA(score_breaks) || is.unsorted(score_breaks, strictly = TRUE) ||
        score_breaks[1] < 0 || score_breaks[length(score_breaks)] > 1) {
      stop("`score_breaks` must be at least two increasing numbers ",
           "within 0 and 1.", call. = FALSE)
    }
    if (!is.null(prev_rounds)) {
      stop("Later rounds are not available for \"score_bands\" yet.",
           call. = FALSE)
    }
    if (!is.null(target_total) || !is.null(max_per_species)) {
      stop("`target_total` and `max_per_species` are not available for ",
           "\"score_bands\": `n_top` clips are drawn per stratum and band, ",
           "so that `inclusion_prob` stays exact.", call. = FALSE)
    }
  }

  # Pilot: restrict to the requested sites
  if (!is.null(sites)) {
    unknown <- setdiff(sites, unique(detections$site))
    if (length(unknown) > 0) {
      warning("Site(s) in `sites` without predictions: ",
              paste(unknown, collapse = ", "))
    }
    detections <- filter(detections, site %in% sites)
    message("Pilot: processing only ",
            paste(intersect(sites, unique(detections$site)), collapse = ", "),
            " (", nrow(detections), " predictions).")
    if (nrow(detections) == 0) {
      stop("No prediction left after the site filter - check `sites`.")
    }
  }

  if (samp_mode == "random_detections" && is.null(threshold)) {
    stop("sampling_mode = \"random_detections\" needs `threshold` ",
         "(the same confidence threshold as the occupancy analysis).")
  }
  message("Sampling mode: ", samp_mode, " (occasion = ", occ_unit, ").")

  sel <- detections |>
    mutate(
      source_audio = remap_path(begin_path, remap_from, remap_to),
      duration     = end_time - begin_time,
      clip_start   = file_offset,
      clip_end     = file_offset + duration,
      occasion_id  = make_occasion_id(source_audio, file_offset, occ_unit)
    )
  sel <- bind_cols(sel, parse_date_hour(basename(sel$begin_path)))

  if (anyNA(sel$recording_date)) {
    n_na <- sum(is.na(sel$recording_date))
    warning(n_na, " prediction(s) with a file name without the ",
            "_YYYYMMDD_HHMMSS pattern - grouped with date/hour = NA.")
  }

  # 'night' is the grouping date (changes if the window crosses midnight)
  sel <- mutate(sel,
                hour_int = suppressWarnings(as.integer(recording_hour)),
                night    = recording_date)

  # List of ALL recordings (only in "random_recordings")
  if (samp_mode == "random_recordings") {
    recs <- get_recordings(sel, recordings, audio_pattern,
                           remap_from, remap_to)
    if (!is.null(sites)) {
      recs <- filter(recs, site %in% sites)
      if (nrow(recs) == 0) {
        stop("No recording of `recordings` left after the site filter - ",
             "check `sites`.", call. = FALSE)
      }
    }
  }

  # Species filter (short codes)
  if (!is.null(species)) {
    n_before <- nrow(sel)
    sel <- filter(sel,
                  str_extract(species_code, "[^_]+$") %in% .env$species)
    message("Filter of ", length(species), " species: ", n_before, " -> ",
            nrow(sel), " predictions.")
    absent <- setdiff(species,
                      str_extract(unique(sel$species_code), "[^_]+$"))
    if (length(absent) > 0) {
      warning("Requested species without any prediction: ",
              paste(absent, collapse = ", "))
    }
    if (nrow(sel) == 0) stop("No prediction of the requested species.")
  }

  # Species to annotate in "random_recordings" (before the time filters:
  # a species enters even without a prediction in the window)
  target_species <- sort(unique(sel$species_code))

  sel <- filter_time(sel, time_window, "predictions")

  # Predictions of the species >= threshold per occasion (to check that
  # every detection of a checked occasion was cut)
  n_det_occasion <- if (!is.null(threshold)) {
    sel |>
      filter(confidence >= threshold) |>
      count(site, species_code, occasion_id, name = "n_detections_occasion")
  }

  if (samp_mode == "top") {
    if (!is.null(min_confidence)) {
      n_before <- nrow(sel)
      sel <- filter(sel, confidence >= min_confidence)
      if (nrow(sel) < n_before) {
        message(n_before - nrow(sel), " predictions dropped by the filter ",
                "confidence < ", min_confidence, ".")
      }
    }

    if (!is.null(prev_rounds)) {
      seen <- prev_rounds |>
        transmute(across(all_of(occasion_key)),
                  .start = round(clip_start, 3))
      n_before <- nrow(sel)
      sel <- sel |>
        mutate(.start = round(clip_start, 3),
               site = as.character(site)) |>
        anti_join(seen, by = c(occasion_key, ".start")) |>
        select(-.start)
      message(n_before - nrow(sel), " predictions already in `previous` ",
              "left out.")
    }

    sel <- sel |>
      group_by(site, species_code, night, recording_hour) |>
      arrange(desc(confidence), .by_group = TRUE) |>
      slice_head(n = n_top) |>
      mutate(rank = row_number()) |>
      ungroup() |>
      mutate(
        species_folder = folder_name(species_code),
        clip_file      = clip_name(confidence, rank, source_audio,
                                   clip_start, clip_end),
        # chosen by score: not a probability sample
        inclusion_prob = NA_real_
      )

    message(nrow(sel), " clips selected (top ", n_top,
            " per site x species x night x hour) of ",
            n_distinct(sel$species_code), " species.")
  } else if (samp_mode == "score_bands") {
    # Score bands: n_top predictions drawn per stratum x band, with the
    # inclusion probability of each. Chosen BY score: serves thresholds and
    # calibration, not the false-positive model.
    bands <- cut(sel$confidence, breaks = score_breaks,
                 include.lowest = TRUE, right = FALSE)
    n_outside <- sum(is.na(bands))
    if (n_outside > 0) {
      message(n_outside, " prediction(s) outside `score_breaks` (",
              score_breaks[1], " to ", score_breaks[length(score_breaks)],
              ") are not drawn.")
    }
    cands <- mutate(sel, score_band = bands) |>
      filter(!is.na(score_band)) |>
      add_period_columns(strata_cols) |>
      join_covariates(covariates, strata_cols)
    check_strata_columns(cands, strata_cols)
    if (nrow(cands) == 0) {
      stop("No prediction within `score_breaks`.", call. = FALSE)
    }
    sel <- withr::with_seed(seed, {
      cands |>
        group_by(across(all_of(c(strata_cols, "score_band")))) |>
        mutate(n_candidates = n(),
               n_drawn = min(n_top, n()),
               inclusion_prob = n_drawn / n_candidates) |>
        slice_sample(n = n_top) |>
        ungroup()
    })
    sel <- sel |>
      mutate(rank = 1L,
             species_folder = folder_name(species_code),
             clip_file = clip_name(confidence, rank, source_audio,
                                   clip_start, clip_end))
    message(nrow(sel), " clips drawn (", n_top, " per ", strata_label,
            " x score band) among ", nrow(cands), " predictions in ",
            length(score_breaks) - 1, " score band(s). These clips serve ",
            "thresholds and calibration, not false-positive occupancy ",
            "models: they were chosen by their score.")
  } else if (samp_mode == "random_detections") {
    # Candidates: occasions with >= 1 prediction of the species >=
    # threshold. The draw (n_top occasions per stratum) ignores the score.
    dets <- filter(sel, confidence >= threshold) |>
      add_period_columns(strata_cols) |>
      join_covariates(covariates, strata_cols)
    check_strata_columns(dets, strata_cols)
    key_cols <- unique(c("site", "species_code", "occasion_id",
                         "recording_date", "night", "recording_hour",
                         strata_cols))
    occasions <- distinct(dets, across(all_of(key_cols)))
    if (anyDuplicated(occasions[c("site", "species_code", "occasion_id")])) {
      stop("The `strata` columns must be constant within an occasion; ",
           "some occasions fall in more than one stratum.", call. = FALSE)
    }
    is_capped <- !is.null(target_total) || !is.null(max_per_species)
    current <- build_candidates(occasions, strata_cols, threshold, occ_unit,
                                strata_label, is_capped)
    if (is.null(prev_rounds)) {
      cand_list <- current
      sel <- withr::with_seed(seed, {
        occasions |>
          group_by(across(all_of(strata_cols))) |>
          mutate(.p1 = min(n_top, n()) / n(),
                 n_candidates = n(),
                 n_drawn = min(n_top, n())) |>
          slice_sample(n = n_top) |>
          ungroup() |>
          mutate(.pr = .p1)
      })
      message(nrow(sel), " occasions drawn (", n_top,
              " per ", strata_label, ") among ",
              n_distinct(dets[c("site", "species_code", "occasion_id")]),
              " with a prediction >= ", threshold, ".")
    } else {
      cand_list <- read_candidates(candidates,
                                   if (is.character(previous)) previous)
      if (is.null(cand_list)) {
        warning("No candidates.csv found: the candidates are rebuilt from ",
                "the predictions, assuming that they did not change since ",
                "the first round.", call. = FALSE)
        cand_list <- current
      }
      check_round_design(cand_list, threshold, occ_unit, strata_label)
      warn_changed_pool(current, cand_list)
      check_round_probs(prev_rounds, cand_list)
      sel <- draw_round(cand_list, prev_rounds, n_top, seed, round_no, cells)
      n_lost <- nrow(anti_join(sel, current, by = occasion_key))
      if (n_lost > 0) {
        warning(n_lost, " occasion(s) drawn have no prediction now, so ",
                "they give no clip.", call. = FALSE)
      }
    }
    drawn_occasions <- sel
  } else {
    # Draw among ALL recordings (or minutes), with or without predictions,
    # in proportion to the effort of each site
    recs <- filter_time(recs, time_window, "recordings")
    if (occ_unit == "minute") {
      recs <- recs |>
        mutate(.dur = audio_duration(source_audio, recording_duration))
      if (anyNA(recs$.dur)) {
        warning(sum(is.na(recs$.dur)), " recording(s) without a ",
                "readable duration - skipped. Set `recording_duration`?")
      }
      recs <- recs |>
        filter(!is.na(.dur)) |>
        mutate(clip_start = map(.dur, \(d) (seq_len(ceiling(d / 60)) - 1) * 60)) |>
        unnest(clip_start) |>
        mutate(clip_end = pmin(clip_start + 60, .dur)) |>
        select(-.dur)
    } else {
      recs <- recs |>
        mutate(clip_start = 0,
               clip_end   = if (is.null(recording_duration)) NA_real_
                            else recording_duration)
    }
    recs <- mutate(recs,
                   occasion_id = make_occasion_id(source_audio,
                                                  clip_start, occ_unit))

    drawn <- withr::with_seed(seed, {
      recs |>
        group_split(site) |>
        map(function(g) {
          n_target <- if (!is.null(n_recordings_per_site)) {
            min(n_recordings_per_site, nrow(g))
          } else {
            max(1, round(recording_fraction * nrow(g)))
          }
          slice_sample(g, n = n_target) |>
            mutate(inclusion_prob = n_target / nrow(g))
        }) |>
        list_rbind()
    })
    message(nrow(drawn), " ", occ_unit, "(s) drawn among ",
            nrow(recs), " recorded, to annotate ",
            length(target_species), " species.")

    # One copy of the recording/minute per species to annotate (the verdict
    # is per species, in the species folder)
    sel <- drawn |>
      cross_join(tibble(species_code = target_species)) |>
      mutate(
        begin_path     = source_audio,
        confidence     = NA_real_,
        rank           = NA_integer_,
        duration       = clip_end - clip_start,
        species_folder = folder_name(species_code),
        clip_file      = paste0("rec_", site, "_", species_folder, "_",
                                occasion_id, ".wav")
      )
  }

  # Total target balanced by species (and, optionally, by hour), or a
  # fixed limit per species -- reproducible draws. In "random_detections"
  # the drawn units are occasions.
  unit_word <- if (samp_mode == "random_detections") "occasions" else "clips"
  if (samp_mode == "random_recordings" &&
      (!is.null(target_total) || !is.null(max_per_species))) {
    warning("target_total/max_per_species are ignored in ",
            "\"random_recordings\" (recording_fraction or ",
            "n_recordings_per_site apply).")
  } else if (!is.null(target_total)) {
    if (!is.null(max_per_species)) {
      warning("target_total is set - max_per_species is ignored.")
    }
    n_before <- nrow(sel)
    sel <- withr::with_seed(seed, {
      sel |>
        group_split(site) |>
        map(function(site_sel) {
          n_avail <- table(site_sel$species_code)
          alloc <- allocate_target(setNames(as.integer(n_avail),
                                            names(n_avail)),
                                   target_total)
          site_sel |>
            group_split(species_code) |>
            map(\(df) sample_clips(df, alloc[[df$species_code[1]]],
                                   balance_by_hour)) |>
            list_rbind()
        }) |>
        list_rbind()
    })
    message("Target of ", target_total, " ", unit_word, " per site ",
            "(balanced by species", if (balance_by_hour) " and hour", "): ",
            n_before, " -> ", nrow(sel), " ", unit_word, ".")
  } else if (!is.null(max_per_species)) {
    n_before <- nrow(sel)
    sel <- withr::with_seed(seed, {
      sel |>
        group_split(site, species_code) |>
        map(\(df) sample_clips(df, max_per_species, balance_by_hour)) |>
        list_rbind()
    })
    message("Limit of ", max_per_species, " ", unit_word, " per species ",
            "(per site): ", n_before, " -> ", nrow(sel), " ", unit_word, ".")
  }

  if (samp_mode == "random_detections") {
    # Inclusion probability = draw in the stratum (.p1) x draw of the
    # target/limit. The allocation of the target is deterministic given the
    # number of candidates, so the 2nd stage is n/N in the stratum (site x
    # species, x hour if balance_by_hour)
    used_cap <- !is.null(target_total) || !is.null(max_per_species)
    stage2_cols <- c("site", "species_code",
                     if (used_cap && balance_by_hour) "recording_hour")
    # with 1st-stage strata without the hour, the number of candidates per
    # hour in the 2nd stage depends on the 1st draw: the product is no
    # longer exact
    if (used_cap && balance_by_hour && !"recording_hour" %in% strata_cols) {
      warning("With strata (", strata_label, ") without the hour and ",
              "balance_by_hour = TRUE, ",
              "inclusion_prob is conditional on the first draw; use ",
              "balance_by_hour = FALSE for exact inclusion probabilities.",
              call. = FALSE)
    }
    p2 <- if (used_cap) {
      inner_join(count(sel, across(all_of(stage2_cols)), name = ".n"),
                 count(drawn_occasions, across(all_of(stage2_cols)),
                       name = ".N"),
                 by = stage2_cols) |>
        mutate(.p2 = .n / .N) |>
        select(all_of(stage2_cols), .p2)
    } else {
      distinct(sel, across(all_of(stage2_cols))) |> mutate(.p2 = 1)
    }

    # Each drawn occasion becomes ALL its predictions >= threshold
    sel <- sel |>
      left_join(p2, by = stage2_cols) |>
      transmute(site, species_code, occasion_id,
                inclusion_prob = .p1 * .p2,
                inclusion_prob_round = .pr * .p2,
                n_candidates = if (used_cap) NA_integer_ else n_candidates,
                n_drawn = if (used_cap) NA_integer_ else n_drawn) |>
      inner_join(dets, by = c("site", "species_code", "occasion_id"),
                 relationship = "one-to-many") |>
      group_by(site, species_code, occasion_id) |>
      arrange(file_offset, .by_group = TRUE) |>
      mutate(rank = row_number()) |>
      ungroup() |>
      mutate(species_folder = folder_name(species_code),
             clip_file      = clip_name(confidence, rank, source_audio,
                                        clip_start, clip_end))
    message(nrow(sel), " clips (every prediction >= ", threshold,
            " of the ", n_distinct(sel[c("site", "species_code",
                                         "occasion_id")]),
            " occasions drawn).")
    if (nrow(sel) > 0 && is.null(prev_rounds) &&
        all(near(sel$inclusion_prob, 1))) {
      message("Every candidate occasion was taken (inclusion_prob = 1): this ",
              "is a census of them, not a random draw. For a sample, use ",
              "wider `strata` or a smaller `n_top`.")
    }
  }

  sel <- mutate(sel, sampling_mode = samp_mode, round = round_no)
  for (col in c("n_candidates", "n_drawn")) {
    if (!col %in% names(sel)) sel[[col]] <- NA_integer_
  }
  if (!"inclusion_prob_round" %in% names(sel)) {
    sel$inclusion_prob_round <- sel$inclusion_prob
  }
  if (!is.null(n_det_occasion)) {
    sel <- sel |>
      left_join(n_det_occasion,
                by = c("site", "species_code", "occasion_id")) |>
      mutate(n_detections_occasion = replace_na(n_detections_occasion, 0L))
  } else {
    sel$n_detections_occasion <- NA_integer_
  }

  if (is.null(other_design)) {
    sel <- mutate(sel, previously_reviewed = FALSE,
                  inherited_verdict = NA_character_,
                  source_design = NA_character_)
  } else {
    sel <- inherit_verdicts(sel, other_design, samp_mode)
    if (!inherit) sel$inherited_verdict <- NA_character_
    message(sum(sel$previously_reviewed), " clip(s) overlap an earlier ",
            "review; ", sum(!is.na(sel$inherited_verdict)), " inherit its ",
            "verdict and need no review.")
  }
  out <- select(sel, all_of(manifest_columns[manifest_columns != "status"]))
  if (samp_mode == "random_detections") attr(out, "candidates") <- cand_list
  out
}

#' Manifest columns, in the order of the clip_manifest.csv file
#' @noRd
manifest_columns <- c(
  "site", "species_code", "species_folder", "recording_date", "night",
  "recording_hour", "rank", "confidence", "clip_file", "clip_start",
  "clip_end", "duration", "source_audio", "begin_path", "status",
  "sampling_mode", "occasion_id", "n_detections_occasion", "inclusion_prob",
  "round", "n_candidates", "n_drawn", "inclusion_prob_round",
  "previously_reviewed", "inherited_verdict", "source_design"
)

#' List all recordings of each site
#'
#' Uses the given table (data frame or CSV) or list.files() in the audio
#' folders that appear in `begin_path`.
#'
#' @param preds A data frame of predictions with `site` and `source_audio`.
#' @param recordings `NULL`, a data frame, or character scalar path to a CSV
#'   file with `site` and `source_audio` (legacy columns accepted).
#' @param audio_pattern Character scalar, regular expression of audio files.
#' @param remap_from,remap_to `NULL` or character scalars, path prefix and
#'   its replacement.
#' @return A tibble with `site`, `source_audio`, `recording_date`,
#'   `recording_hour`, `hour_int` and `night`.
#' @noRd
get_recordings <- function(preds, recordings, audio_pattern,
                           remap_from, remap_to) {
  if (!is.null(recordings)) {
    if (is.character(recordings)) {
      recordings <- read_csv(recordings, show_col_types = FALSE)
    }
    recs <- from_legacy(recordings) |>
      transmute(site, source_audio = remap_path(source_audio,
                                                remap_from, remap_to))
  } else {
    recs <- preds |>
      distinct(site, folder = dirname(source_audio)) |>
      mutate(source_audio = map(folder, \(d) list.files(
        d, pattern = audio_pattern, full.names = TRUE, ignore.case = TRUE))) |>
      unnest(source_audio) |>
      distinct(site, source_audio)
  }
  if (nrow(recs) == 0) {
    stop("No recording found - check remap_from/remap_to or `recordings`.")
  }
  recs <- bind_cols(recs, parse_date_hour(basename(recs$source_audio))) |>
    mutate(hour_int = suppressWarnings(as.integer(recording_hour)),
           night    = recording_date)
  message(nrow(recs), " recordings found at ",
          n_distinct(recs$site), " site(s).")
  recs
}

#' Apply the time filters
#'
#' Hour window, alternate days and date window, on a table with `site`,
#' `recording_date`, `hour_int` and `night`.
#'
#' @param df A data frame with `site`, `recording_date`, `hour_int` and
#'   `night`.
#' @param time_window A list with `hour_start`, `hour_end`,
#'   `alternate_days`, `date_start` and `date_end` (each may be `NULL`).
#' @param what Character scalar, name of the rows in messages (e.g.
#'   `"predictions"`).
#' @return The filtered `df`, with `night` shifted when the hour window
#'   crosses midnight.
#' @noRd
filter_time <- function(df, time_window, what) {
  h_from <- time_window$hour_start
  h_to <- time_window$hour_end
  # Hour window; crossing midnight, group by NIGHT
  if (!is.null(h_from) && !is.null(h_to)) {
    n_before <- nrow(df)
    if (h_from <= h_to) {
      df <- filter(df, hour_int >= h_from, hour_int <= h_to)
    } else {
      df <- df |>
        filter(hour_int >= h_from | hour_int <= h_to) |>
        mutate(night = if_else(
          hour_int <= h_to,
          format(as.Date(recording_date, "%Y%m%d") - 1, "%Y%m%d"),
          recording_date))
      message("The hour window crosses midnight: grouping by night ",
              "(small hours count as the night before).")
    }
    message("Hour window ", h_from, "h-", h_to, "h: ", n_before, " -> ",
            nrow(df), " ", what, ".")
    if (nrow(df) == 0) stop("No ", what, " within the hour window.")
  }

  # Alternate days (per site, on the grouping date/night)
  if (isTRUE(time_window$alternate_days)) {
    n_before <- nrow(df)
    df <- df |>
      group_by(site) |>
      mutate(.day = as.integer(
        as.Date(night, "%Y%m%d") -
          min(as.Date(night, "%Y%m%d"), na.rm = TRUE))) |>
      ungroup() |>
      filter(.day %% 2 == 0) |>
      select(-.day)
    message("Alternate days: ", n_before, " -> ", nrow(df), " ", what, ".")
  }

  # Date window (e.g. the period of the data logger)
  if (!is.null(time_window$date_start) || !is.null(time_window$date_end)) {
    n_before <- nrow(df)
    d_from <- if (is.null(time_window$date_start)) "00000000" else
      as.character(time_window$date_start)
    d_to <- if (is.null(time_window$date_end)) "99999999" else
      as.character(time_window$date_end)
    df <- filter(df, !is.na(recording_date),
                 recording_date >= d_from, recording_date <= d_to)
    message("Date window ", d_from, "-", d_to, ": ", n_before, " -> ",
            nrow(df), " ", what, ".")
    if (nrow(df) == 0) stop("No ", what, " within the date window.")
  }
  df
}

#' Occasion identifier
#'
#' The file name (without extension), or file + minute.
#'
#' @param audio_path Character vector of audio paths.
#' @param start Numeric vector, start of the clip in the file (s).
#' @param occ_unit Character scalar, `"file"` or `"minute"`.
#' @return Character vector of the same length as `audio_path`.
#' @noRd
make_occasion_id <- function(audio_path, start, occ_unit) {
  base <- tools::file_path_sans_ext(basename(audio_path))
  if (occ_unit == "minute") {
    sprintf("%s_m%03d", base, as.integer(start %/% 60))
  } else {
    base
  }
}

#' Build the clip file name
#'
#' `<conf, 3 decimals>_<rank>_<source file stem>_<start>s_<end>s.wav`.
#'
#' @param confidence Numeric vector of confidence scores.
#' @param rank Integer vector of ranks.
#' @param audio_path Character vector of source audio paths.
#' @param start,end Numeric vectors, start and end of the clip (s).
#' @return Character vector of clip file names.
#' @noRd
clip_name <- function(confidence, rank, audio_path, start, end) {
  base <- tools::file_path_sans_ext(basename(audio_path))
  sprintf("%.3f_%d_%s_%.1fs_%.1fs.wav", confidence, rank, base, start, end)
}

#' Duration of each recording
#'
#' The fixed one, or read from the file with the 'av' package.
#'
#' @param paths Character vector of audio paths.
#' @param fixed_dur `NULL` or numeric scalar, fixed duration (s).
#' @return Numeric vector of durations (s), `NA` when unreadable.
#' @noRd
audio_duration <- function(paths, fixed_dur = NULL) {
  if (!is.null(fixed_dur)) return(rep(fixed_dur, length(paths)))
  require_suggested("av", "to read the duration of the recordings")
  map_dbl(paths, \(f) tryCatch(av::av_media_info(f)$duration,
                               error = function(e) NA_real_))
}

#' Split a total target evenly among species
#'
#' Water filling: species with fewer clips than the quota enter whole and
#' the surplus is shared among those that still have clips left.
#'
#' @param n_avail Named integer vector, clips available per species.
#' @param target Integer scalar, total target.
#' @return Named integer vector, clips allocated per species.
#' @noRd
allocate_target <- function(n_avail, target) {
  alloc <- setNames(integer(length(n_avail)), names(n_avail))
  remaining <- target
  pending <- names(n_avail)
  repeat {
    if (length(pending) == 0 || remaining <= 0) break
    quota <- remaining %/% length(pending)
    if (quota == 0) break
    saturated <- pending[n_avail[pending] <= quota]
    if (length(saturated) == 0) {
      alloc[pending] <- quota
      remaining <- remaining - quota * length(pending)
      break
    }
    alloc[saturated] <- n_avail[saturated]
    remaining <- remaining - sum(n_avail[saturated])
    pending <- setdiff(pending, saturated)
  }
  # hand out the remainder (< 1 per species) one by one
  with_room <- names(which(alloc < n_avail))
  if (remaining > 0 && length(with_room) > 0) {
    extra <- with_room[seq_len(min(remaining, length(with_room)))]
    alloc[extra] <- alloc[extra] + 1L
  }
  alloc
}

#' Draw clips of one species
#'
#' With `by_hour = TRUE`, draws round-robin across the hours of the day
#' (covers the diel cycle).
#'
#' @param df A data frame of clips with `recording_hour`.
#' @param n_target Integer scalar, number of rows to keep.
#' @param by_hour Logical scalar, balance across hours?
#' @return At most `n_target` rows of `df`.
#' @noRd
sample_clips <- function(df, n_target, by_hour = TRUE) {
  if (nrow(df) <= n_target) return(df)
  if (by_hour) {
    df |>
      group_by(recording_hour) |>
      mutate(.order = sample.int(n())) |>
      ungroup() |>
      arrange(.order) |>
      slice_head(n = n_target) |>
      select(-.order)
  } else {
    slice_sample(df, n = n_target)
  }
}

#' Resolve the strata of the draw
#'
#' A preset name or a vector of columns, always with site and species and
#' never with score columns.
#'
#' @param strata Character, a preset name or column names.
#' @param samp_mode `NULL` or character scalar, the sampling mode.
#' @return Character vector of stratum columns.
#' @noRd
resolve_strata <- function(strata, samp_mode = NULL) {
  presets <- list(
    night_hour   = c("night", "recording_hour"),
    night        = "night",
    hour         = "recording_hour",
    week         = "week",
    month        = "month",
    site_species = character())
  if (!is.character(strata) || length(strata) == 0) {
    stop("`strata` must be a preset name or a character vector of columns.",
         call. = FALSE)
  }
  # "species": the species alone, pooling sites; only in score_bands,
  # whose clips do not go to the per-site occupancy model
  if (length(strata) == 1 && identical(strata, "species")) {
    if (!identical(samp_mode, "score_bands")) {
      stop("`strata = \"species\"` is only available for ",
           "sampling_mode = \"score_bands\".", call. = FALSE)
    }
    return("species_code")
  }
  cols <- if (length(strata) == 1 && strata %in% names(presets)) {
    presets[[strata]]
  } else {
    strata
  }
  banned <- intersect(cols, c("confidence", "rank"))
  if (length(banned) > 0) {
    stop("`strata` cannot use column(s) that depend on the score: ",
         paste(banned, collapse = ", "), call. = FALSE)
  }
  unique(c("site", "species_code", cols))
}

#' Join occasion covariates
#'
#' Joins the covariates (e.g. from covariate_bins()) by the identifier
#' columns they share with the predictions.
#'
#' @param df A data frame of predictions.
#' @param covariates `NULL` or a data frame of occasion covariates.
#' @param strata_cols Character vector, the stratum columns (for the
#'   warning about missing values).
#' @return `df` with the covariate columns, in its original row order.
#' @noRd
join_covariates <- function(df, covariates, strata_cols) {
  if (is.null(covariates)) return(df)
  check_data_frame(covariates, "covariates")
  ids <- c("site", "night", "recording_date", "recording_hour",
           "source_audio", "occasion_id")
  key_cols <- intersect(ids, names(covariates))
  if (length(key_cols) == 0) {
    stop("`covariates` must share at least one of the columns ",
         paste(ids, collapse = ", "), " with the predictions.", call. = FALSE)
  }
  new_cols <- setdiff(names(covariates), key_cols)
  clashing <- intersect(new_cols, names(df))
  if (length(clashing) > 0) {
    stop("Column(s) of `covariates` already in `detections`: ",
         paste(clashing, collapse = ", "), call. = FALSE)
  }
  cov <- mutate(covariates, across(all_of(key_cols), as.character))
  if (anyDuplicated(cov[key_cols])) {
    stop("`covariates` must have one row per ",
         paste(key_cols, collapse = " x "), ".", call. = FALSE)
  }
  df <- df |>
    mutate(.order = row_number(),
           across(all_of(key_cols), as.character, .names = ".k_{.col}"))
  names(cov)[match(key_cols, names(cov))] <- paste0(".k_", key_cols)
  df <- left_join(df, cov, by = paste0(".k_", key_cols)) |>
    arrange(.order) |>
    select(-".order", -all_of(paste0(".k_", key_cols)))
  used <- intersect(new_cols, strata_cols)
  if (length(used) > 0) {
    incomplete <- rowSums(is.na(df[used])) > 0
    no_value <- unique(df[incomplete, c("site", "species_code", "occasion_id")])
    if (nrow(no_value) > 0) {
      warning(nrow(no_value), " occasion(s) without a value of ",
              paste(used, collapse = ", "), " in `covariates`; they form ",
              "a stratum of their own.", call. = FALSE)
    }
    message("Strata by ", paste(used, collapse = ", "), ": if the ",
            "covariate may be related to the verdict, include it in the ",
            "calibration or weight the clips by inclusion_prob.")
  }
  df
}

#' Add month and ISO week of the night
#'
#' Adds `month` (YYYY-MM) and `week` (YYYY-Www) when used in the strata and
#' absent from the detections.
#'
#' @param df A data frame with `night` (YYYYMMDD).
#' @param cols Character vector, the stratum columns.
#' @return `df`, possibly with `month` and `week`.
#' @noRd
add_period_columns <- function(df, cols) {
  night_date <- function() as.Date(df$night, "%Y%m%d")
  if ("month" %in% cols && !"month" %in% names(df)) {
    df$month <- format(night_date(), "%Y-%m")
  }
  if ("week" %in% cols && !"week" %in% names(df)) {
    df$week <- format(night_date(), "%G-W%V")
  }
  df
}

#' Check that the stratum columns exist in the predictions
#'
#' @param df A data frame of predictions.
#' @param strata Character vector of stratum columns.
#' @return `df` invisibly; errors when a column is missing.
#' @noRd
check_strata_columns <- function(df, strata) {
  absent <- setdiff(strata, names(df))
  if (length(absent) > 0) {
    stop("Column(s) of `strata` not in `detections`: ",
         paste(absent, collapse = ", "), call. = FALSE)
  }
  invisible(df)
}
