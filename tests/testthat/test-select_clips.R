cenarios <- c("top_default", "top_meta", "top_max", "det_file",
              "det_minute_meta", "det_max", "rec_file", "rec_minute",
              "rec_table")

# Manifesto de um cenario, com as mesmas entradas da referencia
manifesto_cenario <- function(nome) {
  pred <- suppressMessages(
    read_selection_tables(file.path(sim_root(), "tabelas")))
  args <- scenario_args(nome)
  suppressMessages(suppressWarnings(
    do.call(select_clips, c(list(detections = pred), args))))
}

for (nm in cenarios) {
  test_that(paste("select_clips() reproduces v1.2.0:", nm), {
    ref  <- ref_table(nm, "manifesto_clipes.csv") |> dplyr::select(-status)
    # colunas novas das rodadas de revisao ficam depois das da v1.2.0
    novo <- as_written(manifesto_cenario(nm))
    expect_identical(names(novo)[seq_along(ref)], names(ref))
    novo <- novo[names(ref)]
    expect_same_table(novo, ref)
  })
}

# Predicoes brutas >= limiar com ocasiao (arquivo), data e hora, contadas
# direto da tabela simulada, sem passar pelo pacote
candidatas_brutas <- function(limiar, horas = 0:23) {
  pred <- suppressMessages(
    read_selection_tables(file.path(sim_root(), "tabelas")))
  pred |>
    dplyr::filter(confidence >= limiar) |>
    dplyr::mutate(
      occasion_id = tools::file_path_sans_ext(
        basename(gsub("\\\\", "/", begin_path))),
      data = sub("^.*_(\\d{8})_(\\d{6})$", "\\1", occasion_id),
      hora = substr(sub("^.*_(\\d{8})_(\\d{6})$", "\\2", occasion_id), 1, 2)) |>
    dplyr::filter(as.integer(hora) %in% horas)
}

test_that("random_detections keeps every clip of each drawn occasion", {
  for (nm in c("det_file", "det_minute_meta", "det_max")) {
    m <- manifesto_cenario(nm)
    por_ocasiao <- dplyr::count(m, site, species_code, occasion_id,
                                n_detections_occasion)
    expect_equal(por_ocasiao$n, por_ocasiao$n_detections_occasion)
    expect_true(all(m$confidence >= scenario_args(nm)$threshold))
    expect_true(any(por_ocasiao$n > 1))
  }

  # contagem independente: cada ocasiao sorteada tem todas as predicoes
  # >= limiar da tabela bruta, e ha no maximo n_top = 1 por estrato
  m <- manifesto_cenario("det_file")
  bruto <- dplyr::count(candidatas_brutas(0.5), site, species_code,
                        occasion_id, name = "n_bruto")
  obs <- dplyr::count(m, site, species_code, occasion_id) |>
    dplyr::left_join(bruto, by = c("site", "species_code", "occasion_id"))
  expect_equal(obs$n, obs$n_bruto)
  por_estrato <- dplyr::distinct(m, site, species_code, night,
                                 recording_hour, occasion_id) |>
    dplyr::count(site, species_code, night, recording_hour)
  expect_true(all(por_estrato$n == 1))
})

