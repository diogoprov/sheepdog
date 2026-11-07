# WAV PCM 16 bits mono com silencio, para testar o corte de verdade
write_silent_wav <- function(caminho, segundos = 5, taxa = 8000) {
  n <- segundos * taxa
  con <- file(caminho, "wb")
  on.exit(close(con))
  writeChar("RIFF", con, eos = NULL)
  writeBin(as.integer(36 + 2 * n), con, size = 4, endian = "little")
  writeChar("WAVEfmt ", con, eos = NULL)
  writeBin(c(16L), con, size = 4, endian = "little")
  writeBin(c(1L, 1L), con, size = 2, endian = "little")
  writeBin(c(as.integer(taxa), as.integer(2 * taxa)), con, size = 4,
           endian = "little")
  writeBin(c(2L, 16L), con, size = 2, endian = "little")
  writeChar("data", con, eos = NULL)
  writeBin(as.integer(2 * n), con, size = 4, endian = "little")
  writeBin(integer(n), con, size = 2, endian = "little")
}

manifesto_teste <- function(origens, inicio = 1, duracao = 2) {
  tibble::tibble(
    site = "S", species_code = "Boana raniceps_boa-ran",
    species_folder = "boa_ran", clip_file = paste0("c", seq_along(origens),
                                                   ".wav"),
    clip_start = inicio, duration = duracao, source_audio = origens,
    begin_path = origens, sampling_mode = "top")
}

for (nm in c("top_default", "det_minute_meta", "rec_table")) {
  test_that(paste("extract_validation_clips() writes the v1.2.0 manifest:", nm), {
    saida <- withr::local_tempdir()
    args <- c(list(data_dir = file.path(sim_root(), "tabelas"),
                   output_dir = saida, simulate = TRUE),
              scenario_args(nm))
    suppressMessages(suppressWarnings(
      do.call(extract_validation_clips, args)))
    novo <- read_as_text(file.path(saida, "clip_manifest.csv"))
    novo[] <- lapply(novo, \(x) gsub(sim_root(), "<ROOT>", x, fixed = TRUE))
    ref <- ref_table(nm, "manifesto_clipes.csv")
    # colunas novas das rodadas de revisao ficam depois das da v1.2.0
    expect_identical(names(novo)[seq_along(ref)], names(ref))
    expect_same_table(novo[names(ref)], ref)
  })
}

test_that("cut_clips() cuts, skips existing clips and flags problems", {
  skip_if_not_installed("av")
  d <- withr::local_tempdir()
  wav <- file.path(d, "S01_20220110_190000.wav")
  write_silent_wav(wav)
  vazio <- file.path(d, "S01_20220110_200000.wav")
  file.create(vazio)
  man <- manifesto_teste(c(wav, file.path(d, "nao_existe.wav"), vazio))

  saida <- file.path(d, "saida")
  expect_warning(res <- suppressMessages(cut_clips(man, saida)),
                 "Some clips were not created")
  expect_identical(res$status[1:2], c("ok", "audio_not_found"))
  expect_match(res$status[3], "^error: ")
  expect_identical(match("status", names(res)), match("begin_path", names(res)) + 1L)
  clipe <- file.path(saida, "clips", "boa_ran", "c1.wav")
  expect_equal(av::av_media_info(clipe)$duration, 2, tolerance = 0.05)

  res2 <- suppressMessages(suppressWarnings(cut_clips(man, saida)))
  expect_identical(res2$status[1], "already_exists")
})

test_that("cut_clips() with simulate = TRUE writes no audio", {
  d <- withr::local_tempdir()
  wav <- file.path(d, "S01_20220110_190000.wav")
  file.create(wav)
  man <- manifesto_teste(c(wav, file.path(d, "nao_existe.wav")))
  res <- suppressMessages(suppressWarnings(
    cut_clips(man, d, simulate = TRUE)))
  expect_identical(res$status, c("simulated", "audio_not_found"))
  expect_false(file.exists(file.path(d, "clips", "boa_ran", "c1.wav")))
})

