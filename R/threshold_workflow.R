#' Uncertainty of the empirical threshold by bootstrap
#'
#' Resamples whole recordings (or nights) of the reviewed clips of each
#' site x species cell, with replacement, and recomputes the threshold of
#' [suggest_thresholds()] in each replicate. Clips of the same recording are
#' not independent, so resampling clips one by one would make the interval
#' too narrow.
#'
#' The threshold is the lowest score at which the precision of the reviewed
#' clips at or above it reaches `target_precision`, weighted by
#' `1 / inclusion_prob` when the clips have it (the weighted count of a
#' probability sample). The upper quantile of the replicates
#' (`threshold_conservative`) is the conservative threshold: with it, the
#' target is met in about `conf` of the replicates.
#'
#' **Which threshold to apply.** Use `threshold_conservative`, not the point
#' `threshold`, for the detections that are kept (for instance in
#' [threshold_history()] and [warning_signs()]). The point threshold is
#' nearly unbiased, but it falls below the cut that gives the target in a
#' large share of samples, by sampling variation alone, and no warning
#' sign computed from the same sample tells those samples apart. The
#' conservative threshold trades some recall for that guarantee. With few
#' reviewed clips per cell (about 100 or fewer), or a precision that levels
#' off near the target, even the conservative threshold can miss it: review
#' more clips near the threshold. A wide interval means
#' the precision curve is flat near the target, and a new round of review
#' near the threshold narrows it (a new round of [select_clips()], combined
#' with the first by [combine_rounds()]).
#'
#' @inheritParams suggest_thresholds
#' @param sustained `NULL` or logical scalar. If `TRUE`, the target must
#'   also hold at every higher cut with at least `min_n` clips (see
#'   [suggest_thresholds()]). `NULL`, the default, currently means `TRUE`
#'   and warns once per session: in the next minor version the default
#'   becomes `FALSE`, as in [suggest_thresholds()], so that the point
#'   `threshold` matches it. Set `sustained` to keep the current thresholds.
#' @param n_boot Integer scalar >= 1. Number of bootstrap replicates.
#' @param cluster Character scalar, the column of `validation` that defines
#'   the resampling unit:
#'   `"source_audio"` (the recording, the default), `"night"` or any other
#'   column. Resampling is done within each site x species cell (and `by`
#'   group), so the unit must vary within it: `"site"` is not a valid unit
#'   here. A cell with a single unit gets `NA` in `threshold_median`,
#'   `threshold_conservative` and `share_reached`, with a warning, since
#'   resampling it gives no information on the uncertainty. With few units
#'   (say, fewer than 10), the quantiles of the replicates are rough.
#' @param conf Numeric scalar in (0, 1). Probability of the conservative
#'   (upper) quantile.
#' @param seed Integer scalar, seed of the resampling. The global random
#'   number generator is left as it was.
#'
#' @return A tibble (class `tbl_df`) with `site`, `species_folder`, the
#'   `by` columns, `threshold` (from all the clips), `threshold_median`,
#'   `threshold_conservative` (quantile `conf` of the replicates),
#'   `share_reached` (share of replicates in which some score reaches the
#'   target) and `n_clusters`.
#' @seealso [suggest_thresholds()], [threshold_by_group()],
#'   [threshold_record()].
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read_validation_tables(file.path(ex, "validation",
#'                                         "validation_by_clip_ARA.csv"))
#' # Resamples whole recordings; use n_boot = 1000 or more in practice
#' boot <- threshold_bootstrap(val, target_precision = 0.90, min_n = 15,
#'                             sustained = TRUE, n_boot = 100)
#' boot[, c("species_folder", "threshold", "threshold_conservative")]
#' @export
threshold_bootstrap <- function(validation, target_precision = 0.90,
                                min_n = 15, by = NULL, weighted = NULL,
                                sustained = NULL, n_boot = 1000,
                                cluster = "source_audio", conf = 0.95,
                                seed = 2026) {
  check_by(validation, by)
  check_prob(target_precision, "target_precision", open = TRUE)
  check_number(min_n, "min_n", lower = 1, integer = TRUE)
  if (!is.null(sustained)) check_flag(sustained, "sustained")
  check_number(n_boot, "n_boot", lower = 1, integer = TRUE)
  if (!is.character(cluster) || length(cluster) != 1L) {
    stop("`cluster` must be the name of one column.", call. = FALSE)
  }
  check_columns(validation, cluster, "validation", hint = "See `cluster`.")
  if (cluster %in% c("site", "species_folder", by)) {
    stop("`cluster` (", cluster, ") is constant within each cell; ",
         "resample a unit that varies within it, such as \"source_audio\".",
         call. = FALSE)
  }
  check_prob(conf, "conf", open = TRUE)
  check_number(seed, "seed", integer = TRUE)
  reviewed <- reviewed_with_confidence(validation)
  has_weights <- has_inclusion_prob(reviewed)
  check_reviewed(reviewed)
  if (is.null(sustained)) {
    warn_sustained_default()
    sustained <- TRUE
  }
  res <- withr::with_seed(seed, {
    reviewed |>
      group_by(site, species_folder, across(all_of(by))) |>
      group_modify(function(d, key) {
        thr_of <- function(x) {
          threshold_for(x, target_precision, min_n, has_weights, weighted,
                        sustained)$threshold
        }
        unit_rows <- split(seq_len(nrow(d)), d[[cluster]])
        reps <- vapply(seq_len(n_boot), function(b) {
          picked <- sample(length(unit_rows), replace = TRUE)
          thr_of(d[unlist(unit_rows[picked], use.names = FALSE), ])
        }, numeric(1))
        ok <- !is.na(reps)
        solo <- length(unit_rows) < 2
        tibble(
          threshold = thr_of(d),
          threshold_median = if (!solo && any(ok)) stats::median(reps[ok]) else
            NA_real_,
          threshold_conservative = if (!solo && any(ok)) unname(stats::quantile(
            reps[ok], conf, names = FALSE)) else NA_real_,
          share_reached = if (solo) NA_real_ else mean(ok),
          n_clusters = length(unit_rows))
      }) |>
      ungroup()
  })
  single <- res$n_clusters < 2
  if (any(single)) {
    warning(sum(single), " cell(s) with a single `", cluster, "` unit: ",
            "no bootstrap interval for them.", call. = FALSE)
  }
  res
}

#' Does one threshold hold in every group?
#'
#' A threshold set for a whole site x species cell can give the target
#' precision on average and miss it in some months, hours or chorus
#' conditions. For each cell and each level of the `by` columns, this
#' function computes the precision of the reviewed clips at or above the
#' threshold of the cell, weighted by `1 / inclusion_prob` when the clips
#' have it, and flags the groups below `target_precision`.
#'
#' @inheritParams suggest_thresholds
#' @param thresholds A data frame (or tibble) or a numeric scalar. The
#'   threshold of each cell: a table with `site`,
#'   `species_folder` and a `threshold` column (e.g. from
#'   [suggest_thresholds()]; `threshold_column` picks another column, such
#'   as `"threshold_conservative"` of [threshold_bootstrap()]), or a single
#'   number for every cell.
#' @param by Character vector of one or more column names of `validation`
#'   that define the groups, e.g. `"recording_hour"`, a month column, or
#'   both.
#' @param threshold_column Character scalar, the column of `thresholds` with
#'   the threshold.
#'
#' @return A tibble (class `tbl_df`) with `site`, `species_folder`, the
#'   `by` columns, `threshold`, `n_above` (reviewed clips at or above it),
#'   `n_eff` (effective sample size of Kish, with weights), `precision_above`
#'   and `below_target`. A group with fewer than `min_n` clips above the
#'   threshold gets `below_target = NA`.
#' @seealso [threshold_bootstrap()], [threshold_record()].
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read_validation_tables(file.path(ex, "validation",
#'                                         "validation_by_clip_ARA.csv"))
#' thr <- suggest_thresholds(val, target_precision = 0.90, min_n = 15)
#' # Does the threshold of each cell hold in every month?
#' val$month <- substr(val$recording_date, 1, 6)
#' threshold_by_group(val, thr, by = "month", target_precision = 0.90,
#'                    min_n = 5)
#' # One threshold for every cell
#' threshold_by_group(val, 0.5, by = "month", min_n = 5)
#' @export
threshold_by_group <- function(validation, thresholds, by,
                               target_precision = 0.90, min_n = 15,
                               threshold_column = "threshold") {
  check_by(validation, by)
  if (length(by) == 0) {
    stop("Give the group columns in `by`.", call. = FALSE)
  }
  check_prob(target_precision, "target_precision", open = TRUE)
  check_number(min_n, "min_n", lower = 1, integer = TRUE)
  check_string(threshold_column, "threshold_column")
  reviewed <- reviewed_with_confidence(validation)
  has_weights <- has_inclusion_prob(reviewed) && !anyNA(reviewed$inclusion_prob)
  if (is.numeric(thresholds) && length(thresholds) == 1) {
    reviewed$.thr <- thresholds
  } else {
    check_columns(thresholds, c("site", "species_folder", threshold_column),
                  "thresholds", hint = "See `threshold_column`.")
    tab <- distinct(thresholds, site, species_folder,
                    .thr = .data[[threshold_column]])
    reviewed <- inner_join(reviewed, tab,
                            by = c("site", "species_folder"))
  }
  reviewed |>
    filter(!is.na(.thr), confidence >= .thr) |>
    group_by(site, species_folder, across(all_of(by))) |>
    summarise(
      threshold = first(.thr),
      n_above = n(),
      n_eff = if (has_weights) kish_n(inclusion_prob) else n(),
      precision_above = if (has_weights) {
        weighted_precision(verdict, inclusion_prob)
      } else {
        mean(verdict == "positive")
      },
      .groups = "drop") |>
    mutate(below_target = if_else(n_above >= min_n,
                                  precision_above < target_precision,
                                  NA))
}

#' Threshold record
#'
#' Gathers, for each site x species cell, what is needed to reproduce and
#' judge a threshold: how it was set (weighted or not, the target, the
#' number of clips), its uncertainty ([threshold_bootstrap()]), whether it
#' holds in every group ([threshold_by_group()]) and the provenance of the
#' clips (`extraction_info.csv` of [extract_validation_clips()] or of the
#' app). With `file`, it also writes the record as a Markdown table.
#'
#' @param thresholds A data frame (or tibble) returned by
#'   [suggest_thresholds()], with columns `site`, `species_folder` and
#'   `threshold`.
#' @param bootstrap `NULL` or a data frame (or tibble) returned by
#'   [threshold_bootstrap()].
#' @param groups `NULL` or a data frame (or tibble) returned by
#'   [threshold_by_group()].
#' @param extraction_info `NULL`, a character scalar with the path to
#'   `extraction_info.csv`, or the data frame read from it: its `key`,
#'   `value` rows are written at the top of the Markdown file.
#' @param target_precision Numeric scalar, target precision used, recorded
#'   in the table.
#' @param file `NULL` or a character scalar, path of a Markdown file to
#'   write.
#'
#' @return A tibble (class `tbl_df`), one row per cell, with the columns of
#'   `thresholds`,
#'   `target_precision`, the bootstrap columns and, from `groups`,
#'   `n_groups`, `n_groups_below` and `worst_group_precision`; invisibly
#'   when `file` is given.
#' @seealso [suggest_thresholds()], [threshold_bootstrap()],
#'   [threshold_by_group()].
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read_validation_tables(file.path(ex, "validation",
#'                                         "validation_by_clip_ARA.csv"))
#' thr <- suggest_thresholds(val, target_precision = 0.90, min_n = 15,
#'                           sustained = TRUE)
#' boot <- threshold_bootstrap(val, target_precision = 0.90, min_n = 15,
#'                             sustained = TRUE, n_boot = 100)
#' val$month <- substr(val$recording_date, 1, 6)
#' groups <- threshold_by_group(val, boot, by = "month", min_n = 5,
#'                              threshold_column = "threshold_conservative")
#' threshold_record(thr, bootstrap = boot, groups = groups)
#' # Also write the record as a Markdown table
#' md <- file.path(tempdir(), "threshold_record.md")
#' threshold_record(thr, bootstrap = boot, groups = groups, file = md)
#' head(readLines(md))
#' @export
threshold_record <- function(thresholds, bootstrap = NULL, groups = NULL,
                             extraction_info = NULL, target_precision = 0.90,
                             file = NULL) {
  if (!is.null(file)) file <- check_file_ext(file, "md")
  check_columns(thresholds, c("site", "species_folder", "threshold"),
                "thresholds")
  key_cols <- c("site", "species_folder")
  record <- thresholds |>
    group_by(site, species_folder) |>
    slice(1) |>
    ungroup() |>
    mutate(target_precision = target_precision)
  if (!is.null(bootstrap)) {
    b <- bootstrap |>
      group_by(site, species_folder) |>
      slice(1) |>
      ungroup() |>
      select(all_of(key_cols), any_of(c("threshold_median",
                                       "threshold_conservative",
                                       "share_reached", "n_clusters")))
    record <- left_join(record, b, by = key_cols)
  }
  if (!is.null(groups)) {
    g <- groups |>
      group_by(site, species_folder) |>
      summarise(n_groups = n(),
                n_groups_below = sum(below_target, na.rm = TRUE),
                worst_group_precision = min(precision_above),
                .groups = "drop")
    record <- left_join(record, g, by = key_cols)
  }
  if (is.null(file)) return(record)

  info <- if (is.character(extraction_info)) {
    read_csv(extraction_info, show_col_types = FALSE)
  } else {
    extraction_info
  }
  lines <- c("# Threshold record", "",
             paste0("Written by sheepdog ", utils::packageVersion("sheepdog"),
                    " on ", format(Sys.Date()), "."), "")
  if (!is.null(info) && all(c("key", "value") %in% names(info))) {
    lines <- c(lines, "## Provenance of the clips", "",
               "| key | value |", "|---|---|",
               paste0("| ", info$key, " | ", info$value, " |"), "")
  }
  fmt <- function(x) {
    if (is.numeric(x)) format(round(x, 3), trim = TRUE) else as.character(x)
  }
  tab <- as.data.frame(lapply(record, fmt))
  lines <- c(lines, "## Thresholds", "",
             paste0("| ", paste(names(tab), collapse = " | "), " |"),
             paste0("|", paste(rep("---", ncol(tab)), collapse = "|"), "|"),
             apply(tab, 1, \(r) paste0("| ", paste(r, collapse = " | "),
                                       " |")))
  writeLines(lines, file)
  message("Threshold record written to ", file)
  invisible(record)
}

#' Warn once per session that the default of `sustained` will change
#'
#' `threshold_bootstrap()` used `sustained = TRUE` while
#' `suggest_thresholds()` uses `FALSE`; the bootstrap default moves to
#' `FALSE` in the next minor version, announced with this warning first.
#'
#' @return `NULL`, invisibly; called for its warning.
#' @noRd
warn_sustained_default <- function() {
  if (isTRUE(sheepdog_state$warned_sustained)) return(invisible(NULL))
  sheepdog_state$warned_sustained <- TRUE
  warning("The default of `sustained` in threshold_bootstrap() will change ",
          "from TRUE to FALSE in the next minor version, to match ",
          "suggest_thresholds(). Set `sustained = TRUE` to keep the current ",
          "thresholds. This warning is shown once per session.",
          call. = FALSE)
  invisible(NULL)
}
