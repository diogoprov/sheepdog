#' Warning signs of a threshold, by species
#'
#' Gathers, for each species, the warning signs that the detections left
#' after a threshold are not a reliable input for an ecological model, and
#' gives a verdict. The signs follow the threshold workflow (Larissa S. M.
#' Sugai, ACAD pilot); this function computes those that a review sample
#' can show:
#'
#' | sign | what it says | from |
#' |---|---|---|
#' | 1 | low recall ceiling: in many occasions with the species, the classifier gave it no score at all | `recall`, the output of [recall_ceiling()] (needs `"random_recordings"` occasions annotated by ear) |
#' | 2 | the threshold discards most true positives | the reviewed clips: share of the positive clips at or above the threshold, weighted by `1 / inclusion_prob` |
#' | 6 | false positives vary by site or season | the reviewed clips: range of the false-positive rate among the levels of each `groups` column; the most frequent identity of the negative clips, when `validation` has `identity` |
#' | 7 | the threshold is not stable across groups | [threshold_by_group()] for each `groups` column |
#' | 8 | the logistic curve is wrong near the threshold | `curves`, the output of [compare_calibration_curves()] |
#'
#' Signs 3, 4 and 5 (occupied sites lost, detected days that do not track
#' the true activity, false negatives that vary by site) need site-days
#' whose true activity is known, that is recordings annotated in full, and
#' are not computed here. A sign whose input is missing is `NA`, not
#' `FALSE`: it was not checked.
#'
#' **Verdict.** A heuristic summary, not a test:
#'
#' - `"not_trustworthy"`: the species has no threshold (no score reaches
#'   the target), no calibration curve reaches the target (sign 8), or three
#'   or more signs are raised;
#' - `"use_with_caveats"`: one or two signs are raised;
#' - `"trustworthy_with_care"`: every sign checked is clear. The signs not
#'   checked (`n_checked` < 5) and signs 3 to 5 may still be raised;
#' - `"not_assessed"`: no sign could be checked.
#'
#' **Which clips.** Signs 2 and 6 are rates of the predictions, so they use
#' the clips with an inclusion probability (`"random_detections"`,
#' `"score_bands"`, `"directed_pps"`), weighted by `1 / inclusion_prob`.
#' Without any such clip they use every reviewed clip, unweighted, with a
#' message: clips of `"top"` are not a random sample, and the rates are
#' then only indicative.
#'
#' @param validation Reviewed clips, as for [suggest_thresholds()].
#' @param thresholds The threshold of each species or cell: a single
#'   number, or a table with `species_folder` (and optionally `site`) and a
#'   `threshold` column, such as the output of [suggest_thresholds()]
#'   (`threshold_column` picks another column, such as
#'   `"threshold_conservative"` of [threshold_bootstrap()]).
#' @param groups Columns of `validation` for signs 6 and 7, such as
#'   `"site"` or a month column. `NULL` uses `"site"` when there is more
#'   than one site.
#' @param curves Optional output of [compare_calibration_curves()] (sign
#'   8). With curves fitted by site, the worst verdict of the species
#'   counts.
#' @param recall Optional output of [recall_ceiling()] (sign 1). With a
#'   ceiling per site, the lowest counts.
#' @param target_precision Target precision of the threshold (sign 7).
#' @param min_n Minimum number of clips of a group for it to count in signs
#'   6 and 7.
#' @param min_tp_kept Sign 2 is raised when the share of the true positives
#'   kept by the threshold is below this.
#' @param max_fp_spread Sign 6 is raised when the false-positive rate of
#'   two levels of a group differs by more than this.
#' @param min_ceiling Sign 1 is raised when the recall ceiling is below
#'   this.
#' @param threshold_column Column of `thresholds` with the threshold.
#' @param file Optional path of a Markdown file to write the report to.
#'
#' @return A tibble with one row per species: `species_folder`,
#'   `threshold` (the median over its cells), `sign1_ceiling`,
#'   `sign1`, `sign2_tp_kept`, `sign2`, `sign6_fp_spread`, `sign6`,
#'   `sign6_detail`, `sign7_share_below`, `sign7`, `sign7_detail`,
#'   `sign8_verdict`, `sign8`, `n_checked`, `n_raised` and `verdict`. The
#'   `signN` columns are `TRUE` (raised), `FALSE` (clear) or `NA` (not
#'   checked).
#' @seealso [recall_ceiling()], [compare_calibration_curves()],
#'   [threshold_by_group()], [threshold_record()], [confuser_summary()].
#' @export
#' @examples
#' \dontrun{
#' thr <- suggest_thresholds(val, target_precision = 0.95, sustained = TRUE)
#' warning_signs(val, thr, groups = c("site", "month"),
#'               curves = compare_calibration_curves(val),
#'               recall = recall_ceiling(rr, det, thresholds = thr,
#'                                       by = c("site", "species_folder")),
#'               file = "warning_signs.md")
#' }
warning_signs <- function(validation, thresholds, groups = NULL,
                          curves = NULL, recall = NULL,
                          target_precision = 0.95, min_n = 15,
                          min_tp_kept = 0.25, max_fp_spread = 0.3,
                          min_ceiling = 0.5, threshold_column = "threshold",
                          file = NULL) {
  validados <- reviewed_with_confidence(validation)
  if (nrow(validados) == 0) {
    stop("No reviewed clip with a confidence in `validation`.",
         call. = FALSE)
  }
  validados <- mutate(validados, site = as.character(site))
  if (is.null(groups) && length(unique(validados$site)) > 1) {
    groups <- "site"
  }
  check_by(validados, groups)
  celulas <- cell_thresholds(thresholds, validados, threshold_column)
  especies <- sort(unique(validados$species_folder))

  # amostra probabilistica para as taxas (sinais 2 e 6)
  com_p <- if ("inclusion_prob" %in% names(validados)) {
    !is.na(validados$inclusion_prob)
  } else {
    rep(FALSE, nrow(validados))
  }
  if (any(com_p)) {
    amostra <- validados[com_p, ]
    amostra$w <- 1 / as.numeric(amostra$inclusion_prob)
  } else {
    message("No reviewed clip has `inclusion_prob`: signs 2 and 6 use every ",
            "clip, unweighted, and are only indicative.")
    amostra <- validados
    amostra$w <- 1
  }
  amostra <- left_join(amostra, celulas, by = c("site", "species_folder"))

  sinal2 <- amostra |>
    filter(verdict == "positive") |>
    group_by(species_folder) |>
    summarise(sign2_tp_kept = if (all(is.na(.limiar))) NA_real_ else
                sum(w[!is.na(.limiar) & confidence >= .limiar]) /
                sum(w[!is.na(.limiar)]),
              .groups = "drop") |>
    mutate(sign2 = sign2_tp_kept < min_tp_kept)

  sinal6 <- fp_spread(amostra, groups, min_n, max_fp_spread)
  if ("identity" %in% names(validados)) {
    confusos <- validados |>
      filter(verdict == "negative", !is.na(identity), identity != "") |>
      count(species_folder, identity, sort = TRUE) |>
      group_by(species_folder) |>
      slice(1) |>
      ungroup() |>
      transmute(species_folder,
                .confuser = paste0("main confuser: ", identity, " (", n,
                                   " clips)"))
    sinal6 <- full_join(sinal6, confusos, by = "species_folder") |>
      mutate(sign6_detail = case_when(
        is.na(.confuser) ~ sign6_detail,
        is.na(sign6_detail) ~ .confuser,
        .default = paste0(sign6_detail, "; ", .confuser))) |>
      select(-".confuser")
  }

  sinal7 <- group_stability(validados, celulas, groups, target_precision,
                            min_n)
  sinal8 <- curve_signs(curves)
  sinal1 <- ceiling_signs(recall, min_ceiling)

  limiar_especie <- celulas |>
    group_by(species_folder) |>
    summarise(threshold = if (all(is.na(.limiar))) NA_real_ else
                stats::median(.limiar, na.rm = TRUE), .groups = "drop")
  saida <- tibble(species_folder = especies) |>
    left_join(limiar_especie, by = "species_folder") |>
    left_join(sinal1, by = "species_folder") |>
    left_join(sinal2, by = "species_folder") |>
    left_join(sinal6, by = "species_folder") |>
    left_join(sinal7, by = "species_folder") |>
    left_join(sinal8, by = "species_folder")
  for (col in c("sign1_ceiling", "sign2_tp_kept", "sign6_fp_spread",
                "sign7_share_below")) {
    if (!col %in% names(saida)) saida[[col]] <- NA_real_
  }
  for (col in c("sign1", "sign2", "sign6", "sign7", "sign8")) {
    if (!col %in% names(saida)) saida[[col]] <- NA
  }
  for (col in c("sign6_detail", "sign7_detail", "sign8_verdict")) {
    if (!col %in% names(saida)) saida[[col]] <- NA_character_
  }
  sinais <- as.matrix(saida[c("sign1", "sign2", "sign6", "sign7", "sign8")])
  saida$n_checked <- rowSums(!is.na(sinais))
  saida$n_raised <- rowSums(matrix(sinais %in% TRUE, nrow = nrow(sinais)))
  saida$verdict <- case_when(
    saida$n_checked == 0 ~ "not_assessed",
    is.na(saida$threshold) |
      saida$sign8_verdict %in% "no_curve_reaches_target" |
      saida$n_raised >= 3 ~ "not_trustworthy",
    saida$n_raised >= 1 ~ "use_with_caveats",
    .default = "trustworthy_with_care")
  saida <- select(saida, species_folder, threshold, sign1_ceiling, sign1,
                  sign2_tp_kept, sign2, sign6_fp_spread, sign6, sign6_detail,
                  sign7_share_below, sign7, sign7_detail, sign8_verdict,
                  sign8, n_checked, n_raised, verdict)
  if (!is.null(file)) write_warning_signs(saida, file)
  saida
}

