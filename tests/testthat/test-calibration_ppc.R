# calibration_ppc(): checagens preditivas da calibracao

test_that("score_bins() merges sparse bins with a neighbour", {
  score <- c(rep(0.15, 20), rep(0.25, 3), rep(0.55, 20), rep(0.95, 4))
  b <- sheepdog:::score_bins(score, width = 0.1, min_n = 15)
  expect_identical(nlevels(b), 2L)
  expect_true(all(table(b) >= 15))
  # a faixa de 0.25 vai para a seguinte; a ultima, para a anterior
  expect_identical(as.character(b[21]), as.character(b[30]))
  expect_identical(as.character(b[47]), as.character(b[30]))
  expect_identical(levels(b), c("0.15-0.15", "0.25-0.95"))
  expect_identical(nlevels(sheepdog:::score_bins(rep(0.5, 3))), 1L)
})

test_that("ppc_table() gives shares, intervals and mid p-values", {
  y <- c(1, 1, 0, 0)
  # 4 amostras: a mesma proporcao do observado em duas, maior nas outras
  yrep <- rbind(c(1, 1, 0, 0), c(1, 0, 1, 0), c(1, 1, 1, 0), c(1, 1, 1, 1))
  tab <- sheepdog:::ppc_table(y, yrep, list(overall = rep("all", 4),
                                            site = c("A", "A", "B", "B")))
  expect_named(tab, c("check", "group", "n", "observed", "pred_mean",
                      "pred_lower", "pred_upper", "p_value", "flagged"))
  todos <- tab[tab$check == "overall", ]
  expect_equal(todos$observed, 0.5)
  expect_equal(todos$pred_mean, mean(c(0.5, 0.5, 0.75, 1)))
  # Pr(T > 0.5) = 0.5, Pr(T = 0.5) = 0.5 -> 0.5 + 0.25
  expect_equal(todos$p_value, 0.75)
  b <- tab[tab$check == "site" & tab$group == "B", ]
  # observado 0; replicas 0, 0.5, 0.5, 1: tres acima e um empate
  expect_equal(b$p_value, 0.875)
  expect_false(b$flagged)
  expect_true(sheepdog:::ppc_table(y, yrep, list(s = c("A", "A", "B", "B")),
                                   flag = 0.2)$flagged[2])
  expect_true(all(tab$pred_lower <= tab$pred_mean & tab$pred_mean <= tab$pred_upper))
})

test_that("calibration_ppc() needs a brms model", {
  fit <- structure(list(), class = "glm")
  expect_error(calibration_ppc(fit), "engine = \"brms\"")
})

test_that("plot_calibration_ppc() draws one check and refuses unknown ones", {
  skip_if_not_installed("ggplot2")
  tab <- sheepdog:::ppc_table(c(1, 0, 1), rbind(c(1, 0, 0), c(1, 1, 1)),
                              list(site = c("A", "B", "B")))
  expect_s3_class(plot_calibration_ppc(tab, "site"), "ggplot")
  expect_error(plot_calibration_ppc(tab, "month"), "available: site")
})
