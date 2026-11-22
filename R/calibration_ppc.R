#' Posterior predictive checks of a Bayesian calibration model
#'
#' Compares the observed share of true positives among the reviewed clips
#' with its posterior predictive distribution, overall and within groups:
#' bins of score (a reliability check), sites, species and any column of
#' the validation data given in `group` (e.g. the month of the recording).
#' A calibration that fits on average can still miss within groups: a
#' detector whose precision drifts with the season, for instance, shows up
#' as months with observed shares outside their predictive intervals, and
#' would bias the detection histories built from the model.
#'
#' For each group, the test statistic is the share of true positives,
#' \eqn{T(y) = \bar y}{T(y) = mean(y)}, and the Bayesian p-value is the mid-p
#' \eqn{\Pr(T(y^{rep}) > T(y)) + \Pr(T(y^{rep}) = T(y)) / 2}{
#'   Pr(T(yrep) > T(y)) + Pr(T(yrep) = T(y)) / 2}, so that ties,
#' frequent in small groups of binary verdicts, count half on each side.
#' Values close to 0 or 1 mean that the model under- or over-predicts the
#' share of true positives in that group (Gelman et al. 2013, *Bayesian
#' Data Analysis*, 3rd ed., ch. 6). The checks reuse the clips the model
#' was fitted to, so they are lenient: a flagged group is a misfit worth
#' modelling (e.g. a group effect in the calibration formula), whereas no
#' flag is not proof of a good fit.
#'
#' @param fit A `brmsfit` returned by [fit_calibration()] with
#'   `engine = "brms"`.
#' @param validations `NULL` or a data frame (or tibble), the calibration data
#'   the model was fitted to, in the same row order, with any columns named in
#'   `group` (keep them with `read_validations(keep = )`). `NULL` uses the data
#'   stored in `fit`, which only hold the columns of the formula.
#' @param group `NULL` or a character vector of columns of `validations` to
#'   check within, besides score bins, sites and species.
#' @param bin_width Numeric scalar in (0, 1), width of the score bins. Bins with
#'   fewer than `min_n` clips are merged with their neighbour.
#' @param min_n Integer scalar >= 1, smallest number of clips in a score bin.
#' @param prob Numeric scalar in (0, 1), probability of the predictive interval.
#' @param flag Numeric scalar in (0, 1). Groups with a p-value below `flag` or
#'   above `1 - flag` are flagged.
#' @param n_draws `NULL` or an integer scalar >= 1, number of posterior draws;
#'   `NULL` uses all.
#' @param seed Integer scalar, seed of the choice of draws and of the predictive
#'   simulation. The global random number generator is left as it was.
#'
#' @return A tibble with one row per check and group: `check` (`"overall"`,
#'   `"score"`, `"site"`, `"species"` or a column of `group`), `group`, `n`
#'   (clips), `observed` (share of true positives), `pred_mean`, `pred_lower`
#'   and `pred_upper` (posterior predictive mean and interval of the
#'   share), `p_value` and `flagged`. Plot it with [plot_calibration_ppc()].
#' @seealso [calibration_diagnostics()] for convergence, which should be
#'   checked first.
#' @export
calibration_ppc <- function(fit, validations = NULL, group = NULL,
                            bin_width = 0.1, min_n = 15, prob = 0.9,
                            flag = 0.05, n_draws = NULL, seed = 2026) {
  check_brmsfit(fit)
  require_suggested("brms", "for the posterior predictive checks")
  check_number(bin_width, "bin_width", 0, 1, open = TRUE)
  check_number(min_n, "min_n", lower = 1, integer = TRUE)
  check_prob(prob, "prob", open = TRUE)
  check_prob(flag, "flag", open = TRUE)
  check_number(n_draws, "n_draws", lower = 1, integer = TRUE, null_ok = TRUE)
  check_number(seed, "seed", integer = TRUE)
  data <- if (is.null(validations)) fit$data else validations
  if (nrow(data) != nrow(fit$data)) {
    stop("`validations` has ", nrow(data), " rows but the model was fitted ",
         "to ", nrow(fit$data), "; pass the data used in fit_calibration().",
         call. = FALSE)
  }
  if (!is.null(group) && !all(group %in% names(data))) {
    stop("Column(s) not in `validations`: ",
         paste(setdiff(group, names(data)), collapse = ", "), call. = FALSE)
  }
  y <- fit$data$tp
  if (!is.null(validations) && "tp" %in% names(validations) &&
      !identical(as.integer(validations$tp), as.integer(y))) {
    stop("The verdicts (`tp`) of `validations` differ from those of the ",
         "fitted data; are the rows in the same order?", call. = FALSE)
  }
  n_total <- brms::ndraws(fit)
  yrep <- withr::with_seed(seed, {
    ids <- if (is.null(n_draws)) NULL
           else sort(sample.int(n_total, min(n_draws, n_total)))
    brms::posterior_predict(fit, draw_ids = ids)
  })
  score <- if ("confidence" %in% names(data)) data$confidence
           else stats::plogis(data$logit_conf)
  groups <- list(overall = rep("all", length(y)),
                 score = score_bins(score, bin_width, min_n))
  for (col in intersect(c("site", "species", group), names(data))) {
    groups[[col]] <- as.character(data[[col]])
  }
  ppc_table(y, yrep, groups, prob, flag)
}

