# Simulacao de vies de psi (21/11/2026; desenho no PLANO, "Simulacao de psi:
# desenho"). Alvo do v1 redefinido: ocupacao por sitio-noite. Pergunta: as
# violacoes das emissoes achadas no Curiango (curiango_teste_emissoes.R)
# enviesam psi?
# Estrutura fixa do Curiango; canto latente do v1 (Markov), com psi, theta e
# rho calibrados; emissoes por faixa (emissions_bins.rds). Cenarios:
#   ind    : faixas independentes dado w (controle);
#   pers   : nos minutos com canto, a faixa repete a do minuto anterior com
#            canto (contiguo) com probabilidade kappa, senao sai de f1 (a
#            marginal continua f1);
#   pers0  : pers, e os minutos sem canto a ate 2 passos de um minuto com
#            canto na faixa >= 0,4 tiram a faixa de f0_surto, a distribuicao
#            ponderada dos negativos do ct12 perto de surto.
# Calibracao (Nelder-Mead, numeros aleatorios comuns) no score >= 0,4 do
# Curiango: taxa, P(y | y anterior), fracao de noites com algum y, fracao de
# minutos altos com vizinho alto, fracao de noites com um unico minuto alto, e
# a prevalencia 0,033 da referencia pos-estratificada.
#   Rscript dev/fase2/sim_psi_curiango.R gerar OUT_DIR FIT_BINS EMIS_BINS [n_por_cenario]
#   (depois: run_curiango_2stage.R em cada OUT_DIR/<cenario>_rNN)
#   Rscript dev/fase2/sim_psi_curiango.R resumo OUT_DIR FIT_BINS [draws]
#   (resumo tambem le os conjuntos de sim_surtos, que guardam dpsi)
source("dev/fase2/emissions_bins_curiango.R")   # curiango_v1, breaks, emis_bins
a <- commandArgs(TRUE); modo <- a[1]; out <- a[2]
d <- curiango_v1("custom", c_lo = qlogis(0.1)); st <- d$stan; m <- d$minutes
N <- st$N_occ
len <- st$last - st$first + 1L
site <- rep(seq_len(st$N_site), len); pos <- sequence(len)
adj <- st$adj == 1L
idx_pos <- split(seq_len(N), pos)
nb <- length(breaks) - 1L
noite <- paste(m$site, d$night)
run <- cumsum(!adj)
fit0 <- readRDS(a[3]); med <- setNames(fit0$summary$median, fit0$summary$variable)
lpsi0 <- drop(st$X %*% med[grep("^beta\\[", names(med))])
eta0 <- drop(st$D %*% med[grep("^alpha\\[", names(med))])
estr_of <- \(b) c(1L, 2L, 2L, 2L, 3L)[b]
pstrat <- function(y, w, e, Ne) {
  pr <- tapply(w * y, factor(e, 1:3), sum) / tapply(w, factor(e, 1:3), sum)
  sum(pr * Ne, na.rm = TRUE) / sum(Ne)
}
# vizinho a ate K passos (mesmo run contiguo) com a propriedade x
near <- function(x, K) {
  v <- logical(N)
  for (lag in seq_len(K)) for (dd in c(-1L, 1L)) {
    i <- seq_len(N) + dd * lag; ok <- i >= 1 & i <= N
    ok[ok] <- run[i[ok]] == run[ok]
    v[ok] <- v[ok] | x[i[ok]]
  }
  v
}
stats_y <- function(b) {
  y <- b == nb
  prev <- c(FALSE, y[-N])
  per <- tabulate(site[y], st$N_site)
  c(y_rate = mean(y), p_y_prev = sum(y[adj] & prev[adj]) / max(sum(prev[adj]), 1),
    nights_any = mean(per > 0), hi_viz = mean(near(y, 1L)[y]), nights_one = mean(per == 1L))
}

