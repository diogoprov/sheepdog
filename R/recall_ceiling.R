#' Recall ceiling and recall at the threshold
#'
#' Estimates how much of the true activity of a species the classifier can
#' recover. The occasions drawn with `sampling_mode = "random_recordings"`
#' and annotated by ear say where the species called, whatever the
#' classifier said; matched with the highest score of the species in each
#' occasion (from the selection tables), they give:
#'
#' - the **recall ceiling**: the share of the occasions with the species
#'   that have at least one prediction of it with a score of at least
#'   `min_confidence`. The species called in the other occasions, but the
#'   classifier gave it no score worth keeping, so no threshold recovers
#'   them;
#' - the **recall at a threshold** `t`: the share of the occasions with the
#'   species whose highest score is at least `t`. It is the ceiling times
#'   the share of the detected occasions whose highest score reaches `t`
#'   (`share_above`).
#'
#' Both are ratios weighted by `1 / inclusion_prob`, so occasions drawn with
#' different probabilities (a different fraction per site) count for the
#' occasions they stand for. The intervals come from a bootstrap of whole
#' recordings (`cluster`) within each group.
#'
#' **Reading it.** A low ceiling means that the classifier misses the
#' species altogether in many occasions with it: check whether a lower
#' `min_confidence` recovers them without many false positives, and if not,
#' the problem is the classifier, not the threshold. A high ceiling with a
#' low recall at the threshold means that the threshold, not the
#' classifier, loses the occasions; weigh it against the precision the
#' threshold buys ([suggest_thresholds()], [threshold_bootstrap()]).
#'
#' **What is needed.** The occasion of the annotation and of the
#' predictions must be the same: give the `occasion_unit` of the draw, and
#' the `remap_from` / `remap_to` of the draw when the recordings moved.
#' Few occasions with the species give wide intervals: the ceiling of a
#' species seldom present needs many annotated occasions.
#'
#' @param validation A data frame (or tibble) of reviewed clips (e.g. from
#'   [read_validation_tables()]), one row per clip, with the occasions of
#'   `"random_recordings"`: `site`, `species_code`,
#'   `occasion_id`, `sampling_mode`, `verdict` (`"positive"` when the
#'   species was heard in the occasion, `"negative"` when not; other
#'   verdicts are left out), `inclusion_prob` and the `cluster` column.
#'   Clips of other designs are ignored.
#' @param detections A data frame (or tibble) of predictions, as returned by
#'   [read_selection_tables()], with columns `site`, `species_code`,
#'   `confidence`, `begin_path` and `file_offset`.
#' @param thresholds `NULL`, a numeric vector in \[0, 1\], or a data frame.
#'   Thresholds at which the recall is computed: a numeric
#'   vector (the same for every group), or a table with the `by` columns
#'   and a `threshold` column, such as the output of
#'   [suggest_thresholds()] (`threshold_column` picks another column, such
#'   as `"threshold_conservative"` of [threshold_bootstrap()]). `NULL` gives
#'   the ceiling only.
#' @param by Character vector of column names that define the groups:
#'   `"species_folder"` (the default, every site pooled) or
#'   `c("site", "species_folder")`.
#' @param min_confidence Numeric scalar, the lowest score kept in the
#'   selection tables (the minimum confidence BirdNET was run with).
#'   Predictions below it are not counted.
#' @param occasion_unit Character scalar, one of `"file"` or `"minute"`.
#'   The occasion of the draw.
#' @param remap_from,remap_to `NULL` or character scalars. Remapping of the
#'   audio paths of `detections`, as in [select_clips()].
#' @param threshold_column Character scalar, the column of `thresholds` with
#'   the threshold.
#' @param n_boot Integer scalar >= 0. Number of bootstrap replicates; 0
#'   skips the intervals.
#' @param cluster Character scalar, the column of `validation` whose levels
#'   are resampled whole: `"source_audio"` (the recording, the default) or
#'   `"night"`.
#' @param conf Numeric scalar in (0, 1). Probability of the intervals.
#' @param seed Integer scalar, seed of the bootstrap. The global random
#'   number generator is left as it was.
#'
#' @return A tibble with one row per group (and threshold): the `by`
#'   columns, `n_occasions` (annotated occasions), `n_present` (occasions
#'   with the species), `n_missed` (occasions with the species and no
#'   prediction of it), `recall_ceiling` with `ceiling_lower` and
#'   `ceiling_upper`; with `thresholds`, also `threshold`, `share_above`,
#'   `recall` and `recall_lower`, `recall_upper`. Groups with no occasion
#'   with the species get `NA`.
#' @seealso [select_clips()] (`"random_recordings"`), [suggest_thresholds()],
#'   [threshold_bootstrap()], [threshold_record()].
#' @export
#' @examples
#' # six occasions annotated by ear at one site; the species is in four
#' sp <- "Boana raniceps_boa-ran"
#' val <- data.frame(
#'   site = "S1", species_code = sp,
#'   occasion_id = paste0("S1_2024010", 1:6, "_200000"),
#'   source_audio = paste0("/r/S1_2024010", 1:6, "_200000.wav"),
#'   sampling_mode = "random_recordings",
#'   verdict = rep(c("positive", "negative"), c(4, 2)),
#'   inclusion_prob = c(0.5, 0.5, 0.5, 0.25, 0.5, 0.5))
#' det <- data.frame(
#'   site = "S1", species_code = sp,
#'   begin_path = paste0("/r/S1_2024010", c(1, 1, 2, 4, 5), "_200000.wav"),
#'   file_offset = c(0, 3, 6, 0, 9),
#'   confidence = c(0.9, 0.3, 0.4, 0.6, 0.8))
#' recall_ceiling(val, det, thresholds = c(0.5, 0.7, 0.9), n_boot = 0)
recall_ceiling <- function(validation, detections, thresholds = NULL,
                           by = "species_folder", min_confidence = 0.1,
                           occasion_unit = c("file", "minute"),
                           remap_from = NULL, remap_to = NULL,
                           threshold_column = "threshold", n_boot = 1000,
                           cluster = "source_audio", conf = 0.95,
                           seed = 2026) {
  unit <- match.arg(occasion_unit)
  check_prob(conf, "conf", open = TRUE)
  check_columns(validation,
                c("site", "species_code", "occasion_id", "sampling_mode",
                  "verdict"),
                "validation")
  check_columns(detections,
                c("site", "species_code", "confidence", "begin_path",
                  "file_offset"),
                "detections", hint = "Read it with read_selection_tables().")
  occasions <- validation |>
    filter(sampling_mode %in% "random_recordings",
           verdict %in% c("positive", "negative")) |>
    mutate(site = as.character(site),
           species_folder = folder_name(species_code),
           occasion_id = as.character(occasion_id),
           present = verdict == "positive")
  if (nrow(occasions) == 0) {
    stop("No occasion of \"random_recordings\" with a positive or negative ",
         "verdict in `validation`. The recall ceiling needs occasions ",
         "annotated by ear, drawn regardless of the classifier.",
         call. = FALSE)
  }
  check_by(occasions, by)
  if (n_boot > 0) {
    check_columns(occasions, cluster, "validation", hint = "See `cluster`.")
  }
  if (!"inclusion_prob" %in% names(occasions) ||
      anyNA(occasions$inclusion_prob)) {
    message("Some occasions lack `inclusion_prob`: every occasion gets the ",
            "same weight.")
    occasions$w <- 1
  } else {
    occasions$w <- 1 / as.numeric(occasions$inclusion_prob)
  }

  # highest score of each species in each occasion
  max_scores <- detections |>
    filter(confidence >= min_confidence) |>
    mutate(site = as.character(site),
           occasion_id = make_occasion_id(
             remap_path(begin_path, remap_from, remap_to), file_offset,
             unit)) |>
    group_by(site, occasion_id, species_code) |>
    summarise(max_score = max(confidence), .groups = "drop")
  found <- occasions$occasion_id %in% max_scores$occasion_id
  if (!any(found)) {
    warning("No annotated occasion has a prediction of any species. Check ",
            "that `occasion_unit` and `remap_from` / `remap_to` are those ",
            "of the draw.", call. = FALSE)
  }
  occasions <- occasions |>
    left_join(max_scores, by = c("site", "occasion_id", "species_code"))

  thr <- thresholds_by_group(thresholds, occasions, by,
                             threshold_column)
  groups <- split(occasions, occasions[by], drop = TRUE)
  alpha <- (1 - conf) / 2
  rows <- withr::with_seed(seed, lapply(groups, function(d) {
    key <- as_tibble(d[1, by, drop = FALSE])
    t_group <- if (is.null(thr)) numeric() else
      group_thresholds(thr, key, by)
    est <- recall_estimates(d, min_confidence, t_group)
    base <- tibble(n_occasions = nrow(d), n_present = sum(d$present),
                   n_missed = sum(d$present & is.na(d$max_score)),
                   recall_ceiling = est$ceiling,
                   ceiling_lower = NA_real_, ceiling_upper = NA_real_)
    reps <- NULL
    if (n_boot > 0 && sum(d$present) > 0) {
      blocks <- split(seq_len(nrow(d)), d[[cluster]])
      reps <- lapply(seq_len(n_boot), function(b) {
        i <- unlist(blocks[sample(length(blocks), replace = TRUE)],
                    use.names = FALSE)
        recall_estimates(d[i, ], min_confidence, t_group)
      })
      ceilings <- vapply(reps, `[[`, numeric(1), "ceiling")
      base$ceiling_lower <- quantile_or_na(ceilings, alpha)
      base$ceiling_upper <- quantile_or_na(ceilings, 1 - alpha)
    }
    if (length(t_group) == 0) {
      return(bind_cols(key, base))
    }
    by_thr <- tibble(threshold = t_group, share_above = est$share,
                     recall = est$recall)
    if (!is.null(reps)) {
      r <- vapply(reps, `[[`, numeric(length(t_group)), "recall")
      r <- matrix(r, nrow = length(t_group))
      by_thr$recall_lower <- apply(r, 1, quantile_or_na, alpha)
      by_thr$recall_upper <- apply(r, 1, quantile_or_na, 1 - alpha)
    } else {
      by_thr$recall_lower <- NA_real_
      by_thr$recall_upper <- NA_real_
    }
    bind_cols(key[rep(1, nrow(by_thr)), , drop = FALSE],
              base[rep(1, nrow(by_thr)), ], by_thr)
  }))
  bind_rows(rows)
}

