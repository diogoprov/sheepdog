# Gravacoes vazias de dois locais, com data e hora no nome
setup_audio <- function(d) {
  for (s in c("ARA", "BAI")) dir.create(file.path(d, s), recursive = TRUE)
  file.create(file.path(d, "ARA", c("ARA01_20211001_190000.wav",
                                    "ARA01_20211001_200000.wav",
                                    "ARA01_20211002_190000.wav")))
  file.create(file.path(d, "BAI", "BAI01_20211001_190000.wav"))
  invisible(d)
}

test_that("recording_summary() puts the recordings after midnight in the night before", {
  rec <- tibble::tibble(
    site = "ARA",
    source_audio = paste0("/a/ARA01_", c("20211001_190000", "20211001_220000",
                                         "20211002_010000", "20211002_190000"),
                          ".wav"))
  det <- tibble::tibble(site = "ARA",
                        begin_path = "/a/ARA01_20211002_010000.wav")
  tab <- recording_summary(rec, det)
  expect_identical(tab$night, c("20211001", "20211002"))
  expect_identical(tab$n_recordings, c(3L, 1L))
  expect_identical(tab$hours_with_detections, c(1L, 0L))
  expect_equal(tab$prop_hours, c(1 / 3, 0))
  expect_match(summary_svg(tab), "ARA, night of 2021-10-01")
})

test_that("recording_summary() counts recordings, hours and predictions", {
  aud <- setup_audio(withr::local_tempdir())
  rec <- suppressMessages(list_recordings(aud))
  det <- tibble::tibble(
    site = "output",
    begin_path = file.path(aud, "ARA", c(rep("ARA01_20211001_190000.wav", 3),
                                         "ARA01_20211002_190000.wav")))
  tab <- recording_summary(rec, det)
  expect_identical(nrow(tab), 3L)
  a1 <- tab[tab$site == "ARA" & tab$night == "20211001", ]
  expect_identical(a1$n_recordings, 2L)
  expect_identical(a1$hours_recorded, 2L)
  expect_identical(a1$hours_with_detections, 1L)
  expect_identical(a1$n_detections, 3L)
  expect_equal(a1$prop_hours, 0.5)
  b1 <- tab[tab$site == "BAI", ]
  expect_identical(b1$n_detections, 0L)
  expect_false(attr(tab, "from_detections"))
  # sem gravacoes: os arquivos das predicoes
  tab2 <- recording_summary(NULL, det)
  expect_true(attr(tab2, "from_detections"))
  expect_identical(sum(tab2$n_recordings), 2L)
  expect_null(recording_summary(NULL, NULL))
  svg <- summary_svg(tab)
  expect_match(svg, "^<svg")
  expect_match(svg, "3 prediction\\(s\\) of any species, any score")
  expect_match(summary_svg(tab, "Sp a"), "of Sp a, any score")
  expect_match(svg, "2021-10-02")
  expect_identical(summary_colour(c(0, 1, NA)),
                   c("#f4f1d0", "#22507e", "#d9d9d9"))
})

test_that("load_app_state() reads the folders and writes recordings.csv", {
  aud <- setup_audio(withr::local_tempdir())
  out <- file.path(withr::local_tempdir(), "round")
  ex <- system.file("extdata", "example", "birdnet", package = "sheepdog")
  st <- app_state(selection_dir = ex, output_dir = out, audio_dir = aud)
  expect_false(st$confirmed)
  suppressMessages(load_app_state(st))
  expect_true(app_ready(st))
  expect_identical(st$clips_dir, file.path(out, "clips"))
  expect_true(file.exists(file.path(out, "recordings.csv")))
  expect_identical(nrow(st$recordings), 4L)
  expect_null(st$clip_queue)
  # um manifesto sem clipes cortados vira aviso, nao erro
  readr::write_csv(tibble::tibble(species_folder = "sp", clip_file = "x.wav",
                                  recording_date = "20211001"),
                   file.path(out, "clip_manifest.csv"))
  st$manifest <- NULL
  expect_warning(suppressMessages(load_app_state(st)), "without clips")
  expect_null(st$clip_queue)
  # so revisao: o erro continua
  st2 <- app_state(manifest = file.path(out, "clip_manifest.csv"),
                   clips_dir = file.path(out, "clips"))
  expect_true(st2$review_only)
  expect_error(load_app_state(st2), "None of the clips")
})

test_that("the app builds its tabs from the state", {
  skip_if_not_installed("shiny")
  st <- app_state()
  load_app_state(st)
  expect_s3_class(review_app(st), "shiny.appobj")
  ui <- as.character(intro_ui(st))
  expect_match(ui, "Graphical abstract")
  expect_match(ui, "Audio panel")
  expect_match(ui, "Apply and reload")
  expect_match(as.character(needs_folders_ui()), "Audio panel")
  expect_true(st$confirmed)
  ex <- system.file("extdata", "example", "birdnet", package = "sheepdog")
  st <- app_state(selection_dir = ex, output_dir = withr::local_tempdir())
  suppressMessages(load_app_state(st))
  expect_false(st$confirmed)
  expect_match(as.character(sampling_ui("s", st$detections, "/x/audio")),
               "/x/audio")
})

test_that("the audio panel refuses a folder that does not exist", {
  skip_if_not_installed("shiny")
  st <- app_state()
  shiny::testServer(setup_server, args = list(st = st, root = NULL), {
    session$setInputs(audio_dir = "/no/such/folder", selection_dir = "",
                      output_dir = "")
    session$setInputs(apply = 1)
    expect_null(st$audio_dir)
    output$status
    expect_match(output$summary$html, "Choose the audio folder")
  })
})

test_that("the audio panel summary follows the chosen species", {
  skip_if_not_installed("shiny")
  ex <- system.file("extdata", "example", "birdnet", package = "sheepdog")
  st <- app_state(selection_dir = ex)
  suppressMessages(load_app_state(st))
  esp <- as.character(st$detections$species_code[1])
  n_esp <- sum(st$detections$species_code == esp)
  shiny::testServer(setup_server, args = list(st = st, root = NULL), {
    session$setInputs(species = NULL)
    todas <- output$summary$html
    expect_match(todas, "any species")
    session$setInputs(species = esp)
    uma <- output$summary$html
    expect_match(uma, paste0("of ", esp), fixed = TRUE)
    soma <- sum(as.integer(gsub(",", "", regmatches(
      uma, gregexpr("[0-9,]+(?= prediction)", uma, perl = TRUE))[[1]])))
    expect_identical(soma, n_esp)
  })
})
