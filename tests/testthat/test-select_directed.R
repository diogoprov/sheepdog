unidades_sim <- function(pred) {
  pred |>
    dplyr::mutate(
      month = format(as.Date(sub("^.*_(\\d{8})_\\d{6}.*$", "\\1",
                                 basename(gsub("\\\\", "/", begin_path))),
                             "%Y%m%d"), "%Y-%m")) |>
    dplyr::distinct(site, species_code, month) |>
    dplyr::mutate(size = seq_len(dplyr::n()) / 10)
}

test_that("pps_inclusion() caps at 1 and sums to n", {
  p <- pps_inclusion(c(10, 1, 1, 1, 1), 2)
  expect_equal(sum(p), 2)
  expect_equal(p[1], 1)
  expect_equal(p[2:5], rep(0.25, 4))
  p <- pps_inclusion(c(1, 2, 3, 4), 2)
  expect_equal(p, 2 * (1:4) / 10)
  expect_equal(pps_inclusion(c(5, 5, 1), 3), c(1, 1, 1))
})

test_that("systematic_pps() draws n units with the given probabilities", {
  p <- pps_inclusion(c(8, 4, 2, 1, 1, 1, 3), 3)
  sorteios <- withr::with_seed(1, replicate(4000, systematic_pps(p)))
  expect_true(all(apply(sorteios, 2, anyDuplicated) == 0))
  freq <- tabulate(sorteios, length(p)) / 4000
  expect_equal(freq, p, tolerance = 0.03)
})

test_that("select_directed() draws one occasion per unit and keeps every detection", {
  pred <- sim_pred()
  un <- unidades_sim(pred)
  sel <- suppressMessages(select_directed(pred, un, n_units = 5,
                                          threshold = 0.5))
  expect_identical(names(sel),
                   c(manifest_columns[manifest_columns != "status"], "stratum"))
  expect_true(all(sel$sampling_mode == "directed_pps"))
  expect_true(all(sel$confidence >= 0.5))
  expect_true(all(sel$round == 1L))
  expect_true(all(sel$n_drawn == 1L))
  # uma ocasiao por unidade, e todas as deteccoes >= limiar dela
  ocas <- dplyr::distinct(sel, stratum, site, species_code, occasion_id)
  expect_equal(nrow(ocas), 5)
  expect_equal(dplyr::n_distinct(ocas$stratum), 5)
  por_ocasiao <- dplyr::count(sel, site, species_code, occasion_id,
                              n_detections_occasion)
  expect_equal(por_ocasiao$n, por_ocasiao$n_detections_occasion)

  un_out <- attr(sel, "units")
  expect_equal(sum(un_out$inclusion_prob_unit), 5)
  expect_equal(sum(un_out$drawn), 5)
  expect_equal(un_out$size_used, un_out$size + 0.05 * mean(un$size))
  sorteadas <- dplyr::filter(un_out, drawn) |>
    dplyr::mutate(stratum = paste(site, species_code, month, sep = "|"))
  pi_clipe <- dplyr::distinct(sel, stratum, inclusion_prob, n_candidates) |>
    dplyr::left_join(sorteadas, by = "stratum")
  expect_equal(pi_clipe$inclusion_prob,
               pi_clipe$inclusion_prob_unit / pi_clipe$n_occasions)
  expect_equal(pi_clipe$n_candidates, pi_clipe$n_occasions)
})

test_that("select_directed() is reproducible and leaves the global RNG alone", {
  pred <- sim_pred()
  un <- unidades_sim(pred)
  set.seed(99)
  antes <- stats::runif(1)
  set.seed(99)
  a <- suppressMessages(select_directed(pred, un, 4, threshold = 0.5))
  expect_identical(stats::runif(1), antes)
  b <- suppressMessages(select_directed(pred, un, 4, threshold = 0.5))
  expect_identical(a, b)
  c <- suppressMessages(select_directed(pred, un, 4, threshold = 0.5,
                                        seed = 7))
  expect_false(identical(a$clip_file, c$clip_file))
})

test_that("select_directed() leaves out reviewed clips and numbers the round", {
  pred <- sim_pred()
  un <- unidades_sim(pred)
  r1 <- suppressMessages(select_directed(pred, un, 6, threshold = 0.5))
  r2 <- suppressMessages(select_directed(pred, un, 6, threshold = 0.5,
                                         previous = r1, seed = 3))
  expect_true(all(r2$round == 2L))
  repetidos <- dplyr::semi_join(r2, r1, by = c("site", "species_code",
                                               "occasion_id", "clip_start"))
  expect_equal(nrow(repetidos), 0)
  # uma revisao de outro desenho tambem sai, sem mudar a rodada
  top <- suppressMessages(select_clips(pred, "top", threshold = 0.5))
  r3 <- suppressMessages(select_directed(pred, un, 6, threshold = 0.5,
                                         previous = top))
  expect_true(all(r3$round == 1L))
  expect_equal(nrow(dplyr::semi_join(r3, top, by = c(
    "site", "species_code", "occasion_id", "clip_start"))), 0)
  # rodada anterior com ocasioes por minuto: casa pelo arquivo e o inicio
  rd <- suppressMessages(select_clips(pred, "random_detections",
                                      occasion_unit = "minute",
                                      threshold = 0.5, n_top = 3))
  r4 <- suppressMessages(select_directed(pred, un, 9, threshold = 0.5,
                                         previous = rd))
  chave <- function(x) paste(x$site, x$species_code, audio_stem(x$source_audio),
                             x$clip_start)
  expect_false(any(chave(r4) %in% chave(rd)))
  expect_error(select_directed(pred, un, 2, 0.5,
                               previous = dplyr::select(rd, -source_audio)),
               "source_audio")
})

