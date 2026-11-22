# Review rounds of one design (#107): a fixed list of candidates, a draw
# among the occasions not drawn yet, and a cumulative inclusion probability

#' Columns that identify an occasion
#' @noRd
occasion_key <- c("site", "species_code", "occasion_id")

#' Stack earlier rounds
#'
#' Without a `round` column, each input counts as one round, in the order
#' given.
#'
#' @param previous Paths to manifests or validation tables, a data frame, or
#'   a list of these.
#' @return A tibble with the stacked rows, an integer `round` and the
#'   temporary column `.input` (index of the input of each row).
#' @noRd
read_previous <- function(previous) {
  inputs <- if (is.data.frame(previous)) list(previous) else as.list(previous)
  tabs <- map(seq_along(inputs), function(i) {
    x <- inputs[[i]]
    if (is.character(x) && !file.exists(x)) {
      stop("Not found: ", x, call. = FALSE)
    }
    tab <- read_manifest(x)
    check_columns(tab, c(occasion_key, "sampling_mode"), "previous")
    if (!"round" %in% names(tab)) tab$round <- i
    tab$.input <- i
    mutate(tab, across(any_of(c("site", "occasion_id", "night",
                                "recording_date", "recording_hour")),
                       as.character),
           round = as.integer(round))
  })
  list_rbind(tabs)
}

#' Build the candidate list of "random_detections"
#'
#' @param occasions A data frame with one row per candidate occasion and the
#'   columns `site`, `species_code`, `occasion_id` and `strata_cols`.
#' @param strata_cols Character vector, the stratum columns.
#' @param threshold Numeric scalar, confidence threshold of the draw.
#' @param occ_unit Character scalar, `"file"` or `"minute"`.
#' @param strata_label Character scalar, label of the strata.
#' @param is_capped Logical scalar, whether `target_total` or
#'   `max_per_species` was used.
#' @return `occasions` with `stratum`, `n_candidates` (N of the stratum) and
#'   the design columns `threshold`, `occasion_unit`, `strata` and `capped`.
#' @noRd
build_candidates <- function(occasions, strata_cols, threshold, occ_unit,
                             strata_label, is_capped) {
  occasions |>
    mutate(across(all_of(occasion_key), as.character),
           stratum = do.call(paste, c(across(all_of(strata_cols)),
                                      sep = " | "))) |>
    add_count(stratum, name = "n_candidates") |>
    mutate(threshold = threshold, occasion_unit = occ_unit,
           strata = strata_label, capped = is_capped)
}

#' Read the candidate list
#'
#' Reads `candidates`, or the candidates.csv next to one of the files in
#' `nearby`.
#'
#' @param candidates `NULL`, a data frame, or character scalar path to a
#'   candidates.csv.
#' @param nearby `NULL`, a data frame, or paths (character vector or list)
#'   whose folders are searched when `candidates` is `NULL`.
#' @return A tibble with the candidates, or `NULL` when none is found.
#' @noRd
read_candidates <- function(candidates, nearby = NULL) {
  if (is.null(candidates)) {
    paths <- if (is.data.frame(nearby)) character() else
      as.character(unlist(Filter(is.character, as.list(nearby))))
    found <- file.path(unique(dirname(paths)), "candidates.csv")
    found <- found[file.exists(found)]
    if (length(found) == 0) return(NULL)
    candidates <- found[1]
  }
  if (is.character(candidates)) {
    if (!file.exists(candidates)) {
      stop("Not found: ", candidates, call. = FALSE)
    }
    candidates <- read_csv(candidates, show_col_types = FALSE,
                           col_types = readr::cols(.default = "c"))
  }
  check_columns(candidates, c(occasion_key, "stratum", "n_candidates"),
                "candidates",
                hint = "Use the candidates.csv of the first round.")
  mutate(candidates, n_candidates = as.integer(n_candidates),
         across(any_of("threshold"), as.numeric),
         across(any_of("capped"), as.logical))
}

#' Refuse what would change the design between rounds
#'
#' @param snap A data frame, the candidate list of the first round.
#' @param threshold Numeric scalar, threshold of this round.
#' @param occ_unit Character scalar, occasion unit of this round.
#' @param strata_label Character scalar, strata label of this round.
#' @return `NULL` invisibly; errors when the design differs.
#' @noRd
check_round_design <- function(snap, threshold, occ_unit, strata_label) {
  expected <- list(threshold = threshold, occasion_unit = occ_unit,
                   strata = strata_label)
  for (field in intersect(names(expected), names(snap))) {
    earlier <- unique(snap[[field]])
    if (length(earlier) != 1 ||
        !isTRUE(all.equal(earlier, expected[[field]]))) {
      stop("`", field, "` differs from the earlier rounds (",
           paste(earlier, collapse = ", "), "): rounds of a design need the ",
           "same threshold, occasion unit and strata.", call. = FALSE)
    }
  }
  if (isTRUE(any(snap$capped))) {
    stop("The first round used `target_total` or `max_per_species`, a second ",
         "stage that later rounds cannot keep exact.", call. = FALSE)
  }
  invisible()
}

