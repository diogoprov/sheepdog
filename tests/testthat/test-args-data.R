# Argument checks of the data, review and export functions (autotest
# findings: scalar arguments given as vectors, flags given as numbers or
# strings, and column names that are not in the input table).

test_that("app_verdicts() checks its paths and reviewer", {
  man <- system.file("extdata", "clip_manifest.csv", package = "sheepdog")
  expect_error(app_verdicts(man, c("a.csv", "b.csv")),
               "`verdicts_file` must be a single character string")
  expect_error(app_verdicts(man, "a.csv", clips_dir = 1),
               "`clips_dir` must be a single character string")
  expect_error(app_verdicts(man, "a.csv", reviewer = c("ana", "bia")),
               "`reviewer` must be a single character string")
})

test_that("cell_status() checks min_n", {
  expect_error(cell_status(NULL, data.frame(), min_n = c(10, 20)),
               "`min_n` must be a number of at least 0")
  expect_error(cell_status(NULL, data.frame(), min_n = -1),
               "`min_n` must be a number of at least 0")
})

test_that("community_matrices() checks min_nights_month and drop_empty", {
  h <- data.frame(site = "A", night = "20211001", species = "boa_ran",
                  detection_k2 = 1L)
  expect_error(community_matrices(h, "boa_ran", min_nights_month = c(5, 6)),
               "`min_nights_month` must be a number of at least 0")
  expect_error(community_matrices(h, "boa_ran", drop_empty = 1L),
               "`drop_empty` must be TRUE or FALSE")
  expect_error(community_matrices(h, "boa_ran", drop_empty = "yes"),
               "`drop_empty` must be TRUE or FALSE")
})

test_that("build_community_matrices() checks min_nights_month", {
  expect_error(build_community_matrices("h.csv", tempdir(), "boa_ran",
                                        min_nights_month = c(5, 6)),
               "`min_nights_month` must be a number of at least 0")
})

test_that("covariate_bins() checks var, name, n_bins and within", {
  x <- data.frame(site = rep(c("A", "B"), each = 4),
                  night = rep(sprintf("202110%02d", 1:4), 2),
                  temp = 1:8)
  expect_error(covariate_bins(x, c("temp", "site")),
               "`var` must be a single character string")
  expect_error(covariate_bins(x, "temp", name = c("a", "b")),
               "`name` must be a single character string")
  expect_error(covariate_bins(x, "temp", n_bins = c(2, 3)),
               "`n_bins` must be a whole number of at least 2")
  expect_error(covariate_bins(x, "temp", n_bins = 2.5),
               "`n_bins` must be a whole number of at least 2")
  expect_error(covariate_bins(x, "temp", within = "habitat"),
               "`within` names column\\(s\\) not in `covariates`: habitat")
  expect_error(covariate_bins(x, "temp", within = 1),
               "`within` must be `NULL` or a character vector")
  # several columns are allowed in `within`
  x$grp <- rep(c("u", "v"), 4)
  b <- covariate_bins(x, "temp", n_bins = 2, within = c("site", "grp"))
  expect_s3_class(b$temp_bin, "ordered")
})

test_that("cut_clips() checks the manifest, output_dir and simulate", {
  man <- data.frame(species_folder = "boa_ran", clip_file = "c1.wav",
                    clip_start = 0, duration = 3, source_audio = "x.wav",
                    begin_path = "x.wav")
  d <- file.path(tempdir(), "args_cut")
  expect_error(cut_clips(list(a = 1), d), "`manifest` must be a data frame")
  expect_error(cut_clips(man[-1], d),
               "`manifest` lacks the column\\(s\\): species_folder")
  expect_error(cut_clips(man, c(d, d), simulate = TRUE),
               "`output_dir` must be a single character string")
  expect_error(cut_clips(man, d, simulate = 1L),
               "`simulate` must be TRUE or FALSE")
})

test_that("extract_validation_clips() checks its scalar arguments", {
  ex <- system.file("extdata", "example", package = "sheepdog")
  b <- file.path(ex, "birdnet")
  d <- file.path(tempdir(), "args_extract")
  expect_error(extract_validation_clips(b, c(d, d)),
               "`output_dir` must be a single character string")
  expect_error(extract_validation_clips(b, d, make_zip = "no"),
               "`make_zip` must be TRUE or FALSE")
  expect_error(extract_validation_clips(b, d, simulate = 0L),
               "`simulate` must be TRUE or FALSE")
  expect_error(extract_validation_clips(b, d, classifier = c("a", "b")),
               "`classifier` must be a single character string")
})

test_that("confuser_summary() checks the verdicts counted", {
  val <- data.frame(species_code = "boa_ran", verdict = "negative",
                    identity = "insect")
  expect_error(confuser_summary(val, verdicts = "maybe"),
               "`verdicts` must be one or more of")
  expect_error(confuser_summary(val, verdicts = character()),
               "`verdicts` must be one or more of")
  # several verdicts are allowed
  expect_s3_class(confuser_summary(val, c("negative", "uncertain")), "tbl_df")
})

test_that("list_recordings() checks its patterns", {
  expect_error(list_recordings(tempdir(), audio_pattern = c("wav", "flac")),
               "`audio_pattern` must be a single character string")
  expect_error(list_recordings(tempdir(), site_pattern = c("a", "b")),
               "`site_pattern` must be a single character string")
})

test_that("read_pamdp() checks audio_root", {
  expect_error(read_pamdp(tempdir(), audio_root = c("a", "b")),
               "`audio_root` must be a single character string")
})

test_that("read_selection_tables() checks its folder and patterns", {
  ex <- system.file("extdata", "example", package = "sheepdog")
  b <- file.path(ex, "birdnet")
  expect_error(read_selection_tables(c(b, b)),
               "`data_dir` must be a single character string")
  expect_error(read_selection_tables(b, table_pattern = c("a", "b")),
               "`table_pattern` must be a single character string")
  expect_error(read_selection_tables(b, per_audio_pattern = c("a", "b")),
               "`per_audio_pattern` must be a single character string")
  expect_error(read_selection_tables(b, site_pattern = c("a", "b")),
               "`site_pattern` must be a single character string")
})

test_that("assign_reviewers() checks overlap and seed", {
  man <- read.csv(system.file("extdata", "clip_manifest.csv",
                              package = "sheepdog"))
  expect_error(assign_reviewers(man, c("ana", "bia"), seed = c(1, 2)),
               "`seed` must be a whole number")
  expect_error(assign_reviewers(man, c("ana", "bia"), overlap = c(0.1, 0.2)),
               "`overlap` must be a number between 0 and 1")
})

test_that("training_nights() checks night_cutoff", {
  f <- "ARA01_20211016_190000_3.0s_6.0s.wav"
  expect_error(training_nights(f, night_cutoff = c(12, 13)),
               "`night_cutoff` must be a number between 0 and 23")
  expect_error(training_nights(f, night_cutoff = 25),
               "`night_cutoff` must be a number between 0 and 23")
})
