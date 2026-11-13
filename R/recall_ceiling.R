#' Recall ceiling and recall at the threshold
#'
#' Estimates how much of the true activity of a species the classifier can
#' recover. The occasions drawn with `sampling_mode = "random_recordings"`
#' and annotated by ear say where the species called, whatever the
#' classifier said; matched with the highest score of the species in each
#' occasion (from the selection tables), they give:
#'
#' - the **recall ceiling**: the share of the occasions with the species
#'   that have at least one prediction of it with a score of at least
#'   `min_confidence`. The species called in the other occasions, but the
#'   classifier gave it no score worth keeping, so no threshold recovers
#'   them;
#' - the **recall at a threshold** `t`: the share of the occasions with the
#'   species whose highest score is at least `t`. It is the ceiling times
#'   the share of the detected occasions whose highest score reaches `t`
#'   (`share_above`).
#'
#' Both are ratios weighted by `1 / inclusion_prob`, so occasions drawn with
#' different probabilities (a different fraction per site) count for the
#' occasions they stand for. The intervals come from a bootstrap of whole
#' recordings (`cluster`) within each group.
#'
#' **Reading it.** A low ceiling means that the classifier misses the
#' species altogether in many occasions with it: check whether a lower
#' `min_confidence` recovers them without many false positives, and if not,
#' the problem is the classifier, not the threshold. A high ceiling with a
#' low recall at the threshold means that the threshold, not the
#' classifier, loses the occasions; weigh it against the precision the
#' threshold buys ([suggest_thresholds()], [threshold_bootstrap()]).
#'
#' **What is needed.** The occasion of the annotation and of the
#' predictions must be the same: give the `occasion_unit` of the draw, and
#' the `remap_from` / `remap_to` of the draw when the recordings moved.
#' Few occasions with the species give wide intervals: the ceiling of a
#' species seldom present needs many annotated occasions.
#'
#' @param validation Reviewed clips (e.g. from [read_validation_tables()]),
#'   with the occasions of `"random_recordings"`: `site`, `species_code`,
#'   `occasion_id`, `sampling_mode`, `verdict` (`"positive"` when the
#'   species was heard in the occasion, `"negative"` when not; other
#'   verdicts are left out), `inclusion_prob` and the `cluster` column.
#'   Clips of other designs are ignored.
#' @param detections Predictions, as returned by [read_selection_tables()].
#' @param thresholds Thresholds at which the recall is computed: a numeric
#'   vector (the same for every group), or a table with the `by` columns
#'   and a `threshold` column, such as the output of
#'   [suggest_thresholds()] (`threshold_column` picks another column, such
#'   as `"threshold_conservative"` of [threshold_bootstrap()]). `NULL` gives
#'   the ceiling only.
#' @param by Columns that define the groups: `"species_folder"` (the
#'   default, every site pooled) or `c("site", "species_folder")`.
#' @param min_confidence The lowest score kept in the selection tables (the
#'   minimum confidence BirdNET was run with). Predictions below it are not
#'   counted.
#' @param occasion_unit The occasion of the draw: `"file"` or `"minute"`.
#' @param remap_from,remap_to Remapping of the audio paths of `detections`,
#'   as in [select_clips()].
#' @param threshold_column Column of `thresholds` with the threshold.
#' @param n_boot Number of bootstrap replicates; 0 skips the intervals.
#' @param cluster Column of `validation` whose levels are resampled whole:
#'   `"source_audio"` (the recording, the default) or `"night"`.
#' @param conf Probability of the intervals.
#' @param seed Seed of the bootstrap. The global random number generator is
#'   left as it was.
#'
#' @return A tibble with one row per group (and threshold): the `by`
#'   columns, `n_occasions` (annotated occasions), `n_present` (occasions
#'   with the species), `n_missed` (occasions with the species and no
#'   prediction of it), `recall_ceiling` with `ceiling_lower` and
#'   `ceiling_upper`; with `thresholds`, also `threshold`, `share_above`,
#'   `recall` and `recall_lower`, `recall_upper`. Groups with no occasion
#'   with the species get `NA`.
#' @seealso [select_clips()] (`"random_recordings"`), [suggest_thresholds()],
#'   [threshold_bootstrap()], [threshold_record()].
#' @export
#' @examples
#' \dontrun{
#' det <- read_selection_tables("birdnet")
#' val <- read_validation_tables(files)
#' recall_ceiling(val, det, thresholds = c(0.5, 0.7, 0.9))
#'
#' # at the threshold of each cell
#' thr <- suggest_thresholds(val, target_precision = 0.95)
#' recall_ceiling(val, det, thresholds = thr,
#'                by = c("site", "species_folder"))
#' }
recall_ceiling <- function(validation, detections, thresholds = NULL,
                           by = "species_folder", min_confidence = 0.1,
                           occasion_unit = c("file", "minute"),
                           remap_from = NULL, remap_to = NULL,
                           threshold_column = "threshold", n_boot = 1000,
                           cluster = "source_audio", conf = 0.95,
                           seed = 2026) {
  unidade <- match.arg(occasion_unit)
  if (!is.numeric(conf) || length(conf) != 1 || conf <= 0 || conf >= 1) {
    stop("`conf` must be a single number between 0 and 1.", call. = FALSE)
  }
  faltam <- setdiff(c("site", "species_code", "occasion_id",
                      "sampling_mode", "verdict"), names(validation))
  if (length(faltam) > 0) {
    stop("`validation` lacks column(s): ", paste(faltam, collapse = ", "),
         ".", call. = FALSE)
  }
  faltam <- setdiff(c("site", "species_code", "confidence", "begin_path",
                      "file_offset"), names(detections))
  if (length(faltam) > 0) {
    stop("`detections` lacks column(s): ", paste(faltam, collapse = ", "),
         ". Read it with read_selection_tables().", call. = FALSE)
  }
  gravacoes <- validation |>
    filter(sampling_mode %in% "random_recordings",
           verdict %in% c("positive", "negative")) |>
    mutate(site = as.character(site),
           species_folder = folder_name(species_code),
           occasion_id = as.character(occasion_id),
           present = verdict == "positive")
  if (nrow(gravacoes) == 0) {
    stop("No occasion of \"random_recordings\" with a positive or negative ",
         "verdict in `validation`. The recall ceiling needs occasions ",
         "annotated by ear, drawn regardless of the classifier.",
         call. = FALSE)
  }
  check_by(gravacoes, by)
  if (n_boot > 0 && !cluster %in% names(gravacoes)) {
    stop("`cluster` (", cluster, ") is not a column of `validation`.",
         call. = FALSE)
  }
  if (!"inclusion_prob" %in% names(gravacoes) ||
      anyNA(gravacoes$inclusion_prob)) {
    message("Some occasions lack `inclusion_prob`: every occasion gets the ",
            "same weight.")
    gravacoes$w <- 1
  } else {
    gravacoes$w <- 1 / as.numeric(gravacoes$inclusion_prob)
  }

  # maior score de cada especie em cada ocasiao
  maximos <- detections |>
    filter(confidence >= min_confidence) |>
    mutate(site = as.character(site),
           occasion_id = make_occasion_id(
             remap_path(begin_path, remap_from, remap_to), file_offset,
             unidade)) |>
    group_by(site, occasion_id, species_code) |>
    summarise(max_score = max(confidence), .groups = "drop")
  achadas <- gravacoes$occasion_id %in% maximos$occasion_id
  if (!any(achadas)) {
    warning("No annotated occasion has a prediction of any species. Check ",
            "that `occasion_unit` and `remap_from` / `remap_to` are those ",
            "of the draw.", call. = FALSE)
  }
  gravacoes <- gravacoes |>
    left_join(maximos, by = c("site", "occasion_id", "species_code"))

  limiares <- thresholds_by_group(thresholds, gravacoes, by,
                                  threshold_column)
  grupos <- split(gravacoes, gravacoes[by], drop = TRUE)
  alfa <- (1 - conf) / 2
  linhas <- withr::with_seed(seed, lapply(grupos, function(d) {
    chave <- as_tibble(d[1, by, drop = FALSE])
    t_grupo <- if (is.null(limiares)) numeric() else
      group_thresholds(limiares, chave, by)
    est <- recall_estimates(d, min_confidence, t_grupo)
    base <- tibble(n_occasions = nrow(d), n_present = sum(d$present),
                   n_missed = sum(d$present & is.na(d$max_score)),
                   recall_ceiling = est$ceiling,
                   ceiling_lower = NA_real_, ceiling_upper = NA_real_)
    reps <- NULL
    if (n_boot > 0 && sum(d$present) > 0) {
      blocos <- split(seq_len(nrow(d)), d[[cluster]])
      reps <- lapply(seq_len(n_boot), function(b) {
        i <- unlist(blocos[sample(length(blocos), replace = TRUE)],
                    use.names = FALSE)
        recall_estimates(d[i, ], min_confidence, t_grupo)
      })
      tetos <- vapply(reps, `[[`, numeric(1), "ceiling")
      base$ceiling_lower <- quantile_or_na(tetos, alfa)
      base$ceiling_upper <- quantile_or_na(tetos, 1 - alfa)
    }
    if (length(t_grupo) == 0) {
      return(bind_cols(chave, base))
    }
    por_limiar <- tibble(threshold = t_grupo, share_above = est$share,
                         recall = est$recall)
    if (!is.null(reps)) {
      r <- vapply(reps, `[[`, numeric(length(t_grupo)), "recall")
      r <- matrix(r, nrow = length(t_grupo))
      por_limiar$recall_lower <- apply(r, 1, quantile_or_na, alfa)
      por_limiar$recall_upper <- apply(r, 1, quantile_or_na, 1 - alfa)
    } else {
      por_limiar$recall_lower <- NA_real_
      por_limiar$recall_upper <- NA_real_
    }
    bind_cols(chave[rep(1, nrow(por_limiar)), , drop = FALSE],
              base[rep(1, nrow(por_limiar)), ], por_limiar)
  }))
  bind_rows(linhas)
}

