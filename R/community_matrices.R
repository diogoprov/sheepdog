#' Community matrices from the detection history
#'
#' Turns the calibrated nightly detection history into site x month
#' community matrices for multivariate ordinations (PCoA, NMDS, RDA).
#' Because those analyses do not model false positives, the entry rule is
#' strict:
#' * a species counts as detected on a night only when it had at least
#'   `k_min` reliable detections that night, i.e. detections with a
#'   calibrated probability >= `p_min` of [calibrate()] (column
#'   `detection_k<k_min>` of the history);
#' * only the core species enter the matrix: species whose calibration is
#'   reliable at every site. Other species would create artefactual beta
#'   diversity from differences in classifier recall among sites;
#' * each cell is the frequency of nights with detection, standardised by
#'   effort: nights with detection / nights recorded at that site x month.
#'
#' Effort (nights recorded) is approximated by the number of distinct
#' nights in the history of the site, for any species. With dense
#' detections, every night actually recorded appears in the history.
#'
#' @param history A data frame (or tibble), the nightly detection history
#'   as returned by [detection_history()], one row per site x species x
#'   night (v1.2.0 `historico_deteccao_noite.csv` tables are also
#'   accepted).
#' @param core_species Character vector of length >= 1, species codes (the
#'   `species` column) that enter the matrix.
#' @param k_min Integer scalar, one of 1, 2 or 3. Repetition rule: 1, 2 or
#'   3 reliable detections on the night.
#' @param min_nights_month Numeric scalar. Site x month cells with fewer
#'   recorded nights are dropped from the matrices (unstable frequencies)
#'   and flagged in `effort`.
#' @param drop_empty Logical scalar. If `TRUE`, drops the site x month rows
#'   in which no core species was detected. Distances such as Bray-Curtis
#'   are undefined for them.
#'
#' @return A list with three tibbles, `frequency` and `counts` (one row per
#'   site x month, with `site`, `month`, `n_nights_recorded` and one column
#'   per core species) and `effort` (`site`, `month`, `n_nights_recorded`,
#'   `included`), plus `trials`: a numeric matrix with the dimensions of
#'   the species columns of `counts` holding the nights recorded, the
#'   `Ntrials` of a binomial model of the counts (e.g. `gllvm::gllvm()`,
#'   which needs a matrix when effort varies among samples). The row names
#'   of `trials` are `<site>_<month>`.
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' history <- read.csv(file.path(ex, "nightly_detection_history.csv"),
#'                     colClasses = c(night = "character"))
#' mats <- community_matrices(history,
#'                            core_species = c("boa_ran", "ela_bic",
#'                                             "phy_cuv"),
#'                            k_min = 2, min_nights_month = 5)
#' mats$frequency
#' # Site x month cells dropped for low effort
#' mats$effort[!mats$effort$included, ]
#' head(mats$trials)
#' @export
community_matrices <- function(history, core_species, k_min = 2,
                               min_nights_month = 5, drop_empty = FALSE) {
  if (length(core_species) == 0) stop("`core_species` is empty.")
  hist_tbl <- from_legacy(history) |>
    mutate(night = as.character(night))

  col_k <- paste0("detection_k", k_min)
  if (!col_k %in% names(hist_tbl)) {
    stop("Column ", col_k, " is not in the history.")
  }

  missing_sp <- setdiff(core_species, unique(hist_tbl$species))
  if (length(missing_sp) > 0) {
    warning("Core species missing from the history: ",
            paste(missing_sp, collapse = ", "))
  }

  # effort: nights recorded per site x month (every species counts)
  hist_tbl <- hist_tbl |>
    mutate(month = str_c(str_sub(night, 1, 4), "-", str_sub(night, 5, 6)))

  effort <- hist_tbl |>
    distinct(site, month, night) |>
    count(site, month, name = "n_nights_recorded") |>
    mutate(included = n_nights_recorded >= min_nights_month)

  # nights with detection per site x month x species (k_min rule, core only)
  detected <- hist_tbl |>
    filter(species %in% core_species, .data[[col_k]] == 1) |>
    count(site, month, species, name = "n_nights_detected")

  long <- effort |>
    filter(included) |>
    select(site, month, n_nights_recorded) |>
    crossing(species = core_species) |>
    left_join(detected, by = c("site", "month", "species")) |>
    mutate(
      n_nights_detected = replace_na(n_nights_detected, 0L),
      frequency = n_nights_detected / n_nights_recorded
    )

  # wide matrices (rows = site x month; columns = species)
  freq <- long |>
    select(site, month, n_nights_recorded, species, frequency) |>
    pivot_wider(names_from = species, values_from = frequency) |>
    arrange(site, month)

  counts <- long |>
    select(site, month, n_nights_recorded, species, n_nights_detected) |>
    pivot_wider(names_from = species, values_from = n_nights_detected) |>
    arrange(site, month)

  if (drop_empty) {
    cols <- intersect(core_species, names(counts))
    empty <- rowSums(as.matrix(counts[cols])) == 0
    if (any(empty)) {
      message(sum(empty), " site x month row(s) without any core species ",
              "dropped: ", paste(counts$site[empty],
                                 counts$month[empty], collapse = ", "))
      counts  <- counts[!empty, ]
      freq <- freq[!empty, ]
    }
  }

  cols <- setdiff(names(counts), c("site", "month", "n_nights_recorded"))
  trials <- matrix(as.numeric(counts$n_nights_recorded),
                       nrow = nrow(counts), ncol = length(cols),
                       dimnames = list(paste(counts$site, counts$month,
                                             sep = "_"), cols))

  list(frequency = freq, counts = counts, effort = effort,
       trials = trials)
}

