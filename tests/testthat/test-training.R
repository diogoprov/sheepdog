# Clipes revisados simulados: arquivos vazios em Positive/Negative
revisao_simulada <- function(d) {
  val <- read_validation_tables(list.files(
    system.file("extdata", "example", "validation", package = "sheepdog"),
    full.names = TRUE))
  dest <- file.path(d, "review", val$species_folder,
                    ifelse(val$verdict == "positive", "Positive", "Negative"))
  for (x in unique(dest)) dir.create(x, recursive = TRUE)
  file.create(file.path(dest, val$clip_file))
  suppressMessages(classify_review(
    dplyr::select(val, -verdict, -reviewed_path), file.path(d, "review")))
}

test_that("read_validation_tables() stacks every column and verdict", {
  f <- list.files(system.file("extdata", "example", "validation",
                              package = "sheepdog"), full.names = TRUE)
  val <- read_validation_tables(f)
  expect_true(all(c("verdict", "species_folder", "reviewed_path") %in%
                    names(val)))
  expect_type(val$night, "character")
  expect_identical(nrow(val), sum(vapply(f, \(x) nrow(read.csv(x)),
                                         integer(1))))
  expect_warning(read_validation_tables(c(f[1], "nao_existe.csv")),
                 "Not found")
})

test_that("build_training_set() builds the BirdNET layout", {
  d <- withr::local_tempdir()
  rev <- revisao_simulada(d)
  out <- file.path(d, "training")
  ts <- suppressWarnings(suppressMessages(
    build_training_set(rev, out, test_sites = "NHE")))
  expect_setequal(unique(ts$set), c("train", "test"))
  expect_true(all(ts$set[ts$site == "NHE"] == "test"))
  pastas <- list.dirs(file.path(out, "train"), recursive = FALSE,
                      full.names = FALSE)
  expect_true("-Boana raniceps_boa-ran" %in% pastas)
  expect_true("Boana raniceps_boa-ran" %in% pastas)
  n_pos <- length(list.files(file.path(out, "train",
                                       "Boana raniceps_boa-ran")))
  expect_identical(n_pos, sum(ts$set == "train" & ts$verdict == "positive" &
                                ts$species_code == "Boana raniceps_boa-ran"))
  expect_true(file.exists(file.path(out, "training_set.csv")))
  # classes com poucos arquivos avisam
  expect_warning(suppressMessages(
    build_training_set(rev, file.path(d, "t2"), min_files = 1e6)),
    "fewer than")
  # sem negativos
  ts2 <- suppressWarnings(suppressMessages(
    build_training_set(rev, file.path(d, "t3"), negatives = FALSE)))
  expect_true(all(ts2$verdict == "positive"))
})

test_that("exclude_training_clips() drops overlapping clips", {
  man <- tibble::tibble(
    species_code = c("a", "a", "a", "b"),
    source_audio = c("x.wav", "x.wav", "y.wav", "x.wav"),
    clip_start = c(0, 6, 0, 0), clip_end = c(3, 9, 3, 3))
  treino <- tibble::tibble(species_code = "a", source_audio = "x.wav",
                           clip_start = 1.5, clip_end = 4.5)
  out <- suppressMessages(exclude_training_clips(man, treino))
  # so o 1o clipe se sobrepoe (mesma especie, mesma gravacao)
  expect_identical(nrow(out), 3L)
  expect_false(any(out$species_code == "a" & out$source_audio == "x.wav" &
                     out$clip_start == 0))
})

test_that("training copies omit unlocalised recordings and keep provenance", {
  d <- withr::local_tempdir()
  reviewed <- file.path(d, c("good.wav", "whole.wav"))
  file.create(reviewed)
  v <- tibble::tibble(site = "A", species_code = "sp", clip_file = basename(reviewed),
                      verdict = "positive", reviewed_path = reviewed,
                      confidence = c(.9, NA_real_))
  expect_message(out <- build_training_set(
    v, file.path(d, "train"), min_files = 1), "whole-recording")
  expect_identical(out$clip_file, "good.wav")
  expect_true(all(is.na(out$source_audio)))
  expect_equal(readr::read_csv(file.path(d, "train", "training_set.csv"),
                               show_col_types = FALSE)$clip_file, "good.wav")
  expect_error(build_training_set(v[v$confidence %in% NA_real_, ],
                   file.path(d, "empty")), "No reviewed clip")
  expect_error(build_training_set(v[c("site", "verdict")], d), "lacks the column")
})