#' Check that earlier rounds match the candidate list
#'
#' Each clip keeps the cumulative probability of its round; a mismatch
#' points to another design or a cap.
#'
#' @param prev_rounds A data frame, the clips of the earlier rounds.
#' @param snap A data frame, the candidate list.
#' @return `NULL` invisibly; errors on a mismatch.
#' @noRd
check_round_probs <- function(prev_rounds, snap) {
  if (!"inclusion_prob" %in% names(prev_rounds) ||
      "n_rounds" %in% names(prev_rounds)) {
    return(invisible())
  }
  occ <- prev_rounds |>
    filter(!is.na(inclusion_prob)) |>
    distinct(across(all_of(occasion_key)), round, inclusion_prob) |>
    inner_join(distinct(snap, across(all_of(occasion_key)), stratum,
                        n_candidates), by = occasion_key)
  expected_p <- occ |>
    count(stratum, n_candidates, round, name = ".n") |>
    group_by(stratum) |>
    arrange(round, .by_group = TRUE) |>
    mutate(.expected = cumsum(.n) / n_candidates) |>
    ungroup() |>
    select(stratum, round, .expected)
  bad <- occ |>
    inner_join(expected_p, by = c("stratum", "round")) |>
    filter(abs(inclusion_prob - .expected) > 1e-8)
  if (nrow(bad) > 0) {
    stop(nrow(bad), " earlier occasion(s) have an `inclusion_prob` that does ",
         "not match the candidates: the earlier round used another design, ",
         "a cap (`target_total`, `max_per_species`) or other predictions.",
         call. = FALSE)
  }
  invisible()
}

#' Warn when the current candidates differ from the list
#'
#' The list of the first round prevails.
#'
#' @param current A data frame, candidates built from the current
#'   predictions.
#' @param snap A data frame, the candidate list of the first round.
#' @return `NULL` invisibly.
#' @noRd
warn_changed_pool <- function(current, snap) {
  n_new <- nrow(anti_join(current, snap, by = occasion_key))
  n_gone <- nrow(anti_join(snap, current, by = occasion_key))
  if (n_new + n_gone > 0) {
    warning("The candidate occasions changed since the first round (", n_new,
            " new, ", n_gone, " gone). The candidates of the first round are ",
            "kept, so that the inclusion probabilities stay exact; start a ",
            "new design to use the new predictions.", call. = FALSE)
  }
  invisible()
}

#' Restrict occasions to the requested cells (site x species)
#'
#' @param pool A data frame with `site` and `species_code`.
#' @param cells A data frame with `site` and `species_folder` or
#'   `species_code`.
#' @return The rows of `pool` in `cells`.
#' @noRd
filter_cells <- function(pool, cells) {
  if (!is.data.frame(cells) || !"site" %in% names(cells) ||
      !any(c("species_folder", "species_code") %in% names(cells))) {
    stop("`cells` must be a data frame with `site` and `species_folder` or ",
         "`species_code`, such as rows of review_support().", call. = FALSE)
  }
  target <- mutate(cells, site = as.character(site))
  if (!"species_folder" %in% names(target)) {
    target$species_folder <- folder_name(target$species_code)
  }
  target <- distinct(target, site, species_folder)
  pool |>
    mutate(species_folder = folder_name(species_code)) |>
    semi_join(target, by = c("site", "species_folder")) |>
    select(-species_folder)
}

