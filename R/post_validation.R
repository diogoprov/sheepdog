#' Classify the reviewed clips
#'
#' Reads the result of the manual review done in the BirdNET GUI and joins
#' it to the clip manifest. The GUI organises the review by moving each
#' clip into subfolders such as `<species>/Positive` and
#' `<species>/Negative`, so the verdict of each clip comes from the path
#' where it is found. Clips still in the species folder are not reviewed.
#'
#' @param manifest Clip manifest: a data frame or the path to
#'   `clip_manifest.csv`. Manifests written by v1.2.0
#'   (`manifesto_clipes.csv`) are also read.
#' @param review_dir Folder with the reviewed clips (the `clips` folder of
#'   the validation package, after the review).
#' @param positive_pattern,negative_pattern Regular expressions
#'   (case-insensitive) that identify the positive and negative folders in
#'   the path of each clip.
#'
#' @return The manifest with two more columns: `verdict` (`"positive"`,
#'   `"negative"`, `"not_reviewed"` or `"clip_missing"`) and
#'   `reviewed_path`, the path where the clip was found. This is the table
#'   written to `validation_by_clip.csv`.
#' @export
classify_review <- function(manifest, review_dir,
                            positive_pattern = "positiv",
                            negative_pattern = "negativ") {
  manifesto <- read_manifest(manifest)

  wavs <- list.files(review_dir, pattern = "\\.wav$",
                     recursive = TRUE, full.names = TRUE)
  if (length(wavs) == 0) stop("No .wav found in ", review_dir)

  # o veredito vem so das subpastas abaixo de review_dir (no Windows o
  # dirname() troca \\ por /, entao as barras sao igualadas antes)
  raiz <- chartr("\\", "/", review_dir)
  revisao <- tibble(reviewed_path = wavs) |>
    mutate(
      clip_file = basename(reviewed_path),
      subpasta  = str_remove(chartr("\\", "/", dirname(reviewed_path)),
                             fixed(raiz)),
      verdict   = case_when(
        str_detect(subpasta, regex(positive_pattern, ignore_case = TRUE)) ~ "positive",
        str_detect(subpasta, regex(negative_pattern, ignore_case = TRUE)) ~ "negative",
        .default = "not_reviewed"
      )
    )

  resultado <- manifesto |>
    left_join(select(revisao, clip_file, verdict, reviewed_path),
              by = "clip_file") |>
    mutate(verdict = replace_na(verdict, "clip_missing")) |>
    fill_inherited()

  contagem <- count(resultado, verdict)
  message("Clips in the manifest: ", nrow(manifesto), "\n",
          paste0("  ", contagem$verdict, ": ", contagem$n, collapse = "\n"))
  if (any(duplicated(revisao$clip_file))) {
    warning("There are duplicated clip names in the review folder - check ",
            "for copies in more than one subfolder.")
  }
  resultado
}

# Le o manifesto (data frame ou csv), aceitando o formato da v1.2.0
read_manifest <- function(manifest) {
  if (is.character(manifest)) {
    manifest <- read_csv(manifest, show_col_types = FALSE)
  }
  manifesto <- from_legacy(manifest)
  # manifestos antigos nao tem a coluna 'night'
  if (!"night" %in% names(manifesto)) {
    manifesto$night <- manifesto$recording_date
  }
  # no modo "random_recordings" a coluna vem toda NA (lida como logica)
  if (!"confidence" %in% names(manifesto)) manifesto$confidence <- NA_real_
  manifesto$confidence <- as.numeric(manifesto$confidence)
  manifesto
}

# Clipes com veredito positivo/negativo e com confidence: gravacoes
# inteiras (modo "random_recordings") ficam fora da precisao e dos
# thresholds
reviewed_with_confidence <- function(validation) {
  filter(validation, verdict %in% c("positive", "negative"),
         !is.na(confidence))
}

# A tabela tem inclusion_prob (clipes de "random_detections")?
has_inclusion_prob <- function(validation) {
  "inclusion_prob" %in% names(validation) &&
    any(!is.na(validation$inclusion_prob))
}

# Precisao ponderada por 1 / inclusion_prob (estimador de razao); NA quando
# algum clipe do grupo nao tem a probabilidade (clipes de "top")
weighted_precision <- function(verdict, prob) {
  prob <- as.numeric(prob)
  if (anyNA(prob)) return(NA_real_)
  w <- 1 / prob
  sum(w[verdict == "positive"]) / sum(w)
}