test_that("missing training clips warn without claiming successful copies", {
  d <- withr::local_tempdir()
  v <- tibble::tibble(site = "A", species_code = "sp", clip_file = "missing.wav",
                      verdict = "positive", reviewed_path = file.path(d, "missing.wav"))
  expect_warning(out <- suppressMessages(build_training_set(v, file.path(d, "out"),
                         min_files = 0)), "could not be copied")
  expect_equal(nrow(out), 0L)
})

test_that("training exclusion handles missing provenance and touching intervals", {
  man <- tibble::tibble(species_code = "sp", source_audio = "same.wav",
                        clip_start = c(0, 3, 6), clip_end = c(3, 6, 9))
  ts <- tibble::tibble(species_code = "sp", source_audio = "same.wav",
                       clip_start = 3, clip_end = 6)
  d <- withr::local_tempfile(fileext = ".csv")
  readr::write_csv(ts, d)
  out <- suppressMessages(exclude_training_clips(man, d))
  expect_equal(out$clip_start, c(0, 6))
  ts$clip_start <- NA_real_
  expect_warning(kept <- exclude_training_clips(man, ts), "nothing excluded")
  expect_identical(kept, man)
  ts$clip_start <- 20; ts$clip_end <- 23
  expect_identical(suppressMessages(exclude_training_clips(man, ts)), man)
  expect_error(read_validation_tables(character()), "No validation table")
})

# Clipes revisados sinteticos: 2 locais x 10 noites x 2 especies, com as
# mesmas noites para as duas especies (uma gravacao por noite)
treino_sintetico <- function() {
  grade <- tidyr::expand_grid(site = c("A", "B"),
                              night = sprintf("202110%02d", 1:10),
                              species_folder = c("sp_a", "sp_b"),
                              k = 1:4)
  dplyr::mutate(grade,
    species_code = paste0("Sp ", species_folder),
    verdict = ifelse(k <= 3, "positive", "negative"),
    confidence = 0.9,
    source_audio = paste0(site, "01_", night, "_200000.wav"),
    clip_start = (k - 1) * 3 + ifelse(species_folder == "sp_a", 0, 30),
    clip_end = clip_start + 3,
    clip_file = paste0(species_folder, "_", source_audio, "_", k, ".wav"),
    reviewed_path = file.path("E:/revisado", clip_file))
}

test_that("a night split holds out whole nights for all species", {
  val <- treino_sintetico()
  d <- withr::local_tempdir()
  set.seed(5)
  antes <- .Random.seed
  ts <- suppressMessages(build_training_set(val, d, split = "night",
                                            copy = FALSE, min_files = 0))
  expect_identical(.Random.seed, antes)
  # ceiling(10 * 0.2) = 2 noites de teste por local, para as duas especies
  noites <- dplyr::distinct(ts, site, night, set)
  expect_identical(as.integer(table(noites$site[noites$set == "test"])),
                   c(2L, 2L))
  expect_identical(nrow(dplyr::distinct(noites, site, night)), nrow(noites))
  expect_true(all(attr(ts, "checks") == 0))
  # nada copiado, so a tabela
  expect_true(file.exists(file.path(d, "training_set.csv")))
  expect_false(dir.exists(file.path(d, "train")))
  # mesma semente, mesmo sorteio; outra semente, outro sorteio
  ts2 <- suppressMessages(build_training_set(val, d, split = "night",
                                             copy = FALSE, min_files = 0))
  expect_identical(ts$set, ts2$set)
  ts3 <- suppressMessages(build_training_set(val, d, split = "night",
                                             seed = 1, copy = FALSE,
                                             min_files = 0))
  expect_false(identical(ts$set, ts3$set))
  expect_error(build_training_set(dplyr::select(val, -night), d,
                                  split = "night"), "lacks the column `night`")
  expect_error(build_training_set(val, d, split = "night", test_prop = 1),
               "between 0 and 1")
})

