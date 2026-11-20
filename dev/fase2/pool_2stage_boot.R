# Pools the stage 2 fits over replicates of the stage 1 night bootstrap
# (emissions_boot_curiango.R + run_curiango_2stage.R): the posterior draws of
# all replicates are stacked with equal weight, so the pooled intervals carry
# the stage 1 uncertainty. Compares with the fit on the point emissions.
#   Rscript dev/fase2/pool_2stage_boot.R BOOT_DIR POINT_FIT [OUT_RDS]
a <- commandArgs(TRUE)
fs <- sort(Sys.glob(file.path(a[1], "b*", "fit_2stage_*.rds")))
pt <- readRDS(a[2])
der <- function(dr) cbind(psi_c = dr[, "psi_c"], theta0 = dr[, "theta0"], theta_bar = dr[, "theta_bar"],
                          psi_tb = dr[, "psi_c"] * dr[, "theta_bar"], rho = dr[, "rho[1]"])
fits <- lapply(fs, readRDS)
dg <- do.call(rbind, lapply(seq_along(fits), \(i) { f <- fits[[i]]
  data.frame(rep = basename(dirname(fs[i])), div = sum(f$diag$num_divergent), tree = sum(f$diag$num_max_treedepth),
             ebfmi_min = round(min(f$diag$ebfmi), 2), rhat_max = round(max(f$summary$rhat, na.rm = TRUE), 4),
             ess_min = round(min(f$summary$ess_bulk, na.rm = TRUE)),
             f1_pi = round(f$emissions$f1[["pi"]], 3),
             psi_tb = round(median(der(f$draws)[, "psi_tb"]), 3)) }))
print(dg, row.names = FALSE)
pool <- do.call(rbind, lapply(fits, \(f) der(f$draws)))
q <- \(m) t(apply(m, 2, quantile, c(.05, .5, .95)))
cat("\nestimativas pontuais do estagio 1:\n"); print(round(q(der(pt$draws)), 3))
cat("\nagrupado sobre", length(fits), "replicas do bootstrap:\n"); print(round(q(pool), 3))
cat("\ncorrelacao entre o peso do comp. baixo de f1 e a mediana de psi_tb:",
    round(cor(dg$f1_pi, dg$psi_tb), 2), "\n")
if (length(a) > 2) saveRDS(list(diag = dg, pooled = q(pool), point = q(der(pt$draws))), a[3])
