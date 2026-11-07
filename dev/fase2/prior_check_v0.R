# Prior predictive check of the emissions of v0; see dev/fase2/README.md.
# No data enter: each prior draw gives two score distributions on the logit
# scale, and we read what they imply about a classifier. Run from the root:
#   Rscript dev/fase2/prior_check_v0.R
set.seed(2026)
n <- 2e5
hn <- \(s) abs(rnorm(n, 0, s))
ln <- \(m, s) rlnorm(n, log(m), s)
candidates <- list(
  A_provisional = list(l0 = rnorm(n, -3, 3), d = hn(5), s0 = hn(3), s1 = hn(3)),
  B_half_normal = list(l0 = rnorm(n, -3, 2), d = hn(4), s0 = hn(1.5), s1 = hn(1.5)),
  C_lognormal = list(l0 = rnorm(n, -3, 2), d = ln(3, 0.6), s0 = ln(1.2, 0.5),
                     s1 = ln(1.2, 0.5)),
  D_lognormal = list(l0 = rnorm(n, -3, 1.5), d = ln(4, 0.5), s0 = ln(1.2, 0.4),
                     s1 = ln(1.2, 0.4))
)
half <- 0
sat <- qlogis(0.9999)
implied <- function(p) {
  up <- \(c, m, s) pnorm(c, m, s, lower.tail = FALSE)
  data.frame(
    false_above_half = up(half, p$l0, p$s0),
    true_above_half = up(half, p$l0 + p$d, p$s1),
    auc = pnorm(p$d / sqrt(p$s0^2 + p$s1^2)),
    true_saturated = up(sat, p$l0 + p$d, p$s1),
    false_floor = pnorm(-sat, p$l0, p$s0)
  )
}
# Region fixed in the README before looking at the output
inside <- function(q) {
  q$false_above_half <= 0.3 & q$true_above_half >= 0.2 &
    q$auc >= 0.6 & q$auc <= 0.999 & q$true_saturated <= 0.3 & q$false_floor <= 0.5
}
out <- lapply(names(candidates), \(k) {
  q <- implied(candidates[[k]])
  cbind(prior = k, data.frame(
    in_region = mean(inside(q)),
    t(sapply(q, \(x) round(quantile(x, c(.05, .5, .95)), 3))) |>
      as.data.frame() |> (\(m) data.frame(
        false05 = m["false_above_half", 1], false95 = m["false_above_half", 3],
        true05 = m["true_above_half", 1], true95 = m["true_above_half", 3],
        auc05 = m["auc", 1], auc50 = m["auc", 2], auc95 = m["auc", 3],
        sat95 = m["true_saturated", 3], floor95 = m["false_floor", 3]))()))
})
print(do.call(rbind, out), digits = 3, row.names = FALSE)
# Density of each prior at the two simulated classifiers, as a check that the
# priors do not rule them out; the priors were not chosen to match them
for (k in names(candidates)) {
  p <- candidates[[k]]
  cat(k, ": P(d<1)", round(mean(p$d < 1), 3), " P(d>8)", round(mean(p$d > 8), 3),
      " P(s0<0.3)", round(mean(p$s0 < .3), 3), " P(s0>4)", round(mean(p$s0 > 4), 3), "\n")
}
