# Teste das emissoes no Curiango (21/11/2026, depois da simulacao com surtos).
# O v1 supoe que, dado w (canto no minuto), a faixa de score do minuto nao
# depende dos scores dos vizinhos. Se isso vale, nos verificados do ct12
#   P(faixa | w, contexto) = P(faixa | w)
# para qualquer contexto definido so pelos outros minutos. Contexto: algum
# minuto a ate K passos (sem lacuna, mesmo sitio-noite, sem contar o proprio)
# com score >= 0,4 ("surto") ou nenhum ("longe").
#   (1) por w e contexto: distribuicao ponderada (1 / pi1) das faixas, e a
#       razao f1/f0 por faixa e contexto;
#   (2) bootstrap por sitio-noite da diferenca P(>= 0,4 | w = 1, surto) -
#       P(>= 0,4 | w = 1, longe) e da razao f1/f0 na faixa 0,1-0,4 entre
#       contextos;
#   (3) referencia pos-estratificada por faixa x contexto, contra a de 3
#       faixas (0,033);
#   (4) ct03, descritivo (escolhido ouvindo; sem pesos).
#   Rscript dev/fase2/curiango_teste_emissoes.R PI_CSV [K] [n_boot]
source("dev/fase2/curiango_v1.R")
a <- commandArgs(TRUE)
K <- if (length(a) > 1) as.integer(a[2]) else 2L
nb <- if (length(a) > 2) as.integer(a[3]) else 2000L
d <- curiango_v1("custom", c_lo = qlogis(0.1)); st <- d$stan; m <- d$minutes
N <- st$N_occ
prob <- ifelse(st$cens == 1L, 0, plogis(st$s))
faixa <- cut(prob, c(-1, 0.1, 0.2, 0.3, 0.4, 2), right = FALSE,
             labels = c("<0,1", "0,1-0,2", "0,2-0,3", "0,3-0,4", ">=0,4"))
hi <- prob >= 0.4
site_of <- rep(seq_len(st$N_site), st$last - st$first + 1L)
# run de minutos contiguos: muda a cada lacuna ou sitio-noite novo
run <- cumsum(st$adj == 0L)
viz <- logical(N)
for (lag in seq_len(K)) for (dirn in c(-1L, 1L)) {
  idx <- seq_len(N) + dirn * lag; ok <- idx >= 1 & idx <= N
  ok[ok] <- run[idx[ok]] == run[ok]
  viz[ok] <- viz[ok] | hi[idx[ok]]
}
ctx <- factor(ifelse(viz, "surto", "longe"), c("longe", "surto"))

p <- read.csv(a[1])
j <- match(paste(p$site, p$time), paste(m$site, format(m$time, "%Y-%m-%d %H:%M:%S"))); stopifnot(!anyNA(j))
r <- data.frame(stage = p$stage, y = p$y, w = 1 / p$pi1, faixa = faixa[j], ctx = ctx[j],
                noite = paste(p$site, d$night[j]))
r12 <- r[r$stage == "ct12", ]

cat("contexto com K =", K, "; minutos no deposito por faixa x contexto:\n")
print(table(faixa, ctx))
cat("\nct12, contagens (y = 1 / y = 0) por faixa x contexto:\n")
print(with(r12, table(faixa, ctx, y)))

dist <- function(x, yy, cc) {
  s <- x$y == yy & x$ctx == cc
  tapply(x$w[s], x$faixa[s], sum, default = 0) / sum(x$w[s])
}
tab <- rbind(`w=1 longe` = dist(r12, 1, "longe"), `w=1 surto` = dist(r12, 1, "surto"),
             `w=0 longe` = dist(r12, 0, "longe"), `w=0 surto` = dist(r12, 0, "surto"))