test_that("nights in exclude_from_test never reach the test set", {
  val <- treino_sintetico()
  d <- withr::local_tempdir()
  guarda <- tibble::tibble(site = "A", night = sprintf("202110%02d", 1:8))
  ts <- suppressMessages(build_training_set(
    val, d, split = "night", exclude_from_test = guarda, copy = FALSE,
    min_files = 0))
  teste_a <- unique(ts$night[ts$site == "A" & ts$set == "test"])
  # so 2 noites elegiveis em A, e ceiling(2 * 0.2) = 1 vai para o teste
  expect_length(teste_a, 1L)
  expect_true(teste_a %in% sprintf("202110%02d", 9:10))
  expect_true(all(attr(ts, "checks") == 0))
  expect_error(build_training_set(val, d, split = "night", copy = FALSE,
                                  exclude_from_test = guarda["site"]),
               "lacks the column")
})

test_that("a site_species_night split warns and its checks catch leaks", {
  val <- treino_sintetico()
  d <- withr::local_tempdir()
  expect_warning(ts <- suppressMessages(build_training_set(
    val, d, split = "site_species_night", copy = FALSE, min_files = 0)),
    "not independent")
  # 2 noites de teste por local x especie, sorteadas em separado
  n_teste <- dplyr::distinct(ts, site, species_code, night, set) |>
    dplyr::count(site, species_code, set)
  expect_true(all(n_teste$n[n_teste$set == "test"] == 2L))
  expect_gt(attr(ts, "checks")[["test_nights_in_train"]], 0)
  expect_error(suppressWarnings(suppressMessages(build_training_set(
    val, d, split = "site_species_night", copy = FALSE, strict = TRUE))),
    "not independent")
  # local inteiro, como antes
  ts_site <- suppressMessages(build_training_set(
    val, d, test_sites = "B", copy = FALSE, min_files = 0))
  expect_true(all(ts_site$set == ifelse(ts_site$site == "B", "test",
                                        "train")))
  expect_warning(suppressMessages(build_training_set(
    val, d, split = "none", test_sites = "B", copy = FALSE, min_files = 0)),
    "ignored")
})

test_that("max_per_site_species caps training positives across nights", {
  val <- treino_sintetico()
  d <- withr::local_tempdir()
  expect_message(ts <- build_training_set(
    val, d, split = "night", max_per_site_species = 8, copy = FALSE,
    min_files = 0, remap_from = "E:/revisado", remap_to = "/mnt/revisado"),
    "160 -> 96")
  pos <- dplyr::filter(ts, set == "train", verdict == "positive")
  por_celula <- dplyr::count(pos, site, species_code)
  expect_true(all(por_celula$n == 8L))
  # 8 clipes de 8 noites de treino: um por noite
  expect_true(all(dplyr::count(pos, site, species_code, night)$n == 1L))
  # teste e negativos intactos
  sem_teto <- suppressMessages(build_training_set(val, d, split = "night",
                                                  copy = FALSE,
                                                  min_files = 0))
  fora <- function(x) dplyr::filter(x, set == "test" | verdict == "negative")
  expect_setequal(fora(ts)$clip_file, fora(sem_teto)$clip_file)
  expect_true(all(startsWith(ts$from, "/mnt/revisado/")))
})

