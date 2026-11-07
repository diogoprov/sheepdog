# Probes the cell that failed coverage in the second validation of v0, without
# Stan: maximum likelihood with loglik_v0, free and with the emissions fixed at
# the truth, in many more data sets than the MCMC grid can afford.
#   Rscript dev/fase2/probe_cell_v0.R OUT_FILE [N_SETS] [N_WORKERS]
suppressPackageStartupMessages(library(parallel))
source("dev/fase2/v0.R")
args <- commandArgs(TRUE)
out <- args[1]
nset <- if (length(args) > 1) as.integer(args[2]) else 500L
workers <- if (length(args) > 2) as.integer(args[3]) else 10L

unpack <- function(q, em = NULL) {
  p <- list(beta = q[1:2], alpha = q[3:4])
  if (is.null(em)) em <- list(lambda0 = q[5], delta = exp(q[6]),
                              sigma0 = exp(q[7]), sigma1 = exp(q[8]))
  c(p, em)
}

fit_ml <- function(dat, start, em = NULL) {
  nll <- function(q) {
    v <- -sum(loglik_v0(unpack(q, em), dat))
    if (is.finite(v)) v else 1e10
  }
  o <- optim(start, nll, method = "BFGS",
             control = list(maxit = 500, reltol = 1e-9))
  h <- optimHess(o$par, nll)
  se <- tryCatch(sqrt(diag(solve(h))), error = \(e) rep(NA_real_, length(o$par)))
  list(par = o$par, se = se, conv = o$convergence)
}

run_set <- function(g) {
  sim <- simulate_v0(beta = c(0, -0.8), alpha = c(qlogis(g$theta), 0.6),
                     delta = g$delta, frac_verified = g$frac, seed = g$seed)
  dat <- sim$stan
  truth <- c(0, -0.8, qlogis(g$theta), 0.6)
  em <- list(lambda0 = -4, delta = g$delta, sigma0 = 1.5, sigma1 = 1.5)
  free <- fit_ml(dat, c(truth, -4, log(g$delta), log(1.5), log(1.5)))
  fixed <- fit_ml(dat, truth, em)
  row <- function(f, kind) data.frame(
    g, kind = kind, est = f$par[3], se = f$se[3], psi = f$par[1],
    lambda0 = if (length(f$par) > 4) f$par[5] else -4,
    delta = if (length(f$par) > 4) exp(f$par[6]) else g$delta,
    sigma0 = if (length(f$par) > 4) exp(f$par[7]) else 1.5,
    sigma1 = if (length(f$par) > 4) exp(f$par[8]) else 1.5, conv = f$conv)
  rbind(row(free, "free"), row(fixed, "fixed"))
}

grid <- expand.grid(theta = c(0.6, 0.3), frac = c(0.05, 0.2), delta = c(3, 5),
                    rep = seq_len(nset))
grid$seed <- 100000L + seq_len(nrow(grid))  # new data, apart from the grid ids
res <- mclapply(split(grid, seq_len(nrow(grid))), \(g)
                tryCatch(run_set(g), error = \(e) NULL),
                mc.cores = workers, mc.preschedule = TRUE)
saveRDS(do.call(rbind, res), out)
cat("sets:", nrow(grid), " returned:", sum(!vapply(res, is.null, TRUE)), "\n")