# Tamanho efetivo da amostra de Kish, com pesos 1 / inclusion_prob
kish_n <- function(prob) {
  w <- 1 / as.numeric(prob)
  sum(w)^2 / sum(w^2)
}

#' Precision by confidence bin
#'
#' Precision (share of positive verdicts) of the reviewed clips, by site,
#' species and confidence bin. Clips without confidence (whole recordings
#' of `"random_recordings"`) are left out.
#'
#' When `validation` has `inclusion_prob` (clips drawn with
#' `"random_detections"` in [select_clips()]), the table also gets
#' `precision_weighted`, the precision weighted by `1 / inclusion_prob`.
#' It estimates the precision among all the predictions of the bin from
#' which the clips were drawn, not only among the reviewed ones; the two
#' differ when the clips of a bin come from strata drawn with different
#' probabilities. It is `NA` in bins with any clip without
#' `inclusion_prob` (clips of `"top"`). A blind review manifest may lack
#' `inclusion_prob`: join it back from the full manifest first.
#'
#' @param validation Table returned by [classify_review()].
#' @param bins Breaks of the confidence bins (left-closed).
#' @param min_n Minimum of reviewed clips for a bin to be taken seriously;
#'   bins with fewer are flagged in `low_support`.
#' @param by Optional columns of `validation` that split each site x
#'   species cell further, e.g. the bin of an environmental gradient or of
#'   an acoustic index joined from [covariate_bins()]. They show which
#'   parts of the gradient lack reviewed clips.
#'
#' @return A tibble with `site`, `species_folder`, the `by` columns, `bin`,
#'   `n_reviewed`, `n_positive`, `precision`, `precision_weighted` (only
#'   with `inclusion_prob`) and `low_support`.
#' @export
precision_by_bin <- function(validation, bins = seq(0.1, 1, by = 0.1),
                             min_n = 15, by = NULL) {
  check_by(validation, by)
  dados <- reviewed_with_confidence(validation)
  pesos <- has_inclusion_prob(dados)
  if (!pesos) dados$inclusion_prob <- NA_real_
  out <- dados |>
    mutate(bin = cut(confidence, breaks = bins,
                     include.lowest = TRUE, right = FALSE)) |>
    group_by(site, species_folder, across(all_of(by)), bin) |>
    summarise(n_reviewed = n(),
              n_positive = sum(verdict == "positive"),
              precision  = n_positive / n_reviewed,
              precision_weighted = weighted_precision(verdict,
                                                      inclusion_prob),
              .groups = "drop") |>
    mutate(low_support = n_reviewed < min_n)
  if (!pesos) out$precision_weighted <- NULL
  out
}

