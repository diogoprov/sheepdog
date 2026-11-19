# Probabilidades de inclusao dos 1.199 verificados do Curiango, com o ct03
# entrando "com pi estimadas" (decisao do Diogo, 19/11/2026), e as
# sensibilidades que a decisao pede: truncagem dos pesos, so ct01+ct02 e o
# fator 0,3 (se o quadro do ct03 foram so as 6 pastas de 5%).
#
# pi1 (sorteio ct01+ct02): glm(inc ~ ano-mes + hora + sitio) nos 97.806 minutos.
# pi3 (complementacao ct03): glm(sel ~ sitio + ano-mes + hora + score
#   Clima_noite + [Clima_noite = 0] + score custom), no quadro dos minutos fora
#   do ct01+ct02. Os meses sem nenhuma escolha dao pi3 ~ 0 (separacao); isso
#   nao afeta os escolhidos, que nunca caem nesses meses.
# pi = pi1 + (1 - pi1) * pi3, para todos os verificados (uniao dos estagios).
#
# Pressuposto nao testavel: a escolha do ct03 nao dependeu do estado real
# (ela nao ouviu antes de escolher). Nenhuma pi corrige isso.
#
# Uso: Rscript dev/fase2/curiango_pi_ct03.R <pasta_zip> <pasta_clima> [saida.csv]
# (as mesmas pastas de curiango_rodada_clima.R, fora do repositorio)
suppressMessages(library(dplyr))
args <- commandArgs(TRUE); base <- file.path(args[1], "liliana_zip"); mc <- args[2]
out <- if (length(args) > 2) args[3] else NULL
key <- function(f) { f <- sub("\\.flac$", "", sub(".*\\\\", "", f))
  tibble(file = f, site = sub("^DIVSPTS01_44p1K_([A-Z]+)_.*", "\\1", f),
         time = as.POSIXct(sub(".*_(\\d{8}_\\d{6})$", "\\1", f), format = "%Y%m%d_%H%M%S", tz = "UTC")) }
utc <- function(d) mutate(d, time = as.POSIXct(format(time, "%Y-%m-%d %H:%M:%S"), tz = "UTC"))
m <- utc(crywolf::curiango$minutes); v <- utc(crywolf::curiango$verified)
st <- read.delim(file.path(mc, "BirdNET_SelectionTable.txt"), check.names = FALSE)
st <- bind_cols(st, key(st$`Begin Path`))
cm <- st |> group_by(site, time) |> summarise(bn_clima = max(Confidence), .groups = "drop")
lg <- function(p) qlogis(pmin(pmax(p, 1e-3), 0.999))
a <- m |> left_join(cm, by = c("site", "time")) |>
  mutate(bn_clima = coalesce(bn_clima, 0), ym = format(time, "%Y-%m"), h = format(time, "%H"),
         lbc = ifelse(bn_clima > 0, lg(bn_clima), 0), bc0 = as.integer(bn_clima == 0), lcu = lg(conf_custom))
lst_ct <- function(d) key(readLines(file.path(base, d, "BirdNET_SelectionTable.list.txt")))
sets <- bind_rows(ct01 = lst_ct("03_output_Birdnet_ct01"), ct02 = lst_ct("03_output_Birdnet-ct02"),
                  ct03 = lst_ct("03_output_Birdnet-ct03"), .id = "ct")
k <- function(d) paste(d$site, d$time)
in12 <- k(a) %in% k(filter(sets, ct != "ct03"))
in3 <- k(a) %in% k(filter(sets, ct == "ct03")) & !in12        # 239 sem os 2 repetidos
a$inc12 <- as.integer(in12); a$sel3 <- as.integer(in3)

