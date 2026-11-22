# Gerador da simulacao de psi (sim_psi_curiango.R e run_simpsi_boot.R).
# Tudo depende de S, uma lista com a estrutura do Curiango e os parametros
# fixos, montada por simpsi_setup(); assim o gerador roda na AWS sem o crywolf.
simpsi_setup <- function(st, noite, lpsi0, eta0, f0, f1, breaks) {
  N <- st$N_occ; len <- st$last - st$first + 1L; adj <- st$adj == 1L
  list(st = st, noite = noite, lpsi0 = lpsi0, eta0 = eta0, f0 = f0, f1 = f1, breaks = breaks,
       N = N, site = rep(seq_len(st$N_site), len), adj = adj,
       idx_pos = split(seq_len(N), sequence(len)), run = cumsum(!adj), nb = length(breaks) - 1L,
       # negativos do ct12 perto de surto (curiango_teste_emissoes.R, K = 2),
       # com um pouco de massa em 0,3-0,4
       f0_surto = c(0.215, 0.640, 0.135, 0.010, 0),
       n12 = c(439L, 460L, 32L, 9L, 20L), n03 = c(0L, 43L, 28L, 16L, 152L),
       ids = c(ind = 6, pers = 7, pers0 = 8))
}
simpsi_near <- function(S, x, K) {
  v <- logical(S$N)
  for (lag in seq_len(K)) for (dd in c(-1L, 1L)) {
    i <- seq_len(S$N) + dd * lag; ok <- i >= 1 & i <= S$N
    ok[ok] <- S$run[i[ok]] == S$run[ok]
    v[ok] <- v[ok] | x[i[ok]]
  }
  v
}
simpsi_stats <- function(S, b) {
  y <- b == S$nb; N <- S$N
  prev <- c(FALSE, y[-N])
  per <- tabulate(S$site[y], S$st$N_site)
  c(y_rate = mean(y), p_y_prev = sum(y[S$adj] & prev[S$adj]) / max(sum(prev[S$adj]), 1),
    nights_any = mean(per > 0), hi_viz = mean(simpsi_near(S, y, 1L)[y]), nights_one = mean(per == 1L))
}
simpsi_w <- function(S, par) {
  z <- rbinom(S$st$N_site, 1, plogis(S$lpsi0 + par[["dpsi"]]))
  eta <- S$eta0 + par[["c"]]
  w <- integer(S$N)
  for (j in seq_along(S$idx_pos)) {
    k <- S$idx_pos[[j]]
    prevw <- if (j == 1L) 0L else ifelse(S$adj[k], w[k - 1L], 0L)
    w[k] <- as.integer(z[S$site[k]] == 1L & runif(length(k)) < plogis(eta[k] + par[["rho"]] * prevw))
  }
  list(w = w, z = z)
}
simpsi_b <- function(S, w, type, par) {
  N <- S$N; nb <- S$nb
  b <- ifelse(w == 1L, sample.int(nb, N, TRUE, S$f1), sample.int(nb, N, TRUE, S$f0))
  if (type %in% c("pers", "pers0")) {
    rep_ <- runif(N) < par[["kappa"]]
    for (j in seq_along(S$idx_pos)[-1]) {
      k <- S$idx_pos[[j]]
      kk <- k[w[k] == 1L & S$adj[k] & w[pmax(k - 1L, 1L)] == 1L & rep_[k]]
      b[kk] <- b[kk - 1L]
    }
  }
  if (type == "pers0") {
    s0 <- which(w == 0L & simpsi_near(S, w == 1L & b == nb, 2L))
    b[s0] <- sample.int(nb, length(s0), TRUE, S$f0_surto)
  }
  b
}
# um conjunto completo (com a semente de sim_psi_curiango.R): canto, faixas e
# rotulos (ct12 estratificado por faixa com pesos N_b / n_b; ct03 com chance
# 30:1 para canto)
simpsi_set <- function(S, type, par, r) withr::with_seed(2026 + 1000 * S$ids[[type]] + r, {
  s <- simpsi_w(S, par); w <- s$w; b <- simpsi_b(S, w, type, par)
  N <- S$N; nb <- S$nb
  Nb <- tabulate(b, nb)
  lab12 <- logical(N); lab03 <- logical(N); wt <- rep(1, N)
  for (bb in seq_len(nb)) {
    cand <- which(b == bb)
    k <- cand[sample.int(length(cand), min(S$n12[bb], length(cand)))]
    lab12[k] <- TRUE; wt[k] <- Nb[bb] / length(k)
    if (S$n03[bb] > 0L) {
      c3 <- cand[!lab12[cand]]
      k3 <- c3[sample.int(length(c3), min(S$n03[bb], length(c3)), prob = ifelse(w[c3] == 1L, 30, 1))]
      lab03[k3] <- TRUE
    }
  }
  list(w = w, z = s$z, b = b, lab12 = lab12, lab03 = lab03, wt = wt)
})
