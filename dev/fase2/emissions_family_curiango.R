# Follow-up of stage 0: shape of the true and false scores of the verified
# minutes, and held-out log score of one normal against a two-component
# normal mixture, both censored, over 50 splits by night (30% held out).
#   Rscript dev/fase2/emissions_family_curiango.R [OUT_FILE]
source("dev/fase2/curiango_v0.R")
set.seed(2026)
lik1 <- function(s, cens, mu, sd, cl, ch)
  ifelse(cens == 0L, dnorm(s, mu, sd), ifelse(cens == 1L, pnorm(cl, mu, sd),
         pnorm(ch, mu, sd, lower.tail = FALSE)))
n1 <- function(p, s, cens, cl, ch) -sum(log(pmax(lik1(s, cens, p[1], exp(p[2]), cl, ch), 1e-300)))
lik2 <- function(p, s, cens, cl, ch) {
  w <- plogis(p[1])
  w * lik1(s, cens, p[2], exp(p[3]), cl, ch) +
    (1 - w) * lik1(s, cens, p[2] + exp(p[4]), exp(p[5]), cl, ch)
}
n2 <- function(p, s, cens, cl, ch) -sum(log(pmax(lik2(p, s, cens, cl, ch), 1e-300)))
fit1 <- function(s, cens, cl, ch) {
  optim(c(mean(s[cens == 0L]), 0), n1, s = s, cens = cens, cl = cl, ch = ch, method = "BFGS")$par
}
fit2 <- function(s, cens, cl, ch) {
  u <- s[cens == 0L]; q <- quantile(u, c(.25, .75), names = FALSE)
  st <- list(c(0, q[1], -0.5, log(max(q[2] - q[1], .5)), 0),
             c(1, q[1] - 0.5, -1, log(2), 0.3))
  fits <- lapply(st, \(p0) optim(p0, n2, s = s, cens = cens, cl = cl, ch = ch,
                                 method = "BFGS", control = list(maxit = 500)))
  fits[[which.min(vapply(fits, `[[`, 0, "value"))]]$par
}
out <- list()
for (cl in c("custom", "birdnet")) {
  d <- curiango_v0(cl); st <- d$stan; ver <- st$v >= 0L
  for (y in 0:1) {
    k <- ver & st$v == y
    s <- st$s[k]; ce <- st$cens[k]
    u <- s[ce == 0L]
    cat("\n==", cl, "class", y, " n", sum(k), " uncensored", length(u), "\n")
    print(table(cut(u, seq(-3, 8, 1))))
    p <- fit2(s, ce, st$c_lo, st$c_hi)
    cat("all data, 2 components: weight", round(plogis(p[1]), 2), " means", round(c(p[2], p[2] + exp(p[4])), 2),
        " sds", round(exp(p[c(3, 5)]), 2), "\n")
  }
  nights <- unique(d$night[ver])
  for (r in 1:50) {
    te <- sample(nights, round(.3 * length(nights)))
    for (y in 0:1) {
      a <- ver & st$v == y & !d$night %in% te; b <- ver & st$v == y & d$night %in% te
      p1 <- fit1(st$s[a], st$cens[a], st$c_lo, st$c_hi)
      p2 <- fit2(st$s[a], st$cens[a], st$c_lo, st$c_hi)
      out[[length(out) + 1]] <- data.frame(classifier = cl, class = y, split = r, n = sum(b),
        one = -n1(p1, st$s[b], st$cens[b], st$c_lo, st$c_hi),
        two = -n2(p2, st$s[b], st$cens[b], st$c_lo, st$c_hi))
    }
  }
}
out <- do.call(rbind, out); out$gain <- out$two - out$one
cat("\n== held-out log score, mixture minus normal, per split ==\n")
print(aggregate(gain ~ classifier + class, out, \(x) round(c(mean = mean(x), q2.5 = quantile(x, .025, names = FALSE),
      q97.5 = quantile(x, .975, names = FALSE), share_pos = mean(x > 0)), 2)))
a <- commandArgs(TRUE); if (length(a)) saveRDS(out, a[1])
