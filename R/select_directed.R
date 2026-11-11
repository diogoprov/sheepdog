#' Directed review round: units drawn with probability proportional to size
#'
#' Draws a review round aimed at the units where a review is worth most,
#' while keeping a known inclusion probability for every clip. A unit is a
#' group of occasions, such as site x month x species. Each unit gets a
#' size, typically the expected gain of one review predicted by an
#' occupancy model; `n_units` units are drawn with probability
#' proportional to size (PPS), one occasion is drawn at random within each
#' drawn unit, and every prediction of that occasion at or above
#' `threshold` becomes a clip, as in `sampling_mode = "random_detections"`
#' of [select_clips()].
#'
#' @param detections Predictions, as returned by [read_selection_tables()].
#' @param units Data frame with one row per eligible unit: the columns
#'   that define the unit (any columns of the prepared predictions, such as
#'   `site`, `species_code` and `month`) and the size column. Only listed
#'   units are drawn, so leave out the units that need no review, for
#'   instance those where a review has already confirmed the species.
#' @param n_units Number of units to draw.
#' @param threshold Confidence threshold: an occasion is a candidate when
#'   it has at least one prediction at or above it, and its clips are all
#'   such predictions. Use the threshold of the occupancy analysis.
#' @param size_col Column of `units` with the size (non-negative).
#' @param floor Share of the mean size added to every size, so that a unit
#'   with size 0 can still be drawn. Without it, a unit the model judges
#'   worthless is never reviewed and the model is never corrected there.
#' @param previous Manifests of earlier review rounds (of any design), as
#'   paths or data frames. Their clips are left out, matched by recording
#'   file and start: an occasion is a candidate only while it has a
#'   prediction at or above `threshold` not yet reviewed.
#' @param seed Seed of the draws. The global random number generator is
#'   left as it was.
#' @inheritParams select_clips
#'
#' @details
#' **Inclusion probabilities.** With sizes \eqn{x_u} (after the floor),
#' the inclusion probability of unit \eqn{u} is
#' \eqn{\pi_u = n x_u / \sum x}, and units whose \eqn{\pi_u} would exceed 1
#' are taken with certainty while the others share the rest of `n_units`.
#' The units are drawn by systematic PPS
#' sampling in a random order, which gives exactly these \eqn{\pi_u}. The
#' occasion is then drawn among the \eqn{N_u} candidate occasions of the
#' unit, so each clip has `inclusion_prob` \eqn{= \pi_u / N_u}. The round is
#' conditional on the earlier rounds: `inclusion_prob` is the probability
#' of this round, given what was reviewed before.
#'
#' **What the weights support.** Weighted by `1 / inclusion_prob`, the clips
#' of the round estimate totals and ratios (such as the precision) of the
#' candidate predictions of the listed units (Horvitz and Thompson 1952,
#' \doi{10.1080/01621459.1952.10483446}). Systematic PPS has no simple
#' joint inclusion probability, so the exact design variance is not
#' available; approximations that treat the draw as with replacement are
#' usually conservative. The units were chosen by a model, so the round is
#' not a sample of all predictions: an occupancy model that reads it needs
#' the inclusion probabilities, which [export_occupancy_data()] writes.
#'
#' A unit without candidate occasions (all reviewed, or no prediction at or
#' above `threshold`) is dropped with a message before the draw.
#'
#' @return The manifest of the round, with the columns of [select_clips()],
#'   `sampling_mode = "directed_pps"`, `n_candidates`
#'   (\eqn{N_u}), `n_drawn = 1` and, at the end, `stratum` (the unit, its
#'   values joined by `|`). The attribute `"units"` holds the units
#'   with their size, `size_used` (after the floor), `n_occasions`,
#'   `inclusion_prob_unit` and `drawn`, for the record of the round; save it
#'   next to the manifest.
#' @seealso [select_clips()], [cut_clips()], [export_occupancy_data()].
#' @export
#' @examples
#' \dontrun{
#' pred <- read_selection_tables("N:/Arara")
#' units <- readr::read_csv("expected_gain.csv") # site, month, species_code, size
#' sel <- select_directed(pred, units, n_units = 40, threshold = 0.5,
#'                        previous = "validation_r1/clip_manifest.csv")
#' man <- cut_clips(sel, "validation_directed")
#' readr::write_csv(man, "validation_directed/clip_manifest.csv")
#' readr::write_csv(attr(sel, "units"), "validation_directed/units.csv")
#' }
select_directed <- function(detections, units, n_units, threshold,
                            size_col = "size", floor = 0.05,
                            occasion_unit = c("file", "minute"),
                            previous = NULL, seed = 2026,
                            remap_from = NULL, remap_to = NULL) {
  unidade <- match.arg(occasion_unit)
  if (!is.data.frame(units)) stop("`units` must be a data frame.", call. = FALSE)
  if (!size_col %in% names(units)) {
    stop("`units` lacks the size column `", size_col, "`.", call. = FALSE)
  }
  chave <- setdiff(names(units), size_col)
  if (length(chave) == 0) {
    stop("`units` needs at least one column besides `", size_col,
         "` to define the unit.", call. = FALSE)
  }
  tamanho <- units[[size_col]]
  if (!is.numeric(tamanho) || anyNA(tamanho) || any(tamanho < 0)) {
    stop("`", size_col, "` must be numeric, non-negative and without NA.",
         call. = FALSE)
  }
  if (anyDuplicated(units[chave])) {
    stop("`units` has more than one row for some unit.", call. = FALSE)
  }
  if (length(n_units) != 1 || is.na(n_units) || n_units < 1 ||
      n_units != round(n_units)) {
    stop("`n_units` must be a positive whole number.", call. = FALSE)
  }
  if (!is.numeric(threshold) || length(threshold) != 1 || is.na(threshold)) {
    stop("`threshold` must be one number.", call. = FALSE)
  }
  if (!is.numeric(floor) || length(floor) != 1 || is.na(floor) || floor < 0) {
    stop("`floor` must be a non-negative number.", call. = FALSE)
  }

  pred <- detections |>
    mutate(source_audio = remap_path(begin_path, remap_from, remap_to),
           duration     = end_time - begin_time,
           clip_start   = file_offset,
           clip_end     = file_offset + duration,
           occasion_id  = make_occasion_id(source_audio, file_offset, unidade))
  pred <- bind_cols(pred, parse_date_hour(basename(pred$begin_path))) |>
    mutate(night = recording_date, site = as.character(site)) |>
    add_period_columns(intersect(c("month", "week"), chave))
  faltam <- setdiff(chave, names(pred))
  if (length(faltam) > 0) {
    stop("Column(s) of `units` not in the predictions: ",
         paste(faltam, collapse = ", "), call. = FALSE)
  }
  units <- mutate(units, across(all_of(chave), as.character))
  pred <- mutate(pred, across(all_of(chave), as.character))

  acima <- filter(pred, confidence >= threshold)
  n_det_ocasiao <- count(acima, site, species_code, occasion_id,
                         name = "n_detections_occasion")
  rodada <- 1L
  if (!is.null(previous)) {
    anteriores <- read_previous(previous)
    dirigidas <- filter(anteriores, sampling_mode == "directed_pps")
    if (nrow(dirigidas) > 0) rodada <- max(dirigidas$round) + 1L
    faltam <- setdiff(c("source_audio", "clip_start"), names(anteriores))
    if (length(faltam) > 0) {
      stop("Earlier rounds without column(s): ",
           paste(faltam, collapse = ", "), ".", call. = FALSE)
    }
    # o clipe e casado pelo arquivo e pelo inicio, que nao dependem da
    # unidade de ocasiao nem do remapeamento dos caminhos de cada rodada
    vistos <- transmute(anteriores, site, species_code,
                        .arquivo = audio_stem(source_audio),
                        .inicio = round(as.numeric(clip_start), 3))
    antes <- nrow(acima)
    acima <- acima |>
      mutate(.arquivo = audio_stem(source_audio),
             .inicio = round(clip_start, 3)) |>
      anti_join(vistos, by = c("site", "species_code", ".arquivo",
                               ".inicio")) |>
      select(-.arquivo, -.inicio)
    message(antes - nrow(acima), " prediction(s) >= ", threshold,
            " already reviewed in `previous` left out.")
  }

  # Ocasioes candidatas de cada unidade
  ocasioes <- acima |>
    distinct(across(all_of(unique(c(chave, ocasiao_chave))))) |>
    semi_join(units, by = chave)
  if (anyDuplicated(ocasioes[ocasiao_chave])) {
    stop("The columns of `units` must be constant within an occasion; ",
         "some occasions fall in more than one unit.", call. = FALSE)
  }
  n_ocasioes <- count(ocasioes, across(all_of(chave)), name = "n_occasions")
  tab <- units |>
    left_join(n_ocasioes, by = chave) |>
    mutate(n_occasions = replace_na(n_occasions, 0L))
  vazias <- tab$n_occasions == 0
  if (any(vazias)) {
    message(sum(vazias), " unit(s) without candidate occasions left out.")
  }
  tab$size_used <- tab[[size_col]] + floor * mean(tab[[size_col]])
  tab$inclusion_prob_unit <- 0
  tab$drawn <- FALSE
  elegiveis <- which(!vazias & tab$size_used > 0)
  if (length(elegiveis) == 0) {
    stop("No unit with candidate occasions and size > 0.", call. = FALSE)
  }
  n <- min(n_units, length(elegiveis))
  if (n < n_units) {
    message("Only ", n, " unit(s) can be drawn; all of them are taken.")
  }
  pis <- pps_inclusion(tab$size_used[elegiveis], n)
  tab$inclusion_prob_unit[elegiveis] <- pis

  sorteio <- withr::with_seed(seed, {
    sel <- elegiveis[systematic_pps(pis)]
    alvo <- tab[sel, c(chave, "n_occasions", "inclusion_prob_unit")]
    escolhidas <- ocasioes |>
      inner_join(alvo, by = chave) |>
      group_by(across(all_of(chave))) |>
      slice_sample(n = 1) |>
      ungroup()
    list(sel = sel, escolhidas = escolhidas)
  })
  tab$drawn[sorteio$sel] <- TRUE

  rotulo <- do.call(paste, c(unname(as.list(sorteio$escolhidas[chave])),
                             sep = "|"))
  escolhidas <- sorteio$escolhidas |>
    transmute(across(all_of(ocasiao_chave)),
              inclusion_prob = inclusion_prob_unit / n_occasions,
              stratum = rotulo, n_candidates = as.integer(n_occasions),
              n_drawn = 1L)
  selecao <- acima |>
    select(-any_of(c("stratum", "n_candidates", "n_drawn"))) |>
    inner_join(escolhidas, by = ocasiao_chave) |>
    group_by(across(all_of(ocasiao_chave))) |>
    arrange(file_offset, .by_group = TRUE) |>
    mutate(rank = row_number()) |>
    ungroup() |>
    left_join(n_det_ocasiao, by = ocasiao_chave) |>
    mutate(species_folder = folder_name(species_code),
           clip_file = clip_name(confidence, rank, source_audio, clip_start,
                                 clip_end),
           sampling_mode = "directed_pps", round = rodada,
           inclusion_prob_round = inclusion_prob,
           previously_reviewed = FALSE, inherited_verdict = NA_character_,
           source_design = NA_character_)
  message(nrow(selecao), " clips from ", length(sorteio$sel), " unit(s) ",
          "drawn of ", length(elegiveis), " (round ", rodada, ").")
  if (all(pis == 1)) {
    message("Every eligible unit was taken (inclusion_prob_unit = 1): this ",
            "is a census of the units.")
  }
  saida <- select(selecao,
                  all_of(manifest_columns[manifest_columns != "status"]),
                  stratum)
  attr(saida, "units") <- tab |>
    relocate(all_of(chave)) |>
    arrange(desc(drawn), desc(inclusion_prob_unit))
  saida
}

