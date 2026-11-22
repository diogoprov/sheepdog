#' Directed review round: units drawn with probability proportional to size
#'
#' Draws a review round aimed at the units where a review is worth most,
#' while keeping a known inclusion probability for every clip. A unit is a
#' group of occasions, such as site x month x species. Each unit gets a
#' size, typically the expected gain of one review predicted by an
#' occupancy model; `n_units` units are drawn with probability
#' proportional to size (PPS), one occasion is drawn at random within each
#' drawn unit, and every prediction of that occasion at or above
#' `threshold` becomes a clip, as in `sampling_mode = "random_detections"`
#' of [select_clips()].
#'
#' @param detections A data frame of predictions, one row per BirdNET
#'   prediction, as returned by [read_selection_tables()] (columns `site`,
#'   `confidence`, `begin_path`, `begin_time`, `end_time` and
#'   `file_offset`).
#' @param units A data frame with one row per eligible unit: the columns
#'   that define the unit (any columns of the prepared predictions, such as
#'   `site`, `species_code` and `month`) and the size column. Only listed
#'   units are drawn, so leave out the units that need no review, for
#'   instance those where a review has already confirmed the species.
#' @param n_units Integer scalar >= 1, number of units to draw.
#' @param threshold Numeric scalar, confidence threshold: an occasion is a
#'   candidate when
#'   it has at least one prediction at or above it, and its clips are all
#'   such predictions. Use the threshold of the occupancy analysis.
#' @param size_col Character scalar, column of `units` with the size (a
#'   non-negative numeric column without `NA`).
#' @param floor Numeric scalar >= 0, share of the mean size added to every
#'   size, so that a unit
#'   with size 0 can still be drawn. Without it, a unit the model judges
#'   worthless is never reviewed and the model is never corrected there.
#' @param previous `NULL`, a character vector of paths, a data frame, or a
#'   list of these: manifests of earlier review rounds (of any design).
#'   Their clips are left out, matched by recording
#'   file and start: an occasion is a candidate only while it has a
#'   prediction at or above `threshold` not yet reviewed.
#' @param seed Integer scalar, seed of the draws. The global random number
#'   generator is
#'   left as it was.
#' @inheritParams select_clips
#'
#' @details
#' **Inclusion probabilities.** With sizes \eqn{x_u} (after the floor),
#' the inclusion probability of unit \eqn{u} is
#' \eqn{\pi_u = n x_u / \sum x}, and units whose \eqn{\pi_u} would exceed 1
#' are taken with certainty while the others share the rest of `n_units`.
#' The units are drawn by systematic PPS
#' sampling in a random order, which gives exactly these \eqn{\pi_u}. The
#' occasion is then drawn among the \eqn{N_u} candidate occasions of the
#' unit, so each clip has `inclusion_prob` \eqn{= \pi_u / N_u}. The round is
#' conditional on the earlier rounds: `inclusion_prob` is the probability
#' of this round, given what was reviewed before.
#'
#' **What the weights support.** Weighted by `1 / inclusion_prob`, the clips
#' of the round estimate totals and ratios (such as the precision) of the
#' candidate predictions of the listed units (Horvitz and Thompson 1952,
#' \doi{10.1080/01621459.1952.10483446}). Systematic PPS has no simple
#' joint inclusion probability, so the exact design variance is not
#' available; approximations that treat the draw as with replacement are
#' usually conservative. The units were chosen by a model, so the round is
#' not a sample of all predictions: an occupancy model that reads it needs
#' the inclusion probabilities, which [export_occupancy_data()] writes.
#'
#' A unit without candidate occasions (all reviewed, or no prediction at or
#' above `threshold`) is dropped with a message before the draw.
#'
#' @return The manifest of the round, with the columns of [select_clips()],
#'   `sampling_mode = "directed_pps"`, `n_candidates`
#'   (\eqn{N_u}), `n_drawn = 1` and, at the end, `stratum` (the unit, its
#'   values joined by `|`). The attribute `"units"` holds the units
#'   with their size, `size_used` (after the floor), `n_occasions`,
#'   `inclusion_prob_unit` and `drawn`, for the record of the round; save it
#'   next to the manifest.
#' @seealso [select_clips()], [cut_clips()], [export_occupancy_data()].
#' @export
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' pred <- read_selection_tables(file.path(ex, "birdnet"))
#' # units and their size, for instance the expected gain from a model
#' units <- data.frame(site = c("ARA", "BAI", "NHE", "XAR"),
#'                     species_code = "Boana raniceps_boa-ran",
#'                     month = "2021-11", size = c(1, 2, 3, 4))
#' sel <- select_directed(pred, units, n_units = 2, threshold = 0.5)
#' attr(sel, "units")
#' # then cut_clips(sel, "validation_directed") with the audio at hand
select_directed <- function(detections, units, n_units, threshold,
                            size_col = "size", floor = 0.05,
                            occasion_unit = c("file", "minute"),
                            previous = NULL, seed = 2026,
                            remap_from = NULL, remap_to = NULL) {
  occ_unit <- match.arg(occasion_unit)
  detections <- check_detections(
    detections, c("site", "confidence", "begin_path", "begin_time",
                  "end_time", "file_offset"))
  check_data_frame(units, "units")
  if (!size_col %in% names(units)) {
    stop("`units` lacks the size column `", size_col, "`.", call. = FALSE)
  }
  key_cols <- setdiff(names(units), size_col)
  if (length(key_cols) == 0) {
    stop("`units` needs at least one column besides `", size_col,
         "` to define the unit.", call. = FALSE)
  }
  sizes <- units[[size_col]]
  if (!is.numeric(sizes) || anyNA(sizes) || any(sizes < 0)) {
    stop("`", size_col, "` must be numeric, non-negative and without NA.",
         call. = FALSE)
  }
  if (anyDuplicated(units[key_cols])) {
    stop("`units` has more than one row for some unit.", call. = FALSE)
  }
  if (length(n_units) != 1 || is.na(n_units) || n_units < 1 ||
      n_units != round(n_units)) {
    stop("`n_units` must be a positive whole number.", call. = FALSE)
  }
  if (!is.numeric(threshold) || length(threshold) != 1 || is.na(threshold)) {
    stop("`threshold` must be one number.", call. = FALSE)
  }
  if (!is.numeric(floor) || length(floor) != 1 || is.na(floor) || floor < 0) {
    stop("`floor` must be a non-negative number.", call. = FALSE)
  }

  pred <- detections |>
    mutate(source_audio = remap_path(begin_path, remap_from, remap_to),
           duration     = end_time - begin_time,
           clip_start   = file_offset,
           clip_end     = file_offset + duration,
           occasion_id  = make_occasion_id(source_audio, file_offset, occ_unit))
  pred <- bind_cols(pred, parse_date_hour(basename(pred$begin_path))) |>
    mutate(night = recording_date, site = as.character(site)) |>
    add_period_columns(intersect(c("month", "week"), key_cols))
  absent <- setdiff(key_cols, names(pred))
  if (length(absent) > 0) {
    stop("Column(s) of `units` not in the predictions: ",
         paste(absent, collapse = ", "), call. = FALSE)
  }
  units <- mutate(units, across(all_of(key_cols), as.character))
  pred <- mutate(pred, across(all_of(key_cols), as.character))

  above <- filter(pred, confidence >= threshold)
  n_det_occasion <- count(above, site, species_code, occasion_id,
                          name = "n_detections_occasion")
  round_no <- 1L
  if (!is.null(previous)) {
    earlier <- read_previous(previous)
    directed <- filter(earlier, sampling_mode == "directed_pps")
    if (nrow(directed) > 0) round_no <- max(directed$round) + 1L
    check_columns(earlier, c("source_audio", "clip_start"), "previous")
    # clips are matched by file and start, which depend neither on the
    # occasion unit nor on the path remapping of each round
    seen <- transmute(earlier, site, species_code,
                      .file = audio_stem(source_audio),
                      .start = round(as.numeric(clip_start), 3))
    n_before <- nrow(above)
    above <- above |>
      mutate(.file = audio_stem(source_audio),
             .start = round(clip_start, 3)) |>
      anti_join(seen, by = c("site", "species_code", ".file", ".start")) |>
      select(-.file, -.start)
    message(n_before - nrow(above), " prediction(s) >= ", threshold,
            " already reviewed in `previous` left out.")
  }

  # Candidate occasions of each unit
  occasions <- above |>
    distinct(across(all_of(unique(c(key_cols, occasion_key))))) |>
    semi_join(units, by = key_cols)
  if (anyDuplicated(occasions[occasion_key])) {
    stop("The columns of `units` must be constant within an occasion; ",
         "some occasions fall in more than one unit.", call. = FALSE)
  }
  n_occ <- count(occasions, across(all_of(key_cols)), name = "n_occasions")
  tab <- units |>
    left_join(n_occ, by = key_cols) |>
    mutate(n_occasions = replace_na(n_occasions, 0L))
  empty <- tab$n_occasions == 0
  if (any(empty)) {
    message(sum(empty), " unit(s) without candidate occasions left out.")
  }
  tab$size_used <- tab[[size_col]] + floor * mean(tab[[size_col]])
  tab$inclusion_prob_unit <- 0
  tab$drawn <- FALSE
  eligible <- which(!empty & tab$size_used > 0)
  if (length(eligible) == 0) {
    stop("No unit with candidate occasions and size > 0.", call. = FALSE)
  }
  n <- min(n_units, length(eligible))
  if (n < n_units) {
    message("Only ", n, " unit(s) can be drawn; all of them are taken.")
  }
  pis <- pps_inclusion(tab$size_used[eligible], n)
  tab$inclusion_prob_unit[eligible] <- pis

  draw_res <- withr::with_seed(seed, {
    sel <- eligible[systematic_pps(pis)]
    target <- tab[sel, c(key_cols, "n_occasions", "inclusion_prob_unit")]
    chosen <- occasions |>
      inner_join(target, by = key_cols) |>
      group_by(across(all_of(key_cols))) |>
      slice_sample(n = 1) |>
      ungroup()
    list(sel = sel, chosen = chosen)
  })
  tab$drawn[draw_res$sel] <- TRUE

  stratum_labels <- do.call(paste,
                            c(unname(as.list(draw_res$chosen[key_cols])),
                              sep = "|"))
  chosen <- draw_res$chosen |>
    transmute(across(all_of(occasion_key)),
              inclusion_prob = inclusion_prob_unit / n_occasions,
              stratum = stratum_labels,
              n_candidates = as.integer(n_occasions),
              n_drawn = 1L)
  clips <- above |>
    select(-any_of(c("stratum", "n_candidates", "n_drawn"))) |>
    inner_join(chosen, by = occasion_key) |>
    group_by(across(all_of(occasion_key))) |>
    arrange(file_offset, .by_group = TRUE) |>
    mutate(rank = row_number()) |>
    ungroup() |>
    left_join(n_det_occasion, by = occasion_key) |>
    mutate(species_folder = folder_name(species_code),
           clip_file = clip_name(confidence, rank, source_audio, clip_start,
                                 clip_end),
           sampling_mode = "directed_pps", round = round_no,
           inclusion_prob_round = inclusion_prob,
           previously_reviewed = FALSE, inherited_verdict = NA_character_,
           source_design = NA_character_)
  message(nrow(clips), " clips from ", length(draw_res$sel), " unit(s) ",
          "drawn of ", length(eligible), " (round ", round_no, ").")
  if (all(pis == 1)) {
    message("Every eligible unit was taken (inclusion_prob_unit = 1): this ",
            "is a census of the units.")
  }
  out <- select(clips,
                all_of(manifest_columns[manifest_columns != "status"]),
                stratum)
  attr(out, "units") <- tab |>
    relocate(all_of(key_cols)) |>
    arrange(desc(drawn), desc(inclusion_prob_unit))
  out
}

