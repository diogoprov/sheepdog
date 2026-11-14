# Pools stage 2 fits of model_v1_3state.stan run on bootstrap replicates of the
# stage 1 emissions (run_curiango_3state.R with BOOT > 0). Draws are pooled
# with equal weight per replicate, and the posterior variance of each quantity
# is split into the mean within-replicate variance (emissions fixed) and the
# variance of the replicate means (emission uncertainty). Optionally compares
# with the fit on the point estimates of the emissions.
#   Rscript dev/fase2/pool_curiango_3state_boot.R BOOT_DIR [POINT_FIT] [OUT_RDS]
a <- commandArgs(TRUE)
files <- sort(list.files(a[1], "^fit_3state_b[0-9]+_.*\\.rds$", full.names = TRUE))
fits <- lapply(files, readRDS)
diag <- do.call(rbind, lapply(fits, \(f) data.frame(
  boot = f$boot, minutes = round(f$seconds / 60),
  divergent = sum(f$diag$num_divergent), max_treedepth = sum(f$diag$num_max_treedepth),
  rhat_max = max(f$summary$rhat, na.rm = TRUE), ess_bulk_min = min(f$summary$ess_bulk, na.rm = TRUE),
  ess_tail_min = min(f$summary$ess_tail, na.rm = TRUE))))
print(diag, digits = 3)
pars <- c("psi_c", "theta_bar", "psi_theta_bar", "theta0", "rho", "p_h", "p_hh", "p_hl")
get <- function(f) {
  d <- as.data.frame(f$draws)
  d$psi_theta_bar <- d$psi_c * d$theta_bar
  if (!"rho" %in% names(d)) d$rho <- d[["rho[1]"]]
  d[pars]
}
dr <- lapply(fits, get)
n <- min(vapply(dr, nrow, 0L))
pool <- do.call(rbind, lapply(dr, \(d) d[seq_len(n), ]))
q <- \(x) quantile(x, c(.05, .5, .95), names = FALSE)
within <- sapply(dr, \(d) vapply(d, var, 0))
means <- sapply(dr, \(d) vapply(d, mean, 0))
tab <- data.frame(par = pars, t(sapply(pool, q)),
                  sd_within = sqrt(rowMeans(within)), sd_between = apply(means, 1, sd),
                  row.names = NULL)
names(tab)[2:4] <- c("q05", "q50", "q95")
tab$share_between <- tab$sd_between^2 / (tab$sd_between^2 + tab$sd_within^2)
if (length(a) > 1 && file.exists(a[2])) {
  p <- get(readRDS(a[2]))
  pt <- t(sapply(p, q))
  tab$point_q05 <- pt[, 1]; tab$point_q50 <- pt[, 2]; tab$point_q95 <- pt[, 3]
}
print(tab, digits = 3)
if (length(a) > 2) saveRDS(list(diag = diag, pooled = tab, replicate_means = means), a[3])
