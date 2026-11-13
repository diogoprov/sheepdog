# WAV PCM de 16 bits com um tom de 1 kHz
escreve_wav <- function(f, dur = 0.5, sr = 8000) {
  y <- as.integer(sin(2 * pi * 1000 * seq(0, dur, by = 1 / sr)) * 8000)
  con <- file(f, "wb")
  on.exit(close(con))
  n <- length(y)
  writeChar("RIFF", con, eos = NULL)
  writeBin(as.integer(36 + 2 * n), con, size = 4, endian = "little")
  writeChar("WAVEfmt ", con, eos = NULL)
  writeBin(16L, con, size = 4, endian = "little")
  writeBin(c(1L, 1L), con, size = 2, endian = "little")
  writeBin(c(as.integer(sr), as.integer(2 * sr)), con, size = 4,
           endian = "little")
  writeBin(c(2L, 16L), con, size = 2, endian = "little")
  writeChar("data", con, eos = NULL)
  writeBin(as.integer(2 * n), con, size = 4, endian = "little")
  writeBin(y, con, size = 2, endian = "little")
}

# Manifesto de 6 clipes (2 especies) com revisores e os clipes cortados
app_dados <- function(d) {
  man <- tibble::tibble(
    site = "A", species_code = rep(c("Sp a", "Sp b"), each = 3),
    species_folder = rep(c("sp_a", "sp_b"), each = 3),
    night = "20211001", recording_hour = 20, confidence = 0.8,
    sampling_mode = "top",
    clip_file = paste0("clip", 1:6, ".wav"),
    reviewer = rep(c("ana", "bia"), 3),
    second_reviewer = c("bia", NA, NA, NA, NA, NA))
  for (i in seq_len(nrow(man))) {
    dir.create(file.path(d, "clips", man$species_folder[i]),
               recursive = TRUE, showWarnings = FALSE)
    escreve_wav(file.path(d, "clips", man$species_folder[i],
                          man$clip_file[i]))
  }
  man
}

test_that("the verdicts log keeps the last verdict of each reviewer", {
  f <- withr::local_tempfile(fileext = ".csv")
  expect_identical(nrow(read_verdict_log(f)), 0L)
  append_verdict(f, "c1.wav", "sp_a", "ana", "positive")
  append_verdict(f, "c2.wav", "sp_a", "ana", "negative")
  append_verdict(f, "c1.wav", "sp_a", "ana", "uncertain")
  append_verdict(f, "c1.wav", "sp_a", "bia", "positive")
  log <- read_verdict_log(f)
  expect_named(log, c("clip_file", "species_folder", "reviewer", "verdict",
                      "time", "identity", "identity_certainty"))
  expect_identical(nrow(log), 3L)
  expect_identical(log$verdict[log$clip_file == "c1.wav" &
                                 log$reviewer == "ana"], "uncertain")
  # sem revisor, a coluna fica vazia
  append_verdict(f, "c3.wav", "sp_a", NULL, "negative")
  expect_true(is.na(read_verdict_log(f)$reviewer[4]))
  readr::write_csv(tibble::tibble(clip_file = "x", species_folder = "y",
                                  reviewer = "z", verdict = "talvez",
                                  time = "t"), f)
  expect_error(read_verdict_log(f), "Unknown verdict")
})

test_that("the queue follows the reviewer of assign_reviewers()", {
  d <- withr::local_tempdir()
  man <- app_dados(d)
  fila <- review_queue(man, file.path(d, "clips"), "bia")
  # os clipes de bia mais o da sobreposicao
  expect_setequal(fila$clip_file, c("clip1.wav", "clip2.wav", "clip4.wav",
                                    "clip6.wav"))
  expect_true(all(file.exists(fila$path)))
  expect_identical(nrow(review_queue(man, file.path(d, "clips"))), 6L)
  expect_error(review_queue(man, file.path(d, "clips"), "caio"),
               "No clip")
  expect_error(review_queue(man, file.path(d, "nada")), "None of the clips")
  file.remove(fila$path[1])
  expect_warning(review_queue(man, file.path(d, "clips")), "not found")
  expect_error(suppressWarnings(review_queue(man["clip_file"], d)),
               "lacks the column")
})

