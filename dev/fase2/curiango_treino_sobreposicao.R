# Sobreposicao entre os clipes de treino do classificador custom do Curiango
# (D:/art-cur/IA/01_training/compau e /noise, da Liliana) e os minutos do
# deposito, os 1.199 verificados e os conjuntos de teste.
# Os nomes dos clipes trazem a gravacao de origem, por exemplo
#   0.507_12_DIVSPTS01_44p1K_UEM_UEM01_20221019_034500_42.0...wav
#   noise.DIVSPTS01_44p1K_XAR_XAR01_20231130_204500.flac.wav
# Um clipe sobreposto a um verificado deixa otimistas as metricas do custom
# (nao as do BirdNET).
#
# Uso: Rscript dev/fase2/curiango_treino_sobreposicao.R <lista_compau.txt> <lista_noise.txt>
# Cada lista e a saida de `ls` da pasta (um nome por linha), fora do repositorio.
suppressMessages(library(dplyr))
args <- commandArgs(TRUE)
rd <- function(f, tipo) {
  x <- trimws(readLines(f)); x <- x[grepl("44p1K_[A-Z]+_.*\\d{8}_\\d{6}", x)]
  tibble(tipo = tipo, nome = x, site = sub(".*44p1K_([A-Z]+)_.*", "\\1", x),
         time = as.POSIXct(sub(".*?_(\\d{8}_\\d{6}).*", "\\1", x), format = "%Y%m%d_%H%M%S", tz = "UTC"))
}
tr <- bind_rows(rd(args[1], "curiango"), rd(args[2], "ruido"))
cat("clipes lidos:", nrow(tr), "\n"); print(table(tr$tipo, tr$site))
utc <- function(d) mutate(d, time = as.POSIXct(format(time, "%Y-%m-%d %H:%M:%S"), tz = "UTC"))
m <- utc(crywolf::curiango$minutes); v <- utc(crywolf::curiango$verified)
g <- distinct(tr, tipo, site, time)
cat("\ngravacoes de origem distintas:", nrow(distinct(g, site, time)), "\n")
cat("faixa de datas:", format(range(g$time)), "\n")
rng <- m |> group_by(site) |> summarise(ini = min(time), fim = max(time))
g <- g |> left_join(rng, by = "site") |> mutate(no_periodo = time >= ini & time <= fim,
  no_deposito = paste(site, time) %in% paste(m$site, m$time),
  verificado = paste(site, time) %in% paste(v$site, v$time))
print(g |> group_by(tipo) |> summarise(n = n(), no_periodo = sum(no_periodo, na.rm = TRUE),
                                       no_deposito = sum(no_deposito), verificado = sum(verificado)))
sob <- g |> filter(verificado) |> left_join(v |> select(site, time, y), by = c("site", "time"))
if (nrow(sob)) { cat("\nclipes de treino entre os verificados:\n"); print(as.data.frame(sob[, c("tipo", "site", "time", "y")])) }
