# Bias of the precision when review rounds stop at a target (sheepdog#107).
# One cell, one stratum, N candidate clips with true precision p. Each round
# reviews m clips drawn among those left. "fixed" always runs k_max rounds;
# "stop" ends at the first round where the precision reaches `target` with at
# least min_n clips, as a user following review_support() would.
#   Rscript dev/review-rounds-stopping.R
one <- function(p, N, m, k_max, target, min_n) {
  v <- sample(c(rep(1L, round(p * N)), rep(0L, N - round(p * N))))
  n_stop <- m * k_max
  for (k in seq_len(k_max)) {
    n <- m * k
    if (n >= min_n && mean(v[seq_len(n)]) >= target) { n_stop <- n; break }
  }
  c(fixed = mean(v[seq_len(m * k_max)]), stop = mean(v[seq_len(n_stop)]),
    reached = mean(v[seq_len(n_stop)]) >= target, rounds = n_stop / m)
}
set.seed(2026)
grid <- expand.grid(p = c(0.7, 0.8, 0.85, 0.9, 0.95), m = c(5, 15))
res <- do.call(rbind, lapply(seq_len(nrow(grid)), \(i) {
  g <- grid[i, ]
  r <- replicate(20000, one(g$p, 500, g$m, 60 %/% g$m, 0.9, 15))
  data.frame(g, bias_fixed = mean(r["fixed", ]) - g$p,
             bias_stop = mean(r["stop", ]) - g$p,
             bias_stop_reached = mean(r["stop", r["reached", ] == 1]) - g$p,
             share_reached = mean(r["reached", ]),
             rounds = mean(r["rounds", ]))
}))
print(res, digits = 3)
