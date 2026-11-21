# Onde o v1 de dois estagios poe canto a mais (21/11/2026, depois do item 4).
# Forward-backward do modelo ajustado: P(w_n = 1 | scores, rotulos) por
# minuto, media sobre draws.
#   (1) deposito inteiro: soma da posterior de canto por faixa de score,
#       contra a estimativa de Hajek da mesma faixa (ct01 + ct02, 1 / pi1);
#   (2) leave-one-out na amostra aleatoria (ct12): para cada minuto
#       verificado, a posterior sem o proprio rotulo (os outros ficam), contra
#       o rotulo, com pesos 1 / pi1; por faixa e por vizinhanca de surto
#       (algum minuto a ate 2 passos com score >= 0,4);
#   (3) ct03 (escolhido ouvindo o audio, entao a fracao de positivos nao e
#       estimavel): posterior contra rotulo, so descritivo.
#   Rscript dev/fase2/curiango_teste_ct03.R FIT_RDS EMIS_RDS PI_CSV [n_draws] [OUT_RDS]
source("dev/fase2/curiango_v1.R")
a <- commandArgs(TRUE)
nd <- if (length(a) > 3) as.integer(a[4]) else 200L
d <- curiango_v1("custom", c_lo = qlogis(0.1)); st <- d$stan; m <- d$minutes
em <- readRDS(a[2])
dr <- readRDS(a[1])$draws
dr <- dr[round(seq(1, nrow(dr), length.out = nd)), , drop = FALSE]
B <- dr[, grep("^beta\\[", colnames(dr)), drop = FALSE]
A <- dr[, grep("^alpha\\[", colnames(dr)), drop = FALSE]
rho <- if ("rho[1]" %in% colnames(dr)) dr[, "rho[1]"] else rep(0, nd)
lpsi <- st$X %*% t(B)                       # N_site x draws (logit)
tA <- t(A)
lse <- \(x, y) { mx <- pmax(x, y); ifelse(is.infinite(mx), mx, mx + log(exp(x - mx) + exp(y - mx))) }
lil <- \(x) plogis(x, log.p = TRUE); l1m <- \(x) plogis(x, lower.tail = FALSE, log.p = TRUE)

# posterior de canto em um sitio-noite i, com o vetor de rotulos v (draws em colunas)
post_site <- function(i, v) {
  ks <- st$first[i]:st$last[i]; K <- length(ks)
  eta <- st$D[ks, , drop = FALSE] %*% tA     # K x draws
  e1 <- ifelse(v[ks] == 0L, -Inf, em$e1[ks]); e0 <- ifelse(v[ks] == 1L, -Inf, em$e0[ks])
  gap <- c(TRUE, st$adj[ks[-1]] == 0L)
  a1 <- a0 <- b1 <- b0 <- matrix(0, K, nd)
  for (k in seq_len(K)) {
    if (gap[k]) {
      prev <- if (k == 1) 0 else lse(a1[k - 1, ], a0[k - 1, ])
      n1 <- prev + lil(eta[k, ]); n0 <- prev + l1m(eta[k, ])
    } else {
      n1 <- lse(a1[k - 1, ] + lil(eta[k, ] + rho), a0[k - 1, ] + lil(eta[k, ]))
      n0 <- lse(a1[k - 1, ] + l1m(eta[k, ] + rho), a0[k - 1, ] + l1m(eta[k, ]))
    }
    a1[k, ] <- n1 + e1[k]; a0[k, ] <- n0 + e0[k]
  }
  if (K > 1) for (k in (K - 1):1) {
    x1 <- e1[k + 1] + b1[k + 1, ]; x0 <- e0[k + 1] + b0[k + 1, ]
    if (gap[k + 1]) {
      t1 <- lse(lil(eta[k + 1, ]) + x1, l1m(eta[k + 1, ]) + x0); b1[k, ] <- t1; b0[k, ] <- t1
    } else {
      b1[k, ] <- lse(lil(eta[k + 1, ] + rho) + x1, l1m(eta[k + 1, ] + rho) + x0)
      b0[k, ] <- lse(lil(eta[k + 1, ]) + x1, l1m(eta[k + 1, ]) + x0)
    }
  }
  L1 <- lse(a1[K, ], a0[K, ]); lp0 <- sum(e0)
  pz <- exp(lil(lpsi[i, ]) + L1 - lse(lil(lpsi[i, ]) + L1, l1m(lpsi[i, ]) + lp0))
  pw <- exp(a1 + b1 - matrix(L1, K, nd, byrow = TRUE)) * matrix(pz, K, nd, byrow = TRUE)
  rowMeans(pw)
}

site_of <- rep(seq_len(st$N_site), st$last - st$first + 1L)
t0 <- Sys.time()
post <- numeric(st$N_occ)
for (i in seq_len(st$N_site)) post[st$first[i]:st$last[i]] <- post_site(i, st$v)
cat("forward-backward no deposito:", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "s\n")

prob <- ifelse(st$cens == 1L, 0, plogis(st$s))
faixa <- cut(prob, c(-1, 0.1, 0.2, 0.3, 0.4, 0.7, 2), right = FALSE,
             labels = c("<0,1", "0,1-0,2", "0,2-0,3", "0,3-0,4", "0,4-0,7", ">=0,7"))
