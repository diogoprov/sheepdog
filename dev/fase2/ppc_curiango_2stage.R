# Posterior predictive checks of the two-stage v1 on the Curiango, with the same
# statistics as ppc_curiango_v0.R (dependence between minutes, detections per
# night, scores by class). Stage 1 emissions are fixed at their point estimates.
# With a night random effect, `new` draws fresh night effects from N(0, sigma)
# (marginal replication); `same` keeps the posterior effects of each night.
# Also takes fits of model_v1_3state.stan (persistent f1 components).
#   Rscript dev/fase2/ppc_curiango_2stage.R FIT_FILE [N_DRAWS] [same|new]
source("dev/fase2/curiango_v1.R")
a <- commandArgs(TRUE); f <- readRDS(a[1]); nd <- if (length(a) > 1) as.integer(a[2]) else 200L
mode <- if (length(a) > 2) a[3] else "new"
d <- curiango_v1("custom", c_lo = qlogis(0.1)); st <- d$stan
nights <- d$night[st$first]
night <- match(nights, sort(unique(nights)))
len <- st$last - st$first + 1L
site <- rep(seq_len(st$N_site), len)
pos <- sequence(len)
adj <- st$adj == 1L
cut40 <- qlogis(0.4)
stats <- function(s, cens, w_ver) {
  y <- as.integer(cens != 1L & s >= cut40)
  prev <- c(0L, y[-length(y)])
  per <- tabulate(site[y == 1L], st$N_site)
  v <- st$v >= 0L
  q <- \(x) if (length(x) > 1) quantile(x, c(.1, .5, .9), names = FALSE) else rep(NA, 3)
  u <- cens == 0L
  c(all_cens = mean(cens == 1L), all = q(s[u]), y_rate = mean(y),
    p_y_given_prev = sum(y[adj] * prev[adj]) / max(sum(prev[adj]), 1),
    nights_any = mean(per > 0), var_per_night = var(per),
    f_cens = mean(cens[v & w_ver == 0L] == 1L), f = q(s[v & w_ver == 0L & u]),
    t_cens = mean(cens[v & w_ver == 1L] == 1L), t = q(s[v & w_ver == 1L & u]))
}
remix <- function(n, p) {
  low <- runif(n) < p[["pi"]]
  rnorm(n, ifelse(low, p[["mu_a"]], p[["mu_b"]]), ifelse(low, p[["sd_a"]], p[["sd_b"]]))
}
obs <- stats(st$s, st$cens, st$v)
dr <- f$draws; idx <- round(seq(1, nrow(dr), length.out = nd)); set.seed(2026)
three <- "xi" %in% colnames(dr)
rho_col <- "rho[1]" %in% colnames(dr)
re <- "sigma_night[1]" %in% colnames(dr)
rep <- vapply(idx, \(i) {
  g <- \(n) as.numeric(dr[i, n])
  psi <- plogis(drop(st$X %*% g(paste0("beta[", seq_len(st$P_psi), "]"))))
  eta <- drop(st$D %*% g(paste0("alpha[", seq_len(st$P_theta), "]")))
  rho <- if (three && "rho" %in% colnames(dr)) g("rho") else if (rho_col) g("rho[1]") else 0
  rho_l <- if ("rho[2]" %in% colnames(dr)) g("rho[2]") else rho
  if (re) {
    nn <- max(night)
    u <- if (mode == "same") g(paste0("u_night[", seq_len(nn), "]")) else rnorm(nn)
    eta <- eta + (g("sigma_night[1]") * u[night])[site]
  }
  z <- rbinom(st$N_site, 1, psi)[site]
  u <- runif(st$N_occ)
  w <- integer(st$N_occ)
  hc <- integer(st$N_occ)  # 1 when a call is in the high component of f1
  u2 <- runif(st$N_occ)
  for (j in seq_len(max(len))) {
    k <- which(pos == j)
    prev <- if (j == 1L) 0L else ifelse(adj[k], w[k - 1L], 0L)
    r <- if (three && j > 1L) ifelse(hc[k - 1L] == 1L, rho, rho_l) else rho
    w[k] <- as.integer(z[k] == 1L & u[k] < plogis(eta[k] + r * prev))
    if (three) {
      ph <- if (j == 1L) rep(g("p_h"), length(k)) else
        ifelse(prev == 1L, ifelse(hc[k - 1L] == 1L, g("p_hh"), g("p_hl")), g("p_h"))
      hc[k] <- as.integer(w[k] == 1L & u2[k] < ph)
    }
  }
  s <- if (three) {
    f1 <- f$emissions$f1
    ifelse(w == 0L, remix(st$N_occ, f$emissions$f0),
           ifelse(hc == 1L, rnorm(st$N_occ, f1[["mu_b"]], f1[["sd_b"]]),
                  rnorm(st$N_occ, f1[["mu_a"]], f1[["sd_a"]])))
  } else ifelse(w == 1L, remix(st$N_occ, f$emissions$f1), remix(st$N_occ, f$emissions$f0))
  cens <- ifelse(s < st$c_lo, 1L, ifelse(s > st$c_hi, 2L, 0L))
  stats(s, cens, w)
}, obs)
out <- data.frame(stat = names(obs), obs = obs, lo = apply(rep, 1, quantile, .025, na.rm = TRUE),
                  med = apply(rep, 1, median, na.rm = TRUE),
                  hi = apply(rep, 1, quantile, .975, na.rm = TRUE), row.names = NULL)
out$inside <- out$lo <= out$obs & out$obs <= out$hi
print(out, digits = 3)
saveRDS(out, sub("fit_", if (re) paste0("ppc_", mode, "_") else "ppc_", a[1]))
