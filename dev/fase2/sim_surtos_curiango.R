# Simulacao com surtos (21/11/2026; desenho no PLANO, "Simulacao com surtos:
# desenho"). Pergunta: o excesso de ~+40% do v1 no Curiango vem do
# procedimento em dois estagios ou de estrutura latente que o v1 nao tem?
# Estrutura fixa do Curiango (sitio-noites, passos, lacunas, covariaveis);
# emissoes verdadeiras = estagio 1 por faixas, a faixa de cada minuto
# sorteada de f1 ou f0 dado w. Cenarios:
#   v1   : o proprio v1, medianas de bins_m1 (controle do procedimento);
#   het  : Markov com rho_i = rho_bar + sigma u_i por sitio-noite, sigma = 2;
#   semi : surtos de duracao 1 + Poisson(L - 1) passos e pelo menos um passo
#          sem canto entre surtos.
# het e semi (e o v1, so como diagnostico) sao calibrados para reproduzir no
# score >= 0,4 do Curiango a taxa, P(y | y anterior), a fracao de noites com
# algum y, e a prevalencia 0,033 da referencia pos-estratificada.
#   het2 : como het, com sigma livre; hett: rho comum e efeito de sitio-noite
#          em theta, N(0, sigma); os dois calibrados tambem na variancia de y
#          por noite (adicionados depois da primeira calibracao).
#   Rscript dev/fase2/sim_surtos_curiango.R gerar OUT_DIR PI_CSV FIT_BINS EMIS_BINS [n_por_cenario] [cenarios,separados,por,virgula]
#   (depois: run_curiango_2stage.R em cada OUT_DIR/<cenario>_rNN)
#   Rscript dev/fase2/sim_surtos_curiango.R resumo OUT_DIR [draws]
source("dev/fase2/emissions_bins_curiango.R")   # curiango_v1, breaks, emis_bins
a <- commandArgs(TRUE); modo <- a[1]; out <- a[2]
d <- curiango_v1("custom", c_lo = qlogis(0.1)); st <- d$stan; m <- d$minutes
N <- st$N_occ
len <- st$last - st$first + 1L
site <- rep(seq_len(st$N_site), len); pos <- sequence(len)
adj <- st$adj == 1L
idx_pos <- split(seq_len(N), pos)            # minutos na posicao j de cada sitio-noite
nb <- length(breaks) - 1L
noite <- paste(m$site, d$night)

# prevalencia marginal do modelo: media sobre minutos de psi_i * P(w = 1 | z = 1),
# recursao de Markov sem emissoes (como em curiango_prevalencia_marginal.R),
# vetorizada por posicao
prev_marg <- function(dr) {
  B <- dr[, grep("^beta\\[", colnames(dr)), drop = FALSE]
  A <- dr[, grep("^alpha\\[", colnames(dr)), drop = FALSE]
  rho <- dr[, "rho[1]"]; nd <- nrow(dr)
  psi <- plogis(st$X %*% t(B))
  soma <- numeric(nd); p1 <- NULL
  for (j in seq_along(idx_pos)) {
    k <- idx_pos[[j]]
    e <- st$D[k, , drop = FALSE] %*% t(A)
    pe <- plogis(e)
    if (j == 1L) p1 <- pe else {
      pp <- p1[match(k - 1L, idx_pos[[j - 1L]]), , drop = FALSE]
      per <- plogis(e + matrix(rho, length(k), nd, byrow = TRUE))
      ct <- adj[k]
      p1 <- pe
      p1[ct, ] <- pp[ct, , drop = FALSE] * per[ct, , drop = FALSE] +
        (1 - pp[ct, , drop = FALSE]) * pe[ct, , drop = FALSE]
    }
    soma <- soma + colSums(psi[site[k], , drop = FALSE] * p1)
  }
  soma / N
}

# referencia pos-estratificada (< 0,1; 0,1 a 0,4; >= 0,4) e seu bootstrap por noite
estr_of <- \(b) c(1L, 2L, 2L, 2L, 3L)[b]
pstrat <- function(y, w, e, Ne) {
  pr <- tapply(w * y, factor(e, 1:3), sum) / tapply(w, factor(e, 1:3), sum)
  sum(pr * Ne, na.rm = TRUE) / sum(Ne)
}

