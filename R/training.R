#' Read and stack the validation tables
#'
#' Stacks the `validation_by_clip.csv` tables of several runs or sites
#' (output of [post_validation()]) and keeps every column and every
#' verdict, unlike [read_validations()], which keeps only what the
#' calibration needs. Tables written by v1.2.0 (`validacao_por_clipe.csv`)
#' are also read.
#'
#' @param files Paths to the `validation_by_clip.csv` files. Missing files
#'   are skipped with a warning.
#' @param candidates For the rounds of one design: the `candidates.csv` of
#'   the first round, passed to [combine_rounds()], which gives the clips
#'   their cumulative `inclusion_prob`. `NULL` only stacks the tables.
#'
#' @return A tibble with the columns of the validation tables; `night` and
#'   `recording_date` are character.
#' @export
read_validation_tables <- function(files, candidates = NULL) {
  if (!is.null(candidates)) {
    existem <- file.exists(files)
    if (any(!existem)) {
      warning("Not found: ", paste(files[!existem], collapse = ", "))
    }
    return(combine_rounds(files[existem], candidates))
  }
  tabs <- map(files, function(f) {
    if (!file.exists(f)) { warning("Not found: ", f); return(NULL) }
    read_manifest(f) |>
      mutate(across(any_of(c("night", "recording_date")), as.character))
  })
  out <- list_rbind(tabs)
  if (is.null(out) || nrow(out) == 0) stop("No validation table read.")
  out
}

