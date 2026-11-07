# Integracao com o crywolf (vignette("crywolf-integration")): colunas, tipos e
# ocasioes dos arquivos de exemplo em inst/extdata

exemplo <- function(f) {
  readr::read_csv(system.file("extdata", f, package = "sheepdog"),
                  col_types = readr::cols(recording_date = "c", night = "c",
                                          recording_hour = "c"))
}

test_that("example files follow the documented columns", {
  man <- exemplo("clip_manifest.csv")
  val <- exemplo("validation_by_clip.csv")
  # os exemplos sao de uma rodada so, sem as colunas das rodadas de revisao
  colunas <- setdiff(sheepdog:::manifest_columns,
                     c("round", "n_candidates", "n_drawn",
                       "inclusion_prob_round", "previously_reviewed",
                       "inherited_verdict", "source_design"))
  expect_identical(names(man), colunas)
  expect_identical(names(val), c(colunas, "verdict", "reviewed_path"))
  expect_true(all(val$verdict %in% c("positive", "negative", "not_reviewed",
                                     "clip_missing")))
  expect_true(all(man$sampling_mode %in% c("top", "random_detections",
                                           "random_recordings")))
  expect_type(man$confidence, "double")
  expect_type(man$inclusion_prob, "double")
  expect_true(all(grepl("^\\d{8}$", man$night)))
  expect_identical(man$occasion_id,
                   tools::file_path_sans_ext(basename(man$source_audio)))
  # todas as deteccoes de cada ocasiao checada estao no manifesto
  n <- table(man$occasion_id)
  expect_equal(as.vector(n[man$occasion_id]), man$n_detections_occasion)
})

test_that("crywolf reads validation_by_clip.csv", {
  skip_if_not_installed("crywolf")
  f <- system.file("extdata", "validation_by_clip.csv", package = "sheepdog")
  v <- tryCatch(crywolf::fp_read_validation(f), error = function(e) NULL)
  skip_if(is.null(v), paste("the installed crywolf does not read the",
                            "sheepdog 2.0.0 column names yet"))
  val <- exemplo("validation_by_clip.csv")
  expect_identical(v$site, val$site)
  expect_identical(v$file, basename(val$source_audio))
  expect_equal(v$start, val$clip_start)
  expect_identical(v$verdict, c(positive = TRUE, negative = FALSE)[val$verdict] |>
                     unname())
})