test_that("inclusion_prob follows each design", {
  # top: selecao pelo score, nao probabilistica
  expect_true(all(is.na(manifesto_cenario("top_default")$inclusion_prob)))

  # random_detections sem meta: min(n_top, N) / N, com N ocasioes
  # candidatas por local x especie x noite x hora
  m <- manifesto_cenario("det_file")
  esperado <- candidatas_brutas(0.5) |>
    dplyr::distinct(site, species_code, occasion_id, data, hora) |>
    dplyr::add_count(site, species_code, data, hora, name = "N") |>
    dplyr::transmute(site, species_code, occasion_id, p = 1 / N)
  obs <- dplyr::distinct(m, site, species_code, occasion_id, inclusion_prob) |>
    dplyr::inner_join(esperado, by = c("site", "species_code", "occasion_id"))
  expect_equal(nrow(obs), nrow(dplyr::distinct(m, site, species_code,
                                               occasion_id)))
  expect_equal(obs$inclusion_prob, obs$p)
  expect_true(any(obs$p < 1))

  # random_detections com limite por especie (det_max: n_top = 2, horas
  # 18-23, max_per_species = 4, sem balancear por hora): p = p1 x p2, com
  # p1 = min(2, N) / N (N ocasioes candidatas no estrato local x especie x
  # noite x hora) e p2 = min(4, S) / S (S ocasioes que passam da 1a etapa
  # no local x especie)
  m <- manifesto_cenario("det_max")
  esperado <- candidatas_brutas(0.5, horas = 18:23) |>
    dplyr::distinct(site, species_code, occasion_id, data, hora) |>
    dplyr::add_count(site, species_code, data, hora, name = "N") |>
    dplyr::group_by(site, species_code) |>
    dplyr::mutate(S = sum(pmin(2, N) / N)) |>
    dplyr::ungroup() |>
    dplyr::transmute(site, species_code, occasion_id,
                     p = pmin(2, N) / N * pmin(4, S) / S)
  obs <- dplyr::distinct(m, site, species_code, occasion_id, inclusion_prob) |>
    dplyr::left_join(esperado, by = c("site", "species_code", "occasion_id"))
  expect_equal(obs$inclusion_prob, obs$p)

  p <- manifesto_cenario("det_minute_meta")$inclusion_prob
  expect_true(all(p > 0 & p <= 1))

  # random_recordings: gravacoes sorteadas / gravacoes do local
  for (nm in c("rec_file", "rec_table")) {
    m <- manifesto_cenario(nm)
    n_grav <- table(simulate_recordings_table(sim_root())$local)
    obs <- dplyr::summarise(m, n = dplyr::n_distinct(occasion_id),
                            p = unique(inclusion_prob), .by = site)
    expect_equal(obs$p, as.numeric(obs$n / n_grav[obs$site]))
  }
  # rec_minute: 4 minutos por local entre (gravacoes x 3 minutos de 180 s)
  m <- manifesto_cenario("rec_minute")
  n_grav <- table(simulate_recordings_table(sim_root())$local)
  expect_equal(unique(m$inclusion_prob), unique(4 / (as.numeric(n_grav) * 3)))
  expect_true(all(is.na(m$confidence)))
})

test_that("select_clips() leaves the global RNG untouched", {
  pred <- suppressMessages(
    read_selection_tables(file.path(sim_root(), "tabelas")))
  set.seed(99)
  antes <- .Random.seed
  suppressMessages(select_clips(pred, "random_detections", threshold = 0.5))
  expect_identical(.Random.seed, antes)
})

test_that("random_detections says when the draw is a census", {
  pred <- suppressMessages(
    read_selection_tables(file.path(sim_root(), "tabelas")))
  msgs <- capture_messages(
    select_clips(pred, "random_detections", threshold = 0.5, n_top = 1e6,
                 strata = "night_hour"))
  expect_true(any(grepl("census", msgs)))
  msgs <- capture_messages(
    select_clips(pred, "random_detections", threshold = 0.5, n_top = 1,
                 strata = "night"))
  expect_false(any(grepl("census", msgs)))
})

test_that("random_detections needs a threshold", {
  pred <- suppressMessages(
    read_selection_tables(file.path(sim_root(), "tabelas")))
  expect_error(suppressMessages(select_clips(pred, "random_detections")),
               "threshold")
})

test_that("strata sets the strata of the random_detections draw", {
  det <- suppressMessages(read_selection_tables(
    system.file("extdata", "example", "birdnet", package = "sheepdog")))
  # uma gravacao por hora: por noite x hora nada e sorteado
  m_nh <- suppressMessages(select_clips(det, "random_detections",
                                        threshold = 0.5, n_top = 1))
  expect_true(all(m_nh$inclusion_prob == 1))
  # por local x especie: n_top / N ocasioes, igual em cada estrato
  m_ss <- suppressMessages(select_clips(det, "random_detections",
                                        threshold = 0.5, n_top = 3,
                                        strata = "site_species"))
  oc <- dplyr::distinct(m_ss, site, species_code, occasion_id, inclusion_prob)
  expect_true(all(dplyr::count(oc, site, species_code)$n <= 3))
  cand <- det |>
    dplyr::filter(confidence >= 0.5) |>
    dplyr::mutate(occasion_id = tools::file_path_sans_ext(
      basename(gsub("\\\\", "/", begin_path)))) |>
    dplyr::distinct(site, species_code, occasion_id) |>
    dplyr::count(site, species_code, name = "N")
  esperado <- dplyr::left_join(oc, cand, by = c("site", "species_code"))
  expect_equal(esperado$inclusion_prob, pmin(3, esperado$N) / esperado$N)
  # estrato sem hora + balance_by_hour: probabilidade condicional, avisa
  expect_warning(
    suppressMessages(select_clips(det, "random_detections", threshold = 0.5,
                                  strata = "night", max_per_species = 5)),
    "conditional on the first draw")
  expect_no_warning(
    suppressMessages(select_clips(det, "random_detections", threshold = 0.5,
                                  strata = "night", max_per_species = 5,
                                  balance_by_hour = FALSE)))
})

