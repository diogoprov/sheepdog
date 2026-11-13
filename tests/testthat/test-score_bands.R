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