test_that("an empty manifest stops with a clear error", {
  d <- withr::local_tempdir()
  man <- app_dados(d)
  f <- file.path(d, "manifest.csv")
  # 0 bytes
  file.create(f)
  expect_error(review_queue(f, file.path(d, "clips")),
               "`manifest` is empty \\(0 rows\\)")
  # so o cabecalho
  readr::write_csv(man[0, ], f)
  expect_error(review_queue(f, file.path(d, "clips")),
               "`manifest` is empty \\(0 rows\\)")
  expect_error(review_queue(file.path(d, "nao_existe.csv"), d),
               "`manifest` not found")
  # sem colunas obrigatorias: erro direto, sem o aviso de recording_date
  readr::write_csv(man["site"], f)
  expect_no_warning(expect_error(review_queue(f, file.path(d, "clips")),
                                 "lacks the column"))
})

test_that("an empty verdicts file stops with a clear error", {
  f <- withr::local_tempfile(fileext = ".csv")
  file.create(f)
  expect_error(read_verdict_log(f), "`verdicts_file` is empty \\(0 bytes\\)")
  # so o cabecalho: log valido, ainda sem vereditos
  writeLines(paste(verdict_columns, collapse = ","), f)
  expect_identical(nrow(read_verdict_log(f)), 0L)
})

test_that("the app writes each verdict and moves to the next clip", {
  skip_if_not_installed("shiny")
  d <- withr::local_tempdir()
  man <- app_dados(d)
  f <- file.path(d, "verdicts.csv")
  # bia: clip1 e clip2 (sp_a), clip4 e clip6 (sp_b)
  fila <- review_queue(man, file.path(d, "clips"), "bia")
  shiny::testServer(review_server, args = list(
    fila = fila, verdicts_file = f, reviewer = "bia"), {
    session$setInputs(species = "", pending = TRUE)
    estado <- session$returned
    expect_identical(estado$current(), 1L)
    session$setInputs(positive = 1)
    expect_identical(estado$current(), 2L)
    session$setInputs(key = "n")
    session$setInputs(key = "u")
    expect_identical(estado$current(), 4L)
    expect_identical(unname(estado$verdicts()),
                     c("positive", "negative", "uncertain"))
    session$setInputs(key = "ArrowLeft")
    expect_identical(estado$current(), 3L)
    expect_match(output$progress, "3 of 4")
    # filtro por especie: so o clipe de sp_b ainda nao revisado
    session$setInputs(species = "sp_b")
    expect_identical(fila$clip_file[estado$current()], "clip6.wav")
  })
  log <- read_verdict_log(f)
  expect_identical(log$verdict, c("positive", "negative", "uncertain"))
  expect_identical(log$clip_file, c("clip1.wav", "clip2.wav", "clip4.wav"))
  expect_true(all(log$reviewer == "bia"))
  # ao reabrir, os ja revisados saem da fila
  shiny::testServer(review_server, args = list(
    fila = fila, verdicts_file = f, reviewer = "bia"), {
    session$setInputs(species = "", pending = TRUE)
    expect_identical(session$returned$current(), 4L)
    session$setInputs(pending = FALSE)
    expect_identical(session$returned$current(), 1L)
    expect_match(output$current_verdict, "positive")
  })
})

test_that("app_verdicts() returns the table of classify_review()", {
  d <- withr::local_tempdir()
  man <- app_dados(d)
  f <- file.path(d, "verdicts.csv")
  append_verdict(f, "clip1.wav", "sp_a", "ana", "positive")
  append_verdict(f, "clip1.wav", "sp_a", "bia", "negative")
  append_verdict(f, "clip2.wav", "sp_a", "bia", "positive")
  append_verdict(f, "clip3.wav", "sp_a", "ana", "uncertain")
  v <- suppressMessages(app_verdicts(man, f, file.path(d, "clips"),
                                     reviewer = "ana"))
  expect_identical(nrow(v), 6L)
  expect_identical(v$verdict, c("positive", "not_reviewed", "uncertain",
                                rep("not_reviewed", 3)))
  expect_true(all(file.exists(v$reviewed_path)))
  expect_true(all(v$reviewer == "ana"))
  # todos os revisores: uma linha por clipe e revisor
  todos <- suppressMessages(app_verdicts(man, f))
  expect_identical(nrow(todos), 7L)
  expect_true(all(is.na(todos$reviewed_path)))
  ag <- suppressWarnings(reviewer_agreement(
    dplyr::filter(todos, !is.na(reviewer))))
  expect_identical(ag$n_clips, 1L)
  cons <- suppressMessages(consensus_verdicts(
    dplyr::filter(todos, !is.na(reviewer))))
  expect_identical(cons$verdict[cons$clip_file == "clip1.wav"],
                   "disagreement")
  # incertos ficam fora da precisao
  p <- precision_by_bin(v, min_n = 1)
  expect_identical(sum(p$n_reviewed), 1L)
  append_verdict(f, "fora.wav", "sp_a", "ana", "positive")
  expect_warning(suppressMessages(app_verdicts(man, f)), "not in the")
})