if (modo == "gerar") {
  nper <- if (length(a) > 4) as.integer(a[5]) else 8L
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  em <- readRDS(a[4])
  # negativos do ct12 perto de surto (K = 2), distribuicao ponderada por faixa
  # (curiango_teste_emissoes.R): 0,215; 0,646; 0,139; 0; 0. Um pouco de massa
  # em 0,3-0,4 para nao zerar a faixa.
  f0_surto <- c(0.215, 0.640, 0.135, 0.010, 0)
  sim_w <- function(par) {
    z <- rbinom(st$N_site, 1, plogis(lpsi0 + par[["dpsi"]]))
    eta <- eta0 + par[["c"]]
    w <- integer(N)
    for (j in seq_along(idx_pos)) {
      k <- idx_pos[[j]]
      prevw <- if (j == 1L) 0L else ifelse(adj[k], w[k - 1L], 0L)
      w[k] <- as.integer(z[site[k]] == 1L & runif(length(k)) < plogis(eta[k] + par[["rho"]] * prevw))
    }
    list(w = w, z = z)
  }
  sim_b <- function(w, type, par) {
    b <- ifelse(w == 1L, sample.int(nb, N, TRUE, em$f1), sample.int(nb, N, TRUE, em$f0))
    if (type %in% c("pers", "pers0")) {
      rep_ <- runif(N) < par[["kappa"]]
      for (j in seq_along(idx_pos)[-1]) {
        k <- idx_pos[[j]]
        kk <- k[w[k] == 1L & adj[k] & w[pmax(k - 1L, 1L)] == 1L & rep_[k]]
        b[kk] <- b[kk - 1L]
      }
    }
    if (type == "pers0") {
      s0 <- which(w == 0L & near(w == 1L & b == nb, 2L))
      b[s0] <- sample.int(nb, length(s0), TRUE, f0_surto)
    }
    b
  }
  natpar <- function(type, q) c(dpsi = q[1], c = q[2], rho = q[3],
                                kappa = if (type == "ind") 0 else plogis(q[4]))
  prob <- ifelse(st$cens == 1L, 0, plogis(st$s)); prob[st$cens == 2L] <- 1
  obs <- stats_y(as.integer(cut(prob, breaks, right = FALSE)))
  tgt <- c(obs, prev = 0.0327)
  sim_stats <- function(type, par, seed) withr::with_seed(seed, {
    s <- sim_w(par); c(stats_y(sim_b(s$w, type, par)), prev = mean(s$w))
  })
  loss <- function(q, type) {
    s <- rowMeans(sapply(1:3, \(r) sim_stats(type, natpar(type, q), 900 + r)))
    sum((log(s[names(tgt)]) - log(tgt))^2)
  }
  start <- list(ind = c(0, 0, med[["rho[1]"]]), pers = c(0, 0, 2, 1), pers0 = c(0, 0, 2, 1))
  cal <- lapply(names(start), \(type) {
    o <- optim(start[[type]], loss, type = type, method = "Nelder-Mead",
               control = list(maxit = 250, reltol = 1e-6))
    par <- natpar(type, o$par)
    s <- rowMeans(sapply(1:10, \(r) sim_stats(type, par, 950 + r)))
    list(type = type, par = par, loss = o$value, conv = o$convergence, stats = s)
  })
  names(cal) <- names(start)
  tab <- rbind(observado = tgt, do.call(rbind, lapply(cal, \(x) x$stats)))
  cat("\nCalibracao (media de 10 simulacoes; prev do observado = referencia pos-estratificada)\n")
  print(round(tab, 4))
  for (x in cal) cat(x$type, ": ", paste(names(x$par), round(x$par, 3), sep = " = ", collapse = ", "),
                     "  perda:", round(x$loss, 4), " conv:", x$conv, "\n")

  n12 <- c(439L, 460L, 32L, 9L, 20L); n03 <- c(0L, 43L, 28L, 16L, 152L)
  ids <- c(ind = 6, pers = 7, pers0 = 8)
  for (type in names(cal)) for (r in seq_len(nper)) withr::with_seed(2026 + 1000 * ids[[type]] + r, {
    par <- cal[[type]]$par
    s <- sim_w(par); w <- s$w; b <- sim_b(w, type, par)
    Nb <- tabulate(b, nb)
    lab12 <- logical(N); lab03 <- logical(N); wt <- rep(1, N)
    for (bb in seq_len(nb)) {
      cand <- which(b == bb)
      k <- cand[sample.int(length(cand), min(n12[bb], length(cand)))]
      lab12[k] <- TRUE; wt[k] <- Nb[bb] / length(k)
      if (n03[bb] > 0L) {
        c3 <- cand[!lab12[cand]]
        k3 <- c3[sample.int(length(c3), min(n03[bb], length(c3)), prob = ifelse(w[c3] == 1L, 30, 1))]
        lab03[k3] <- TRUE
      }
    }
    y <- rep(NA_integer_, N); y[lab12] <- w[lab12]
    e <- emis_bins(b, lab12, y, wt)
    e$v <- ifelse(lab12 | lab03, w, -1L)
    es <- estr_of(b); Ne <- tabulate(es, 3); k12 <- which(lab12)
    e$truth <- list(scenario = type, par = par, prev = mean(w), stats = stats_y(b),
                    psi_bar = mean(plogis(lpsi0 + par[["dpsi"]])), z_bar = mean(s$z),
                    ref = pstrat(w[k12], wt[k12], es[k12], Ne))
    dd <- file.path(out, sprintf("%s_r%02d", type, r))
    dir.create(dd, showWarnings = FALSE)
    saveRDS(e, file.path(dd, "emissions.rds"))
    cat(basename(dd), " psi_bar:", round(e$truth$psi_bar, 3), " z_bar:", round(mean(s$z), 3),
        " prev:", round(mean(w), 4), " f1>=0,4:", round(e$f1[nb], 3), "\n")
  })
  saveRDS(list(obs = obs, tgt = tgt, cal = cal, tab = tab), file.path(out, "calibracao.rds"))
}

