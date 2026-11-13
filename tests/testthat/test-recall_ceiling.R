# recall_ceiling(): teto de recall e recall no limiar, pelas gravacoes
# anotadas de ouvido

# Seis ocasioes anotadas da especie A no local S1; a especie esta em quatro
teto_dados <- function() {
  sp <- "Especie a_esp-a"
  val <- tibble::tibble(
    site = "S1", species_code = sp,
    occasion_id = paste0("S1_2024010", 1:6, "_200000"),
    source_audio = paste0("/r/S1_2024010", 1:6, "_200000.wav"),
    sampling_mode = "random_recordings",
    verdict = c("positive", "positive", "positive", "positive", "negative",
                "negative"),
    inclusion_prob = c(0.5, 0.5, 0.5, 0.25, 0.5, 0.5))
  det <- tibble::tibble(
    site = "S1", species_code = sp,
    begin_path = paste0("/r/S1_2024010", c(1, 1, 2, 4, 5), "_200000.wav"),
    file_offset = c(0, 3, 6, 0, 9),
    confidence = c(0.9, 0.3, 0.4, 0.6, 0.8))
  list(val = val, det = det)
}

test_that("the ceiling and the recall are weighted ratios", {
  x <- teto_dados()
  r <- recall_ceiling(x$val, x$det, thresholds = c(0.5, 0.95), n_boot = 0)
  expect_equal(nrow(r), 2)
  expect_equal(r$n_occasions, c(6, 6))
  expect_equal(r$n_present, c(4, 4))
  expect_equal(r$n_missed, c(1, 1))
  # presentes: pesos 2, 2, 2, 4; detectadas: 1, 2 e 4 (a 3 nao tem predicao)
  expect_equal(r$recall_ceiling, c(0.8, 0.8))
  # >= 0.5: ocasioes 1 (0.9) e 4 (0.6), pesos 2 + 4
  expect_equal(r$recall[r$threshold == 0.5], 0.6)
  expect_equal(r$share_above[r$threshold == 0.5], 0.75)
  expect_equal(r$recall[r$threshold == 0.95], 0)
  expect_true(all(is.na(r$recall_lower)))
  # so o teto, sem limiares
  s <- recall_ceiling(x$val, x$det, n_boot = 0)
  expect_equal(nrow(s), 1)
  expect_false("recall" %in% names(s))
  # um min_confidence mais alto deixa de contar a ocasiao 2 (0.4)
  m <- recall_ceiling(x$val, x$det, min_confidence = 0.5, n_boot = 0)
  expect_equal(m$recall_ceiling, 0.6)
})

test_that("the bootstrap gives intervals around the estimates", {
  x <- teto_dados()
  r <- recall_ceiling(x$val, x$det, thresholds = 0.5, n_boot = 200)
  expect_true(r$ceiling_lower <= r$recall_ceiling)
  expect_true(r$ceiling_upper >= r$recall_ceiling)
  expect_true(r$recall_lower <= r$recall & r$recall <= r$recall_upper)
  r2 <- recall_ceiling(x$val, x$det, thresholds = 0.5, n_boot = 200)
  expect_identical(r$ceiling_lower, r2$ceiling_lower)
})

test_that("thresholds can come per group from a table", {
  x <- teto_dados()
  outra <- x$val
  outra$site <- "S2"
  outra$occasion_id <- sub("S1", "S2", outra$occasion_id)
  outra$source_audio <- sub("S1", "S2", outra$source_audio)
  det2 <- x$det
  det2$site <- "S2"
  det2$begin_path <- sub("S1", "S2", det2$begin_path)
  val <- rbind(x$val, outra)
  det <- rbind(x$det, det2)
  thr <- tibble::tibble(site = c("S1", "S2"), species_folder = "esp_a",
                        threshold = c(0.5, 0.85))
  r <- recall_ceiling(val, det, thresholds = thr,
                      by = c("site", "species_folder"), n_boot = 0)
  expect_equal(r$threshold, c(0.5, 0.85))
  expect_equal(r$recall, c(0.6, 0.2))
  # a mesma tabela com by mais grosso tem dois limiares por grupo
  expect_error(recall_ceiling(val, det, thresholds = thr, n_boot = 0),
               "more than one threshold")
  # outra coluna da tabela
  thr$threshold_conservative <- c(0.95, 0.95)
  r <- recall_ceiling(val, det, thresholds = thr, n_boot = 0,
                      by = c("site", "species_folder"),
                      threshold_column = "threshold_conservative")
  expect_equal(r$recall, c(0, 0))
})

test_that("recall_ceiling() checks its inputs", {
  x <- teto_dados()
  expect_error(recall_ceiling(dplyr::mutate(x$val, sampling_mode = "top"),
                              x$det), "No occasion of \"random_recordings\"")
  expect_error(recall_ceiling(x$val[, -1], x$det), "lacks column")
  expect_error(recall_ceiling(x$val, x$det[, -4]), "read_selection_tables")
  expect_error(recall_ceiling(x$val, x$det, thresholds = 1.5),
               "between 0 and 1")
  expect_error(recall_ceiling(x$val, x$det, thresholds = list(1)),
               "numeric vector or a table")
  expect_error(recall_ceiling(x$val, x$det, conf = 2), "between 0 and 1")
  expect_error(recall_ceiling(x$val, x$det, by = "month"), "month")
  expect_error(recall_ceiling(x$val, x$det, cluster = "night"),
               "not a column")
  expect_error(recall_ceiling(x$val, x$det,
                              thresholds = data.frame(species_folder = "a")),
               "lacks column")
  sem <- x$val
  sem$inclusion_prob <- NULL
  expect_message(r <- recall_ceiling(sem, x$det, n_boot = 0),
                 "same weight")
  expect_equal(r$recall_ceiling, 0.75)
  # unidade de ocasiao errada: nenhuma ocasiao casa com as predicoes
  expect_warning(recall_ceiling(x$val, x$det, occasion_unit = "minute",
                                n_boot = 0), "occasion_unit")
})

test_that("a group without the species gets NA", {
  x <- teto_dados()
  x$val$verdict <- "negative"
  r <- recall_ceiling(x$val, x$det, thresholds = 0.5, n_boot = 50)
  expect_equal(r$n_present, 0)
  expect_true(is.na(r$recall_ceiling))
  expect_true(is.na(r$recall))
  expect_true(is.na(r$ceiling_lower))
})

test_that("it works on a random_recordings draw of the simulated survey", {
  val <- sim_validation(sim_pred(), "random_recordings",
                        recording_fraction = 0.5)
  r <- do.call(recall_ceiling, c(list(val, sim_pred(), thresholds = 0.5,
                                      n_boot = 50), remap()))
  expect_true(all(r$recall_ceiling >= r$recall, na.rm = TRUE))
  expect_true(all(r$recall_ceiling <= 1, na.rm = TRUE))
  expect_gt(sum(r$n_present), 0)
})
