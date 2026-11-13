# warning_signs(): sinais de alerta do limiar por especie

# Clipes simulados de duas especies em dois locais. "boa": poucos falsos
# positivos em todo lugar. "ruim": falsos positivos frequentes em B, raros
# em A, e verdadeiros positivos quase todos abaixo de 0.8
sinais_dados <- function(n = 200) {
  withr::with_seed(11, {
    um <- function(esp, site, p_tp) {
      conf <- stats::runif(n, 0.1, 0.999)
      tibble::tibble(site = site, species_folder = esp,
                     species_code = paste0("X y_", esp),
                     source_audio = paste0(site, "_r", sample(40, n, TRUE)),
                     confidence = conf,
                     verdict = ifelse(stats::runif(n) < p_tp(conf),
                                      "positive", "negative"),
                     inclusion_prob = 0.5)
    }
    dplyr::bind_rows(
      um("boa", "A", function(x) 0.9 + 0.1 * x),
      um("boa", "B", function(x) 0.9 + 0.1 * x),
      um("ruim", "A", function(x) ifelse(x < 0.8, 0.9, 0.95)),
      um("ruim", "B", function(x) ifelse(x < 0.8, 0.3, 0.95)))
  })
}

test_that("signs 2, 6 and 7 come from the reviewed clips", {
  val <- sinais_dados()
  ws <- warning_signs(val, thresholds = 0.8, min_tp_kept = 0.35)
  expect_equal(ws$species_folder, c("boa", "ruim"))
  expect_true(all(ws$threshold == 0.8))
  # sinal 2: scores uniformes em 0.1-1, so ~22% (boa) a ~31% (ruim) dos
  # positivos ficam acima de 0.8
  expect_true(all(ws$sign2_tp_kept < 0.35))
  expect_true(all(ws$sign2))
  # sinal 6: em "ruim" a taxa de FP vai de ~0.1 (A) a ~0.6 (B)
  expect_true(ws$sign6[ws$species_folder == "ruim"])
  expect_false(ws$sign6[ws$species_folder == "boa"])
  expect_match(ws$sign6_detail[ws$species_folder == "ruim"],
               "site: FP rate .* \\(A\\) to .* \\(B\\)")
  # sinal 7: acima de 0.8 a precisao e ~0.95-1 nos dois locais
  expect_false(any(ws$sign7, na.rm = TRUE))
  # sem curves e recall, sinais 1 e 8 nao foram checados
  expect_true(all(is.na(ws$sign1)))
  expect_true(all(is.na(ws$sign8)))
  expect_equal(ws$n_checked, c(3, 3))
  expect_identical(ws$verdict[ws$species_folder == "ruim"],
                   "use_with_caveats")
})

test_that("signs 1 and 8 come from recall_ceiling() and the curves", {
  val <- sinais_dados()
  curvas <- tibble::tibble(species_folder = c("boa", "boa", "ruim", "ruim"),
                           curve = c("logistic", "gam", "logistic", "gam"),
                           verdict = c("keep_logistic", "keep_logistic",
                                       "no_curve_reaches_target",
                                       "no_curve_reaches_target"))
  teto <- tibble::tibble(site = c("A", "B", "A", "B"),
                         species_folder = c("boa", "boa", "ruim", "ruim"),
                         recall_ceiling = c(0.9, 0.8, 0.6, 0.3))
  ws <- warning_signs(val, thresholds = 0.5, curves = curvas, recall = teto)
  boa <- ws[ws$species_folder == "boa", ]
  ruim <- ws[ws$species_folder == "ruim", ]
  expect_equal(boa$sign1_ceiling, 0.8)
  expect_false(boa$sign1)
  expect_equal(ruim$sign1_ceiling, 0.3)
  expect_true(ruim$sign1)
  expect_false(boa$sign8)
  expect_true(ruim$sign8)
  expect_equal(ws$n_checked, c(5, 5))
  expect_identical(boa$verdict, "trustworthy_with_care")
  # nenhuma curva alcanca o alvo: nao confiavel, com qualquer numero de sinais
  expect_identical(ruim$verdict, "not_trustworthy")
  # o pior veredito da especie vale quando as curvas sao por local
  por_local <- tibble::tibble(site = c("A", "B"), species_folder = "boa",
                              verdict = c("keep_logistic",
                                          "sample_more_near_threshold"))
  ws <- warning_signs(val, 0.5, curves = por_local)
  expect_identical(ws$sign8_verdict[ws$species_folder == "boa"],
                   "sample_more_near_threshold")
  expect_true(is.na(ws$sign8[ws$species_folder == "boa"]))
})