cat("\n(1) P(faixa | w, contexto), ponderada por 1 / pi1\n"); print(round(tab, 4))
cat("razao f1/f0 por faixa e contexto\n")
print(round(rbind(longe = tab[1, ] / tab[3, ], surto = tab[2, ] / tab[4, ]), 2))
cat("pesos efetivos dos positivos: longe", round(sum(r12$w[r12$y == 1 & r12$ctx == "longe"])),
    " surto", round(sum(r12$w[r12$y == 1 & r12$ctx == "surto"])), "\n")

# (2) bootstrap por sitio-noite
mid <- c("0,1-0,2", "0,2-0,3", "0,3-0,4")
stat <- function(x) {
  t1l <- dist(x, 1, "longe"); t1s <- dist(x, 1, "surto")
  t0l <- dist(x, 0, "longe"); t0s <- dist(x, 0, "surto")
  c(d_hi = t1s[[">=0,4"]] - t1l[[">=0,4"]],
    hi_surto = t1s[[">=0,4"]], hi_longe = t1l[[">=0,4"]],
    lr_mid = log((sum(t1s[mid]) / sum(t0s[mid])) / (sum(t1l[mid]) / sum(t0l[mid]))),
    mid0_surto = sum(t0s[mid]), mid0_longe = sum(t0l[mid]))
}
g <- split(seq_len(nrow(r12)), r12$noite)
bs <- withr::with_seed(2026, t(replicate(nb, stat(r12[unlist(g[sample.int(length(g), replace = TRUE)]), ]))))
cat("\n(2) bootstrap por sitio-noite (", nb, "); pontual, 5%, 50%, 95%, NA\n")
print(round(cbind(pontual = stat(r12), t(apply(bs, 2, quantile, c(.05, .5, .95), na.rm = TRUE)),
                  na = colSums(!is.finite(bs))), 3))
cat("P(d_hi <= 0):", mean(bs[, "d_hi"] <= 0, na.rm = TRUE),
    "  P(lr_mid <= 0):", mean(bs[, "lr_mid"] <= 0, na.rm = TRUE), "\n")

# (3) referencia pos-estratificada por faixa (3 estratos) e por faixa x contexto
estr <- cut(prob, c(-1, 0.1, 0.4, 2), right = FALSE)
ps <- function(x, cell_dep, cell_lab) {
  Ne <- table(cell_dep)
  pr <- tapply(x$w * x$y, cell_lab, sum) / tapply(x$w, cell_lab, sum)
  pr[is.na(pr) & grepl("0.4,2", names(pr), fixed = TRUE)] <- 1   # >= 0,4 sem rotulo: precisao 1
  pr[is.na(pr)] <- 0
  sum(pr[names(Ne)] * Ne) / N
}
c3 <- estr[j][r$stage == "ct12"]
c6 <- interaction(estr, ctx)[j][r$stage == "ct12"]
ref3 <- function(x, ii) ps(x, estr, c3[ii])
ref6 <- function(x, ii) ps(x, interaction(estr, ctx), c6[ii])
ii0 <- seq_len(nrow(r12))
b36 <- withr::with_seed(2026, t(replicate(nb, {
  ii <- unlist(g[sample.int(length(g), replace = TRUE)]); x <- r12[ii, ]
  c(ref3 = ref3(x, ii), ref6 = ref6(x, ii))
})))
cat("\n(3) referencia pos-estratificada: 3 faixas", round(ref3(r12, ii0), 4),
    " faixa x contexto", round(ref6(r12, ii0), 4), "\n")
print(round(t(apply(b36, 2, quantile, c(.05, .5, .95))), 4))
cat("precisao do ct12 por estrato x contexto:\n")
print(round(tapply(r12$w * r12$y, c6, sum) / tapply(r12$w, c6, sum), 4))

# (4) ct03 descritivo
r03 <- r[r$stage == "ct03", ]
cat("\n(4) ct03 (sem pesos): contagens por faixa x contexto x y\n")
print(with(r03, table(faixa, ctx, y)))
saveRDS(list(K = K, tab = tab, boot = bs, ref = b36, ctx = ctx), sprintf(
  "dev/fase2/results/curiango_v1/teste_emissoes_K%d.rds", K))
