#' @srrstats {G5.2b} Every progress message, note and the remaining errors and warnings are triggered and their text checked.
#' @noRd
NULL

# Each test runs a cheap call, captures its messages and matches them,
# including a value (a count, a mode, a folder) where the message has one.
# The patterns keep a literal piece of each message so that
# dev/ropensci-stats/conditions.R can tie them to the code.

msgs_of <- function(expr) {
  out <- NULL
  suppressWarnings(out <- testthat::capture_messages(expr))
  out
}

test_that("calibrate() reports the model, the scoring, the effort curve and the outputs", {
  skip_if_not_installed("lme4")
  raiz <- sim_root()
  saida <- withr::local_tempdir()
  tab <- file.path(raiz, "tabelas/output_ARA/BirdNET_SelectionTable.txt")
  m <- msgs_of(calibrate(
    validation_files = ref_path("cal", "validacao_por_clipe_ARA.csv"),
    prediction_tables = c(ARA = tab), output_dir = saida, k_folds = 2,
    effort_curve = TRUE, effort_n = 5, effort_reps = 2))
  expect_match(m, "^Selected model \\(one_se_logloss\\): m\\d", all = FALSE)
  expect_match(m, "^Scoring \\w* \\(.*\\)\\.\\.\\.", all = FALSE)
  expect_true(any(startsWith(m, paste0("Scoring ARA (", tab, ")..."))))
  expect_match(m, "^Effort curve \\(2 repetitions per n\\)\\.\\.\\.",
               all = FALSE)
  expect_match(m, paste0("^Done! Outputs in .*\nnightly_detection_history",
                         "\\.csv is the input of the analyses"), all = FALSE)
  expect_match(m, "the column 'detection' uses k = 1;", all = FALSE, fixed = TRUE)
})

test_that("fit_calibration() passes on the lme4 messages that are not about singular fits", {
  skip_if_not_installed("lme4")
  # sheepdog rejects rank-deficient fixed effects before the fit, so glmer()
  # is wrapped to add a non-singular message to those of the real fit
  glmer_real <- lme4::glmer
  local_mocked_bindings(
    glmer = function(...) {
      message("a note from lme4")
      glmer_real(...)
    }, .package = "lme4")
  val <- sim_calibration(n = 300, n_species = 4, sd_species = 0.8)
  m <- msgs_of(fit <- fit_calibration(val, tp ~ logit_conf + (1 | species)))
  expect_match(m, "^lme4: ", all = FALSE)
  expect_true("lme4: a note from lme4\n" %in% m)
  expect_false(any(grepl("singular", m)))
  expect_true("a note from lme4" %in% attr(fit, "sheepdog_messages"))
})

test_that("app_verdicts() counts the clips of the review queue", {
  d <- withr::local_tempdir()
  man <- tibble::tibble(
    site = "A", species_code = "Sp a", species_folder = "sp_a",
    clip_file = paste0("clip", 1:3, ".wav"))
  f <- file.path(d, "verdicts.csv")
  append_verdict(f, "clip1.wav", "sp_a", "ana", "positive")
  append_verdict(f, "clip2.wav", "sp_a", "ana", "negative")
  m <- msgs_of(app_verdicts(man, f, reviewer = "ana"))
  expect_match(m, "^Clips in the review queue: 3\n", all = FALSE)
  expect_match(m, "  not_reviewed: 1", all = FALSE, fixed = TRUE)
  expect_match(m, "  positive: 1", all = FALSE, fixed = TRUE)
})

test_that("classify_review() and post_validation() report the clips and the outputs", {
  d <- withr::local_tempdir()
  man <- tibble::tibble(
    site = "A", species_code = "Sp a", species_folder = "sp_a",
    clip_file = paste0("clip", 1:3, ".wav"), confidence = c(0.6, 0.7, 0.8),
    night = "20211001", recording_hour = 20, sampling_mode = "top",
    source_audio = "rec.wav")
  dir.create(file.path(d, "review", "sp_a", "Positive"), recursive = TRUE)
  dir.create(file.path(d, "review", "sp_a", "Negative"), recursive = TRUE)
  file.create(file.path(d, "review", "sp_a", "Positive", "clip1.wav"))
  file.create(file.path(d, "review", "sp_a", "Negative", "clip2.wav"))
  m <- msgs_of(classify_review(man, file.path(d, "review")))
  expect_match(m, "^Clips in the manifest: 3\n", all = FALSE)
  expect_match(m, "  clip_missing: 1", all = FALSE, fixed = TRUE)

  f <- file.path(d, "verdicts.csv")
  append_verdict(f, "clip1.wav", "sp_a", "ana", "positive")
  append_verdict(f, "clip1.wav", "sp_a", "bia", "negative")
  append_verdict(f, "clip2.wav", "sp_a", "bia", "positive")
  saida <- file.path(d, "pv")
  m <- msgs_of(post_validation(manifest_path = man, output_dir = saida,
                               verdicts_file = f, min_n = 1))
  expect_match(
    m, "^Clips reviewed by more than one reviewer are combined with consensus_verdicts\\(\\)\\.",
    all = FALSE)
  expect_match(m, "^Done! Results in .*pv", all = FALSE)
})

