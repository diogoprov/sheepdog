# Rodada do BirdNET "Clima_noite" da Liliana (03_output_Birdnet-Clima_noite)
# contra o deposito e as rodadas dos conjuntos de teste, e o criterio da
# complementacao (ct03). Complementa curiango_conjuntos_teste.R.
#
# Uso: Rscript dev/fase2/curiango_rodada_clima.R <pasta_zip> <pasta_clima>
# <pasta_zip> contem liliana_zip/ (Evaluation.zip extraido); <pasta_clima>
# contem BirdNET_SelectionTable.txt, .list.txt e BirdNET_analysis_params.csv
# (pasta misterio_curiango no Box do codigo FrogNet). Fora do repositorio.
suppressMessages(library(dplyr))
args <- commandArgs(TRUE); base <- file.path(args[1], "liliana_zip"); mc <- args[2]
key <- function(f) { f <- sub("\\.flac$", "", sub(".*\\\\", "", f))
  tibble(file = f, site = sub("^DIVSPTS01_44p1K_([A-Z]+)_.*", "\\1", f),
         time = as.POSIXct(sub(".*_(\\d{8}_\\d{6})$", "\\1", f), format = "%Y%m%d_%H%M%S", tz = "UTC")) }
m <- crywolf::curiango$minutes |> mutate(time = as.POSIXct(format(time, "%Y-%m-%d %H:%M:%S"), tz = "UTC"))
v <- crywolf::curiango$verified |> mutate(time = as.POSIXct(format(time, "%Y-%m-%d %H:%M:%S"), tz = "UTC"))
lst <- key(readLines(file.path(mc, "BirdNET_SelectionTable.list.txt")))
cat("arquivos na rodada:", nrow(lst), " em comum com o deposito:", nrow(semi_join(lst, m, by = c("site","time"))), "\n")
st <- read.delim(file.path(mc, "BirdNET_SelectionTable.txt"), check.names = FALSE)
st <- bind_cols(st, key(st$`Begin Path`))
cm <- st |> group_by(site, time) |> summarise(bn_clima = max(Confidence), n_win = n(), .groups = "drop")
a <- m |> left_join(cm, by = c("site","time")) |> mutate(bn_clima = coalesce(bn_clima, 0), n_win = coalesce(n_win, 0L))
cat("Clima_noite x deposito: iguais", round(mean(abs(a$bn_clima - a$conf_birdnet) < 1e-3), 4), " cor", round(cor(a$bn_clima, a$conf_birdnet), 4), "\n")
# rodadas dos conjuntos
rd <- function(d) { fs <- list.files(file.path(base, d), pattern = "selection.table.txt$", full.names = TRUE)
  bind_rows(lapply(fs, \(f) { x <- read.delim(f, check.names = FALSE); x$file <- sub("\\.BirdNET.*", "", basename(f)); x })) }
lst_ct <- function(d) key(readLines(file.path(base, d, "BirdNET_SelectionTable.list.txt")))
sets <- bind_rows(ct01 = lst_ct("03_output_Birdnet_ct01"), ct02 = lst_ct("03_output_Birdnet-ct02"), ct03 = lst_ct("03_output_Birdnet-ct03"), .id = "ct")
b <- bind_rows(rd("03_output_Birdnet_ct01"), rd("03_output_Birdnet-ct02"), rd("03_output_Birdnet-ct03"))
bm <- b |> group_by(file) |> summarise(bn_ct = max(ifelse(`Common Name` == "Common Pauraque", Confidence, 0)))
x <- sets |> left_join(bm, by = "file") |> left_join(a, by = c("site","time"))
cat("conjuntos x Clima_noite: iguais", round(mean(abs(x$bn_ct - x$bn_clima) < 1e-3, na.rm = TRUE), 4), "\n")
cat("conjuntos x deposito: iguais", round(mean(abs(x$bn_ct - x$conf_birdnet) < 1e-3, na.rm = TRUE), 4), "\n")
print(x |> group_by(ct) |> summarise(n = n(), bn_clima_pos = mean(bn_clima > 0), bn_dep_pos = mean(conf_birdnet > 0), bn_ct_pos = mean(bn_ct > 0), min_clima = min(bn_clima)))
# ct03 sem os 2 repetidos
u3 <- x |> filter(ct == "ct03", !file %in% x$file[x$ct != "ct03"])
cat("\nct03 (239): bn_clima > 0:", sum(u3$bn_clima > 0), " min bn_clima:", min(u3$bn_clima), "\n")
print(quantile(u3$bn_clima, c(0, .05, .1, .25, .5)))
cat("populacao bn_clima > 0:", sum(a$bn_clima > 0), " por sitio:\n"); print(table(a$site[a$bn_clima > 0]))
cat("ct03 por sitio:\n"); print(table(u3$site))
cat("fração escolhida entre bn_clima>0 por sitio:\n"); print(round(table(u3$site[u3$bn_clima>0]) / table(a$site[a$bn_clima > 0])[names(table(u3$site[u3$bn_clima>0]))], 3))
# selecao de ct03 entre os bn_clima > 0 e fora dos sorteados: depende do score?
cand <- a |> filter(bn_clima > 0) |> anti_join(filter(x, ct != "ct03"), by = c("site","time")) |>
  mutate(sel = as.integer(paste(site, time) %in% paste(u3$site, u3$time)), ym = format(time, "%Y-%m"), h = format(time, "%H"))
cat("candidatos:", nrow(cand), " escolhidos:", sum(cand$sel), "\n")
g0 <- glm(sel ~ site + ym + h, binomial, cand); g1 <- update(g0, . ~ . + qlogis(pmin(bn_clima, .999)))
print(anova(g0, g1, test = "LRT")); print(coef(summary(g1))[nrow(coef(summary(g1))), ])
print(cand |> mutate(faixa = cut(bn_clima, c(0, .1, .2, .3, .5, .7, 1))) |> group_by(faixa) |> summarise(N = n(), esc = sum(sel), pct = round(100 * esc / N, 1)))
cat("\nmeses ct03:\n"); print(table(format(u3$time, "%Y-%m")))
cat("\n--- o custom (ou o BirdNET do deposito) ainda prediz a escolha, dado o BirdNET Clima_noite? ---\n")
cand <- cand |> mutate(lbc = qlogis(pmin(bn_clima, .999)), lcu = qlogis(pmin(pmax(conf_custom, 1e-3), .999)),
                       lbd = qlogis(pmin(pmax(conf_birdnet, 1e-3), .999)))
g1 <- glm(sel ~ site + ym + h + lbc, binomial, cand)
print(anova(g1, update(g1, . ~ . + lcu), test = "LRT")[2, ])
print(anova(g1, update(g1, . ~ . + lbd), test = "LRT")[2, ])
# y so existe nos escolhidos; checar o padrao dos 19 sem BirdNET
z <- u3 |> filter(bn_clima == 0) |> left_join(v |> select(site, time, y), by = c("site","time"))
cat("\nos 19 do ct03 sem deteccao no Clima_noite: custom\n"); print(summary(z$conf_custom)); cat("positivos:", sum(z$y), "de", nrow(z), "\n")
print(table(format(z$time, "%Y-%m"), z$site))
# populacao das meses usados x nao usados entre candidatos
cat("\ncandidatos por ano-mes (N) e escolhidos:\n"); print(cand |> group_by(ym) |> summarise(N = n(), esc = sum(sel)) |> as.data.frame())
