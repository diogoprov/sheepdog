# Stage 0 again, with the verified minutes weighted by the inverse of their
# inclusion rate in three strata of the custom score. Provisional: the mechanism
# of the inclusion is unknown. Also tabulates inclusion by hour and site.
#   Rscript dev/fase2/emissions_weighted_curiango.R [OUT_FILE]
source("dev/fase2/curiango_v0.R")
set.seed(2026)
d <- curiango_v0("custom"); st <- d$stan; m <- d$minutes
ver <- st$v >= 0L
stratum <- cut(m$conf_custom, c(-1, 0.3, 0.5, 1), right = FALSE)
rate <- tapply(ver, stratum, mean); print(round(rate, 4))
w_all <- as.numeric(1 / rate[stratum]); w_all <- w_all / mean(w_all[ver])
low <- m$conf_custom < 0.3
h <- as.integer(format(m$time, "%H"))
cat("\ninclusion below 0.3, by hour:\n"); print(round(tapply(ver[low], h[low], mean), 4))
cat("\ninclusion below 0.3, by site:\n"); print(round(tapply(ver[low], m$site[low], mean), 4))
cat("\ninclusion overall, by site:\n"); print(round(tapply(ver, m$site, mean), 4))
print(chisq.test(table(m$site[low], ver[low]))$p.value)
print(chisq.test(table(h[low], ver[low]))$p.value)

one <- function(s, cens, mu, sd, cl, ch) ifelse(cens == 0L, dnorm(s, mu, sd),
  ifelse(cens == 1L, pnorm(cl, mu, sd), pnorm(ch, mu, sd, lower.tail = FALSE)))
ll1 <- function(p, s, ce, cl, ch) log(pmax(one(s, ce, p[1], exp(p[2]), cl, ch), 1e-300))
ll2 <- function(p, s, ce, cl, ch) {
  a <- plogis(p[1])
  log(pmax(a * one(s, ce, p[2], exp(p[3]), cl, ch) +
             (1 - a) * one(s, ce, p[2] + exp(p[4]), exp(p[5]), cl, ch), 1e-300))
}
fit <- function(ll, starts, s, ce, w) {
  fs <- lapply(starts, \(p0) optim(p0, \(p) -sum(w * ll(p, s, ce, st$c_lo, st$c_hi)),
                                   method = "BFGS", control = list(maxit = 500)))
  fs[[which.min(vapply(fs, `[[`, 0, "value"))]]$par
}
s1 <- \(s, ce) list(c(mean(s[ce == 0L]), 0))
s2 <- \(s, ce) { q <- quantile(s[ce == 0L], c(.25, .75), names = FALSE)
  list(c(0, q[1], -0.5, log(max(q[2] - q[1], .5)), 0), c(1, q[1] - 0.5, -1, log(2), 0.3)) }
for (y in 0:1) {
  k <- ver & st$v == y
  p <- fit(ll1, s1(st$s[k], st$cens[k]), st$s[k], st$cens[k], w_all[k])
  q <- fit(ll2, s2(st$s[k], st$cens[k]), st$s[k], st$cens[k], w_all[k])
  cat("\nclass", y, " effective n", round(sum(w_all[k])^2 / sum(w_all[k]^2), 1),
      "\n normal: mu", round(p[1], 2), "sd", round(exp(p[2]), 2),
      "\n mixture: weight", round(plogis(q[1]), 2), "means", round(c(q[2], q[2] + exp(q[4])), 2),
      "sds", round(exp(q[c(3, 5)]), 2), "\n")
}
nights <- unique(d$night[ver]); out <- list()
for (r in 1:50) {
  te <- sample(nights, round(.3 * length(nights)))
  for (y in 0:1) {
    a <- ver & st$v == y & !d$night %in% te; b <- ver & st$v == y & d$night %in% te
    p <- fit(ll1, s1(st$s[a], st$cens[a]), st$s[a], st$cens[a], w_all[a])
    q <- fit(ll2, s2(st$s[a], st$cens[a]), st$s[a], st$cens[a], w_all[a])
    out[[length(out) + 1]] <- data.frame(class = y, split = r,
      gain = sum(w_all[b] * (ll2(q, st$s[b], st$cens[b], st$c_lo, st$c_hi) -
                             ll1(p, st$s[b], st$cens[b], st$c_lo, st$c_hi))))
  }
}
out <- do.call(rbind, out)
print(aggregate(gain ~ class, out, \(x) round(c(mean = mean(x), lo = quantile(x, .025, names = FALSE),
      hi = quantile(x, .975, names = FALSE), pos = mean(x > 0)), 2)))
a <- commandArgs(TRUE); if (length(a)) saveRDS(out, a[1])
