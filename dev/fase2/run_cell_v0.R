# Repeats the cell that failed criterion 2 of the second validation (theta 0.6,
# 5% verified, delta 3, c = logit(0.1)) with the priors of the prior predictive
# check, and pairs each fit with maximum likelihood on the same data. The
# design is in dev/fase2/README.md. Run from the repository root:
#   Rscript dev/fase2/run_cell_v0.R OUT_DIR [N_WORKERS] [N_SETS]
# Each data set writes OUT_DIR/task_<id>.rds, so a stopped run resumes. Ids come
# from the grid of run_val2_v0.R, so sets 1 to 60 are the same data.
suppressPackageStartupMessages({library(cmdstanr); library(parallel)})
source("dev/fase2/v0.R")
src <- parse("dev/fase2/probe_cell_v0.R")
keep <- vapply(src, \(e) is.call(e) && identical(e[[1]], as.name("<-")) &&
                 as.character(e[[2]])[1] %in% c("unpack", "fit_ml"), TRUE)
for (e in src[keep]) eval(e)
args <- commandArgs(TRUE)
out <- args[1]
workers <- if (length(args) > 1) as.integer(args[2]) else 4L
nsets <- if (length(args) > 2) as.integer(args[3]) else 160L
dir.create(out, recursive = TRUE, showWarnings = FALSE)
mod <- cmdstan_model("dev/fase2/model_v0.stan", dir = out, quiet = TRUE,
                     include_paths = "dev/fase2")
grid <- expand.grid(theta = c(0.6, 0.3, 0.1), frac = c(0.2, 0.05, 0),
                    delta = c(5, 3), rep = seq_len(nsets))
grid$id <- seq_len(nrow(grid))
grid <- grid[grid$theta == 0.6 & grid$frac == 0.05 & grid$delta == 3, ]
pars <- c("beta[1]", "beta[2]", "alpha[1]", "alpha[2]", "lambda0", "delta",
          "sigma0", "sigma1")

run_task <- function(g) {
  file <- file.path(out, sprintf("task_%05d.rds", g$id))
  if (file.exists(file)) return(invisible(NULL))
  sim <- simulate_v0(beta = c(0, -0.8), alpha = c(qlogis(g$theta), 0.6),
                     delta = g$delta, frac_verified = g$frac, seed = g$id)
  dat <- sim$stan
  t0 <- Sys.time()
  wd <- tempfile("fit"); dir.create(wd)
  on.exit(unlink(wd, recursive = TRUE))
  fit <- suppressWarnings(mod$sample(
    data = dat, chains = 4, parallel_chains = 1, iter_warmup = 1000,
    iter_sampling = 1000, adapt_delta = 0.95, seed = g$id, refresh = 0,
    output_dir = wd, show_messages = FALSE, show_exceptions = FALSE,
    init = \(chain_id) inits_v0(dat)))
  sm <- as.data.frame(fit$summary(
    pars, "mean", "median", ~quantile(.x, c(.025, .975)), "rhat", "ess_bulk"))
  names(sm)[4:5] <- c("lo", "hi")
  # theta on the probability scale: the mean of plogis(alpha), not plogis(mean)
  th <- plogis(as.numeric(fit$draws("alpha[1]")))
  ml <- fit_ml(dat, c(0, -0.8, qlogis(g$theta), 0.6, -4, log(g$delta),
                      log(1.5), log(1.5)))
  saveRDS(cbind(g, seconds = as.numeric(difftime(Sys.time(), t0, units = "secs")),
                sm, divergent = sum(fit$diagnostic_summary(quiet = TRUE)$num_divergent),
                theta_mean = mean(th), theta_median = median(th),
                ml_alpha = ml$par[3], ml_se = ml$se[3], ml_conv = ml$conv), file)
}
tasks <- split(grid, grid$id)
done <- mclapply(tasks, \(g) tryCatch(run_task(g), error = \(e) conditionMessage(e)),
                 mc.cores = workers, mc.preschedule = FALSE)
bad <- Filter(is.character, done)
cat("tasks:", length(tasks), " failed:", length(bad), "\n")
if (length(bad)) print(unique(unlist(bad)))