test_that("the review queue can be a reactive that starts empty", {
  skip_if_not_installed("shiny")
  d <- withr::local_tempdir()
  man <- app_dados(d)
  cortada <- review_queue(man, file.path(d, "clips"))
  f <- file.path(d, "verdicts.csv")
  entrada <- shiny::reactiveVal(NULL)
  shiny::testServer(review_server, args = list(
    fila = entrada, verdicts_file = f, reviewer = "ana"), {
      session$setInputs(species = "", pending = TRUE)
      expect_true(is.na(atual()))
      expect_match(output$current_verdict, "Sampling tab")
      session$setInputs(positive = 1)
      expect_false(file.exists(f))
      # clipes recem-cortados chegam a fila
      entrada(cortada)
      session$flushReact()
      expect_identical(atual(), 1L)
      expect_identical(output$progress, "0 of 6 clips reviewed")
      session$setInputs(positive = 2)
      expect_identical(read_verdict_log(f)$clip_file, "clip1.wav")
      expect_identical(atual(), 2L)
    })
})

test_that("sampling_args() keeps only the filled fields", {
  a <- sampling_args(list(mode = "random_detections", occasion_unit = "file",
                          threshold = NA, n_top = 2, min_confidence = 0.1,
                          seed = 2026, target_total = NA,
                          max_per_species = 5, sites = NULL,
                          species = c("boa-ran"), hour_start = NA,
                          hour_end = NA, remap_from = "", remap_to = "",
                          strata = "night", recording_fraction = 0.5))
  expect_identical(a$strata, "night")
  expect_identical(a$max_per_species, 5)
  expect_null(a$threshold)
  expect_null(a$remap_from)
  expect_null(a$recording_fraction)
})

test_that("the sampling tab draws, then cuts and writes the manifest", {
  skip_if_not_installed("shiny")
  # o corte de verdade usa o av
  skip_if_not_installed("av")
  ex <- system.file("extdata", "example", package = "sheepdog")
  det <- suppressMessages(read_selection_tables(file.path(ex, "birdnet")))
  out <- withr::local_tempdir()
  shiny::testServer(sampling_server, args = list(
    detections = det, selection_dir = file.path(ex, "birdnet"),
    output_dir = out, classifier = "test"), {
      session$setInputs(mode = "random_detections", occasion_unit = "file",
                        threshold = 0.5, n_top = 1, strata = "night",
                        target_total = NA, max_per_species = NA,
                        min_confidence = 0.1, sites = "ARA", species = NULL,
                        hour_start = NA, hour_end = NA, seed = 2026,
                        remap_from = "", remap_to = "", simulate = TRUE,
                        replace = FALSE)
      session$setInputs(cut = 1)
      expect_match(notas(), "Draw the clips first")
      expect_error(output$counts_title)
      session$setInputs(draw = 1)
      expect_match(output$counts_title$html, "Clips per site and species")
      expect_match(output$inclusion_title$html, "Inclusion probability")
      sel <- selecao()
      ref <- suppressWarnings(suppressMessages(select_clips(
        det, sampling_mode = "random_detections", threshold = 0.5,
        n_top = 1, strata = "night", sites = "ARA", seed = 2026)))
      expect_identical(sel$clip_file, ref$clip_file)
      expect_true(all(sel$site == "ARA"))
      expect_match(output$counts, "ARA")
      # simulado: nada gravado, a fila nao recarrega
      session$setInputs(cut = 2)
      expect_true(all(status()$status == "audio_not_found"))
      expect_false(file.exists(file.path(out, "clip_manifest.csv")))
      expect_identical(cortes(), 0L)
      session$setInputs(simulate = FALSE, cut = 3)
      man <- readr::read_csv(file.path(out, "clip_manifest.csv"),
                             show_col_types = FALSE)
      expect_identical(man$clip_file, sel$clip_file)
      info <- readr::read_csv(file.path(out, "extraction_info.csv"),
                              show_col_types = FALSE)
      expect_identical(info$value[info$key == "select_clips.strata"],
                       "night")
      expect_identical(info$value[info$key == "classifier"], "test")
      # sem nenhuma gravacao achada, avisa e nao recarrega a fila
      expect_true(any(grepl("No recording was found", notas())))
      expect_identical(cortes(), 0L)
      # nao sobrescreve o manifesto sem pedir
      session$setInputs(cut = 4)
      expect_match(notas(), "already exists")
      expect_identical(cortes(), 0L)
      # top avisa que nao estima falsos positivos
      session$setInputs(mode = "top", draw = 2)
      expect_true(any(grepl("false-positive rate", notas())))
    })
})

