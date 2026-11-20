# Joint v1 on the Curiango with informative priors on f1 from the night
# bootstrap of the stage 1 emissions (model_v1_prior1.stan). All minutes enter
# as unverified (v = -1): the verified labels enter only through the prior.
# Saves in the format of run_curiango_2stage.R (emissions at the posterior
# medians, rho as rho[1]) so that ppc_curiango_2stage.R runs on it; that PPC
# then fixes the emissions at their medians.
#   Rscript dev/fase2/run_curiango_v1prior.R OUT_DIR EMIS_RDS [chains] [warmup] [sampling]
suppressPackageStartupMessages(library(cmdstanr))
source("dev/fase2/v1.R"); source("dev/fase2/curiango_v1.R")
a <- commandArgs(TRUE)
out <- a[1]; em <- readRDS(a[2])
ch <- if (length(a) > 2) as.integer(a[3]) else 4L
wu <- if (length(a) > 3) as.integer(a[4]) else 1000L
sa <- if (length(a) > 4) as.integer(a[5]) else 1000L
dir.create(out, recursive = TRUE, showWarnings = FALSE)
b <- as.data.frame(em$boot); b1 <- b[b$class == 1, ]
U <- cbind(qlogis(b1$pi), b1$mu_a, log(b1$mu_b - b1$mu_a), log(b1$sd_a), log(b1$sd_b))
d <- curiango_v1("custom", c_lo = qlogis(0.1)); dat <- d$stan
dat$v[] <- -1L
dat$u_mu <- colMeans(U); dat$u_Sigma <- cov(U)
cat("prior de f1: media", round(dat$u_mu, 3), " dp", round(sqrt(diag(dat$u_Sigma)), 3), "\n")
mod <- cmdstan_model("dev/fase2/model_v1_prior1.stan", dir = out, quiet = TRUE,
                     include_paths = "dev/fase2")
i0 <- inits_v1(dat)
i0 <- i0[setdiff(names(i0), c("d1", "gap", "sigma1a", "sigma1b", "pi1"))]
i0$u <- dat$u_mu
t0 <- Sys.time()
fit <- mod$sample(data = dat, chains = ch, parallel_chains = ch, iter_warmup = wu,
                  iter_sampling = sa, adapt_delta = 0.95, seed = 2026, refresh = 50,
                  init = \(chain_id) i0, show_exceptions = FALSE)
secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
pars <- c("beta", "alpha", "rho", "theta0", "theta_bar", "psi_c", "lambda0", "sigma0", "sigma0b",
          "pi0", "mu1a", "mu1b", "sigma1a", "sigma1b", "pi1")
dr <- posterior::as_draws_matrix(fit$draws(pars))
colnames(dr)[colnames(dr) == "rho"] <- "rho[1]"
md <- \(n) median(dr[, n])
emis <- list(f0 = c(pi = md("pi0"), mu_a = md("lambda0"), sd_a = md("sigma0"), mu_b = md("lambda0"), sd_b = md("sigma0b")),
             f1 = c(pi = md("pi1"), mu_a = md("mu1a"), sd_a = md("sigma1a"), mu_b = md("mu1b"), sd_b = md("sigma1b")))
saveRDS(list(markov = 1L, night_re = 0L, chains = ch, warmup = wu, sampling = sa, seconds = secs,
             prior = dat[c("u_mu", "u_Sigma")], emissions = emis,
             summary = as.data.frame(fit$summary(pars)), diag = fit$diagnostic_summary(quiet = TRUE),
             draws = dr),
        file.path(out, sprintf("fit_v1prior_%dx%d.rds", ch, wu + sa)))
cat("seconds", secs, "\n")
