#' Select the clips to validate
#'
#' Applies the sampling design to the predictions read by
#' [read_selection_tables()] and returns the clip manifest: one row per clip
#' to cut, with its site, species, night, source audio, start and end. No
#' audio is read or written; cut the clips with [cut_clips()].
#'
#' @section Sampling modes:
#' * `"top"` keeps the `n_top` predictions with the highest confidence per
#'   site x species x night x hour. It serves classifier retraining and the
#'   score-to-probability calibration of [calibrate()]. Do not use it to
#'   estimate false-positive rates: top-score clips hold fewer false
#'   positives than a random sample.
#' * `"random_detections"` draws, at random, `n_top` occasions per
#'   stratum (by default site x species x night x hour; see `strata`)
#'   among the occasions with at least one
#'   prediction of the species with confidence >= `threshold`, and keeps
#'   every prediction >= `threshold` of each drawn occasion. This is the
#'   observation-confirmation design of Chambert et al. (2015,
#'   \doi{10.1890/14-1507.1}).
#' * `"random_recordings"` draws recordings (or minutes) among all those
#'   recorded, with or without predictions, in proportion to the effort of
#'   each site, for annotation by ear. This is the multiple-method design of
#'   Miller et al. (2011, \doi{10.1890/10-1396.1}). The clip is the whole
#'   recording (or minute), copied once per species to annotate, and
#'   `confidence` is `NA`.
#'
#' In both random modes, use the same `threshold` as the occupancy analysis.
#'
#' @param detections Predictions, as returned by [read_selection_tables()].
#' @param sampling_mode `"top"`, `"random_detections"` or
#'   `"random_recordings"`. See *Sampling modes*.
#' @param occasion_unit The occasion of the occupancy model: `"file"` (the
#'   whole recording) or `"minute"` (minute of the file, from
#'   `file_offset`).
#' @param threshold Confidence threshold of the occupancy analysis. It
#'   defines the candidate occasions of `"random_detections"` and the
#'   `n_detections_occasion` column. `NULL` leaves that column `NA`.
#' @param n_top `"top"`: predictions kept per site x species x night x
#'   hour. `"random_detections"`: occasions drawn per stratum (`strata`).
#' @param strata `"random_detections"`: the strata of the occasion draw
#'   (ignored by the other modes). Either one of the presets, all within
#'   site x species:
#'   * `"night_hour"`: night x hour (the rule of 2.0.0);
#'   * `"night"`: night;
#'   * `"hour"`: hour of the day, pooling the nights (covers the diel
#'     cycle without fixing the night);
#'   * `"week"`: ISO week of the night (`YYYY-Www`);
#'   * `"month"`: month of the night (`YYYY-MM`), which spreads the draw
#'     over the season;
#'   * `"site_species"`: no further stratification;
#'
#'   or a character vector of column names of `detections`, e.g.
#'   `c("site", "species_code", "habitat", "night")`, for strata defined by
#'   the user. Columns can be added to `detections` before the call; since
#'   site and species are always part of the strata, useful columns vary
#'   within a site (the moon phase, the rain of the night, a recorder when
#'   a site has several). `month` and `week` can also be used and are
#'   derived from the night when absent.
#'   `site` and `species_code` are always added to the strata, which keeps
#'   `inclusion_prob` exact when `target_total` or `max_per_species` draw
#'   again within site x species. Columns that depend on the score
#'   (`confidence`, `rank`) are refused, since the observation-confirmation
#'   design needs strata independent of the score, and every stratum
#'   column must be constant within an occasion.
#'
#'   With one recording per hour and `occasion_unit = "file"`,
#'   `"night_hour"` holds a single occasion per stratum and draws nothing
#'   (every `inclusion_prob` is 1); a coarser stratum makes the draw
#'   random. With strata without the hour and `balance_by_hour = TRUE`
#'   under `target_total` or `max_per_species`, `inclusion_prob` is
#'   conditional on the first draw (a warning says so).
#' @param covariates `"random_detections"`: optional data frame of
#'   occasion covariates whose columns can be used in `strata`, such as
#'   the bins of an environmental gradient or of an acoustic index made by
#'   [covariate_bins()]. It is joined to the predictions by the columns it
#'   shares with them among `site`, `night`, `recording_date`,
#'   `recording_hour`, `source_audio` and `occasion_id` (compared as
#'   character; `night` and `recording_date` are `YYYYMMDD`). Occasions
#'   without a match form a stratum of their own, with a warning. A
#'   stratum other than site, species and time may be related to the
#'   verdict, so the calibration should include it or weight the clips by
#'   `inclusion_prob` (a message says so).
#' @param recording_fraction `"random_recordings"`: fraction of the
#'   recordings (or minutes) drawn at each site, rounded, with at least one
#'   per site. The default (1 %) suits large projects: with fewer than 150
#'   recordings per site it draws a single recording; raise it or use
#'   `n_recordings_per_site` in small projects.
#' @param n_recordings_per_site `"random_recordings"`: fixed number of
#'   recordings (or minutes) per site, used instead of `recording_fraction`.
#' @param recordings `"random_recordings"`: the list of all recordings, as a
#'   data frame or the path to a CSV file with the columns `site` and
#'   `source_audio` (the v1.2.0 columns `local` and `caminho_audio` are
#'   also read). `NULL` lists the files matching `audio_pattern` in the
#'   audio folders that appear in `begin_path`; folders without any
#'   prediction are then left out.
#' @param audio_pattern Regular expression for the audio files listed when
#'   `recordings` is `NULL`.
#' @param recording_duration Length of the recordings (s), for
#'   `occasion_unit = "minute"` in `"random_recordings"` and for the end of
#'   whole-recording clips. `NULL` reads each file with the 'av' package
#'   when needed (minute occasions) and leaves `clip_end` as `NA` otherwise.
#' @param min_confidence Minimum confidence of a candidate prediction in
#'   `"top"`. `NULL` applies no filter. The random modes use `threshold`.
#' @param sites Restrict to these sites. `NULL` keeps all.
#' @param date_start,date_end Date window of the recordings (`"YYYYMMDD"`).
#'   `NULL` leaves that side open.
#' @param species Restrict to these short species codes (the last part of
#'   `species_code`, e.g. `"boa-ran"`). `NULL` keeps all.
#' @param hour_start,hour_end Hour window (0-23). It can cross midnight:
#'   `hour_start = 17, hour_end = 2` keeps 17h-23h and 0h-2h, and the
#'   grouping becomes by night (small hours count as the night before).
#'   `NULL` applies no filter.
#' @param alternate_days Keep alternate days (or nights), anchored on the
#'   first date of each site.
#' @param target_total Total clips per site, split evenly among species by
#'   water filling: species with fewer clips than the quota enter whole and
#'   the surplus goes to the others. In `"random_detections"` it counts
#'   occasions. Ignored in `"random_recordings"`. `NULL` sets no target.
#'   Because the target is split evenly, rare species have higher
#'   inclusion probabilities than common ones: estimates pooled across
#'   species must weight the clips by `1 / inclusion_prob`.
#' @param balance_by_hour Within each species, draw round-robin across the
#'   hours of the day (covers the diel cycle) when applying `target_total`
#'   or `max_per_species`.
#' @param max_per_species Simpler alternative to `target_total`: a fixed
#'   limit per site x species. Ignored when `target_total` is set.
#' @param remap_from,remap_to Replace the prefix `remap_from` of the
#'   `begin_path` paths by `remap_to`, e.g. `"N:/"` and `"/Volumes/Arara/"`.
#'   Backslashes are turned into forward slashes first.
#' @param seed Seed of every random draw. The global random number
#'   generator is left as it was.
#'
#' @return A tibble, the clip manifest without `status`, with the columns
#'   `site`, `species_code`, `species_folder`, `recording_date`, `night`,
#'   `recording_hour`, `rank`, `confidence`, `clip_file`, `clip_start`,
#'   `clip_end`, `duration`, `source_audio`, `begin_path`, `sampling_mode`,
#'   `occasion_id`, `n_detections_occasion` and `inclusion_prob`. See
#'   `vignette("crywolf-integration")` for their definitions.
#' @export
select_clips <- function(detections,
                         sampling_mode = c("top", "random_detections",
                                           "random_recordings"),
                         occasion_unit = c("file", "minute"),
                         threshold = NULL,
                         n_top = 2,
                         strata = "night_hour",
                         covariates = NULL,
                         recording_fraction = 0.01,
                         n_recordings_per_site = NULL,
                         recordings = NULL,
                         audio_pattern = "\\.(wav|flac|mp3)$",
                         recording_duration = NULL,
                         min_confidence = 0.1,
                         sites = NULL,
                         date_start = NULL,
                         date_end = NULL,
                         species = NULL,
                         hour_start = NULL,
                         hour_end = NULL,
                         alternate_days = FALSE,
                         target_total = NULL,
                         balance_by_hour = TRUE,
                         max_per_species = NULL,
                         remap_from = NULL,
                         remap_to = NULL,
                         seed = 2026) {
  modo    <- match.arg(sampling_mode)
  estrato1 <- resolve_strata(strata)
  rotulo1  <- paste(estrato1, collapse = " x ")
  unidade <- match.arg(occasion_unit)
  janela  <- list(hour_start = hour_start, hour_end = hour_end,
                  alternate_days = alternate_days,
                  date_start = date_start, date_end = date_end)

  # Piloto: restringir aos locais pedidos
  if (!is.null(sites)) {
    desconhecidos <- setdiff(sites, unique(detections$site))
    if (length(desconhecidos) > 0) {
      warning("Site(s) in `sites` without predictions: ",
              paste(desconhecidos, collapse = ", "))
    }
    detections <- filter(detections, site %in% sites)
    message("Pilot: processing only ",
            paste(intersect(sites, unique(detections$site)), collapse = ", "),
            " (", nrow(detections), " predictions).")
    if (nrow(detections) == 0) {
      stop("No prediction left after the site filter - check `sites`.")
    }
  }

  if (modo == "random_detections" && is.null(threshold)) {
    stop("sampling_mode = \"random_detections\" needs `threshold` ",
         "(the same confidence threshold as the occupancy analysis).")
  }
  message("Sampling mode: ", modo, " (occasion = ", unidade, ").")

  selecao <- detections |>
    mutate(
      source_audio = remap_path(begin_path, remap_from, remap_to),
      duration     = end_time - begin_time,
      clip_start   = file_offset,
      clip_end     = file_offset + duration,
      occasion_id  = make_occasion_id(source_audio, file_offset, unidade)
    )
  selecao <- bind_cols(selecao, parse_date_hour(basename(selecao$begin_path)))

  if (anyNA(selecao$recording_date)) {
    n_na <- sum(is.na(selecao$recording_date))
    warning(n_na, " prediction(s) with a file name without the ",
            "_YYYYMMDD_HHMMSS pattern - grouped with date/hour = NA.")
  }

  # 'night' e a data de agrupamento (muda se a janela cruzar a meia-noite)
  selecao <- mutate(selecao,
                    hour_int = suppressWarnings(as.integer(recording_hour)),
                    night    = recording_date)

  # Lista de TODAS as gravacoes (so no modo "random_recordings")
  if (modo == "random_recordings") {
    gravacoes <- list_recordings(selecao, recordings, audio_pattern,
                                 remap_from, remap_to)
  }

  # Filtro de especies (codigos curtos)
  if (!is.null(species)) {
    antes   <- nrow(selecao)
    selecao <- filter(selecao,
                      str_extract(species_code, "[^_]+$") %in% species)
    message("Filter of ", length(species), " species: ", antes, " -> ",
            nrow(selecao), " predictions.")
    faltantes <- setdiff(species,
                         str_extract(unique(selecao$species_code), "[^_]+$"))
    if (length(faltantes) > 0) {
      warning("Requested species without any prediction: ",
              paste(faltantes, collapse = ", "))
    }
    if (nrow(selecao) == 0) stop("No prediction of the requested species.")
  }

  # Especies a anotar no modo "random_recordings" (antes dos filtros de
  # tempo: a especie entra mesmo sem predicao na janela)
  especies_alvo <- sort(unique(selecao$species_code))

  selecao <- filter_time(selecao, janela, "predictions")

  # Predicoes da especie >= threshold por ocasiao (para conferir que todas
  # as deteccoes de uma ocasiao checada foram cortadas)
  n_det_ocasiao <- if (!is.null(threshold)) {
    selecao |>
      filter(confidence >= threshold) |>
      count(site, species_code, occasion_id, name = "n_detections_occasion")
  }

  if (modo == "top") {
    if (!is.null(min_confidence)) {
      antes   <- nrow(selecao)
      selecao <- filter(selecao, confidence >= min_confidence)
      if (nrow(selecao) < antes) {
        message(antes - nrow(selecao), " predictions dropped by the filter ",
                "confidence < ", min_confidence, ".")
      }
    }

    selecao <- selecao |>
      group_by(site, species_code, night, recording_hour) |>
      arrange(desc(confidence), .by_group = TRUE) |>
      slice_head(n = n_top) |>
      mutate(rank = row_number()) |>
      ungroup() |>
      mutate(
        species_folder = folder_name(species_code),
        clip_file      = clip_name(confidence, rank, source_audio,
                                   clip_start, clip_end),
        # selecao pelo score: nao e uma amostra probabilistica
        inclusion_prob = NA_real_
      )

    message(nrow(selecao), " clips selected (top ", n_top,
            " per site x species x night x hour) of ",
            n_distinct(selecao$species_code), " species.")
  } else if (modo == "random_detections") {
    # Candidatas: ocasioes com >= 1 predicao da especie >= threshold. O
    # sorteio (n_top ocasioes por estrato) nao olha o score.
    deteccoes <- filter(selecao, confidence >= threshold) |>
      add_period_columns(estrato1) |>
      join_covariates(covariates, estrato1)
    faltam <- setdiff(estrato1, names(deteccoes))
    if (length(faltam) > 0) {
      stop("Column(s) of `strata` not in `detections`: ",
           paste(faltam, collapse = ", "), call. = FALSE)
    }
    chave <- unique(c("site", "species_code", "occasion_id",
                      "recording_date", "night", "recording_hour", estrato1))
    ocasioes <- distinct(deteccoes, across(all_of(chave)))
    if (anyDuplicated(ocasioes[c("site", "species_code", "occasion_id")])) {
      stop("The `strata` columns must be constant within an occasion; ",
           "some occasions fall in more than one stratum.", call. = FALSE)
    }
    selecao <- withr::with_seed(seed, {
      ocasioes |>
        group_by(across(all_of(estrato1))) |>
        mutate(.p1 = min(n_top, n()) / n()) |>
        slice_sample(n = n_top) |>
        ungroup()
    })
    message(nrow(selecao), " occasions drawn (", n_top,
            " per ", rotulo1, ") among ",
            n_distinct(deteccoes[c("site", "species_code", "occasion_id")]),
            " with a prediction >= ", threshold, ".")
    ocasioes_candidatas <- selecao
  } else {
    # Sorteio entre TODAS as gravacoes (ou minutos), com ou sem predicao,
    # proporcional ao esforco de cada local
    gravacoes <- filter_time(gravacoes, janela, "recordings")
    if (unidade == "minute") {
      gravacoes <- gravacoes |>
        mutate(.dur = audio_duration(source_audio, recording_duration))
      if (anyNA(gravacoes$.dur)) {
        warning(sum(is.na(gravacoes$.dur)), " recording(s) without a ",
                "readable duration - skipped. Set `recording_duration`?")
      }
      gravacoes <- gravacoes |>
        filter(!is.na(.dur)) |>
        mutate(clip_start = map(.dur, \(d) (seq_len(ceiling(d / 60)) - 1) * 60)) |>
        unnest(clip_start) |>
        mutate(clip_end = pmin(clip_start + 60, .dur)) |>
        select(-.dur)
    } else {
      gravacoes <- gravacoes |>
        mutate(clip_start = 0,
               clip_end   = if (is.null(recording_duration)) NA_real_
                            else recording_duration)
    }
    gravacoes <- mutate(gravacoes,
                        occasion_id = make_occasion_id(source_audio,
                                                       clip_start, unidade))

    sorteadas <- withr::with_seed(seed, {
      gravacoes |>
        group_split(site) |>
        map(function(g) {
          n_alvo <- if (!is.null(n_recordings_per_site)) {
            min(n_recordings_per_site, nrow(g))
          } else {
            max(1, round(recording_fraction * nrow(g)))
          }
          slice_sample(g, n = n_alvo) |>
            mutate(inclusion_prob = n_alvo / nrow(g))
        }) |>
        list_rbind()
    })
    message(nrow(sorteadas), " ", unidade, "(s) drawn among ",
            nrow(gravacoes), " recorded, to annotate ",
            length(especies_alvo), " species.")

    # Uma copia da gravacao/minuto por especie a anotar (o veredito e por
    # especie, na pasta da especie)
    selecao <- sorteadas |>
      cross_join(tibble(species_code = especies_alvo)) |>
      mutate(
        begin_path     = source_audio,
        confidence     = NA_real_,
        rank           = NA_integer_,
        duration       = clip_end - clip_start,
        species_folder = folder_name(species_code),
        clip_file      = paste0("rec_", site, "_", species_folder, "_",
                                occasion_id, ".wav")
      )
  }

  # Meta total balanceada por especie (e, opcionalmente, por hora), ou
  # limite fixo por especie -- sorteios reprodutiveis. Em
  # "random_detections" as unidades sorteadas sao ocasioes.
  unid <- if (modo == "random_detections") "occasions" else "clips"
  if (modo == "random_recordings" &&
      (!is.null(target_total) || !is.null(max_per_species))) {
    warning("target_total/max_per_species are ignored in ",
            "\"random_recordings\" (recording_fraction or ",
            "n_recordings_per_site apply).")
  } else if (!is.null(target_total)) {
    if (!is.null(max_per_species)) {
      warning("target_total is set - max_per_species is ignored.")
    }
    antes <- nrow(selecao)
    selecao <- withr::with_seed(seed, {
      selecao |>
        group_split(site) |>
        map(function(sel_local) {
          n_disp <- table(sel_local$species_code)
          aloc   <- allocate_target(setNames(as.integer(n_disp), names(n_disp)),
                                    target_total)
          sel_local |>
            group_split(species_code) |>
            map(\(df) sample_clips(df, aloc[[df$species_code[1]]],
                                   balance_by_hour)) |>
            list_rbind()
        }) |>
        list_rbind()
    })
    message("Target of ", target_total, " ", unid, " per site (balanced ",
            "by species", if (balance_by_hour) " and hour", "): ",
            antes, " -> ", nrow(selecao), " ", unid, ".")
  } else if (!is.null(max_per_species)) {
    antes <- nrow(selecao)
    selecao <- withr::with_seed(seed, {
      selecao |>
        group_split(site, species_code) |>
        map(\(df) sample_clips(df, max_per_species, balance_by_hour)) |>
        list_rbind()
    })
    message("Limit of ", max_per_species, " ", unid, " per species ",
            "(per site): ", antes, " -> ", nrow(selecao), " ", unid, ".")
  }

  if (modo == "random_detections") {
    # Probabilidade de inclusao = sorteio no estrato (.p1) x sorteio da
    # meta/limite. A alocacao da meta e deterministica dado o numero de
    # candidatas, entao a 2a etapa e n/N no estrato (local x especie, x hora
    # se balance_by_hour)
    usou_meta <- !is.null(target_total) || !is.null(max_per_species)
    estrato   <- c("site", "species_code",
                   if (usou_meta && balance_by_hour) "recording_hour")
    # com estrato da 1a etapa sem a hora, o numero de candidatas por hora
    # na 2a etapa depende do 1o sorteio: o produto deixa de ser exato
    if (usou_meta && balance_by_hour && !"recording_hour" %in% estrato1) {
      warning("With strata (", rotulo1, ") without the hour and ",
              "balance_by_hour = TRUE, ",
              "inclusion_prob is conditional on the first draw; use ",
              "balance_by_hour = FALSE for exact inclusion probabilities.",
              call. = FALSE)
    }
    p2 <- if (usou_meta) {
      inner_join(count(selecao, across(all_of(estrato)), name = ".n"),
                 count(ocasioes_candidatas, across(all_of(estrato)),
                       name = ".N"),
                 by = estrato) |>
        mutate(.p2 = .n / .N) |>
        select(all_of(estrato), .p2)
    } else {
      distinct(selecao, across(all_of(estrato))) |> mutate(.p2 = 1)
    }

    # Cada ocasiao sorteada vira TODAS as suas predicoes >= threshold
    selecao <- selecao |>
      left_join(p2, by = estrato) |>
      transmute(site, species_code, occasion_id,
                inclusion_prob = .p1 * .p2) |>
      inner_join(deteccoes, by = c("site", "species_code", "occasion_id"),
                 relationship = "one-to-many") |>
      group_by(site, species_code, occasion_id) |>
      arrange(file_offset, .by_group = TRUE) |>
      mutate(rank = row_number()) |>
      ungroup() |>
      mutate(species_folder = folder_name(species_code),
             clip_file      = clip_name(confidence, rank, source_audio,
                                        clip_start, clip_end))
    message(nrow(selecao), " clips (every prediction >= ", threshold,
            " of the ", n_distinct(selecao[c("site", "species_code",
                                             "occasion_id")]),
            " occasions drawn).")
  }

  selecao <- mutate(selecao, sampling_mode = modo)
  if (!is.null(n_det_ocasiao)) {
    selecao <- selecao |>
      left_join(n_det_ocasiao, by = c("site", "species_code", "occasion_id")) |>
      mutate(n_detections_occasion = replace_na(n_detections_occasion, 0L))
  } else {
    selecao$n_detections_occasion <- NA_integer_
  }

  select(selecao, all_of(manifest_columns[manifest_columns != "status"]))
}

