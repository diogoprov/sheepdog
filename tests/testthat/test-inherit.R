# Duas gravacoes de 60 s, uma especie: predicoes em 0 s e 30 s de cada
inherit_pred <- function() {
  grade <- expand.grid(rec = c("A_20240101_200000", "A_20240102_200000"),
                       t = c(0, 30), stringsAsFactors = FALSE)
  tibble::tibble(site = "A", species_code = "Sp_one", confidence = 0.8,
                 begin_path = paste0("/audio/A/", grade$rec, ".wav"),
                 file_offset = grade$t, begin_time = grade$t,
                 end_time = grade$t + 3)
}
rec_lista <- function() {
  data.frame(site = "A", source_audio = paste0(
    "/audio/A/", c("A_20240101_200000", "A_20240102_200000"), ".wav"))
}
det <- function(pred = inherit_pred(), ..., inherit = TRUE) {
  suppressMessages(select_clips(pred, "random_detections", threshold = 0.5,
                                strata = "site_species", n_top = 10,
                                inherit = inherit, ...))
}
rec <- function(pred = inherit_pred(), unit = "file", ..., inherit = TRUE) {
  suppressMessages(select_clips(pred, "random_recordings", inherit = inherit,
                                occasion_unit = unit, n_recordings_per_site = 100,
                                recordings = rec_lista(),
                                recording_duration = 60, ...))
}
com_veredito <- function(m, ...) {
  m$verdict <- c(...)[seq_len(nrow(m))]
  m
}

test_that("an absent recording makes its predictions negative", {
  r <- rec()
  r$verdict <- ifelse(grepl("0101", r$source_audio), "negative", "positive")
  m <- det(previous = r)
  dia1 <- grepl("0101", m$source_audio)
  expect_true(all(m$previously_reviewed))
  expect_true(all(m$inherited_verdict[dia1] == "negative"))
  expect_true(all(is.na(m$inherited_verdict[!dia1])))
  expect_true(all(m$source_design == "random_recordings"))
})

test_that("by default, overlaps are marked and still reviewed", {
  r <- rec()
  r$verdict <- "negative"
  m <- det(previous = r, inherit = FALSE)
  expect_true(all(m$previously_reviewed))
  expect_true(all(m$source_design == "random_recordings"))
  expect_true(all(is.na(m$inherited_verdict)))
  d <- withr::local_tempdir()
  cortado <- suppressMessages(suppressWarnings(
    cut_clips(m, d, simulate = TRUE)))
  expect_false(any(cortado$status == "inherited"))
})

test_that("a positive prediction makes its recording present", {
  d <- det()
  d$verdict <- ifelse(grepl("0101", d$source_audio) & d$clip_start == 30,
                      "positive", "negative")
  m <- rec(previous = d)
  dia1 <- grepl("0101", m$source_audio)
  expect_identical(unique(m$inherited_verdict[dia1]), "positive")
  # so predicoes negativas: a especie pode ter cantado abaixo do limiar
  expect_true(all(is.na(m$inherited_verdict[!dia1])))
  expect_true(all(m$previously_reviewed))
})

test_that("minutes and files can be mixed", {
  # minuto sem a especie, em arquivo com minutos revistos, so diz daquele minuto
  pred <- inherit_pred()
  pred$file_offset[pred$file_offset == 30] <- 70
  pred$begin_time <- pred$file_offset
  pred$end_time <- pred$file_offset + 3
  minutos <- suppressMessages(select_clips(
    pred, "random_recordings", occasion_unit = "minute",
    n_recordings_per_site = 100, recordings = rec_lista(),
    recording_duration = 120))
  minutos$verdict <- ifelse(minutos$clip_start == 0, "negative", "positive")
  m <- det(pred, previous = minutos)
  expect_true(all(m$inherited_verdict[m$clip_start == 0] == "negative"))
  expect_true(all(is.na(m$inherited_verdict[m$clip_start == 70])))

  # predicao positiva vale para o minuto dela, e nao para o outro
  d <- det(pred)
  d$verdict <- ifelse(d$clip_start == 70, "positive", "negative")
  mm <- suppressMessages(select_clips(
    pred, "random_recordings", occasion_unit = "minute",
    n_recordings_per_site = 100, recordings = rec_lista(),
    recording_duration = 120, previous = d, inherit = TRUE))
  expect_true(all(mm$inherited_verdict[mm$clip_start == 60] == "positive"))
  expect_true(all(is.na(mm$inherited_verdict[mm$clip_start == 0])))

  # arquivo sem duracao conhecida cobre o arquivo inteiro
  arq <- suppressMessages(select_clips(
    pred, "random_recordings", n_recordings_per_site = 100,
    recordings = rec_lista()))
  arq$verdict <- "negative"
  expect_true(all(det(pred, previous = arq)$inherited_verdict == "negative"))
})

