# Phase 2 prototype, model v0: simulator, reference log likelihood in R and
# the Miller likelihood of the thresholded data. See dev/fase2/README.md.

# Simulates one score per occasion, censored below c_lo. `frac_verified` is
# the share of occasions verified at random, whatever their score.
simulate_v0 <- function(nsite = 150, nocc = 20, beta = c(0, -0.8),
                        alpha = c(-0.5, 0.6), lambda0 = -4, delta = 5,
                        sigma0 = 1.5, sigma1 = 1.5, c_lo = qlogis(0.1),
                        c_hi = qlogis(0.9999), frac_verified = 0.05,
                        prior_emissions = 1L, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  x <- as.numeric(scale(rnorm(nsite)))
  d <- as.numeric(scale(rnorm(nsite * nocc)))
  site <- rep(seq_len(nsite), each = nocc)
  z <- rbinom(nsite, 1, plogis(beta[1] + beta[2] * x))
  w <- rbinom(nsite * nocc, 1, z[site] * plogis(alpha[1] + alpha[2] * d))
  s <- rnorm(nsite * nocc, ifelse(w == 1, lambda0 + delta, lambda0),
             ifelse(w == 1, sigma1, sigma0))
  cens <- ifelse(s < c_lo, 1L, ifelse(s > c_hi, 2L, 0L))
  verified <- runif(nsite * nocc) < frac_verified
  list(
    stan = list(
      N_site = nsite, N_occ = nsite * nocc,
      first = (seq_len(nsite) - 1L) * nocc + 1L,
      last = seq_len(nsite) * nocc,
      P_psi = 2L, X = cbind(1, x), P_theta = 2L, D = cbind(1, d),
      s = ifelse(cens == 0L, s, 0), cens = cens,
      v = ifelse(verified, w, -1L), c_lo = c_lo, c_hi = c_hi,
      prior_emissions = prior_emissions
    ),
    truth = list(z = z, w = w, s = s, site = site)
  )
}

# The same data with the score replaced by y = 1[s > c]. Both censoring
# points move to c, so that every occasion is censored on one side.
threshold_data <- function(sim, c = qlogis(0.5)) {
  dat <- sim$stan
  y <- as.integer(sim$truth$s > c)
  dat$cens <- ifelse(y == 1L, 2L, 1L)
  dat$s <- rep(0, dat$N_occ)
  dat$c_lo <- c
  dat$c_hi <- c
  dat$v <- rep(-1L, dat$N_occ)
  list(stan = dat, y = y)
}

# Per-site log likelihood of v0, on the probability scale and written apart
# from the Stan code. `p` has beta, alpha, lambda0, delta, sigma0, sigma1.
loglik_v0 <- function(p, dat) {
  psi <- plogis(drop(dat$X %*% p$beta))
  theta <- plogis(drop(dat$D %*% p$alpha))
  mu0 <- p$lambda0
  mu1 <- p$lambda0 + p$delta
  f <- function(mu, sigma) {
    ifelse(dat$cens == 0L, dnorm(dat$s, mu, sigma),
           ifelse(dat$cens == 1L, pnorm(dat$c_lo, mu, sigma),
                  pnorm(dat$c_hi, mu, sigma, lower.tail = FALSE)))
  }
  e0 <- f(mu0, p$sigma0)
  e1 <- f(mu1, p$sigma1)
  occupied <- ifelse(dat$v == 1L, theta * e1,
                     ifelse(dat$v == 0L, (1 - theta) * e0,
                            theta * e1 + (1 - theta) * e0))
  empty <- ifelse(dat$v == 1L, 0, e0)
  vapply(seq_len(dat$N_site), \(i) {
    k <- dat$first[i]:dat$last[i]
    log(psi[i] * prod(occupied[k]) + (1 - psi[i]) * prod(empty[k]))
  }, numeric(1))
}

# Miller-type likelihood of y, with p10 and p11 implied by the components:
# p10 = 1 - F0(c), p11 = theta (1 - F1(c)) + (1 - theta) p10.
loglik_miller <- function(p, dat, y) {
  psi <- plogis(drop(dat$X %*% p$beta))
  theta <- plogis(drop(dat$D %*% p$alpha))
  p10 <- pnorm(dat$c_lo, p$lambda0, p$sigma0, lower.tail = FALSE)
  p1 <- pnorm(dat$c_lo, p$lambda0 + p$delta, p$sigma1, lower.tail = FALSE)
  p11 <- theta * p1 + (1 - theta) * p10
  miller_sites(psi, p11, rep(p10, dat$N_occ), y, dat$first, dat$last)
}

miller_sites <- function(psi, p11, p10, y, first, last) {
  vapply(seq_along(psi), \(i) {
    k <- first[i]:last[i]
    log(psi[i] * prod(p11[k]^y[k] * (1 - p11[k])^(1 - y[k])) +
          (1 - psi[i]) * prod(p10[k]^y[k] * (1 - p10[k])^(1 - y[k])))
  }, numeric(1))
}

# Initial values from the verified occasions, as Rhinehart et al. (2022)
# suggest: most of their failures came from a poor start of mu1.
inits_v0 <- function(dat, chain_id = 1) {
  obs <- dat$cens == 0L
  neg <- dat$s[obs & dat$v == 0L]
  pos <- dat$s[obs & dat$v == 1L]
  l0 <- if (length(neg) > 2) mean(neg) else dat$c_lo - 1
  m1 <- if (length(pos) > 2) mean(pos) else dat$c_lo + 3
  list(beta = c(0, rep(0, dat$P_psi - 1)),
       alpha = c(0, rep(0, dat$P_theta - 1)),
       lambda0 = l0, delta = max(m1 - l0, 1), sigma0 = 1, sigma1 = 1)
}
