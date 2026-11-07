# Refits fits that failed criterion 1 with a stricter sampler; see README.md.
# Run from the repository root:
#   Rscript dev/fase2/run_diag_v0.R OUT_DIR [N_WORKERS]
# Each fit writes OUT_DIR/refit_<id>_<cut>.rds, so a stopped run resumes.
suppressPackageStartupMessages({
  library(cmdstanr); library(parallel); library(dplyr)
})
source("dev/fase2/v0.R")
args <- commandArgs(TRUE)
out <- args[1]
workers <- if (length(args) > 1) as.integer(args[2]) else 4L
dir.create(out, recursive = TRUE, showWarnings = FALSE)
mod <- cmdstan_model("dev/fase2/model_v0.stan", dir = out, quiet = TRUE,
                     include_paths = "dev/fase2")
pars <- c("beta[1]", "beta[2]", "alpha[1]", "alpha[2]", "lambda0", "delta",
          "sigma0", "sigma1")

# per main combination, the failed fits with the lowest ids:
# 2 at logit(0.3) and 3 at logit(0.5)
base <- readRDS("dev/fase2/results/val_v0/task_all.rds")
picked <- base |>
  filter(theta > 0.1, frac > 0, cut > 0.1) |>
  group_by(theta, frac, delta, cut, id) |>
  summarise(ok = max(rhat) < 1.01 & first(divergent) == 0, .groups = "drop") |>
  filter(!ok) |>
  group_by(theta, frac, delta, cut) |>
  arrange(id, .by_group = TRUE) |>
  filter(row_number() <= ifelse(cut == 0.3, 2L, 3L)) |>
  ungroup() |>
  select(-ok) |>
  arrange(desc(cut), id)

at_cut <- function(sim, c) {
  dat <- sim$stan
  s <- sim$truth$s
  dat$c_lo <- c
  dat$cens <- ifelse(s < c, 1L, ifelse(s > dat$c_hi, 2L, 0L))
  dat$s <- ifelse(dat$cens == 0L, s, 0)
  dat
}

run_fit <- function(g) {
  file <- file.path(out, sprintf("refit_%05d_%02d.rds", g$id, 10 * g$cut))
  if (file.exists(file)) return(invisible(NULL))
  sim <- simulate_v0(beta = c(0, -0.8), alpha = c(qlogis(g$theta), 0.6),
                     delta = g$delta, frac_verified = g$frac, seed = g$id)
  dat <- at_cut(sim, qlogis(g$cut))
  wd <- tempfile("fit"); dir.create(wd)
  on.exit(unlink(wd, recursive = TRUE))
  t0 <- Sys.time()
  fit <- suppressWarnings(mod$sample(
    data = dat, chains = 4, parallel_chains = 1, iter_warmup = 1000,
    iter_sampling = 1000, adapt_delta = 0.95, seed = g$id, refresh = 0,
    output_dir = wd, show_messages = FALSE, show_exceptions = FALSE,
    init = \(chain_id) inits_v0(dat)))
  sm <- as.data.frame(fit$summary(
    pars, "mean", ~quantile(.x, c(.025, .975)), "rhat", "ess_bulk"))
  names(sm)[3:4] <- c("lo", "hi")
  sm$divergent <- sum(fit$diagnostic_summary(quiet = TRUE)$num_divergent)
  saveRDS(cbind(g, seconds = as.numeric(difftime(Sys.time(), t0,
                                                 units = "secs")), sm), file)
}

cat("fits:", nrow(picked), "\n")
print(as.data.frame(count(picked, delta, cut)))
done <- mclapply(split(picked, seq_len(nrow(picked))), run_fit,
                 mc.cores = workers, mc.preschedule = FALSE)
bad <- vapply(done, inherits, logical(1), "try-error")
cat("fits:", length(done), " failed:", sum(bad), "\n")
if (any(bad)) print(unique(unlist(lapply(done[bad], as.character))))
