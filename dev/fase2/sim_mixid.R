# Identification simulation of model_mix.stan (PLANO-identificacao-mistura.md).
# Reuses the data sets and selections of the ignorability simulation, with the
# same seeds, so every fit pairs with the v0 fit of results/ignorab_v0.

source("dev/fase2/sim_ignorab.R")

# Stan data for model_mix.stan; `verified` are indices (empty for none).
stan_mixid <- function(sim, verified = integer()) {
  dat <- stan_ignorab(sim, verified, with_h = TRUE)
  dat$prior_emissions <- NULL
  dat
}

# Inits away from the truth: generic shapes, centred on the verified scores
# when there are enough of them.
inits_mixid <- function(dat) {
  obs <- dat$cens == 0L
  neg <- dat$s[obs & dat$v == 0L]
  l0 <- if (length(neg) > 2) mean(neg) else dat$c_lo - 1
  list(beta = rep(0, dat$P_psi), alpha = rep(0, dat$P_theta), lambda0 = l0,
       sigma0 = 0.5, tail0 = 0.5, pi0 = 0.8, d1 = 0.5, gap = 2,
       sigma1a = 0.5, sigma1b = 1, pi1 = 0.5)
}

# Per data set: 2 fractions x (S1, S2) and one fit without verification.
mixid_designs <- c("S1", "S2")
mixid_grid <- function(n_reps) {
  sets <- expand.grid(rep = seq_len(n_reps), truth = c("normal", "mixture"),
                      stringsAsFactors = FALSE)
  # the same set numbers as ig_grid(), so the seeds match
  sets$set <- seq_len(nrow(sets))
  arms <- rbind(expand.grid(frac = c(0.05, 0.02), design = mixid_designs,
                            stringsAsFactors = FALSE),
                data.frame(frac = 0, design = "none"))
  g <- merge(sets, arms, by = NULL)
  g <- g[order(g$set, g$frac, g$design), ]
  g$id <- seq_len(nrow(g))
  rownames(g) <- NULL
  g
}

mixid_pars <- c("beta[1]", "beta[2]", "alpha[1]", "alpha[2]", "alpha[3]",
                "lambda0", "sigma0", "sigma0b", "pi0", "mu1a", "mu1b",
                "sigma1a", "sigma1b", "pi1")
mixid_truth <- function(truth) {
  p <- c(psi = 0.5, theta = 0.3, `beta[1]` = 0, `beta[2]` = -0.8,
         `alpha[1]` = qlogis(0.3), `alpha[2]` = 0.6, `alpha[3]` = 1)
  if (truth == "mixture") p <- c(p, unlist(ig_truth$mixture))
  p
}
