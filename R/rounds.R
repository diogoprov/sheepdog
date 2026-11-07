# Rodadas de revisao de um mesmo desenho (#107): lista de candidatas fixa,
# sorteio entre as ocasioes ainda nao sorteadas e probabilidade acumulada

ocasiao_chave <- c("site", "species_code", "occasion_id")

# Empilha rodadas anteriores: caminhos, data frame ou lista dos dois. Sem a
# coluna `round`, cada entrada conta como uma rodada, na ordem dada
read_previous <- function(previous) {
  entradas <- if (is.data.frame(previous)) list(previous) else as.list(previous)
  tabs <- map(seq_along(entradas), function(i) {
    x <- entradas[[i]]
    if (is.character(x) && !file.exists(x)) {
      stop("Not found: ", x, call. = FALSE)
    }
    tab <- read_manifest(x)
    faltam <- setdiff(c(ocasiao_chave, "sampling_mode"), names(tab))
    if (length(faltam) > 0) {
      stop("Earlier round without column(s): ",
           paste(faltam, collapse = ", "), ".", call. = FALSE)
    }
    if (!"round" %in% names(tab)) tab$round <- i
    tab$.entrada <- i
    mutate(tab, across(any_of(c("site", "occasion_id", "night",
                                "recording_date", "recording_hour")),
                       as.character),
           round = as.integer(round))
  })
  list_rbind(tabs)
}

# Lista de candidatas de "random_detections": uma linha por ocasiao, com o
# estrato, o N do estrato e o desenho que a gerou
build_candidates <- function(ocasioes, estrato, threshold, unidade, rotulo,
                             limitado) {
  ocasioes |>
    mutate(across(all_of(ocasiao_chave), as.character),
           stratum = do.call(paste, c(across(all_of(estrato)), sep = " | "))) |>
    add_count(stratum, name = "n_candidates") |>
    mutate(threshold = threshold, occasion_unit = unidade, strata = rotulo,
           capped = limitado)
}

# Le a lista de candidatas: `candidates`, ou candidates.csv ao lado de um
# dos arquivos dados. NULL quando nao ha nenhuma
read_candidates <- function(candidates, perto = NULL) {
  if (is.null(candidates)) {
    caminhos <- if (is.data.frame(perto)) character() else
      as.character(unlist(Filter(is.character, as.list(perto))))
    achados <- file.path(unique(dirname(caminhos)), "candidates.csv")
    achados <- achados[file.exists(achados)]
    if (length(achados) == 0) return(NULL)
    candidates <- achados[1]
  }
  if (is.character(candidates)) {
    if (!file.exists(candidates)) {
      stop("Not found: ", candidates, call. = FALSE)
    }
    candidates <- read_csv(candidates, show_col_types = FALSE,
                           col_types = readr::cols(.default = "c"))
  }
  faltam <- setdiff(c(ocasiao_chave, "stratum", "n_candidates"),
                    names(candidates))
  if (length(faltam) > 0) {
    stop("`candidates` lacks column(s): ", paste(faltam, collapse = ", "),
         ". Use the candidates.csv of the first round.", call. = FALSE)
  }
  mutate(candidates, n_candidates = as.integer(n_candidates),
         across(any_of("threshold"), as.numeric),
         across(any_of("capped"), as.logical))
}

# Recusa o que mudaria o desenho entre as rodadas
check_round_design <- function(snap, threshold, unidade, rotulo) {
  iguais <- list(threshold = threshold, occasion_unit = unidade,
                 strata = rotulo)
  for (campo in intersect(names(iguais), names(snap))) {
    antes <- unique(snap[[campo]])
    if (length(antes) != 1 || !isTRUE(all.equal(antes, iguais[[campo]]))) {
      stop("`", campo, "` differs from the earlier rounds (",
           paste(antes, collapse = ", "), "): rounds of a design need the ",
           "same threshold, occasion unit and strata.", call. = FALSE)
    }
  }
  if (isTRUE(any(snap$capped))) {
    stop("The first round used `target_total` or `max_per_species`, a second ",
         "stage that later rounds cannot keep exact.", call. = FALSE)
  }
  invisible()
}