# Limiar de cada local x especie: numero unico ou tabela por especie (e
# local); uma tabela so por especie vale para todos os locais
cell_thresholds <- function(thresholds, validados, coluna) {
  celulas <- distinct(validados, site, species_folder)
  if (is.numeric(thresholds) && length(thresholds) == 1) {
    return(mutate(celulas, .limiar = thresholds))
  }
  if (!is.data.frame(thresholds)) {
    stop("`thresholds` must be a single number or a table.", call. = FALSE)
  }
  faltam <- setdiff(c("species_folder", coluna), names(thresholds))
  if (length(faltam) > 0) {
    stop("`thresholds` lacks the column(s): ", paste(faltam, collapse = ", "),
         call. = FALSE)
  }
  chave <- intersect(c("site", "species_folder"), names(thresholds))
  tab <- thresholds |>
    mutate(across(all_of(chave), as.character)) |>
    group_by(across(all_of(chave))) |>
    summarise(.limiar = first(.data[[coluna]]), .groups = "drop")
  left_join(celulas, tab, by = chave)
}

# Sinal 6: amplitude da taxa de falso positivo entre niveis de cada grupo
fp_spread <- function(amostra, groups, min_n, max_spread) {
  if (length(groups) == 0) return(tibble(species_folder = character()))
  por_grupo <- lapply(groups, function(g) {
    amostra |>
      filter(!is.na(.data[[g]])) |>
      group_by(species_folder, nivel = as.character(.data[[g]])) |>
      summarise(n = n(), fp = sum(w[verdict == "negative"]) / sum(w),
                .groups = "drop") |>
      filter(n >= min_n) |>
      group_by(species_folder) |>
      filter(n() >= 2) |>
      summarise(spread = max(fp) - min(fp),
                detail = sprintf("%s: FP rate %.2f (%s) to %.2f (%s)", g,
                                 min(fp), nivel[which.min(fp)], max(fp),
                                 nivel[which.max(fp)]),
                .groups = "drop")
  })
  bind_rows(por_grupo) |>
    group_by(species_folder) |>
    summarise(sign6_fp_spread = max(spread),
              sign6_detail = paste(detail, collapse = "; "),
              .groups = "drop") |>
    mutate(sign6 = sign6_fp_spread > max_spread)
}

