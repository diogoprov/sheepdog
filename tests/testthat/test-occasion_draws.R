# occasion_draws(): deteccoes por ocasiao sobre as draws da calibracao

fixture_copy <- function(nome = "export-1.2", env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  file.copy(list.files(test_path("fixtures", nome), full.names = TRUE), dir)
  dir
}

test_that("the 1.2 fixture is reproduced from its own settings", {
  skip_if_not_installed("arrow")
  dir <- fixture_copy()
  guardado <- arrow::read_parquet(file.path(dir, "occasion_draws.parquet"))
  sc <- jsonlite::read_json(file.path(dir, "schema.json"), simplifyVector = TRUE)
  expect_identical(sc$schema_version, 1.2)
  expect_identical(sc$occasion_draws$rule, "sample")
  expect_warning(
    novo <- occasion_draws(dir, rule = sc$occasion_draws$rule,
                           n_draws = sc$occasion_draws$n_draws,
                           seed = sc$occasion_draws$seed, write = FALSE),
    "not scored")
  expect_equal(novo, tibble::as_tibble(guardado), ignore_attr = TRUE)
  expect_type(guardado$y, "integer")
  expect_identical(unique(guardado$species), "phy_cuv")
})

test_that("unscored occasions are NA and drop out of the draw", {
  skip_if_not_installed("arrow")
  dir <- fixture_copy()
  od <- suppressWarnings(occasion_draws(dir, n_draws = 3, write = FALSE))
  oc <- readr::read_csv(file.path(dir, "occasions.csv"),
                        col_types = readr::cols(.default = "c"))
  na_occ <- unique(od$occasion_id[is.na(od$y)])
  expect_gt(length(na_occ), 0)
  # so as ocasioes de NHE x 202112 (pontos da grade apagados na fixture)
  meses <- oc$month[match(na_occ, oc$occasion_id)]
  expect_true(all(meses == "202112"))
  expect_true(all(startsWith(na_occ, "NHE")))
  # NA em todas as draws
  expect_true(all(is.na(od$y[od$occasion_id %in% na_occ])))
})

test_that("the first draws do not depend on n_draws, and the RNG is kept", {
  skip_if_not_installed("arrow")
  dir <- fixture_copy("export-1.1")
  set.seed(3)
  antes <- .Random.seed
  a <- occasion_draws(dir, n_draws = 10, seed = 5, write = FALSE)
  expect_identical(.Random.seed, antes)
  b <- occasion_draws(dir, n_draws = 4, seed = 5, write = FALSE)
  expect_identical(b, a[a$draw %in% sort(unique(a$draw))[1:4], ])
  expect_false(identical(occasion_draws(dir, n_draws = 4, seed = 6,
                                        write = FALSE), b))
})

test_that("the threshold rule needs no seed and gives fewer detections", {
  skip_if_not_installed("arrow")
  dir <- fixture_copy("export-1.1")
  amostra <- occasion_draws(dir, write = FALSE)
  limiar <- occasion_draws(dir, rule = "threshold", p_min = 0.95, seed = NULL,
                           write = FALSE)
  expect_lt(mean(limiar$y), mean(amostra$y))
  expect_error(occasion_draws(dir, seed = NULL), "seed")
})

test_that("writing records the table in schema.json as version 1.2", {
  skip_if_not_installed("arrow")
  dir <- fixture_copy("export-1.1")
  expect_message(occasion_draws(dir, n_draws = 5, seed = 1), "written")
  sc <- jsonlite::read_json(file.path(dir, "schema.json"))
  expect_identical(sc$schema_version, 1.2)
  expect_identical(sc$occasion_draws$n_draws, 5L)
  expect_identical(sc$occasion_draws$seed, 1L)
  expect_null(sc$occasion_draws$p_min)
  # listas de um elemento continuam listas
  expect_type(sc$species, "list")
  expect_type(sc$occasion_draws$species, "list")
  expect_identical(sc$tables$occasion_draws$rows,
                   nrow(arrow::read_parquet(file.path(dir, "occasion_draws.parquet"))))
})

test_that("exports without calibration or species are refused", {
  dir <- withr::local_tempdir()
  expect_error(occasion_draws(dir), "schema.json")
  skip_if_not_installed("arrow")
  dir <- fixture_copy("export-1.1")
  expect_error(occasion_draws(dir, species = "boa_ran"), "No species")
  file.remove(file.path(dir, "calibration_draws.parquet"))
  expect_error(occasion_draws(dir), "no calibration draws")
})

# Mesmo resultado que crywolf::fp_draws_data(), com a ocasiao que tem
# predicoes com e sem draws (fixture 1.2). Roda quando o crywolf instalado
# ja casa chaves genericas (esquema 1.1)
test_that("occasion_draws() gives the detections of crywolf::fp_draws_data()", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("crywolf", minimum_version = "2.0.0.9000")
  dir <- fixture_copy()
  x <- suppressWarnings(crywolf::fp_read_sheepdog(dir, species = "phy_cuv"))
  for (regra in c("sample", "threshold")) {
    v <- suppressWarnings(crywolf::fp_draws_data(x, rule = regra, p_min = 0.5,
                                                 n_draws = 20, seed = 11))
    s <- suppressWarnings(occasion_draws(dir, rule = regra, p_min = 0.5,
                                         n_draws = 20, seed = 11,
                                         write = FALSE))
    ids <- sort(unique(s$draw))
    expect_identical(attr(v, "draws"), ids)
    for (j in seq_along(ids)) {
      cw <- v[[j]]$auto[c("site", "occasion_id", "y")]
      sd <- s[s$draw == ids[j], ]
      # ocasioes pontuadas com predicao: o mesmo y
      pont <- sd[!is.na(sd$y), ]
      m <- match(paste(pont$site, pont$occasion_id),
                 paste(cw$site, cw$occasion_id))
      expect_false(anyNA(m))
      expect_identical(as.integer(cw$y[m]), pont$y)
      # nao pontuadas: fora do crywolf (ou NA); sem predicao: 0
      na_cw <- cw$y[match(paste(sd$site[is.na(sd$y)], sd$occasion_id[is.na(sd$y)]),
                          paste(cw$site, cw$occasion_id))]
      expect_true(all(is.na(na_cw)))
      resto <- cw[!paste(cw$site, cw$occasion_id) %in%
                    paste(sd$site, sd$occasion_id), ]
      expect_true(all(resto$y == 0))
    }
  }
})
