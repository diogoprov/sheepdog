# Stage 0 of the Curiango step: maximum likelihood of the censored normal for
# each class, on the verified minutes only (no Stan), with a split by night.
#   Rscript dev/fase2/emissions_curiango_v0.R [OUT_FILE]
source("dev/fase2/curiango_v0.R")
set.seed(2026)
nll <- function(p, s, cens, cl, ch) {
  mu <- p[1]; sd <- exp(p[2])
  -sum(ifelse(cens == 0L, dnorm(s, mu, sd, log = TRUE),
              ifelse(cens == 1L, pnorm(cl, mu, sd, log.p = TRUE),
                     pnorm(ch, mu, sd, lower.tail = FALSE, log.p = TRUE))))
}
fit <- function(s, cens, cl, ch) {
  o <- optim(c(mean(s[cens == 0L]), 0), nll, s = s, cens = cens, cl = cl, ch = ch,
             method = "BFGS", hessian = TRUE)
  se <- sqrt(diag(solve(o$hessian)))
  c(mu = o$par[1], se_mu = se[1], sigma = exp(o$par[2]), se_log_sigma = se[2])
}
# censored share and quantiles of the uncensored scores
feat <- function(s, cens) {
  u <- s[cens == 0L]
  c(cens = mean(cens == 1L), q = if (length(u) > 1) quantile(u, c(.1, .5, .9), names = FALSE) else rep(NA, 3))
}
res <- list()
for (cl in c("custom", "birdnet")) {
  d <- curiango_v0(cl); st <- d$stan
  ver <- st$v >= 0L
  nights <- unique(d$night[ver])
  test_n <- sample(nights, round(0.3 * length(nights)))
  test <- ver & d$night %in% test_n
  train <- ver & !test
  for (y in 0:1) {
    a <- train & st$v == y; b <- test & st$v == y
    p <- fit(st$s[a], st$cens[a], st$c_lo, st$c_hi)
    # 2000 replicate test sets of the size of the held-out class
    rep <- replicate(2000, {
      x <- rnorm(sum(b), p["mu"], p["sigma"])
      feat(x, ifelse(x < st$c_lo, 1L, ifelse(x > st$c_hi, 2L, 0L)))
    })
    ob <- feat(st$s[b], st$cens[b])
    all_p <- fit(st$s[ver & st$v == y], st$cens[ver & st$v == y], st$c_lo, st$c_hi)
    res[[paste(cl, y)]] <- data.frame(
      classifier = cl, class = y, n_train = sum(a), n_test = sum(b),
      n_test_unc = sum(b & st$cens == 0L), mu = p["mu"], sigma = p["sigma"],
      mu_all = all_p["mu"], sigma_all = all_p["sigma"],
      stat = c("cens", "q10", "q50", "q90"), obs = ob,
      lo = apply(rep, 1, quantile, .025, na.rm = TRUE),
      hi = apply(rep, 1, quantile, .975, na.rm = TRUE), row.names = NULL)
  }
}
out <- do.call(rbind, res); rownames(out) <- NULL
out$inside <- out$lo <= out$obs & out$obs <= out$hi
print(out, digits = 3)
a <- commandArgs(TRUE)
if (length(a)) saveRDS(out, a[1])