#' Plot posterior predictive checks of a calibration model
#'
#' Draws, for one check of [calibration_ppc()], the observed share of true
#' positives of each group over its posterior predictive mean and interval.
#' Flagged groups are drawn as crosses.
#'
#' @param ppc A data frame (tibble) returned by [calibration_ppc()].
#' @param check Character scalar, the check to draw: `"score"`, `"site"`,
#'   `"species"`, `"overall"` or a column given in `group`.
#'
#' @return A ggplot object.
#' @export
plot_calibration_ppc <- function(ppc, check = "score") {
  require_suggested("ggplot2", "to plot the posterior predictive checks")
  tab <- ppc[ppc$check == check, ]
  if (nrow(tab) == 0) {
    stop("No check \"", check, "\" in `ppc`; available: ",
         paste(unique(ppc$check), collapse = ", "), ".", call. = FALSE)
  }
  tab$group <- factor(tab$group, levels = unique(tab$group))
  ggplot2::ggplot(tab, ggplot2::aes(x = group)) +
    ggplot2::geom_linerange(ggplot2::aes(ymin = pred_lower, ymax = pred_upper),
                            linewidth = 2.5, colour = "grey75") +
    ggplot2::geom_point(ggplot2::aes(y = pred_mean), colour = "grey40",
                        size = 2) +
    ggplot2::geom_point(ggplot2::aes(y = observed, shape = flagged),
                        colour = "#1e5e4e", size = 2.6) +
    ggplot2::scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 4),
                                name = "Flagged") +
    ggplot2::coord_cartesian(ylim = c(0, 1)) +
    ggplot2::labs(x = if (check == "score") "Score bin" else check,
                  y = "Share of true positives",
                  subtitle = "Dot: observed; grey: posterior predictive mean and interval") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
                   legend.position = "bottom")
}

#' Bin scores into intervals of fixed width
#'
#' Bins with fewer than `min_n` clips are merged with their neighbour (the
#' next one, or the previous one for the last bin).
#'
#' @param score Numeric vector in \[0, 1\], confidence scores.
#' @param width Numeric scalar, width of the bins.
#' @param min_n Integer scalar, smallest number of clips in a bin.
#' @return A factor with one element per score, labelled by the range of the
#'   scores in each bin and ordered by score.
#' @noRd
score_bins <- function(score, width = 0.1, min_n = 15) {
  bin <- floor(pmin(score, 1 - 1e-9) / width)
  repeat {
    n <- table(bin)
    if (length(n) == 1 || all(n >= min_n)) break
    target <- as.numeric(names(n)[n < min_n][1])
    neighbours <- as.numeric(names(n))
    dest <- if (target == max(neighbours)) max(neighbours[neighbours < target])
            else min(neighbours[neighbours > target])
    bin[bin == target] <- dest
  }
  label <- tapply(score, bin, function(x) sprintf("%.2f-%.2f", min(x), max(x)))
  ord <- order(as.numeric(names(label)))
  factor(unname(label[as.character(bin)]), levels = unname(label[ord]))
}

#' Table of posterior predictive checks
#'
#' @param y Integer vector of 0/1 verdicts, one per clip.
#' @param yrep Numeric matrix of replicated verdicts, one row per draw and
#'   one column per clip.
#' @param groups Named list of vectors (character or factor), each with one
#'   element per clip; the names are the checks.
#' @param prob Numeric scalar in (0, 1), probability of the predictive
#'   interval.
#' @param flag Numeric scalar in (0, 1); groups with a p-value below `flag`
#'   or above `1 - flag` are flagged.
#' @return A tibble with one row per check x group: `check`, `group`, `n`,
#'   `observed`, `pred_mean`, `pred_lower`, `pred_upper`, `p_value` and
#'   `flagged`.
#' @noRd
ppc_table <- function(y, yrep, groups, prob = 0.9, flag = 0.05) {
  tail_p <- (1 - prob) / 2
  imap(groups, function(g, name) {
    idx <- split(seq_along(y), g, drop = TRUE)
    if (is.factor(g)) idx <- idx[intersect(levels(g), names(idx))]
    imap(idx, function(i, label) {
      t_rep <- rowMeans(yrep[, i, drop = FALSE])
      t_obs <- mean(y[i])
      tibble(check = name, group = label, n = length(i), observed = t_obs,
             pred_mean = mean(t_rep),
             pred_lower = unname(stats::quantile(t_rep, tail_p)),
             pred_upper = unname(stats::quantile(t_rep, 1 - tail_p)),
             p_value = mean(t_rep > t_obs) + mean(t_rep == t_obs) / 2)
    }) |> list_rbind()
  }) |>
    list_rbind() |>
    mutate(flagged = p_value < flag | p_value > 1 - flag)
}
