# Checks of model_mix.stan: per-site log likelihood, R against Stan, on each draw.
suppressPackageStartupMessages(library(cmdstanr))
source("dev/fase2/mix.R")
sim <- simulate_mix(nsite = 60, nocc = 20, frac_verified = 0.05, seed = 1)
dat <- sim$stan
dir <- tempfile(); dir.create(dir)
mod <- cmdstan_model("dev/fase2/model_mix.stan", dir = dir, quiet = TRUE, include_paths = "dev/fase2")
fit <- mod$sample(data = dat, chains = 1, iter_warmup = 100, iter_sampling = 50, seed = 1,
                  refresh = 0, show_messages = FALSE, init = \(chain_id) inits_mix(dat))
dr <- posterior::as_draws_df(fit$draws())
ll <- as.matrix(fit$draws("log_lik", format = "draws_matrix"))
gap <- max(vapply(seq_len(nrow(dr)), \(i) {
  r <- dr[i, ]
  p <- list(beta = c(r$`beta[1]`, r$`beta[2]`), alpha = c(r$`alpha[1]`, r$`alpha[2]`),
            lambda0 = r$lambda0, sigma0 = r$sigma0, sigma0b = r$sigma0b, pi0 = r$pi0,
            mu1a = r$mu1a, mu1b = r$mu1b, sigma1a = r$sigma1a, sigma1b = r$sigma1b, pi1 = r$pi1)
  max(abs(loglik_mix(p, dat) - ll[i, ]))
}, 0))
cat("max |log lik R - Stan| over", nrow(dr), "draws:", gap, "\n")
