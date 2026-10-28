#' Detections of each occasion over the draws of the calibration
#'
#' Turns an export of [export_occupancy_data()] with calibration draws into
#' one version of the detection data per posterior draw: in each draw, an
#' occasion is a detection when at least one of its predictions is judged
#' true. Any occupancy software can then fit its model to each version and
#' pool the posteriors, so that the uncertainty of the calibration reaches
#' the ecological estimates (Monte Carlo propagation). This is the
#' occasion-level counterpart of [history_draws()], which works by night.
#'
#' @section Rules:
#' With `rule = "sample"` (default), a prediction whose probability of
#' being true is `p` in a draw is judged true with probability `p`, so no
#' threshold is involved; this assumes that the predictions of an occasion
#' are true or false independently, given the calibration. With
#' `rule = "threshold"`, it is judged true when `p >= p_min`, as in
#' [history_draws()]; this keeps only the predictions the calibration is
#' nearly sure of and gives fewer detections.
#'
#' @section Matching:
#' A prediction takes the value of the grid point nearest its score and of
#' the calibration keys of its occasion (`schema.json$calibration$keys`,
#' e.g. the month). An occasion with a prediction that has no calibration
#' draws (a species, site or key level absent from
#' `calibration_draws.parquet`) cannot be scored: it is `NA` in every draw,
#' with a warning, not a non-detection.
#'
#' @section Reproducibility:
#' The random numbers follow those of `crywolf::fp_draws_data()`, so that
#' both give the same detections for the same export, rule and seed: the
#' seed is set once per species with R's default generators
#' (Mersenne-Twister, Inversion, Rejection), and each draw, in increasing
#' order of its identifier, takes one uniform number per scored prediction,
#' in the order of `detections.csv`. The first `n` draws of a call are
#' therefore the same as those of a call with `n_draws = n`. Species are
#' processed one at a time, in alphabetical order, each from the seed. The
#' global random number generator is left as it was.
#'
#' @param export_dir Folder written by [export_occupancy_data()] with
#'   `fit`.
#' @param species Optional species to process, matched against `species`
#'   (the short code, e.g. `"phy_cuv"`) or `species_code` of
#'   `detections.csv`. All species with calibration draws by default.
#' @param rule `"sample"` or `"threshold"`; see Rules.
#' @param p_min Threshold of `rule = "threshold"`.
#' @param n_draws Optional number of calibration draws to use: the first
#'   ones, in increasing order of their identifiers. All by default.
#' @param seed Seed of `rule = "sample"`.
#' @param write Write `occasion_draws.parquet` in `export_dir` and record it
#'   in `schema.json` (schema version 1.2)? An existing table is replaced.
#'
#' @return A tibble with `draw`, `site`, `occasion_id`, `species` and `y`
#'   (1 detection, 0 none, `NA` not scored), with one row per draw and
#'   occasion with at least one exported prediction of the species. The
#'   other occasions of `occasions.csv` are non-detections in every draw.
#'   Returned invisibly when `write = TRUE`.
#' @seealso [export_occupancy_data()], [history_draws()],
#'   `vignette("crywolf-integration")`.
#' @export
occasion_draws <- function(export_dir, species = NULL,
                           rule = c("sample", "threshold"), p_min = 0.95,
                           n_draws = NULL, seed = 2026, write = TRUE) {
  rule <- match.arg(rule)
  schema_file <- file.path(export_dir, "schema.json")
  if (!file.exists(schema_file)) {
    stop("No schema.json in `export_dir`; was it written by ",
         "export_occupancy_data()?", call. = FALSE)
  }
  require_suggested("arrow", "to read calibration_draws.parquet")
  schema <- jsonlite::read_json(schema_file, simplifyVector = TRUE)
  if (length(schema$calibration$covariates) > 0) {
    stop("The calibration of this export depends on continuous ",
         "covariate(s) (", paste(schema$calibration$covariates, collapse = ", "),
         "): it has no grid of calibration draws, and its versions were ",
         "drawn by export_occupancy_data() (occasion_draws.parquet). To ",
         "change the rule, the seed or the number of versions, export again ",
         "with `n_versions`, `rule`, `p_min` and `seed`.", call. = FALSE)
  }
  parquet <- file.path(export_dir, "calibration_draws.parquet")
  if (is.null(schema$calibration) || !file.exists(parquet)) {
    stop("The export has no calibration draws; write it with ",
         "export_occupancy_data(fit = ).", call. = FALSE)
  }
  if (rule == "sample" && (!is.numeric(seed) || length(seed) != 1 ||
                           is.na(seed))) {
    stop("`seed` must be a number for rule = \"sample\".", call. = FALSE)
  }
  chaves <- setdiff(schema$calibration$keys,
                    c("site", "species", "grid_index"))
  # tudo como texto (identificadores e chaves nao viram numero); so o
  # score e convertido
  ler <- function(nome) {
    readr::read_csv(file.path(export_dir, nome), na = "", progress = FALSE,
                    col_types = readr::cols(.default = readr::col_character()))
  }
  det <- ler("detections.csv")
  det$confidence <- as.numeric(det$confidence)
  ocasioes <- ler("occasions.csv")
  for (ch in chaves) {
    if (!ch %in% names(ocasioes)) {
      # exports 1.0 com calibracao por mes nao gravavam a coluna
      if (ch != "month") {
        stop("Calibration key `", ch, "` is not a column of occasions.csv.",
             call. = FALSE)
      }
      ocasioes$month <- substr(ocasioes$recording_date, 1, 6)
    }
  }
  cal <- as.data.frame(arrow::read_parquet(parquet))
  for (ch in c("site", "species", chaves)) cal[[ch]] <- as.character(cal[[ch]])

  especies <- sort(unique(det$species[det$species %in% cal$species]))
  if (!is.null(species)) {
    pedidas <- unique(det$species[det$species %in% species |
                                    det$species_code %in% species])
    especies <- intersect(especies, pedidas)
  }
  if (length(especies) == 0) {
    stop("No species with both predictions and calibration draws",
         if (!is.null(species)) " among `species`", ".", call. = FALSE)
  }
  out <- map(especies, \(sp) occasion_draws_species(
    det[det$species == sp, ], ocasioes, cal[cal$species == sp, ], chaves,
    schema$calibration$grid_step, rule, p_min, n_draws, seed)) |>
    list_rbind()

  if (!write) return(out)
  arrow::write_parquet(out, file.path(export_dir, "occasion_draws.parquet"))
  schema$schema_version <- 1.2
  schema$tables$occasion_draws <- list(file = "occasion_draws.parquet",
                                       rows = nrow(out))
  schema$occasion_draws <- compact(list(
    file = "occasion_draws.parquet", rule = rule,
    p_min = if (rule == "threshold") p_min,
    seed = if (rule == "sample") seed,
    n_draws = length(unique(out$draw)), species = I(especies)))
  # listas de um elemento continuam listas no JSON
  for (campo in c("sites", "species", "occasion_covariates")) {
    if (!is.null(schema[[campo]])) schema[[campo]] <- I(schema[[campo]])
  }
  if (!is.null(schema$calibration$keys)) {
    schema$calibration$keys <- I(schema$calibration$keys)
  }
  jsonlite::write_json(schema, schema_file, auto_unbox = TRUE, pretty = TRUE,
                       digits = NA)
  message("occasion_draws.parquet written to ", export_dir, ": ",
          nrow(out), " rows, ", length(unique(out$draw)), " draws.")
  invisible(out)
}