#' Recall ceiling, share above each threshold and recall
#'
#' All are ratios weighted by `1 / inclusion_prob` (column `w`).
#'
#' @param d A data frame of annotated occasions of one group, with columns
#'   `present` (logical), `max_score` (numeric, `NA` without prediction)
#'   and `w` (numeric weight).
#' @param min_confidence Numeric scalar, lowest score kept.
#' @param thr Numeric vector of thresholds in \[0, 1\].
#' @return A list with `ceiling` (numeric scalar), `recall` and `share`
#'   (numeric vectors, one value per threshold).
#' @noRd
recall_estimates <- function(d, min_confidence, thr) {
  pres <- d$present
  w_present <- sum(d$w[pres])
  detected <- pres & !is.na(d$max_score) & d$max_score >= min_confidence
  ceil <- if (w_present > 0) sum(d$w[detected]) / w_present else NA_real_
  recall <- vapply(thr, function(t) {
    if (near(w_present, 0)) return(NA_real_)
    sum(d$w[detected & d$max_score >= t]) / w_present
  }, numeric(1))
  share <- vapply(thr, function(t) {
    pd <- sum(d$w[detected])
    if (near(pd, 0)) return(NA_real_)
    sum(d$w[detected & d$max_score >= t]) / pd
  }, numeric(1))
  list(ceiling = ceil, recall = recall, share = share)
}