test_that("val_prop draws validation nights after the test set and the cap", {
  val <- treino_sintetico()
  d <- withr::local_tempdir()
  guarda <- tibble::tibble(site = "A", night = sprintf("202110%02d", 1:6))
  q <- function(...) suppressMessages(build_training_set(
    val, d, split = "night", max_per_site_species = 12, copy = FALSE,
    min_files = 0, exclude_from_test = guarda, ...))
  ts <- q(val_prop = 0.25)
  noites <- dplyr::distinct(ts, site, night, set)
  # cada noite num conjunto so; teste e treino como sem validacao
  expect_identical(nrow(dplyr::distinct(noites, site, night)), nrow(noites))
  sem <- q()
  expect_identical(ts$set == "test", sem$set == "test")
  expect_identical(ts$clip_file, sem$clip_file)
  # B: 8 noites de treino, ceiling(8 * 0.25) = 2 de validacao; A: so as
  # noites fora da guarda e do teste
  n_val <- dplyr::count(dplyr::filter(noites, set == "val"), site)
  expect_identical(n_val$n, c(1L, 2L))
  expect_false(any(ts$night[ts$set == "val" & ts$site == "A"] %in%
                     guarda$night))
  ck <- attr(ts, "checks")
  expect_named(ck, c("test_nights_in_train", "test_nights_excluded",
                     "test_clips_overlapping_train", "val_nights_in_train",
                     "val_nights_excluded"))
  expect_true(all(ck == 0))
  expect_named(attr(sem, "checks"), names(ck)[1:3])
  expect_true(all(startsWith(ts$to[ts$set == "val"], file.path(d, "val"))))
  # igual a uma segunda chamada sobre as linhas de treino, com seed + 1
  treino <- dplyr::filter(sem, set == "train") |>
    dplyr::mutate(reviewed_path = from)
  div <- suppressMessages(build_training_set(
    treino, d, split = "night", test_prop = 0.25, seed = 2027,
    exclude_from_test = guarda, copy = FALSE, min_files = 0))
  noites_val <- dplyr::distinct(dplyr::filter(div, set == "test"), site,
                                night)
  expect_equal(dplyr::arrange(noites_val, site, night),
               dplyr::arrange(dplyr::distinct(dplyr::filter(
                 ts, set == "val"), site, night), site, night),
               ignore_attr = TRUE)
  expect_false(identical(q(val_prop = 0.25, val_seed = 1)$set, ts$set))
  expect_error(q(val_prop = 1), "between 0 and 1")
  expect_error(build_training_set(dplyr::select(val, -night), d,
                                  val_prop = 0.2, copy = FALSE),
               "lacks the column `night`")
})

test_that("negatives_folder puts every negative in a non-event folder", {
  d <- withr::local_tempdir()
  rev <- revisao_simulada(d)
  out <- file.path(d, "training")
  ts <- suppressWarnings(suppressMessages(build_training_set(
    rev, out, test_sites = "NHE", negatives_folder = "Noise")))
  neg <- ts[ts$verdict == "negative", ]
  expect_true(all(neg$class_folder == "Noise"))
  expect_false(any(startsWith(ts$class_folder, "-")))
  pastas <- list.dirs(file.path(out, "train"), recursive = FALSE,
                      full.names = FALSE)
  expect_true("Noise" %in% pastas)
  # o arquivo leva especie e local; o clip_file da tabela nao muda
  esperado <- paste(sub("^.*_", "", neg$species_code), neg$site,
                    neg$clip_file, sep = "-")
  expect_identical(basename(neg$to), esperado)
  expect_true(all(file.exists(neg$to)))
  expect_identical(anyDuplicated(ts$to), 0L)
  # mesma divisao e mesma exclusao que com as pastas "-classe"
  ts0 <- suppressWarnings(suppressMessages(build_training_set(
    rev, file.path(d, "t0"), test_sites = "NHE", copy = FALSE)))
  expect_identical(ts$set, ts0$set)
  man <- suppressMessages(read_validation_tables(list.files(
    system.file("extdata", "example", "validation", package = "sheepdog"),
    full.names = TRUE)))
  expect_identical(
    suppressMessages(exclude_training_clips(man, ts))$clip_file,
    suppressMessages(exclude_training_clips(man, ts0))$clip_file)
  # qualquer caixa das classes sem evento; outro nome e erro
  ts_s <- suppressWarnings(suppressMessages(build_training_set(
    rev, file.path(d, "t1"), test_sites = "NHE", copy = FALSE,
    negatives_folder = "silence")))
  expect_true(all(ts_s$class_folder[ts_s$verdict == "negative"] ==
                    "silence"))
  expect_error(build_training_set(rev, out, negatives_folder = "Negatives"),
               "non-event class")
})

