# Simulator and reference log likelihood of model_v1.stan (mixture emissions
# and a Markov term on w within the night), written apart from the Stan code.
# Reuses the truths, the selections and the seeds of sim_ignorab.R.

source("dev/fase2/sim_ignorab.R")

v1_par <- modifyList(ig_par, list(rho = 2, p_gap = 0.04))

# One data set. `adj` marks occasions whose previous occasion is the previous
# step of the same site (the Curiango has a gap before about 4% of minutes).
simulate_v1 <- function(truth = c("normal", "mixture"), seed, par = v1_par) {
  truth <- match.arg(truth)
  set.seed(seed)
  n <- par$nsite * par$nocc
  x <- as.numeric(scale(rnorm(par$nsite)))
  d <- as.numeric(scale(rnorm(n)))
  h <- rbinom(n, 1, par$p_h)
  site <- rep(seq_len(par$nsite), each = par$nocc)
  k <- rep(seq_len(par$nocc), par$nsite)
  adj <- as.integer(k > 1 & runif(n) >= par$p_gap)
  z <- rbinom(par$nsite, 1, plogis(par$beta[1] + par$beta[2] * x))
  eta <- par$alpha[1] + par$alpha[2] * d + par$alpha[3] * h
  w <- integer(n)
  u <- runif(n)
  for (i in seq_len(n)) {
    prev <- if (adj[i] == 1L) w[i - 1L] else 0L
    w[i] <- as.integer(z[site[i]] == 1L && u[i] < plogis(eta[i] + par$rho * prev))
  }
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
       w = w, s = s, cens = cens, adj = adj)
}

# Stan data for model_v1.stan (and model_mix.stan, which ignores `adj`).
stan_v1 <- function(sim, verified = integer()) {
  dat <- stan_ignorab(sim, verified, with_h = TRUE)
  dat$prior_emissions <- NULL
  dat$adj <- sim$adj
  dat
}

# Per-site log likelihood by the forward algorithm, in R.
loglik_v1 <- function(p, dat) {
  psi <- plogis(drop(dat$X %*% p$beta))
  eta <- drop(dat$D %*% p$alpha)
  one <- function(mu, sd) ifelse(dat$cens == 0L, dnorm(dat$s, mu, sd),
    ifelse(dat$cens == 1L, pnorm(dat$c_lo, mu, sd), pnorm(dat$c_hi, mu, sd, lower.tail = FALSE)))
  e0 <- p$pi0 * one(p$lambda0, p$sigma0) + (1 - p$pi0) * one(p$lambda0, p$sigma0b)
  e1 <- p$pi1 * one(p$mu1a, p$sigma1a) + (1 - p$pi1) * one(p$mu1b, p$sigma1b)
  vapply(seq_len(dat$N_site), \(i) {
    ks <- dat$first[i]:dat$last[i]
    f <- c(1, 0)  # forward probabilities of (w = 1, w = 0), rescaled
    logc <- 0
    for (j in seq_along(ks)) {
      k <- ks[j]
      if (j == 1L || dat$adj[k] == 0L) {
        tot <- if (j == 1L) 1 else sum(f)
        g <- tot * c(plogis(eta[k]), 1 - plogis(eta[k]))
      } else {
        p1 <- c(plogis(eta[k] + p$rho), plogis(eta[k]))   # from w = 1, w = 0
        g <- c(sum(f * p1), sum(f * (1 - p1)))
      }
      g <- g * c(e1[k], e0[k]) * c(dat$v[k] != 0L, dat$v[k] != 1L)
      m <- sum(g); logc <- logc + log(m); f <- g / m
    }
    a <- log(psi[i]) + logc
    b <- if (any(dat$v[ks] == 1L)) -Inf else log(1 - psi[i]) + sum(log(e0[ks]))
    mx <- max(a, b); mx + log(exp(a - mx) + exp(b - mx))
  }, numeric(1))
}

inits_v1 <- function(dat) {
  obs <- dat$cens == 0L
  neg <- dat$s[obs & dat$v == 0L]
  l0 <- if (length(neg) > 2) mean(neg) else dat$c_lo - 1
  list(beta = rep(0, dat$P_psi), alpha = rep(0, dat$P_theta), rho = 0,
       lambda0 = l0, sigma0 = 0.5, tail0 = 0.5, pi0 = 0.8, d1 = 0.5, gap = 2,
       sigma1a = 0.5, sigma1b = 1, pi1 = 0.5)
}

# Calling rate at the centre: after a gap and stationary within a run.
v1_theta <- function(alpha0, rho) {
  t0 <- plogis(alpha0)
  c(theta0 = t0, theta_bar = t0 / (1 - plogis(alpha0 + rho) + t0))
}

# Validation grid (PLANO-v1-markov.md): per data set, 2 fractions (PPS) x
# 2 models (v1 and model_mix, no Markov), on the same data and selection.
v1_alpha0 <- c(`0` = qlogis(0.3), `2` = qlogis(0.15))
v1_grid <- function(n_reps) {
  sets <- expand.grid(rep = seq_len(n_reps), rho = c(0, 2))
  sets$set <- seq_len(nrow(sets))
  arms <- expand.grid(frac = c(0.05, 0.02), model = c("v1", "mix"),
                      stringsAsFactors = FALSE)
  g <- merge(sets, arms, by = NULL)
  g <- g[order(g$set, g$frac, g$model), ]
  g$id <- seq_len(nrow(g))
  rownames(g) <- NULL
  g
}
v1_seed_data <- function(set) 2026L * 10000L + set
v1_seed_sel <- function(set, frac) 2026L * 100000L + set * 100L + round(frac * 100)
v1_sim_par <- function(rho) {
  p <- v1_par
  p$rho <- rho
  p$alpha <- c(v1_alpha0[[as.character(rho)]], ig_par$alpha[2:3])
  p
}
