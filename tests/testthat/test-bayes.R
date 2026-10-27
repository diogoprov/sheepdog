test_that("snap_to_grid() and summarise_grid_draws() work on the grid", {
  g <- sheepdog:::score_grid(0.1, 0.01)
  expect_equal(g[1], 0.1)
  idx <- sheepdog:::snap_to_grid(c(0.1, 0.1049, 0.106, 0.999), 0.1, 0.01)
  expect_identical(idx, c(1, 1, 2, length(g)))
  # 4 amostras x 2 pontos da grade
  d <- cbind(c(0.90, 0.96, 0.97, 0.99), c(0.1, 0.2, 0.3, 0.4))
  s <- sheepdog:::summarise_grid_draws(d, p_min = 0.95, lower_prob = 0)
  expect_equal(s$p_tp, colMeans(d))
  expect_equal(s$p_tp_lower, c(0.90, 0.1))
  expect_equal(s$pr_reliable, c(0.75, 0))
})

test_that("detection_history() applies the mean and probability rules", {
  sc <- tibble::tibble(site = "A", species = "x", night = c("1", "1", "2"),
                       p_tp = c(0.96, 0.97, 0.99),
                       pr_reliable = c(0.95, 0.5, 0.92))
  h_m <- detection_history(sc, p_min = 0.95)
  expect_identical(h_m$n_reliable, c(2L, 1L))
  h_p <- detection_history(sc, rule = "probability", prob_min = 0.9)
  expect_identical(h_p$n_reliable, c(1L, 1L))
  expect_error(detection_history(sc[c("site", "species", "night", "p_tp")],
                                 rule = "probability"), "pr_reliable")
})

test_that("fit_calibration(engine = 'brms') requires an explicit prior", {
  skip_if_not_installed("brms")
  val <- tibble::tibble(site = factor("A"), species = factor("x"),
                        confidence = 0.5, logit_conf = 0, tp = 1L)
  expect_error(fit_calibration(val, tp ~ logit_conf, engine = "brms"),
               "explicit `prior`")
})

test_that("calibration_prior() matches the classes of the formula", {
  skip_if_not_installed("brms")
  ex <- system.file("extdata", "example", "validation", package = "sheepdog")
  val <- suppressMessages(read_validations(list.files(ex, full.names = TRUE)))
  classes <- function(f) unique(calibration_prior(f, val)$class)
  expect_setequal(classes(tp ~ logit_conf), c("b", "Intercept"))
  m <- calibration_models(uncorrelated = TRUE)
  expect_setequal(classes(m$m4_species_x_site),
                  c("b", "cor", "Intercept", "sd"))
  expect_setequal(classes(m$m5_species_x_site_uncorrelated),
                  c("b", "Intercept", "sd"))
  pr <- calibration_prior(tp ~ logit_conf, val)
  expect_true(grepl(as.character(round(mean(val$logit_conf), 3)),
                    pr$prior[pr$class == "Intercept"], fixed = TRUE))
  expect_identical(pr$lb[pr$class == "b"], "0")
})

# O ajuste com Stan leva ~1 min (compilacao): roda so com
# SHEEPDOG_TEST_BRMS=true
test_that("the brms backend scores, builds histories and propagates draws", {
  skip_if_not_installed("brms")
  skip_if_not(identical(Sys.getenv("SHEEPDOG_TEST_BRMS"), "true"),
              "set SHEEPDOG_TEST_BRMS=true to fit the Stan model")
  ex <- system.file("extdata", "example", package = "sheepdog")
  val <- suppressMessages(read_validations(list.files(
    file.path(ex, "validation"), full.names = TRUE)))
  f <- calibration_models(uncorrelated = TRUE)$m5_species_x_site_uncorrelated
  fit <- suppressWarnings(fit_calibration(
    val, f, engine = "brms", prior = calibration_prior(f, val),
    chains = 2, iter = 600, refresh = 0, seed = 1))
  expect_s3_class(fit, "brmsfit")
  expect_named(calibration_diagnostics(fit),
               c("max_rhat", "min_ess_bulk", "min_ess_tail", "n_divergent",
                 "ok"))
  tabs <- c(ARA = file.path(ex, "birdnet", "ARA",
                            "BirdNET_SelectionTable.txt"))
  sc <- suppressMessages(score_detections(tabs, fit))
  expect_true(all(c("p_tp_lower", "pr_reliable") %in% names(sc)))
  expect_true(all(sc$p_tp_lower <= sc$p_tp))
  expect_true(all(sc$pr_reliable >= 0 & sc$pr_reliable <= 1))
  ppc <- calibration_ppc(fit, val, n_draws = 100)
  expect_setequal(unique(ppc$check), c("overall", "score", "site", "species"))
  expect_identical(ppc$n[ppc$check == "overall"], nrow(val))
  expect_true(all(ppc$p_value >= 0 & ppc$p_value <= 1))
  expect_error(calibration_ppc(fit, val[-1, ]), "rows")
  hd <- history_draws(fit, sc, n_draws = 20)
  expect_identical(dplyr::n_distinct(hd$draw), 20L)
  h <- detection_history(sc)
  # cada amostra tem as mesmas noites do historico deterministico
  expect_equal(nrow(hd) / 20, nrow(h))
  md <- community_matrices_draws(hd, c("boa_ran", "phy_cuv"), k_min = 1,
                                 min_nights_month = 3)
  expect_true(all(md$summary$frequency_lower <= md$summary$frequency_mean))
  expect_true(all(md$summary$frequency_mean <= md$summary$frequency_upper))
})
