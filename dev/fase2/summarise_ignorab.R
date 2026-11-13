# Summary of run_ignorab.R by the criteria of PLANO-ignorabilidade.md.
#   Rscript dev/fase2/summarise_ignorab.R OUT_DIR
# OUT_DIR holds task_*.rds or a single task_all.rds.
args <- commandArgs(TRUE)
out <- args[1]
files <- list.files(out, "^task_\\d+\\.rds$", full.names = TRUE)
r <- if (length(files)) do.call(rbind, lapply(files, readRDS)) else
  readRDS(file.path(out, "task_all.rds"))
truth <- c(psi = 0.5, theta = 0.3)

cat("fits:", length(unique(r$id)), " errors:", sum(!is.na(r$error[!duplicated(r$id)])), "\n")
fits <- r[!duplicated(r$id), ]
cat(sprintf("seconds per fit: median %.0f, max %.0f; CPU hours: %.2f\n",
            median(fits$seconds), max(fits$seconds), sum(fits$seconds) / 3600))

# I1: convergence per cell
conv <- aggregate(cbind(ok = rhat < 1.01) ~ id, r[!is.na(r$rhat), ], all)
fits$conv <- conv$ok[match(fits$id, conv$id)] & fits$divergent == 0
fits$arm <- with(fits, ifelse(design == "none", "none",
                              paste0(design, ifelse(with_h, "", "-noh"))))
cell <- c("truth", "frac", "arm")

k <- r[r$variable %in% names(truth), ]
k$arm <- fits$arm[match(k$id, fits$id)]
k$err <- k$mean - truth[k$variable]
k$cover <- k$lo <= truth[k$variable] & k$hi >= truth[k$variable]
k$width <- k$hi - k$lo

tab <- aggregate(cbind(bias = err, cover, width) ~ truth + frac + arm + variable, k, mean)
tab$n <- aggregate(err ~ truth + frac + arm + variable, k, length)$err
cv <- aggregate(conv ~ truth + frac + arm, fits, mean)
tab$conv <- cv$conv[match(do.call(paste, tab[cell]), do.call(paste, cv[cell]))]

# paired difference to S1 (S1-noh for the arms without h)
k$base <- ifelse(grepl("noh", k$arm), "S1-noh", "S1")
b <- k[k$arm %in% c("S1", "S1-noh"), c("truth", "set", "frac", "arm", "variable", "mean")]
names(b)[names(b) %in% c("arm", "mean")] <- c("base", "mean_base")
k <- merge(k, b, all.x = TRUE)
pd <- aggregate(cbind(paired = mean - mean_base) ~ truth + frac + arm + variable, k, mean)
tab <- merge(tab, pd, all.x = TRUE)
tab <- tab[order(tab$variable, tab$truth, -tab$frac, tab$arm), ]
num <- c("bias", "cover", "width", "conv", "paired")
tab[num] <- lapply(tab[num], round, 3)
print(tab, row.names = FALSE)

pass <- \(x) abs(x$bias) <= 0.05 & x$cover >= 0.90
i2 <- tab[tab$truth == "normal" & tab$arm %in% c("S1", "S2", "S3", "S4"), ]
i3 <- tab[tab$truth == "mixture" & tab$arm %in% c("S2", "S3"), ]
cat("\nI1 cells with >= 95% converged:", sum(cv$conv >= 0.95), "of", nrow(cv), "\n")
cat("I2 (control) cells passing:", sum(pass(i2)), "of", nrow(i2), "\n")
cat("I3 (score selection, mixture) cells passing:",
    sum(pass(i3) & abs(i3$paired) <= 0.05, na.rm = TRUE), "of", nrow(i3), "\n")
if (max(tab$n) < 20) cat("Too few replicates for coverage; this is a pilot.\n")
