#' Warning signs of a threshold, by species
#'
#' Gathers, for each species, the warning signs that the detections left
#' after a threshold carry problems an ecological model has to deal with
#' (recall that is low or uneven, false positives that change between
#' sites or seasons or cluster in recordings, a calibration curve of the
#' wrong shape), and sums them up in a verdict. The signs describe the
#' heterogeneity of the data, not whether the threshold reaches its target
#' precision (see "What the verdict says" below). They follow the
#' threshold workflow (Larissa S. M. Sugai, ACAD pilot); this function
#' computes those that a review sample can show:
#'
#' | sign | what it says | from |
#' |---|---|---|
#' | 1 | low recall ceiling: in many occasions with the species, the classifier gave it no score at all | `recall`, the output of [recall_ceiling()] (needs `"random_recordings"` occasions annotated by ear) |
#' | 2 | the threshold discards most true positives | the reviewed clips: share of the positive clips at or above the threshold, weighted by `1 / inclusion_prob` |
#' | 6 | false positives vary by site or season | the reviewed clips: range of the false-positive rate among the levels of each `groups` column; the most frequent identity of the negative clips, when `validation` has `identity` |
#' | 7 | the threshold is not stable across groups | [threshold_by_group()] for each `groups` column |
#' | 8 | the logistic curve is wrong near the threshold | `curves`, the output of [compare_calibration_curves()] |
#' | 9 | false positives cluster in recordings | the reviewed clips at or above the threshold: design effect of the false positives by `cluster` |
#'
#' Signs 3, 4 and 5 (occupied sites lost, detected days that do not track
#' the true activity, false negatives that vary by site) need site-days
#' whose true activity is known, that is recordings annotated in full, and
#' are not computed here. A sign whose input is missing is `NA`, not
#' `FALSE`: it was not checked.
#'
#' **Sign 9.** Among the reviewed clips at or above the threshold of their
#' cell (all cells of the species together, unweighted), the false
#' positives may concentrate in a few recordings, for instance a recording
#' with an insect chorus or a similar species calling all night. The sign
#' gives the design effect of the false-positive indicator by `cluster`,
#' \eqn{1 + (\bar m - 1)\rho}, where \eqn{\rho} is the intraclass
#' correlation (ANOVA estimator, truncated at 0) and \eqn{\bar m =
#' \sum m_i^2 / \sum m_i} the mean cluster size weighted by size. A design
#' effect of 3 means that the precision above the threshold is as uncertain
#' as with a third of the clips: intervals that treat clips as independent
#' are too narrow ([threshold_bootstrap()] resamples whole recordings and
#' does not have this problem), and false positives that cluster in
#' recordings can turn into false occupied sites. It needs several reviewed
#' clips per recording, as in designs that review whole occasions; with one
#' clip per recording it is `NA`. With no false positive (or no true
#' positive) above the threshold, the design effect is 1.
#'
#' **Verdict.** A heuristic summary of the signs, not a test:
#'
#' - `"not_trustworthy"`: the species has no threshold (no score reaches
#'   the target), no calibration curve reaches the target (sign 8), or three
#'   or more signs are raised;
#' - `"use_with_caveats"`: one or two signs are raised;
#' - `"trustworthy_with_care"`: every sign checked is clear. The signs not
#'   checked (`n_checked` < 6) and signs 3 to 5 may still be raised;
#' - `"not_assessed"`: no sign could be checked.
#'
#' **What the verdict says.** The verdict is a diagnosis of the
#' heterogeneity of the data, not of the reliability of the threshold, and
#' it is not a probability that the threshold misses its target. Two
#' reasons:
#'
#' - the signs are checks whose reach grows with the sample: with more
#'   reviewed clips, more groups reach `min_n` and enter signs 6 and 7, and
#'   smaller differences are seen. A large sample therefore tends to raise
#'   more signs even when its threshold is more precise, and a small one can
#'   clear every sign with a threshold that misses the target;
#' - a threshold taken from a review sample misses its target mostly
#'   through sampling variation, which no sign computed from the same
#'   sample tells apart. In resamples of a real data set, samples with every
#'   sign clear missed the target more often than samples judged
#'   `"not_trustworthy"`, and in simulations a clear verdict was reassuring
#'   only in a small share of the samples. Changing the rule of the verdict
#'   (more signs required, intervals for signs 6 and 7) did not reorder it.
#'
#' Read the verdict as a list of what to look at, and of what the
#' ecological model should account for (false positives by site or season,
#' clustered false positives, a low recall ceiling), together with the
#' value of each sign (the `sign1_ceiling`, `sign2_tp_kept`,
#' `sign6_fp_spread`, `sign7_share_below` and `sign9_deff` columns). For
#' the reliability of the threshold, apply the conservative threshold of
#' [threshold_bootstrap()] (`threshold_conservative`), whatever the
#' verdict.
#'
#' **Which clips.** Signs 2 and 6 are rates of the predictions, so they use
#' the clips with an inclusion probability (`"random_detections"`,
#' `"score_bands"`, `"directed_pps"`), weighted by `1 / inclusion_prob`.
#' Without any such clip they use every reviewed clip, unweighted, with a
#' message: clips of `"top"` are not a random sample, and the rates are
#' then only indicative.
#'
#' @param validation A data frame (or tibble) of reviewed clips, as for
#'   [suggest_thresholds()]. One row per clip.
#' @param thresholds A numeric scalar or a data frame (or tibble). The
#'   threshold of each species or cell: a single
#'   number, or a table with `species_folder` (and optionally `site`) and a
#'   `threshold` column, such as the output of [suggest_thresholds()]
#'   (`threshold_column` picks another column, such as
#'   `"threshold_conservative"` of [threshold_bootstrap()], the threshold
#'   to apply).
#' @param groups `NULL` or a character vector of column names of
#'   `validation` for signs 6 and 7, such as `"site"` or a month column.
#'   `NULL` uses `"site"` when there is more than one site.
#' @param curves `NULL` or a data frame (or tibble) returned by
#'   [compare_calibration_curves()] (sign 8). With curves fitted by site,
#'   the worst verdict of the species counts.
#' @param recall `NULL` or a data frame (or tibble) returned by
#'   [recall_ceiling()] (sign 1). With a ceiling per site, the lowest
#'   counts.
#' @param target_precision Numeric scalar in (0, 1). Target precision of the
#'   threshold (sign 7).
#' @param min_n Numeric scalar. Minimum number of clips of a group for it to
#'   count in signs 6 and 7.
#' @param min_tp_kept Numeric scalar in \[0, 1\]. Sign 2 is raised when the
#'   share of the true positives kept by the threshold is below this.
#' @param max_fp_spread Numeric scalar in \[0, 1\]. Sign 6 is raised when the
#'   false-positive rate of two levels of a group differs by more than
#'   this.
#' @param min_ceiling Numeric scalar in \[0, 1\]. Sign 1 is raised when the
#'   recall ceiling is below this.
#' @param threshold_column Character scalar, the column of `thresholds` with
#'   the threshold.
#' @param cluster `NULL` or a character scalar, the column of `validation`
#'   with the recording (or other unit) of each clip, for sign 9. A name
#'   that is not a column of `validation` leaves sign 9 `NA`, without an
#'   error.
#' @param max_deff Numeric scalar. Sign 9 is raised when the design effect
#'   of the false positives above the threshold is above this.
#' @param file `NULL` or a character scalar, path of a Markdown file to
#'   write the report to.
#'
#' @return A tibble (class `tbl_df`) with one row per species:
#'   `species_folder`,
#'   `threshold` (the median over its cells), `sign1_ceiling`,
#'   `sign1`, `sign2_tp_kept`, `sign2`, `sign6_fp_spread`, `sign6`,
#'   `sign6_detail`, `sign7_share_below`, `sign7`, `sign7_detail`,
#'   `sign8_verdict`, `sign8`, `sign9_deff`, `sign9`, `n_checked`,
#'   `n_raised` and `verdict`. The
#'   `signN` columns are `TRUE` (raised), `FALSE` (clear) or `NA` (not
#'   checked).
#' @seealso [recall_ceiling()], [compare_calibration_curves()],
#'   [threshold_by_group()], [threshold_record()], [confuser_summary()].
#' @export
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read_validation_tables(list.files(file.path(ex, "validation"),
#'                                          full.names = TRUE))
#' thr <- threshold_bootstrap(val, target_precision = 0.95, n_boot = 30,
#'                            sustained = TRUE)
#' warning_signs(val, thr, groups = "site",
#'               threshold_column = "threshold_conservative",
#'               file = tempfile(fileext = ".md"))
warning_signs <- function(validation, thresholds, groups = NULL,
                          curves = NULL, recall = NULL,
                          target_precision = 0.95, min_n = 15,
                          min_tp_kept = 0.25, max_fp_spread = 0.3,
                          min_ceiling = 0.5, threshold_column = "threshold",
                          cluster = "source_audio", max_deff = 2,
                          file = NULL) {
  if (!is.null(file)) file <- check_file_ext(file, "md")
  check_string(cluster, "cluster", null_ok = TRUE)
  reviewed <- reviewed_with_confidence(validation)
  check_reviewed(reviewed)
  reviewed <- mutate(reviewed, site = as.character(site))
  if (is.null(groups) && length(unique(reviewed$site)) > 1) {
    groups <- "site"
  }
  check_by(reviewed, groups)
  cells <- cell_thresholds(thresholds, reviewed, threshold_column)
  species_list <- sort(unique(reviewed$species_folder))

  # probability sample for the rates (signs 2 and 6)
  has_p <- if ("inclusion_prob" %in% names(reviewed)) {
    !is.na(reviewed$inclusion_prob)
  } else {
    rep(FALSE, nrow(reviewed))
  }
  if (any(has_p)) {
    clips <- reviewed[has_p, ]
    clips$w <- 1 / as.numeric(clips$inclusion_prob)
  } else {
    message("No reviewed clip has `inclusion_prob`: signs 2 and 6 use every ",
            "clip, unweighted, and are only indicative.")
    clips <- reviewed
    clips$w <- 1
  }
  clips <- left_join(clips, cells, by = c("site", "species_folder"))

  sign2_tbl <- clips |>
    filter(verdict == "positive") |>
    group_by(species_folder) |>
    summarise(sign2_tp_kept = if (all(is.na(.thr))) NA_real_ else
                sum(w[!is.na(.thr) & confidence >= .thr]) /
                sum(w[!is.na(.thr)]),
              .groups = "drop") |>
    mutate(sign2 = sign2_tp_kept < min_tp_kept)

  sign6_tbl <- fp_spread(clips, groups, min_n, max_fp_spread)
  if ("identity" %in% names(reviewed)) {
    confusers <- reviewed |>
      filter(verdict == "negative", !is.na(identity), identity != "") |>
      count(species_folder, identity, sort = TRUE) |>
      group_by(species_folder) |>
      slice(1) |>
      ungroup() |>
      transmute(species_folder,
                .confuser = paste0("main confuser: ", identity, " (", n,
                                   " clips)"))
    sign6_tbl <- full_join(sign6_tbl, confusers, by = "species_folder") |>
      mutate(sign6_detail = case_when(
        is.na(.confuser) ~ sign6_detail,
        is.na(sign6_detail) ~ .confuser,
        .default = paste0(sign6_detail, "; ", .confuser))) |>
      select(-".confuser")
  }

  sign7_tbl <- group_stability(reviewed, cells, groups, target_precision,
                               min_n)
  sign8_tbl <- curve_signs(curves)
  sign9_tbl <- fp_design_effect(reviewed, cells, cluster, min_n, max_deff)
  sign1_tbl <- ceiling_signs(recall, min_ceiling)

  thr_species <- cells |>
    group_by(species_folder) |>
    summarise(threshold = if (all(is.na(.thr))) NA_real_ else
                stats::median(.thr, na.rm = TRUE), .groups = "drop")
  out <- tibble(species_folder = species_list) |>
    left_join(thr_species, by = "species_folder") |>
    left_join(sign1_tbl, by = "species_folder") |>
    left_join(sign2_tbl, by = "species_folder") |>
    left_join(sign6_tbl, by = "species_folder") |>
    left_join(sign7_tbl, by = "species_folder") |>
    left_join(sign8_tbl, by = "species_folder") |>
    left_join(sign9_tbl, by = "species_folder")
  for (col in c("sign1_ceiling", "sign2_tp_kept", "sign6_fp_spread",
                "sign7_share_below", "sign9_deff")) {
    if (!col %in% names(out)) out[[col]] <- NA_real_
  }
  for (col in c("sign1", "sign2", "sign6", "sign7", "sign8", "sign9")) {
    if (!col %in% names(out)) out[[col]] <- NA
  }
  for (col in c("sign6_detail", "sign7_detail", "sign8_verdict")) {
    if (!col %in% names(out)) out[[col]] <- NA_character_
  }
  signs <- as.matrix(out[c("sign1", "sign2", "sign6", "sign7", "sign8",
                           "sign9")])
  out$n_checked <- rowSums(!is.na(signs))
  out$n_raised <- rowSums(matrix(signs %in% TRUE, nrow = nrow(signs)))
  out$verdict <- case_when(
    out$n_checked == 0 ~ "not_assessed",
    is.na(out$threshold) |
      out$sign8_verdict %in% "no_curve_reaches_target" |
      out$n_raised >= 3 ~ "not_trustworthy",
    out$n_raised >= 1 ~ "use_with_caveats",
    .default = "trustworthy_with_care")
  out <- select(out, species_folder, threshold, sign1_ceiling, sign1,
                sign2_tp_kept, sign2, sign6_fp_spread, sign6, sign6_detail,
                sign7_share_below, sign7, sign7_detail, sign8_verdict,
                sign8, sign9_deff, sign9, n_checked, n_raised, verdict)
  if (!is.null(file)) write_warning_signs(out, file)
  out
}

#' Threshold of each site x species cell
#'
#' A single number applies to every cell; a table by species only applies
#' to every site of the species.
#'
#' @param thresholds Numeric scalar, or a data frame with `species_folder`
#'   (optionally `site`) and the column `column`.
#' @param reviewed A data frame of reviewed clips with `site` and
#'   `species_folder`.
#' @param column Character scalar, column of `thresholds` with the
#'   threshold.
#' @return A tibble with `site`, `species_folder` and `.thr` (numeric, `NA`
#'   for cells without a threshold).
#' @noRd
cell_thresholds <- function(thresholds, reviewed, column) {
  cells <- distinct(reviewed, site, species_folder)
  if (is.numeric(thresholds) && length(thresholds) == 1) {
    return(mutate(cells, .thr = thresholds))
  }
  if (!is.data.frame(thresholds)) {
    stop("`thresholds` must be a single number or a table.", call. = FALSE)
  }
  check_columns(thresholds, c("species_folder", column), "thresholds")
  key_cols <- intersect(c("site", "species_folder"), names(thresholds))
  tab <- thresholds |>
    mutate(across(all_of(key_cols), as.character)) |>
    group_by(across(all_of(key_cols))) |>
    summarise(.thr = first(.data[[column]]), .groups = "drop")
  left_join(cells, tab, by = key_cols)
}

#' Sign 6: spread of the false-positive rate among the levels of each group
#'
#' @param clips A data frame of reviewed clips with `species_folder`,
#'   `verdict`, the weight `w` and the `groups` columns.
#' @param groups Character vector, grouping columns.
#' @param min_n Numeric scalar, minimum number of clips of a level.
#' @param max_spread Numeric scalar, largest spread that keeps the sign
#'   clear.
#' @return A tibble with `species_folder`, `sign6_fp_spread`,
#'   `sign6_detail` and `sign6`; only `species_folder` without groups.
#' @noRd
fp_spread <- function(clips, groups, min_n, max_spread) {
  if (length(groups) == 0) return(tibble(species_folder = character()))
  by_group <- lapply(groups, function(g) {
    clips |>
      filter(!is.na(.data[[g]])) |>
      group_by(species_folder, level = as.character(.data[[g]])) |>
      summarise(n = n(), fp = sum(w[verdict == "negative"]) / sum(w),
                .groups = "drop") |>
      filter(n >= min_n) |>
      group_by(species_folder) |>
      filter(n() >= 2) |>
      summarise(spread = max(fp) - min(fp),
                detail = sprintf("%s: FP rate %.2f (%s) to %.2f (%s)", g,
                                 min(fp), level[which.min(fp)], max(fp),
                                 level[which.max(fp)]),
                .groups = "drop")
  })
  bind_rows(by_group) |>
    group_by(species_folder) |>
    summarise(sign6_fp_spread = max(spread),
              sign6_detail = paste(detail, collapse = "; "),
              .groups = "drop") |>
    mutate(sign6 = sign6_fp_spread > max_spread)
}

#' Sign 7: groups in which the threshold of the cell falls below the target
#'
#' @param reviewed A data frame of reviewed clips.
#' @param cells A tibble from cell_thresholds().
#' @param groups Character vector, grouping columns.
#' @param target_prec Numeric scalar in (0, 1), target precision.
#' @param min_n Numeric scalar, minimum number of clips above the threshold
#'   for a group to count.
#' @return A tibble with `species_folder`, `sign7_share_below`,
#'   `sign7_detail` and `sign7`; only `species_folder` without groups or
#'   thresholds.
#' @noRd
group_stability <- function(reviewed, cells, groups, target_prec, min_n) {
  if (length(groups) == 0) return(tibble(species_folder = character()))
  tab <- filter(cells, !is.na(.thr)) |>
    rename(threshold = .thr)
  if (nrow(tab) == 0) return(tibble(species_folder = character()))
  by_group <- lapply(groups, function(g) {
    if (identical(g, "site")) {
      # the threshold is already by site: the question is whether each
      # site reaches the target
      d <- reviewed |>
        inner_join(tab, by = c("site", "species_folder")) |>
        filter(confidence >= threshold)
      has_weights <- has_inclusion_prob(d) && !anyNA(d$inclusion_prob)
      d |>
        group_by(species_folder, level = site) |>
        summarise(n_above = n(),
                  precision_above = if (has_weights) {
                    weighted_precision(verdict, inclusion_prob)
                  } else {
                    mean(verdict == "positive")
                  }, .groups = "drop") |>
        mutate(below_target = if_else(n_above >= min_n,
                                      precision_above < target_prec, NA),
               group = g)
    } else {
      threshold_by_group(reviewed, tab, by = g, target_precision = target_prec,
                         min_n = min_n) |>
        mutate(level = paste(site, .data[[g]], sep = " / "), group = g)
    }
  })
  bind_rows(lapply(by_group, \(d) select(d, species_folder, group, level,
                                        precision_above, below_target))) |>
    filter(!is.na(below_target)) |>
    group_by(species_folder) |>
    summarise(sign7_share_below = mean(below_target),
              sign7_detail = if (any(below_target)) paste0(
                "below target: ",
                paste(sprintf("%s %s (%.2f)", group[below_target],
                              level[below_target],
                              precision_above[below_target]),
                      collapse = ", ")) else NA_character_,
              .groups = "drop") |>
    mutate(sign7 = sign7_share_below > 0)
}

#' Sign 8: verdict of compare_calibration_curves()
#'
#' The worst verdict of each species counts.
#'
#' @param curves `NULL` or the output of compare_calibration_curves().
#' @return A tibble with `species_folder`, `sign8_verdict` and `sign8`;
#'   only `species_folder` without `curves`.
#' @noRd
curve_signs <- function(curves) {
  if (is.null(curves)) return(tibble(species_folder = character()))
  if (!all(c("species_folder", "verdict") %in% names(curves))) {
    stop("`curves` must be the output of compare_calibration_curves(), ",
         "with species_folder among its `by` columns.", call. = FALSE)
  }
  severity <- c("no_curve_reaches_target", "use_monotone_or_weighted",
             "sample_more_near_threshold", "too_few_clips", "keep_logistic")
  curves |>
    distinct(across(any_of(c("site", "species_folder"))), verdict) |>
    group_by(species_folder) |>
    summarise(sign8_verdict = severity[min(match(verdict, severity))],
              .groups = "drop") |>
    mutate(sign8 = case_when(
      sign8_verdict %in% c("no_curve_reaches_target",
                           "use_monotone_or_weighted") ~ TRUE,
      sign8_verdict == "keep_logistic" ~ FALSE,
      .default = NA))
}

#' Sign 9: design effect of the false positives above the threshold
#'
#' By recording (or other `cluster` unit) within each species.
#'
#' @param reviewed A data frame of reviewed clips.
#' @param cells A tibble from cell_thresholds().
#' @param cluster Character scalar or `NULL`, column with the unit.
#' @param min_n Numeric scalar, minimum number of clips for an estimate.
#' @param max_deff Numeric scalar, largest design effect that keeps the
#'   sign clear.
#' @return A tibble with `species_folder`, `sign9_deff` and `sign9`; only
#'   `species_folder` without the `cluster` column.
#' @noRd
fp_design_effect <- function(reviewed, cells, cluster, min_n, max_deff) {
  if (is.null(cluster) || !cluster %in% names(reviewed)) {
    return(tibble(species_folder = character()))
  }
  reviewed |>
    inner_join(filter(cells, !is.na(.thr)),
               by = c("site", "species_folder")) |>
    filter(confidence >= .thr, !is.na(.data[[cluster]])) |>
    group_by(species_folder) |>
    summarise(sign9_deff = design_effect(verdict == "negative",
                                         paste(site, .data[[cluster]]),
                                         min_n),
              .groups = "drop") |>
    mutate(sign9 = sign9_deff > max_deff)
}

#' Design effect of a binary indicator by cluster
#'
#' ANOVA estimator of the intraclass correlation, truncated at 0, and the
#' mean cluster size weighted by size.
#'
#' @param y Logical or numeric 0/1 vector.
#' @param unit Vector of the same length as `y`, cluster of each value.
#' @param min_n Numeric scalar, minimum length of `y` for an estimate.
#' @return Numeric scalar, the design effect; 1 when `y` is constant, `NA`
#'   with too few values or one value per cluster.
#' @noRd
design_effect <- function(y, unit, min_n) {
  y <- as.numeric(y)
  n <- length(y)
  g <- factor(unit)
  m <- tabulate(g)
  k <- length(m)
  if (n < min_n || k < 2 || n == k) return(NA_real_)
  if (all(y == y[1])) return(1)
  means <- tapply(y, g, mean)
  msb <- sum(m * (means - mean(y))^2) / (k - 1)
  msw <- sum((y - means[as.integer(g)])^2) / (n - k)
  m0 <- (n - sum(m^2) / n) / (k - 1)
  icc <- max(0, (msb - msw) / (msb + (m0 - 1) * msw))
  1 + (sum(m^2) / n - 1) * icc
}

#' Sign 1: recall ceiling from recall_ceiling()
#'
#' The lowest ceiling of each species counts.
#'
#' @param recall `NULL` or the output of recall_ceiling().
#' @param min_ceiling Numeric scalar, lowest ceiling that keeps the sign
#'   clear.
#' @return A tibble with `species_folder`, `sign1_ceiling` and `sign1`;
#'   only `species_folder` without `recall`.
#' @noRd
ceiling_signs <- function(recall, min_ceiling) {
  if (is.null(recall)) return(tibble(species_folder = character()))
  if (!all(c("species_folder", "recall_ceiling") %in% names(recall))) {
    stop("`recall` must be the output of recall_ceiling(), with ",
         "species_folder among its `by` columns.", call. = FALSE)
  }
  recall |>
    group_by(species_folder) |>
    summarise(sign1_ceiling = if (all(is.na(recall_ceiling))) NA_real_ else
                min(recall_ceiling, na.rm = TRUE), .groups = "drop") |>
    mutate(sign1 = sign1_ceiling < min_ceiling)
}

#' Write the warning signs as a Markdown table
#'
#' @param out A tibble from warning_signs().
#' @param file Character scalar, path of the Markdown file.
#' @return `file`, invisibly.
#' @noRd
write_warning_signs <- function(out, file) {
  fmt <- function(x) {
    if (is.numeric(x)) format(round(x, 2), trim = TRUE) else
      ifelse(is.na(x), "", as.character(x))
  }
  tab <- as.data.frame(lapply(out, fmt))
  lines <- c("# Warning signs of the thresholds", "",
             paste0("Written by sheepdog ",
                    utils::packageVersion("sheepdog"), " on ",
                    format(Sys.Date()), ". Signs 3 to 5 need recordings ",
                    "annotated in full and are not checked; an empty sign ",
                    "was not checked. The verdict sums up the ",
                    "heterogeneity of the data, not whether the ",
                    "threshold reaches its target: for that, use the ",
                    "conservative threshold of threshold_bootstrap()."), "",
             paste0("| ", paste(names(tab), collapse = " | "), " |"),
             paste0("|", paste(rep("---", ncol(tab)), collapse = "|"), "|"),
             apply(tab, 1, \(r) paste0("| ", paste(r, collapse = " | "),
                                       " |")))
  writeLines(lines, file)
  message("Warning signs written to ", file)
  invisible(file)
}
