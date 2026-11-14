# Two-stage emissions, stage 1: f0 and f1 (two-normal mixtures, censored at
# c_lo and c_hi) fitted only on the verified minutes, weighted by the inverse
# of the inclusion rate in three strata of the custom score, as in
# emissions_weighted_curiango.R (provisional: the inclusion mechanism is not
# known and also depends on hour and site). Bootstrap over nights for the
# spread of the estimates. Returns the per-minute log densities for stage 2.
#   Rscript dev/fase2/emissions_2stage_curiango.R OUT_FILE [n_boot]
source("dev/fase2/curiango_v1.R")
emis_2stage <- function(d, n_boot = 0L, seed = 2026L) {
  st <- d$stan; m <- d$minutes
  ver <- st$v >= 0L
  stratum <- cut(m$conf_custom, c(-1, 0.3, 0.5, 1), right = FALSE)
  rate <- tapply(ver, stratum, mean)
  w <- as.numeric(1 / rate[stratum])
  one <- function(s, cens, mu, sd) ifelse(cens == 0L, dnorm(s, mu, sd),
    ifelse(cens == 1L, pnorm(st$c_lo, mu, sd), pnorm(st$c_hi, mu, sd, lower.tail = FALSE)))
  # p = (logit weight of component a, mean a, log sd a, log gap to mean b, log sd b)
  dens <- function(p, s, cens) plogis(p[1]) * one(s, cens, p[2], exp(p[3])) +
    (1 - plogis(p[1])) * one(s, cens, p[2] + exp(p[4]), exp(p[5]))
  fit <- function(k) {
    s <- st$s[k]; ce <- st$cens[k]; wk <- w[k]
    q <- quantile(s[ce == 0L], c(.25, .75), names = FALSE)
    starts <- list(c(0, q[1], -0.5, log(max(q[2] - q[1], .5)), 0),
                   c(1, q[1] - 0.5, -1, log(2), 0.3), c(2, q[1], -1.5, 0, -0.5))
    fs <- lapply(starts, \(p0) optim(p0, \(p) -sum(wk * log(pmax(dens(p, s, ce), 1e-300))),
                                     method = "BFGS", control = list(maxit = 1000)))
    fs[[which.min(vapply(fs, `[[`, 0, "value"))]]$par
  }
  nat <- \(p) c(pi = plogis(p[1]), mu_a = p[2], sd_a = exp(p[3]),
                mu_b = p[2] + exp(p[4]), sd_b = exp(p[5]))
  p0 <- fit(ver & st$v == 0L); p1 <- fit(ver & st$v == 1L)
  boot <- NULL
  if (n_boot > 0L) {
    set.seed(seed)
    nights <- unique(d$night[ver])
    boot <- do.call(rbind, lapply(seq_len(n_boot), \(b) {
      take <- sample(nights, replace = TRUE)
      idx <- unlist(lapply(take, \(n) which(ver & d$night == n)))
      k0 <- idx[st$v[idx] == 0L]; k1 <- idx[st$v[idx] == 1L]
      # fit() takes a logical or an index vector
      rbind(c(class = 0, b = b, nat(fit(k0))), c(class = 1, b = b, nat(fit(k1))))
    }))
  }
  list(rate = rate, f0 = nat(p0), f1 = nat(p1),
       n_eff = c(f0 = sum(w[ver & st$v == 0L])^2 / sum(w[ver & st$v == 0L]^2),
                 f1 = sum(w[ver & st$v == 1L])^2 / sum(w[ver & st$v == 1L]^2)),
       e0 = log(pmax(dens(p0, st$s, st$cens), 1e-300)),
       e1 = log(pmax(dens(p1, st$s, st$cens), 1e-300)), boot = boot)
}
if (sys.nframe() == 0L) {
  a <- commandArgs(TRUE)
  d <- curiango_v1("custom", c_lo = qlogis(0.1))
  r <- emis_2stage(d, n_boot = if (length(a) > 1) as.integer(a[2]) else 0L)
  cat("inclusion rate by stratum:", round(r$rate, 4), "\n")
  cat("effective n:", round(r$n_eff, 1), "\n")
  print(round(rbind(f0 = r$f0, f1 = r$f1), 3))
  if (!is.null(r$boot)) {
    b <- as.data.frame(r$boot)
    print(aggregate(. ~ class, b[, -2], \(x) round(quantile(x, c(.05, .5, .95)), 3)))
  }
  saveRDS(r, a[1])
}
