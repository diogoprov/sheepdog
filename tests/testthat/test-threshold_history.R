dados_historico <- function() {
  detections <- data.frame(
    site = "A",
    species_code = c(rep("Boana raniceps_boa-ran", 4),
                     rep("Dendropsophus nanus_den-nan", 2)),
    confidence = c(0.9, 0.8, 0.3, 0.75, 0.95, 0.05),
    begin_path = c("x/A_20240110_200000.wav", "x/A_20240110_210000.wav",
                   "x/A_20240111_200000.wav", "x/A_20240112_020000.wav",
                   "x/A_20240113_200000.wav", "x/A_20240114_200000.wav"))
  thresholds <- data.frame(site = "A", species_folder = "boa_ran",
                           threshold = 0.7)
  list(det = detections, thr = thresholds)
}

test_that("threshold_history() counts reliable detections per night", {
  d <- dados_historico()
  h <- suppressMessages(threshold_history(d$det, d$thr))
  expect_named(h, c("site", "species", "night", "n_detections", "n_reliable",
                    "confidence_max", "detection_k1", "detection_k2",
                    "detection_k3", "detection"))
  boa <- h[h$species == "boa_ran", ]
  # a gravacao das 02h de 12/01 e da noite de 11/01
  expect_identical(boa$night, c("20240110", "20240111"))
  expect_identical(boa$n_detections, c(2L, 2L))
  expect_identical(boa$n_reliable, c(2L, 1L))
  expect_identical(boa$detection_k1, c(1L, 1L))
  expect_identical(boa$detection_k2, c(1L, 0L))
  expect_identical(boa$confidence_max, c(0.9, 0.75))
})

test_that("nights of cells without a threshold stay as effort", {
  d <- dados_historico()
  expect_message(h <- threshold_history(d$det, d$thr), "without a threshold")
  den <- h[h$species == "den_nan", ]
  expect_identical(den$night, "20240113")
  expect_true(is.na(den$n_reliable) && is.na(den$detection_k1))

  # esforco: 3 noites, e nao as 2 de boa_ran, com a noite de den_nan contada
  m <- community_matrices(h, core_species = "boa_ran", k_min = 1,
                          min_nights_month = 1)
  expect_identical(m$effort$n_nights_recorded, 3L)
  expect_equal(m$frequency$boa_ran, 2 / 3)
})

test_that("a missing threshold in the table means no threshold", {
  d <- dados_historico()
  d$thr <- rbind(d$thr, data.frame(site = "A", species_folder = "den_nan",
                                   threshold = NA_real_))
  h <- suppressMessages(threshold_history(d$det, d$thr))
  expect_true(is.na(h$detection_k1[h$species == "den_nan"]))
})

test_that("min_confidence, dawn_hour and the repetition rule are used", {
  d <- dados_historico()
  h <- suppressMessages(threshold_history(d$det, d$thr, min_confidence = 0.5,
                                          dawn_hour = 1,
                                          min_detections_night = 2))
  boa <- h[h$species == "boa_ran", ]
  expect_identical(boa$night, c("20240110", "20240112"))
  expect_identical(boa$detection, c(1L, 0L))
})

test_that("threshold_history() takes the output of review_support()", {
  ex <- system.file("extdata", "example", package = "sheepdog")
  arqs <- list.files(file.path(ex, "validation"), full.names = TRUE)
  val <- purrr::list_rbind(purrr::map(arqs, readr::read_csv,
                                      show_col_types = FALSE))
  det <- suppressMessages(read_selection_tables(file.path(ex, "birdnet")))
  s <- review_support(val, det, conf_high = 0.7, min_n = 15)
  h <- suppressMessages(threshold_history(det, s))
  expect_setequal(unique(h$site), unique(det$site))
  com_limiar <- paste(s$site, s$species_folder)[!is.na(s$threshold)]
  cela <- paste(h$site, h$species) %in% com_limiar
  expect_false(anyNA(h$detection_k1[cela]))
  expect_true(all(is.na(h$detection_k1[!cela])))
})

test_that("bad input stops with a clear error", {
  d <- dados_historico()
  expect_error(threshold_history(d$det[-3], d$thr), "confidence")
  expect_error(threshold_history(d$det, d$thr[-3]), "threshold")
  expect_error(threshold_history(d$det, rbind(d$thr, d$thr)), "one row per")
})