# Uma especie: matriz de P(TP) por chave x draw, casamento das predicoes e
# sorteio na ordem de crywolf::fp_draws_data()
occasion_draws_species <- function(det, ocasioes, cal, chaves, step, rule,
                                   p_min, n_draws, seed) {
  ids <- sort(unique(cal$draw))
  if (!is.null(n_draws)) ids <- utils::head(ids, n_draws)
  cal <- cal[cal$draw %in% ids, , drop = FALSE]
  # a origem da grade com os bits gravados (o valor do JSON pode diferir
  # no ultimo digito)
  grid_min <- min(cal$confidence[cal$grid_index == 1])
  chave <- function(d, g) {
    do.call(paste, c(unname(as.list(d[c("site", "species", chaves)])),
                     list(g, sep = "\r")))
  }
  linhas <- unique(chave(cal, cal$grid_index))
  if (anyDuplicated(cbind(chave(cal, cal$grid_index), cal$draw))) {
    stop("calibration_draws.parquet has more than one value for some key ",
         "and draw; is a key missing from schema.json?", call. = FALSE)
  }
  P <- matrix(NA_real_, length(linhas), length(ids))
  P[cbind(match(chave(cal, cal$grid_index), linhas),
          match(cal$draw, ids))] <- cal$p_tp

  occ_key <- paste(ocasioes$site, ocasioes$occasion_id, sep = "\r")
  o <- match(paste(det$site, det$occasion_id, sep = "\r"), occ_key)
  g <- round((det$confidence - grid_min) / step) + 1
  g <- pmin(pmax(g, 1), max(cal$grid_index))
  det_chaves <- ocasioes[o, chaves, drop = FALSE]
  k <- match(chave(cbind(det[c("site", "species")], det_chaves), g), linhas)
  Pdet <- matrix(NA_real_, nrow(det), length(ids))
  Pdet[!is.na(k), ] <- P[k[!is.na(k)], , drop = FALSE]
  sample_versions(det, ocasioes, o, Pdet, ids, rule, p_min, seed,
                  motivo = "without calibration draws")
}

