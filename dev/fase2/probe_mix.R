# One recovery of model_mix.stan with the emissions of the Curiango and few
# verified minutes. A sanity check and a timing, not a validation.
#   Rscript dev/fase2/probe_mix.R OUT_DIR [NSITE] [FRAC] [SEED]
suppressPackageStartupMessages(library(cmdstanr))
source("dev/fase2/mix.R")
a <- commandArgs(TRUE); out <- a[1]
ns <- if (length(a) > 1) as.integer(a[2]) else 300L
fr <- if (length(a) > 2) as.numeric(a[3]) else 0.012
sd <- if (length(a) > 3) as.integer(a[4]) else 1L
dir.create(out, recursive = TRUE, showWarnings = FALSE)
sim <- simulate_mix(nsite = ns, frac_verified = fr, seed = sd); dat <- sim$stan
cat("occasions", dat$N_occ, " verified", sum(dat$v >= 0), " positives", sum(dat$v == 1), "\n")
mod <- cmdstan_model("dev/fase2/model_mix.stan", dir = out, quiet = TRUE, include_paths = "dev/fase2")
t0 <- Sys.time()
fit <- mod$sample(data = dat, chains = 4, parallel_chains = 4, iter_warmup = 1000, iter_sampling = 1000,
                  adapt_delta = 0.95, seed = sd, refresh = 0, show_messages = FALSE, show_exceptions = FALSE,
                  init = \(chain_id) inits_mix(dat))
p <- c("beta", "alpha", "lambda0", "sigma0", "sigma0b", "pi0", "mu1a", "mu1b", "sigma1a", "sigma1b", "pi1")
sm <- as.data.frame(fit$summary(p, "mean", ~quantile(.x, c(.025, .975)), "rhat", "ess_bulk"))
sm$truth <- c(0, -0.8, -0.5, 0.6, unlist(em_curiango[c("lambda0", "sigma0", "sigma0b", "pi0", "mu1a", "mu1b", "sigma1a", "sigma1b", "pi1")]))
print(sm, digits = 3)
cat("minutes", as.numeric(difftime(Sys.time(), t0, units = "mins")), " divergences",
    sum(fit$diagnostic_summary(quiet = TRUE)$num_divergent), "\n")
saveRDS(sm, file.path(out, sprintf("probe_%d_%g_%d.rds", ns, fr, sd)))