# Nome do arquivo de audio sem pasta nem extensao (aceita caminhos do
# Windows)
audio_stem <- function(caminho) {
  tools::file_path_sans_ext(basename(gsub("\\\\", "/", caminho)))
}

# Probabilidades de inclusao proporcionais ao tamanho para n fixo: as
# unidades com n * x / soma(x) >= 1 entram com certeza e o resto de n e
# repartido entre as demais, ate nenhuma passar de 1
pps_inclusion <- function(x, n) {
  p <- numeric(length(x))
  fixa <- rep(FALSE, length(x))
  repeat {
    p[!fixa] <- (n - sum(fixa)) * x[!fixa] / sum(x[!fixa])
    novas <- !fixa & p >= 1
    if (!any(novas)) break
    fixa[novas] <- TRUE
    p[novas] <- 1
  }
  p
}

# Amostragem sistematica PPS em ordem aleatoria: um ponto inicial uniforme
# e passos de 1 sobre as probabilidades acumuladas. Devolve os indices
# sorteados; cada unidade entra com a sua probabilidade
systematic_pps <- function(p) {
  n <- round(sum(p))
  ordem <- sample.int(length(p))
  acumulada <- cumsum(p[ordem])
  pontos <- stats::runif(1) + 0:(n - 1)
  pos <- findInterval(pontos, acumulada, left.open = TRUE) + 1L
  ordem[pmin(pos, length(p))]
}
