#' Detections of each occasion over the draws of the calibration
#'
#' Turns an export of [export_occupancy_data()] with calibration draws into
#' one version of the detection data per posterior draw: in each draw, an
#' occasion is a detection when at least one of its predictions is judged
#' true. Any occupancy software can then fit its model to each version and
#' pool the posteriors, so that the uncertainty of the calibration reaches
#' the ecological estimates (Monte Carlo propagation). This is the
#' occasion-level counterpart of [history_draws()], which works by night.
#'
#' @section Rules:
#' With `rule = "sample"` (default), a prediction whose probability of
#' being true is `p` in a draw is judged true with probability `p`, so no
#' threshold is involved; this assumes that the predictions of an occasion
#' are true or false independently, given the calibration. With
#' `rule = "threshold"`, it is judged true when `p >= p_min`, as in
#' [history_draws()]; this keeps only the predictions the calibration is
#' nearly sure of and gives fewer detections.
#'
#' @section Matching:
#' A prediction takes the value of the grid point nearest its score and of
#' the calibration keys of its occasion (`schema.json$calibration$keys`,
#' e.g. the month). An occasion with a prediction that has no calibration
#' draws (a species, site or key level absent from
#' `calibration_draws.parquet`) cannot be scored: it is `NA` in every draw,
#' with a warning, not a non-detection.
#'
#' @section Reproducibility:
#' The random numbers follow those of `crywolf::fp_draws_data()`, so that
#' both give the same detections for the same export, rule and seed: the
#' seed is set once per species with R's default generators
#' (Mersenne-Twister, Inversion, Rejection), and each draw, in increasing
#' order of its identifier, takes one uniform number per scored prediction,
#' in the order of `detections.csv`. The first `n` draws of a call are
#' therefore the same as those of a call with `n_draws = n`. Species are
#' processed one at a time, in alphabetical order, each from the seed. The
#' global random number generator is left as it was.
#'
#' @param export_dir Character scalar, path to the folder written by
#'   [export_occupancy_data()] with
#'   `fit`.
#' @param species `NULL` or character vector, species to process, matched
#'   against `species`
#'   (the short code, e.g. `"phy_cuv"`) or `species_code` of
#'   `detections.csv`. All species with calibration draws by default.
#' @param rule Character scalar, `"sample"` or `"threshold"`; see Rules.
#' @param p_min Numeric scalar in \[0, 1\], threshold of
#'   `rule = "threshold"`.
#' @param n_draws `NULL` or integer scalar >= 1, number of calibration
#'   draws to use: the first ones, in increasing order of their
#'   identifiers. All by default.
#' @param seed Numeric scalar, seed of `rule = "sample"`.
#' @param write Logical scalar. If `TRUE`, write `occasion_draws.parquet`
#'   in `export_dir` and record it
#'   in `schema.json` (schema version 1.2 or later). An existing table is replaced.
#'
#' @return A tibble with `draw`, `site`, `occasion_id`, `species` and `y`
#'   (1 detection, 0 none, `NA` not scored), with one row per draw and
#'   occasion with at least one exported prediction of the species. The
#'   other occasions of `occasions.csv` are non-detections in every draw.
#'   Returned invisibly when `write = TRUE`.
#' @seealso [export_occupancy_data()], [history_draws()],
#'   `vignette("crywolf-integration")`.
#' @export
occasion_draws <- function(export_dir, species = NULL,
                           rule = c("sample", "threshold"), p_min = 0.95,
                           n_draws = NULL, seed = 2026, write = TRUE) {
  rule <- match.arg(rule)
  schema_file <- file.path(export_dir, "schema.json")
  if (!file.exists(schema_file)) {
    stop("No schema.json in `export_dir`; was it written by ",
         "export_occupancy_data()?", call. = FALSE)
  }
  require_suggested("arrow", "to read calibration_draws.parquet")
  schema <- jsonlite::read_json(schema_file, simplifyVector = TRUE)
  if (length(schema$calibration$covariates) > 0) {
    stop("The calibration of this export depends on continuous ",
         "covariate(s) (", paste(schema$calibration$covariates, collapse = ", "),
         "): it has no grid of calibration draws, and its versions were ",
         "drawn by export_occupancy_data() (occasion_draws.parquet). To ",
         "change the rule, the seed or the number of versions, export again ",
         "with `n_versions`, `rule`, `p_min` and `seed`.", call. = FALSE)
  }
  parquet <- file.path(export_dir, "calibration_draws.parquet")
  if (is.null(schema$calibration) || !file.exists(parquet)) {
    stop("The export has no calibration draws; write it with ",
         "export_occupancy_data(fit = ).", call. = FALSE)
  }
  if (rule == "sample" && (!is.numeric(seed) || length(seed) != 1 ||
                           is.na(seed))) {
    stop("`seed` must be a number for rule = \"sample\".", call. = FALSE)
  }
  keys <- setdiff(schema$calibration$keys,
                  c("site", "species", "grid_index"))
  # everything as text (identifiers and keys do not become numbers); only
  # the score is converted
  read_chr <- function(fname) {
    readr::read_csv(file.path(export_dir, fname), na = "", progress = FALSE,
                    col_types = readr::cols(.default = readr::col_character()))
  }
  det <- read_chr("detections.csv")
  det$confidence <- as.numeric(det$confidence)
  occasions <- read_chr("occasions.csv")
  for (ch in keys) {
    if (!ch %in% names(occasions)) {
      # 1.0 exports with calibration by month did not write the column
      if (ch != "month") {
        stop("Calibration key `", ch, "` is not a column of occasions.csv.",
             call. = FALSE)
      }
      occasions$month <- substr(occasions$recording_date, 1, 6)
    }
  }
  # without mmap, the file is not left locked on Windows after reading
  cal <- as.data.frame(arrow::read_parquet(parquet, mmap = FALSE))
  for (ch in c("site", "species", keys)) cal[[ch]] <- as.character(cal[[ch]])

  spp <- sort(unique(det$species[det$species %in% cal$species]))
  if (!is.null(species)) {
    requested <- unique(det$species[det$species %in% species |
                                    det$species_code %in% species])
    spp <- intersect(spp, requested)
  }
  if (length(spp) == 0) {
    stop("No species with both predictions and calibration draws",
         if (!is.null(species)) " among `species`", ".", call. = FALSE)
  }
  out <- map(spp, \(sp) occasion_draws_species(
    det[det$species == sp, ], occasions, cal[cal$species == sp, ], keys,
    schema$calibration$grid_step, rule, p_min, n_draws, seed)) |>
    list_rbind()

  if (!write) return(out)
  arrow::write_parquet(out, file.path(export_dir, "occasion_draws.parquet"))
  schema$schema_version <- max(schema$schema_version, 1.2)
  schema$tables$occasion_draws <- list(file = "occasion_draws.parquet",
                                       rows = nrow(out))
  schema$occasion_draws <- compact(list(
    file = "occasion_draws.parquet", rule = rule,
    p_min = if (rule == "threshold") p_min,
    seed = if (rule == "sample") seed,
    n_draws = length(unique(out$draw)), species = I(spp)))
  # one-element vectors stay arrays in the JSON
  for (field in c("sites", "species", "occasion_covariates")) {
    if (!is.null(schema[[field]])) schema[[field]] <- I(schema[[field]])
  }
  if (!is.null(schema$calibration$keys)) {
    schema$calibration$keys <- I(schema$calibration$keys)
  }
  jsonlite::write_json(schema, schema_file, auto_unbox = TRUE, pretty = TRUE,
                       digits = NA)
  message("occasion_draws.parquet written to ", export_dir, ": ",
          nrow(out), " rows, ", length(unique(out$draw)), " draws.")
  invisible(out)
}