if (modo == "resumo") {
  nd <- if (length(a) > 3) as.integer(a[4]) else 1000L
  ds <- sort(Sys.glob(file.path(out, "*_r*")))
  res <- do.call(rbind, lapply(ds, \(dd) {
    f <- Sys.glob(file.path(dd, "fit_2stage_*.rds")); if (!length(f)) return(NULL)
    x <- readRDS(f[1]); tr <- readRDS(file.path(dd, "emissions.rds"))$truth
    dr <- x$draws[round(seq(1, nrow(x$draws), length.out = nd)), , drop = FALSE]
    pb <- colMeans(plogis(st$X %*% t(dr[, grep("^beta\\[", colnames(dr)), drop = FALSE])))
    q <- quantile(pb, c(.05, .5, .95))
    psi_true <- if (!is.null(tr$psi_bar)) tr$psi_bar else mean(plogis(lpsi0 + tr$par[["dpsi"]]))
    data.frame(conjunto = basename(dd), cenario = tr$scenario, psi = psi_true,
               mod_med = q[[2]], mod_lo = q[[1]], mod_hi = q[[3]],
               div = sum(x$diag$num_divergent), rhat = max(x$summary$rhat),
               ess = min(x$summary$ess_bulk))
  }))
  res$vies <- res$mod_med / res$psi - 1
  res$vies_abs <- res$mod_med - res$psi
  res$cob <- res$mod_lo <= res$psi & res$psi <= res$mod_hi
  print(res, digits = 3, row.names = FALSE)
  cat("\nPor cenario (psi medio sobre sitio-noites; vies da mediana; cobertura de 90%)\n")
  print(aggregate(cbind(psi, vies_abs, vies, cob, div, rhat) ~ cenario, res, \(x) round(mean(x), 3)))
  saveRDS(res, file.path(out, "resumo_psi.rds"))
}