#' Write the community matrices
#'
#' Reads the nightly detection history written by [calibrate()] and writes
#' the matrices of [community_matrices()] to `output_dir`:
#' `frequency_matrix_site_month_k<k>.csv`,
#' `count_matrix_site_month_k<k>.csv` and `effort_site_month.csv` (which
#' also lists the dropped cells). This is the function form of the v1.2.0
#' script `gerar_matrizes_comunidade.R`.
#'
#' @inheritParams community_matrices
#' @param history_file Character scalar, path to
#'   `nightly_detection_history.csv` (or a v1.2.0
#'   `historico_deteccao_noite.csv`).
#' @param output_dir Character scalar, path to the output folder; created if
#'   needed.
#'
#' @return The list returned by [community_matrices()], invisibly.
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' out <- file.path(tempdir(), "matrices")
#' build_community_matrices(file.path(ex, "nightly_detection_history.csv"),
#'                          output_dir = out,
#'                          core_species = c("boa_ran", "ela_bic",
#'                                           "phy_cuv"),
#'                          k_min = 2)
#' list.files(out)
#' @export
build_community_matrices <- function(history_file, output_dir, core_species,
                                     k_min = 2, min_nights_month = 5) {
  if (!file.exists(history_file)) stop("History not found: ", history_file)
  # the night (YYYYMMDD) is read as text, in the new or the legacy format
  night_cols <- intersect(c("night", "noite"),
                          names(read_csv(history_file, n_max = 0,
                                         show_col_types = FALSE)))
  hist_tbl <- read_csv(
    history_file, show_col_types = FALSE,
    col_types = readr::cols(!!!setNames(rep(list(readr::col_character()),
                                            length(night_cols)), night_cols),
                            .default = readr::col_guess()))
  mats <- community_matrices(hist_tbl, core_species, k_min,
                             min_nights_month)

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  suffix <- paste0("site_month_k", k_min)
  write_csv(mats$frequency,
            file.path(output_dir, paste0("frequency_matrix_", suffix, ".csv")))
  write_csv(mats$counts,
            file.path(output_dir, paste0("count_matrix_", suffix, ".csv")))
  write_csv(mats$effort, file.path(output_dir, "effort_site_month.csv"))

  n_dropped <- sum(!mats$effort$included)
  message("Matrix: ", nrow(mats$frequency), " rows (site x month) x ",
          length(core_species), " species | rule k >= ", k_min)
  message("Effort: ", sum(mats$effort$included), " site x month cells ",
          "included; ", n_dropped, " dropped for having < ", min_nights_month,
          " recorded nights (see effort_site_month.csv)")
  message("Files in: ", output_dir)
  invisible(mats)
}