test_that("the min_confidence message is skipped when nothing is dropped", {
  det <- suppressMessages(read_selection_tables(
    system.file("extdata", "example", "birdnet", package = "sheepdog")))
  msgs <- testthat::capture_messages(select_clips(det, min_confidence = 0))
  expect_false(any(grepl("predictions dropped", msgs)))
})

test_that("strata presets hour, week and month draw within those periods", {
  det <- suppressMessages(read_selection_tables(
    system.file("extdata", "example", "birdnet", package = "sheepdog")))
  sorteio <- function(strata) suppressMessages(select_clips(
    det, "random_detections", threshold = 0.5, n_top = 1, strata = strata))
  oc <- function(m) dplyr::distinct(m, site, species_code, occasion_id,
                                    night, recording_hour)
  # um sorteio por local x especie x periodo
  m_mes <- oc(sorteio("month")) |>
    dplyr::mutate(month = substr(night, 1, 6))
  expect_true(all(dplyr::count(m_mes, site, species_code, month)$n == 1))
  m_hora <- oc(sorteio("hour"))
  expect_true(all(dplyr::count(m_hora, site, species_code,
                               recording_hour)$n == 1))
  m_sem <- oc(sorteio("week")) |>
    dplyr::mutate(week = format(as.Date(night, "%Y%m%d"), "%G-W%V"))
  expect_true(all(dplyr::count(m_sem, site, species_code, week)$n == 1))
  # os estratos mais grossos sorteiam de fato (probabilidade < 1)
  expect_true(any(sorteio("month")$inclusion_prob < 1))
  # a coluna derivada nao entra no manifesto
  expect_false("month" %in% names(sorteio("month")))
})

test_that("strata takes user columns and validates them", {
  det <- suppressMessages(read_selection_tables(
    system.file("extdata", "example", "birdnet", package = "sheepdog")))
  hab <- tibble::tibble(site = c("ARA", "BAI", "NHE", "XAR"),
                        habitat = c("pond", "pond", "stream", "stream"))
  det_h <- dplyr::left_join(det, hab, by = "site")
  m <- suppressMessages(select_clips(
    det_h, "random_detections", threshold = 0.5, n_top = 2,
    strata = c("habitat", "month")))
  # local e especie entram sempre: no maximo 2 ocasioes por local x
  # especie x habitat x mes
  oc <- dplyr::distinct(m, site, species_code, occasion_id, night) |>
    dplyr::mutate(month = substr(night, 1, 6))
  expect_true(all(dplyr::count(oc, site, species_code, month)$n <= 2))
  expect_error(select_clips(det_h, "random_detections", threshold = 0.5,
                            strata = c("habitat", "confidence")),
               "depend on the score")
  expect_error(suppressMessages(select_clips(
    det_h, "random_detections", threshold = 0.5, strata = "nao_existe")),
    "not in `detections`")
  # file_offset varia dentro de uma ocasiao (arquivo): recusado
  expect_error(suppressMessages(select_clips(
    det_h, "random_detections", threshold = 0.5, strata = "file_offset")),
    "constant within an occasion")
})

test_that("random_recordings keeps only the recordings of `sites`", {
  pred <- suppressMessages(
    read_selection_tables(file.path(sim_root(), "tabelas")))
  args <- scenario_args("rec_table")
  args$sites <- NULL
  locais <- unique(pred$site)
  um <- locais[1]
  m <- suppressMessages(suppressWarnings(
    do.call(select_clips, c(list(detections = pred, sites = um), args))))
  expect_identical(unique(m$site), um)
  # a probabilidade de inclusao continua sendo a do local
  todos <- manifesto_cenario("rec_table")
  expect_equal(unique(m$inclusion_prob),
               unique(todos$inclusion_prob[todos$site == um]))
})
