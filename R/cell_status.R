#' Status of each site x species cell for the community matrices
#'
#' Classifies each site x species cell of the calibration by whether its
#' detections can enter a community matrix, separating the absence of a
#' species from a calibration that does not work:
#'
#' * `"reliable"`: the calibrated curve reaches `p_min` within the range of
#'   reviewed scores of the cell, and the cell has at least `min_n`
#'   reviewed clips;
#' * `"probably_absent"`: clips were reviewed but none was a true positive.
#'   The species can enter the matrix with zeros at that site;
#' * `"unreliable"`: true positives were reviewed, but the curve never
#'   reaches `p_min` within the reviewed scores, or the cell has fewer than
#'   `min_n` reviewed clips, or no clip at all was reviewed. A zero in such
#'   a cell could be a false negative.
#'
#' [suggest_core_species()] keeps the species without unreliable cells.
#' The final choice of core species remains with the analyst.
#'
#' @param fit Model returned by [fit_calibration()].
#' @param validations Table returned by [read_validations()], the clips
#'   the model was fitted to.
#' @param p_min Calibrated probability that makes a detection reliable, as
#'   in [detection_history()].
#' @param min_n Minimum number of reviewed clips in a cell.
#' @param by Optional columns of `validations` that split each cell, e.g.
#'   the bin of an environmental gradient or of an acoustic index from
#'   [covariate_bins()] (kept by `read_validations(keep = )` or joined
#'   afterwards). Each site x species x `by` cell gets its own status; the
#'   threshold uses the `by` columns only if the calibration model does.
#'
#' @return A tibble with one row per site x species (x `by`): `site`,
#'   `species`, the `by` columns,
#'   `n_reviewed`, `n_tp`, `max_confidence` (highest reviewed score),
#'   `threshold` (lowest grid score at which the calibrated probability
#'   reaches `p_min`; `NA` if never), `status` and `reason`. The grid
#'   contains both observed endpoints and steps of 0.01 within the
#'   reviewed range.
#' @export
cell_status <- function(fit, validations, p_min = 0.95, min_n = 15,
                        by = NULL) {
  check_by(validations, by)
  niveis <- fit_levels(fit)
  resumo <- validations |>
    mutate(across(c(site, species), as.character)) |>
    group_by(site, species, across(all_of(by))) |>
    summarise(n_reviewed = n(), n_tp = sum(tp),
              min_confidence = min(confidence),
              max_confidence = max(confidence), .groups = "drop")

  celulas <- expand_grid(site = niveis$site, species = niveis$species)
  if (!is.null(by)) {
    celulas <- tidyr::crossing(celulas, distinct(validations[by]))
  }
  celulas <- celulas |>
    left_join(resumo, by = c("site", "species", by)) |>
    mutate(n_reviewed = replace_na(n_reviewed, 0L),
           n_tp = replace_na(n_tp, 0L))

  limiar <- pmap_dbl(celulas, function(site, species, n_reviewed,
                                       min_confidence, max_confidence, ...) {
    if (n_reviewed == 0) return(NA_real_)
    extras <- list(...)[by]
    # Include both observed endpoints, without extrapolating below the
    # reviewed range or missing crossings between 0.99 and the maximum.
    interior <- seq(floor(min_confidence * 100) / 100,
                    max_confidence, by = 0.01)
    scores <- sort(unique(c(min_confidence,
                            interior[interior >= min_confidence &
                                       interior <= max_confidence],
                            max_confidence)))
    grade <- tibble(
      site = factor(site, levels = niveis$site),
      species = factor(species, levels = niveis$species),
      confidence = scores) |>
      mutate(logit_conf = safe_logit(confidence))
    for (col in by) grade[[col]] <- extras[[col]]
    p <- predict_tp(fit, grade)
    if (any(p >= p_min)) min(grade$confidence[p >= p_min]) else NA_real_
  })

  celulas |>
    mutate(
      threshold = limiar,
      status = case_when(
        n_reviewed > 0 & n_tp == 0              ~ "probably_absent",
        n_reviewed >= min_n & !is.na(threshold) ~ "reliable",
        .default = "unreliable"
      ),
      reason = case_when(
        status == "reliable"        ~ "reaches p_min",
        status == "probably_absent" ~ "no true positive among the reviewed clips",
        n_reviewed == 0             ~ "no reviewed clip",
        n_reviewed < min_n          ~ "fewer than min_n reviewed clips",
        .default = "does not reach p_min within the reviewed scores"
      )
    ) |>
    select(site, species, all_of(by), n_reviewed, n_tp, max_confidence,
           threshold, status, reason) |>
    arrange(species, site, across(all_of(by)))
}

#' Suggest the core species of the community matrices
#'
#' Keeps the species with no unreliable site x species cell in the table of
#' [cell_status()]: reliable at every site, or reliable where present and
#' probably absent elsewhere.
#'
#' @param status Table returned by [cell_status()].
#'
#' @return A character vector of species codes (the `species` column of
#'   the history).
#' @export
suggest_core_species <- function(status) {
  status |>
    group_by(species) |>
    summarise(ok = !any(status == "unreliable"),
              any_reliable = any(status == "reliable"), .groups = "drop") |>
    filter(ok, any_reliable) |>
    pull(species) |>
    as.character()
}