hi <- prob >= 0.4
viz <- logical(st$N_occ)                      # algum minuto a ate 2 passos (sem lacuna) com score >= 0,4
for (lag in 1:2) {
  for (dirn in c(-1, 1)) {
    idx <- seq_len(st$N_occ) + dirn * lag; ok <- idx >= 1 & idx <= st$N_occ
    same <- ok; same[ok] <- site_of[idx[ok]] == site_of[ok]
    # sem lacuna entre os dois minutos
    contig <- same
    for (s in which(same)) {
      r <- sort(c(s, idx[s])); contig[s] <- all(st$adj[(r[1] + 1):r[2]] == 1L)
    }
    viz[contig] <- viz[contig] | hi[idx[contig]]
  }
}
viz <- viz & !hi

p <- read.csv(a[3])
j <- match(paste(p$site, p$time), paste(m$site, format(m$time, "%Y-%m-%d %H:%M:%S"))); stopifnot(!anyNA(j))

# (1) deposito por faixa
k12 <- p$stage == "ct12"; w <- 1 / p$pi1[k12]
haj_faixa <- sapply(levels(faixa), \(f) { s <- faixa[j[k12]] == f; sum(w[s] * p$y[k12][s]) / sum(w) * st$N_occ })
tab1 <- data.frame(faixa = levels(faixa), minutos = as.vector(table(faixa)),
                   canto_modelo = round(tapply(post, faixa, sum)), canto_hajek = round(haj_faixa))
tab1 <- rbind(tab1, data.frame(faixa = "total", minutos = st$N_occ, canto_modelo = round(sum(post)),
                               canto_hajek = round(sum(haj_faixa))))
cat("\n(1) minutos com canto no deposito: posterior do modelo x Hajek\n"); print(tab1, row.names = FALSE)
# referencia pos-estratificada: precisao ponderada em 3 estratos de score
# (< 0,1; 0,1 a 0,4; >= 0,4) vezes o numero de minutos do estrato no
# deposito; bootstrap por sitio-noite
estr <- cut(prob, c(-1, 0.1, 0.4, 2), right = FALSE)
r <- data.frame(y = p$y[k12], w = w, e = estr[j[k12]], noite = paste(p$site, d$night[j])[k12])
Ne <- table(estr)
pstrat <- \(r) { pr <- tapply(r$w * r$y, r$e, sum) / tapply(r$w, r$e, sum); sum(pr * Ne) / st$N_occ }
noites <- split(seq_len(nrow(r)), r$noite)
bps <- withr::with_seed(2026, replicate(2000, pstrat(r[unlist(noites[sample.int(length(noites), replace = TRUE)]), ])))
cat("referencia pos-estratificada:", round(pstrat(r), 4), " bootstrap 90%:",
    round(quantile(bps, c(.05, .5, .95), na.rm = TRUE), 4), " (NA:", sum(is.na(bps)), ")\n")
cat("vizinhos de surto (score < 0,4, ate 2 passos de um >= 0,4):", sum(viz),
    " canto pelo modelo:", round(sum(post[viz])), "\n")

# (2) e (3) leave-one-out nos verificados
loo <- numeric(length(j))
for (r in seq_along(j)) {
  n <- j[r]; i <- site_of[n]; v <- st$v; v[n] <- -1L
  if (p$stage[r] == "ct03") v[n] <- -1L        # ct03 nao entra em v de qualquer forma
  loo[r] <- post_site(i, v)[n - st$first[i] + 1L]
}
res <- data.frame(stage = p$stage, y = p$y, w = 1 / p$pi1, faixa = faixa[j], viz = viz[j], hi = hi[j],
                  post = post[j], loo = loo)
resumo <- function(x, peso = TRUE) {
  ww <- if (peso) x$w else rep(1, nrow(x))
  c(n = nrow(x), pos = sum(x$y), obs = sum(ww * x$y) / sum(ww), pred = sum(ww * x$loo) / sum(ww))
}
r12 <- res[res$stage == "ct12", ]
cat("\n(2) ct12, leave-one-out (media ponderada por 1 / pi1)\n")
print(round(do.call(rbind, c(list(todos = resumo(r12)), lapply(split(r12, r12$faixa), resumo))), 4))
cat("por vizinhanca de surto (score < 0,4):\n")
print(round(do.call(rbind, lapply(split(r12[!r12$hi, ], ifelse(r12$viz[!r12$hi], "vizinho", "longe")), resumo)), 4))
cat("ct12 negativos com loo > 0,5:", sum(r12$y == 0 & r12$loo > 0.5),
    "  positivos com loo < 0,1:", sum(r12$y == 1 & r12$loo < 0.1), "\n")
r03 <- res[res$stage == "ct03", ]
cat("\n(3) ct03 (descritivo, sem pesos; fracao de positivos enviesada pela escolha)\n")
print(round(do.call(rbind, lapply(split(r03, r03$faixa), resumo, peso = FALSE)), 3))
print(round(do.call(rbind, lapply(split(r03[!r03$hi, ], ifelse(r03$viz[!r03$hi], "vizinho", "longe")), resumo, peso = FALSE)), 3))
cat("ct03 negativos com post > 0,5:", sum(r03$y == 0 & r03$loo > 0.5), "de", sum(r03$y == 0), "\n")
if (length(a) > 4) saveRDS(list(post = post, res = res, tab1 = tab1, viz = viz), a[5])