#' Build the training folders for BirdNET-Analyzer
#'
#' Splits the reviewed clips into a training and a test set and copies them
#' into the folder layout that the training script of BirdNET-Analyzer
#' expects: one folder per class, named after the label (`species_code`, so
#' the retrained classifier keeps the labels of the current one), with the
#' negatives of a class in a folder with the same name prefixed by `-` (or
#' all negatives in one non-event folder; see Negatives). The test clips go
#' to a separate `test` folder; with `val_prop`, a validation set by night
#' goes to `val`, to be passed as `--test_data` (see Splits).
#'
#' The layout follows the documentation of BirdNET-Analyzer (version
#' 2.4.0, `birdnet_analyzer.train`), which also recommends at least 100
#' files per species; classes below `min_files` in the training set raise
#' a warning. Whole-recording clips of `"random_recordings"` (longer than
#' 3 s, `confidence` = `NA`) are left out: their label says only that the
#' species was heard somewhere in the recording.
#'
#' The table of clips is also written to `training_set.csv` in
#' `output_dir`; keep it with the classifier, to leave these clips out of
#' later validation rounds with [exclude_training_clips()].
#'
#' @section Splits:
#' Clips of the same night are correlated, so a split by clip leaks
#' information from the training into the test set.
#' * `"site"`: the clips of `test_sites` form the test set, which then
#'   measures transfer to sites the classifier was not trained on.
#' * `"night"`: in each site, `ceiling(n * test_prop)` of its `n` nights
#'   are drawn for the test set, for all species together, so that no
#'   recording is training data for one species and test data for another.
#' * `"site_species_night"`: the nights are drawn within each site x
#'   species with at least two nights (the split of the 2.x scripts of the
#'   FrogNet project). The same night can then be in the training set for
#'   one species and in the test set for another, which breaks the
#'   independence of the test set; it is kept only to reproduce earlier
#'   training sets, and warns.
#' * `"none"`: every clip goes to the training set.
#'
#' With `val_prop`, a validation set is drawn after the test set and after
#' `max_per_site_species`, among the nights left in the training set: in
#' each site, `ceiling(n * val_prop)` of its `n` training nights, never
#' from `exclude_from_test`. Its clips go to `val/`. BirdNET-Analyzer draws
#' its own validation set by file, which leaks nights, and its autotune
#' chooses the hyperparameters on it; pass `val/` as `--test_data` so that
#' the validation is by night, and keep `test/` for the final evaluation.
#' The result is the same as a second call of `build_training_set()` with
#' `split = "night"`, `test_prop = val_prop` and `seed = val_seed` on the
#' training rows of the first.
#'
#' The draws use `seed` (`seed + 1` for `max_per_site_species`, and
#' `val_seed` for the validation set) and leave the global random number
#' generator as it was. They follow the
#' order of the rows of `validation`: the same clips in another order give
#' another split.
#'
#' @section Negatives:
#' BirdNET-Analyzer (version 2.4.0 and its main branch of October 2026)
#' gives the label -1 to the clips of `-<species_code>` folders. That label
#' enters the loss functions unchanged, which makes the loss of those clips
#' negative and unbounded; `keras.metrics.AUC` does not count -1 as a
#' negative, which inflates the validation AUPRC whenever the validation
#' set holds such clips; and the internal random split puts all of them in
#' the training set. Clips of the non-event folders (`"Noise"`, `"Other"`,
#' `"Background"`, `"Silence"`, in any case) get the label 0 and do not
#' have these problems (reported in
#' <https://github.com/birdnet-team/BirdNET-Analyzer/issues/1033>). Until
#' it is fixed, use `negatives_folder = "Noise"`: every negative goes to
#' that folder, as `<species>-<site>-<clip_file>` (the short species code
#' after the last `_` of `species_code`), so that the file keeps its origin
#' and clips of different species do not collide. The negatives then train
#' the classifier against all classes, not only their own.
#'
#' @section Checks:
#' At the end, the counts are reported, and kept in the attribute
#' `"checks"` of the result: test nights (site x night) that also have
#' training clips, test nights listed in `exclude_from_test`, and test
#' clips that overlap a training clip of the same species in the same
#' recording; with `val_prop`, also validation nights with training clips
#' and validation nights listed in `exclude_from_test`. All should be 0
#' with `split = "night"`. With `strict = TRUE`, any count above 0 is an
#' error.
#'
#' @param validation Reviewed clips, as returned by [classify_review()],
#'   [post_validation()] (`$validation`) or [read_validation_tables()]. It
#'   needs `site`, `species_code`, `clip_file`, `verdict` and
#'   `reviewed_path` (the path where the review left each clip), and
#'   `night` for the splits by night.
#' @param output_dir Output folder; `train/` and, if any clip is held out,
#'   `test/` are created in it.
#' @param split How to split the clips into training and test sets; see
#'   Splits.
#' @param test_sites Sites held out for testing with `split = "site"`.
#'   `NULL` puts every clip in `train/`.
#' @param test_prop Proportion of the nights of each site (or site x
#'   species) drawn for the test set.
#' @param seed Seed of the draws.
#' @param max_per_site_species Optional maximum number of positive
#'   training clips per site x species. Larger sets are reduced by taking
#'   clips from the nights in turn, in random order, which keeps as many
#'   nights as possible. Test clips and negatives are not reduced.
#' @param exclude_from_test Optional table with `site` and `night` (e.g.
#'   from [training_nights()]): nights that must not be in the test set,
#'   such as nights whose recordings trained another classifier that will
#'   be compared on it. They are left out of the draws of the test and
#'   validation sets and stay in the training set.
#' @param val_prop Optional proportion of the training nights of each site
#'   drawn for the validation set (`val/`); see Splits. `NULL` draws none.
#' @param val_seed Seed of the validation draw. The default, `seed + 1`, is
#'   also the seed of `max_per_site_species`; the two draws are separate,
#'   and the default reproduces the training sets of the FrogNet project.
#' @param negatives Include the negative clips?
#' @param negatives_folder `NULL` puts the negatives of each class in a
#'   `-<species_code>` folder. A non-event class of BirdNET-Analyzer
#'   (`"Noise"`, `"Other"`, `"Background"` or `"Silence"`) puts all of them
#'   in that folder instead; see Negatives.
#' @param min_files Minimum number of positive training files per class
#'   below which a warning is raised.
#' @param copy Copy the clips? With `FALSE`, only `training_set.csv` is
#'   written, so that the split can be built on a computer without the
#'   clips and copied later.
#' @param remap_from,remap_to Optional prefix of `reviewed_path` and its
#'   replacement, for clips reviewed on another computer or drive.
#' @param strict Raise an error if any check is above 0?
#'
#' @return A tibble with one row per clip: `site`, `species_code`,
#'   `verdict`, `set` (`"train"`, `"val"` or `"test"`), `class_folder`,
#'   `clip_file`,
#'   `source_audio`, `clip_start`, `clip_end`, `from`, `to` and `night`,
#'   invisibly, with the checks in the attribute `"checks"`. With
#'   `copy = TRUE`, clips that could not be copied are left out.
#' @seealso [training_nights()], [exclude_training_clips()],
#'   `vignette("retraining")`.
#' @export
build_training_set <- function(validation, output_dir,
                               split = c("site", "night",
                                         "site_species_night", "none"),
                               test_sites = NULL, test_prop = 0.2,
                               seed = 2026, max_per_site_species = NULL,
                               exclude_from_test = NULL, val_prop = NULL,
                               val_seed = seed + 1, negatives = TRUE,
                               negatives_folder = NULL, min_files = 100, copy = TRUE,
                               remap_from = NULL, remap_to = NULL,
                               strict = FALSE) {
  split <- match.arg(split)
  faltam <- setdiff(c("site", "species_code", "clip_file", "verdict",
                      "reviewed_path"), names(validation))
  if (length(faltam) > 0) {
    stop("`validation` lacks the column(s): ", paste(faltam, collapse = ", "))
  }
  por_noite <- split %in% c("night", "site_species_night")
  if ((por_noite || !is.null(exclude_from_test)) &&
      !"night" %in% names(validation)) {
    stop("`validation` lacks the column `night`, needed by split = \"",
         split, "\" and `exclude_from_test`.", call. = FALSE)
  }
  if (por_noite && (!is.numeric(test_prop) || length(test_prop) != 1 ||
                    test_prop <= 0 || test_prop >= 1)) {
    stop("`test_prop` must be a number between 0 and 1.", call. = FALSE)
  }
  if (!is.numeric(seed) || length(seed) != 1 || is.na(seed)) {
    stop("`seed` must be a number.", call. = FALSE)
  }
  if (!is.null(val_prop)) {
    if (!is.numeric(val_prop) || length(val_prop) != 1 || is.na(val_prop) ||
        val_prop <= 0 || val_prop >= 1) {
      stop("`val_prop` must be a number between 0 and 1.", call. = FALSE)
    }
    if (!"night" %in% names(validation)) {
      stop("`validation` lacks the column `night`, needed by `val_prop`.",
           call. = FALSE)
    }
    if (!is.numeric(val_seed) || length(val_seed) != 1 || is.na(val_seed)) {
      stop("`val_seed` must be a number.", call. = FALSE)
    }
  }
  if (!is.null(negatives_folder)) {
    if (!is.character(negatives_folder) || length(negatives_folder) != 1 ||
        !tolower(negatives_folder) %in% non_event_classes) {
      stop("`negatives_folder` must be a non-event class of ",
           "BirdNET-Analyzer: ", paste(non_event_classes, collapse = ", "),
           " (in any case).", call. = FALSE)
    }
  }
  if (!is.null(test_sites) && split != "site") {
    warning("`test_sites` is ignored with split = \"", split, "\".",
            call. = FALSE)
  }
  vereditos <- c("positive", if (negatives) "negative")
  clipes <- validation |>
    filter(verdict %in% vereditos, !is.na(reviewed_path))
  if ("confidence" %in% names(clipes)) {
    inteiras <- sum(is.na(clipes$confidence))
    if (inteiras > 0) {
      message(inteiras, " whole-recording clip(s) (no confidence) left out.")
      clipes <- filter(clipes, !is.na(confidence))
    }
  }
  if (nrow(clipes) == 0) stop("No reviewed clip to copy.")
  if (split == "site") {
    desconhecidos <- setdiff(test_sites, unique(clipes$site))
    if (length(desconhecidos) > 0) {
      warning("Site(s) in `test_sites` without clips: ",
              paste(desconhecidos, collapse = ", "))
    }
  }
  for (col in c("source_audio", "clip_start", "clip_end", "night")) {
    if (!col %in% names(clipes)) clipes[[col]] <- NA
  }
  clipes$night <- as.character(clipes$night)
  # especie das chaves de sorteio: species_folder quando existe (a ordem dos
  # grupos entra no sorteio)
  clipes$.sp <- if ("species_folder" %in% names(clipes)) {
    clipes$species_folder
  } else {
    clipes$species_code
  }
  guarda <- training_guard(exclude_from_test)

  clipes$set <- with_training_seed(seed, split_sets(
    clipes, split, test_sites, test_prop, guarda))
  if (!is.null(max_per_site_species)) {
    antes <- nrow(clipes)
    clipes <- with_training_seed(seed + 1,
                                 cap_positives(clipes, max_per_site_species))
    message("At most ", max_per_site_species, " positive training clips ",
            "per site x species: ", antes, " -> ", nrow(clipes), " clips.")
  }
  if (!is.null(val_prop)) {
    # sobre as linhas de treino, na ordem que tem depois do teto, como uma
    # segunda chamada da funcao
    treino <- clipes$set == "train"
    clipes$set[treino] <- if_else(
      with_training_seed(val_seed, split_sets(
        clipes[treino, ], "night", NULL, val_prop, guarda)) == "test",
      "val", "train")
  }

  if (!is.null(remap_from) && !is.null(remap_to)) {
    clipes$reviewed_path <- remap_path(clipes$reviewed_path, remap_from,
                                       remap_to)
  }
  negativo <- clipes$verdict == "negative"
  pasta <- if_else(negativo, paste0("-", clipes$species_code),
                   clipes$species_code)
  destino <- clipes$clip_file
  if (!is.null(negatives_folder)) {
    pasta[negativo] <- negatives_folder
    destino[negativo] <- paste(str_extract(clipes$species_code[negativo],
                                           "[^_]+$"),
                               clipes$site[negativo],
                               clipes$clip_file[negativo], sep = "-")
  }
  copia <- clipes |>
    transmute(site, species_code, verdict, set, class_folder = pasta,
              clip_file, source_audio, clip_start, clip_end,
              from = reviewed_path,
              to = file.path(output_dir, set, class_folder, destino),
              night)
  repetidos <- sum(duplicated(copia$to))
  if (repetidos > 0) {
    warning(repetidos, " clip(s) share a destination with another clip and ",
            "would overwrite it.", call. = FALSE)
  }

  if (copy) {
    walk(unique(dirname(copia$to)), dir.create, recursive = TRUE,
         showWarnings = FALSE)
    ok <- file.copy(copia$from, copia$to, overwrite = TRUE)
    if (!all(ok)) {
      warning(sum(!ok), " clip(s) could not be copied - check ",
              "`reviewed_path`.")
    }
    copia <- copia[ok, ]
  } else {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  poucos <- copia |>
    filter(set == "train", verdict == "positive") |>
    count(species_code) |>
    right_join(distinct(copia, species_code), by = "species_code") |>
    mutate(n = replace_na(n, 0L)) |>
    filter(n < min_files)
  if (nrow(poucos) > 0) {
    warning("Class(es) with fewer than ", min_files, " positive training ",
            "files: ", paste0(poucos$species_code, " (", poucos$n, ")",
                              collapse = ", "), call. = FALSE)
  }

  write_csv(copia, file.path(output_dir, "training_set.csv"))
  message(nrow(copia), " clips ", if (copy) "copied to " else
            "listed in training_set.csv (nothing copied) in ", output_dir,
          " (", sum(copia$set == "train"), " train, ",
          if (!is.null(val_prop)) paste0(sum(copia$set == "val"), " val, "),
          sum(copia$set == "test"), " test).")
  checagens <- training_checks(copia, guarda, validacao = !is.null(val_prop))
  if (any(copia$set %in% c("test", "val"))) {
    message("Checks (all should be 0 with split = \"night\"):\n",
            paste0("  ", names(checagens), ": ", checagens,
                   collapse = "\n"))
    if (strict && any(checagens > 0)) {
      stop("The test or validation set is not independent of the ",
           "training set (see the checks above).", call. = FALSE)
    }
  }
  attr(copia, "checks") <- checagens
  invisible(copia)
}

# Sorteios com semente propria, nos geradores padrao do R, sem mexer no
# gerador global
with_training_seed <- function(seed, code) {
  withr::with_seed(seed, code, .rng_kind = "Mersenne-Twister",
                   .rng_normal_kind = "Inversion",
                   .rng_sample_kind = "Rejection")
}

# Noites que nao podem ir para o teste (site x night como texto)
training_guard <- function(exclude_from_test) {
  if (is.null(exclude_from_test)) return(NULL)
  faltam <- setdiff(c("site", "night"), names(exclude_from_test))
  if (length(faltam) > 0) {
    stop("`exclude_from_test` lacks the column(s): ",
         paste(faltam, collapse = ", "), call. = FALSE)
  }
  exclude_from_test |>
    filter(!is.na(site), !is.na(night)) |>
    transmute(site = as.character(site), night = as.character(night)) |>
    distinct()
}

# Conjunto de cada clipe ("train"/"test"); o sorteio segue o do script
# m3_treino.R do FrogNet, linha a linha
split_sets <- function(clipes, split, test_sites, test_prop, guarda) {
  if (split == "none") return(rep("train", nrow(clipes)))
  if (split == "site") {
    return(if_else(clipes$site %in% test_sites, "test", "train"))
  }
  if (split == "site_species_night") {
    warning("split = \"site_species_night\" draws the nights within each ",
            "site x species: a night can be training data for one species ",
            "and test data for another, so the test set is not independent.",
            call. = FALSE)
    elegiveis <- distinct(clipes, site, .sp, night)
    if (!is.null(guarda)) {
      elegiveis <- anti_join(elegiveis, guarda, by = c("site", "night"))
    }
    teste <- elegiveis |>
      group_by(site, .sp) |>
      mutate(.ordem = sample.int(n())) |>
      filter(n() >= 2, .ordem <= ceiling(n() * test_prop)) |>
      ungroup() |>
      select(site, .sp, night)
    chave <- c("site", ".sp", "night")
  } else {
    elegiveis <- distinct(clipes, site, night)
    if (!is.null(guarda)) {
      elegiveis <- anti_join(elegiveis, guarda, by = c("site", "night"))
    }
    teste <- elegiveis |>
      group_by(site) |>
      mutate(.ordem = sample.int(n())) |>
      filter(.ordem <= ceiling(n() * test_prop)) |>
      ungroup() |>
      select(site, night)
    chave <- c("site", "night")
  }
  teste$.teste <- TRUE
  marcado <- left_join(clipes[chave], teste, by = chave)$.teste
  if_else(!is.na(marcado), "test", "train")
}

# Teto de positivos do treino por local x especie: as noites cedem um
# clipe por vez, em ordem aleatoria
cap_positives <- function(clipes, teto) {
  clipes |>
    group_by(site, .sp, set, verdict) |>
    group_modify(function(d, g) {
      if (g$set != "train" || g$verdict != "positive" || nrow(d) <= teto) {
        return(d)
      }
      d |>
        group_by(night) |>
        mutate(.rodada = sample.int(n())) |>
        ungroup() |>
        mutate(.desempate = sample.int(n())) |>
        arrange(.rodada, .desempate) |>
        slice_head(n = teto) |>
        select(-.rodada, -.desempate)
    }) |>
    ungroup()
}

# Classes sem evento do BirdNET-Analyzer (NON_EVENT_CLASSES), rotulo 0
non_event_classes <- c("noise", "other", "background", "silence")

# Contagens de vazamento entre treino e teste (e validacao)
training_checks <- function(copia, guarda, validacao = FALSE) {
  treino <- filter(copia, set == "train")
  teste <- filter(copia, set == "test")
  noites_teste <- teste |>
    filter(!is.na(night)) |>
    distinct(site, night)
  sobrepostos <- if (nrow(teste) > 0 && nrow(treino) > 0) {
    nrow(teste) - nrow(suppressMessages(suppressWarnings(
      exclude_training_clips(teste, treino))))
  } else {
    0L
  }
  out <- c(test_nights_in_train = nrow(semi_join(
      noites_teste, distinct(treino, site, night), by = c("site", "night"))),
    test_nights_excluded = if (is.null(guarda)) 0L else
      nrow(semi_join(noites_teste, guarda, by = c("site", "night"))),
    test_clips_overlapping_train = as.integer(sobrepostos))
  if (!validacao) return(out)
  noites_val <- copia |>
    filter(set == "val", !is.na(night)) |>
    distinct(site, night)
  c(out,
    val_nights_in_train = nrow(semi_join(
      noites_val, distinct(treino, site, night), by = c("site", "night"))),
    val_nights_excluded = if (is.null(guarda)) 0L else
      nrow(semi_join(noites_val, guarda, by = c("site", "night"))))
}

#' Nights and recordings of clips used to train a classifier
#'
#' Reads the site, date and time of the source recording from the names of
#' training clips (of the current classifier, or of the reference library
#' folders of another one) and returns their recordings and nights. Pass
#' the result to `exclude_from_test` of [build_training_set()], so that a
#' test set does not hold nights another compared classifier was trained
#' on, or to [exclude_training_clips()].
#'
#' @param files File names or paths of training clips. Elements that are
#'   folders are listed recursively.
#' @param pattern Perl regular expression with the named groups `site`,
#'   `date` (`YYYYMMDD`) and `time` (`HHMMSS`). The default takes the
#'   letters before the recorder number, the date and the time of names
#'   such as `ARA01_20211016_190000` or
#'   `..._ARA_ARA01_20230121_203000_12.0s_15.0s.wav`.
#' @param site_map Optional named character vector to fix diverging site
#'   names, e.g. `c(BEP2 = "BEP")`, as in [read_validations()].
#' @param night_cutoff Recordings that start before this hour belong to
#'   the night of the day before, as in [detection_history()].
#'
#' @return A tibble with `file`, `site`, `recording` (site, date and time
#'   of the source recording, before `site_map`) and `night`
#'   (`YYYYMMDD`). Names that do not match `pattern` are left out with a
#'   warning.
#' @seealso [build_training_set()], [exclude_training_clips()].
#' @export
#' @examples
#' training_nights(c("ARA01_20211016_190000_3.0s_6.0s.wav",
#'                   "ARA01_20211017_013000_9.0s_12.0s.wav",
#'                   "FNJV_0042_Boana_raniceps.wav"))
training_nights <- function(files,
                            pattern = paste0("(?<site>[A-Za-z]+)[A-Za-z0-9]*",
                                             "_(?<date>\\d{8})_(?<time>\\d{6})"),
                            site_map = NULL, night_cutoff = 12) {
  pastas <- dir.exists(files)
  files <- c(files[!pastas],
             unlist(lapply(files[pastas], list.files, recursive = TRUE,
                           full.names = TRUE)))
  p <- recording_parts(files, pattern)
  if (any(!p$ok)) {
    fora <- basename(files[!p$ok])
    warning(length(fora), " file name(s) do not match `pattern` and were ",
            "left out: ", paste(utils::head(fora, 5), collapse = ", "),
            if (length(fora) > 5) ", ...", call. = FALSE)
  }
  p <- p[p$ok, ]
  data <- as.Date(p$date, format = "%Y%m%d")
  hora <- as.integer(substr(p$time, 1, 2))
  out <- tibble(file = files[p$ok_index],
                site = rename_site(p$site, site_map),
                recording = p$recording,
                night = format(if_else(hora < night_cutoff, data - 1, data),
                               "%Y%m%d"))
  # o padrao acompanha a tabela, para exclude_training_clips()
  attr(out, "pattern") <- pattern
  out
}

recording_pattern <- paste0("(?<site>[A-Za-z]+)[A-Za-z0-9]*",
                            "_(?<date>\\d{8})_(?<time>\\d{6})")

# Local, data e hora da gravacao de origem a partir do nome do arquivo
# (grupos nomeados site, date, time); recording = site_date_time
recording_parts <- function(files, pattern = recording_pattern) {
  nomes <- basename(files)
  m <- regexpr(pattern, nomes, perl = TRUE)
  if (!all(c("site", "date", "time") %in% attr(m, "capture.names"))) {
    stop("`pattern` needs the named groups `site`, `date` and `time`.",
         call. = FALSE)
  }
  inicio <- attr(m, "capture.start")
  tam <- attr(m, "capture.length")
  pega <- function(g) {
    out <- substring(nomes, inicio[, g], inicio[, g] + tam[, g] - 1)
    out[m < 0] <- NA_character_
    out
  }
  tibble(ok = m > 0, ok_index = seq_along(nomes), site = pega("site"),
         date = pega("date"), time = pega("time"),
         recording = if_else(m > 0, paste(site, date, time, sep = "_"),
                             NA_character_))
}

#' Leave the training clips out of a manifest
#'
#' Drops from a clip manifest the clips that share data with the clips used
#' to train the classifier (the `training_set.csv` written by
#' [build_training_set()], or the table of [training_nights()]). Use it
#' before reviewing the detections of a retrained classifier: scores of the
#' clips it was trained on are biased upwards.
#'
#' @section Levels:
#' * `"clip"`: clips that overlap in time a training clip of the same
#'   recording.
#' * `"recording"`: every clip of a recording with a training clip.
#' * `"night"`: every clip of a site x night with a training clip.
#'
#' With `any_species = FALSE`, only clips of the same species are dropped;
#' with `TRUE`, a recording or night used to train one species is
#' left out for all of them. A table of [training_nights()] has no species,
#' clip times or `source_audio`: it takes `level = "recording"` or
#' `"night"`, always for any species. With `"recording"`, the site, date
#' and time are read from `source_audio` of the manifest with `pattern`,
#' which should be the one given to [training_nights()].
#'
#' @param manifest Clip manifest, as returned by [select_clips()] or read
#'   from `clip_manifest.csv`.
#' @param training_set Table returned by [build_training_set()] or
#'   [training_nights()], or the path to a `training_set.csv`.
#' @param level What a training clip excludes; see Levels.
#' @param any_species Exclude across species?
#' @param pattern With a table of [training_nights()] and
#'   `level = "recording"`, the regular expression that reads the
#'   recordings from `source_audio`. By default, the one recorded in the
#'   table by [training_nights()] (lost if the table was rebuilt, e.g. by
#'   [dplyr::bind_rows()]), else the default of [training_nights()].
#'
#' @return The manifest without the excluded clips.
#' @export
exclude_training_clips <- function(manifest, training_set,
                                   level = c("clip", "recording", "night"),
                                   any_species = FALSE, pattern = NULL) {
  level <- match.arg(level)
  if (is.character(training_set)) {
    training_set <- read_csv(training_set, show_col_types = FALSE)
  }
  de_noites <- "recording" %in% names(training_set) &&
    !"source_audio" %in% names(training_set)
  if (de_noites) {
    if (level == "clip") {
      stop("A table of training_nights() has no clip times: use level = ",
           "\"recording\" or \"night\".", call. = FALSE)
    }
    if (!any_species) {
      message("A table of training_nights() has no species: clips of ",
              "every species are excluded.")
      any_species <- TRUE
    }
  }
  sp <- if (any_species) character() else "species_code"
  if (level == "night") {
    faltam <- setdiff(c("site", "night"),
                      intersect(names(manifest), names(training_set)))
    if (length(faltam) > 0) {
      stop("`manifest` and `training_set` both need `site` and `night` for ",
           "level = \"night\".", call. = FALSE)
    }
    treino <- training_set |>
      filter(!is.na(night)) |>
      transmute(across(all_of(sp)), site = as.character(site),
                night = as.character(night)) |>
      distinct()
    chave <- c(sp, "site", "night")
    alvo <- mutate(manifest, site = as.character(site),
                   night = as.character(night))
  } else if (de_noites) {
    treino <- distinct(training_set, .rec = recording)
    chave <- ".rec"
    alvo <- manifest
    if (is.null(pattern)) {
      pattern <- attr(training_set, "pattern")
      if (is.null(pattern)) pattern <- recording_pattern
    }
    alvo$.rec <- recording_parts(manifest$source_audio, pattern)$recording
    if (all(is.na(alvo$.rec))) {
      warning("No `source_audio` of the manifest matches `pattern`; ",
              "nothing excluded. Give the pattern used in ",
              "training_nights().", call. = FALSE)
      return(manifest)
    }
  } else {
    treino <- training_set |>
      filter(!is.na(source_audio), !is.na(clip_start)) |>
      distinct(across(all_of(sp)), source_audio, t_ini = clip_start,
               t_fim = clip_end)
    chave <- c(sp, "source_audio")
    alvo <- manifest
    if (level == "recording") treino <- distinct(treino, across(all_of(chave)))
  }
  if (nrow(treino) == 0) {
    warning("`training_set` has no ",
            if (level == "night") "site/night" else "source_audio/clip_start",
            "; nothing excluded.")
    return(manifest)
  }
  junta <- alvo |>
    mutate(.linha = row_number()) |>
    inner_join(treino, by = chave, relationship = "many-to-many")
  if (level == "clip") junta <- filter(junta, clip_start < t_fim,
                                       clip_end > t_ini)
  fora <- unique(junta$.linha)
  message(length(fora), " clip(s) sharing a ", level, " with the training ",
          "clips left out of the manifest.")
  if (length(fora) == 0) return(manifest)
  manifest[-fora, ]
}
