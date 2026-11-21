# Item 4 do PLANO: compara a prevalencia de minutos com canto do v1 de dois
# estagios com a referencia por desenho na mesma escala.
#
# psi_c * theta_bar (0,059) e a prevalencia de uma noite tipica nas
# covariaveis centrais; a referencia (Hajek, so ct01+ct02 com pesos 1 / pi1)
# e a media sobre todos os minutos do deposito. Aqui:
#   (1) prevalencia marginal do modelo: para cada draw, a media sobre os
#       97.806 minutos de psi_i * P(w_n = 1 | z_i = 1), com P(w = 1 | z = 1)
#       pela recursao de Markov sem emissoes (a propria cadeia, nao o dado);
#       draws de todas as replicas do bootstrap do estagio 1, peso igual;
#   (2) referencia de Hajek com bootstrap por noite (noites sorteadas com
#       reposicao entre as que tem verificados de ct01+ct02; pi1 fixo).
#   Rscript dev/fase2/curiango_prevalencia_marginal.R BOOT_DIR PI_CSV [draws_por_replica] [n_boot] [OUT_RDS]
source("dev/fase2/curiango_v1.R")
a <- commandArgs(TRUE)
nd <- if (length(a) > 2) as.integer(a[3]) else 200L
nb <- if (length(a) > 3) as.integer(a[4]) else 2000L
d <- curiango_v1("custom", c_lo = qlogis(0.1)); st <- d$stan

# (1) modelo
fs <- sort(Sys.glob(file.path(a[1], "b*", "fit_2stage_*.rds")))
dr <- do.call(rbind, lapply(fs, \(f) {
  x <- readRDS(f)$draws
  x[round(seq(1, nrow(x), length.out = nd)), , drop = FALSE]
}))
B <- dr[, grep("^beta\\[", colnames(dr)), drop = FALSE]
A <- dr[, grep("^alpha\\[", colnames(dr)), drop = FALSE]
rho <- dr[, "rho[1]"]
psi <- plogis(st$X %*% t(B))               # N_site x draws
tA <- t(A)                                 # eta de cada minuto calculado no laco (memoria)
site_of <- rep(seq_len(st$N_site), st$last - st$first + 1L)
stopifnot(length(site_of) == st$N_occ)
soma <- numeric(nrow(dr)); p1 <- numeric(nrow(dr))
for (n in seq_len(st$N_occ)) {
  i <- site_of[n]
  en <- drop(st$D[n, ] %*% tA)
  p1 <- if (n == st$first[i] || st$adj[n] == 0L) plogis(en) else
    p1 * plogis(en + rho) + (1 - p1) * plogis(en)
  soma <- soma + psi[i, ] * p1
}
prev_mod <- soma / st$N_occ
q <- \(x) quantile(x, c(.05, .5, .95))
cat("replicas:", length(fs), " draws:", nrow(dr), "\n")
cat("modelo, psi_c * theta_bar (noite tipica):", round(q(dr[, "psi_c"] * dr[, "theta_bar"]), 4), "\n")
cat("modelo, prevalencia marginal nos minutos:", round(q(prev_mod), 4), "\n")

# (2) referencia
p <- read.csv(a[2])
m <- d$minutes
km <- paste(m$site, format(m$time, "%Y-%m-%d %H:%M:%S")); kp <- paste(p$site, p$time)
j <- match(kp, km); stopifnot(!anyNA(j))
r <- data.frame(y = p$y, w = 1 / p$pi1, noite = paste(p$site, d$night[j]))[p$stage == "ct12", ]
hajek <- \(r) sum(r$w * r$y) / sum(r$w)
noites <- split(seq_len(nrow(r)), r$noite)
boot <- withr::with_seed(2026, replicate(nb, {
  k <- unlist(noites[sample.int(length(noites), replace = TRUE)], use.names = FALSE)
  hajek(r[k, ])
}))
cat("referencia: n =", nrow(r), " positivos =", sum(r$y), " noites (sitio x noite) =", length(noites),
    " N estimado =", round(sum(r$w)), "de", st$N_occ, "\n")
cat("referencia de Hajek:", round(hajek(r), 4), " bootstrap por noite:", round(q(boot), 4), "\n")
cat("proporcao sem pesos:", round(mean(r$y), 4), "\n")
cat("P(modelo marginal > referencia pontual):", round(mean(prev_mod > hajek(r)), 3), "\n")
cat("P(diferenca > 0), draws x bootstrap pareados ao acaso:",
    round(mean(prev_mod > sample(boot, length(prev_mod), replace = TRUE)), 3), "\n")
if (length(a) > 4) saveRDS(list(prev_mod = prev_mod, psi_tb = dr[, "psi_c"] * dr[, "theta_bar"],
                                hajek = hajek(r), boot = boot), a[5])