#' Suggest a confidence threshold per species
#'
#' For each site and species (and each level of the `by` columns), the
#' lowest confidence `c` such that the
#' precision among the reviewed clips with confidence >= `c` reaches
#' `target_precision`, with at least `min_n` clips. Candidate cuts are the
#' observed confidences rounded to two decimals.
#'
#' **Sustained target.** With `sustained = TRUE`, the target must also hold
#' at every higher cut with at least `min_n` clips, the rule of
#' [calibrated_thresholds()]. This is not the default: the curve of the model
#' is smooth, while the empirical precision of a high cut rests on few clips,
#' so a cut can fail by chance, and the failure of the highest supported cut
#' leaves the cell without a threshold. In a simulation with 300 clips per
#' cell, the share of cells without a threshold rose from 0.09 to 0.24, and
#' the true precision of the cuts from 0.888 to 0.896
#' (`dev/sustained-threshold-rule.R`).
#'
#' The precision is computed from the reviewed clips of each cell alone, so
#' it is reliable only when the clips were drawn at random within the cell
#' and are numerous. [calibrated_thresholds()] derives the thresholds from
#' the calibration model of stage 2 instead.
#'
#' **Design weights.** Clips of `"random_detections"` have unequal
#' `inclusion_prob`: quiet strata are reviewed almost in full and choruses
#' lightly. The plain share of positive clips then estimates the precision
#' of the reviewed sample, not that of the predictions kept by the cut. So,
#' by default, a cell whose clips all have `inclusion_prob` is judged by the
#' precision weighted by `1 / inclusion_prob`, as in [precision_by_bin()],
#' and `min_n` applies to Kish's effective sample size,
#' \eqn{(\sum w)^2 / \sum w^2}, so that a cut resting on a few heavily
#' weighted clips is not accepted. With equal inclusion probabilities, both
#' choices give the same threshold. The weights cost variance: when
#' precision does not vary between strata, the unweighted estimate is also
#' unbiased and less variable (`weighted = FALSE`).
#'
#' A cell that mixes clips with and without `inclusion_prob` (`"top"` and
#' `"random_detections"`, say) cannot be weighted: it gets the unweighted
#' precision, with a warning, since `"top"` clips are not a probability
#' sample and should not set thresholds.
#'
#' @inheritParams precision_by_bin
#' @param target_precision Target precision.
#' @param weighted Which precision chooses the cut. `NULL` (default): the
#'   weighted one in the cells whose clips all have `inclusion_prob`, the
#'   unweighted one elsewhere. `TRUE`: always the weighted one; cells with
#'   clips without `inclusion_prob` get no threshold, with a warning, and
#'   it is an error if no clip has it. `FALSE`: always the unweighted one,
#'   and `n_support` for `min_n`.
#' @param sustained Must the target also hold at every higher cut with at
#'   least `min_n` clips? See Sustained target.
#'
#' @return A tibble with `site`, `species_folder`, the `by` columns,
#'   `threshold`, `n_support`, `precision_at_threshold` (unweighted; `NA`
#'   when no cut reaches the target). With `inclusion_prob`, also
#'   `precision_weighted_at_threshold`, `n_eff` (Kish's effective sample
#'   size at the threshold) and `precision_used` (`"weighted"` or
#'   `"unweighted"`, the precision that chose the cut). Without any
#'   reviewed clip with a confidence, the tibble has no rows.
#' @seealso [calibrated_thresholds()] for thresholds from the calibration
#'   model.
#' @export
suggest_thresholds <- function(validation, target_precision = 0.90,
                               min_n = 15, by = NULL, weighted = NULL,
                               sustained = FALSE) {
  check_by(validation, by)
  if (!is.null(weighted) && !(isTRUE(weighted) || isFALSE(weighted))) {
    stop("`weighted` must be NULL, TRUE or FALSE.", call. = FALSE)
  }
  validados <- reviewed_with_confidence(validation)
  warn_uncombined(validados)
  pesos <- has_inclusion_prob(validados)
  if (isTRUE(weighted) && nrow(validados) > 0 && !pesos) {
    stop("`weighted = TRUE` needs `inclusion_prob`, which no reviewed clip ",
         "has.", call. = FALSE)
  }
  # sem clipes com confidence, group_modify() criaria uma linha toda NA
  # (era o que a v1.2.0 escrevia)
  if (nrow(validados) == 0) {
    vazio <- tibble(site = character(), species_folder = character())
    for (col in by) vazio[[col]] <- validation[[col]][0]
    return(bind_cols(vazio,
                     tibble(threshold = numeric(), n_support = integer(),
                            precision_at_threshold = numeric())))
  }
  celulas <- group_by(validados, site, species_folder, across(all_of(by)))
  if (pesos && !isFALSE(weighted)) {
    mistas <- celulas |>
      summarise(mista = anyNA(inclusion_prob) && !all(is.na(inclusion_prob)),
                .groups = "drop") |>
      pull(mista) |>
      sum()
    if (mistas > 0) {
      warning(mistas, " cell(s) mix clips with and without `inclusion_prob` ",
              "(\"top\" clips?), which are not a probability sample and ",
              "should not set thresholds; ",
              if (isTRUE(weighted)) "they get no threshold."
              else "they use the unweighted precision.", call. = FALSE)
    }
  }
  celulas |>
    group_modify(~ threshold_for(.x, target_precision, min_n, pesos,
                                 weighted, sustained)) |>
    ungroup()
}

