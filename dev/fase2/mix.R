# Simulator and reference log likelihood of model_mix.stan, written apart from
# the Stan code. Defaults for the emissions: maximum likelihood on the verified
# minutes of the custom classifier (dev/fase2/emissions_family_curiango.R).
em_curiango <- list(lambda0 = -2.17, sigma0 = 0.33, sigma0b = 1.22, pi0 = 0.87,
                    mu1a = -1.47, mu1b = 1.19, sigma1a = 0.41, sigma1b = 1.42, pi1 = 0.25)

simulate_mix <- function(nsite = 300, nocc = 56, beta = c(0, -0.8), alpha = c(-0.5, 0.6),
                         em = em_curiango, c_lo = qlogis(0.1), c_hi = qlogis(0.9999),
                         frac_verified = 0.012, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  x <- as.numeric(scale(rnorm(nsite)))
  d <- as.numeric(scale(rnorm(nsite * nocc)))
  site <- rep(seq_len(nsite), each = nocc)
  n <- nsite * nocc
  z <- rbinom(nsite, 1, plogis(beta[1] + beta[2] * x))
  w <- rbinom(n, 1, z[site] * plogis(alpha[1] + alpha[2] * d))
  core <- runif(n) < em$pi0
  low <- runif(n) < em$pi1
  s <- ifelse(w == 1,
              rnorm(n, ifelse(low, em$mu1a, em$mu1b), ifelse(low, em$sigma1a, em$sigma1b)),
              rnorm(n, em$lambda0, ifelse(core, em$sigma0, em$sigma0b)))
  cens <- ifelse(s < c_lo, 1L, ifelse(s > c_hi, 2L, 0L))
  verified <- runif(n) < frac_verified
  list(stan = list(N_site = nsite, N_occ = n,
                   first = (seq_len(nsite) - 1L) * nocc + 1L, last = seq_len(nsite) * nocc,
                   P_psi = 2L, X = cbind(1, x), P_theta = 2L, D = cbind(1, d),
                   s = ifelse(cens == 0L, s, 0), cens = cens,
                   v = ifelse(verified, w, -1L), c_lo = c_lo, c_hi = c_hi),
       truth = list(z = z, w = w, s = s, site = site))
}

loglik_mix <- function(p, dat) {
  psi <- plogis(drop(dat$X %*% p$beta))
  theta <- plogis(drop(dat$D %*% p$alpha))
  one <- function(mu, sd) ifelse(dat$cens == 0L, dnorm(dat$s, mu, sd),
    ifelse(dat$cens == 1L, pnorm(dat$c_lo, mu, sd), pnorm(dat$c_hi, mu, sd, lower.tail = FALSE)))
  e0 <- p$pi0 * one(p$lambda0, p$sigma0) + (1 - p$pi0) * one(p$lambda0, p$sigma0b)
  e1 <- p$pi1 * one(p$mu1a, p$sigma1a) + (1 - p$pi1) * one(p$mu1b, p$sigma1b)
  occupied <- ifelse(dat$v == 1L, theta * e1, ifelse(dat$v == 0L, (1 - theta) * e0,
                                                     theta * e1 + (1 - theta) * e0))
  empty <- ifelse(dat$v == 1L, 0, e0)
  vapply(seq_len(dat$N_site), \(i) {
    k <- dat$first[i]:dat$last[i]
    # sums of logs: a product over 56 occasions can underflow
    a <- log(psi[i]) + sum(log(occupied[k])); b <- log(1 - psi[i]) + sum(log(empty[k]))
    m <- max(a, b); m + log(exp(a - m) + exp(b - m))
  }, numeric(1))
}

inits_mix <- function(dat, em = em_curiango) {
  list(beta = rep(0, dat$P_psi), alpha = rep(0, dat$P_theta), lambda0 = em$lambda0,
       sigma0 = em$sigma0, tail0 = em$sigma0b - em$sigma0, pi0 = em$pi0,
       d1 = em$mu1a - em$lambda0, gap = em$mu1b - em$mu1a, sigma1a = em$sigma1a,
       sigma1b = em$sigma1b, pi1 = em$pi1)
}