test_that("the export tab writes the occupancy tables with the verdicts", {
  skip_if_not_installed("shiny")
  ex <- system.file("extdata", "example", package = "sheepdog")
  det <- suppressMessages(read_selection_tables(file.path(ex, "birdnet")))
  rec <- readr::read_csv(file.path(ex, "recordings.csv"),
                         show_col_types = FALSE)
  out <- withr::local_tempdir()
  man <- suppressWarnings(suppressMessages(select_clips(
    det, sampling_mode = "random_detections", threshold = 0.5, n_top = 1,
    sites = "ARA")))
  readr::write_csv(man, file.path(out, "clip_manifest.csv"))
  f <- file.path(out, "verdicts.csv")
  for (i in 1:4) {
    append_verdict(f, man$clip_file[i], man$species_folder[i], "ana",
                   c("positive", "negative")[1 + i %% 2])
  }
  # dois revisores discordam num clipe
  append_verdict(f, man$clip_file[1], man$species_folder[1], "bia",
                 "positive")
  shiny::testServer(export_server, args = list(
    detections = det, output_dir = out, clips_dir = file.path(out, "clips"),
    verdicts_file = f, recordings = rec), {
      session$setInputs(occasion_unit = "file", min_confidence = 0.1,
                        export_dir = file.path(out, "occupancy"),
                        overwrite = FALSE, export = 1)
      r <- resultado()
      expect_false(is.null(r))
      expect_true(file.exists(file.path(out, "occupancy", "schema.json")))
      expect_identical(r$schema$schema, "sheepdog-occupancy")
      expect_identical(nrow(r$tables$validation), 4L)
      expect_identical(sum(r$tables$validation$verdict == "disagreement"),
                       1L)
      expect_match(output$tables, "validation")
      # sem overwrite, a segunda exportacao falha com aviso no app
      session$setInputs(export = 2)
      expect_true(any(grepl("^Error", notas())))
    })
})

test_that("app_verdicts() reports the clips marked more than once", {
  d <- withr::local_tempdir()
  man <- app_dados(d)
  f <- file.path(d, "verdicts.csv")
  append_verdict(f, "clip1.wav", "sp_a", "ana", "positive")
  append_verdict(f, "clip1.wav", "sp_a", "ana", "positive")
  append_verdict(f, "clip2.wav", "sp_a", "ana", "positive")
  append_verdict(f, "clip2.wav", "sp_a", "ana", "negative")
  append_verdict(f, "clip3.wav", "sp_a", "bia", "positive")
  msgs <- character()
  v <- withCallingHandlers(
    app_verdicts(man, f, reviewer = "ana"),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    })
  expect_true(any(grepl("2 clip\\(s\\) marked more than once by the same reviewer, 1 of them",
                        msgs)))
  expect_identical(v$verdict[v$clip_file == "clip2.wav"], "negative")
  # um clipe marcado por dois revisores nao conta como remarcado
  append_verdict(f, "clip3.wav", "sp_a", "ana", "negative")
  msgs <- character()
  withCallingHandlers(
    app_verdicts(man, f, reviewer = "bia"),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    })
  expect_false(any(grepl("more than once", msgs)))
})