#' Draw the occasion detections of one species from the calibration grid
#'
#' Builds the matrix of P(TP) by key x draw, matches each prediction to its
#' grid point and keys, and draws in the order of `crywolf::fp_draws_data()`.
#'
#' @param det A data frame, the rows of `detections.csv` for one species
#'   (character columns, numeric `confidence`).
#' @param occasions A data frame, the rows of `occasions.csv` (character).
#' @param cal A data frame, the rows of `calibration_draws.parquet` for the
#'   species, with `draw`, `grid_index`, `confidence`, `p_tp` and the keys.
#' @param keys Character vector, calibration keys other than `site`,
#'   `species` and `grid_index`.
#' @param step Numeric scalar, the step of the score grid.
#' @param rule Character scalar, `"sample"` or `"threshold"`.
#' @param p_min Numeric scalar in \[0, 1\], threshold of `rule = "threshold"`.
#' @param n_draws Integer scalar or `NULL`, number of first draws to use.
#' @param seed Numeric scalar, seed of `rule = "sample"`.
#' @return A tibble with `draw`, `site`, `occasion_id`, `species` and `y`.
#' @noRd
occasion_draws_species <- function(det, occasions, cal, keys, step, rule,
                                   p_min, n_draws, seed) {
  ids <- sort(unique(cal$draw))
  if (!is.null(n_draws)) ids <- utils::head(ids, n_draws)
  cal <- cal[cal$draw %in% ids, , drop = FALSE]
  # the origin of the grid with the stored bits (the JSON value may differ
  # in the last digit)
  grid_min <- min(cal$confidence[cal$grid_index == 1])
  key_of <- function(d, g) {
    do.call(paste, c(unname(as.list(d[c("site", "species", keys)])),
                     list(g, sep = "\r")))
  }
  rows <- unique(key_of(cal, cal$grid_index))
  if (anyDuplicated(cbind(key_of(cal, cal$grid_index), cal$draw))) {
    stop("calibration_draws.parquet has more than one value for some key ",
         "and draw; is a key missing from schema.json?", call. = FALSE)
  }
  P <- matrix(NA_real_, length(rows), length(ids))
  P[cbind(match(key_of(cal, cal$grid_index), rows),
          match(cal$draw, ids))] <- cal$p_tp

  occ_key <- paste(occasions$site, occasions$occasion_id, sep = "\r")
  o <- match(paste(det$site, det$occasion_id, sep = "\r"), occ_key)
  g <- round((det$confidence - grid_min) / step) + 1
  g <- pmin(pmax(g, 1), max(cal$grid_index))
  det_keys <- occasions[o, keys, drop = FALSE]
  k <- match(key_of(cbind(det[c("site", "species")], det_keys), g), rows)
  Pdet <- matrix(NA_real_, nrow(det), length(ids))
  Pdet[!is.na(k), ] <- P[k[!is.na(k)], , drop = FALSE]
  sample_versions(det, occasions, o, Pdet, ids, rule, p_min, seed,
                  reason = "without calibration draws")
}

