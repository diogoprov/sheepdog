# sampling_mode = "score_bands": sorteio por estrato x faixa de score, para
# limiares e calibracao (nao para o modelo de falsos positivos)

pred_exemplo <- function() {
  ex <- system.file("extdata", "example", "birdnet", package = "sheepdog")
  suppressMessages(read_selection_tables(ex))
}

test_that("score_bands draws n_top clips per stratum and band", {
  det <- pred_exemplo()
  quebras <- c(0.1, 0.4, 0.7, 1)
  man <- suppressMessages(select_clips(det, "score_bands", n_top = 3,
                                       strata = "site_species",
                                       score_breaks = quebras))
  expect_true(all(man$sampling_mode == "score_bands"))
  expect_true(all(man$confidence >= 0.1))
  man$faixa <- cut(man$confidence, quebras, include.lowest = TRUE,
                   right = FALSE)
  por_celula <- dplyr::count(man, site, species_code, faixa)
  expect_true(all(por_celula$n <= 3))
  # a probabilidade de inclusao vem das candidatas de cada estrato x faixa
  det$faixa <- cut(det$confidence, quebras, include.lowest = TRUE,
                   right = FALSE)
  cand <- dplyr::count(dplyr::filter(det, !is.na(faixa)),
                       site, species_code, faixa, name = "N")
  chk <- dplyr::left_join(man, cand, by = c("site", "species_code", "faixa"))
  expect_equal(chk$inclusion_prob, pmin(3, chk$N) / chk$N)
  expect_equal(chk$n_candidates, chk$N)
  # a mesma semente da o mesmo sorteio
  man2 <- suppressMessages(select_clips(det, "score_bands", n_top = 3,
                                        strata = "site_species",
                                        score_breaks = quebras))
  expect_identical(man$clip_file, man2$clip_file)
})

test_that("score_bands says what its clips are for", {
  det <- pred_exemplo()
  expect_message(select_clips(det, "score_bands", n_top = 1,
                              strata = "site_species"),
                 "not false-positive occupancy models")
  expect_message(select_clips(det, "score_bands", n_top = 1,
                              strata = "site_species",
                              score_breaks = c(0.5, 1)),
                 "outside `score_breaks`")
})

test_that("score_bands checks its arguments", {
  det <- pred_exemplo()
  sb <- function(...) suppressMessages(select_clips(det, "score_bands",
                                                    strata = "site_species",
                                                    ...))
  expect_error(sb(score_breaks = c(0.7, 0.4)), "increasing")
  expect_error(sb(score_breaks = 0.5), "at least two")
  expect_error(sb(score_breaks = c(0.1, 1.2)), "within 0 and 1")
  expect_error(sb(target_total = 20), "not available")
  expect_error(sb(max_per_species = 5), "not available")
  expect_error(sb(score_breaks = c(0.999, 1)), "No prediction")
  # o score continua proibido como coluna de estrato
  expect_error(select_clips(det, "score_bands",
                            strata = c("site", "confidence")),
               "depend on the score")
  man <- sb(n_top = 1)
  man$verdict <- "positive"
  expect_error(sb(previous = man), "Later rounds")
})

test_that("the export warns that score_bands clips are not for crywolf", {
  val <- sim_validation(sim_pred(), "score_bands", strata = "site_species",
                        n_top = 2)
  avisos <- character()
  withCallingHandlers(
    export_sim(validation = val),
    warning = function(w) {
      avisos <<- c(avisos, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
  expect_true(any(grepl("score_bands.*crywolf drops them", avisos)))
})

# Ponta a ponta com o crywolf: o export mistura clipes aleatorios e por
# faixa; o crywolf descarta os de faixa com um aviso e fica com os demais
test_that("crywolf drops the score_bands clips of a real export", {
  skip_if_not_installed("crywolf")
  skip_if(!any(grepl("score_bands", deparse(crywolf::fp_read_sheepdog))),
          "this crywolf does not drop score_bands clips")
  pred <- sim_pred()
  ale <- sim_validation(pred, "random_detections", strata = "site_species",
                        n_top = 2)
  fai <- sim_validation(pred, "score_bands", strata = "site_species",
                        n_top = 2)
  chave <- function(m) paste(m$source_audio, m$clip_start, m$species_code)
  fai <- fai[!chave(fai) %in% chave(ale), ]
  val <- dplyr::bind_rows(ale, fai)
  out <- suppressWarnings(export_sim(validation = val))
  sp <- utils::read.csv(file.path(out$dir, "validation.csv"))
  sp <- sp$species[sp$sampling_mode == "score_bands"][1]
  avisos <- character()
  x <- withCallingHandlers(
    suppressMessages(crywolf::fp_read_sheepdog(out$dir, species = sp)),
    warning = function(w) {
      avisos <<- c(avisos, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
  expect_true(any(grepl("score_bands\" were dropped", avisos)))
  expect_true(nrow(x$validation) > 0)
  expect_true(all(x$validation$sampling_mode == "random_detections"))
})

test_that("score_bands can pool the sites with strata = \"species\"", {
  det <- pred_exemplo()
  quebras <- c(0.1, 0.4, 0.7, 1)
  man <- suppressMessages(select_clips(det, "score_bands", n_top = 4,
                                       strata = "species",
                                       score_breaks = quebras))
  man$faixa <- cut(man$confidence, quebras, include.lowest = TRUE,
                   right = FALSE)
  expect_true(all(dplyr::count(man, species_code, faixa)$n <= 4))
  # o local continua no manifesto, mas o estrato e a especie x faixa
  expect_true(all(!is.na(man$site)))
  det$faixa <- cut(det$confidence, quebras, include.lowest = TRUE,
                   right = FALSE)
  cand <- dplyr::count(dplyr::filter(det, !is.na(faixa)), species_code,
                       faixa, name = "N")
  chk <- dplyr::left_join(man, cand, by = c("species_code", "faixa"))
  expect_equal(chk$inclusion_prob, pmin(4, chk$N) / chk$N)
  # so no modo score_bands
  expect_error(suppressMessages(select_clips(det, "random_detections",
                                             threshold = 0.5,
                                             strata = "species")),
               "only available")
})