test_that("post_validation() reads the verdicts file of the app", {
  d <- withr::local_tempdir()
  man <- app_dados(d)
  man$confidence <- c(0.6, 0.7, 0.8, 0.6, 0.7, 0.9)
  man$source_audio <- "rec.wav"
  f <- file.path(d, "verdicts.csv")
  append_verdict(f, "clip1.wav", "sp_a", "ana", "positive")
  append_verdict(f, "clip2.wav", "sp_a", "bia", "negative")
  append_verdict(f, "clip4.wav", "sp_b", "bia", "positive")
  append_verdict(f, "clip4.wav", "sp_b", "bia", "negative")
  saida <- file.path(d, "pv")
  res <- suppressMessages(post_validation(
    file.path(d, "clips"), man, saida, verdicts_file = f, min_n = 1))
  expect_true(file.exists(file.path(saida, "validation_by_clip.csv")))
  expect_identical(nrow(res$validation), 6L)
  expect_identical(res$validation$verdict,
                   c("positive", "negative", "not_reviewed", "negative",
                     rep("not_reviewed", 2)))
  expect_true(all(file.exists(res$validation$reviewed_path)))
  expect_identical(sum(res$precision$n_reviewed), 3L)
  # so um revisor
  so_ana <- suppressMessages(post_validation(
    manifest_path = man, output_dir = file.path(d, "pv_ana"),
    verdicts_file = f, reviewer = "ana", min_n = 1))
  expect_identical(sum(so_ana$validation$verdict == "positive"), 1L)
  # dois revisores no mesmo clipe: consenso
  append_verdict(f, "clip1.wav", "sp_a", "bia", "negative")
  cons <- suppressMessages(post_validation(
    manifest_path = man, output_dir = file.path(d, "pv_cons"),
    verdicts_file = f, min_n = 1))
  expect_identical(nrow(cons$validation), 6L)
  expect_identical(cons$validation$verdict[cons$validation$clip_file ==
                                             "clip1.wav"], "disagreement")
  # com inclusion_prob, as tabelas ganham a precisao ponderada
  man$inclusion_prob <- 0.5
  expect_message(
    pond <- post_validation(manifest_path = man,
                            output_dir = file.path(d, "pv_pond"),
                            verdicts_file = f, reviewer = "bia", min_n = 1),
    "weighted by 1 / inclusion_prob")
  expect_true("precision_weighted" %in% names(pond$precision))
  expect_error(post_validation(manifest_path = man, output_dir = saida),
               "Give `review_dir`")
  expect_error(suppressMessages(post_validation(
    manifest_path = man, output_dir = saida, verdicts_file = f,
    reviewer = "zeca")), "Check `verdicts_file`")
})

test_that("locate_audio() finds moved recordings by file name", {
  d <- withr::local_tempdir()
  dir.create(file.path(d, "new", "Campinas"), recursive = TRUE)
  file.create(file.path(d, "new", "Campinas", c("a_20261002_092817.flac",
                                                 "b_20261003_085442.flac")))
  antigos <- file.path(d, "old", c("a_20261002_092817.flac",
                                   "b_20261003_085442.flac",
                                   "c_20261004_062102.flac"))
  chk <- locate_audio(c(antigos, antigos[1]), file.path(d, "new"))
  # no Windows o tempdir() vem com barras invertidas, e locate_audio()
  # devolve barras normais: compara os caminhos com barras normais
  barras <- function(x) gsub("\\\\", "/", x)
  expect_identical(chk$n, 3L)
  expect_identical(chk$missing, antigos)
  expect_identical(barras(unname(chk$found)),
                   barras(file.path(d, "new", "Campinas",
                                    basename(antigos[1:2]))))
  expect_identical(names(chk$found), antigos[1:2])
  expect_identical(barras(chk$remap),
                   barras(paste0(c(file.path(d, "old"),
                                   file.path(d, "new", "Campinas")), "/")))
  # sem pasta de audio: so lista as ausentes
  expect_length(locate_audio(antigos)$found, 0)
  # nomes repetidos na pasta de audio sao ambiguos e ficam de fora
  dir.create(file.path(d, "new", "copy"))
  file.create(file.path(d, "new", "copy", "a_20261002_092817.flac"))
  chk <- locate_audio(antigos, paste0(file.path(d, "new"), "/"))
  expect_identical(names(chk$found), antigos[2])
})

