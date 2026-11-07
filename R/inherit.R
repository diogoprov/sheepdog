# Reuso da revisao de outro desenho (#102): o sorteio continua independente, e
# so o veredito que a revisao anterior ja da e herdado

# Herda vereditos para os clipes de `selecao`, a partir das revisoes de
# `outros` (o outro desenho). Duas revisoes tratam do mesmo trecho quando sao do
# mesmo local, especie e gravacao e seus intervalos se sobrepoem, o que cobre
# unidades diferentes (minuto e arquivo):
# * ouvido ausente -> toda predicao do trecho e negativa;
# * predicao positiva -> a gravacao ou o minuto tem a especie.
# O contrario nao vale: presente de ouvido nao diz qual predicao e verdadeira,
# e predicoes negativas nao dizem que a especie nao cantou abaixo do limiar
inherit_verdicts <- function(selecao, outros, modo) {
  if (!"verdict" %in% names(outros)) {
    stop("`previous` of another design must have the verdicts: give its ",
         "validation_by_clip.csv.", call. = FALSE)
  }
  revisados <- outros |>
    filter(verdict %in% c("positive", "negative"))
  if ("inherited_verdict" %in% names(revisados)) {
    revisados <- filter(revisados, is.na(inherited_verdict))
  }
  revisados <- revisados |>
    transmute(site = as.character(site), species_code,
              .rec = recording_name(source_audio),
              .ini = as.numeric(clip_start),
              .fim = coalesce(as.numeric(clip_end), Inf),
              .negativo = verdict == "negative", .desenho = sampling_mode)
  sobre <- selecao |>
    transmute(.linha = row_number(), site = as.character(site), species_code,
              .rec = recording_name(source_audio),
              .a = as.numeric(clip_start),
              .b = coalesce(as.numeric(clip_end), Inf)) |>
    inner_join(revisados, by = c("site", "species_code", ".rec"),
               relationship = "many-to-many") |>
    filter(.a < .fim, .ini < .b) |>
    group_by(.linha) |>
    summarise(.todos_neg = all(.negativo), .algum_pos = any(!.negativo),
              .desenho = first(.desenho), .groups = "drop")
  selecao$previously_reviewed <- FALSE
  selecao$inherited_verdict <- NA_character_
  selecao$source_design <- NA_character_
  selecao$previously_reviewed[sobre$.linha] <- TRUE
  selecao$source_design[sobre$.linha] <- sobre$.desenho
  selecao$inherited_verdict[sobre$.linha] <- if (modo == "random_detections") {
    if_else(sobre$.todos_neg, "negative", NA_character_)
  } else {
    if_else(sobre$.algum_pos, "positive", NA_character_)
  }
  selecao
}

recording_name <- function(path) {
  tools::file_path_sans_ext(basename(chartr("\\", "/", path)))
}

# Clipes sem veredito proprio recebem o herdado; um veredito dado de fato
# prevalece, e o clipe deixa de ser herdado. Sem clipe cortado, nao ha caminho
fill_inherited <- function(tabela) {
  if (!"inherited_verdict" %in% names(tabela)) return(tabela)
  tabela$inherited_verdict <- as.character(tabela$inherited_verdict)
  revisto <- tabela$verdict %in% c("positive", "negative", "uncertain")
  tabela$inherited_verdict[revisto] <- NA_character_
  herdado <- !is.na(tabela$inherited_verdict)
  tabela$verdict[herdado] <- tabela$inherited_verdict[herdado]
  if ("reviewed_path" %in% names(tabela)) {
    tabela$reviewed_path[herdado] <- NA_character_
  }
  tabela
}

# Linhas herdadas de uma tabela de manifesto ou de validacao
is_inherited <- function(tabela) {
  if (!"inherited_verdict" %in% names(tabela)) {
    return(rep(FALSE, nrow(tabela)))
  }
  !is.na(tabela$inherited_verdict)
}
