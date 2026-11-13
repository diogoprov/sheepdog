# Checks of sim_ignorab.R (step 0 of PLANO-ignorabilidade.md), no Stan.
#   Rscript dev/fase2/check_ignorab.R
source("dev/fase2/sim_ignorab.R")
ok <- function(cond, msg) {
  cat(if (isTRUE(cond)) "ok  " else "FAIL", msg, "\n")
  if (!isTRUE(cond)) assign("n_fail", n_fail + 1, globalenv())
}
n_fail <- 0

# same seed, same data; selection does not touch the data stream
a <- simulate_ignorab("normal", 1)
b <- simulate_ignorab("normal", 1)
ok(identical(a, b), "same seed gives the same data")
ok(!identical(a$s, simulate_ignorab("normal", 2)$s), "another seed changes the data")
ok(identical(select_ignorab(a, "S2", 0.05, 9), select_ignorab(a, "S2", 0.05, 9)),
   "same seed gives the same selection")

# the same n in every design
for (fr in c(0.05, 0.02)) for (dz in ig_designs) {
  sel <- select_ignorab(a, dz, fr, 3)
  ok(length(sel$idx) == round(fr * length(a$s)) && !anyDuplicated(sel$idx),
     sprintf("%s at %.2f: n = %d, no repeats", dz, fr, length(sel$idx)))
  ok(abs(sum(sel$pi) - length(sel$idx)) < 1e-8, sprintf("%s at %.2f: sum(pi) = n", dz, fr))
}

# PPS frequencies match pi (small population so 4,000 draws are enough)
small <- a
keep <- 1:60
small$s <- a$s[keep]; small$cens <- a$cens[keep]; small$h <- a$h[keep]
small$w <- a$w[keep]
for (dz in c("S2", "S4", "S5")) {
  p <- select_ignorab(small, dz, 0.1, 1)$pi
  draws <- vapply(1:4000, \(r) tabulate(select_ignorab(small, dz, 0.1, r)$idx, 60),
                  numeric(60))
  ok(max(abs(rowMeans(draws) - p)) < 0.03,
     sprintf("%s: max |freq - pi| = %.3f", dz, max(abs(rowMeans(draws) - p))))
}

# the designs select what they should
r <- vapply(ig_designs, \(dz) {
  idx <- select_ignorab(a, dz, 0.05, 5)$idx
  c(score = mean(plogis(a$s[idx])), h = mean(a$h[idx]), w = mean(a$w[idx]))
}, numeric(3))
print(round(r, 3))
ok(r["score", "S3"] > r["score", "S2"] && r["score", "S2"] > r["score", "S1"],
   "mean score: S3 > S2 > S1")
ok(r["h", "S4"] > r["h", "S1"] + 0.1, "S4 enriches h")
ok(r["w", "S5"] > r["w", "S1"] + 0.1, "S5 enriches w")

# truths: calling share, positives verified, censoring
for (tr in c("normal", "mixture")) {
  sims <- lapply(1:20, \(k) simulate_ignorab(tr, k))
  cat(sprintf("%s: calling %.3f, censored %.2f, positives at 2%% (random) %.1f\n", tr,
              mean(sapply(sims, \(x) mean(x$w))), mean(sapply(sims, \(x) mean(x$cens == 1))),
              mean(sapply(sims, \(x) sum(x$w[select_ignorab(x, "S1", 0.02, 1)$idx])))))
}

# Stan data
dat <- stan_ignorab(a, select_ignorab(a, "S2", 0.05, 1)$idx)
ok(sum(dat$v >= 0) == 150 && dat$P_theta == 3, "Stan data: 150 verified, theta ~ d + h")
ok(stan_ignorab(a, with_h = FALSE)$P_theta == 2 && all(stan_ignorab(a)$v == -1),
   "Stan data without h and without verification")

g <- ig_grid(50)
ok(nrow(g) == 1500 && !anyDuplicated(g[c("set", "frac", "design", "with_h")]),
   "grid: 1,500 fits")
sd <- unique(with(g, ig_seed_sel(set, frac, design)[design != "none"]))
ok(length(sd) == 100 * 2 * 5, "selection seeds are distinct per set x fraction x design")

cat(if (n_fail == 0) "\nall checks passed\n" else sprintf("\n%d checks failed\n", n_fail))