test_that("build_community_matrices() reports where the files are", {
  saida <- withr::local_tempdir()
  m <- msgs_of(build_community_matrices(
    ref_path("mat", "historico_simulado.csv"), saida,
    core_species = c("boa_ran", "den_nan"), k_min = 1))
  expect_match(m, "^Files in: ", all = FALSE)
  expect_true(any(grepl(saida, m, fixed = TRUE)))
})

test_that("cut_clips() and pack_clips() report the clips and packages", {
  d <- withr::local_tempdir()
  wav <- file.path(d, "S01_20220110_190000.wav")
  file.create(wav)
  man <- tibble::tibble(
    site = "S", species_code = "Boana raniceps_boa-ran",
    species_folder = "boa_ran", clip_file = c("c1.wav", "c2.wav"),
    clip_start = 1, duration = 2,
    source_audio = c(wav, file.path(d, "nao_existe.wav")),
    begin_path = c(wav, file.path(d, "nao_existe.wav")),
    sampling_mode = "top")
  m <- msgs_of(cut_clips(man, d, simulate = TRUE))
  expect_match(m, "^Simulating the cut of 2 clips\\.\\.\\.", all = FALSE)
  expect_match(m, "^  \\w*: \\d*", all = FALSE)
  expect_match(m, "  simulated: 1", all = FALSE, fixed = TRUE)
  expect_match(m, "  audio_not_found: 1", all = FALSE, fixed = TRUE)

  dir.create(file.path(d, "clips", "boa_ran"), recursive = TRUE,
             showWarnings = FALSE)
  file.create(file.path(d, "clips", "boa_ran", "c1.wav"))
  m <- msgs_of(pack_clips(man, d))
  expect_match(m, "^Package \\S*: [0-9.]* MB", all = FALSE)
  expect_match(m, "^Package boa_ran\\.zip: 0 MB", all = FALSE)
})

test_that("join_occasion_covariates() warns about rows matching no occasion", {
  oc <- tibble::tibble(site = "A", occasion_id = c("o1", "o2"), night = "1")
  expect_warning(
    join_occasion_covariates(
      oc, tibble::tibble(site = "A", occasion_id = c("o1", "o8", "o9"),
                         temp = 1:3), NULL, NULL),
    "^2 row\\(s\\) of `occasion_covariates` match no occasion\\.$")
})

test_that("join_identities() counts the negative clips with an identity", {
  val <- tibble::tibble(
    clip_file = paste0("c", 1:3, ".wav"), species_code = "Sp a",
    verdict = c("negative", "negative", "negative"))
  ext <- tibble::tibble(clip = c("c1.wav", "c2.wav"),
                        id_correta = c("insect", "rain"))
  expect_message(join_identities(val, ext, identity_col = "id_correta"),
                 "^2 of 3 negative clip\\(s\\) with an identity\\.")
})

test_that("list_recordings() counts the audio files of the predictions in the list", {
  d <- withr::local_tempdir()
  dir.create(file.path(d, "ARA"))
  aud <- file.path(d, "ARA", c("ARA01_20211001_190000.wav",
                               "ARA01_20211001_200000.wav"))
  file.create(aud)
  pred <- tibble::tibble(begin_path = c(aud[1], aud[1], aud[2]))
  m <- msgs_of(list_recordings(d, predictions = pred))
  expect_match(m, "^2 recordings listed at 1 site\\(s\\)\\.", all = FALSE)
  expect_match(m, "^2 of 2 audio files of the predictions are in the list\\.",
               all = FALSE)
})

