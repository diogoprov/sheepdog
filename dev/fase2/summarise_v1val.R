# Summary of run_v1val.R by the criteria of PLANO-v1-markov.md.
#   Rscript dev/fase2/summarise_v1val.R OUT_DIR
# OUT_DIR holds task_*.rds or a single task_all.rds.
source("dev/fase2/v1.R")
args <- commandArgs(TRUE)
out <- args[1]
files <- list.files(out, "^task_[0-9]+[.]rds$", full.names = TRUE)
r <- if (length(files)) do.call(rbind, lapply(files, readRDS)) else
  readRDS(file.path(out, "task_all.rds"))
fits <- r[!duplicated(r$id), ]
cat("fits:", nrow(fits), " errors:", sum(!is.na(fits$error)), "\n")
cat(sprintf("seconds per fit: median %.0f, max %.0f; CPU hours: %.2f\n",
            median(fits$seconds), max(fits$seconds), sum(fits$seconds) / 3600))

# V1: convergence (all saved parameters)
conv <- aggregate(cbind(ok = rhat < 1.01) ~ id, r[!is.na(r$rhat), ], all)
fits$conv <- conv$ok[match(fits$id, conv$id)] & fits$divergent == 0
fits$conv[is.na(fits$conv)] <- FALSE
cv <- aggregate(cbind(conv, divergent = divergent > 0) ~ rho + frac + model, fits, mean)
cat("\nV1, share converged and share with divergences per cell:\n")
print(transform(cv, conv = round(conv, 2), divergent = round(divergent, 2)), row.names = FALSE)

truth_of <- function(variable, rho) {
  a0 <- v1_alpha0[[as.character(rho)]]
  th <- v1_theta(a0, rho)
  em <- unlist(ig_truth$mixture)
  t <- c(psi = 0.5, theta0 = th[["theta0"]], theta_bar = th[["theta_bar"]],
         `beta[1]` = 0, `beta[2]` = -0.8, `alpha[1]` = a0, `alpha[2]` = 0.6,
         `alpha[3]` = 1, rho = rho, em)
  unname(t[variable])
}
k <- r[!is.na(r$variable), ]
k$true <- mapply(truth_of, k$variable, k$rho)
k <- k[!is.na(k$true), ]
k$err <- k$mean - k$true
k$cover <- k$lo <= k$true & k$hi >= k$true
k$width <- k$hi - k$lo
main <- c("psi", "theta0", "theta_bar", "rho")
tab <- aggregate(cbind(bias = err, cover, width) ~ rho + frac + model + variable,
                 k[k$variable %in% main, ], mean)
tab$n <- aggregate(err ~ rho + frac + model + variable, k[k$variable %in% main, ], length)$err
# paired difference v1 minus mix on the same data set
b <- k[k$model == "mix", c("set", "frac", "variable", "mean")]
names(b)[4] <- "mean_mix"
pv <- merge(k[k$model == "v1" & k$variable %in% main, ], b)
pd <- aggregate(cbind(v1_minus_mix = mean - mean_mix) ~ rho + frac + variable, pv, mean)
pd$model <- "v1"
tab <- merge(tab, pd, all.x = TRUE)
tab <- tab[order(tab$variable, tab$rho, -tab$frac, tab$model), ]
num <- c("bias", "cover", "width", "v1_minus_mix")
tab[num] <- lapply(tab[num], round, 3)
cat("\npsi, theta0, theta_bar and rho at the centre:\n")
print(tab, row.names = FALSE)

pass <- \(x) abs(x$bias) <= 0.05 & x$cover >= 0.90
v2 <- tab[tab$model == "v1" & tab$variable %in% c("psi", "theta0", "theta_bar"), ]
c1 <- cv[cv$model == "v1", ]
cat("\nV1 (v1 cells with >= 95% converged):", sum(c1$conv >= 0.95), "of", nrow(c1), "\n")
cat("V2 (v1: psi, theta0, theta_bar) cells passing:", sum(pass(v2)), "of", nrow(v2), "\n")
if (max(tab$n) < 20) cat("Too few replicates for coverage; this is a pilot.\n")