# Teto, fracao acima de cada limiar e recall, ponderados por 1 / p
recall_estimates <- function(d, min_confidence, limiares) {
  pres <- d$present
  peso_pres <- sum(d$w[pres])
  detectada <- pres & !is.na(d$max_score) & d$max_score >= min_confidence
  teto <- if (peso_pres > 0) sum(d$w[detectada]) / peso_pres else NA_real_
  recall <- vapply(limiares, function(t) {
    if (peso_pres == 0) return(NA_real_)
    sum(d$w[detectada & d$max_score >= t]) / peso_pres
  }, numeric(1))
  share <- vapply(limiares, function(t) {
    pd <- sum(d$w[detectada])
    if (pd == 0) return(NA_real_)
    sum(d$w[detectada & d$max_score >= t]) / pd
  }, numeric(1))
  list(ceiling = teto, recall = recall, share = share)
}

quantile_or_na <- function(x, p) {
  x <- x[!is.na(x)]
  if (length(x) == 0) NA_real_ else
    unname(stats::quantile(x, p, names = FALSE))
}

# Limiares: vetor numerico para todos os grupos, ou tabela por grupo
thresholds_by_group <- function(thresholds, gravacoes, by, coluna) {
  if (is.null(thresholds)) return(NULL)
  if (is.numeric(thresholds)) {
    if (anyNA(thresholds) || any(thresholds < 0 | thresholds > 1)) {
      stop("`thresholds` must be scores between 0 and 1.", call. = FALSE)
    }
    return(sort(unique(thresholds)))
  }
  if (!is.data.frame(thresholds)) {
    stop("`thresholds` must be a numeric vector or a table.", call. = FALSE)
  }
  faltam <- setdiff(c(by, coluna), names(thresholds))
  if (length(faltam) > 0) {
    stop("`thresholds` lacks column(s): ", paste(faltam, collapse = ", "),
         ".", call. = FALSE)
  }
  out <- thresholds |>
    mutate(across(all_of(by), as.character)) |>
    select(all_of(by), threshold = all_of(coluna)) |>
    filter(!is.na(threshold)) |>
    distinct()
  repetidos <- out |> count(across(all_of(by))) |> filter(n > 1)
  if (nrow(repetidos) > 0) {
    stop("`thresholds` has more than one threshold for some group of `by`; ",
         "use the same `by` as the thresholds (e.g. c(\"site\", ",
         "\"species_folder\")).", call. = FALSE)
  }
  out
}

group_thresholds <- function(limiares, chave, by) {
  if (is.numeric(limiares)) return(limiares)
  chave <- mutate(chave, across(everything(), as.character))
  semi_join(limiares, chave, by = by)$threshold
}
