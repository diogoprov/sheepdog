# Ignorability simulation (phase 2, step 4): simulator with an hour covariate
# and two emission truths, the five selection designs, and the Stan data.
# The design and the criteria are in dev/fase2/PLANO-ignorabilidade.md.

source("dev/fase2/v0.R")

ig_truth <- list(
  normal = list(lambda0 = -2.16, delta = 1.29, sigma0 = 0.35, sigma1 = 1.49),
  mixture = list(lambda0 = -2.2, sigma0 = 0.26, sigma0b = 0.61, pi0 = 0.85,
                 mu1a = -1.45, mu1b = 0.91, sigma1a = 0.41, sigma1b = 1.42,
                 pi1 = 0.78)
)
ig_par <- list(nsite = 150, nocc = 20, beta = c(0, -0.8),
               alpha = c(qlogis(0.3), 0.6, 1), p_h = 0.25,
               c_lo = qlogis(0.1), c_hi = qlogis(0.9999))

# Copies of pps_inclusion() and systematic_pps() in R/select_directed.R; the
# AWS run ships only dev/fase2, so they are repeated here.
pps_inclusion <- function(x, n) {
  p <- numeric(length(x))
  fixed <- rep(FALSE, length(x))
  repeat {
    p[!fixed] <- (n - sum(fixed)) * x[!fixed] / sum(x[!fixed])
    new <- !fixed & p >= 1
    if (!any(new)) break
    fixed[new] <- TRUE
    p[new] <- 1
  }
  p
}
systematic_pps <- function(p) {
  n <- round(sum(p))
  ord <- sample.int(length(p))
  cum <- cumsum(p[ord])
  pts <- stats::runif(1) + 0:(n - 1)
  pos <- findInterval(pts, cum, left.open = TRUE) + 1L
  ord[pmin(pos, length(p))]
}

# One data set, no verification. `truth` is "normal" or "mixture".
simulate_ignorab <- function(truth = c("normal", "mixture"), seed,
                             par = ig_par) {
  truth <- match.arg(truth)
  set.seed(seed)
  n <- par$nsite * par$nocc
  x <- as.numeric(scale(rnorm(par$nsite)))
  d <- as.numeric(scale(rnorm(n)))
  h <- rbinom(n, 1, par$p_h)
  site <- rep(seq_len(par$nsite), each = par$nocc)
  z <- rbinom(par$nsite, 1, plogis(par$beta[1] + par$beta[2] * x))
  theta <- plogis(par$alpha[1] + par$alpha[2] * d + par$alpha[3] * h)
  w <- rbinom(n, 1, z[site] * theta)
  em <- ig_truth[[truth]]
  if (truth == "normal") {
    s <- rnorm(n, ifelse(w == 1, em$lambda0 + em$delta, em$lambda0),
               ifelse(w == 1, em$sigma1, em$sigma0))
  } else {
    core <- runif(n) < em$pi0
    low <- runif(n) < em$pi1
    s <- ifelse(w == 1,
                rnorm(n, ifelse(low, em$mu1a, em$mu1b),
                      ifelse(low, em$sigma1a, em$sigma1b)),
                rnorm(n, em$lambda0, ifelse(core, em$sigma0, em$sigma0b)))
  }
  cens <- ifelse(s < par$c_lo, 1L, ifelse(s > par$c_hi, 2L, 0L))
  list(truth = truth, par = par, x = x, d = d, h = h, site = site, z = z,
       w = w, s = s, cens = cens)
}

# Which occasions are verified under each design, with the same n in all.
# Returns the indices and the inclusion probability of every occasion.
ig_designs <- c("S1", "S2", "S3", "S4", "S5")
select_ignorab <- function(sim, design, frac, seed) {
  set.seed(seed)
  N <- length(sim$s)
  n <- round(frac * N)
  s_obs <- ifelse(sim$cens == 0L, sim$s,
                  ifelse(sim$cens == 1L, sim$par$c_lo, sim$par$c_hi))
  pps <- function(size) {
    p <- pps_inclusion(size, n)
    list(idx = sort(systematic_pps(p)), pi = p)
  }
  switch(design,
    S1 = list(idx = sort(sample.int(N, n)), pi = rep(n / N, N)),
    S2 = {
      size <- plogis(s_obs)
      pps(size + 0.05 * mean(size))
    },
    S3 = {
      idx <- order(s_obs, runif(N), decreasing = TRUE)[seq_len(n)]
      pi <- numeric(N); pi[idx] <- 1
      list(idx = sort(idx), pi = pi)
    },
    S4 = pps(ifelse(sim$h == 1, 3, 1)),
    S5 = pps(ifelse(sim$w == 1, 5, 1)),
    stop("unknown design ", design)
  )
}

# Stan data for model_v0.stan; `verified` are indices (empty for none).
stan_ignorab <- function(sim, verified = integer(), with_h = TRUE) {
  par <- sim$par
  v <- rep(-1L, length(sim$s))
  v[verified] <- sim$w[verified]
  D <- if (with_h) cbind(1, sim$d, sim$h) else cbind(1, sim$d)
  list(N_site = par$nsite, N_occ = length(sim$s),
       first = (seq_len(par$nsite) - 1L) * par$nocc + 1L,
       last = seq_len(par$nsite) * par$nocc,
       P_psi = 2L, X = cbind(1, sim$x), P_theta = ncol(D), D = D,
       s = ifelse(sim$cens == 0L, sim$s, 0), cens = sim$cens, v = v,
       c_lo = par$c_lo, c_hi = par$c_hi, prior_emissions = 1L)
}

# The fits of the plan: per data set, 2 fractions x (S1-S5 with h, S1 and S4
# without h) plus one fit without verification. One row per fit.
ig_grid <- function(n_reps) {
  sets <- expand.grid(rep = seq_len(n_reps), truth = c("normal", "mixture"),
                      stringsAsFactors = FALSE)
  sets$set <- seq_len(nrow(sets))
  arms <- rbind(
    expand.grid(frac = c(0.05, 0.02), design = ig_designs, with_h = TRUE,
                stringsAsFactors = FALSE),
    expand.grid(frac = c(0.05, 0.02), design = c("S1", "S4"), with_h = FALSE,
                stringsAsFactors = FALSE),
    data.frame(frac = 0, design = "none", with_h = TRUE)
  )
  g <- merge(sets, arms, by = NULL)
  g <- g[order(g$set, g$frac, g$design, !g$with_h), ]
  g$id <- seq_len(nrow(g))
  rownames(g) <- NULL
  g
}

# Seeds: the data depend only on the set; the selection on the set, the
# fraction and the design (the same selection with and without h).
ig_seed_data <- function(set) 2026L * 1000L + set
ig_seed_sel <- function(set, frac, design) {
  2026L * 100000L + set * 100L + round(frac * 100) * 10L +
    match(design, ig_designs, nomatch = 0L)
}
