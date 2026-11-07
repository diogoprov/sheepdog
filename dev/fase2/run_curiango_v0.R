# Stage 1 of the Curiango step: model v0 as a baseline, although stage 0 showed
# that the censored normal does not describe the scores. Run from the root:
#   Rscript dev/fase2/run_curiango_v0.R OUT_DIR [classifier] [c]
suppressPackageStartupMessages(library(cmdstanr))
source("dev/fase2/v0.R"); source("dev/fase2/curiango_v0.R")
a <- commandArgs(TRUE)
out <- a[1]; cl <- if (length(a) > 1) a[2] else "custom"
cc <- if (length(a) > 2) as.numeric(a[3]) else 0.1
dir.create(out, recursive = TRUE, showWarnings = FALSE)
d <- curiango_v0(cl, c_lo = qlogis(cc)); dat <- d$stan
mod <- cmdstan_model("dev/fase2/model_v0.stan", dir = out, quiet = TRUE,
                     include_paths = "dev/fase2")
t0 <- Sys.time()
fit <- mod$sample(data = dat, chains = 4, parallel_chains = 4, iter_warmup = 1000,
                  iter_sampling = 1000, adapt_delta = 0.95, seed = 2026, refresh = 100,
                  init = \(chain_id) inits_v0(dat), show_exceptions = FALSE)
secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
pars <- c("beta", "alpha", "lambda0", "delta", "sigma0", "sigma1")
dr <- posterior::as_draws_matrix(fit$draws(pars))
saveRDS(list(classifier = cl, c = cc, seconds = secs, time = fit$time(),
             summary = as.data.frame(fit$summary(pars)),
             diag = fit$diagnostic_summary(quiet = TRUE),
             draws = dr[seq(1, nrow(dr), by = 4), ]),
        file.path(out, sprintf("fit_%s_%g.rds", cl, cc)))
cat("seconds", secs, "\n")