test_that("the draw does not depend on the earlier design", {
  pred <- inherit_pred()
  sozinho <- suppressMessages(select_clips(
    pred, "random_detections", threshold = 0.5, strata = "site_species",
    n_top = 1))
  r <- rec()
  r$verdict <- "negative"
  depois <- suppressMessages(select_clips(
    pred, "random_detections", threshold = 0.5, strata = "site_species",
    n_top = 1, previous = r))
  expect_identical(depois$occasion_id, sozinho$occasion_id)
  expect_identical(depois$inclusion_prob, sozinho$inclusion_prob)
  expect_identical(unique(depois$round), 1L)
  # caps seguem valendo entre desenhos
  expect_no_error(suppressMessages(select_clips(
    pred, "random_detections", threshold = 0.5, strata = "site_species",
    previous = r, max_per_species = 1)))
})

test_that("the other design must have verdicts and be random", {
  expect_error(det(previous = rec()), "validation_by_clip")
  top <- suppressMessages(select_clips(inherit_pred(), "top"))
  top$verdict <- "positive"
  expect_error(det(previous = top), "same design")
})

test_that("inherited verdicts do not propagate", {
  r <- rec()
  r$verdict <- "negative"
  d <- det(previous = r)
  d$verdict <- d$inherited_verdict
  m <- rec(previous = d)
  expect_false(any(m$previously_reviewed))
})

test_that("inherited clips are skipped, filled in and not exported", {
  r <- rec()
  r$verdict <- ifelse(grepl("0101", r$source_audio), "negative", "positive")
  m <- det(previous = r)
  d <- withr::local_tempdir()
  cortado <- suppressMessages(suppressWarnings(
    cut_clips(m, d, simulate = TRUE)))
  herdado <- !is.na(m$inherited_verdict)
  expect_true(all(cortado$status[herdado] == "inherited"))
  expect_false(any(cortado$status[!herdado] == "inherited"))

  caminho <- file.path(d, "m.csv")
  readr::write_csv(cortado, caminho)
  # o corte foi simulado: a fila precisa dos arquivos dos clipes
  file.create(file.path(d, "clips", m$species_folder[!herdado],
                        m$clip_file[!herdado]))
  fila <- sheepdog:::review_queue(caminho, file.path(d, "clips"))
  expect_equal(nrow(fila), sum(!herdado))

  log <- dplyr::transmute(m[!herdado, ], species_folder, clip_file,
                          reviewer = "x", verdict = "positive",
                          time = "2024-01-01 00:00:00")
  readr::write_csv(log, file.path(d, "v.csv"))
  val <- suppressMessages(app_verdicts(caminho, file.path(d, "v.csv"),
                                       clips_dir = file.path(d, "clips")))
  expect_true(all(val$verdict[herdado] == "negative"))
  expect_true(all(is.na(val$reviewed_path[herdado])))
  expect_true(all(val$verdict[!herdado] == "positive"))

  # um veredito dado de fato prevalece sobre o herdado
  t <- val
  t$verdict[herdado][1] <- "positive"
  t2 <- sheepdog:::fill_inherited(t)
  expect_identical(t2$verdict[herdado][1], "positive")
  expect_true(is.na(t2$inherited_verdict[herdado][1]))
})

test_that("retraining_clips() leaves out recordings with an inherited verdict", {
  v <- tibble::tibble(site = "A", species_code = "s", species_folder = "s",
                      clip_file = c("a", "b"), reviewed_path = c("p", NA),
                      confidence = NA_real_, night = "1", recording_hour = "1",
                      source_audio = "x", verdict = "positive",
                      inherited_verdict = c(NA, "positive"))
  expect_identical(retraining_clips(v)$clip_file, "a")
})

test_that("the export keeps each occasion where it was reviewed", {
  oc <- tibble::tibble(site = "A", occasion_id = c("o1", "o2"))
  base <- tibble::tibble(site = "A", species_code = "Sp_one",
                         clip_start = 0, clip_end = 3, confidence = 0.8,
                         inclusion_prob = 0.5, n_detections_occasion = 1L)
  v <- dplyr::bind_rows(
    dplyr::mutate(base, occasion_id = "o1", sampling_mode = "random_recordings",
                  verdict = "negative", inherited_verdict = NA_character_),
    dplyr::mutate(base, occasion_id = "o1", sampling_mode = "random_detections",
                  verdict = "negative", inherited_verdict = "negative"),
    dplyr::mutate(base, occasion_id = "o2", sampling_mode = "random_detections",
                  verdict = "positive", inherited_verdict = NA_character_),
    dplyr::mutate(base, occasion_id = "o2", sampling_mode = "random_recordings",
                  verdict = "positive", inherited_verdict = "positive"))
  expect_warning(out <- sheepdog:::export_validation(v, oc), "chosen by")
  expect_identical(out$validation$occasion_id, "o2")
  expect_identical(out$recordings_verified$occasion_id, "o1")

  # revisoes de verdade nas duas tabelas: aviso, e nada e tirado
  v$inherited_verdict <- NA_character_
  expect_warning(out <- sheepdog:::export_validation(v, oc), "independent")
  expect_equal(nrow(out$validation), 2)
})
