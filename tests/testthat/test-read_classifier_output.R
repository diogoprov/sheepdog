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
  low <- write_lines_tmp(c(
    "file,start_time,end_time,sp1,sp2",
    "S1/S1_20240110_200000.wav,0,3,-5,2",
    "S1/S1_20240110_200000.wav,3,6,-6,-4"))
  lo <- suppressMessages(read_classifier_output(low, "opensoundscape"))
  expect_identical(lo$label, "sp2")
  expect_error(suppressMessages(read_classifier_output(
    low, "opensoundscape", min_confidence = 0.95)), "No prediction at or above")
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
  expect_error(read_classifier_output(1:3, "perch"), "character vector of paths")
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
  expect_warning(none <- suppressMessages(score_detections(
    c(ARA = file.path(withr::local_tempdir(), "none.txt")), fit)),
    "Table not found for ARA")
  expect_identical(nrow(none), 0L)
})

test_that("Arbimon job downloads are read with sites, labels and verdicts", {
  d <- withr::local_tempdir()
  # older download: `min`, no `frequency`
  writeLines(c(
    "id,recording,site,year,month,day,hour,min,species,songtype,x1,x2,y1,y2,validated,uri,score,site_id",
    "1,LevMax_20170314_033000.flac,LevMax,2017,3,14,3,30,Eleutherodactylus coqui,Common Song,34.8,35.6,1119,3703,(not validated),https://x/1.png,0.226,2324",
    "2,PinMax_20170312_233000.flac,PinMax,2017,3,12,23,30,Eleutherodactylus coqui,Common Song,48.9,49.7,1119,3703,present,https://x/2.png,0.312,1976",
    "3,PinMax_20170312_233000.flac,PinMax,2017,3,12,23,30,Eleutherodactylus coqui,Common Song,10.0,10.8,1119,3703,not present,https://x/3.png,0.05,1976"),
    file.path(d, "coqui.csv"))
  # newer download: `minute` and `frequency`; one species, two song types
  writeLines(c(
    "id,recording,site,year,month,day,hour,minute,species,songtype,x1,x2,y1,y2,frequency,validated,url,score,site_id",
    "4,LevMax_20170320_161000.flac,LevMax,2017,3,20,16,10,Coccyzus minor,Simple Call,5.0,6.0,500,900,24000,(not validated),https://x/4,0.4,2324",
    "5,LevMax_20170320_161000.flac,LevMax,2017,3,20,16,10,Coccyzus minor,Common Song,7.0,8.0,500,900,24000,present,https://x/5,0.5,2324"),
    file.path(d, "cuckoo.csv"))
  file.create(file.path(d, "empty_job.csv"))
  a <- suppressMessages(read_classifier_output(d, "arbimon",
                                               audio_root = "/audio"))
  # the 0.05 match is below min_confidence; the empty file is skipped
  expect_identical(nrow(a), 4L)
  expect_setequal(a$site, c("LevMax", "PinMax"))
  expect_setequal(a$label, c("Eleutherodactylus coqui",
                             "Coccyzus minor (Simple Call)",
                             "Coccyzus minor (Common Song)"))
  expect_identical(a$verdict[a$score == 0.312], "positive")
  expect_true(is.na(a$verdict[a$score == 0.226]))
  expect_equal(a$confidence, a$score)
  expect_identical(a$begin_path[a$score == 0.312],
                   "/audio/PinMax_20170312_233000.flac")
  expect_equal(sort(a$end_time - a$begin_time), c(0.8, 0.8, 1, 1),
               tolerance = 1e-8)
  neg <- suppressMessages(read_classifier_output(
    file.path(d, "coqui.csv"), "arbimon", min_confidence = 0))
  expect_identical(neg$verdict[neg$score == 0.05], "negative")
  expect_error(read_classifier_output(file.path(d, "empty_job.csv"),
                                      "arbimon"), "Every file is empty")
})

test_that("Arbimon export-all files need the recordings and the label", {
  d <- withr::local_tempdir()
  f <- file.path(d, "pm-job_116143.csv")
  writeLines(c(
    "x1,y1,x2,y2,score,validated,site_id,recording_id,recording_local_time,site_name,audio_url",
    "27.685,29625,27.994,45188,0.136,0,80097,268285577,2025-09-02 04:00:00,7_ZdzE05_KZP,https://s3/a.flac",
    "25.285,29625,25.594,45188,0.181,1,80097,268285579,2025-09-04 04:00:00,7_ZdzE05_KZP,https://s3/b.flac"),
    f)
  rec <- tibble::tibble(
    recording_id = c("268285577", "268285579"),
    meta = c('{"encoder":"x","filename":"Z05_20250902_040000.wav"}',
             '{"encoder":"x","filename":"Z05_20250904_040000.wav"}'))
  expect_error(read_classifier_output(f, "arbimon"), "give it in `label`")
  expect_error(read_classifier_output(f, "arbimon", label = "Gryllus sp."),
               "give the `recordings` table")
  x <- suppressMessages(read_classifier_output(
    f, "arbimon", label = "Gryllus sp.", recordings = rec))
  expect_identical(x$begin_path, c("Z05_20250902_040000.wav",
                                   "Z05_20250904_040000.wav"))
  expect_identical(unique(x$site), "7_ZdzE05_KZP")
  expect_identical(x$verdict, c(NA, "positive"))
  rec_csv <- file.path(d, "recordings.0001.csv")
  readr::write_csv(rec, rec_csv)
  y <- suppressMessages(read_classifier_output(
    f, "arbimon", label = "Gryllus sp.", recordings = rec_csv))
  expect_identical(y$begin_path, x$begin_path)
  expect_error(read_classifier_output(f, "arbimon", label = "G",
                                      recordings = rec[1, ]),
               "recording_id\\(s\\) not found")
  expect_error(read_classifier_output(f, "arbimon", label = "G",
                                      recordings = rec["recording_id"]),
               "needs the columns recording_id and meta")
  expect_error(read_classifier_output(f, "arbimon", label = "G",
                                      recordings = file.path(d, "no.csv")),
               "Not found")
  bad <- file.path(d, "bad.csv")
  writeLines(c("a,b", "1,2"), bad)
  expect_error(read_classifier_output(bad, "arbimon"),
               "is not an Arbimon pattern matching export")
  holes <- file.path(d, "holes.csv")
  writeLines(c(
    "x1,y1,x2,y2,score,validated,site_id,recording_id,recording_local_time,site_name,audio_url",
    ",1,2,3,0.5,0,1,268285577,t,S,u",
    "1,1,2,3,0.5,0,1,268285577,t,S,u"), holes)
  expect_message(read_classifier_output(holes, "arbimon", label = "G",
                                        recordings = rec),
                 "1 row\\(s\\) without a recording, start or score left out")
})