#' Draw one round
#'
#' Draws `n_top` occasions per stratum among those not drawn yet. The seed
#' changes with the round: with the same seed, the drawn positions would
#' repeat and the round would take the neighbours of earlier occasions.
#'
#' @param snap A data frame, the candidate list.
#' @param prev_rounds A data frame, the clips of the earlier rounds.
#' @param n_top Integer scalar, occasions drawn per stratum.
#' @param seed Integer scalar, seed of the first round.
#' @param round_no Integer scalar, number of this round.
#' @param cells `NULL` or a data frame of cells, see `filter_cells()`.
#' @return A tibble of the drawn occasions with `n_drawn`, `.pr` (draw of
#'   this round) and `.p1` (cumulative probability).
#' @noRd
draw_round <- function(snap, prev_rounds, n_top, seed, round_no, cells) {
  seen <- distinct(prev_rounds, across(all_of(occasion_key)))
  n_outside <- nrow(anti_join(seen, snap, by = occasion_key))
  if (n_outside > 0) {
    stop(n_outside, " earlier occasion(s) are not among the candidates: ",
         "these are not rounds of the same design.", call. = FALSE)
  }
  earlier_n <- snap |>
    semi_join(seen, by = occasion_key) |>
    count(stratum, name = ".n_before")
  pool <- anti_join(snap, seen, by = occasion_key)
  if (!is.null(cells)) {
    if (nrow(filter_cells(snap, cells)) == 0) {
      stop("No candidate occasion in `cells`.", call. = FALSE)
    }
    pool <- filter_cells(pool, cells)
  }
  drawn <- withr::with_seed(seed + round_no - 1L, {
    pool |>
      group_by(stratum) |>
      mutate(.pr = min(n_top, n()) / n()) |>
      slice_sample(n = n_top) |>
      ungroup()
  })
  drawn <- drawn |>
    left_join(earlier_n, by = "stratum") |>
    add_count(stratum, name = ".n_now") |>
    mutate(n_drawn = replace_na(.n_before, 0L) + .n_now,
           .p1 = n_drawn / n_candidates)
  left <- anti_join(pool, drawn, by = occasion_key)
  exhausted <- n_distinct(pool$stratum) - n_distinct(left$stratum)
  message("Round ", round_no, ": ", nrow(drawn), " occasions drawn among ",
          nrow(pool), " not drawn yet; ", exhausted, " of ",
          n_distinct(pool$stratum), " strata have no occasion left.")
  drawn
}

#' Combine the review rounds of a design
#'
#' Stacks the tables of the rounds of a `"random_detections"` design and
#' gives every clip the inclusion probability of the combined sample. Each
#' round of [select_clips()] draws among the occasions not drawn yet, so the
#' occasions drawn in all rounds are a simple random sample of each stratum,
#' and every clip has the probability `n_drawn / n_candidates`, whatever its
#' round. The value stored in the table of an earlier round is out of date
#' as soon as another round is drawn; this function recomputes it from the
#' candidates and the clips, so no earlier file is edited.
#'
#' The probability is exact for a number of rounds fixed in advance. When
#' the rounds of a cell go on until it reaches a target, the decision to
#' stop depends on the verdicts, and the precision tends to be too high;
#' see `vignette("validation-effort")`.
#'
#' @param validation A character vector of paths, a data frame, or a list
#'   of these: the tables of all rounds (paths to the
#'   `validation_by_clip.csv` files or manifests), one row per clip, with
#'   the columns `site`, `species_code`, `occasion_id` and `sampling_mode`.
#'   Tables without `round` count as one round each, in the order given.
#' @param candidates `NULL`, a character scalar (path) or a data frame: the
#'   `candidates.csv` of the first round. `NULL` looks for it in the
#'   folders of `validation`.
#'
#' @section Rounds of other designs:
#' The tables may also hold clips of other designs, such as a
#' `"score_bands"` round drawn after the random rounds to add clips near the
#' threshold (`previous` of the other design in [select_clips()]). Only the
#' `"random_detections"` clips form the cumulative sample: the clips of the
#' other designs are independent draws and keep their own `inclusion_prob`,
#' `n_candidates` and `n_drawn`, and an occasion drawn by both designs is
#' not taken as a repeated round. Weighted by `1 / inclusion_prob`, the
#' pooled table adds the Horvitz-Thompson totals of the draws, so the
#' weighted precision of [suggest_thresholds()], [precision_by_bin()] and
#' [compare_calibration_curves()] is still a ratio estimate. Clips of
#' `"score_bands"` are chosen by their score and are not for occupancy
#' models ([export_occupancy_data()] warns about them). See
#' `vignette("validation-effort")`.
#'
#' @return A tibble (class `tbl_df`): the stacked table, in the order of
#'   the input, with `stratum`,
#'   `n_candidates`, `n_drawn`, the cumulative `inclusion_prob` and
#'   `n_rounds`, the number of rounds with clips of the site x species.
#'   Clips of other sampling modes keep their `inclusion_prob`,
#'   `n_candidates` and `n_drawn`, with `stratum` and `n_rounds` `NA`.
#' @seealso [select_clips()], [read_validation_tables()].
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' det <- read_selection_tables(file.path(ex, "birdnet"))
#' # two rounds of the same "random_detections" design; the second draws
#' # among the occasions not drawn in the first
#' r1 <- select_clips(det, "random_detections", threshold = 0.5,
#'                    strata = "site_species", n_top = 3)
#' cand <- attr(r1, "candidates")
#' r2 <- select_clips(det, "random_detections", threshold = 0.5,
#'                    strata = "site_species", n_top = 3,
#'                    previous = r1, candidates = cand)
#' both <- combine_rounds(list(r1, r2), cand)
#' # every clip now has the probability of the combined sample
#' unique(both[, c("site", "species_folder", "n_candidates", "n_drawn",
#'                 "inclusion_prob")])
#' @export
combine_rounds <- function(validation, candidates = NULL) {
  tab <- read_previous(validation)
  snap <- read_candidates(candidates,
                          if (!is.data.frame(validation)) validation)
  if (is.null(snap)) {
    stop("No candidates.csv found: give `candidates`.", call. = FALSE)
  }
  # Only the "random_detections" rounds form the cumulative sample; clips
  # of other designs (score_bands, random_recordings, top, directed_pps)
  # are independent draws and stay as they are, with their own
  # inclusion_prob, n_candidates and n_drawn. An occasion drawn by both
  # designs is legitimate and does not count as a repeated round
  is_random <- tab$sampling_mode %in% "random_detections"
  rd <- tab[is_random, ]
  others <- tab[!is_random, ]
  repeated <- rd |>
    distinct(across(all_of(occasion_key)), round) |>
    count(across(all_of(occasion_key))) |>
    filter(n > 1)
  if (nrow(repeated) > 0) {
    stop(nrow(repeated), " occasion(s) are in more than one round. Rounds ",
         "drawn without `previous` are not a single sample.", call. = FALSE)
  }
  same_round <- rd |>
    inner_join(distinct(snap, across(all_of(occasion_key)),
                        .stratum = stratum),
               by = occasion_key) |>
    distinct(.stratum, round, .input) |>
    count(.stratum, round) |>
    filter(n > 1)
  if (nrow(same_round) > 0) {
    stop("Two tables have the same round of a stratum: they were drawn ",
         "without `previous`, so they are not a single sample.", call. = FALSE)
  }
  n_outside <- nrow(anti_join(rd, snap, by = occasion_key))
  if (n_outside > 0) {
    stop(n_outside, " clip(s) are from occasions outside `candidates`.",
         call. = FALSE)
  }
  rd <- select(rd, -any_of(c(".input", "stratum", "n_candidates",
                             "n_drawn", "n_rounds"))) |>
    left_join(distinct(snap, across(all_of(occasion_key)), stratum,
                       n_candidates), by = occasion_key)
  n_drawn_tab <- rd |>
    distinct(across(all_of(occasion_key)), stratum) |>
    count(stratum, name = "n_drawn")
  n_rounds_tab <- rd |>
    group_by(site, species_code) |>
    summarise(n_rounds = n_distinct(round), .groups = "drop")
  rd <- rd |>
    left_join(n_drawn_tab, by = "stratum") |>
    left_join(n_rounds_tab, by = c("site", "species_code")) |>
    mutate(inclusion_prob = n_drawn / n_candidates)
  others <- select(others, -any_of(c(".input", "stratum", "n_rounds")))
  others$stratum <- rep(NA_character_, nrow(others))
  others$n_rounds <- rep(NA_integer_, nrow(others))
  # same row order as the input
  ord <- order(c(which(is_random), which(!is_random)))
  bind_rows(rd, others)[ord, , drop = FALSE]
}

