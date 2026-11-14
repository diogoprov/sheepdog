# Model v1 (mixture + Markov) on the Curiango. Run from the root:
#   Rscript dev/fase2/run_curiango_v1.R OUT_DIR [classifier] [c] [chains] [warmup] [sampling] [model]
# A short run (1 chain, 150 + 50) measures the time before the full fit.
# model = "mix" fits model_mix.stan (same data, no Markov), to isolate it.
suppressPackageStartupMessages(library(cmdstanr))
source("dev/fase2/v1.R"); source("dev/fase2/curiango_v1.R")
a <- commandArgs(TRUE)
out <- a[1]; cl <- if (length(a) > 1) a[2] else "custom"
cc <- if (length(a) > 2) as.numeric(a[3]) else 0.1
ch <- if (length(a) > 3) as.integer(a[4]) else 4L
wu <- if (length(a) > 4) as.integer(a[5]) else 1000L
sa <- if (length(a) > 5) as.integer(a[6]) else 1000L
md <- if (length(a) > 6) a[7] else "v1"
markov <- md == "v1"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
d <- curiango_v1(cl, c_lo = qlogis(cc)); dat <- d$stan
cat("site-nights", dat$N_site, " minutes", dat$N_occ, " adjacent", mean(dat$adj),
    " verified", sum(dat$v >= 0), " positives", sum(dat$v == 1), "\n")
source("dev/fase2/sim_mixid.R")  # inits_mixid()
mod <- cmdstan_model(sprintf("dev/fase2/model_%s.stan", md), dir = out, quiet = TRUE,
                     include_paths = "dev/fase2")
t0 <- Sys.time()
fit <- mod$sample(data = dat, chains = ch, parallel_chains = ch, iter_warmup = wu,
                  iter_sampling = sa, adapt_delta = 0.95, seed = 2026, refresh = 25,
                  init = \(chain_id) if (markov) inits_v1(dat) else inits_mixid(dat),
                  show_exceptions = FALSE)
secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
pars <- c("beta", "alpha", if (markov) c("rho", "theta0", "theta_bar"), "lambda0",
          "sigma0", "sigma0b", "pi0", "mu1a", "mu1b", "sigma1a", "sigma1b", "pi1")
dr <- posterior::as_draws_matrix(fit$draws(pars))
saveRDS(list(classifier = cl, c = cc, chains = ch, warmup = wu, sampling = sa,
             seconds = secs, time = fit$time(),
             summary = as.data.frame(fit$summary(pars)),
             diag = fit$diagnostic_summary(quiet = TRUE),
             sampler = posterior::as_draws_df(fit$sampler_diagnostics()),
             draws = dr),
        file.path(out, sprintf("fit_%s_%s_%g_%dx%d.rds", md, cl, cc, ch, wu + sa)))
cat("seconds", secs, "\n")
