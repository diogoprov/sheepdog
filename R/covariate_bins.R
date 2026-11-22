#' Bins of an occasion covariate for stratified clip selection
#'
#' Cuts a continuous covariate of the occasions (an environmental gradient,
#' such as the mean temperature of the night, or an acoustic index of the
#' recording or minute) into bins that can stratify the draw of
#' [select_clips()] (`sampling_mode = "random_detections"`, argument
#' `covariates`) and group the checks of stage 1 ([precision_by_bin()],
#' [suggest_thresholds()] and [cell_status()], argument `by`).
#'
#' The bins are computed on `covariates`, which should list every occasion
#' (with or without predictions), so that the same bins serve the draw and
#' every later table: the clip manifest and the validation tables keep
#' their usual columns, and the same table returned here is joined to them
#' by `key` (e.g. `site` and `night`) before the checks of stage 1. By default the breaks are quantiles within each site:
#' acoustic indices depend on the gain and placement of each recorder, and
#' quantiles over all sites would mix the covariate with the site.
#'
#' A covariate used to stratify the draw does not depend on the score, so
#' `inclusion_prob` stays exact. It may, however, be related to the verdict
#' (an acoustic index rises when the species calls; the false-positive rate
#' may change along a gradient). The calibration should then include the
#' bin (e.g. `tp ~ logit_conf + (1 | temp_bin)`) or weight the clips by the
#' inverse of `inclusion_prob`; see `vignette("validation-effort")`.
#'
#' @param covariates A data frame with the `key` columns and `var`, one row
#'   per occasion (or per night, when the covariate is nightly).
#' @param var Character scalar, name of the numeric column to cut.
#' @param key Character vector, columns that identify a row of
#'   `covariates` and are matched
#'   against the occasions in [select_clips()]: any of `site`, `night`,
#'   `recording_date`, `recording_hour`, `source_audio` and `occasion_id`.
#'   `night` and `recording_date` are dates written as `YYYYMMDD`.
#' @param n_bins Integer scalar >= 2, number of bins when `breaks` is
#'   `NULL`.
#' @param breaks `NULL` or numeric vector of length >= 2, strictly
#'   increasing: breaks shared by all groups, instead of quantiles (bins
#'   are left-closed; the last one includes its
#'   upper end).
#' @param within `NULL` or character vector, columns within which quantile
#'   breaks are computed (`NULL`
#'   for quantiles over all rows). Ignored when `breaks` is given.
#' @param name Character scalar, name of the new column. Defaults to
#'   `<var>_bin`.
#'
#' @return The `key` columns (as character) and the bin, an ordered factor
#'   with levels `q1`, `q2`, ... (quantile bins, from low to high values of
#'   `var`) or the intervals of `breaks`. Rows with a missing `var` get a
#'   missing bin.
#' @export
#' @examples
#' nights <- data.frame(
#'   site  = rep(c("A", "B"), each = 6),
#'   night = rep(sprintf("202110%02d", 1:6), 2),
#'   temp  = c(18, 20, 22, 24, 26, 28, 15, 16, 17, 18, 19, 20))
#' covariate_bins(nights, "temp", n_bins = 3)
#' covariate_bins(nights, "temp", breaks = c(15, 20, 25, 30))
covariate_bins <- function(covariates, var, key = c("site", "night"),
                           n_bins = 3, breaks = NULL, within = "site",
                           name = paste0(var, "_bin")) {
  check_data_frame(covariates, "covariates")
  missing <- setdiff(c(key, var, if (is.null(breaks)) within),
                    names(covariates))
  if (length(missing) > 0) {
    stop("Column(s) not in `covariates`: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }
  if (!is.numeric(covariates[[var]])) {
    stop("`", var, "` must be numeric.", call. = FALSE)
  }
  if (anyDuplicated(covariates[key])) {
    stop("`key` (", paste(key, collapse = ", "), ") must identify one row ",
         "of `covariates`.", call. = FALSE)
  }
  tab <- mutate(covariates, across(all_of(key), as.character))

  if (!is.null(breaks)) {
    if (!is.numeric(breaks) || length(breaks) < 2 || is.unsorted(breaks) ||
        anyDuplicated(breaks)) {
      stop("`breaks` must be at least two increasing numbers.", call. = FALSE)
    }
    outside <- !is.na(tab[[var]]) &
      (tab[[var]] < min(breaks) | tab[[var]] > max(breaks))
    if (any(outside)) {
      stop(sum(outside), " value(s) of `", var, "` outside `breaks`.",
           call. = FALSE)
    }
    tab[[name]] <- cut(tab[[var]], breaks = breaks, right = FALSE,
                       include.lowest = TRUE, ordered_result = TRUE)
  } else {
    if (!is.numeric(n_bins) || length(n_bins) != 1 || n_bins < 2) {
      stop("`n_bins` must be a number >= 2.", call. = FALSE)
    }
    labels <- paste0("q", seq_len(n_bins))
    tab <- tab |>
      group_by(across(all_of(within))) |>
      mutate(.bin = quantile_bin(.data[[var]], n_bins, labels,
                                 cur_group())) |>
      ungroup()
    tab[[name]] <- factor(tab$.bin, levels = labels, ordered = TRUE)
  }
  tab[c(key, name)]
}

#' Cut a numeric vector into quantile bins
#'
#' Repeated quantiles (many ties) would leave empty bins, so the error asks
#' for fewer bins.
#'
#' @param x Numeric vector to cut.
#' @param n_bins Integer scalar, number of bins.
#' @param labels Character vector of length `n_bins`, the bin labels.
#' @param group A one-row data frame from `dplyr::cur_group()`, used to name
#'   the group in the error message.
#' @return Character vector of bin labels, same length as `x`.
#' @noRd
quantile_bin <- function(x, n_bins, labels, group) {
  if (all(is.na(x))) return(rep(NA_character_, length(x)))
  cuts <- stats::quantile(x, probs = seq(0, 1, length.out = n_bins + 1),
                            na.rm = TRUE, names = FALSE)
  if (anyDuplicated(cuts)) {
    where <- if (ncol(group) > 0) {
      paste0(" in ", paste(names(group), unlist(group), sep = " = ",
                           collapse = ", "))
    } else ""
    stop("Too many ties to cut the covariate into ", n_bins, " quantile ",
         "bins", where, "; use fewer bins or `breaks`.", call. = FALSE)
  }
  as.character(cut(x, breaks = cuts, labels = labels,
                   include.lowest = TRUE, right = FALSE))
}
