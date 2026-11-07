#' Confidence thresholds from the calibration model
#'
#' Derives a confidence threshold for each site x species from the
#' calibration model of stage 2 ([fit_calibration()]), instead of from the
#' reviewed clips of each cell alone, as [suggest_thresholds()] does. The
#' calibration model is the logistic regression of the verdict on the logit
#' of the score proposed by the BirdNET authors (Wood & Kahl 2024,
#' \doi{10.1007/s10336-024-02144-5}), with species and site effects, so a
#' cell with few reviewed clips borrows strength from the others.
#'
#' Two rules are available:
#'
#' - `rule = "probability"` (the rule of Wood & Kahl 2024): the lowest score
#'   `c` at which the calibrated probability that a detection is a true
#'   positive, P(TP | score = c, site, species), reaches `target` and stays
#'   at or above it for every higher score. Only the model is needed.
#' - `rule = "precision"`: the lowest score `c` at which the expected
#'   precision of the detections kept, the mean of P(TP) over every
#'   detection of the cell with a score >= `c`, reaches `target` and stays
#'   at or above it. It needs the scored detections of the selection tables
#'   ([score_detections()]), and answers the question that
#'   [suggest_thresholds()] answers with the reviewed clips: what share of
#'   the detections above the threshold are true? The threshold is lower
#'   than with `"probability"`, because the detections above `c` have higher
#'   probabilities than a detection at `c`.
#'
#' The candidate thresholds are the points of a grid of scores (step
#' `grid_step`, from `min_confidence`), as in [score_detections()].
#'
#' With a model fitted with `engine = "brms"`, `rule = "probability"` also
#' returns `threshold_lower`: the lowest score at which the lower quantile
#' (`lower_prob`) of the posterior of P(TP) reaches `target`, a conservative
#' threshold that accounts for the uncertainty of the calibration.
#'
#' **Which clips to review.** The calibration models the verdict given the
#' score. Choosing the clips to review by their score only (for instance,
#' adding a second random sample from the higher scores, as Wood & Kahl 2024
#' suggest for species with few true detections) does not
#' bias P(TP | score), as long as the model form is right; it does bias the
#' precision computed directly from the reviewed clips, which
#' [suggest_thresholds()] uses. The site-confirmation design of
#' false-positive occupancy models needs instead clips drawn at random
#' (`sampling_mode = "random_detections"` or `"random_recordings"` in
#' [select_clips()]).
#'
#' **Site effects.** With a site effect, P(TP | score, site) mixes the error
#' of the classifier with how often the species calls at the site. For a
#' threshold this is what is wanted: the precision at a site depends on
#' both. It is not a measure of the classifier alone.
#'
#' @param fit Model returned by [fit_calibration()].
#' @param target Target probability (`"probability"`) or precision
#'   (`"precision"`). The default, 0.95, is the `p_min` of
#'   [score_detections()] and [calibrate()], so that the probability
#'   threshold is the score equivalent of the cut on P(TP) used for the
#'   detection histories. It is the same for both rules; the `"precision"`
#'   threshold is lower for the same target (see Details).
#'   [suggest_thresholds()] uses 0.90 by default.
#' @param rule `"probability"` or `"precision"`; see Details.
#' @param scored Table returned by [score_detections()], with `site`,
#'   `species`, `confidence` and `p_tp`. Required for `rule = "precision"`;
#'   with `rule = "probability"`, its site x species cells are used when
#'   `cells` is `NULL`.
#' @param cells Data frame of the cells to threshold, with `site` and
#'   `species` and any other variable of the calibration formula. By default,
#'   the cells of `scored` or, without it, every site x species of the
#'   calibration.
#' @param lower_prob Models fitted with `engine = "brms"`: the probability of
#'   the lower quantile of the posterior of P(TP) used for
#'   `threshold_lower`.
#' @inheritParams score_detections
#'
#' @return A tibble with the cell columns, `threshold` and, for
#'   `rule = "probability"`, `p_tp_at_threshold` (and `threshold_lower` with
#'   a `brms` model); for `rule = "precision"`, `precision_at_threshold`,
#'   `n_above` (detections kept) and `n_detections`. `threshold` is `NA` when
#'   no score of the grid reaches the target. With `"precision"`, a cell can
#'   be `NA` while `"probability"` gives a threshold: the probability
#'   threshold may lie above every detection of the cell, and then no set of
#'   detections reaches the target.
#' @seealso [suggest_thresholds()] for thresholds from the reviewed clips of
#'   each cell; [compare_thresholds()] to put both side by side; [calibrate()], which writes these thresholds to
#'   `thresholds.csv`.
#' @export
#' @examples
#' \dontrun{
#' val <- read_validations(validation_files)
#' fit <- fit_calibration(val, calibration_models()$m4_species_x_site)
#' calibrated_thresholds(fit, target = 0.95)
#'
#' # expected precision of the detections kept, from the selection tables
#' scored <- score_detections(tables, fit)
#' calibrated_thresholds(fit, target = 0.90, rule = "precision",
#'                       scored = scored)
#' }
calibrated_thresholds <- function(fit, target = 0.95,
                                  rule = c("probability", "precision"),
                                  scored = NULL, cells = NULL,
                                  min_confidence = 0.1, grid_step = 0.01,
                                  lower_prob = 0.05) {
  rule <- match.arg(rule)
  niveis <- fit_levels(fit)
  if (!is.numeric(target) || length(target) != 1 || target <= 0 ||
      target >= 1) {
    stop("`target` must be a single number between 0 and 1.", call. = FALSE)
  }

  if (rule == "precision") {
    if (is.null(scored)) {
      stop("rule = \"precision\" needs `scored`, the detections scored by ",
           "score_detections().", call. = FALSE)
    }
    return(thresholds_by_precision(scored, target, min_confidence,
                                   grid_step))
  }

  if (is.null(cells)) {
    cells <- if (!is.null(scored)) {
      distinct(scored, site = as.character(site),
               species = as.character(species))
    } else {
      expand_grid(site = niveis$site, species = niveis$species)
    }
  }
  faltam <- setdiff(c("site", "species"), names(cells))
  if (length(faltam) > 0) {
    stop("`cells` lacks the columns: ", paste(faltam, collapse = ", "),
         call. = FALSE)
  }
  cells <- distinct(cells) |>
    mutate(site = as.character(site), species = as.character(species))
  novos <- c(setdiff(cells$site, niveis$site),
             setdiff(cells$species, niveis$species))
  if (length(novos) > 0) {
    warning("Level(s) not in the calibration, thresholded with the ",
            "population-level effects only: ",
            paste(unique(novos), collapse = ", "), call. = FALSE)
  }

  grade <- score_grid(min_confidence, grid_step)
  nd <- cells |>
    mutate(.cell = row_number()) |>
    tidyr::expand_grid(confidence = grade) |>
    mutate(logit_conf = safe_logit(confidence),
           site = factor(site, levels = niveis$site),
           species = factor(species, levels = niveis$species))

  if (inherits(fit, "brmsfit")) {
    draws <- brms::posterior_epred(fit, newdata = nd,
                                   allow_new_levels = TRUE)
    resumo <- summarise_grid_draws(draws, target, lower_prob)
    nd$p_tp <- resumo$p_tp
    nd$p_tp_lower <- resumo$p_tp_lower
  } else {
    nd$p_tp <- predict_tp(fit, nd)
  }

  limiares <- nd |>
    group_by(.cell) |>
    summarise(
      threshold = confidence[first_sustained(p_tp, target)],
      p_tp_at_threshold = p_tp[first_sustained(p_tp, target)],
      threshold_lower = if ("p_tp_lower" %in% names(nd))
        confidence[first_sustained(p_tp_lower, target)] else NA_real_,
      .groups = "drop")
  if (!inherits(fit, "brmsfit")) limiares$threshold_lower <- NULL

  cells |>
    mutate(.cell = row_number()) |>
    left_join(limiares, by = ".cell") |>
    select(-".cell")
}