#' Quantile ignoring missing values, or NA
#'
#' @param x Numeric vector.
#' @param p Numeric scalar in \[0, 1\], probability of the quantile.
#' @return Numeric scalar, the quantile of the non-missing values of `x`;
#'   `NA` if there are none.
#' @noRd
quantile_or_na <- function(x, p) {
  x <- x[!is.na(x)]
  if (length(x) == 0) NA_real_ else
    unname(stats::quantile(x, p, names = FALSE))
}

#' Check and prepare the thresholds of recall_ceiling()
#'
#' @param thresholds `NULL`, a numeric vector in \[0, 1\] for every group,
#'   or a data frame with the `by` columns and the column `column`.
#' @param occasions A data frame of annotated occasions (not used).
#' @param by Character vector, grouping columns.
#' @param column Character scalar, column of `thresholds` with the
#'   threshold.
#' @return `NULL`, a sorted numeric vector of unique thresholds, or a tibble
#'   with the `by` columns (as character) and `threshold`.
#' @noRd
thresholds_by_group <- function(thresholds, occasions, by, column) {
  if (is.null(thresholds)) return(NULL)
  if (is.numeric(thresholds)) {
    if (anyNA(thresholds) || any(thresholds < 0 | thresholds > 1)) {
      stop("`thresholds` must be scores between 0 and 1.", call. = FALSE)
    }
    return(sort(unique(thresholds)))
  }
  if (!is.data.frame(thresholds)) {
    stop("`thresholds` must be a numeric vector or a table.", call. = FALSE)
  }
  check_columns(thresholds, c(by, column), "thresholds")
  out <- thresholds |>
    mutate(across(all_of(by), as.character)) |>
    select(all_of(by), threshold = all_of(column)) |>
    filter(!is.na(threshold)) |>
    distinct()
  dups <- out |> count(across(all_of(by))) |> filter(n > 1)
  if (nrow(dups) > 0) {
    stop("`thresholds` has more than one threshold for some group of `by`; ",
         "use the same `by` as the thresholds (e.g. c(\"site\", ",
         "\"species_folder\")).", call. = FALSE)
  }
  out
}

#' Thresholds of one group
#'
#' @param thr A numeric vector, or a tibble from thresholds_by_group().
#' @param key A one-row data frame with the `by` values of the group.
#' @param by Character vector, grouping columns.
#' @return Numeric vector of the thresholds of the group.
#' @noRd
group_thresholds <- function(thr, key, by) {
  if (is.numeric(thr)) return(thr)
  key <- mutate(key, across(everything(), as.character))
  semi_join(thr, key, by = by)$threshold
}
