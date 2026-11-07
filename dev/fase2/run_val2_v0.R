# Second validation of model v0; the design is in dev/fase2/README.md.
# Main cells only, c <= logit(0.3), stricter sampler, and 30 extra data sets
# in the cells with 5% verified. Run from the repository root:
#   Rscript dev/fase2/run_val2_v0.R OUT_DIR [N_WORKERS]
# Each data set writes OUT_DIR/task_<id>.rds, so a stopped run resumes.
# Ids come from the same grid as run_val_v0.R, so sets 1 to 30 are the same
# data; summarise_val_v0.R and diagnose_val_v0.R read the output.
suppressPackageStartupMessages({library(cmdstanr); library(parallel)})
source("dev/fase2/v0.R")
args <- commandArgs(TRUE)
out <- args[1]
workers <- if (length(args) > 1) as.integer(args[2]) else 4L
dir.create(out, recursive = TRUE, showWarnings = FALSE)
mod <- cmdstan_model("dev/fase2/model_v0.stan", dir = out, quiet = TRUE,
                     include_paths = "dev/fase2")

cuts <- c(0.1, 0.3)
grid <- expand.grid(theta = c(0.6, 0.3, 0.1), frac = c(0.2, 0.05, 0),
                    delta = c(5, 3), rep = seq_len(60))
grid$id <- seq_len(nrow(grid))
grid <- grid[grid$theta > 0.1 & grid$frac > 0 &
               (grid$rep <= 30 | grid$frac == 0.05), ]
pars <- c("beta[1]", "beta[2]", "alpha[1]", "alpha[2]", "lambda0", "delta",
          "sigma0", "sigma1")

at_cut <- function(sim, c) {
  dat <- sim$stan
  s <- sim$truth$s
  dat$c_lo <- c
  dat$cens <- ifelse(s < c, 1L, ifelse(s > dat$c_hi, 2L, 0L))
  dat$s <- ifelse(dat$cens == 0L, s, 0)
  dat
}

run_task <- function(g) {
  file <- file.path(out, sprintf("task_%05d.rds", g$id))
  if (file.exists(file)) return(invisible(NULL))
  sim <- simulate_v0(beta = c(0, -0.8), alpha = c(qlogis(g$theta), 0.6),
                     delta = g$delta, frac_verified = g$frac, seed = g$id)
  res <- lapply(cuts, \(cc) {
    dat <- at_cut(sim, qlogis(cc))
    t0 <- Sys.time()
    wd <- tempfile("fit"); dir.create(wd)
    on.exit(unlink(wd, recursive = TRUE))
    r <- tryCatch({
      fit <- suppressWarnings(mod$sample(
        data = dat, chains = 4, parallel_chains = 1, iter_warmup = 1000,
        iter_sampling = 1000, adapt_delta = 0.95, seed = g$id, refresh = 0,
        output_dir = wd, show_messages = FALSE, show_exceptions = FALSE,
        init = \(chain_id) inits_v0(dat)))
      sm <- as.data.frame(fit$summary(
        pars, "mean", ~quantile(.x, c(.025, .975)), "rhat", "ess_bulk"))
      names(sm)[3:4] <- c("lo", "hi")
      sm$divergent <- sum(fit$diagnostic_summary(quiet = TRUE)$num_divergent)
      sm$error <- NA_character_
      sm
    }, error = \(e) data.frame(variable = NA, mean = NA, lo = NA, hi = NA,
                               rhat = NA, ess_bulk = NA, divergent = NA,
                               error = conditionMessage(e)))
    cbind(g, cut = cc, seconds = as.numeric(difftime(Sys.time(), t0,
                                                     units = "secs")), r)
  })
  saveRDS(do.call(rbind, res), file)
}

tasks <- split(grid, grid$id)
cat("tasks:", length(tasks), "\n")
done <- mclapply(tasks, run_task, mc.cores = workers, mc.preschedule = FALSE)
bad <- vapply(done, inherits, logical(1), "try-error")
cat("tasks:", length(tasks), " failed:", sum(bad), "\n")
if (any(bad)) print(unique(unlist(lapply(done[bad], as.character))))
