# Posterior predictive checks of the baseline v0 on the Curiango data: scores by
# class on the verified minutes, all scores, and dependence between minutes.
#   Rscript dev/fase2/ppc_curiango_v0.R FIT_FILE [N_DRAWS]
source("dev/fase2/curiango_v0.R")
a <- commandArgs(TRUE); f <- readRDS(a[1]); nd <- if (length(a) > 1) as.integer(a[2]) else 200L
d <- curiango_v0(f$classifier, c_lo = qlogis(f$c)); st <- d$stan
site <- rep(seq_len(st$N_site), st$last - st$first + 1L)
t <- as.numeric(d$minutes$time) / 60
adj <- c(FALSE, diff(t) == 15 & diff(site) == 0)   # minute k follows k - 1 by 15 min
cut40 <- qlogis(0.4)
stats <- function(s, cens, w_ver) {
  # s on the logit scale, with censored values below c_lo
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
obs <- stats(st$s, st$cens, st$v)
dr <- f$draws; idx <- round(seq(1, nrow(dr), length.out = nd)); set.seed(2026)
rep <- vapply(idx, \(i) {
  g <- \(n) as.numeric(dr[i, n])
  psi <- plogis(drop(st$X %*% g(c("beta[1]", "beta[2]", "beta[3]"))))
  th <- plogis(drop(st$D %*% g(c("alpha[1]", "alpha[2]", "alpha[3]"))))
  z <- rbinom(st$N_site, 1, psi)
  w <- rbinom(st$N_occ, 1, z[site] * th)
  s <- rnorm(st$N_occ, g("lambda0") + w * g("delta"), ifelse(w == 1, g("sigma1"), g("sigma0")))
  cens <- ifelse(s < st$c_lo, 1L, ifelse(s > st$c_hi, 2L, 0L))
  stats(s, cens, w)
}, obs)
out <- data.frame(stat = names(obs), obs = obs, lo = apply(rep, 1, quantile, .025, na.rm = TRUE),
                  med = apply(rep, 1, median, na.rm = TRUE),
                  hi = apply(rep, 1, quantile, .975, na.rm = TRUE), row.names = NULL)
out$inside <- out$lo <= out$obs & out$obs <= out$hi
print(out, digits = 3)
saveRDS(out, sub("fit_", "ppc_", a[1]))