#' Review support of each cell: is more validation worth it?
#'
#' For each site x species cell (and each level of the `by` columns, such as
#' the bin of an environmental gradient or of an acoustic index), counts the
#' reviewed clips at high scores, their precision, and the high-score
#' detections of the selection tables that were not reviewed, and labels the
#' cell:
#'
#' * `"reached"`: [suggest_thresholds()] found a threshold that reaches
#'   `target_precision` with at least `min_n` clips;
#' * `"exhausted"`: fewer than `min_n` high-score detections are left to
#'   review, so more effort cannot add support;
#' * `"unreliable"`: precision at high scores is below `min_precision`, so
#'   more review would only confirm it (retrain the classifier instead);
#' * `"review more"`: high-score detections remain and precision there is
#'   intermediate, so a further round of review may reach a threshold;
#' * `"not reviewed"`: the cell has detections but no reviewed clip.
#'
#' The cut-offs (`conf_high`, `min_n`, `min_precision`) are illustrative
#' defaults: set them from the precision the study needs. Splitting cells by
#' `by` lowers the number of clips per cell, so more cells fall short of
#' `min_n`; compare with the reading without `by`. These labels interpret
#' counts; they are not a statistical test.
#'
#' @param validation Reviewed clips, as for [precision_by_bin()] (the
#'   `validation_by_clip.csv` tables).
#' @param detections Predictions, as returned by [read_selection_tables()].
#' @param conf_high Score from which a prediction counts as high.
#' @param min_n Minimum number of clips, as in [suggest_thresholds()], and
#'   of unreviewed high-score detections for `"review more"`.
#' @param min_precision Precision at high scores below which a cell is
#'   `"unreliable"`.
#' @param target_precision Target precision of [suggest_thresholds()].
#' @param weighted Passed to [suggest_thresholds()], so that `"reached"`
#'   follows the same rule. `prec_high` stays unweighted.
#' @param by Optional columns that split each cell, e.g. `"temp_bin"`.
#'   They must be columns of `covariates` (joined to both tables) or of
#'   both tables.
#' @param covariates Optional table of occasion covariates, such as the
#'   output of [covariate_bins()], joined to the clips and to the
#'   predictions by the columns it shares with them among `site`, `night`,
#'   `recording_date`, `recording_hour`, `source_audio` and `occasion_id`,
#'   as in [select_clips()].
#' @inheritParams select_clips
#'
#' @return A tibble with `site`, `species_folder`, the `by` columns,
#'   `n_reviewed`, `n_fp` (false positives among them), `n_high`
#'   (reviewed clips with score >= `conf_high`), `prec_high` (their
#'   precision), `n_high_all` (predictions with score >= `conf_high`),
#'   `unreviewed_high`, `threshold` and `diagnosis`, ordered by diagnosis.
#'   With a table of [combine_rounds()], also `n_rounds` and
#'   `reached_last_round`: the cell has a threshold now but had none before
#'   its last round.
#' @seealso `vignette("validation-effort")`.
#' @export
review_support <- function(validation, detections, conf_high = 0.7,
                           min_n = 15, min_precision = 0.5,
                           target_precision = 0.90, by = NULL,
                           covariates = NULL,
                           occasion_unit = c("file", "minute"),
                           remap_from = NULL, remap_to = NULL,
                           weighted = NULL) {
  unidade <- match.arg(occasion_unit)
  faltam <- setdiff(c("site", "species_code", "confidence", "begin_path",
                      "file_offset"), names(detections))
  if (length(faltam) > 0) {
    stop("`detections` lacks column(s): ", paste(faltam, collapse = ", "),
         ". Read it with read_selection_tables().", call. = FALSE)
  }
  # as predicoes ganham as colunas de identificacao das ocasioes, como no
  # select_clips()
  det <- detections |>
    mutate(site = as.character(site),
           species_folder = folder_name(species_code),
           source_audio = remap_path(begin_path, remap_from, remap_to),
           occasion_id = make_occasion_id(source_audio, file_offset, unidade))
  det <- bind_cols(det, parse_date_hour(basename(det$begin_path))) |>
    mutate(night = recording_date)
  val <- reviewed_with_confidence(validation) |>
    mutate(site = as.character(site))
  if (!is.null(covariates)) {
    val <- join_covariates(val, covariates, character())
    det <- join_covariates(det, covariates, character())
  }
  check_by(val, by)
  check_by(det, by)
  for (col in by) {
    sem <- sum(is.na(det[[col]]))
    if (sem > 0) {
      warning(sem, " prediction(s) without a value of `", col, "`; they ",
              "form a group of their own.", call. = FALSE)
    }
  }
  # as colunas de `by` com o mesmo tipo nas duas tabelas
  for (col in by) {
    val[[col]] <- as.character(val[[col]])
    det[[col]] <- as.character(det[[col]])
  }
  celula <- c("site", "species_folder", by)

  revisados <- val |>
    group_by(across(all_of(celula))) |>
    summarise(n_reviewed = n(),
              n_fp = sum(verdict == "negative"),
              n_high = sum(confidence >= conf_high),
              prec_high = if (n_high > 0) {
                mean(verdict[confidence >= conf_high] == "positive")
              } else NA_real_,
              .groups = "drop")
  todas <- det |>
    group_by(across(all_of(celula))) |>
    summarise(n_high_all = sum(confidence >= conf_high), .groups = "drop")
  limiares <- suggest_thresholds(val, target_precision = target_precision,
                                 min_n = min_n, by = by,
                                 weighted = weighted) |>
    select(all_of(celula), threshold)
  rodadas <- rounds_by_cell(val, celula, target_precision, min_n, by, weighted)

  saida <- full_join(revisados, todas, by = celula) |>
    left_join(limiares, by = celula) |>
    mutate(
      n_reviewed = replace_na(n_reviewed, 0L),
      n_fp = replace_na(n_fp, 0L),
      n_high = replace_na(n_high, 0L),
      n_high_all = replace_na(n_high_all, 0L),
      unreviewed_high = pmax(n_high_all - n_high, 0L),
      diagnosis = case_when(
        n_reviewed == 0                                  ~ "not reviewed",
        !is.na(threshold)                                ~ "reached",
        unreviewed_high < min_n                          ~ "exhausted",
        !is.na(prec_high) & prec_high < min_precision    ~ "unreliable",
        .default = "review more"
      )) |>
    select(all_of(celula), n_reviewed, n_fp, n_high, prec_high, n_high_all,
           unreviewed_high, threshold, diagnosis) |>
    arrange(diagnosis, species_folder, site, across(all_of(by)))
  if (is.null(rodadas)) return(saida)
  saida <- left_join(saida, rodadas, by = celula) |>
    mutate(reached_last_round = diagnosis == "reached" & !replace_na(.antes, FALSE) &
             replace_na(n_rounds, 1L) > 1L) |>
    select(-.antes)
  if (any(saida$reached_last_round)) {
    message(sum(saida$reached_last_round), " cell(s) reached the target only ",
            "in their last round: their precision tends to be too high if ",
            "that is why the rounds stopped.")
  }
  saida
}

