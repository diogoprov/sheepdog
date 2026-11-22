#' Read and stack the validation tables
#'
#' Stacks the `validation_by_clip.csv` tables of several runs or sites
#' (output of [post_validation()]) and keeps every column and every
#' verdict, unlike [read_validations()], which keeps only what the
#' calibration needs. Tables written by v1.2.0 (`validacao_por_clipe.csv`)
#' are also read.
#'
#' @param files Character vector, paths to the `validation_by_clip.csv`
#'   files. Missing files
#'   are skipped with a warning.
#' @param candidates `NULL`, a character scalar (path) or a data frame. For
#'   the rounds of one design: the `candidates.csv` of the first round,
#'   passed to [combine_rounds()], which gives the clips
#'   their cumulative `inclusion_prob`. `NULL` only stacks the tables.
#'
#' @return A tibble with the columns of the validation tables; `night` and
#'   `recording_date` are character.
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' files <- list.files(file.path(ex, "validation"), full.names = TRUE)
#' basename(files)
#' val <- read_validation_tables(files)
#' table(val$site, val$verdict)
#' @export
read_validation_tables <- function(files, candidates = NULL) {
  if (!is.null(candidates)) {
    found <- file.exists(files)
    if (any(!found)) {
      warning("Not found: ", paste(files[!found], collapse = ", "))
    }
    return(combine_rounds(files[found], candidates))
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
#'   DiverSons project). The same night can then be in the training set for
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
#' @param validation A data frame of reviewed clips, one row per clip, as
#'   returned by [classify_review()],
#'   [post_validation()] (`$validation`) or [read_validation_tables()]. It
#'   needs `site`, `species_code`, `clip_file`, `verdict` and
#'   `reviewed_path` (the path where the review left each clip), and
#'   `night` for the splits by night.
#' @param output_dir Character scalar, path to the output folder; `train/`
#'   and, if any clip is held out,
#'   `test/` are created in it.
#' @param split Character scalar, one of `"site"`, `"night"`,
#'   `"site_species_night"` or `"none"`: how to split the clips into
#'   training and test sets; see Splits.
#' @param test_sites `NULL` or character vector, sites held out for testing
#'   with `split = "site"`.
#'   `NULL` puts every clip in `train/`.
#' @param test_prop Numeric scalar in (0, 1), proportion of the nights of
#'   each site (or site x
#'   species) drawn for the test set.
#' @param seed Numeric scalar, seed of the draws.
#' @param max_per_site_species `NULL` or integer scalar, maximum number of
#'   positive
#'   training clips per site x species. Larger sets are reduced by taking
#'   clips from the nights in turn, in random order, which keeps as many
#'   nights as possible. Test clips and negatives are not reduced.
#' @param exclude_from_test `NULL` or a data frame with `site` and `night`,
#'   one row per night (e.g.
#'   from [training_nights()]): nights that must not be in the test set,
#'   such as nights whose recordings trained another classifier that will
#'   be compared on it. They are left out of the draws of the test and
#'   validation sets and stay in the training set.
#' @param val_prop `NULL` or numeric scalar in (0, 1), proportion of the
#'   training nights of each site
#'   drawn for the validation set (`val/`); see Splits. `NULL` draws none.
#' @param val_seed Numeric scalar, seed of the validation draw. The
#'   default, `seed + 1`, is
#'   also the seed of `max_per_site_species`; the two draws are separate,
#'   and the default reproduces the training sets of the DiverSons project.
#' @param negatives Logical scalar. If `TRUE`, include the negative clips.
#' @param negatives_folder `NULL` or character scalar. `NULL` puts the
#'   negatives of each class in a
#'   `-<species_code>` folder. A non-event class of BirdNET-Analyzer
#'   (`"Noise"`, `"Other"`, `"Background"` or `"Silence"`) puts all of them
#'   in that folder instead; see Negatives.
#' @param min_files Numeric scalar, minimum number of positive training
#'   files per class
#'   below which a warning is raised.
#' @param copy Logical scalar. If `TRUE`, copy the clips; with `FALSE`, only
#'   `training_set.csv` is
#'   written, so that the split can be built on a computer without the
#'   clips and copied later.
#' @param remap_from,remap_to `NULL` or character scalars, prefix of
#'   `reviewed_path` and its
#'   replacement, for clips reviewed on another computer or drive.
#' @param strict Logical scalar. If `TRUE`, raise an error if any check is
#'   above 0.
#'
#' @return A tibble with one row per clip: `site`, `species_code`,
#'   `verdict`, `set` (`"train"`, `"val"` or `"test"`), `class_folder`,
#'   `clip_file`,
#'   `source_audio`, `clip_start`, `clip_end`, `from`, `to` and `night`,
#'   invisibly, with the checks in the attribute `"checks"`. With
#'   `copy = TRUE`, clips that could not be copied are left out.
#' @seealso [training_nights()], [exclude_training_clips()],
#'   `vignette("retraining")`.
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read_validation_tables(list.files(file.path(ex, "validation"),
#'                                          full.names = TRUE))
#' # Recreate the folders of a review in the BirdNET GUI, with empty files,
#' # and read back where each clip is (reviewed_path)
#' review_dir <- file.path(tempdir(), "clips_training")
#' dest <- file.path(review_dir, val$species_folder,
#'                   ifelse(val$verdict == "positive", "Positive", "Negative"))
#' for (d in unique(dest)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
#' invisible(file.create(file.path(dest, val$clip_file)))
#' reviewed <- classify_review(val[, setdiff(names(val),
#'                                           c("verdict", "reviewed_path"))],
#'                             review_dir)
#'
#' # Hold out one site for testing; copy = FALSE writes only training_set.csv
#' out_dir <- file.path(tempdir(), "birdnet_training")
#' ts <- build_training_set(reviewed, out_dir, split = "site",
#'                          test_sites = "NHE", min_files = 20,
#'                          copy = FALSE)
#' table(ts$set, ts$verdict)
#'
#' # Or a split by night, with all negatives in the non-event class "Noise"
#' ts_night <- build_training_set(reviewed, out_dir, split = "night",
#'                                test_prop = 0.2, negatives_folder = "Noise",
#'                                min_files = 20, copy = FALSE)
#' attr(ts_night, "checks")
#' unlink(c(review_dir, out_dir), recursive = TRUE)
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
  check_columns(validation,
                c("site", "species_code", "clip_file", "verdict",
                  "reviewed_path"),
                "validation")
  by_night <- split %in% c("night", "site_species_night")
  if ((by_night || !is.null(exclude_from_test)) &&
      !"night" %in% names(validation)) {
    stop("`validation` lacks the column `night`, needed by split = \"",
         split, "\" and `exclude_from_test`.", call. = FALSE)
  }
  if (by_night && (!is.numeric(test_prop) || length(test_prop) != 1 ||
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
  verdicts <- c("positive", if (negatives) "negative")
  clips <- validation |>
    filter(verdict %in% verdicts, !is.na(reviewed_path))
  if ("confidence" %in% names(clips)) {
    n_whole <- sum(is.na(clips$confidence))
    if (n_whole > 0) {
      message(n_whole, " whole-recording clip(s) (no confidence) left out.")
      clips <- filter(clips, !is.na(confidence))
    }
  }
  if (nrow(clips) == 0) stop("No reviewed clip to copy.")
  if (split == "site") {
    unknown <- setdiff(test_sites, unique(clips$site))
    if (length(unknown) > 0) {
      warning("Site(s) in `test_sites` without clips: ",
              paste(unknown, collapse = ", "))
    }
  }
  for (col in c("source_audio", "clip_start", "clip_end", "night")) {
    if (!col %in% names(clips)) clips[[col]] <- NA
  }
  clips$night <- as.character(clips$night)
  # species of the draw keys: species_folder when present (the order of
  # the groups enters the draw)
  clips$.sp <- if ("species_folder" %in% names(clips)) {
    clips$species_folder
  } else {
    clips$species_code
  }
  guard <- training_guard(exclude_from_test)

  clips$set <- with_training_seed(seed, split_sets(
    clips, split, test_sites, test_prop, guard))
  if (!is.null(max_per_site_species)) {
    n_before <- nrow(clips)
    clips <- with_training_seed(seed + 1,
                                cap_positives(clips, max_per_site_species))
    message("At most ", max_per_site_species, " positive training clips ",
            "per site x species: ", n_before, " -> ", nrow(clips), " clips.")
  }
  if (!is.null(val_prop)) {
    # on the training rows, in their order after the cap, like a second
    # call of the function
    is_train <- clips$set == "train"
    clips$set[is_train] <- if_else(
      with_training_seed(val_seed, split_sets(
        clips[is_train, ], "night", NULL, val_prop, guard)) == "test",
      "val", "train")
  }

  if (!is.null(remap_from) && !is.null(remap_to)) {
    clips$reviewed_path <- remap_path(clips$reviewed_path, remap_from,
                                      remap_to)
  }
  is_neg <- clips$verdict == "negative"
  class_dir <- if_else(is_neg, paste0("-", clips$species_code),
                       clips$species_code)
  dest_file <- clips$clip_file
  if (!is.null(negatives_folder)) {
    class_dir[is_neg] <- negatives_folder
    dest_file[is_neg] <- paste(str_extract(clips$species_code[is_neg],
                                           "[^_]+$"),
                               clips$site[is_neg],
                               clips$clip_file[is_neg], sep = "-")
  }
  copy_tab <- clips |>
    transmute(site, species_code, verdict, set, class_folder = class_dir,
              clip_file, source_audio, clip_start, clip_end,
              from = reviewed_path,
              to = file.path(output_dir, set, class_folder, dest_file),
              night)
  n_dup <- sum(duplicated(copy_tab$to))
  if (n_dup > 0) {
    warning(n_dup, " clip(s) share a destination with another clip and ",
            "would overwrite it.", call. = FALSE)
  }

  if (copy) {
    walk(unique(dirname(copy_tab$to)), dir.create, recursive = TRUE,
         showWarnings = FALSE)
    ok <- file.copy(copy_tab$from, copy_tab$to, overwrite = TRUE)
    if (!all(ok)) {
      warning(sum(!ok), " clip(s) could not be copied - check ",
              "`reviewed_path`.")
    }
    copy_tab <- copy_tab[ok, ]
  } else {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  few <- copy_tab |>
    filter(set == "train", verdict == "positive") |>
    count(species_code) |>
    right_join(distinct(copy_tab, species_code), by = "species_code") |>
    mutate(n = replace_na(n, 0L)) |>
    filter(n < min_files)
  if (nrow(few) > 0) {
    warning("Class(es) with fewer than ", min_files, " positive training ",
            "files: ", paste0(few$species_code, " (", few$n, ")",
                              collapse = ", "), call. = FALSE)
  }

  write_csv(copy_tab, file.path(output_dir, "training_set.csv"))
  message(nrow(copy_tab), " clips ", if (copy) "copied to " else
            "listed in training_set.csv (nothing copied) in ", output_dir,
          " (", sum(copy_tab$set == "train"), " train, ",
          if (!is.null(val_prop)) paste0(sum(copy_tab$set == "val"), " val, "),
          sum(copy_tab$set == "test"), " test).")
  checks <- training_checks(copy_tab, guard, with_val = !is.null(val_prop))
  if (any(copy_tab$set %in% c("test", "val"))) {
    message("Checks (all should be 0 with split = \"night\"):\n",
            paste0("  ", names(checks), ": ", checks,
                   collapse = "\n"))
    if (strict && any(checks > 0)) {
      stop("The test or validation set is not independent of the ",
           "training set (see the checks above).", call. = FALSE)
    }
  }
  attr(copy_tab, "checks") <- checks
  invisible(copy_tab)
}

#' Evaluate draws with their own seed
#'
#' Uses the default R generators and leaves the global generator as it was.
#'
#' @param seed Numeric scalar, the seed.
#' @param code Expression to evaluate.
#' @return The value of `code`.
#' @noRd
with_training_seed <- function(seed, code) {
  withr::with_seed(seed, code, .rng_kind = "Mersenne-Twister",
                   .rng_normal_kind = "Inversion",
                   .rng_sample_kind = "Rejection")
}

#' Nights that cannot go to the test set
#'
#' @param exclude_from_test `NULL` or a data frame with `site` and `night`.
#' @return `NULL`, or a tibble of distinct `site` x `night` as character.
#' @noRd
training_guard <- function(exclude_from_test) {
  if (is.null(exclude_from_test)) return(NULL)
  check_columns(exclude_from_test, c("site", "night"), "exclude_from_test")
  exclude_from_test |>
    filter(!is.na(site), !is.na(night)) |>
    transmute(site = as.character(site), night = as.character(night)) |>
    distinct()
}

#' Assign each clip to a set
#'
#' The draw follows the m3_treino.R script of the DiverSons project, line
#' by line.
#'
#' @param clips A data frame with `site`, `.sp` and `night`.
#' @param split Character scalar, `"none"`, `"site"`, `"night"` or
#'   `"site_species_night"`.
#' @param test_sites `NULL` or character vector of test sites.
#' @param test_prop Numeric scalar in (0, 1), proportion of nights drawn.
#' @param guard `NULL` or a data frame of `site` x `night` kept out of the
#'   test set.
#' @return Character vector, `"train"` or `"test"` per row of `clips`.
#' @noRd
split_sets <- function(clips, split, test_sites, test_prop, guard) {
  if (split == "none") return(rep("train", nrow(clips)))
  if (split == "site") {
    return(if_else(clips$site %in% test_sites, "test", "train"))
  }
  if (split == "site_species_night") {
    warning("split = \"site_species_night\" draws the nights within each ",
            "site x species: a night can be training data for one species ",
            "and test data for another, so the test set is not independent.",
            call. = FALSE)
    eligible <- distinct(clips, site, .sp, night)
    if (!is.null(guard)) {
      eligible <- anti_join(eligible, guard, by = c("site", "night"))
    }
    test_tab <- eligible |>
      group_by(site, .sp) |>
      mutate(.order = sample.int(n())) |>
      filter(n() >= 2, .order <= ceiling(n() * test_prop)) |>
      ungroup() |>
      select(site, .sp, night)
    key_cols <- c("site", ".sp", "night")
  } else {
    eligible <- distinct(clips, site, night)
    if (!is.null(guard)) {
      eligible <- anti_join(eligible, guard, by = c("site", "night"))
    }
    test_tab <- eligible |>
      group_by(site) |>
      mutate(.order = sample.int(n())) |>
      filter(.order <= ceiling(n() * test_prop)) |>
      ungroup() |>
      select(site, night)
    key_cols <- c("site", "night")
  }
  test_tab$.test <- TRUE
  marked <- left_join(clips[key_cols], test_tab, by = key_cols)$.test
  if_else(!is.na(marked), "test", "train")
}

#' Cap the positive training clips per site x species
#'
#' The nights give up one clip at a time, in random order.
#'
#' @param clips A data frame with `site`, `.sp`, `set`, `verdict` and
#'   `night`.
#' @param cap Integer scalar, maximum number of positive training clips.
#' @return `clips` with the excess positive training clips dropped.
#' @noRd
cap_positives <- function(clips, cap) {
  clips |>
    group_by(site, .sp, set, verdict) |>
    group_modify(function(d, g) {
      if (g$set != "train" || g$verdict != "positive" || nrow(d) <= cap) {
        return(d)
      }
      d |>
        group_by(night) |>
        mutate(.round = sample.int(n())) |>
        ungroup() |>
        mutate(.tiebreak = sample.int(n())) |>
        arrange(.round, .tiebreak) |>
        slice_head(n = cap) |>
        select(-.round, -.tiebreak)
    }) |>
    ungroup()
}

#' Non-event classes of BirdNET-Analyzer (NON_EVENT_CLASSES), label 0
#' @noRd
non_event_classes <- c("noise", "other", "background", "silence")

#' Count leaks between training and test (and validation) sets
#'
#' @param copy_tab A data frame with `site`, `night`, `set`,
#'   `species_code`, `source_audio`, `clip_start` and `clip_end`.
#' @param guard `NULL` or a data frame of excluded `site` x `night`.
#' @param with_val Logical scalar, add the validation checks?
#' @return Named integer vector of counts.
#' @noRd
training_checks <- function(copy_tab, guard, with_val = FALSE) {
  train_tab <- filter(copy_tab, set == "train")
  test_tab <- filter(copy_tab, set == "test")
  test_nights <- test_tab |>
    filter(!is.na(night)) |>
    distinct(site, night)
  n_overlap <- if (nrow(test_tab) > 0 && nrow(train_tab) > 0) {
    nrow(test_tab) - nrow(suppressMessages(suppressWarnings(
      exclude_training_clips(test_tab, train_tab))))
  } else {
    0L
  }
  out <- c(test_nights_in_train = nrow(semi_join(
      test_nights, distinct(train_tab, site, night), by = c("site", "night"))),
    test_nights_excluded = if (is.null(guard)) 0L else
      nrow(semi_join(test_nights, guard, by = c("site", "night"))),
    test_clips_overlapping_train = as.integer(n_overlap))
  if (!with_val) return(out)
  val_nights <- copy_tab |>
    filter(set == "val", !is.na(night)) |>
    distinct(site, night)
  c(out,
    val_nights_in_train = nrow(semi_join(
      val_nights, distinct(train_tab, site, night), by = c("site", "night"))),
    val_nights_excluded = if (is.null(guard)) 0L else
      nrow(semi_join(val_nights, guard, by = c("site", "night"))))
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
#' @param files Character vector, file names or paths of training clips.
#'   Elements that are
#'   folders are listed recursively.
#' @param pattern Character scalar, Perl regular expression with the named
#'   groups `site`,
#'   `date` (`YYYYMMDD`) and `time` (`HHMMSS`). The default takes the
#'   letters before the recorder number, the date and the time of names
#'   such as `ARA01_20211016_190000` or
#'   `..._ARA_ARA01_20230121_203000_12.0s_15.0s.wav`.
#' @param site_map `NULL` or a named character vector to fix diverging site
#'   names, e.g. `c(BEP2 = "BEP")`, as in [read_validations()].
#' @param night_cutoff Numeric scalar (hour, 0-23). Recordings that start
#'   before this hour belong to
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
  is_dir <- dir.exists(files)
  files <- c(files[!is_dir],
             unlist(lapply(files[is_dir], list.files, recursive = TRUE,
                           full.names = TRUE)))
  p <- recording_parts(files, pattern)
  if (any(!p$ok)) {
    dropped <- basename(files[!p$ok])
    warning(length(dropped), " file name(s) do not match `pattern` and were ",
            "left out: ", paste(utils::head(dropped, 5), collapse = ", "),
            if (length(dropped) > 5) ", ...", call. = FALSE)
  }
  p <- p[p$ok, ]
  dates <- as.Date(p$date, format = "%Y%m%d")
  hour <- as.integer(substr(p$time, 1, 2))
  out <- tibble(file = files[p$ok_index],
                site = rename_site(p$site, site_map),
                recording = p$recording,
                night = format(if_else(hour < night_cutoff, dates - 1, dates),
                               "%Y%m%d"))
  # the pattern goes with the table, for exclude_training_clips()
  attr(out, "pattern") <- pattern
  out
}

#' Default pattern of training_nights()
#' @noRd
recording_pattern <- paste0("(?<site>[A-Za-z]+)[A-Za-z0-9]*",
                            "_(?<date>\\d{8})_(?<time>\\d{6})")

#' Site, date and time of the source recording from file names
#'
#' @param files Character vector of file names or paths.
#' @param pattern Character scalar, Perl regular expression with the named
#'   groups `site`, `date` and `time`.
#' @return A tibble with `ok`, `ok_index`, `site`, `date`, `time` and
#'   `recording` (`site_date_time`), one row per file.
#' @noRd
recording_parts <- function(files, pattern = recording_pattern) {
  file_names <- basename(files)
  m <- regexpr(pattern, file_names, perl = TRUE)
  if (!all(c("site", "date", "time") %in% attr(m, "capture.names"))) {
    stop("`pattern` needs the named groups `site`, `date` and `time`.",
         call. = FALSE)
  }
  starts <- attr(m, "capture.start")
  lens <- attr(m, "capture.length")
  grab <- function(g) {
    out <- substring(file_names, starts[, g], starts[, g] + lens[, g] - 1)
    out[m < 0] <- NA_character_
    out
  }
  tibble(ok = m > 0, ok_index = seq_along(file_names), site = grab("site"),
         date = grab("date"), time = grab("time"),
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
#' @param manifest A data frame, the clip manifest (one row per clip), as
#'   returned by [select_clips()] or read
#'   from `clip_manifest.csv`.
#' @param training_set A data frame returned by [build_training_set()] or
#'   [training_nights()], or a character scalar, path to a
#'   `training_set.csv`.
#' @param level Character scalar, one of `"clip"`, `"recording"` or
#'   `"night"`: what a training clip excludes; see Levels.
#' @param any_species Logical scalar. If `TRUE`, exclude across species.
#' @param pattern `NULL` or character scalar. With a table of
#'   [training_nights()] and
#'   `level = "recording"`, the regular expression that reads the
#'   recordings from `source_audio`. By default, the one recorded in the
#'   table by [training_nights()] (lost if the table was rebuilt, e.g. by
#'   [dplyr::bind_rows()]), else the default of [training_nights()].
#'
#' @return The manifest without the excluded clips.
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' det <- read_selection_tables(file.path(ex, "birdnet"))
#' man <- select_clips(det, sampling_mode = "top", n_top = 1)
#'
#' # nights whose recordings were used to train the classifier, read from the
#' # names of its training clips
#' trained <- training_nights(c("ARA01_20211016_190000_3.0s_6.0s.wav",
#'                              "BAI01_20211020_220000_9.0s_12.0s.wav"))
#' man2 <- exclude_training_clips(man, trained, level = "night")
#' nrow(man) - nrow(man2)
#' @export
exclude_training_clips <- function(manifest, training_set,
                                   level = c("clip", "recording", "night"),
                                   any_species = FALSE, pattern = NULL) {
  level <- match.arg(level)
  if (is.character(training_set)) {
    training_set <- read_csv(training_set, show_col_types = FALSE)
  }
  from_nights <- "recording" %in% names(training_set) &&
    !"source_audio" %in% names(training_set)
  if (from_nights) {
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
    absent <- setdiff(c("site", "night"),
                      intersect(names(manifest), names(training_set)))
    if (length(absent) > 0) {
      stop("`manifest` and `training_set` both need `site` and `night` for ",
           "level = \"night\".", call. = FALSE)
    }
    train_tab <- training_set |>
      filter(!is.na(night)) |>
      transmute(across(all_of(sp)), site = as.character(site),
                night = as.character(night)) |>
      distinct()
    key_cols <- c(sp, "site", "night")
    target <- mutate(manifest, site = as.character(site),
                     night = as.character(night))
  } else if (from_nights) {
    train_tab <- distinct(training_set, .rec = recording)
    key_cols <- ".rec"
    target <- manifest
    if (is.null(pattern)) {
      pattern <- attr(training_set, "pattern")
      if (is.null(pattern)) pattern <- recording_pattern
    }
    target$.rec <- recording_parts(manifest$source_audio, pattern)$recording
    if (all(is.na(target$.rec))) {
      warning("No `source_audio` of the manifest matches `pattern`; ",
              "nothing excluded. Give the pattern used in ",
              "training_nights().", call. = FALSE)
      return(manifest)
    }
  } else {
    train_tab <- training_set |>
      filter(!is.na(source_audio), !is.na(clip_start)) |>
      distinct(across(all_of(sp)), source_audio, t_start = clip_start,
               t_end = clip_end)
    key_cols <- c(sp, "source_audio")
    target <- manifest
    if (level == "recording") {
      train_tab <- distinct(train_tab, across(all_of(key_cols)))
    }
  }
  if (nrow(train_tab) == 0) {
    warning("`training_set` has no ",
            if (level == "night") "site/night" else "source_audio/clip_start",
            "; nothing excluded.")
    return(manifest)
  }
  joined <- target |>
    mutate(.row = row_number()) |>
    inner_join(train_tab, by = key_cols, relationship = "many-to-many")
  if (level == "clip") joined <- filter(joined, clip_start < t_end,
                                        clip_end > t_start)
  dropped <- unique(joined$.row)
  message(length(dropped), " clip(s) sharing a ", level, " with the training ",
          "clips left out of the manifest.")
  if (length(dropped) == 0) return(manifest)
  manifest[-dropped, ]
}
