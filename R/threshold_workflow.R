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
#' target is met in about `conf` of the replicates. A wide interval means
#' the precision curve is flat near the target, and a new round of review
#' near the threshold narrows it (a new round of [select_clips()], combined
#' with the first by [combine_rounds()]).
#'
#' @inheritParams suggest_thresholds
#' @param n_boot Number of bootstrap replicates.
#' @param cluster Column of `validation` that defines the resampling unit:
#'   `"source_audio"` (the recording, the default) or `"night"`.
#' @param conf Probability of the conservative (upper) quantile.
#' @param seed Seed of the resampling. The global random number generator
#'   is left as it was.
#'
#' @return A tibble with `site`, `species_folder`, the `by` columns,
#'   `threshold` (from all the clips), `threshold_median`,
#'   `threshold_conservative` (quantile `conf` of the replicates),
#'   `share_reached` (share of replicates in which some score reaches the
#'   target) and `n_clusters`.
#' @seealso [suggest_thresholds()], [threshold_by_group()],
#'   [threshold_record()].
#' @export
threshold_bootstrap <- function(validation, target_precision = 0.90,
                                min_n = 15, by = NULL, weighted = NULL,
                                sustained = TRUE, n_boot = 1000,
                                cluster = "source_audio", conf = 0.95,
                                seed = 2026) {
  check_by(validation, by)
  if (!cluster %in% names(validation)) {
    stop("`cluster` (", cluster, ") is not a column of `validation`.",
         call. = FALSE)
  }
  if (!is.numeric(conf) || length(conf) != 1 || conf <= 0 || conf >= 1) {
    stop("`conf` must be a single number between 0 and 1.", call. = FALSE)
  }
  validados <- reviewed_with_confidence(validation)
  pesos <- has_inclusion_prob(validados)
  if (nrow(validados) == 0) {
    stop("No reviewed clip with a confidence in `validation`.",
         call. = FALSE)
  }
  withr::with_seed(seed, {
    validados |>
      group_by(site, species_folder, across(all_of(by))) |>
      group_modify(function(d, chave) {
        limiar <- function(x) {
          threshold_for(x, target_precision, min_n, pesos, weighted,
                        sustained)$threshold
        }
        grupos <- split(seq_len(nrow(d)), d[[cluster]])
        reps <- vapply(seq_len(n_boot), function(b) {
          escolhidos <- sample(length(grupos), replace = TRUE)
          limiar(d[unlist(grupos[escolhidos], use.names = FALSE), ])
        }, numeric(1))
        ok <- !is.na(reps)
        tibble(
          threshold = limiar(d),
          threshold_median = if (any(ok)) stats::median(reps[ok]) else
            NA_real_,
          threshold_conservative = if (any(ok)) unname(stats::quantile(
            reps[ok], conf, names = FALSE)) else NA_real_,
          share_reached = mean(ok),
          n_clusters = length(grupos))
      }) |>
      ungroup()
  })
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
#' @param thresholds The threshold of each cell: a table with `site`,
#'   `species_folder` and a `threshold` column (e.g. from
#'   [suggest_thresholds()]; `threshold_column` picks another column, such
#'   as `"threshold_conservative"` of [threshold_bootstrap()]), or a single
#'   number for every cell.
#' @param by Columns of `validation` that define the groups, e.g.
#'   `"recording_hour"` or a month column.
#' @param threshold_column Column of `thresholds` with the threshold.
#'
#' @return A tibble with `site`, `species_folder`, the `by` columns,
#'   `threshold`, `n_above` (reviewed clips at or above it), `n_eff`
#'   (effective sample size of Kish, with weights), `precision_above` and
#'   `below_target`. A group with fewer than `min_n` clips above the
#'   threshold gets `below_target = NA`.
#' @seealso [threshold_bootstrap()], [threshold_record()].
#' @export
threshold_by_group <- function(validation, thresholds, by,
                               target_precision = 0.90, min_n = 15,
                               threshold_column = "threshold") {
  check_by(validation, by)
  if (length(by) == 0) {
    stop("Give the group columns in `by`.", call. = FALSE)
  }
  validados <- reviewed_with_confidence(validation)
  pesos <- has_inclusion_prob(validados) && !anyNA(validados$inclusion_prob)
  if (is.numeric(thresholds) && length(thresholds) == 1) {
    validados$.limiar <- thresholds
  } else {
    faltam <- setdiff(c("site", "species_folder", threshold_column),
                      names(thresholds))
    if (length(faltam) > 0) {
      stop("`thresholds` lacks the column(s): ",
           paste(faltam, collapse = ", "), call. = FALSE)
    }
    tab <- distinct(thresholds, site, species_folder,
                    .limiar = .data[[threshold_column]])
    validados <- inner_join(validados, tab,
                            by = c("site", "species_folder"))
  }
  validados |>
    filter(!is.na(.limiar), confidence >= .limiar) |>
    group_by(site, species_folder, across(all_of(by))) |>
    summarise(
      threshold = first(.limiar),
      n_above = n(),
      n_eff = if (pesos) kish_n(inclusion_prob) else n(),
      precision_above = if (pesos) {
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
#' @param thresholds Table from [suggest_thresholds()].
#' @param bootstrap Optional table from [threshold_bootstrap()].
#' @param groups Optional table from [threshold_by_group()].
#' @param extraction_info Optional path to `extraction_info.csv` (or the
#'   table read from it): its `key`, `value` rows are written at the top of
#'   the Markdown file.
#' @param target_precision Target precision used, recorded in the table.
#' @param file Optional path of a Markdown file to write.
#'
#' @return A tibble, one row per cell, with the columns of `thresholds`,
#'   `target_precision`, the bootstrap columns and, from `groups`,
#'   `n_groups`, `n_groups_below` and `worst_group_precision`; invisibly
#'   when `file` is given.
#' @seealso [suggest_thresholds()], [threshold_bootstrap()],
#'   [threshold_by_group()].
#' @export
threshold_record <- function(thresholds, bootstrap = NULL, groups = NULL,
                             extraction_info = NULL, target_precision = 0.90,
                             file = NULL) {
  faltam <- setdiff(c("site", "species_folder", "threshold"),
                    names(thresholds))
  if (length(faltam) > 0) {
    stop("`thresholds` lacks the column(s): ", paste(faltam, collapse = ", "),
         call. = FALSE)
  }
  chave <- c("site", "species_folder")
  ficha <- thresholds |>
    group_by(site, species_folder) |>
    slice(1) |>
    ungroup() |>
    mutate(target_precision = target_precision)
  if (!is.null(bootstrap)) {
    b <- bootstrap |>
      group_by(site, species_folder) |>
      slice(1) |>
      ungroup() |>
      select(all_of(chave), any_of(c("threshold_median",
                                     "threshold_conservative",
                                     "share_reached", "n_clusters")))
    ficha <- left_join(ficha, b, by = chave)
  }
  if (!is.null(groups)) {
    g <- groups |>
      group_by(site, species_folder) |>
      summarise(n_groups = n(),
                n_groups_below = sum(below_target, na.rm = TRUE),
                worst_group_precision = min(precision_above),
                .groups = "drop")
    ficha <- left_join(ficha, g, by = chave)
  }
  if (is.null(file)) return(ficha)

  info <- if (is.character(extraction_info)) {
    read_csv(extraction_info, show_col_types = FALSE)
  } else {
    extraction_info
  }
  linhas <- c("# Threshold record", "",
              paste0("Written by sheepdog ", utils::packageVersion("sheepdog"),
                     " on ", format(Sys.Date()), "."), "")
  if (!is.null(info) && all(c("key", "value") %in% names(info))) {
    linhas <- c(linhas, "## Provenance of the clips", "",
                "| key | value |", "|---|---|",
                paste0("| ", info$key, " | ", info$value, " |"), "")
  }
  fmt <- function(x) {
    if (is.numeric(x)) format(round(x, 3), trim = TRUE) else as.character(x)
  }
  tab <- as.data.frame(lapply(ficha, fmt))
  linhas <- c(linhas, "## Thresholds", "",
              paste0("| ", paste(names(tab), collapse = " | "), " |"),
              paste0("|", paste(rep("---", ncol(tab)), collapse = "|"), "|"),
              apply(tab, 1, \(r) paste0("| ", paste(r, collapse = " | "),
                                        " |")))
  writeLines(linhas, file)
  message("Threshold record written to ", file)
  invisible(ficha)
}