if (modo == "gerar") {
  nper <- if (length(a) > 5) as.integer(a[6]) else 8L
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  em <- readRDS(a[5])
  fit <- readRDS(a[4]); med <- setNames(fit$summary$median, fit$summary$variable)
  lpsi0 <- drop(st$X %*% med[grep("^beta\\[", names(med))])
  eta0 <- drop(st$D %*% med[grep("^alpha\\[", names(med))])

  sim_w <- function(type, par) {
    z <- rbinom(st$N_site, 1, plogis(lpsi0 + par[["dpsi"]]))
    eta <- eta0 + par[["c"]]
    w <- integer(N); rem <- integer(N)
    rho_i <- switch(type, v1 = , hett = rep(par[["rho"]], st$N_site),
                    het = , het2 = par[["rho"]] + par[["sigma"]] * rnorm(st$N_site), semi = NULL)
    if (type == "hett") eta <- eta + (par[["sigma"]] * rnorm(st$N_site))[site]
    for (j in seq_along(idx_pos)) {
      k <- idx_pos[[j]]; zk <- z[site[k]] == 1L
      ct <- if (j == 1L) rep(FALSE, length(k)) else adj[k]
      prevw <- ifelse(ct, w[pmax(k - 1L, 1L)], 0L)
      if (type != "semi") {
        w[k] <- as.integer(zk & runif(length(k)) < plogis(eta[k] + rho_i[site[k]] * prevw))
      } else {
        prevrem <- ifelse(ct, rem[pmax(k - 1L, 1L)], 0L)
        cont <- prevw == 1L & prevrem > 0L
        start <- !cont & prevw == 0L & zk & runif(length(k)) < plogis(eta[k])
        w[k] <- as.integer(cont | start)
        rem[k] <- ifelse(cont, prevrem - 1L, ifelse(start, rpois(length(k), par[["L"]] - 1), 0L))
      }
    }
    w
  }
  sim_b <- \(w) ifelse(w == 1L, sample.int(nb, N, TRUE, em$f1), sample.int(nb, N, TRUE, em$f0))
  stats_y <- function(b) {
    y <- as.integer(b == nb)
    prev <- c(0L, y[-N])
    per <- tabulate(site[y == 1L], st$N_site)
    c(y_rate = mean(y), p_y_prev = sum(y[adj] * prev[adj]) / max(sum(prev[adj]), 1),
      nights_any = mean(per > 0), var_night = var(per))
  }

  # observado
  prob <- ifelse(st$cens == 1L, 0, plogis(st$s)); prob[st$cens == 2L] <- 1
  b_obs <- as.integer(cut(prob, breaks, right = FALSE))
  obs <- stats_y(b_obs)
  tgt <- c(obs[c("y_rate", "p_y_prev", "nights_any")], prev = 0.0327)

  # calibracao (numeros aleatorios comuns: 3 sementes fixas)
  natpar <- function(type, q) switch(type,
    v1 = c(dpsi = q[1], c = q[2], rho = q[3]),
    het = c(dpsi = q[1], c = q[2], rho = q[3], sigma = 2),
    het2 = , hett = c(dpsi = q[1], c = q[2], rho = q[3], sigma = exp(q[4])),
    semi = c(dpsi = q[1], c = q[2], L = 1 + exp(q[3])))
  sim_stats <- function(type, par, seed) withr::with_seed(seed, {
    w <- sim_w(type, par); c(stats_y(sim_b(w)), prev = mean(w))
  })
  # het2 e hett (adicionados depois da primeira calibracao, antes dos ajustes:
  # nenhum dos geradores originais reproduzia a variancia entre noites) tem
  # sigma livre e a variancia por noite tambem como alvo
  tgt5 <- c(tgt, var_night = obs[["var_night"]])
  loss <- function(q, type) {
    tg <- if (type %in% c("het2", "hett")) tgt5 else tgt
    s <- rowMeans(sapply(1:3, \(r) sim_stats(type, natpar(type, q), 900 + r)))
    sum((log(s[names(tg)]) - log(tg))^2)
  }
  start <- list(v1 = c(0, 0, med[["rho[1]"]]), het = c(0, 0, med[["rho[1]"]]), semi = c(0, 0, log(3)),
                het2 = c(0.6, -0.8, med[["rho[1]"]], log(2)), hett = c(0, -0.5, med[["rho[1]"]], log(1)))
  cal <- lapply(names(start), \(type) {
    o <- optim(start[[type]], loss, type = type, method = "Nelder-Mead",
               control = list(maxit = 200, reltol = 1e-6))
    par <- natpar(type, o$par)
    s <- rowMeans(sapply(1:10, \(r) sim_stats(type, par, 950 + r)))
    list(type = type, par = par, loss = o$value, conv = o$convergence, stats = s)
  })
  names(cal) <- names(start)
  par_v1 <- c(dpsi = 0, c = 0, rho = med[["rho[1]"]])
  s_v1 <- rowMeans(sapply(1:10, \(r) sim_stats("v1", par_v1, 950 + r)))
  tab <- rbind(observado = c(obs, prev = 0.0327), v1_bins_m1 = s_v1,
               do.call(rbind, lapply(cal, \(x) x$stats)))
  rownames(tab)[-(1:2)] <- paste0(names(cal), "_calibrado")
  cat("\nCalibracao (media de 10 simulacoes; prev do observado = referencia pos-estratificada)\n")
  print(round(tab, 4))
  for (x in cal) cat(x$type, ": ", paste(names(x$par), round(x$par, 3), sep = " = ", collapse = ", "),
                     "  perda:", round(x$loss, 4), " conv:", x$conv, "\n")

  # conjuntos
  n12 <- c(439L, 460L, 32L, 9L, 20L); n03 <- c(0L, 43L, 28L, 16L, 152L)
  cen <- list(v1 = list(type = "v1", par = par_v1),
              het = list(type = "het", par = cal$het$par),
              semi = list(type = "semi", par = cal$semi$par),
              het2 = list(type = "het2", par = cal$het2$par),
              hett = list(type = "hett", par = cal$hett$par))
  so <- if (length(a) > 6) strsplit(a[7], ",")[[1]] else names(cen)
  cen <- cen[so]
  ids <- c(v1 = 1, het = 2, semi = 3, het2 = 4, hett = 5)
  for (si in seq_along(cen)) for (r in seq_len(nper)) withr::with_seed(2026 + 1000 * ids[[names(cen)[si]]] + r, {
    cc <- cen[[si]]
    w <- sim_w(cc$type, cc$par); b <- sim_b(w)
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
    es <- estr_of(b); Ne <- tabulate(es, 3)
    k12 <- which(lab12)
    ref <- pstrat(w[k12], wt[k12], es[k12], Ne)
    g <- split(seq_along(k12), noite[k12])
    rb <- replicate(500, { kk <- unlist(g[sample.int(length(g), replace = TRUE)], use.names = FALSE)
                           pstrat(w[k12][kk], wt[k12][kk], es[k12][kk], Ne) })
    e$truth <- list(scenario = names(cen)[si], par = cc$par, prev = mean(w), stats = stats_y(b),
                    ref = ref, ref_ci = quantile(rb, c(.05, .95), na.rm = TRUE),
                    n_pos12 = sum(w[k12]), n_pos03 = sum(w[lab03]))
    dd <- file.path(out, sprintf("%s_r%02d", names(cen)[si], r))
    dir.create(dd, showWarnings = FALSE)
    saveRDS(e, file.path(dd, "emissions.rds"))
    cat(basename(dd), " prev:", round(mean(w), 4), " ref:", round(ref, 4),
        " pos ct12:", sum(w[k12]), " pos ct03:", sum(w[lab03]), "/", sum(lab03),
        " f1>=0,4:", round(e$f1[nb], 3), "\n")
  })
  saveRDS(list(obs = obs, tgt = tgt, cal = cal, tab = tab), file.path(out, "calibracao.rds"))
}