test_that("select_directed() drops empty units and takes all when n is large", {
  pred <- sim_pred()
  un <- unidades_sim(pred)
  un <- dplyr::bind_rows(un, tibble::tibble(site = "ZZZ",
                                            species_code = un$species_code[1],
                                            month = un$month[1], size = 50))
  msgs <- capture_messages(sel <- select_directed(pred, un, 1000,
                                                  threshold = 0.5))
  expect_match(msgs, "without candidate occasions", all = FALSE)
  expect_match(msgs, "census", all = FALSE)
  u <- attr(sel, "units")
  expect_false(u$drawn[u$site == "ZZZ"])
  expect_equal(u$inclusion_prob_unit[u$site == "ZZZ"], 0)
  expect_true(all(u$drawn[u$n_occasions > 0]))
  expect_true(all(u$inclusion_prob_unit[u$n_occasions > 0] == 1))
})

test_that("a unit of size 0 can be drawn thanks to the floor", {
  pred <- sim_pred()
  un <- unidades_sim(pred)
  un$size[1] <- 0
  u <- attr(suppressMessages(select_directed(pred, un, 3, threshold = 0.5)),
            "units")
  expect_gt(u$inclusion_prob_unit[u$size == 0], 0)
  u0 <- attr(suppressMessages(select_directed(pred, un, 3, threshold = 0.5,
                                              floor = 0)), "units")
  expect_equal(u0$inclusion_prob_unit[u0$size == 0], 0)
})

test_that("select_directed() checks its inputs", {
  pred <- sim_pred()
  un <- unidades_sim(pred)
  expect_error(select_directed(pred, un, 2, 0.5, size_col = "gain"),
               "size column")
  expect_error(select_directed(pred, un["size"], 2, 0.5), "besides")
  neg <- un; neg$size[1] <- -1
  expect_error(select_directed(pred, neg, 2, 0.5), "non-negative")
  expect_error(select_directed(pred, rbind(un, un[1, ]), 2, 0.5),
               "more than one row")
  expect_error(select_directed(pred, dplyr::mutate(un, habitat = "a"), 2,
                               0.5), "not in the predictions")
  expect_error(select_directed(pred, un, 0, 0.5), "positive whole")
  expect_error(select_directed(pred, un, 2, NA), "one number")
  expect_error(select_directed(pred, un, 2, 0.5, floor = -1), "floor")
  expect_error(select_directed(pred, as.list(un), 2, 0.5), "data frame")
  zero <- un; zero$size <- 0
  expect_error(suppressMessages(select_directed(pred, zero, 2, 0.5,
                                                floor = 0)), "size > 0")
  # unidade que muda dentro da ocasiao (o deslocamento no arquivo)
  por_trecho <- dplyr::distinct(pred, site, species_code, file_offset) |>
    dplyr::mutate(size = 1)
  expect_error(suppressMessages(select_directed(pred, por_trecho, 2, 0.5)),
               "more than one unit")
})

test_that("export_occupancy_data() keeps directed_pps clips with their scope", {
  pred <- sim_pred()
  un <- unidades_sim(pred)
  sel <- suppressMessages(do.call(select_directed, c(
    list(pred, un, 5, threshold = 0.5), remap())))
  sel$verdict <- "negative"
  sel$verdict[1] <- "positive"
  out <- suppressWarnings(export_sim(validation = sel))
  v <- readr::read_csv(file.path(out$dir, "validation.csv"),
                       show_col_types = FALSE)
  expect_true(all(v$sampling_mode == "directed_pps"))
  expect_true(all(v$review_scope == "occasion"))
  expect_equal(v$inclusion_prob, sel$inclusion_prob[match(
    paste(v$occasion_id, v$clip_start),
    paste(sel$occasion_id, sel$clip_start))])
  expect_false(anyNA(v$stratum))
  sel$verdict[2] <- "not_reviewed"
  v2 <- readr::read_csv(file.path(
    suppressWarnings(export_sim(validation = sel))$dir, "validation.csv"),
    show_col_types = FALSE)
  oc <- sel$occasion_id[2]
  expect_true(all(v2$review_scope[v2$occasion_id == oc] == "clip"))
})