test_that("the sampling tab offers to use the recordings of the audio folder", {
  skip_if_not_installed("shiny")
  ex <- system.file("extdata", "example", package = "sheepdog")
  det <- suppressMessages(read_selection_tables(file.path(ex, "birdnet")))
  out <- withr::local_tempdir()
  aud <- withr::local_tempdir()
  ref <- suppressWarnings(suppressMessages(select_clips(
    det, sampling_mode = "random_detections", threshold = 0.5,
    n_top = 1, strata = "night", sites = "ARA", seed = 2026)))
  file.create(file.path(aud, basename(unique(ref$source_audio))))
  shiny::testServer(sampling_server, args = list(
    detections = det, selection_dir = file.path(ex, "birdnet"),
    output_dir = out, classifier = "test"), {
      session$setInputs(mode = "random_detections", occasion_unit = "file",
                        threshold = 0.5, n_top = 1, strata = "night",
                        target_total = NA, max_per_species = NA,
                        min_confidence = 0.1, sites = "ARA", species = NULL,
                        hour_start = NA, hour_end = NA, seed = 2026,
                        remap_from = "", remap_to = "", audio_dir = aud,
                        simulate = TRUE, replace = FALSE)
      session$setInputs(draw = 1)
      expect_length(audio()$found, length(unique(ref$source_audio)))
      session$setInputs(relocate = 1)
      expect_true(all(file.exists(selecao()$source_audio)))
      expect_identical(selecao()$begin_path, ref$begin_path)
      expect_identical(realocadas()$n, length(unique(ref$source_audio)))
      expect_match(notas()[1], "now read from")
    })
})

test_that("the spectrogram takes the palette, the FFT window and the band", {
  skip_if_not_installed("av")
  f <- withr::local_tempfile(fileext = ".wav")
  escreve_wav(f, dur = 1)
  png <- withr::local_tempfile(fileext = ".png")
  grDevices::png(png)
  expect_no_error(plot_spectrogram(f, max_freq = 2, fft = 512L,
                                   overlap = 0.9, palette = "Viridis"))
  # o topo do eixo e o pedido, qualquer que seja o FFT
  for (fft in c(256L, 512L, 1024L)) {
    g <- plot_spectrogram(f, max_freq = 2, fft = fft)
    expect_equal(g$usr[4], 2)
  }
  expect_no_error(plot_spectrogram(f, fft = 2048L, palette = "Gray"))
  expect_no_error(plot_spectrogram(f, brightness = 0.3, contrast = 2))
  expect_no_error(plot_spectrogram(f, palette = "Mako", brightness = -0.5,
                                   contrast = 0.25))
  grDevices::dev.off()
  expect_length(spectrogram_colours("Inferno"), 64)
  expect_identical(spectrogram_colours("unknown"),
                   grDevices::gray.colors(64, start = 0, end = 1))
  skip_if_not_installed("shiny")
  ui <- as.character(review_ui("r", max_freq = 8))
  expect_match(ui, "Palette")
  expect_match(ui, "Brightness")
  expect_match(ui, "Contrast")
  expect_match(ui, "FFT window")
  expect_match(ui, 'value="8"')
})

test_that("the verdicts log keeps the identity of negative clips", {
  f <- withr::local_tempfile(fileext = ".csv")
  append_verdict(f, "c1.wav", "sp_a", "ana", "negative",
                 identity = c(" Sp b ", "insect"),
                 identity_certainty = "probable")
  append_verdict(f, "c2.wav", "sp_a", "ana", "positive",
                 identity = "rain", identity_certainty = "sure")
  append_verdict(f, "c3.wav", "sp_a", "ana", "uncertain", identity = "")
  log <- read_verdict_log(f)
  expect_identical(log$identity, c("Sp b|insect", NA, NA))
  expect_identical(log$identity_certainty, c("probable", NA, NA))
  expect_error(append_verdict(f, "c4.wav", "sp_a", "ana", "negative",
                              identity = "x", identity_certainty = "maybe"))
})

test_that("a verdicts file of an earlier version gains the identity columns", {
  f <- withr::local_tempfile(fileext = ".csv")
  readr::write_csv(tibble::tibble(clip_file = "c1.wav", species_folder = "sp_a",
                                  reviewer = "ana", verdict = "negative",
                                  time = "t"), f, na = "")
  log <- read_verdict_log(f)
  expect_true(all(c("identity", "identity_certainty") %in% names(log)))
  expect_true(is.na(log$identity))
  append_verdict(f, "c2.wav", "sp_a", "ana", "negative", identity = "bird",
                 identity_certainty = "sure")
  log <- read_verdict_log(f)
  expect_identical(nrow(log), 2L)
  expect_identical(log$identity, c(NA, "bird"))
  expect_identical(names(readr::read_csv(f, n_max = 0,
                                         show_col_types = FALSE))[6:7],
                   c("identity", "identity_certainty"))
})