#' Audio file name without folder or extension
#'
#' Accepts Windows paths.
#'
#' @param path Character vector of file paths.
#' @return Character vector of the same length.
#' @noRd
audio_stem <- function(path) {
  tools::file_path_sans_ext(basename(gsub("\\\\", "/", path)))
}

#' Inclusion probabilities proportional to size for a fixed n
#'
#' Units with `n * x / sum(x) >= 1` are taken with certainty and the rest of
#' `n` is shared among the others, until none exceeds 1.
#'
#' @param x Numeric vector of non-negative sizes.
#' @param n Integer scalar, number of units to draw.
#' @return Numeric vector in \[0, 1\], same length as `x`, summing to `n`.
#' @noRd
pps_inclusion <- function(x, n) {
  p <- numeric(length(x))
  certain <- rep(FALSE, length(x))
  repeat {
    p[!certain] <- (n - sum(certain)) * x[!certain] / sum(x[!certain])
    new_certain <- !certain & p >= 1
    if (!any(new_certain)) break
    certain[new_certain] <- TRUE
    p[new_certain] <- 1
  }
  p
}

#' Systematic PPS sampling in random order
#'
#' A uniform starting point and steps of 1 over the cumulative
#' probabilities; each unit is drawn with its own probability.
#'
#' @param p Numeric vector of inclusion probabilities in \[0, 1\].
#' @return Integer vector, the indices of the drawn units.
#' @noRd
systematic_pps <- function(p) {
  n <- round(sum(p))
  ord <- sample.int(length(p))
  cum_p <- cumsum(p[ord])
  points <- stats::runif(1) + 0:(n - 1)
  pos <- findInterval(points, cum_p, left.open = TRUE) + 1L
  ord[pmin(pos, length(p))]
}