# Sorteio das versoes de uma especie, na ordem de crywolf::fp_draws_data():
# `Pdet` tem P(TP) de cada predicao (linhas, na ordem de detections.csv) em
# cada draw (colunas, `ids` em ordem crescente); `o` e a linha da ocasiao de
# cada predicao em `ocasioes`. Predicoes sem P(TP) deixam a ocasiao NA.
sample_versions <- function(det, ocasioes, o, Pdet, ids, rule, p_min, seed,
                            motivo) {
  if (anyNA(o)) {
    warning(sum(is.na(o)), " prediction(s) of ", det$species[1], " are not ",
            "in occasions.csv and were left out.", call. = FALSE)
  }
  sem_cal <- !stats::complete.cases(Pdet) & !is.na(o)
  nao_pontuadas <- unique(o[sem_cal])
  if (length(nao_pontuadas) > 0) {
    warning(sum(sem_cal), " prediction(s) of ", det$species[1], " ", motivo,
            ": their ", length(nao_pontuadas),
            " occasion(s) are NA (not scored).", call. = FALSE)
  }
  # fora do sorteio: sem P(TP), fora das ocasioes e todas as predicoes de
  # uma ocasiao nao pontuada
  keep <- !sem_cal & !is.na(o) & !(o %in% nao_pontuadas)
  Pk <- Pdet[keep, , drop = FALSE]
  o_keep <- o[keep]
  com_pred <- sort(unique(o[!is.na(o)]))

  sortear <- function() {
    map(seq_along(ids), function(j) {
      p <- Pk[, j]
      verdadeira <- if (rule == "sample") stats::runif(length(p)) < p
                    else p >= p_min
      y <- tabulate(o_keep[verdadeira], nbins = nrow(ocasioes))[com_pred] > 0
      y <- as.integer(y)
      y[com_pred %in% nao_pontuadas] <- NA_integer_
      tibble(draw = as.integer(ids[j]), site = ocasioes$site[com_pred],
             occasion_id = ocasioes$occasion_id[com_pred],
             species = det$species[1], y = y)
    }) |> list_rbind()
  }
  if (rule == "sample") {
    withr::with_seed(seed, sortear(), .rng_kind = "Mersenne-Twister",
                     .rng_normal_kind = "Inversion",
                     .rng_sample_kind = "Rejection")
  } else {
    sortear()
  }
}