test_that("app_verdicts() carries the identities", {
  d <- withr::local_tempdir()
  man <- app_dados(d)
  f <- file.path(d, "verdicts.csv")
  append_verdict(f, "clip1.wav", "sp_a", "ana", "negative",
                 identity = "Sp b", identity_certainty = "sure")
  append_verdict(f, "clip2.wav", "sp_a", "ana", "positive")
  v <- suppressMessages(app_verdicts(man, f, reviewer = "ana"))
  expect_identical(v$identity[v$clip_file == "clip1.wav"], "Sp b")
  expect_true(is.na(v$identity[v$clip_file == "clip2.wav"]))
})

test_that("join_identities() fills, keeps and checks the identities", {
  val <- tibble::tibble(
    clip_file = paste0("c", 1:5, ".wav"), species_code = "Sp a",
    verdict = c("negative", "negative", "positive", "uncertain", "negative"),
    identity = c("bird", NA, NA, NA, NA),
    identity_certainty = c("sure", NA, NA, NA, NA))
  ext <- tibble::tibble(
    clip = c("pasta/c1.wav", "c2.wav", "c3.wav", "c4.wav", "c9.wav"),
    id_correta = c("insect", "Sp b", "rain", "Sp b|bird", "noise"),
    certeza = c("sure", "sure", "probable", "probable", "sure"))
  expect_warning(expect_warning(expect_warning(
    out <- suppressMessages(join_identities(
      val, ext, identity_col = "id_correta", certainty_col = "certeza")),
    "not in `validation`"), "different identity"), "not negative")
  # a do app fica; as externas preenchem o resto
  expect_identical(out$identity, c("bird", "Sp b", "rain", "Sp b|bird", NA))
  expect_identical(out$identity_certainty,
                   c("sure", "sure", "probable", "probable", NA))
  expect_message(suppressWarnings(join_identities(
    val, ext, identity_col = "id_correta")), "2 of 3 negative")
  expect_error(join_identities(val, ext), "lacks the column")
  ext$certeza[1] <- "talvez"
  expect_error(join_identities(val, ext, identity_col = "id_correta",
                               certainty_col = "certeza"), "Unknown certainty")
  # tabela sem as colunas de identidade e caminho para csv
  f <- withr::local_tempfile(fileext = ".csv")
  readr::write_csv(ext[2, ], f)
  out <- suppressMessages(join_identities(val[2, 1:3], f,
                                          identity_col = "id_correta"))
  expect_identical(out$identity, "Sp b")
  expect_true(is.na(out$identity_certainty))
})

test_that("join_identities() can be limited to one reviewer", {
  val <- tibble::tibble(clip_file = c("c1.wav", "c1.wav"),
                        reviewer = c("ana", "bia"),
                        verdict = "negative")
  out <- suppressMessages(join_identities(
    val, tibble::tibble(clip = "c1.wav", identity = "insect"),
    reviewer = "bia"))
  expect_identical(out$identity, c(NA, "insect"))
})

test_that("confuser_summary() counts the identities of each class", {
  val <- tibble::tibble(
    species_code = c(rep("Sp a", 5), "Sp b"),
    verdict = c("negative", "negative", "negative", "uncertain", "positive",
                "negative"),
    identity = c("Sp b", "Sp b|insect", NA, "rain", NA, "bird"),
    identity_certainty = c("sure", "probable", NA, "sure", NA, "sure"))
  s <- confuser_summary(val)
  a <- s[s$species_code == "Sp a", ]
  expect_identical(a$identity, c("Sp b", "insect", NA))
  expect_identical(a$n, c(2L, 1L, 1L))
  expect_equal(a$n_weighted, c(1.5, 0.5, 1))
  expect_equal(sum(a$share), 1)
  expect_identical(a$n_sure, c(1L, 0L, 0L))
  expect_identical(a$is_class, c(TRUE, FALSE, FALSE))
  expect_false(s$is_class[s$species_code == "Sp b"])
  s2 <- confuser_summary(val, verdicts = c("negative", "uncertain"))
  expect_true("rain" %in% s2$identity)
  expect_error(confuser_summary(val[1:2]), "lacks the column")
})

