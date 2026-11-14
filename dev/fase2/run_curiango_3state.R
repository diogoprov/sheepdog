# Two-stage v1 with persistent f1 components on the Curiango
# (model_v1_3state.stan). Stage 1 emissions from emissions_2stage_curiango.R.
#   Rscript dev/fase2/run_curiango_3state.R OUT_DIR EMIS_RDS [chains] [warmup] [sampling] [rho_comp 1/0]
suppressPackageStartupMessages(library(cmdstanr))
source("dev/fase2/curiango_v1.R")
a <- commandArgs(TRUE)
out <- a[1]; em <- readRDS(a[2])
ch <- if (length(a) > 2) as.integer(a[3]) else 4L
wu <- if (length(a) > 3) as.integer(a[4]) else 1000L
sa <- if (length(a) > 4) as.integer(a[5]) else 1000L
rc <- if (length(a) > 5) as.integer(a[6]) else 0L
dir.create(out, recursive = TRUE, showWarnings = FALSE)
st <- curiango_v1("custom", c_lo = qlogis(0.1))$stan
# log density of one censored normal component, as in emissions_2stage_curiango.R
comp <- function(mu, sd) log(pmax(ifelse(st$cens == 0L, dnorm(st$s, mu, sd),
  ifelse(st$cens == 1L, pnorm(st$c_lo, mu, sd), pnorm(st$c_hi, mu, sd, lower.tail = FALSE))),
  1e-300))
dat <- st[c("N_site", "N_occ", "first", "last", "P_psi", "X", "P_theta", "D", "v", "adj")]
dat$e0 <- em$e0
dat$e1a <- comp(em$f1[["mu_a"]], em$f1[["sd_a"]])
dat$e1b <- comp(em$f1[["mu_b"]], em$f1[["sd_b"]])
dat$rho_comp <- rc
mod <- cmdstan_model("dev/fase2/model_v1_3state.stan", dir = out, quiet = TRUE)
t0 <- Sys.time()
fit <- mod$sample(data = dat, chains = ch, parallel_chains = ch, iter_warmup = wu,
                  iter_sampling = sa, adapt_delta = 0.95, seed = 2026, refresh = 50,
                  init = \(chain_id) list(beta = rep(0, dat$P_psi), alpha = rep(0, dat$P_theta),
                                          rho = rep(0, 1 + rc), xi = qlogis(1 - em$f1[["pi"]]),
                                          tau_h = 0, tau_l = 0),
                  show_exceptions = FALSE)
secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
pars <- c("beta", "alpha", "rho", "xi", "tau_h", "tau_l", "psi_c", "theta0", "theta_bar",
          "p_h", "p_hh", "p_hl")
saveRDS(list(rho_comp = rc, chains = ch, warmup = wu, sampling = sa, seconds = secs,
             emissions = em[c("rate", "f0", "f1", "n_eff")],
             summary = as.data.frame(fit$summary(pars)),
             diag = fit$diagnostic_summary(quiet = TRUE),
             draws = posterior::as_draws_matrix(fit$draws(pars))),
        file.path(out, sprintf("fit_3state%s_%dx%d.rds", if (rc == 1) "_rc" else "", ch, wu + sa)))
cat("seconds", secs, "\n")