test_that("read_pamdp() reports the observations left out", {
  dir <- withr::local_tempdir()
  utils::write.csv(data.frame(
    deploymentID = "d1", locationID = "ARA", latitude = -20,
    longitude = -54, deploymentStart = "2021-10-01T18:00:00-04:00",
    deploymentEnd = "2021-10-02T06:00:00-04:00"),
    file.path(dir, "deployments.csv"), row.names = FALSE)
  utils::write.csv(data.frame(
    mediaID = "m1", deploymentID = "d1",
    timestamp = "2021-10-01T19:00:00-04:00",
    filePath = "ARA/ARA01_20211001_190000.wav", filePublic = FALSE,
    fileMediatype = "audio/wav", sampleRate = 48000, bitDepth = 16,
    fileLength = 60, numChannels = 1),
    file.path(dir, "media.csv"), row.names = FALSE)
  utils::write.csv(data.frame(
    observationID = paste0("o", 1:4), deploymentID = "d1",
    mediaID = c("m1", "m1", "m9", "m8"), eventStart = c(3, 0, 1, 2),
    eventEnd = c(6, 60, 4, 5), observationLevel = "event",
    observationType = c("animal", "rain", "animal", "animal"),
    scientificName = c("Boana raniceps", NA, "Boana raniceps",
                       "Boana raniceps"),
    classificationMethod = "machine", classifiedBy = "BirdNET 2.4",
    classificationProbability = c(0.9, 0.6, 0.5, 0.4)),
    file.path(dir, "observations.csv"), row.names = FALSE)
  m <- msgs_of(read_pamdp(dir))
  expect_match(m, "^1 other observation\\(s\\) left out \\(not of a classifier, ",
               all = FALSE)
  expect_match(m, "^2 prediction\\(s\\) without a media file in media\\.csv left out\\.",
               all = FALSE)
})

test_that("read_selection_tables() lists the tables found in each folder", {
  m <- msgs_of(read_selection_tables(file.path(sim_root(), "tabelas")))
  expect_match(m, "^3 combined table\\(s\\) and 0 per-audio table\\(s\\)",
               all = FALSE)
  expect_match(m, "^  - .*: ", all = FALSE)
  expect_match(m, "^  - .*output_ARA: BirdNET_SelectionTable\\.txt",
               all = FALSE)
})

# Recordings of 60 s at two sites, one species, two predictions each
msg_pred <- function() {
  grade <- expand.grid(rec = c("A_20240101_200000", "A_20240102_200000",
                               "A_20240103_200000", "A_20240104_010000",
                               "B_20240101_200000"),
                       t = c(0, 30), stringsAsFactors = FALSE)
  tibble::tibble(site = substr(grade$rec, 1, 1),
                 species_code = "Sp_one", confidence = 0.8,
                 begin_path = paste0("/audio/", grade$rec, ".wav"),
                 file_offset = grade$t, begin_time = grade$t,
                 end_time = grade$t + 3)
}

test_that("select_clips() reports the mode, the pilot sites and the time windows", {
  pred <- msg_pred()
  m <- msgs_of(select_clips(pred, "top", sites = "A", hour_start = 19,
                            hour_end = 21, alternate_days = TRUE,
                            date_start = "20240101", date_end = "20240102"))
  expect_match(m, "^Pilot: processing only A \\(8 predictions\\)\\.",
               all = FALSE)
  expect_match(m, "^Sampling mode: top \\(occasion = file\\)\\.", all = FALSE)
  expect_match(m, "^Hour window 19h-21h: 8 -> 6 predictions\\.", all = FALSE)
  expect_match(m, "^Alternate days: 6 -> 4 predictions\\.", all = FALSE)
  expect_match(m, "^Date window 20240101-20240102: 4 -> 2 predictions\\.",
               all = FALSE)
  expect_error(
    suppressMessages(select_clips(pred, "top", hour_start = 5, hour_end = 6)),
    "^No predictions within the hour window\\.")
  expect_error(
    suppressMessages(select_clips(pred, "top", date_start = "20250101")),
    "^No predictions within the date window\\.")
})

test_that("select_clips() notes the earlier rounds and the overlaps with an earlier review", {
  pred <- msg_pred()
  draw <- function(...) {
    select_clips(pred, "random_detections", threshold = 0.5,
                 strata = "site_species", n_top = 1, ...)
  }
  r1 <- suppressMessages(draw())
  suppressMessages(expect_message(draw(previous = r1, candidates = attr(r1, "candidates")),
                 "^`previous`: earlier rounds of this design, so their occasions leave the pool\\."))
  rec <- suppressMessages(select_clips(
    pred, "random_recordings", n_recordings_per_site = 100,
    recordings = unique(data.frame(site = pred$site,
                                   source_audio = pred$begin_path)),
    recording_duration = 60))
  rec$verdict <- "negative"
  m <- msgs_of(draw(previous = rec, inherit = TRUE))
  expect_match(
    m, "^\\d+ clip\\(s\\) overlap an earlier review; \\d+ inherit its verdict and need no review\\.",
    all = FALSE)
})