test_that("pack_clips() zips one package per species", {
  d <- withr::local_tempdir()
  for (sp in c("boa_ran", "den_nan")) {
    dir.create(file.path(d, "clips", sp, "Positive"), recursive = TRUE)
    file.create(file.path(d, "clips", sp, paste0(sp, ".wav")))
    file.create(file.path(d, "clips", sp, "Positive", paste0(sp, "_p.wav")))
  }
  man <- tibble::tibble(species_folder = c("boa_ran", "den_nan", "boa_ran"))
  zips <- suppressMessages(pack_clips(man, d))
  expect_identical(zips, file.path(d, "packages", c("boa_ran.zip",
                                                    "den_nan.zip")))
  for (i in 1:2) {
    sp <- c("boa_ran", "den_nan")[i]
    arquivos <- zip::zip_list(zips[i])$filename
    expect_true(all(c(paste0(sp, "/", sp, ".wav"),
                      paste0(sp, "/Positive/", sp, "_p.wav")) %in% arquivos))
    expect_false(any(grepl(setdiff(c("boa_ran", "den_nan"), sp), arquivos)))
  }
})

test_that("extract_validation_clips() cuts, zips and resumes", {
  skip_if_not_installed("av")
  d <- withr::local_tempdir()
  dir.create(file.path(d, "dados", "output_S1"), recursive = TRUE)
  audio <- file.path(d, "dados", "S1_20220110_193000.wav")
  write_silent_wav(audio, segundos = 10)
  tab <- data.frame(
    "Begin Time (s)" = c(0, 3, 6), "End Time (s)" = c(3, 6, 9),
    "Species Code" = c("Boana raniceps_boa-ran", "Boana raniceps_boa-ran",
                       "Scinax nasicus_sci-nas"),
    "Confidence" = c(0.9, 0.5, 0.7), "Begin Path" = audio,
    "File Offset (s)" = c(0, 3, 6), check.names = FALSE)
  utils::write.table(tab, file.path(d, "dados", "output_S1",
                                    "BirdNET_SelectionTable.txt"),
                     sep = "\t", quote = FALSE, row.names = FALSE)
  saida <- file.path(d, "saida")
  man <- suppressMessages(
    extract_validation_clips(file.path(d, "dados"), saida))
  expect_identical(man$status, rep("ok", 3))
  expect_true(file.exists(file.path(saida, "clip_manifest.csv")))
  expect_setequal(list.files(file.path(saida, "packages")),
                  c("boa_ran.zip", "sci_nas.zip"))
  expect_length(zip::zip_list(file.path(saida, "packages",
                                        "boa_ran.zip"))$filename[
    grepl("\\.wav$", zip::zip_list(file.path(saida, "packages",
                                              "boa_ran.zip"))$filename)], 2)

  # segunda rodada: nada e cortado de novo
  antes <- file.mtime(list.files(file.path(saida, "clips"),
                                 recursive = TRUE, full.names = TRUE))
  man2 <- suppressMessages(
    extract_validation_clips(file.path(d, "dados"), saida, make_zip = FALSE))
  expect_identical(man2$status, rep("already_exists", 3))
  depois <- file.mtime(list.files(file.path(saida, "clips"),
                                  recursive = TRUE, full.names = TRUE))
  expect_identical(antes, depois)
})

test_that("extract_validation_clips() writes extraction_info.csv", {
  saida <- withr::local_tempdir()
  # os audios do exemplo nao existem: o aviso de clipes nao gerados e
  # esperado
  suppressWarnings(suppressMessages(extract_validation_clips(
    system.file("extdata", "example", "birdnet", package = "sheepdog"),
    saida, sampling_mode = "random_detections", threshold = 0.5,
    strata = "site_species", simulate = TRUE, classifier = "Test v1")))
  info <- readr::read_csv(file.path(saida, "extraction_info.csv"),
                          show_col_types = FALSE)
  expect_named(info, c("key", "value"))
  valor <- stats::setNames(info$value, info$key)
  expect_identical(valor[["classifier"]], "Test v1")
  expect_identical(valor[["select_clips.sampling_mode"]], "random_detections")
  expect_identical(valor[["select_clips.threshold"]], "0.5")
  expect_identical(valor[["sheepdog_version"]],
                   as.character(utils::packageVersion("sheepdog")))
})