test_that("the app writes the identity given before a negative verdict", {
  skip_if_not_installed("shiny")
  d <- withr::local_tempdir()
  man <- app_dados(d)
  f <- file.path(d, "verdicts.csv")
  fila <- review_queue(man, file.path(d, "clips"), "bia")
  shiny::testServer(review_server, args = list(
    fila = fila, verdicts_file = f, reviewer = "bia"), {
    session$setInputs(species = "", pending = TRUE)
    session$setInputs(identity = c("Sp b", "insect"),
                      identity_certainty = "probable")
    session$setInputs(negative = 1)
    # sem identidade no clipe seguinte
    session$setInputs(identity = NULL, identity_certainty = "sure")
    session$setInputs(key = "n")
  })
  log <- read_verdict_log(f)
  expect_identical(log$identity, c("Sp b|insect", NA))
  expect_identical(log$identity_certainty, c("probable", NA))
})

test_that("join_identities() and confuser_summary() check their inputs", {
  val <- tibble::tibble(clip_file = paste0("c", 1:7, ".wav"),
                        species_code = "Sp a", verdict = "positive")
  ids <- tibble::tibble(clip = c("c1.wav", "c1.wav"), identity = "bird")
  expect_error(join_identities(val, ids), "more than one row")
  expect_error(join_identities(val["clip_file"], ids[1, ]),
               "`validation` lacks")
  # listas longas sao cortadas em 5
  ids <- tibble::tibble(clip = c(val$clip_file, paste0("x", 1:6, ".wav")),
                        identity = "bird")
  expect_warning(expect_warning(suppressMessages(join_identities(val, ids)),
                                "x5.wav, \\.\\.\\."), "c5.wav \\(positive\\), \\.\\.\\.")
  # sem identity_certainty e com classes dadas
  val$verdict <- "negative"
  val$identity <- "Sp b"
  s <- confuser_summary(val, classes = "Sp b")
  expect_true(s$is_class)
  expect_identical(s$n_sure, 0L)
})

test_that("sampling_args() passes score bands and drops what they refuse", {
  a <- sampling_args(list(mode = "score_bands", occasion_unit = "file",
                          threshold = 0.5, n_top = 2, min_confidence = 0.1,
                          seed = 2026, target_total = 20,
                          max_per_species = 5, sites = NULL, species = NULL,
                          hour_start = NA, hour_end = NA, remap_from = "",
                          remap_to = "", strata = "site_species",
                          score_breaks = "0.1, 0.5, 1"))
  expect_identical(a$strata, "site_species")
  expect_identical(a$score_breaks, c(0.1, 0.5, 1))
  expect_null(a$target_total)
  expect_null(a$max_per_species)
  expect_null(a$threshold)
  expect_identical(parse_breaks("0,1; 0,5; 1"), c(0.1, 0.5, 1))
  expect_null(parse_breaks(""))
  expect_error(parse_breaks("0.1, a, 1"), "numbers separated by commas")
})

test_that("the sampling tab draws score bands", {
  skip_if_not_installed("shiny")
  ex <- system.file("extdata", "example", package = "sheepdog")
  det <- suppressMessages(read_selection_tables(file.path(ex, "birdnet")))
  out <- withr::local_tempdir()
  shiny::testServer(sampling_server, args = list(
    detections = det, selection_dir = file.path(ex, "birdnet"),
    output_dir = out, classifier = "test"), {
      base <- list(mode = "score_bands", occasion_unit = "file",
                   threshold = NA, n_top = 1, strata = "site_species",
                   target_total = NA, max_per_species = NA,
                   min_confidence = 0.1, sites = NULL, species = NULL,
                   hour_start = NA, hour_end = NA, seed = 2026,
                   remap_from = "", remap_to = "", audio_dir = "",
                   simulate = TRUE, replace = FALSE)
      do.call(session$setInputs, c(base, score_breaks = "0.1, x"))
      session$setInputs(draw = 1)
      expect_match(notas(), "numbers separated by commas", all = FALSE)
      session$setInputs(score_breaks = "0.1, 0.5, 1")
      session$setInputs(draw = 2)
      expect_true(all(selecao()$sampling_mode == "score_bands"))
      expect_match(notas(), "not false-positive occupancy models",
                   all = FALSE)
    })
})