# Colunas do manifesto, na ordem do arquivo clip_manifest.csv
manifest_columns <- c(
  "site", "species_code", "species_folder", "recording_date", "night",
  "recording_hour", "rank", "confidence", "clip_file", "clip_start",
  "clip_end", "duration", "source_audio", "begin_path", "status",
  "sampling_mode", "occasion_id", "n_detections_occasion", "inclusion_prob"
)

# Lista todas as gravacoes de cada local: a tabela dada (data frame ou
# csv) ou list.files() nas pastas de audio que aparecem em begin_path
list_recordings <- function(selecao, recordings, audio_pattern,
                            remap_from, remap_to) {
  if (!is.null(recordings)) {
    if (is.character(recordings)) {
      recordings <- read_csv(recordings, show_col_types = FALSE)
    }
    gravacoes <- from_legacy(recordings) |>
      transmute(site, source_audio = remap_path(source_audio,
                                                remap_from, remap_to))
  } else {
    gravacoes <- selecao |>
      distinct(site, pasta = dirname(source_audio)) |>
      mutate(source_audio = map(pasta, \(d) list.files(
        d, pattern = audio_pattern, full.names = TRUE, ignore.case = TRUE))) |>
      unnest(source_audio) |>
      distinct(site, source_audio)
  }
  if (nrow(gravacoes) == 0) {
    stop("No recording found - check remap_from/remap_to or `recordings`.")
  }
  gravacoes <- bind_cols(gravacoes,
                         parse_date_hour(basename(gravacoes$source_audio))) |>
    mutate(hour_int = suppressWarnings(as.integer(recording_hour)),
           night    = recording_date)
  message(nrow(gravacoes), " recordings listed at ",
          n_distinct(gravacoes$site), " site(s).")
  gravacoes
}

