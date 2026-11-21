# Reviewed clips simulated from a known calibration model, for the
# parameter recovery, performance and noise tests (G5.6, G5.7, G5.9):
# tp ~ Bernoulli(plogis(a + u_species + b * logit(confidence))), with
# u_species ~ normal(0, sd_species) and scores uniform on the logit scale
# between logit(0.1) and logit(0.99).
sim_calibration <- function(n = 600, a = -0.5, b = 1.2, n_species = 6,
                            n_sites = 4, sd_species = 0, seed = 1) {
  withr::with_seed(seed, {
    sp <- paste0("sp", seq_len(n_species))
    u <- stats::setNames(stats::rnorm(n_species, 0, sd_species), sp)
    species <- sample(sp, n, replace = TRUE)
    logit_conf <- stats::runif(n, stats::qlogis(0.1), stats::qlogis(0.99))
    p <- stats::plogis(a + u[species] + b * logit_conf)
    tibble::tibble(
      site = factor(sample(paste0("S", seq_len(n_sites)), n, replace = TRUE)),
      species = factor(species, levels = sp),
      confidence = stats::plogis(logit_conf),
      logit_conf = logit_conf,
      tp = as.integer(stats::runif(n) < p))
  })
}

# Extended tests (Stan fits, long simulations): run with
# SHEEPDOG_EXTENDED_TESTS=true; SHEEPDOG_TEST_BRMS=true is kept as an alias
extended_tests <- function() {
  any(vapply(c("SHEEPDOG_EXTENDED_TESTS", "SHEEPDOG_TEST_BRMS"),
             function(v) identical(tolower(Sys.getenv(v)), "true"),
             logical(1)))
}

skip_if_not_extended <- function() {
  testthat::skip_if_not(extended_tests(),
                        "set SHEEPDOG_EXTENDED_TESTS=true for extended tests")
}
