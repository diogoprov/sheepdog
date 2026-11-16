# Arm "pamflow-style" for the 6b simulation: compares, on the populations
# of sim_oob.R, the thresholds of sheepdog (point threshold of
# threshold_for() and the conservative threshold of threshold_bootstrap())
# with the threshold of the detection_validation pipeline of pamflow
# (Betancourt et al. 2026, Methods Ecol Evol, doi:10.1111/2041-210x.70432;
# code at github.com/pamflow-org/pamflow, src/pamflow/pipelines/
# detection_validation/nodes.py and species_detection/nodes.py).
#
# pamflow, as reimplemented here:
# - review sample: n segments drawn among all detections of the species,
#   stratified in 5 equal-width bins of the species' own score range, with
#   the same number per bin (surplus of small bins to the others);
#   inclusion probabilities are not kept;
# - unweighted logistic regression of TP on the score (identity, the
#   default, or logit); no fit with n < 15 or < 3 per class, or with
#   separation; no threshold when the likelihood-ratio test gives
#   p >= 0.05 or the slope is negative;
# - threshold t*: the score at which the fitted P(TP) equals the target;
#   none when t* is above the highest reviewed score (target_unreachable).
# pamflow's target is local (P(TP) at the threshold); sheepdog's is the
# precision of all detections kept (at or above the threshold). Both are
# reported: true precision above the cut, true local P(TP) at the cut
# (mean TP of the population within +/- 0.02 of the cut) and recall kept.
#
# Arms: sd_point and sd_cons (two-stage sample of sim_oob.R), pf_same
# (pamflow logistic on that same sample), pf_native and pf_native_logit
# (pamflow on its own sample, same n).
# Two-branch workflow (two_branch, two_branch_ptp): compare_calibration_curves()
# on the two-stage sample (logistic and monotone GAM, bootstrap of the
# disagreement with n_boot_cmp replicates); with "keep_logistic", the
# threshold_precision (two_branch) or threshold_p_tp (two_branch_ptp) of
# the logistic; with "use_monotone_or_weighted", sd_cons; otherwise none.
#   Rscript dev/oob-6b/sim_pamflow.R OUT_RDS [reps] [n_boot] [cores] [n_boot_cmp]
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
a <- commandArgs(TRUE)
out <- a[1]
reps <- if (length(a) > 1) as.integer(a[2]) else 300L
n_boot <- if (length(a) > 2) as.integer(a[3]) else 200L
cores <- if (length(a) > 3) as.integer(a[4]) else 6L
n_boot_cmp <- if (length(a) > 4) as.integer(a[5]) else 100L
targets <- c(0.90, 0.95)
bands <- c(0.1, 0.3, 0.5, 0.7, 0.9, 1.0001)

# Populations and two-stage sample: as in sim_oob.R
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

# pamflow sampling (_allocate_per_bin and _sample_species, "stratified")
allocate <- function(sizes, n) {
  alloc <- integer(length(sizes))
  left <- n
  while (left > 0) {
    open <- which(alloc < sizes)
    if (length(open) == 0) break
    share <- left %/% length(open); extra <- left %% length(open)
    for (i in seq_along(open)) {
      b <- open[i]
      add <- min(share + (i <= extra), sizes[b] - alloc[b])
      alloc[b] <- alloc[b] + add
      left <- left - add
    }
  }
  alloc
}
pamflow_sample <- function(pop, n, n_bins = 5) {
  bin <- cut(pop$confidence, n_bins, labels = FALSE)
  idx <- split(seq_len(nrow(pop)), factor(bin, levels = seq_len(n_bins)))
  k <- allocate(lengths(idx), n)
  pick <- unlist(mapply(\(i, kk) i[sample.int(length(i), kk)], idx, k,
                        SIMPLIFY = FALSE))
  pop[pick, ]
}

