# Acesso as saidas de referencia da v1.2.0 (fixtures/ref_v1.2.0), geradas
# por data-raw/make_reference_v1.2.0.R

#' @srrstats {G5.4} Outputs are tested against stored reference outputs of the v1.2.0 script implementation (`tests/testthat/helper-reference.R`, `tests/testthat/fixtures/`), and the probability-rule threshold is tested against the analytic inversion of a logistic calibration.
#' @srrstats {G5.4b} Results are compared with the previous implementation (v1.2.0) through stored outputs; see G5.4.
ref_path <- function(...) test_path("fixtures", "ref_v1.2.0", ...)

# Raiz simulada (a mesma de make_reference_v1.2.0.R), criada uma vez por
# sessao de testes
sim_root <- local({
  raiz <- NULL
  function() {
    if (is.null(raiz)) {
      raiz <<- file.path(tempdir(), "sheepdog-sim")
      unlink(raiz, recursive = TRUE)
      dir.create(raiz)
      raiz <<- normalizePath(raiz, winslash = "/")
      simulate_pam(raiz)
      utils::write.csv(simulate_recordings_table(raiz),
                       file.path(raiz, "gravacoes.csv"), row.names = FALSE)
    }
    raiz
  }
})

# Nomes dos argumentos da v1.2.0 (config) -> argumentos do pacote
legacy_args <- c(
  modo_amostragem = "sampling_mode", unidade_ocasiao = "occasion_unit",
  limiar = "threshold", n_top = "n_top",
  fracao_gravacoes = "recording_fraction",
  n_gravacoes_por_local = "n_recordings_per_site",
  tabela_gravacoes = "recordings", padrao_audio = "audio_pattern",
  duracao_gravacao = "recording_duration", conf_minima = "min_confidence",
  locais = "sites", data_inicio = "date_start", data_fim = "date_end",
  especies = "species", hora_inicio = "hour_start", hora_fim = "hour_end",
  alternar_dias = "alternate_days", meta_total = "target_total",
  balancear_por_hora = "balance_by_hour", max_por_especie = "max_per_species",
  remap_de = "remap_from", remap_para = "remap_to"
)
legacy_arg_values <- c(aleatorio_deteccoes = "random_detections",
                       aleatorio_gravacoes = "random_recordings",
                       arquivo = "file", minuto = "minute")

# Argumentos de select_clips() equivalentes ao config de um cenario
scenario_args <- function(nome) {
  raiz <- sim_root()
  cfg <- utils::modifyList(readRDS(ref_path("base_extracao.rds")),
                           readRDS(ref_path(nome, "cenario.rds")),
                           keep.null = TRUE)
  cfg <- cfg[intersect(names(cfg), names(legacy_args))]
  cfg <- lapply(cfg, function(x) {
    if (!is.character(x)) return(x)
    x <- sub("<ROOT>", raiz, x, fixed = TRUE)
    ifelse(x %in% names(legacy_arg_values), legacy_arg_values[x], x)
  })
  stats::setNames(cfg, legacy_args[names(cfg)])
}

# Le um csv como texto (todas as colunas character), para comparar
# exatamente o que foi escrito
read_as_text <- function(caminho) {
  readr::read_csv(caminho, col_types = readr::cols(.default = "c"),
                  na = character(), progress = FALSE)
}

# Compara uma saida com a referencia da v1.2.0 (as duas lidas como texto).
# Colunas numericas sao comparadas com tolerancia, porque os ultimos digitos
# das contas variam entre plataformas; nos nomes de clipe, o prefixo da
# confidence (3 casas) e ignorado, porque o arredondamento de valores no
# limite tambem varia -- a confidence em si e comparada na sua coluna.
# As saidas de modelos ajustados por otimizacao (GLMM) pedem uma tolerancia
# maior, passada em `tolerance`
expect_same_table <- function(novo, ref, label = NULL, tolerance = 1e-8) {
  normalizar <- function(df) {
    df[] <- lapply(df, function(x) {
      num <- suppressWarnings(as.numeric(x))
      if (identical(is.na(num), is.na(x) | x %in% c("NA", ""))) num else x
    })
    for (col in intersect(c("clip_file", "reviewed_path"), names(df))) {
      df[[col]] <- sub("(^|/)[0-9]+\\.[0-9]{3}_", "\\1", df[[col]])
    }
    df
  }
  expect_equal(normalizar(novo), normalizar(ref), tolerance = tolerance,
               label = label)
}

# Escreve uma tabela como o pacote escreve e le de volta como texto,
# trocando a raiz simulada por <ROOT>
as_written <- function(df) {
  f <- tempfile(fileext = ".csv")
  readr::write_csv(df, f)
  txt <- gsub(sim_root(), "<ROOT>", readLines(f), fixed = TRUE)
  writeLines(txt, f)
  read_as_text(f)
}

# Colunas e valores das tabelas de saida da v1.2.0 que o pacote nunca le
# (so escreve): o mapa fica aqui, para comparar com as referencias
ref_columns <- c(
  faixa = "bin", n_validados = "n_reviewed", n_positivos = "n_positive",
  precisao = "precision", pouco_suporte = "low_support",
  n_suporte = "n_support", precisao_no_corte = "precision_at_threshold",
  n_clipes = "n_clips", presenca = "presence",
  conf_max_positivo = "max_confidence_positive",
  modelo = "model", auc_media = "auc_mean", auc_dp = "auc_sd",
  n_por_celula = "n_per_cell", data = "date", hora = "hour",
  noites = "nights", noites_k1 = "nights_k1", noites_k2 = "nights_k2",
  noites_k3 = "nights_k3", mes = "month",
  n_noites_gravadas = "n_nights_recorded", incluido = "included",
  n_noites_deteccao = "n_nights_detected", frequencia = "frequency"
)
ref_values <- c(
  confirmada = "confirmed",
  nao_detectada_nos_validados = "not_detected_in_reviewed",
  nao_validada = "not_reviewed",
  m1_int_especie = "m1_species_intercept",
  m2_slope_especie = "m2_species_slope", m3_mais_local = "m3_plus_site",
  m4_especie_x_local = "m4_species_x_site"
)

# Referencia da v1.2.0 convertida para os nomes atuais
# rec_prefix = FALSE mantem o prefixo "grav_" (clipes cortados pela v1.2.0)
ref_table <- function(..., rec_prefix = TRUE) {
  ref <- read_as_text(ref_path(...))
  # recodifica os valores lidos como texto ("NA" continua "NA")
  out <- sheepdog:::from_legacy(ref)
  if (rec_prefix && "clip_file" %in% names(out)) {
    out$clip_file <- sub("^grav_", "rec_", out$clip_file)
  }
  velhas <- intersect(names(ref_columns), names(out))
  names(out)[match(velhas, names(out))] <- ref_columns[velhas]
  for (col in intersect(c("presence", "model"), names(out))) {
    x <- out[[col]]
    out[[col]] <- ifelse(x %in% names(ref_values), ref_values[x], x)
  }
  out
}