test_that("training_nights() reads site, recording and night from names", {
  d <- withr::local_tempdir()
  dir.create(file.path(d, "classe", "sub"), recursive = TRUE)
  file.create(file.path(d, "classe", "sub", "BEP201_20211003_200000_1.wav"))
  expect_warning(tn <- training_nights(
    c("x_ARA01_20211001_190000_3.0s_6.0s.wav",
      "ARA01_20211002_013000_9.0s.wav", "FNJV_0042_Boana.wav",
      file.path(d, "classe")),
    site_map = c(BEP = "BEP2")), "do not match")
  expect_named(tn, c("file", "site", "recording", "night"))
  expect_identical(tn$site, c("ARA", "ARA", "BEP2"))
  expect_identical(tn$recording, c("ARA_20211001_190000",
                                   "ARA_20211002_013000",
                                   "BEP_20211003_200000"))
  # antes do meio-dia, a noite anterior
  expect_identical(tn$night, c("20211001", "20211001", "20211003"))
  proprio <- training_nights("P_X9_20211001_050000.wav",
                             "_(?<site>[A-Z0-9]+)_(?<date>\\d{8})_(?<time>\\d{6})",
                             night_cutoff = 4)
  expect_identical(c(proprio$site, proprio$night), c("X9", "20211001"))
  expect_error(training_nights("a.wav", "(\\d{8})"), "named groups")
})

test_that("exclude_training_clips() drops by recording or night", {
  man <- tibble::tibble(
    site = "A", species_code = c("a", "a", "b", "a", "b"),
    night = c("20211001", "20211001", "20211001", "20211001", "20211002"),
    source_audio = c("A01_20211001_200000.wav", "A01_20211001_200000.wav",
                     "A01_20211001_200000.wav", "A01_20211001_220000.wav",
                     "A01_20211002_200000.wav"),
    clip_start = c(0, 30, 0, 0, 0), clip_end = c(3, 33, 3, 3, 3))
  ts <- tibble::tibble(site = "A", species_code = "a", night = "20211001",
                       source_audio = "A01_20211001_200000.wav",
                       clip_start = 0, clip_end = 3)
  q <- function(...) suppressMessages(exclude_training_clips(man, ts, ...))
  expect_identical(nrow(q()), 4L)
  expect_identical(nrow(q(level = "recording")), 3L)
  expect_identical(nrow(q(level = "recording", any_species = TRUE)), 2L)
  expect_identical(nrow(q(level = "night")), 2L)
  expect_identical(nrow(q(level = "night", any_species = TRUE)), 1L)
  # a tabela de training_nights() vale para toda especie
  tn <- training_nights("treino_A01_20211001_200000_1.wav")
  expect_message(r <- exclude_training_clips(man, tn, level = "recording"),
                 "every species")
  expect_identical(nrow(r), 2L)
  expect_identical(nrow(suppressMessages(
    exclude_training_clips(man, tn, level = "night"))), 1L)
  expect_error(exclude_training_clips(man, tn), "no clip times")
  expect_error(exclude_training_clips(man[c("species_code", "source_audio")],
                                      ts, level = "night"), "both need")
})

test_that("exclusion by recording reads source_audio with the pattern used", {
  # data_hora_local: o padrao default nao le esses nomes
  padrao <- "(?<date>\\d{8})_(?<time>\\d{6})_(?<site>[A-Z0-9]+)"
  man <- tibble::tibble(species_code = "a",
                        source_audio = c("20211001_200000_X9.wav",
                                         "20211002_200000_X9.wav"))
  tn <- training_nights("20211001_200000_X9_clip1.wav", padrao)
  expect_identical(attr(tn, "pattern"), padrao)
  r <- suppressMessages(exclude_training_clips(man, tn, level = "recording"))
  expect_identical(r$source_audio, "20211002_200000_X9.wav")
  # sem o atributo (tabela refeita), o padrao vai no argumento
  sem <- dplyr::bind_rows(tn[0, ], tibble::as_tibble(as.list(tn)))
  attr(sem, "pattern") <- NULL
  expect_warning(suppressMessages(
    exclude_training_clips(man, sem, level = "recording")), "matches")
  r2 <- suppressMessages(exclude_training_clips(man, sem, level = "recording",
                                                pattern = padrao))
  expect_identical(nrow(r2), 1L)
})
