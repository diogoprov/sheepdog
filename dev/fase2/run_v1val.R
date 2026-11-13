# Validation of model_v1.stan in simulation (PLANO-v1-markov.md). One task per
# fit; each writes OUT_DIR/task_<id>.rds, so a stopped run resumes.
#   Rscript dev/fase2/run_v1val.R OUT_DIR [N_WORKERS] [N_REPS]
# The pilot is N_REPS = 1 (8 fits); the full run is N_REPS = 50 (400 fits).
suppressPackageStartupMessages({library(cmdstanr); library(parallel)})
source("dev/fase2/v1.R")
source("dev/fase2/sim_mixid.R")  # inits_mixid()
args <- commandArgs(TRUE)
out <- args[1]
workers <- if (length(args) > 1) as.integer(args[2]) else 4L
n_reps <- if (length(args) > 2) as.integer(args[3]) else 50L
dir.create(out, recursive = TRUE, showWarnings = FALSE)
mods <- list(
  v1 = cmdstan_model("dev/fase2/model_v1.stan", dir = out, quiet = TRUE,
                     include_paths = "dev/fase2"),
  mix = cmdstan_model("dev/fase2/model_mix.stan", dir = out, quiet = TRUE,
                      include_paths = "dev/fase2"))
grid <- v1_grid(n_reps)
em <- c("lambda0", "sigma0", "sigma0b", "pi0", "mu1a", "mu1b", "sigma1a",
        "sigma1b", "pi1")

run_task <- function(g) {
  file <- file.path(out, sprintf("task_%05d.rds", g$id))
  if (file.exists(file)) return(invisible(NULL))
  sim <- simulate_v1("mixture", v1_seed_data(g$set), par = v1_sim_par(g$rho))
  ver <- select_ignorab(sim, "S2", g$frac, v1_seed_sel(g$set, g$frac))$idx
  dat <- stan_v1(sim, ver)
  markov <- g$model == "v1"
  pars <- c("beta[1]", "beta[2]", "alpha[1]", "alpha[2]", "alpha[3]",
            if (markov) "rho", em)
  t0 <- Sys.time()
  wd <- tempfile("fit"); dir.create(wd)
  on.exit(unlink(wd, recursive = TRUE))
  r <- tryCatch({
    fit <- suppressWarnings(mods[[g$model]]$sample(
      data = dat, chains = 4, parallel_chains = 1, iter_warmup = 1000,
      iter_sampling = 1000, adapt_delta = 0.95, seed = g$id, refresh = 0,
      output_dir = wd, show_messages = FALSE, show_exceptions = FALSE,
      init = \(chain_id) if (markov) inits_v1(dat) else inits_mixid(dat)))
    sm <- as.data.frame(fit$summary(
      pars, "mean", ~quantile(.x, c(.025, .975)), "rhat", "ess_bulk"))
    names(sm)[3:4] <- c("lo", "hi")
    # psi, theta0 and the stationary theta_bar at the centre (d = 0, h = 0);
    # without Markov theta0 = theta_bar = inverse logit of alpha[1]
    dr <- posterior::as_draws_matrix(fit$draws(c("beta[1]", "alpha[1]", if (markov) "rho")))
    rho <- if (markov) dr[, "rho"] else 0
    a0 <- as.numeric(dr[, "alpha[1]"])
    rho <- as.numeric(rho)
    q <- cbind(psi = plogis(as.numeric(dr[, "beta[1]"])), theta0 = plogis(a0),
               theta_bar = plogis(a0) / (1 - plogis(a0 + rho) + plogis(a0)))
    hat <- \(v) sm[[v]][match(c("beta[1]", "alpha[1]", "alpha[1]"), sm$variable)]
    pr <- data.frame(variable = colnames(q), mean = colMeans(q),
                     lo = apply(q, 2, quantile, 0.025),
                     hi = apply(q, 2, quantile, 0.975),
                     rhat = hat("rhat"), ess_bulk = hat("ess_bulk"))
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