# Rodadas por celula e se ela ja tinha limiar antes da ultima rodada; NULL
# para tabelas sem combine_rounds()
rounds_by_cell <- function(val, celula, target_precision, min_n, by, weighted) {
  if (!"n_rounds" %in% names(val)) return(NULL)
  val <- filter(val, !is.na(n_rounds))
  por_celula <- val |>
    group_by(across(all_of(celula))) |>
    summarise(n_rounds = n_distinct(round), .groups = "drop")
  antes <- before_last_round(val)
  if (nrow(antes) == 0) return(mutate(por_celula, .antes = FALSE))
  limiar <- suggest_thresholds(antes, target_precision = target_precision,
                               min_n = min_n, by = by, weighted = weighted) |>
    transmute(across(all_of(celula)), .antes = !is.na(threshold))
  left_join(por_celula, limiar, by = celula)
}

# Colunas extras de agrupamento (argumento `by`)
check_by <- function(dados, by) {
  if (is.null(by)) return(invisible())
  if (!is.character(by) || anyNA(by)) {
    stop("`by` must be a character vector of column names.", call. = FALSE)
  }
  faltam <- setdiff(by, names(dados))
  if (length(faltam) > 0) {
    stop("Column(s) of `by` not in the table: ",
         paste(faltam, collapse = ", "), call. = FALSE)
  }
  invisible()
}

# Menor corte c tal que a precisao entre os clipes com confidence >= c
# atinge o alvo. Com pesos, a precisao e o apoio da decisao sao os
# ponderados nas celulas em que todo clipe tem inclusion_prob
threshold_for <- function(df, alvo, n_min, pesos = FALSE, weighted = NULL,
                          sustained = FALSE) {
  cortes <- sort(unique(round(df$confidence, 2)))
  out <- tibble(threshold = NA_real_, n_support = NA_integer_,
                precision_at_threshold = NA_real_)
  if (pesos) {
    out$precision_weighted_at_threshold <- NA_real_
    out$n_eff <- NA_real_
    out$precision_used <- NA_character_
  }
  completa <- pesos && !anyNA(df$inclusion_prob)
  if (isTRUE(weighted) && !completa) return(out)
  ponderar <- completa && !isFALSE(weighted)
  cortes <- cortes[vapply(cortes, \(c0) any(df$confidence >= c0), TRUE)]
  medida <- function(c0) {
    sub <- filter(df, confidence >= c0)
    if (ponderar) {
      c(weighted_precision(sub$verdict, sub$inclusion_prob),
        kish_n(sub$inclusion_prob))
    } else {
      c(mean(sub$verdict == "positive"), nrow(sub))
    }
  }
  medidas <- vapply(cortes, medida, numeric(2))
  # o alvo vale neste corte e em todos os cortes acima com apoio, como em
  # calibrated_thresholds(); cortes com menos de min_n clipes nao contam
  apoiados <- which(medidas[2, ] >= n_min)
  ruins <- apoiados[medidas[1, apoiados] < alvo]
  validos <- apoiados[medidas[1, apoiados] >= alvo]
  if (sustained && length(ruins) > 0) validos <- validos[validos > max(ruins)]
  if (length(validos) == 0) return(out)

  c0 <- cortes[validos[1]]
  sub <- filter(df, confidence >= c0)
  out$threshold <- c0
  out$n_support <- nrow(sub)
  out$precision_at_threshold <- mean(sub$verdict == "positive")
  if (pesos) {
    out$precision_weighted_at_threshold <-
      weighted_precision(sub$verdict, sub$inclusion_prob)
    out$n_eff <- if (anyNA(sub$inclusion_prob)) {
      NA_real_
    } else {
      kish_n(sub$inclusion_prob)
    }
    out$precision_used <- if (ponderar) "weighted" else "unweighted"
  }
  out
}

