# Replicas of the night bootstrap of the stage 1 by score bins
# (emissions_bins_curiango.R), one folder per replica with its per-minute
# densities, for run_curiango_2stage.R. Same seed and resampling of site-nights
# of the whole deposit as the bootstrap of emissions_bins_curiango.R.
#   Rscript dev/fase2/emissions_bins_boot.R OUT_DIR PI_CSV [n_boot]
source("dev/fase2/emissions_bins_curiango.R")
a <- commandArgs(TRUE); out <- a[1]; nboot <- if (length(a) > 2) as.integer(a[3]) else 20L
d <- curiango_v1("custom", c_lo = qlogis(0.1)); st <- d$stan; m <- d$minutes
prob <- ifelse(st$cens == 1L, 0, plogis(st$s)); prob[st$cens == 2L] <- 1
b <- as.integer(cut(prob, breaks, right = FALSE))
p <- read.csv(a[2])
j <- match(paste(p$site, p$time), paste(m$site, format(m$time, "%Y-%m-%d %H:%M:%S")))
stopifnot(!anyNA(j))
k12 <- p$stage == "ct12"
lab <- rep(FALSE, st$N_occ); lab[j[k12]] <- TRUE
y <- rep(NA_integer_, st$N_occ); y[j[k12]] <- p$y[k12]
w <- rep(1, st$N_occ); w[j[k12]] <- 1 / p$pi1[k12]
g <- split(seq_len(st$N_occ), paste(m$site, d$night))
withr::with_seed(2026, for (r in seq_len(nboot)) {
  idx <- unlist(g[sample.int(length(g), replace = TRUE)], use.names = FALSE)
  rb <- emis_bins(b[idx], lab[idx], y[idx], w[idx])
  # densities of the replica applied to every minute of the original deposit
  rb$e0 <- log(rb$f0[b]); rb$e1 <- log(rb$f1[b]); rb$N <- tabulate(b, length(rb$f0))
  dir.create(file.path(out, sprintf("b%02d", r)), recursive = TRUE, showWarnings = FALSE)
  saveRDS(rb, file.path(out, sprintf("b%02d", r), "emissions.rds"))
  cat(sprintf("b%02d", r), "f1 >= 0.4:", round(rb$f1[5], 3), " log f1/f0:", round(log(rb$f1 / rb$f0), 2), "\n")
})
