# pi1 exato do sorteio ct01+ct02 do Curiango, a partir do script da Liliana
# (Disponibilidade_dados_clima.R, achado no NAS em 25/11/2026).
#
# Desenho: quadro = registros do datalogger (clima_diversons_noite.csv,
# 16:00-23:50 e 00:10-06:00); peso = mes (5 ago-out, 3 nov-jan, 1 resto) x
# hora (4 de 18 a 22 h, 2 de 0 a 5 h, 1 resto); slice_sample(prop = 0.01,
# weight_by = peso) por sitio, sem reposicao e sem semente. Sorteados sem
# audio do sitio cairam; os 967 restantes formam ct01+ct02.
#
# pi1 por classe de peso dentro do sitio (unidades de mesmo peso sao
# trocaveis): aproximacao n w / W e Monte Carlo do sample.int sem reposicao.
#
# Uso: Rscript dev/fase2/curiango_pi1_exato.R <pasta liliana_sorteio> [saida.csv] [pi_verificados.csv]
suppressMessages(library(dplyr))
args <- commandArgs(TRUE); dir <- args[1]; out <- if (length(args) > 1) args[2] else NULL
fr <- read.csv(file.path(dir, "clima_diversons_noite.csv"))
am <- read.csv(file.path(dir, "amostra_teste_curiango.csv"))
fr <- fr |> mutate(hora = floor(Hora_24 / 10000),
  peso_mes = case_when(Mes %in% c(8, 9, 10) ~ 5, Mes %in% c(11, 12, 1) ~ 3, TRUE ~ 1),
  peso_hora = case_when(hora >= 18 & hora <= 22 ~ 4, hora >= 0 & hora <= 5 ~ 2, TRUE ~ 1),
  w = peso_mes * peso_hora, key = paste(Site, DataHora_Formatada))
stopifnot(all(paste(am$Site, am$DataHora) %in% fr$key))
chk <- am |> mutate(key = paste(Site, DataHora)) |> left_join(select(fr, key, w), by = "key")
stopifnot(all(chk$w == chk$peso_total))
n_s <- fr |> count(Site, name = "N") |> left_join(count(am, Site, name = "n"), by = "Site") |>
  mutate(n_floor = floor(0.01 * N))
print(n_s)
set.seed(2026); R <- 400
cls <- fr |> group_by(Site, w) |> summarise(Nw = n(), .groups = "drop") |>
  left_join(select(n_s, Site, n), by = "Site") |> group_by(Site) |>
  mutate(pi_aprox = n * w / sum(Nw * w)) |> ungroup()
mc <- lapply(split(fr, fr$Site), function(d) {
  n <- n_s$n[n_s$Site == d$Site[1]]
  hits <- tabulate(unlist(lapply(seq_len(R), \(r) sample.int(nrow(d), n, prob = d$w))), nrow(d))
  tibble(Site = d$Site[1], w = d$w, h = hits) |> group_by(Site, w) |>
    summarise(pi_mc = sum(h) / (R * n()), .groups = "drop") })
cls <- left_join(cls, bind_rows(mc), by = c("Site", "w"))
print(as.data.frame(mutate(cls, across(starts_with("pi"), \(x) signif(x, 4)))))
fr <- left_join(fr, select(cls, Site, w, pi_aprox, pi_mc), by = c("Site", "w"))
if (!is.null(out)) write.csv(select(fr, site = Site, datahora = DataHora_Formatada, w, pi_aprox, pi_mc), out, row.names = FALSE)

# Optional third argument: pi_verificados.csv (from curiango_pi_ct03.R) to
# update in place. The model pi1 is kept as pi1_modelo; pi1 becomes the design
# pi1 (n w / W; the Monte Carlo agrees within its noise), and pi and pi_f03
# are recomputed with the same pi3.
if (length(args) > 2) {
  pv <- read.csv(args[3])
  if (!"pi1_modelo" %in% names(pv)) pv$pi1_modelo <- pv$pi1
  k <- paste(pv$site, format(as.POSIXct(pv$time, tz = "UTC"), "%Y%m%d_%H%M%S"))
  pv$pi1 <- signif(fr$pi_aprox[match(k, fr$key)], 4)
  stopifnot(!anyNA(pv$pi1))
  pv$pi <- signif(pv$pi1 + (1 - pv$pi1) * pv$pi3, 4)
  pv$pi_f03 <- signif(pv$pi1 + (1 - pv$pi1) * 0.3 * pv$pi3, 4)
  write.csv(pv, args[3], row.names = FALSE)
  cat("pi_verificados atualizado:", nrow(pv), "linhas\n")
}
