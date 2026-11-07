#' Nightly detection history from empirical thresholds
#'
#' The history of the empirical route: a detection is reliable when its
#' confidence reaches the threshold of its site x species cell, from
#' [review_support()] or [suggest_thresholds()], with no calibration model.
#' The result has the columns that [community_matrices()] and
#' [summarise_history()] read, as the history of [detection_history()].
#'
#' Every night with a detection stays in the history, also those of cells
#' without a threshold, because [community_matrices()] takes the effort from
#' the distinct nights of the history. Leaving those cells out would lower
#' the nights recorded and raise the frequency of the other species. In
#' those cells `n_reliable` and the detection columns are `NA`: nothing is
#' known about them. [community_matrices()] does not count `NA` as a
#' detection, so such a cell shows as 0 in the matrices, which does not mean
#' that the species is absent.
#'
#' The threshold holds for the set of detections kept, not for each one; see
#' [suggest_thresholds()].
#'
#' @param detections Predictions, from [read_selection_tables()], with
#'   `site`, `species_code`, `confidence` and `begin_path`. Use every
#'   prediction, not only those of the cells with a threshold.
#' @param thresholds Table with `site`, `species_folder` and `threshold`, one
#'   row per cell, such as the output of [review_support()]. Cells with a
#'   missing threshold or without a row have no threshold.
#' @param min_confidence Predictions below this confidence are left out, as
#'   in [score_detections()]. This also sets which nights count as recorded.
#' @param dawn_hour Recordings that start before this hour belong to the
#'   night before.
#' @param min_detections_night Repetition rule: minimum number of reliable
#'   detections for a night with detection.
#'
#' @return A tibble with `site`, `species` (the short code, as in
#'   `species_folder`), `night`, `n_detections`, `n_reliable`,
#'   `confidence_max`, `detection_k1`, `detection_k2`, `detection_k3` and
#'   `detection`.
#' @seealso [review_support()], [detection_history()],
#'   [community_matrices()]
#' @export
#' @examples
#' detections <- data.frame(
#'   site = "A", species_code = "Boana raniceps_boa-ran",
#'   confidence = c(0.9, 0.8, 0.3),
#'   begin_path = c("A_20240110_200000.wav", "A_20240110_210000.wav",
#'                  "A_20240111_200000.wav"))
#' thresholds <- data.frame(site = "A", species_folder = "boa_ran",
#'                          threshold = 0.7)
#' threshold_history(detections, thresholds)
threshold_history <- function(detections, thresholds, min_confidence = 0.1,
                              dawn_hour = 12, min_detections_night = 1) {
  faltam <- setdiff(c("site", "species_code", "confidence", "begin_path"),
                    names(detections))
  if (length(faltam) > 0) {
    stop("`detections` needs the column(s): ", paste(faltam, collapse = ", "),
         ".", call. = FALSE)
  }
  faltam <- setdiff(c("site", "species_folder", "threshold"), names(thresholds))
  if (length(faltam) > 0) {
    stop("`thresholds` needs the column(s): ", paste(faltam, collapse = ", "),
         ".", call. = FALSE)
  }
  limiares <- thresholds |>
    transmute(site = as.character(site), species = species_folder, threshold)
  if (anyDuplicated(limiares[c("site", "species")])) {
    stop("`thresholds` must have one row per site x species; thresholds by ",
         "month or another `by` column are not supported.", call. = FALSE)
  }

  data_hora <- parse_date_hour(basename(detections$begin_path))
  noites <- detections |>
    mutate(site = as.character(site),
           species = folder_name(species_code),
           night = night_of(data_hora$recording_date,
                            data_hora$recording_hour, dawn_hour)) |>
    filter(confidence >= min_confidence, !is.na(night)) |>
    left_join(limiares, by = c("site", "species")) |>
    group_by(site, species, night) |>
    summarise(n_detections = n(),
              n_reliable = sum(confidence >= threshold),
              confidence_max = max(confidence),
              .groups = "drop")

  historico <- noites |>
    mutate(detection_k1 = as.integer(n_reliable >= 1),
           detection_k2 = as.integer(n_reliable >= 2),
           detection_k3 = as.integer(n_reliable >= 3),
           detection = as.integer(n_reliable >= min_detections_night))

  sem_limiar <- filter(historico, is.na(n_reliable)) |>
    distinct(site, species)
  if (nrow(sem_limiar) > 0) {
    message(nrow(sem_limiar), " site x species cell(s) without a threshold: ",
            "their nights count as effort, and their detection columns are ",
            "NA.")
  }
  historico
}