#' Confirmed presence by night
#'
#' Summarises the verdicts by site, species and night. A night is
#' `"confirmed"` when at least one clip is positive,
#' `"not_detected_in_reviewed"` when clips were reviewed but none was
#' positive, and `"not_reviewed"` otherwise.
#'
#' @inheritParams precision_by_bin
#'
#' @return A tibble with `site`, `species_folder`, `night`, `n_clips`,
#'   `n_reviewed`, `n_positive`, `presence` and `max_confidence_positive`.
#' @export
nightly_presence <- function(validation) {
  validation |>
    group_by(site, species_folder, night) |>
    summarise(
      n_clips    = n(),
      n_reviewed = sum(verdict %in% c("positive", "negative")),
      n_positive = sum(verdict == "positive"),
      presence   = case_when(
        n_positive > 0 ~ "confirmed",
        n_reviewed > 0 ~ "not_detected_in_reviewed",
        .default       = "not_reviewed"
      ),
      max_confidence_positive = ifelse(
        n_positive > 0, max(confidence[verdict == "positive"]), NA_real_),
      .groups = "drop"
    )
}

#' Positive clips for retraining
#'
#' Lists the clips confirmed as positive, ready to retrain the classifier.
#'
#' @inheritParams precision_by_bin
#'
#' @return A tibble with `site`, `species_code`, `species_folder`,
#'   `clip_file`, `reviewed_path`, `confidence`, `night`, `recording_hour`
#'   and `source_audio`.
#' @export
retraining_clips <- function(validation) {
  validation[!is_inherited(validation), ] |>
    filter(verdict == "positive") |>
    select(site, species_code, species_folder, clip_file, reviewed_path,
           confidence, night, recording_hour, source_audio)
}

#' Plot the precision curves
#'
#' One panel per species: precision by confidence bin, with the target
#' precision as a dashed line and bins with low support shown faded. With
#' more than one site, each site is a line of its own colour.
#' Needs the 'ggplot2' package.
#'
#' @param precision Table returned by [precision_by_bin()].
#' @inheritParams precision_by_bin
#' @inheritParams suggest_thresholds
#'
#' @return A ggplot object.
#' @export
plot_precision <- function(precision, bins = seq(0.1, 1, by = 0.1),
                           target_precision = 0.90, min_n = 15) {
  require_suggested("ggplot2", "to plot the precision curves")
  # com varios locais, uma linha por local (antes as linhas de locais
  # diferentes eram ligadas no mesmo painel)
  varios_locais <- n_distinct(precision$site) > 1
  linha <- if (varios_locais) {
    list(ggplot2::geom_line(ggplot2::aes(colour = site, group = site)),
         ggplot2::geom_point(ggplot2::aes(size = n_reviewed,
                                          alpha = !low_support,
                                          colour = site)))
  } else {
    list(ggplot2::geom_line(colour = "#2a7fbf"),
         ggplot2::geom_point(ggplot2::aes(size = n_reviewed,
                                          alpha = !low_support),
                             colour = "#2a7fbf"))
  }
  precision |>
    mutate(conf_meio = bins[as.integer(bin)] + 0.05) |>
    ggplot2::ggplot(ggplot2::aes(conf_meio, precision)) +
    ggplot2::geom_hline(yintercept = target_precision,
                        linetype = "dashed", colour = "grey50") +
    linha +
    ggplot2::scale_alpha_manual(values = c(`TRUE` = 1, `FALSE` = 0.3),
                                guide = "none") +
    ggplot2::scale_size_continuous(name = "reviewed clips") +
    ggplot2::scale_x_continuous(limits = c(0.1, 1),
                                breaks = seq(0.1, 1, 0.2)) +
    ggplot2::scale_y_continuous(limits = c(0, 1)) +
    ggplot2::facet_wrap(~ species_folder) +
    ggplot2::labs(x = "Confidence (bin centre)", y = "Precision",
                  title = "Precision of the predictions by confidence bin",
                  subtitle = paste0("Dashed line: target precision (",
                                    target_precision, "); faded points: < ",
                                    min_n, " clips in the bin")) +
    ggplot2::theme_minimal(base_size = 11)
}

