# Emissions of the Curiango fits against the verified minutes (PLANO-v1-markov.md).
#   Rscript dev/fase2/check_curiango_emissions.R dev/fase2/results/curiango_v1/fit_*.rds
args <- commandArgs(TRUE)
source("dev/fase2/v1.R"); source("dev/fase2/curiango_v1.R")
dat <- curiango_v1("custom", c_lo = qlogis(0.1))$stan
one <- function(f) {
  r <- readRDS(f); s <- r$summary; m <- setNames(s$mean, s$variable)
  dg <- r$diag
  cat("\n==", basename(f), "  minutes:", round(r$seconds / 60), "\n")
  cat("divergent", sum(dg$num_divergent), " max_treedepth", sum(dg$num_max_treedepth),
      " ebfmi", paste(round(dg$ebfmi, 2), collapse = " "),
      " max rhat", round(max(s$rhat, na.rm = TRUE), 3), " min ess_bulk", round(min(s$ess_bulk, na.rm = TRUE)), "\n")
  print(s[, c("variable", "mean", "q5", "q95", "rhat", "ess_bulk")], digits = 3, row.names = FALSE)
  dens <- function(x, mu, sd) dnorm(x, mu, sd)
  e0 <- \(x) m[["pi0"]] * dens(x, m[["lambda0"]], m[["sigma0"]]) + (1 - m[["pi0"]]) * dens(x, m[["lambda0"]], m[["sigma0b"]])
  e1 <- \(x) m[["pi1"]] * dens(x, m[["mu1a"]], m[["sigma1a"]]) + (1 - m[["pi1"]]) * dens(x, m[["mu1b"]], m[["sigma1b"]])
  obs <- dat$cens == 0
  neg <- dat$s[obs & dat$v == 0]; pos <- dat$s[obs & dat$v == 1]
  psi <- plogis(m[["beta[1]"]])
  th <- if ("theta_bar" %in% names(m)) m[["theta_bar"]] else plogis(m[["alpha[1]"]])
  cat(sprintf("psi %.3f  theta %.3f  psi*theta %.3f\n", psi, th, psi * th))
  cat(sprintf("share f1>f0: verified negatives %.2f, positives %.2f\n",
              mean(e1(neg) > e0(neg)), mean(e1(pos) > e0(pos))))
  # posterior P(w=1 | s) ignoring the prior structure, with prior p = psi*theta
  p <- psi * th
  cat(sprintf("P(w=1|s) at prior psi*theta: negatives median %.2f, positives median %.2f\n",
              median(p * e1(neg) / (p * e1(neg) + (1 - p) * e0(neg))),
              median(p * e1(pos) / (p * e1(pos) + (1 - p) * e0(pos)))))
}
for (f in args) one(f)
