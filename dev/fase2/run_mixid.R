# Identification simulation of model_mix.stan (PLANO-identificacao-mistura.md).
# One task per fit; each writes OUT_DIR/task_<id>.rds, so a stopped run
# resumes. Run from the repository root:
#   Rscript dev/fase2/run_mixid.R OUT_DIR [N_WORKERS] [N_REPS]
# The pilot is N_REPS = 1 (10 fits); the full run is N_REPS = 50 (500 fits).
suppressPackageStartupMessages({library(cmdstanr); library(parallel)})
source("dev/fase2/sim_mixid.R")
args <- commandArgs(TRUE)
out <- args[1]
workers <- if (length(args) > 1) as.integer(args[2]) else 4L
n_reps <- if (length(args) > 2) as.integer(args[3]) else 50L
dir.create(out, recursive = TRUE, showWarnings = FALSE)
mod <- cmdstan_model("dev/fase2/model_mix.stan", dir = out, quiet = TRUE,
                     include_paths = "dev/fase2")
grid <- mixid_grid(n_reps)

run_task <- function(g) {
  file <- file.path(out, sprintf("task_%05d.rds", g$id))
  if (file.exists(file)) return(invisible(NULL))
  sim <- simulate_ignorab(g$truth, ig_seed_data(g$set))
  ver <- if (g$design == "none") integer() else
    select_ignorab(sim, g$design, g$frac, ig_seed_sel(g$set, g$frac, g$design))$idx
  dat <- stan_mixid(sim, ver)
  t0 <- Sys.time()
  wd <- tempfile("fit"); dir.create(wd)
  on.exit(unlink(wd, recursive = TRUE))
  r <- tryCatch({
    fit <- suppressWarnings(mod$sample(
      data = dat, chains = 4, parallel_chains = 1, iter_warmup = 1000,
      iter_sampling = 1000, adapt_delta = 0.95, seed = g$id, refresh = 0,
      output_dir = wd, show_messages = FALSE, show_exceptions = FALSE,
      init = \(chain_id) inits_mixid(dat)))
    sm <- as.data.frame(fit$summary(
      mixid_pars, "mean", ~quantile(.x, c(.025, .975)), "rhat", "ess_bulk"))
    names(sm)[3:4] <- c("lo", "hi")
    # psi and theta at the centre (d = 0, h = 0), on the probability scale
    dr <- posterior::as_draws_matrix(fit$draws(c("beta[1]", "alpha[1]")))
    pr <- data.frame(variable = c("psi", "theta"),
                     mean = colMeans(plogis(dr)),
                     lo = apply(plogis(dr), 2, quantile, 0.025),
                     hi = apply(plogis(dr), 2, quantile, 0.975),
                     rhat = sm$rhat[match(c("beta[1]", "alpha[1]"), sm$variable)],
                     ess_bulk = sm$ess_bulk[match(c("beta[1]", "alpha[1]"), sm$variable)])
    sm <- rbind(pr, sm)
    sm$divergent <- sum(fit$diagnostic_summary(quiet = TRUE)$num_divergent)
    sm$n_pos_verified <- sum(dat$v == 1L)
    sm$error <- NA_character_
    sm
  }, error = \(e) data.frame(variable = NA, mean = NA, lo = NA, hi = NA,
                             rhat = NA, ess_bulk = NA, divergent = NA,
                             n_pos_verified = NA, error = conditionMessage(e)))
  rownames(r) <- NULL
  saveRDS(cbind(g, seconds = as.numeric(difftime(Sys.time(), t0, units = "secs")), r),
          file)
}

tasks <- split(grid, grid$id)
cat("tasks:", length(tasks), "\n")
done <- mclapply(tasks, run_task, mc.cores = workers, mc.preschedule = FALSE)
bad <- vapply(done, inherits, logical(1), "try-error")
cat("tasks:", length(tasks), " failed:", sum(bad), "\n")
if (any(bad)) print(unique(unlist(lapply(done[bad], as.character))))