# As rodadas anteriores batem com a lista? Cada clipe guarda a probabilidade
# acumulada da sua rodada; a diferenca indica outro desenho ou um limite
check_round_probs <- function(rodadas, snap) {
  if (!"inclusion_prob" %in% names(rodadas) || "n_rounds" %in% names(rodadas)) {
    return(invisible())
  }
  ocas <- rodadas |>
    filter(!is.na(inclusion_prob)) |>
    distinct(across(all_of(ocasiao_chave)), round, inclusion_prob) |>
    inner_join(distinct(snap, across(all_of(ocasiao_chave)), stratum,
                        n_candidates), by = ocasiao_chave)
  esperado <- ocas |>
    count(stratum, n_candidates, round, name = ".n") |>
    group_by(stratum) |>
    arrange(round, .by_group = TRUE) |>
    mutate(.esperado = cumsum(.n) / n_candidates) |>
    ungroup() |>
    select(stratum, round, .esperado)
  ruins <- ocas |>
    inner_join(esperado, by = c("stratum", "round")) |>
    filter(abs(inclusion_prob - .esperado) > 1e-8)
  if (nrow(ruins) > 0) {
    stop(nrow(ruins), " earlier occasion(s) have an `inclusion_prob` that does ",
         "not match the candidates: the earlier round used another design, ",
         "a cap (`target_total`, `max_per_species`) or other predictions.",
         call. = FALSE)
  }
  invisible()
}

# Avisa se as predicoes de agora nao sao as da lista; a lista prevalece
warn_changed_pool <- function(atual, snap) {
  novas <- nrow(anti_join(atual, snap, by = ocasiao_chave))
  sumiram <- nrow(anti_join(snap, atual, by = ocasiao_chave))
  if (novas + sumiram > 0) {
    warning("The candidate occasions changed since the first round (", novas,
            " new, ", sumiram, " gone). The candidates of the first round are ",
            "kept, so that the inclusion probabilities stay exact; start a ",
            "new design to use the new predictions.", call. = FALSE)
  }
  invisible()
}

# Restringe as ocasioes as celulas pedidas (site x especie)
filter_cells <- function(pool, cells) {
  if (!is.data.frame(cells) || !"site" %in% names(cells) ||
      !any(c("species_folder", "species_code") %in% names(cells))) {
    stop("`cells` must be a data frame with `site` and `species_folder` or ",
         "`species_code`, such as rows of review_support().", call. = FALSE)
  }
  alvo <- mutate(cells, site = as.character(site))
  if (!"species_folder" %in% names(alvo)) {
    alvo$species_folder <- folder_name(alvo$species_code)
  }
  alvo <- distinct(alvo, site, species_folder)
  pool |>
    mutate(species_folder = folder_name(species_code)) |>
    semi_join(alvo, by = c("site", "species_folder")) |>
    select(-species_folder)
}

# Sorteio da rodada: n_top ocasioes por estrato, entre as ainda nao
# sorteadas. A semente muda com a rodada: com a mesma, as posicoes sorteadas
# se repetiriam e a rodada pegaria as vizinhas das ocasioes anteriores
draw_round <- function(snap, rodadas, n_top, seed, rodada, cells) {
  ja <- distinct(rodadas, across(all_of(ocasiao_chave)))
  fora <- nrow(anti_join(ja, snap, by = ocasiao_chave))
  if (fora > 0) {
    stop(fora, " earlier occasion(s) are not among the candidates: these ",
         "are not rounds of the same design.", call. = FALSE)
  }
  anteriores <- snap |>
    semi_join(ja, by = ocasiao_chave) |>
    count(stratum, name = ".n_antes")
  pool <- anti_join(snap, ja, by = ocasiao_chave)
  if (!is.null(cells)) {
    if (nrow(filter_cells(snap, cells)) == 0) {
      stop("No candidate occasion in `cells`.", call. = FALSE)
    }
    pool <- filter_cells(pool, cells)
  }
  sorteadas <- withr::with_seed(seed + rodada - 1L, {
    pool |>
      group_by(stratum) |>
      mutate(.pr = min(n_top, n()) / n()) |>
      slice_sample(n = n_top) |>
      ungroup()
  })
  sorteadas <- sorteadas |>
    left_join(anteriores, by = "stratum") |>
    add_count(stratum, name = ".n_agora") |>
    mutate(n_drawn = replace_na(.n_antes, 0L) + .n_agora,
           .p1 = n_drawn / n_candidates)
  sobra <- anti_join(pool, sorteadas, by = ocasiao_chave)
  esgotados <- n_distinct(pool$stratum) - n_distinct(sobra$stratum)
  message("Round ", rodada, ": ", nrow(sorteadas), " occasions drawn among ",
          nrow(pool), " not drawn yet; ", esgotados, " of ",
          n_distinct(pool$stratum), " strata have no occasion left.")
  sorteadas
}