# Filtros de tempo (janela de horas, dia sim/dia nao, janela de datas),
# sobre uma tabela com site, recording_date, hour_int e night
filter_time <- function(df, janela, rotulo) {
  hi <- janela$hour_start
  hf <- janela$hour_end
  # Janela de horas; cruzando a meia-noite, agrupa por NOITE
  if (!is.null(hi) && !is.null(hf)) {
    antes <- nrow(df)
    if (hi <= hf) {
      df <- filter(df, hour_int >= hi, hour_int <= hf)
    } else {
      df <- df |>
        filter(hour_int >= hi | hour_int <= hf) |>
        mutate(night = if_else(
          hour_int <= hf,
          format(as.Date(recording_date, "%Y%m%d") - 1, "%Y%m%d"),
          recording_date))
      message("The hour window crosses midnight: grouping by night ",
              "(small hours count as the night before).")
    }
    message("Hour window ", hi, "h-", hf, "h: ", antes, " -> ",
            nrow(df), " ", rotulo, ".")
    if (nrow(df) == 0) stop("No ", rotulo, " within the hour window.")
  }

  # "Dia sim, dia nao" (por local, sobre a data/noite de agrupamento)
  if (isTRUE(janela$alternate_days)) {
    antes <- nrow(df)
    df <- df |>
      group_by(site) |>
      mutate(.dia = as.integer(
        as.Date(night, "%Y%m%d") -
          min(as.Date(night, "%Y%m%d"), na.rm = TRUE))) |>
      ungroup() |>
      filter(.dia %% 2 == 0) |>
      select(-.dia)
    message("Alternate days: ", antes, " -> ", nrow(df), " ", rotulo, ".")
  }

  # Janela de datas (ex.: periodo do data logger)
  if (!is.null(janela$date_start) || !is.null(janela$date_end)) {
    antes <- nrow(df)
    di <- if (is.null(janela$date_start)) "00000000" else as.character(janela$date_start)
    dfim <- if (is.null(janela$date_end)) "99999999" else as.character(janela$date_end)
    df <- filter(df, !is.na(recording_date),
                 recording_date >= di, recording_date <= dfim)
    message("Date window ", di, "-", dfim, ": ", antes, " -> ",
            nrow(df), " ", rotulo, ".")
    if (nrow(df) == 0) stop("No ", rotulo, " within the date window.")
  }
  df
}