# Sinal 7: grupos em que o limiar da celula fica abaixo do alvo
group_stability <- function(validados, celulas, groups, alvo, min_n) {
  if (length(groups) == 0) return(tibble(species_folder = character()))
  tab <- filter(celulas, !is.na(.limiar)) |>
    rename(threshold = .limiar)
  if (nrow(tab) == 0) return(tibble(species_folder = character()))
  por_grupo <- lapply(groups, function(g) {
    if (identical(g, "site")) {
      # o limiar ja e por local: a pergunta e se cada local atinge o alvo
      d <- validados |>
        inner_join(tab, by = c("site", "species_folder")) |>
        filter(confidence >= threshold)
      pesos <- has_inclusion_prob(d) && !anyNA(d$inclusion_prob)
      d |>
        group_by(species_folder, nivel = site) |>
        summarise(n_above = n(),
                  precision_above = if (pesos) {
                    weighted_precision(verdict, inclusion_prob)
                  } else {
                    mean(verdict == "positive")
                  }, .groups = "drop") |>
        mutate(below_target = if_else(n_above >= min_n,
                                      precision_above < alvo, NA),
               grupo = g)
    } else {
      threshold_by_group(validados, tab, by = g, target_precision = alvo,
                         min_n = min_n) |>
        mutate(nivel = paste(site, .data[[g]], sep = " / "), grupo = g)
    }
  })
  bind_rows(lapply(por_grupo, \(d) select(d, species_folder, grupo, nivel,
                                         precision_above, below_target))) |>
    filter(!is.na(below_target)) |>
    group_by(species_folder) |>
    summarise(sign7_share_below = mean(below_target),
              sign7_detail = if (any(below_target)) paste0(
                "below target: ",
                paste(sprintf("%s %s (%.2f)", grupo[below_target],
                              nivel[below_target],
                              precision_above[below_target]),
                      collapse = ", ")) else NA_character_,
              .groups = "drop") |>
    mutate(sign7 = sign7_share_below > 0)
}