# Indice do primeiro ponto a partir do qual `x` fica >= `target` ate o fim
# da grade; NA quando o ultimo ponto nao chega ao alvo. Pontos NA (sem
# deteccoes acima, na regra "precision") nao contam.
first_sustained <- function(x, target) {
  ok <- !is.na(x) & x >= target
  validos <- which(!is.na(x))
  if (length(validos) == 0 || !ok[max(validos)]) return(NA_integer_)
  falhas <- validos[!ok[validos]]
  primeiro <- if (length(falhas) == 0) min(validos) else
    min(validos[validos > max(falhas)])
  primeiro
}

# Regra "precision": media de P(TP) das deteccoes com score >= c, para cada
# ponto c da grade, por local x especie
thresholds_by_precision <- function(scored, target, min_confidence,
                                    grid_step) {
  faltam <- setdiff(c("site", "species", "confidence", "p_tp"),
                    names(scored))
  if (length(faltam) > 0) {
    stop("`scored` lacks the columns: ", paste(faltam, collapse = ", "),
         ". Use the output of score_detections().", call. = FALSE)
  }
  grade <- score_grid(min_confidence, grid_step)
  scored |>
    mutate(site = as.character(site), species = as.character(species)) |>
    filter(!is.na(p_tp)) |>
    group_by(site, species) |>
    group_modify(function(d, chave) {
      ord <- order(d$confidence, decreasing = TRUE)
      conf <- d$confidence[ord]
      soma <- cumsum(d$p_tp[ord])
      # numero de deteccoes com score >= cada ponto da grade
      n_acima <- vapply(grade, \(g) sum(conf >= g), integer(1))
      prec <- ifelse(n_acima > 0, soma[pmax(n_acima, 1)] / n_acima, NA_real_)
      i <- first_sustained(prec, target)
      tibble(threshold = grade[i], precision_at_threshold = prec[i],
             n_above = if (is.na(i)) NA_integer_ else n_acima[i],
             n_detections = nrow(d))
    }) |>
    ungroup()
}