# Identificador da ocasiao: o arquivo (sem extensao) ou arquivo + minuto
make_occasion_id <- function(caminho_audio, inicio, unidade) {
  base <- tools::file_path_sans_ext(basename(caminho_audio))
  if (unidade == "minute") {
    sprintf("%s_m%03d", base, as.integer(inicio %/% 60))
  } else {
    base
  }
}

# Monta o nome do clipe:
#   <conf 3 casas>_<rank>_<arquivo original sem extensao>_<ini>s_<fim>s.wav
clip_name <- function(confidence, rank, caminho_audio, ini, fim) {
  base <- tools::file_path_sans_ext(basename(caminho_audio))
  sprintf("%.3f_%d_%s_%.1fs_%.1fs.wav", confidence, rank, base, ini, fim)
}

# Duracao (s) de cada gravacao: a fixa ou lida do arquivo com o 'av'
audio_duration <- function(caminhos, fixa = NULL) {
  if (!is.null(fixa)) return(rep(fixa, length(caminhos)))
  require_suggested("av", "to read the duration of the recordings")
  map_dbl(caminhos, \(f) tryCatch(av::av_media_info(f)$duration,
                                  error = function(e) NA_real_))
}

# Reparte uma meta total entre especies de forma balanceada ("water
# filling"): especies com menos clipes que a cota entram inteiras e o
# excedente e redistribuido entre as que ainda tem sobra
allocate_target <- function(n_disponivel, meta_total) {
  aloc     <- setNames(integer(length(n_disponivel)), names(n_disponivel))
  restante <- meta_total
  pend     <- names(n_disponivel)
  repeat {
    if (length(pend) == 0 || restante <= 0) break
    cota      <- restante %/% length(pend)
    if (cota == 0) break
    saturadas <- pend[n_disponivel[pend] <= cota]
    if (length(saturadas) == 0) {
      aloc[pend] <- cota
      restante   <- restante - cota * length(pend)
      break
    }
    aloc[saturadas] <- n_disponivel[saturadas]
    restante <- restante - sum(n_disponivel[saturadas])
    pend     <- setdiff(pend, saturadas)
  }
  # distribui a sobra (< 1 por especie) uma a uma
  com_folga <- names(which(aloc < n_disponivel))
  if (restante > 0 && length(com_folga) > 0) {
    extra <- com_folga[seq_len(min(restante, length(com_folga)))]
    aloc[extra] <- aloc[extra] + 1L
  }
  aloc
}

