write_lines_tmp <- function(lines, dir = withr::local_tempdir(.local_envir = parent.frame())) {
  f <- file.path(dir, "predictions.csv")
  writeLines(lines, f)
  f
}

test_that("the three Perch headers are read with logits turned into confidences", {
  hoplite <- write_lines_tmp(c(
    "idx,project,filename,window_start,window_end,label,logits",
    "1,proj,A/A_20240110_200000.wav,0.0,5.0,Boana raniceps,2.0",
    "2,proj,A/A_20240110_200000.wav,5.0,10.0,Boana raniceps,-3.0",
    "3,proj,B/B_20240111_210000.wav,10.0,15.0,\"Scinax x-signatus\",0.5"))
  h <- suppressMessages(read_classifier_output(hoplite, "perch"))
  # -3 is a confidence of 0.047, below the default 0.1
  expect_identical(nrow(h), 2L)
  expect_equal(h$confidence, stats::plogis(c(2, 0.5)))
  expect_equal(h$score, c(2, 0.5))
  expect_identical(h$site, c("A", "B"))
  expect_identical(h$species_code,
                   c("Boana raniceps_boana-raniceps",
                     "Scinax x-signatus_scinax-x-signatus"))
  expect_identical(folder_name(h$species_code),
                   c("boana_raniceps", "scinax_x_signatus"))
  expect_equal(h$file_offset, h$begin_time)
  expect_identical(unique(h$classifier), "perch")

  old <- write_lines_tmp(c(
    "idx,dataset_name,source_id,offset,label,logits",
    "1,ds,A/A_20240110_200000.wav,60.0,sp1,1.0"))
  o <- suppressMessages(read_classifier_output(old, "perch", window_s = 3))
  expect_equal(c(o$begin_time, o$end_time), c(60, 63))

  chirp <- write_lines_tmp(c(
    "filename, timestamp_s, label, logit",
    "A/A_20240110_200000.wav,25.00,sp1,0.00"))
  ch <- suppressMessages(read_classifier_output(chirp, "perch"))
  expect_equal(c(ch$begin_time, ch$end_time, ch$confidence), c(25, 30, 0.5))

  holes <- write_lines_tmp(c(
    "filename, timestamp_s, label, logit",
    "A/A_20240110_200000.wav,25.00,sp1,1.00",
    "A/A_20240110_200000.wav,,sp1,1.00"))
  expect_message(read_classifier_output(holes, "perch"),
                 "1 row\\(s\\) without a file, time, label or score left out")
  bad <- write_lines_tmp(c("a,b,c", "1,2,3"))
  expect_error(read_classifier_output(bad, "perch"),
               "is not a Perch inference CSV")
})

test_that("OpenSoundscape wide tables become one row per class and window", {
  f <- write_lines_tmp(c(
    "file,start_time,end_time,Ovenbird,Wood Thrush",
    "S1/S1_20240110_200000.wav,0.0,3.0,-3.4,0.1",
    "S1/S1_20240110_200000.wav,3.0,6.0,1.5,-0.2",
    "S2/S2_20240110_200000.wav,,,,"))
  expect_message(o <- read_classifier_output(f, "opensoundscape",
                                             min_confidence = 0.4),
                 "1 window\\(s\\) without scores \\(audio that could not be read\\)")
  expect_identical(nrow(o), 3L)
  expect_setequal(o$label, c("Ovenbird", "Wood Thrush"))
  expect_equal(sort(o$score), c(-0.2, 0.1, 1.5))
  expect_identical(unique(o$site), "S1")
  expect_true(all(o$confidence >= 0.4))
  expect_identical(o$species_code[o$label == "Wood Thrush"][1],
                   "Wood Thrush_wood-thrush")

  expect_error(read_classifier_output(f, "opensoundscape",
                                      score_scale = "probability"),
               "look like logits")
  p <- write_lines_tmp(c(
    "file,start_time,end_time,sp1",
    paste0("S1/S1_20240110_200000.wav,", 0:11 * 3, ",", 1:12 * 3, ",",
           seq(0.05, 0.6, by = 0.05))))
  expect_message(read_classifier_output(p, "opensoundscape"),
                 "use score_scale = \"probability\"")
  pr <- suppressMessages(read_classifier_output(p, "opensoundscape",
                                                score_scale = "probability"))
  expect_equal(sort(pr$confidence), seq(0.1, 0.6, by = 0.05))
  no_class <- write_lines_tmp(c("file,start_time,end_time", "S1/a.wav,0,3"))
  expect_error(read_classifier_output(no_class, "opensoundscape"),
               "has no class columns")
  nope <- write_lines_tmp(c("file,offset,sp1", "a.wav,0,1"))
  expect_error(read_classifier_output(nope, "opensoundscape"),
               "lacks start_time, end_time")
})

test_that("sites, audio roots and folders of files are handled", {
  d <- withr::local_tempdir()
  dir.create(file.path(d, "runs"))
  writeLines(c("filename, timestamp_s, label, logit",
               "rec_Campus01_20240110_200000.wav,0,sp1,3"),
             file.path(d, "runs", "a.csv"))
  writeLines(c("filename, timestamp_s, label, logit",
               "rec_Campus02_20240110_200000.wav,0,sp1,3"),
             file.path(d, "runs", "b.csv"))
  expect_error(suppressMessages(read_classifier_output(d, "perch")),
               "give `site_pattern`")
  x <- suppressMessages(read_classifier_output(
    d, "perch", site_pattern = "^[^_]+_([^_]+)_", audio_root = "/audio/"))
  expect_identical(x$site, c("Campus01", "Campus02"))
  expect_identical(x$begin_path[1], "/audio/rec_Campus01_20240110_200000.wav")
  expect_error(read_classifier_output(file.path(d, "none.csv"), "perch"),
               "Not found")
  expect_error(read_classifier_output(withr::local_tempdir(), "perch"),
               "No .csv file found")
  expect_error(suppressMessages(read_classifier_output(
    d, "perch", site_pattern = "^[^_]+_([^_]+)_", min_confidence = 0.99)),
    "No prediction at or above")
  expect_error(read_classifier_output(d, "perch", audio_root = c("a", "b")),
               "single path")
})

test_that("score_detections() takes a table of predictions like the paths", {
  val <- suppressMessages(read_validations(
    ref_path("cal", paste0("validacao_por_clipe_", c("ARA", "XAR2", "BAI"),
                           ".csv")), site_map = c(XAR2 = "XAR")))
  fit <- fit_calibration(val, calibration_models()$m0_global)
  path <- file.path(sim_root(), "tabelas/output_ARA/BirdNET_SelectionTable.txt")
  by_path <- suppressMessages(score_detections(c(ARA = path), fit))
  tab <- suppressMessages(read_selection_tables(dirname(path)))
  expect_message(by_table <- score_detections(tab, fit),
                 "Scoring the predictions of ARA")
  expect_equal(by_table, by_path)
  expect_error(score_detections(tab[, c("site", "confidence")], fit),
               "lacks the column")
  expect_error(score_detections(1:3, fit), "data frame of predictions")
})
