# Summary of run_mixid.R by the criteria of PLANO-identificacao-mistura.md,
# paired with the v0 fits of the ignorability run on the same data sets.
#   Rscript dev/fase2/summarise_mixid.R OUT_DIR [V0_DIR]
# OUT_DIR holds task_*.rds or a single task_all.rds.
source("dev/fase2/sim_mixid.R")
args <- commandArgs(TRUE)
out <- args[1]
v0_dir <- if (length(args) > 1) args[2] else "dev/fase2/results/ignorab_v0"
read_run <- function(dir) {
  files <- list.files(dir, "^task_\\d+\\.rds$", full.names = TRUE)
  if (length(files)) do.call(rbind, lapply(files, readRDS)) else
    readRDS(file.path(dir, "task_all.rds"))
}
r <- read_run(out)
fits <- r[!duplicated(r$id), ]
cat("fits:", nrow(fits), " errors:", sum(!is.na(fits$error)), "\n")
cat(sprintf("seconds per fit: median %.0f, max %.0f; CPU hours: %.2f\n",
            median(fits$seconds), max(fits$seconds), sum(fits$seconds) / 3600))

# M1: convergence of the fit (all saved parameters)
conv <- aggregate(cbind(ok = rhat < 1.01) ~ id, r[!is.na(r$rhat), ], all)
fits$conv <- conv$ok[match(fits$id, conv$id)] & fits$divergent == 0
fits$conv[is.na(fits$conv)] <- FALSE
cv <- aggregate(cbind(conv, divergent = divergent > 0) ~ truth + frac + design,
                fits, mean)
cat("\nM1, share converged and share with divergences per cell:\n")
print(transform(cv, conv = round(conv, 2), divergent = round(divergent, 2)),
      row.names = FALSE)

score <- function(k) {
  k$true <- mapply(\(v, t) mixid_truth(t)[v], k$variable, k$truth)
  k <- k[!is.na(k$true), ]
  k$err <- k$mean - k$true
  k$cover <- k$lo <= k$true & k$hi >= k$true
  k$width <- k$hi - k$lo
  k
}
k <- score(r[!is.na(r$variable), ])

# v0 on the same data sets, selections and seeds
v0 <- read_run(v0_dir)
v0 <- v0[v0$with_h & v0$design %in% c(mixid_designs, "none") &
           v0$variable %in% c("psi", "theta"), ]
v0 <- score(v0)
key <- c("truth", "set", "frac", "design", "variable")
pair <- merge(k[k$variable %in% c("psi", "theta"), c(key, "mean", "cover", "width")],
              v0[, c(key, "mean", "cover", "width")], by = key,
              suffixes = c("", "_v0"))

tab <- aggregate(cbind(bias = err, cover, width) ~ truth + frac + design + variable,
                 k[k$variable %in% c("psi", "theta"), ], mean)
tab$n <- aggregate(err ~ truth + frac + design + variable,
                   k[k$variable %in% c("psi", "theta"), ], length)$err
pv <- aggregate(cbind(paired_v0 = mean - mean_v0, cover_v0, width_ratio = width / width_v0) ~
                  truth + frac + design + variable, pair, mean)
tab <- merge(tab, pv, all.x = TRUE)
tab <- tab[order(tab$variable, tab$truth, -tab$frac, tab$design), ]
num <- c("bias", "cover", "width", "paired_v0", "cover_v0", "width_ratio")
tab[num] <- lapply(tab[num], round, 3)
cat("\npsi and theta at the centre (paired_v0 = mean minus the v0 mean, same data):\n")
print(tab, row.names = FALSE)

em <- names(ig_truth$mixture)
et <- aggregate(cbind(bias = err, cover, width) ~ frac + design + variable,
                k[k$truth == "mixture" & k$variable %in% em, ], mean)
et[c("bias", "cover", "width")] <- lapply(et[c("bias", "cover", "width")], round, 3)
cat("\nM3, emissions under the mixture truth:\n")
print(et[order(et$variable, -et$frac, et$design), ], row.names = FALSE)

pass <- \(x) abs(x$bias) <= 0.05 & x$cover >= 0.90
m2 <- tab[tab$truth == "mixture" & tab$design %in% mixid_designs, ]
m4 <- tab[tab$truth == "normal" & tab$design %in% mixid_designs, ]
c_mix <- cv[cv$truth == "mixture" & cv$design %in% mixid_designs, ]
cat("\nM1 mixture cells with >= 95% converged:", sum(c_mix$conv >= 0.95), "of",
    nrow(c_mix), "\n")
cat("M2 (mixture truth, S1 and S2) cells passing:", sum(pass(m2)), "of", nrow(m2), "\n")
cat("M4 (normal truth, S1 and S2) cells passing:", sum(pass(m4)), "of", nrow(m4), "\n")
if (max(tab$n) < 20) cat("Too few replicates for coverage; this is a pilot.\n")