#' Warn about a table with several rounds not built by combine_rounds()
#'
#' Such a table has the `inclusion_prob` of each round, not the cumulative
#' one.
#'
#' @param validation A data frame of reviewed clips.
#' @return `NULL` invisibly.
#' @noRd
warn_uncombined <- function(validation) {
  if ("round" %in% names(validation) && !"n_rounds" %in% names(validation) &&
      n_distinct(validation$round, na.rm = TRUE) > 1) {
    warning("The table has several rounds but was not built by ",
            "combine_rounds(): `inclusion_prob` is the one of each round.",
            call. = FALSE)
  }
  invisible()
}

#' The rounds without the last one of each cell
#'
#' Recomputes the cumulative probability of that time, to know whether a
#' cell reached its target only in the last round.
#'
#' @param val A data frame from combine_rounds(), with `site`,
#'   `species_folder`, `species_code`, `occasion_id`, `stratum`, `round` and
#'   `n_candidates`.
#' @return `val` without the last round of each cell, with the
#'   `inclusion_prob` of the earlier rounds.
#' @noRd
before_last_round <- function(val) {
  earlier <- val |>
    group_by(site, species_folder) |>
    filter(round < max(round)) |>
    ungroup()
  n_drawn_tab <- earlier |>
    distinct(site, species_code, occasion_id, stratum) |>
    count(stratum, name = ".n_before")
  earlier |>
    left_join(n_drawn_tab, by = "stratum") |>
    mutate(inclusion_prob = .n_before / n_candidates) |>
    select(-.n_before)
}
