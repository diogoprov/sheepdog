# Checks of model v0. Run from the repository root:
#   Rscript dev/fase2/check_v0.R [recovery]
# Checks 1 to 3 compare log likelihoods at fixed parameters. "recovery" adds
# a sanity run on 5 data sets, which is not the validation of README.md.
# Prints the results; nothing is written to the repository.
suppressPackageStartupMessages({library(cmdstanr); library(posterior)})
source("dev/fase2/v0.R")
mod <- cmdstan_model("dev/fase2/model_v0.stan", dir = tempdir(), quiet = TRUE,
                     include_paths = "dev/fase2")

draws_to_pars <- function(d, P_psi, P_theta) {
  lapply(seq_len(nrow(d)), \(r) list(
    beta = unlist(d[r, paste0("beta[", seq_len(P_psi), "]")]),
    alpha = unlist(d[r, paste0("alpha[", seq_len(P_theta), "]")]),
    lambda0 = d$lambda0[r], delta = d$delta[r],
    sigma0 = d$sigma0[r], sigma1 = d$sigma1[r]))
}
max_diff <- function(fit, dat, ll) {
  d <- as_draws_df(fit$draws())
  pars <- draws_to_pars(d, dat$P_psi, dat$P_theta)
  lls <- as_draws_matrix(fit$draws("log_lik"))
  max(vapply(seq_along(pars), \(r) max(abs(ll(pars[[r]]) - lls[r, ])),
             numeric(1)))
}
short <- function(dat, seed = 1) {
  mod$sample(data = dat, chains = 1, iter_warmup = 50, iter_sampling = 20,
             seed = seed, refresh = 0, show_messages = FALSE,
             init = \(chain_id) inits_v0(dat))
}

cat("\n== 1. log likelihood, R against Stan ==\n")
sim <- simulate_v0(nsite = 60, nocc = 10, frac_verified = 0.2, seed = 1)
cat("censored below:", mean(sim$stan$cens == 1),
    " above:", mean(sim$stan$cens == 2),
    " verified:", mean(sim$stan$v >= 0), "\n")
f <- short(sim$stan)
cat("max |R - Stan|:",
    max_diff(f, sim$stan, \(p) loglik_v0(p, sim$stan)), "\n")

cat("\n== 2. thresholded scores, Stan against Miller in R ==\n")
th <- threshold_data(sim)
f2 <- short(th$stan)
cat("max |Miller - Stan|:",
    max_diff(f2, th$stan, \(p) loglik_miller(p, th$stan, th$y)), "\n")

cat("\n== 3. the Miller likelihood in R against unmarked::occuFP ==\n")
sim3 <- simulate_v0(nsite = 300, nocc = 10, beta = c(0.3, 0), seed = 2,
                    alpha = c(0, 0))
th3 <- threshold_data(sim3, c = qlogis(0.3))
Y <- matrix(th3$y, nrow = 300, byrow = TRUE)
umf <- unmarked::unmarkedFrameOccuFP(y = Y, type = c(0, 10, 0))
fp <- unmarked::occuFP(detformula = ~1, FPformula = ~1, stateformula = ~1,
                       data = umf, starts = c(0, 1, -2), se = FALSE)
co <- plogis(unmarked::coef(fp))
ll <- sum(miller_sites(rep(co[1], 300), rep(co[2], 3000), rep(co[3], 3000),
                       th3$y, th3$stan$first, th3$stan$last))
cat("estimates (psi, p11, p10):", round(co, 3), "\n")
cat("occuFP logLik:", -fp@negLogLike, " R Miller:", ll, "\n")

if (!"recovery" %in% commandArgs(TRUE)) quit(save = "no")

cat("\n== 4. recovery, 5 data sets (90% intervals) ==\n")
truth <- c(`beta[1]` = 0, `beta[2]` = -0.8, `alpha[1]` = -0.5, `alpha[2]` = 0.6,
           lambda0 = -4, delta = 5, sigma0 = 1.5, sigma1 = 1.5)
res <- do.call(rbind, lapply(1:5, \(r) {
  sim <- simulate_v0(seed = 100 + r)
  fit <- mod$sample(data = sim$stan, chains = 4, parallel_chains = 4,
                    iter_warmup = 500, iter_sampling = 500, seed = r,
                    refresh = 0, show_messages = FALSE,
                    init = \(chain_id) inits_v0(sim$stan))
  sm <- fit$summary(names(truth), "mean", ~quantile(.x, c(.05, .95)),
                    "rhat", "ess_bulk")
  dg <- fit$diagnostic_summary(quiet = TRUE)
  cbind(rep = r, sm, truth = truth, divergent = sum(dg$num_divergent))
}))
res$covered <- res$`5%` <= res$truth & res$truth <= res$`95%`
print(aggregate(cbind(mean, covered, rhat, ess_bulk) ~ variable, res, mean),
      digits = 3)
cat("truth:\n"); print(truth)
cat("max rhat:", max(res$rhat), " min ess_bulk:", min(res$ess_bulk),
    " divergences:", sum(res$divergent[res$variable == "beta[1]"]), "\n")
