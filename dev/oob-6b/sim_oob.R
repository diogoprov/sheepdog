# Request 6b of the review-design study: a sign of the uncertainty of the
# empirical threshold. Compares, on simulated review samples, the lower
# bound of the precision of the chosen threshold from (i) a bootstrap with
# the threshold fixed at the point estimate and (ii) an out-of-bag bootstrap
# (threshold chosen in the replicate, precision measured on the recordings
# left out), and the conservative threshold of threshold_bootstrap()
# (boot_cons). Failure: true precision at or above the threshold below
# target - 0.02.
#   Rscript dev/oob-6b/sim_oob.R OUT_RDS [reps] [n_boot] [cores]
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
a <- commandArgs(TRUE)
out <- a[1]
reps <- if (length(a) > 1) as.integer(a[2]) else 300L
n_boot <- if (length(a) > 2) as.integer(a[3]) else 200L
cores <- if (length(a) > 3) as.integer(a[4]) else 6L
targets <- c(0.90, 0.95)
tol <- 0.02
bands <- c(0.1, 0.3, 0.5, 0.7, 0.9, 1.0001)

# Population of one scenario: 300 recordings x 40 detections, logit score
# N(-1, 1.5) kept above 0.1; P(TP) logistic in the logit, with a recording
# effect on the log-odds (clustered false positives) and an optional
# ceiling (precision that levels off near the target)
population <- function(scen, seed) {
  withr::with_seed(seed, {
    R <- 300; m <- 40
    rec <- rep(seq_len(R), each = m)
    x <- stats::rnorm(R * m, -1, 1.5)
    conf <- stats::plogis(x)
    sig <- switch(scen, indep = 0, clumped = 1.5, plateau = 1.5)
    u <- stats::rnorm(R, 0, sig)[rec]
    p <- stats::plogis(1 + 1.6 * x + u)
    if (scen == "plateau") p <- 0.955 * p
    tp <- stats::rbinom(R * m, 1, p)
    d <- data.frame(rec = rec, confidence = round(conf, 3), tp = tp)
    d <- d[d$confidence >= 0.1, ]
    d$band <- cut(d$confidence, bands, right = FALSE)
    d
  })
}

# True precision of the detections at or above each cut
true_precision <- function(pop, cut) {
  if (is.na(cut)) return(NA_real_)
  mean(pop$tp[pop$confidence >= cut])
}

# Two-stage review sample: k recordings at random, then n / 5 clips per
# score band among their detections (all of a band when it has fewer);
# inclusion probability within the recordings drawn
draw_sample <- function(pop, n) {
  k <- max(10, round(n / 4))
  recs <- sample(unique(pop$rec), k)
  sub <- pop[pop$rec %in% recs, ]
  per <- n / 5
  parts <- lapply(split(sub, sub$band), function(b) {
    if (nrow(b) == 0) return(NULL)
    take <- min(nrow(b), per)
    s <- b[sample(nrow(b), take), ]
    s$inclusion_prob <- take / nrow(b)
    s
  })
  s <- do.call(rbind, parts)
  s$verdict <- ifelse(s$tp == 1, "positive", "negative")
  s
}

thr <- function(d, t) {
  threshold_for(d, t, 15, pesos = TRUE, weighted = TRUE,
                sustained = TRUE)$threshold
}
wprec <- function(d, cut) {
  if (is.na(cut)) return(NA_real_)
  s <- d$confidence >= cut
  if (sum(s) < 5) return(NA_real_)
  w <- 1 / d$inclusion_prob[s]
  sum(w * d$tp[s]) / sum(w)
}

one_sample <- function(pop, n) {
  s <- draw_sample(pop, n)
  t_hat <- vapply(targets, \(t) thr(s, t), 0)
  groups <- split(seq_len(nrow(s)), s$rec)
  k <- length(groups)
  boot <- replicate(n_boot, {
    pick <- sample(k, replace = TRUE)
    inb <- s[unlist(groups[pick], use.names = FALSE), ]
    oob <- s[unlist(groups[setdiff(seq_len(k), pick)], use.names = FALSE), ]
    tb <- vapply(targets, \(t) thr(inb, t), 0)
    c(tb,                                                    # replicate threshold
      vapply(seq_along(targets), \(j) wprec(inb, t_hat[j]), 0),  # fixed
      vapply(seq_along(targets), \(j) wprec(oob, tb[j]), 0))     # out-of-bag
  })
  nt <- length(targets)
  q <- \(x, p) if (mean(!is.na(x)) >= 0.5) unname(stats::quantile(x, p, na.rm = TRUE)) else NA_real_
  do.call(rbind, lapply(seq_len(nt), function(j) {
    tb <- boot[j, ]; fx <- boot[nt + j, ]; ob <- boot[2 * nt + j, ]
    cons <- q(tb, 0.95)
    data.frame(n = n, target = targets[j], k = k,
               t_hat = t_hat[j], prec_true = true_precision(pop, t_hat[j]),
               lb_fixed = q(fx, 0.05), lb_oob = q(ob, 0.05),
               q20_fixed = q(fx, 0.20), q20_oob = q(ob, 0.20),
               mean_oob = if (mean(!is.na(ob)) >= 0.5) mean(ob, na.rm = TRUE) else NA_real_,
               med_oob = q(ob, 0.5),
               share_reached = mean(!is.na(tb)),
               t_cons = cons, prec_true_cons = true_precision(pop, cons))
  }))
}

grid <- expand.grid(scen = c("indep", "clumped", "plateau"),
                    n = c(100, 200, 400, 800), rep = seq_len(reps),
                    stringsAsFactors = FALSE)
pops <- lapply(c(indep = 1, clumped = 2, plateau = 3),
               \(i) population(c("indep", "clumped", "plateau")[i], 2026 + i))
RNGkind("L'Ecuyer-CMRG"); set.seed(2026)
t0 <- Sys.time()
res <- parallel::mclapply(seq_len(nrow(grid)), function(i) {
  g <- grid[i, ]
  r <- one_sample(pops[[g$scen]], g$n)
  cbind(scen = g$scen, rep = g$rep, r)
}, mc.cores = cores, mc.set.seed = TRUE)
res <- do.call(rbind, res)
attr(res, "seconds") <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
attr(res, "true_curves") <- lapply(pops, \(p) {
  cuts <- seq(0.5, 0.99, by = 0.01)
  data.frame(cut = cuts, precision = vapply(cuts, \(c) true_precision(p, c), 0))
})
saveRDS(res, out)
cat("seconds", attr(res, "seconds"), "\n")