#' Summarise the manual validation
#'
#' Runs the whole post-validation step: reads the verdicts of the reviewed
#' clips and writes, to `output_dir`:
#' * `validation_by_clip.csv`: manifest + verdict of each clip
#'   ([classify_review()] for a review in the BirdNET GUI, [app_verdicts()]
#'   for a review in [run_app()]);
#' * `precision_by_bin.csv`: precision by species x confidence bin
#'   ([precision_by_bin()]);
#' * `suggested_thresholds.csv`: lowest confidence reaching the target
#'   precision, by species ([suggest_thresholds()]);
#' * `nightly_presence.csv`: confirmed presence by site x species x night
#'   ([nightly_presence()]);
#' * `retraining_clips.csv`: positive clips for retraining
#'   ([retraining_clips()]);
#' * `thresholds_compared.csv`: empirical and model thresholds, with `fit`
#'   ([compare_thresholds()]);
#' * `precision_by_bin.png`: precision curves ([plot_precision()]), when
#'   'ggplot2' is installed.
#'
#' The verdicts come from the folders of a review in the BirdNET GUI
#' (`review_dir`) or from the verdicts file of [run_app()]
#' (`verdicts_file`). In the second case, a clip marked more than once
#' keeps the last verdict of each reviewer, and clips reviewed by more than
#' one reviewer are combined with [consensus_verdicts()]: conflicting
#' verdicts become `"disagreement"` and, like `"uncertain"`, are left out of
#' the precision and the thresholds.
#'
#' With `inclusion_prob` in the manifest (clips of `"random_detections"`),
#' the precision tables also give the precision weighted by
#' `1 / inclusion_prob` (see [precision_by_bin()]), and that precision
#' chooses the thresholds, unless `weighted = FALSE`; see
#' [suggest_thresholds()].
#'
#' This is the function form of the v1.2.0 script `pos_validacao.R`.
#'
#' @inheritParams classify_review
#' @param review_dir Folder with the reviewed clips. For a review in the
#'   BirdNET GUI, the `clips` folder after the review, whose subfolders
#'   give the verdicts. With `verdicts_file`, optional: the folder of the
#'   clips, used to fill `reviewed_path` (needed by [retraining_clips()]
#'   and [build_training_set()]).
#' @inheritParams precision_by_bin
#' @inheritParams suggest_thresholds
#' @param manifest_path Path to the manifest of the same run as the
#'   reviewed clips (`clip_manifest.csv`, or a v1.2.0
#'   `manifesto_clipes.csv`).
#' @param output_dir Output folder; created if needed.
#' @param verdicts_file Optional verdicts file written by [run_app()], used
#'   instead of the subfolders of `review_dir`.
#' @param reviewer With `verdicts_file`, optional reviewer(s) whose
#'   verdicts are used, as in [app_verdicts()].
#' @param weighted,sustained Passed to [suggest_thresholds()].
#' @param fit Optional model of [fit_calibration()]. With it,
#'   [compare_thresholds()] writes `thresholds_compared.csv`.
#' @param scored,quality With `fit`, passed to [compare_thresholds()].
#' @param previous For a later round of a design: the
#'   `validation_by_clip.csv` of the earlier rounds. `validation_by_clip.csv`
#'   keeps the clips of this round only; the summaries and
#'   `validation_combined.csv` cover all rounds, from [combine_rounds()].
#' @param candidates With `previous`, the `candidates.csv` of the first
#'   round. `NULL` looks for it beside `manifest_path` and `previous`.
#'
#' @return A list with the tables `validation`, `precision`, `thresholds`,
#'   `presence` and `retraining` (and `compared`, with `fit`), invisibly.
#' @export
post_validation <- function(review_dir = NULL, manifest_path, output_dir,
                            positive_pattern = "positiv",
                            negative_pattern = "negativ",
                            bins = seq(0.1, 1, by = 0.1),
                            target_precision = 0.90,
                            min_n = 15, verdicts_file = NULL,
                            reviewer = NULL, weighted = NULL,
                            previous = NULL, candidates = NULL, fit = NULL,
                            scored = NULL, quality = NULL, sustained = FALSE) {
  if (is.null(verdicts_file)) {
    if (is.null(review_dir)) {
      stop("Give `review_dir` (review in the BirdNET GUI) or ",
           "`verdicts_file` (review in run_app()).", call. = FALSE)
    }
    resultado <- classify_review(manifest_path, review_dir,
                                 positive_pattern, negative_pattern)
  } else {
    resultado <- app_verdicts(manifest_path, verdicts_file,
                              clips_dir = review_dir, reviewer = reviewer)
    if (anyDuplicated(resultado[c("species_folder", "clip_file")])) {
      message("Clips reviewed by more than one reviewer are combined with ",
              "consensus_verdicts().")
      resultado <- consensus_verdicts(resultado)
    }
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  write_csv(resultado, file.path(output_dir, "validation_by_clip.csv"))
  if (!is.null(previous)) {
    if (is.null(candidates)) {
      candidates <- read_candidates(NULL, c(manifest_path, previous))
    }
    # sem a coluna `round`, esta rodada vem depois das anteriores
    resultado <- combine_rounds(c(as.list(previous), list(resultado)),
                                candidates)
    write_csv(resultado, file.path(output_dir, "validation_combined.csv"))
    message("Rounds combined: ", n_distinct(resultado$round),
            "; see validation_combined.csv")
  }

  validados <- filter(resultado, verdict %in% c("positive", "negative"))
  if (nrow(validados) == 0) {
    stop("No clip with a positive/negative verdict - was the review ",
         "done? ", if (is.null(verdicts_file)) {
           "Check positive_pattern/negative_pattern."
         } else {
           "Check `verdicts_file` and `reviewer`."
         }, call. = FALSE)
  }
  if (has_inclusion_prob(reviewed_with_confidence(resultado))) {
    message("The manifest has inclusion_prob: the precision tables also ",
            "give the precision weighted by 1 / inclusion_prob.")
  }
  sem_conf <- sum(is.na(validados$confidence))
  if (sem_conf > 0) {
    message(sem_conf, " reviewed clip(s) without confidence (drawn ",
            "recordings) left out of the precision by bin and the ",
            "thresholds.")
  }

  precisao <- precision_by_bin(resultado, bins, min_n)
  write_csv(precisao, file.path(output_dir, "precision_by_bin.csv"))

  thresholds <- suggest_thresholds(resultado, target_precision, min_n,
                                   weighted = weighted, sustained = sustained)
  write_csv(thresholds, file.path(output_dir, "suggested_thresholds.csv"))
  message("Suggested thresholds (target precision ", target_precision,
          "): see suggested_thresholds.csv")

  comparados <- NULL
  if (!is.null(fit)) {
    comparados <- compare_thresholds(resultado, fit, scored,
                                     target_precision = target_precision,
                                     min_n = min_n, quality = quality,
                                     weighted = weighted,
                                     sustained = sustained)
    write_csv(comparados, file.path(output_dir, "thresholds_compared.csv"))
    message("Empirical and model thresholds: see thresholds_compared.csv")
  }

  presenca <- nightly_presence(resultado)
  write_csv(presenca, file.path(output_dir, "nightly_presence.csv"))

  retreino <- retraining_clips(resultado)
  write_csv(retreino, file.path(output_dir, "retraining_clips.csv"))
  message(nrow(retreino), " positive clips listed for retraining.")

  if (nrow(precisao) > 0) {
    if (requireNamespace("ggplot2", quietly = TRUE)) {
      g <- plot_precision(precisao, bins, target_precision, min_n)
      ggplot2::ggsave(file.path(output_dir, "precision_by_bin.png"), g,
                      width = 11, height = 8, dpi = 200)
    } else {
      message("Package 'ggplot2' not installed: precision_by_bin.png ",
              "was not drawn.")
    }
  }

  message("Done! Results in ", output_dir)
  invisible(c(list(validation = resultado, precision = precisao,
                   thresholds = thresholds, presence = presenca,
                   retraining = retreino),
              if (!is.null(comparados)) list(compared = comparados)))
}