f1 <- glm(inc12 ~ ym + h + site, binomial, a)
a$pi1 <- fitted(f1)
fr <- a[!in12, ]
f3 <- suppressWarnings(glm(sel3 ~ site + ym + h + lbc + bc0 + lcu, binomial, fr))
a$pi3 <- 0; a$pi3[!in12] <- fitted(f3)
cat("pi1: soma", round(sum(a$pi1)), "(n =", sum(in12), ")  pi3: soma", round(sum(a$pi3)), "(n =", sum(in3), ")\n")

d <- a |> filter(in12 | in3) |> inner_join(v |> select(site, time, y), by = c("site", "time")) |>
  mutate(stage = ifelse(inc12 == 1, "ct12", "ct03"),
         pi = pi1 + (1 - pi1) * pi3, pi_f03 = pi1 + (1 - pi1) * 0.3 * pi3)
cat("verificados com pi:", nrow(d), " positivos:", sum(d$y), "\n")
kish <- function(w) round(sum(w)^2 / sum(w^2))
trunc_w <- function(w, q = 0.95) pmin(w, quantile(w, q))
hajek <- function(y, w) sum(w * y) / sum(w)
cat("\npesos 1/pi por estagio:\n")
print(d |> group_by(stage) |> summarise(n = n(), pos = sum(y), w_min = round(min(1 / pi)), w_med = round(median(1 / pi)),
                                        w_max = round(max(1 / pi)), soma_w = round(sum(1 / pi))))
top <- sort(1 / d$pi, decreasing = TRUE)
cat("fracao do peso total nos 10 maiores:", round(sum(top[1:10]) / sum(top), 3), "\n")
cat("positivos com peso > 500:", sum(d$y == 1 & 1 / d$pi > 500), " escores Clima_noite deles:",
    paste(round(d$bn_clima[d$y == 1 & 1 / d$pi > 500], 2), collapse = " "), "\n")

esq <- list(
  "so ct01+ct02 (pi1)"        = with(filter(d, stage == "ct12"), list(y = y, w = 1 / pi1, d = filter(d, stage == "ct12"))),
  "todos, pi"                 = list(y = d$y, w = 1 / d$pi, d = d),
  "todos, pi, truncado p95"   = list(y = d$y, w = trunc_w(1 / d$pi), d = d),
  "todos, pi com fator 0,3"   = list(y = d$y, w = 1 / d$pi_f03, d = d),
  "todos, sem peso"           = list(y = d$y, w = rep(1, nrow(d)), d = d))
cat("\nprevalencia (Hajek) e n efetivo:\n")
print(do.call(rbind, lapply(names(esq), \(nm) with(esq[[nm]], data.frame(esquema = nm, n = length(y), pos = sum(y),
  prev = round(hajek(y, w), 4), n_eff = kish(w))))), row.names = FALSE)

# P(y = 1 | faixa de score), ponderada: e o que o estagio 1 usa para a curva
fx <- function(s) cut(s, c(-Inf, 0, 0.1, 0.3, 0.5, 0.7, 1), labels = c("0", "0-0.1", "0.1-0.3", "0.3-0.5", "0.5-0.7", "0.7-1"))
for (sc in c("conf_birdnet", "conf_custom")) {
  cat("\nP(y = 1 | faixa de", sc, ") por esquema (n na faixa entre parenteses no 'todos'):\n")
  tab <- sapply(esq, \(e) tapply(seq_along(e$y), fx(e$d[[sc]]), \(i) if (length(i)) round(hajek(e$y[i], e$w[i]), 3) else NA))
  nn <- table(fx(d[[sc]])); print(cbind(n = as.integer(nn), tab))
}
if (!is.null(out)) {
  write.csv(d |> transmute(site, time = format(time, "%Y-%m-%d %H:%M:%S"), stage, y, conf_birdnet, conf_custom, bn_clima,
                           pi1 = signif(pi1, 4), pi3 = signif(pi3, 4), pi = signif(pi, 4), pi_f03 = signif(pi_f03, 4)),
            out, row.names = FALSE)
  cat("\ngravado:", out, "\n")
}