# Sorteia n_alvo clipes de uma especie; com por_hora = TRUE faz um
# round-robin entre as horas do dia (cobre o ciclo diel)
sample_clips <- function(df, n_alvo, por_hora = TRUE) {
  if (nrow(df) <= n_alvo) return(df)
  if (por_hora) {
    df |>
      group_by(recording_hour) |>
      mutate(.ordem = sample.int(n())) |>
      ungroup() |>
      arrange(.ordem) |>
      slice_head(n = n_alvo) |>
      select(-.ordem)
  } else {
    slice_sample(df, n = n_alvo)
  }
}

# Estratos do sorteio de random_detections: um dos atalhos ou um vetor de
# colunas, sempre com local e especie e nunca com colunas do score
resolve_strata <- function(strata) {
  atalhos <- list(
    night_hour   = c("night", "recording_hour"),
    night        = "night",
    hour         = "recording_hour",
    week         = "week",
    month        = "month",
    site_species = character())
  if (!is.character(strata) || length(strata) == 0) {
    stop("`strata` must be a preset name or a character vector of columns.",
         call. = FALSE)
  }
  cols <- if (length(strata) == 1 && strata %in% names(atalhos)) {
    atalhos[[strata]]
  } else {
    strata
  }
  proibidas <- intersect(cols, c("confidence", "rank"))
  if (length(proibidas) > 0) {
    stop("`strata` cannot use column(s) that depend on the score: ",
         paste(proibidas, collapse = ", "), call. = FALSE)
  }
  unique(c("site", "species_code", cols))
}