#' Combine the review rounds of a design
#'
#' Stacks the tables of the rounds of a `"random_detections"` design and
#' gives every clip the inclusion probability of the combined sample. Each
#' round of [select_clips()] draws among the occasions not drawn yet, so the
#' occasions drawn in all rounds are a simple random sample of each stratum,
#' and every clip has the probability `n_drawn / n_candidates`, whatever its
#' round. The value stored in the table of an earlier round is out of date
#' as soon as another round is drawn; this function recomputes it from the
#' candidates and the clips, so no earlier file is edited.
#'
#' The probability is exact for a number of rounds fixed in advance. When
#' the rounds of a cell go on until it reaches a target, the decision to
#' stop depends on the verdicts, and the precision tends to be too high;
#' see `vignette("validation-effort")`.
#'
#' @param validation The tables of all rounds: paths to the
#'   `validation_by_clip.csv` files or manifests, a data frame, or a list of
#'   these. Tables without `round` count as one round each, in the order
#'   given.
#' @param candidates The `candidates.csv` of the first round, as a path or a
#'   data frame. `NULL` looks for it in the folders of `validation`.
#'
#' @return The stacked table, with `stratum`, `n_candidates`, `n_drawn`,
#'   the cumulative `inclusion_prob` and `n_rounds`, the number of rounds
#'   with clips of the site x species. Clips of other sampling modes are
#'   kept as they are, with these columns `NA`.
#' @seealso [select_clips()], [read_validation_tables()].
#' @export
combine_rounds <- function(validation, candidates = NULL) {
  tab <- read_previous(validation)
  snap <- read_candidates(candidates, if (!is.data.frame(validation)) validation)
  if (is.null(snap)) {
    stop("No candidates.csv found: give `candidates`.", call. = FALSE)
  }
  repetidas <- tab |>
    distinct(across(all_of(ocasiao_chave)), round) |>
    count(across(all_of(ocasiao_chave))) |>
    filter(n > 1)
  if (nrow(repetidas) > 0) {
    stop(nrow(repetidas), " occasion(s) are in more than one round. Rounds ",
         "drawn without `previous` are not a single sample.", call. = FALSE)
  }
  mesma_rodada <- tab |>
    filter(sampling_mode == "random_detections") |>
    inner_join(distinct(snap, across(all_of(ocasiao_chave)), .estrato = stratum),
               by = ocasiao_chave) |>
    distinct(.estrato, round, .entrada) |>
    count(.estrato, round) |>
    filter(n > 1)
  if (nrow(mesma_rodada) > 0) {
    stop("Two tables have the same round of a stratum: they were drawn ",
         "without `previous`, so they are not a single sample.", call. = FALSE)
  }
  tab$.entrada <- NULL
  aleatorio <- tab$sampling_mode == "random_detections"
  fora <- tab[aleatorio, ] |>
    anti_join(snap, by = ocasiao_chave) |>
    nrow()
  if (fora > 0) {
    stop(fora, " clip(s) are from occasions outside `candidates`.",
         call. = FALSE)
  }
  tab <- select(tab, -any_of(c("stratum", "n_candidates", "n_drawn",
                               "n_rounds"))) |>
    left_join(distinct(snap, across(all_of(ocasiao_chave)), stratum,
                       n_candidates), by = ocasiao_chave)
  sorteios <- tab |>
    filter(sampling_mode == "random_detections") |>
    distinct(across(all_of(ocasiao_chave)), stratum) |>
    count(stratum, name = "n_drawn")
  rodadas <- tab |>
    filter(sampling_mode == "random_detections") |>
    group_by(site, species_code) |>
    summarise(n_rounds = n_distinct(round), .groups = "drop")
  tab |>
    left_join(sorteios, by = "stratum") |>
    left_join(rodadas, by = c("site", "species_code")) |>
    mutate(inclusion_prob = if_else(sampling_mode == "random_detections",
                                    n_drawn / n_candidates, inclusion_prob))
}

# Tabela com varias rodadas e inclusion_prob de cada rodada?
warn_uncombined <- function(validation) {
  if ("round" %in% names(validation) && !"n_rounds" %in% names(validation) &&
      n_distinct(validation$round, na.rm = TRUE) > 1) {
    warning("The table has several rounds but was not built by ",
            "combine_rounds(): `inclusion_prob` is the one of each round.",
            call. = FALSE)
  }
  invisible()
}

# As mesmas rodadas sem a ultima de cada celula, com a probabilidade
# acumulada de entao (para saber se a celula so atingiu o alvo na ultima)
before_last_round <- function(val) {
  antes <- val |>
    group_by(site, species_folder) |>
    filter(round < max(round)) |>
    ungroup()
  sorteios <- antes |>
    distinct(site, species_code, occasion_id, stratum) |>
    count(stratum, name = ".n_antes")
  antes |>
    left_join(sorteios, by = "stratum") |>
    mutate(inclusion_prob = .n_antes / n_candidates) |>
    select(-.n_antes)
}
