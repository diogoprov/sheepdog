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
    mutate(verdict = replace_na(verdict, "clip_missing"))

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

#' Precision by confidence bin
#'
#' Precision (share of positive verdicts) of the reviewed clips, by site,
#' species and confidence bin. Clips without confidence (whole recordings
#' of `"random_recordings"`) are left out.
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
#'   `n_reviewed`, `n_positive`, `precision` and `low_support`.
#' @export
precision_by_bin <- function(validation, bins = seq(0.1, 1, by = 0.1),
                             min_n = 15, by = NULL) {
  check_by(validation, by)
  reviewed_with_confidence(validation) |>
    mutate(bin = cut(confidence, breaks = bins,
                     include.lowest = TRUE, right = FALSE)) |>
    group_by(site, species_folder, across(all_of(by)), bin) |>
    summarise(n_reviewed = n(),
              n_positive = sum(verdict == "positive"),
              precision  = n_positive / n_reviewed,
              .groups = "drop") |>
    mutate(low_support = n_reviewed < min_n)
}

#' Suggest a confidence threshold per species
#'
#' For each site and species (and each level of the `by` columns), the
#' lowest confidence `c` such that the
#' precision among the reviewed clips with confidence >= `c` reaches
#' `target_precision`, with at least `min_n` clips. Candidate cuts are the
#' observed confidences rounded to two decimals.
#'
#' @inheritParams precision_by_bin
#' @param target_precision Target precision.
#'
#' @return A tibble with `site`, `species_folder`, the `by` columns,
#'   `threshold`, `n_support` and `precision_at_threshold` (`NA` when no
#'   cut reaches the target). Without any reviewed clip with a confidence,
#'   the tibble has no rows.
#' @export
suggest_thresholds <- function(validation, target_precision = 0.90,
                               min_n = 15, by = NULL) {
  check_by(validation, by)
  validados <- reviewed_with_confidence(validation)
  # sem clipes com confidence, group_modify() criaria uma linha toda NA
  # (era o que a v1.2.0 escrevia)
  if (nrow(validados) == 0) {
    vazio <- tibble(site = character(), species_folder = character())
    for (col in by) vazio[[col]] <- validation[[col]][0]
    return(bind_cols(vazio,
                     tibble(threshold = numeric(), n_support = integer(),
                            precision_at_threshold = numeric())))
  }
  validados |>
    group_by(site, species_folder, across(all_of(by))) |>
    group_modify(~ threshold_for(.x, target_precision, min_n)) |>
    ungroup()
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
# atinge o alvo
threshold_for <- function(df, alvo, n_min) {
  cortes <- sort(unique(round(df$confidence, 2)))
  for (c0 in cortes) {
    sub <- filter(df, confidence >= c0)
    if (nrow(sub) >= n_min &&
        mean(sub$verdict == "positive") >= alvo) {
      return(tibble(threshold = c0,
                    n_support = nrow(sub),
                    precision_at_threshold = mean(sub$verdict == "positive")))
    }
  }
  tibble(threshold = NA_real_, n_support = NA_integer_,
         precision_at_threshold = NA_real_)
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
  validation |>
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
#' Runs the whole post-validation step: classifies the reviewed clips and
#' writes, to `output_dir`:
#' * `validation_by_clip.csv`: manifest + verdict of each clip
#'   ([classify_review()]);
#' * `precision_by_bin.csv`: precision by species x confidence bin
#'   ([precision_by_bin()]);
#' * `suggested_thresholds.csv`: lowest confidence reaching the target
#'   precision, by species ([suggest_thresholds()]);
#' * `nightly_presence.csv`: confirmed presence by site x species x night
#'   ([nightly_presence()]);
#' * `retraining_clips.csv`: positive clips for retraining
#'   ([retraining_clips()]);
#' * `precision_by_bin.png`: precision curves ([plot_precision()]), when
#'   'ggplot2' is installed.
#'
#' This is the function form of the v1.2.0 script `pos_validacao.R`.
#'
#' @inheritParams classify_review
#' @inheritParams precision_by_bin
#' @inheritParams suggest_thresholds
#' @param manifest_path Path to the manifest of the same run as the
#'   reviewed clips (`clip_manifest.csv`, or a v1.2.0
#'   `manifesto_clipes.csv`).
#' @param output_dir Output folder; created if needed.
#'
#' @return A list with the tables `validation`, `precision`, `thresholds`,
#'   `presence` and `retraining`, invisibly.
#' @export
post_validation <- function(review_dir, manifest_path, output_dir,
                            positive_pattern = "positiv",
                            negative_pattern = "negativ",
                            bins = seq(0.1, 1, by = 0.1),
                            target_precision = 0.90,
                            min_n = 15) {
  resultado <- classify_review(manifest_path, review_dir,
                               positive_pattern, negative_pattern)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  write_csv(resultado, file.path(output_dir, "validation_by_clip.csv"))

  validados <- filter(resultado, verdict %in% c("positive", "negative"))
  if (nrow(validados) == 0) {
    stop("No clip with a positive/negative verdict - was the review ",
         "done? Check positive_pattern/negative_pattern.")
  }
  sem_conf <- sum(is.na(validados$confidence))
  if (sem_conf > 0) {
    message(sem_conf, " reviewed clip(s) without confidence (drawn ",
            "recordings) left out of the precision by bin and the ",
            "thresholds.")
  }

  precisao <- precision_by_bin(resultado, bins, min_n)
  write_csv(precisao, file.path(output_dir, "precision_by_bin.csv"))

  thresholds <- suggest_thresholds(resultado, target_precision, min_n)
  write_csv(thresholds, file.path(output_dir, "suggested_thresholds.csv"))
  message("Suggested thresholds (target precision ", target_precision,
          "): see suggested_thresholds.csv")

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
  invisible(list(validation = resultado, precision = precisao,
                 thresholds = thresholds, presence = presenca,
                 retraining = retreino))
}