# Junta as covariaveis das ocasioes (ex. de covariate_bins()) pelas
# colunas de identificacao que elas compartilham com as predicoes
join_covariates <- function(df, covariates, estratos) {
  if (is.null(covariates)) return(df)
  if (!is.data.frame(covariates)) {
    stop("`covariates` must be a data frame.", call. = FALSE)
  }
  ids <- c("site", "night", "recording_date", "recording_hour",
           "source_audio", "occasion_id")
  chave <- intersect(ids, names(covariates))
  if (length(chave) == 0) {
    stop("`covariates` must share at least one of the columns ",
         paste(ids, collapse = ", "), " with the predictions.", call. = FALSE)
  }
  novas <- setdiff(names(covariates), chave)
  repetidas <- intersect(novas, names(df))
  if (length(repetidas) > 0) {
    stop("Column(s) of `covariates` already in `detections`: ",
         paste(repetidas, collapse = ", "), call. = FALSE)
  }
  cov <- mutate(covariates, across(all_of(chave), as.character))
  if (anyDuplicated(cov[chave])) {
    stop("`covariates` must have one row per ",
         paste(chave, collapse = " x "), ".", call. = FALSE)
  }
  df <- df |>
    mutate(.ordem = row_number(),
           across(all_of(chave), as.character, .names = ".k_{.col}"))
  names(cov)[match(chave, names(cov))] <- paste0(".k_", chave)
  df <- left_join(df, cov, by = paste0(".k_", chave)) |>
    arrange(.ordem) |>
    select(-".ordem", -all_of(paste0(".k_", chave)))
  usadas <- intersect(novas, estratos)
  if (length(usadas) > 0) {
    faltando <- rowSums(is.na(df[usadas])) > 0
    sem <- unique(df[faltando, c("site", "species_code", "occasion_id")])
    if (nrow(sem) > 0) {
      warning(nrow(sem), " occasion(s) without a value of ",
              paste(usadas, collapse = ", "), " in `covariates`; they form ",
              "a stratum of their own.", call. = FALSE)
    }
    message("Strata by ", paste(usadas, collapse = ", "), ": if the ",
            "covariate may be related to the verdict, include it in the ",
            "calibration or weight the clips by inclusion_prob.")
  }
  df
}

# Mes (AAAA-MM) e semana ISO (AAAA-Wss) da noite, quando usados nos
# estratos e ausentes das deteccoes
add_period_columns <- function(df, cols) {
  data_noite <- function() as.Date(df$night, "%Y%m%d")
  if ("month" %in% cols && !"month" %in% names(df)) {
    df$month <- format(data_noite(), "%Y-%m")
  }
  if ("week" %in% cols && !"week" %in% names(df)) {
    df$week <- format(data_noite(), "%G-W%V")
  }
  df
}