#' Draw the detection versions of one species
#'
#' Draws in the order of `crywolf::fp_draws_data()`. Predictions without
#' P(TP) leave their occasion `NA` (not scored).
#'
#' @param det A data frame, the predictions of one species, in the order of
#'   `detections.csv`, with `species`.
#' @param occasions A data frame of occasions with `site` and `occasion_id`.
#' @param o Integer vector, one element per row of `det`, the row of each
#'   prediction's occasion in `occasions` (`NA` when absent).
#' @param Pdet Numeric matrix of P(TP), one row per prediction and one column
#'   per draw.
#' @param ids Vector of draw identifiers, in increasing order, one per column
#'   of `Pdet`.
#' @param rule Character scalar, `"sample"` or `"threshold"`.
#' @param p_min Numeric scalar in \[0, 1\], threshold of `rule = "threshold"`.
#' @param seed Numeric scalar, seed of `rule = "sample"`.
#' @param reason Character scalar, why a prediction has no P(TP), for the
#'   warning.
#' @return A tibble with `draw`, `site`, `occasion_id`, `species` and `y`
#'   (integer, `NA` when not scored), one row per draw and occasion with a
#'   prediction.
#' @noRd
sample_versions <- function(det, occasions, o, Pdet, ids, rule, p_min, seed,
                            reason) {
  if (anyNA(o)) {
    warning(sum(is.na(o)), " prediction(s) of ", det$species[1], " are not ",
            "in occasions.csv and were left out.", call. = FALSE)
  }
  no_cal <- !stats::complete.cases(Pdet) & !is.na(o)
  unscored <- unique(o[no_cal])
  if (length(unscored) > 0) {
    warning(sum(no_cal), " prediction(s) of ", det$species[1], " ", reason,
            ": their ", length(unscored),
            " occasion(s) are NA (not scored).", call. = FALSE)
  }
  # left out of the draw: predictions without P(TP), outside the occasions,
  # and all predictions of an unscored occasion
  keep <- !no_cal & !is.na(o) & !(o %in% unscored)
  Pk <- Pdet[keep, , drop = FALSE]
  o_keep <- o[keep]
  with_pred <- sort(unique(o[!is.na(o)]))

  draw_all <- function() {
    map(seq_along(ids), function(j) {
      p <- Pk[, j]
      is_true <- if (rule == "sample") stats::runif(length(p)) < p
                 else p >= p_min
      y <- tabulate(o_keep[is_true], nbins = nrow(occasions))[with_pred] > 0
      y <- as.integer(y)
      y[with_pred %in% unscored] <- NA_integer_
      tibble(draw = as.integer(ids[j]), site = occasions$site[with_pred],
             occasion_id = occasions$occasion_id[with_pred],
             species = det$species[1], y = y)
    }) |> list_rbind()
  }
  if (rule == "sample") {
    withr::with_seed(seed, draw_all(), .rng_kind = "Mersenne-Twister",
                     .rng_normal_kind = "Inversion",
                     .rng_sample_kind = "Rejection")
  } else {
    draw_all()
  }
}