test_that("thresholds come per cell or per species", {
  val <- sinais_dados()
  por_celula <- tibble::tibble(site = c("A", "B", "A", "B"),
                               species_folder = c("boa", "boa", "ruim",
                                                  "ruim"),
                               threshold = c(0.3, 0.5, 0.6, NA))
  ws <- warning_signs(val, por_celula)
  expect_equal(ws$threshold, c(0.4, 0.6))
  por_especie <- tibble::tibble(species_folder = c("boa", "ruim"),
                                limiar_c = c(0.2, NA))
  ws <- warning_signs(val, por_especie, threshold_column = "limiar_c")
  expect_equal(ws$threshold[1], 0.2)
  # sem limiar: nao confiavel
  expect_identical(ws$verdict[2], "not_trustworthy")
  expect_true(is.na(ws$sign2_tp_kept[2]))
  expect_error(warning_signs(val, list(0.5)), "single number or a table")
  expect_error(warning_signs(val, tibble::tibble(site = "A")), "lacks")
})

test_that("a global threshold below target in a group raises sign 7", {
  val <- sinais_dados()
  val$month <- ifelse(val$confidence > 0.55, "jan", "fev")
  ws <- warning_signs(val, 0.2, groups = c("site", "month"),
                      target_precision = 0.95)
  ruim <- ws[ws$species_folder == "ruim", ]
  expect_true(ruim$sign7)
  expect_match(ruim$sign7_detail, "below target")
  expect_gt(ruim$sign7_share_below, 0)
})

test_that("identities name the main confuser, and the report is written", {
  val <- sinais_dados()
  val$identity <- ifelse(val$verdict == "negative", "Scinax fuscovarius",
                         NA)
  arq <- withr::local_tempfile(fileext = ".md")
  expect_message(ws <- warning_signs(val, 0.8, file = arq), "written")
  expect_match(ws$sign6_detail[ws$species_folder == "ruim"],
               "main confuser: Scinax fuscovarius")
  md <- readLines(arq)
  expect_match(md[1], "Warning signs")
  expect_true(any(grepl("^\\| species_folder", md)))
  expect_true(any(grepl("ruim", md)))
})

test_that("clips without inclusion_prob are used unweighted, with a message", {
  val <- sinais_dados()
  val$inclusion_prob <- NULL
  expect_message(ws <- warning_signs(val, 0.8), "only indicative")
  expect_equal(nrow(ws), 2)
  expect_error(warning_signs(val[0, ], 0.8), "No reviewed clip")
  expect_error(warning_signs(val, 0.8, groups = "month"), "month")
  expect_error(warning_signs(val, 0.8, curves = data.frame(a = 1)),
               "compare_calibration_curves")
  expect_error(warning_signs(val, 0.8, recall = data.frame(a = 1)),
               "recall_ceiling")
})

test_that("a single site skips the group signs unless groups are given", {
  val <- sinais_dados()
  val <- val[val$site == "A", ]
  ws <- warning_signs(val, 0.8)
  expect_true(all(is.na(ws$sign6)))
  expect_true(all(is.na(ws$sign7)))
  expect_equal(ws$n_checked, c(1, 1))
  sem_nada <- warning_signs(val, 0.8)
  expect_true(all(sem_nada$verdict %in% c("use_with_caveats",
                                          "trustworthy_with_care")))
})