if (modo == "resumo") {
  nd <- if (length(a) > 2) as.integer(a[3]) else 400L
  ds <- sort(Sys.glob(file.path(out, "*_r*")))
  res <- do.call(rbind, lapply(ds, \(dd) {
    f <- Sys.glob(file.path(dd, "fit_2stage_*.rds")); if (!length(f)) return(NULL)
    x <- readRDS(f[1]); tr <- readRDS(file.path(dd, "emissions.rds"))$truth
    dr <- x$draws[round(seq(1, nrow(x$draws), length.out = nd)), , drop = FALSE]
    pm <- prev_marg(dr); q <- quantile(pm, c(.05, .5, .95))
    data.frame(conjunto = basename(dd), cenario = tr$scenario, verdade = tr$prev,
               mod_med = q[[2]], mod_lo = q[[1]], mod_hi = q[[3]],
               ref = tr$ref, ref_lo = tr$ref_ci[[1]], ref_hi = tr$ref_ci[[2]],
               div = sum(x$diag$num_divergent), rhat = max(x$summary$rhat),
               ess = min(x$summary$ess_bulk), rho = x$summary$median[x$summary$variable == "rho[1]"])
  }))
  res$vies_mod <- res$mod_med / res$verdade - 1
  res$cob_mod <- res$mod_lo <= res$verdade & res$verdade <= res$mod_hi
  res$vies_ref <- res$ref / res$verdade - 1
  res$cob_ref <- res$ref_lo <= res$verdade & res$verdade <= res$ref_hi
  print(res, digits = 3, row.names = FALSE)
  cat("\nPor cenario (vies relativo da mediana; cobertura de 90%)\n")
  print(aggregate(cbind(vies_mod, cob_mod, vies_ref, cob_ref, div, rhat) ~ cenario, res,
                  \(x) round(mean(x), 3)))
  saveRDS(res, file.path(out, "resumo.rds"))
}