test_that("select_directed() reports the clips drawn, the units and the earlier rounds", {
  pred <- sim_pred()
  un <- pred |>
    dplyr::distinct(site, species_code) |>
    dplyr::mutate(size = seq_len(dplyr::n()))
  m <- msgs_of(sel <- select_directed(pred, un, n_units = 100,
                                      threshold = 0.5))
  expect_match(m, "^\\d+ clips from \\d+ unit\\(s\\) drawn of \\d+ \\(round 1\\)\\.",
               all = FALSE)
  expect_true(sprintf("%d clips from %d unit(s) drawn of %d (round 1).\n",
                      nrow(sel), nrow(un), nrow(un)) %in% m)
  expect_match(m, "^Only \\d+ unit\\(s\\) can be drawn; all of them are taken\\.",
               all = FALSE)
  expect_true(sprintf("Only %d unit(s) can be drawn; all of them are taken.\n",
                      nrow(un)) %in% m)
  m <- msgs_of(select_directed(pred, un, n_units = 2, threshold = 0.5,
                               previous = sel))
  expect_match(
    m, "^\\d+ prediction\\(s\\) >= 0\\.5 already reviewed in `previous` left out\\.",
    all = FALSE)
  expect_true(sprintf(
    "%d prediction(s) >= 0.5 already reviewed in `previous` left out.\n",
    nrow(sel)) %in% m)
})

test_that("build_training_set() and exclude_training_clips() report the clips", {
  d <- withr::local_tempdir()
  val <- read_validation_tables(list.files(
    system.file("extdata", "example", "validation", package = "sheepdog"),
    full.names = TRUE))
  dest <- file.path(d, "review", val$species_folder,
                    ifelse(val$verdict == "positive", "Positive", "Negative"))
  for (x in unique(dest)) dir.create(x, recursive = TRUE)
  file.create(file.path(dest, val$clip_file))
  rev <- suppressMessages(classify_review(
    dplyr::select(val, -verdict, -reviewed_path), file.path(d, "review")))
  m <- msgs_of(ts <- build_training_set(rev, file.path(d, "t"),
                                        test_sites = "NHE", copy = FALSE))
  expect_match(m, "^\\d+ clips listed in training_set\\.csv \\(nothing copied\\) in ",
               all = FALSE)
  expect_true(any(startsWith(m, paste(nrow(ts), "clips listed in"))))
  expect_match(m, 'Checks \\(all should be 0 with split = "night"\\):',
               all = FALSE)

  man <- tibble::tibble(
    species_code = c("a", "a", "a", "b"),
    source_audio = c("x.wav", "x.wav", "y.wav", "x.wav"),
    clip_start = c(0, 6, 0, 0), clip_end = c(3, 9, 3, 3))
  treino <- tibble::tibble(species_code = "a", source_audio = "x.wav",
                           clip_start = 1.5, clip_end = 4.5)
  expect_message(exclude_training_clips(man, treino),
                 "^1 clip\\(s\\) sharing a clip with the training clips left out of the manifest\\.")
})

test_that("missing suggested packages are reported, not fatal", {
  skip_if_not_installed("lme4")
  local_mocked_bindings(has_suggested = function(pkg) FALSE)
  raiz <- sim_root()
  saida <- withr::local_tempdir()
  tab <- file.path(raiz, "tabelas/output_ARA/BirdNET_SelectionTable.txt")
  m <- msgs_of(calibrate(
    validation_files = ref_path("cal", "validacao_por_clipe_ARA.csv"),
    prediction_tables = c(ARA = tab), output_dir = saida, k_folds = 2))
  expect_match(m, "^Package 'ggplot2' not installed: calibration_curves.png was not drawn",
               all = FALSE)
  expect_false(file.exists(file.path(saida, "calibration_curves.png")))

  d <- withr::local_tempdir()
  man <- tibble::tibble(
    site = "A", species_code = "Sp a", species_folder = "sp_a",
    clip_file = paste0("clip", 1:2, ".wav"), confidence = c(0.6, 0.8),
    night = "20211001", recording_hour = 20, sampling_mode = "top",
    source_audio = "rec.wav")
  f <- file.path(d, "verdicts.csv")
  append_verdict(f, "clip1.wav", "sp_a", "ana", "positive")
  append_verdict(f, "clip2.wav", "sp_a", "ana", "negative")
  m <- msgs_of(post_validation(manifest_path = man, output_dir = file.path(d, "pv"),
                               verdicts_file = f, min_n = 1))
  expect_match(m, "^Package 'ggplot2' not installed: precision_by_bin.png ",
               all = FALSE)

  val <- tibble::tibble(site = "A", species_folder = "sp",
                        confidence = seq(0.1, 0.99, length.out = 60),
                        verdict = rep(c("negative", "positive"), 30))
  m <- msgs_of(compare_calibration_curves(
    val, curves = c("logistic", "monotone_gam"), cv = FALSE))
  expect_match(m, "^Package scam is not installed: the monotone GAM is left out\\. ",
               all = FALSE)
})