# Sinal 8: veredito de compare_calibration_curves() (o pior da especie)
curve_signs <- function(curves) {
  if (is.null(curves)) return(tibble(species_folder = character()))
  if (!all(c("species_folder", "verdict") %in% names(curves))) {
    stop("`curves` must be the output of compare_calibration_curves(), ",
         "with species_folder among its `by` columns.", call. = FALSE)
  }
  ordem <- c("no_curve_reaches_target", "use_monotone_or_weighted",
             "sample_more_near_threshold", "too_few_clips", "keep_logistic")
  curves |>
    distinct(across(any_of(c("site", "species_folder"))), verdict) |>
    group_by(species_folder) |>
    summarise(sign8_verdict = ordem[min(match(verdict, ordem))],
              .groups = "drop") |>
    mutate(sign8 = case_when(
      sign8_verdict %in% c("no_curve_reaches_target",
                           "use_monotone_or_weighted") ~ TRUE,
      sign8_verdict == "keep_logistic" ~ FALSE,
      .default = NA))
}

# Sinal 1: teto de recall de recall_ceiling() (o menor da especie)
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

write_warning_signs <- function(saida, file) {
  fmt <- function(x) {
    if (is.numeric(x)) format(round(x, 2), trim = TRUE) else
      ifelse(is.na(x), "", as.character(x))
  }
  tab <- as.data.frame(lapply(saida, fmt))
  linhas <- c("# Warning signs of the thresholds", "",
              paste0("Written by sheepdog ",
                     utils::packageVersion("sheepdog"), " on ",
                     format(Sys.Date()), ". Signs 3 to 5 need recordings ",
                     "annotated in full and are not checked; an empty sign ",
                     "was not checked."), "",
              paste0("| ", paste(names(tab), collapse = " | "), " |"),
              paste0("|", paste(rep("---", ncol(tab)), collapse = "|"), "|"),
              apply(tab, 1, \(r) paste0("| ", paste(r, collapse = " | "),
                                        " |")))
  writeLines(linhas, file)
  message("Warning signs written to ", file)
  invisible(file)
}
