# Stage 1 by score bins (21/11/2026, after the leave-one-out test of the
# PLANO). With the two-normal mixtures, stage 2 puts 2.5 to 3 times the
# reference's calling minutes in the 0.1 to 0.4 band, by a near-constant
# factor close to and far from the bursts: the f1/f0 ratio in the mid band
# looks inflated. Here f0 and f1 are piecewise constant on score bins (prob
# scale: < 0.1 censored, 0.1-0.2, 0.2-0.3, 0.3-0.4, >= 0.4), so only the
# ratio per bin matters in stage 2 (the bin width cancels):
#   * calling minutes of bin b: weighted precision of the verified minutes of
#     ct01 + ct02 in b (weights 1 / pi1) times the minutes of b in the deposit
#     (the post-stratified reference, bin by bin);
#   * f1(b) from those calling minutes and f0(b) from the rest of the census,
#     each plus 0.5 per bin.
# A first version took f1 from the weighted share of the positives in each
# bin: 20 positives put 0.45 of f1 at >= 0.4, where the 1,756 minutes of that
# bin (precision 1) put 0.53, and stage 2 then needed more mid-band calls.
# With f1_from = "positives" that version is kept for comparison.
# The ratio f1/f0 per bin is then anchored on the design-based precision of
# the bin. Note: the same ct12 labels give the reference of criterion 1, as
# they already gave f1 in the parametric version.
#   Rscript dev/fase2/emissions_bins_curiango.R OUT_DIR PI_CSV [n_boot] [census|positives]
source("dev/fase2/curiango_v1.R")
breaks <- c(-1, 0.1, 0.2, 0.3, 0.4, 2)

emis_bins <- function(b, lab, y, w, nb = length(breaks) - 1L, a0 = 0.5, f1_from = "census") {
  N <- tabulate(b, nb)
  k <- which(lab)
  ww <- w[k] / mean(w[k])
  sw <- vapply(seq_len(nb), \(j) sum(ww[b[k] == j]), 0)
  swy <- vapply(seq_len(nb), \(j) sum(ww[b[k] == j & y[k] == 1L]), 0)
  prec <- ifelse(sw > 0, swy / sw, 0)
  n1 <- if (f1_from == "census") prec * N else swy
  f1 <- (n1 + a0) / sum(n1 + a0)
  n0 <- N - prec * N
  f0 <- (n0 + a0) / sum(n0 + a0)
  list(type = "bins", breaks = breaks, f0 = f0, f1 = f1, rate = prec, N = N,
       n_eff = c(f0 = sum(n0), f1 = sum(ww[y[k] == 1L])^2 / sum(ww[y[k] == 1L]^2)),
       e0 = log(f0[b]), e1 = log(f1[b]))
}

if (sys.nframe() == 0L) {
  a <- commandArgs(TRUE)
  out <- a[1]; nboot <- if (length(a) > 2) as.integer(a[3]) else 0L
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
  f1_from <- if (length(a) > 3) a[4] else "census"
  r <- emis_bins(b, lab, y, w, f1_from = f1_from)
  lb <- c("<0.1", "0.1-0.2", "0.2-0.3", "0.3-0.4", ">=0.4")
  print(data.frame(bin = lb, minutes = r$N, precision = round(r$rate, 4), f0 = signif(r$f0, 3),
                   f1 = signif(r$f1, 3), log_ratio = round(log(r$f1 / r$f0), 2)), row.names = FALSE)
  cat("n_eff:", round(r$n_eff, 1), "\n")
  if (nboot > 0L) {
    g <- split(seq_len(st$N_occ), paste(m$site, d$night))
    r$boot <- withr::with_seed(2026, t(replicate(nboot, {
      idx <- unlist(g[sample.int(length(g), replace = TRUE)], use.names = FALSE)
      rb <- emis_bins(b[idx], lab[idx], y[idx], w[idx], f1_from = f1_from)
      c(f0 = rb$f0, f1 = rb$f1)
    })))
  }
  saveRDS(r, file.path(out, if (f1_from == "census") "emissions_bins.rds" else "emissions_bins_pos.rds"))
}
