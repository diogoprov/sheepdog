# Two-stage v1 on the Curiango: stage 1 emissions (emissions_2stage_curiango.R)
# fixed, then model_v1_2stage.stan with or without the Markov term.
#   Rscript dev/fase2/run_curiango_2stage.R OUT_DIR EMIS_RDS [markov 1/0] [chains] [warmup] [sampling]
suppressPackageStartupMessages(library(cmdstanr))
source("dev/fase2/curiango_v1.R")
a <- commandArgs(TRUE)
out <- a[1]; em <- readRDS(a[2])
mk <- if (length(a) > 2) as.integer(a[3]) else 1L
ch <- if (length(a) > 3) as.integer(a[4]) else 4L
wu <- if (length(a) > 4) as.integer(a[5]) else 1000L
sa <- if (length(a) > 5) as.integer(a[6]) else 1000L
dir.create(out, recursive = TRUE, showWarnings = FALSE)
st <- curiango_v1("custom", c_lo = qlogis(0.1))$stan
dat <- st[c("N_site", "N_occ", "first", "last", "P_psi", "X", "P_theta", "D", "v", "adj")]
dat$e0 <- em$e0; dat$e1 <- em$e1; dat$markov <- mk
mod <- cmdstan_model("dev/fase2/model_v1_2stage.stan", dir = out, quiet = TRUE)
t0 <- Sys.time()
fit <- mod$sample(data = dat, chains = ch, parallel_chains = ch, iter_warmup = wu,
                  iter_sampling = sa, adapt_delta = 0.95, seed = 2026, refresh = 50,
                  init = \(chain_id) list(beta = rep(0, dat$P_psi), alpha = rep(0, dat$P_theta),
                                          rho = rep(0, mk)),
                  show_exceptions = FALSE)
secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
pars <- c("beta", "alpha", if (mk == 1) "rho", "psi_c", "theta0", "theta_bar")
saveRDS(list(markov = mk, chains = ch, warmup = wu, sampling = sa, seconds = secs,
             emissions = em[c("rate", "f0", "f1", "n_eff")],
             summary = as.data.frame(fit$summary(pars)),
             diag = fit$diagnostic_summary(quiet = TRUE),
             draws = posterior::as_draws_matrix(fit$draws(pars))),
        file.path(out, sprintf("fit_2stage_m%d_%dx%d.rds", mk, ch, wu + sa)))
cat("seconds", secs, "\n")
