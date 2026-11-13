# Checks of model_v1.stan:
# 1. per-site log likelihood, R forward algorithm against Stan, on each draw;
# 2. with rho = 0, the R forward algorithm equals loglik_mix() of mix.R;
# 3. the simulator gives runs: P(w = 1 | previous w = 1) above P(w = 1).
suppressPackageStartupMessages(library(cmdstanr))
source("dev/fase2/v1.R")
source("dev/fase2/mix.R")

sim <- simulate_v1("mixture", seed = 1, par = modifyList(v1_par, list(nsite = 60)))
ver <- select_ignorab(sim, "S2", 0.05, seed = 2)$idx
dat <- stan_v1(sim, ver)

occ <- sim$z[sim$site] == 1L
pr <- sim$adj == 1L & occ
cat(sprintf("simulated runs: P(w=1) = %.3f in occupied sites, P(w=1 | prev w=1) = %.3f\n",
            mean(sim$w[occ]), mean(sim$w[which(pr)][sim$w[which(pr) - 1L] == 1L])))

dir <- tempfile(); dir.create(dir)
mod <- cmdstan_model("dev/fase2/model_v1.stan", dir = dir, quiet = TRUE,
                     include_paths = "dev/fase2")
fit <- mod$sample(data = dat, chains = 1, iter_warmup = 150, iter_sampling = 50,
                  seed = 1, refresh = 0, show_messages = FALSE,
                  init = \(chain_id) inits_v1(dat))
dr <- posterior::as_draws_df(fit$draws())
ll <- as.matrix(fit$draws("log_lik", format = "draws_matrix"))
par_of <- function(r, rho = r$rho) list(
  beta = c(r$`beta[1]`, r$`beta[2]`),
  alpha = c(r$`alpha[1]`, r$`alpha[2]`, r$`alpha[3]`), rho = rho,
  lambda0 = r$lambda0, sigma0 = r$sigma0, sigma0b = r$sigma0b, pi0 = r$pi0,
  mu1a = r$mu1a, mu1b = r$mu1b, sigma1a = r$sigma1a, sigma1b = r$sigma1b,
  pi1 = r$pi1)
gap1 <- max(vapply(seq_len(nrow(dr)), \(i)
  max(abs(loglik_v1(par_of(dr[i, ]), dat) - ll[i, ])), 0))
gap2 <- max(vapply(seq_len(10), \(i) {
  p <- par_of(dr[i, ], rho = 0)
  max(abs(loglik_v1(p, dat) - loglik_mix(p, dat)))
}, 0))
cat("1. max |log lik R - Stan| over", nrow(dr), "draws:", signif(gap1, 3), "\n")
cat("2. max |forward with rho = 0 - loglik_mix| over 10 draws:", signif(gap2, 3), "\n")
cat("posterior mean of rho in this short run:", round(mean(dr$rho), 2),
    "(simulated", v1_par$rho, ")\n")
stopifnot(gap1 < 1e-5, gap2 < 1e-8)