# pamflow fit and threshold (fit_precision_models, recommend_thresholds)
pamflow_threshold <- function(d, targets, transform = "identity") {
  none <- rep(NA_real_, length(targets))
  y <- d$tp; s <- d$confidence
  if (length(y) < 15 || sum(y) < 3 || sum(1 - y) < 3) return(none)
  if (min(s[y == 1]) > max(s[y == 0]) || min(s[y == 0]) > max(s[y == 1])) {
    return(none)
  }
  x <- if (transform == "logit") stats::qlogis(pmin(pmax(s, 1e-6), 1 - 1e-6)) else s
  f <- suppressWarnings(stats::glm(y ~ x, family = stats::binomial()))
  b <- stats::coef(f)
  se <- sqrt(diag(stats::vcov(f)))[2]
  if (!f$converged || !is.finite(se) || se > 1e3) return(none)
  p_lr <- stats::pchisq(f$null.deviance - f$deviance, 1, lower.tail = FALSE)
  if (p_lr >= 0.05 || b[2] < 0) return(none)
  fx <- (stats::qlogis(targets) - b[1]) / b[2]
  t_star <- if (transform == "logit") stats::plogis(fx) else fx
  t_star[t_star > max(s)] <- NA_real_   # target_unreachable
  unname(t_star)
}

# True quantities of the population at a cut
truth <- function(pop, cut) {
  if (is.na(cut)) return(c(NA_real_, NA_real_, NA_real_))
  keep <- pop$confidence >= cut
  near <- abs(pop$confidence - cut) <= 0.02
  c(prec = if (any(keep)) mean(pop$tp[keep]) else NA_real_,
    local = if (sum(near) >= 20) mean(pop$tp[near]) else NA_real_,
    recall = sum(pop$tp[keep]) / sum(pop$tp))
}

two_branch <- function(s, t_cons) {
  v <- s
  v$species_folder <- "sp"
  v$source_audio <- v$rec
  cmp <- suppressMessages(suppressWarnings(compare_calibration_curves(
    v, target = targets, curves = c("logistic", "monotone_gam"),
    cv = FALSE, n_boot = n_boot_cmp, seed = 1)))
  lg <- cmp[cmp$curve == "logistic", ]
  lg <- lg[match(targets, lg$target), ]
  keep <- lg$verdict == "keep_logistic"
  other <- lg$verdict == "use_monotone_or_weighted"
  pick <- function(x) ifelse(keep, x, ifelse(other, t_cons, NA_real_))
  list(precision = pick(lg$threshold_precision), p_tp = pick(lg$threshold_p_tp),
       verdict = lg$verdict)
}

one_sample <- function(pop, n) {
  s <- draw_sample(pop, n)
  t_pt <- vapply(targets, \(t) thr(s, t), 0)
  groups <- split(seq_len(nrow(s)), s$rec)
  k <- length(groups)
  boot <- replicate(n_boot, {
    inb <- s[unlist(groups[sample(k, replace = TRUE)], use.names = FALSE), ]
    vapply(targets, \(t) thr(inb, t), 0)
  })
  boot <- matrix(boot, nrow = length(targets))
  t_cons <- apply(boot, 1, \(b) if (mean(!is.na(b)) >= 0.5) {
    unname(stats::quantile(b, 0.95, na.rm = TRUE))
  } else NA_real_)
  pn <- pamflow_sample(pop, n)
  # Two-branch workflow: logistic threshold when compare_calibration_curves()
  # keeps the logistic, conservative threshold when it does not, none
  # otherwise (too few clips, sample more near the threshold, no curve
  # reaches the target)
  cmp <- two_branch(s, t_cons)
  arms <- list(sd_point = t_pt, sd_cons = t_cons,
               two_branch = cmp$precision, two_branch_ptp = cmp$p_tp,
               pf_same = pamflow_threshold(s, targets),
               pf_native = pamflow_threshold(pn, targets),
               pf_native_logit = pamflow_threshold(pn, targets, "logit"))
  do.call(rbind, lapply(names(arms), function(arm) {
    do.call(rbind, lapply(seq_along(targets), function(j) {
      tr <- truth(pop, arms[[arm]][j])
      data.frame(n = n, target = targets[j], arm = arm,
                 cmp_verdict = cmp$verdict[j],
                 threshold = arms[[arm]][j], prec_true = tr[1],
                 local_true = tr[2], recall = tr[3])
    }))
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
  cbind(scen = g$scen, rep = g$rep, one_sample(pops[[g$scen]], g$n))
}, mc.cores = cores, mc.set.seed = TRUE)
res <- do.call(rbind, res)
rownames(res) <- NULL
attr(res, "seconds") <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
saveRDS(res, out)
cat("seconds", attr(res, "seconds"), "\n")
