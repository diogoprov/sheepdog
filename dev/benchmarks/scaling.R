# Scaling of the calibration fits with the number of reviewed clips
# (rOpenSci standard RE5.0) and comparison with alternative implementations
# in base R (G1.6). Simulated data with known generating parameters; no
# downloads. Writes inst/benchmarks/scaling-*.csv and
# inst/benchmarks/alternatives-*.csv, read by vignettes/performance.Rmd.
#   Rscript dev/benchmarks/scaling.R [N_CORES]
# Run from the root of a source checkout; about 10 minutes on 10 cores.
suppressPackageStartupMessages({
  library(parallel)
  devtools::load_all(quiet = TRUE)
})
cores <- if (length(commandArgs(TRUE))) as.integer(commandArgs(TRUE)[1]) else 4L
Sys.setenv(OMP_NUM_THREADS = 1, OPENBLAS_NUM_THREADS = 1)
out <- "inst/benchmarks"

# Eight species and six sites; species intercepts and slopes, site and
# species x site intercepts on the logit scale; scores uniform on the logit
# scale between 0.10 and 0.9995
gen <- function(n, seed, n_species = 8, n_sites = 6, sd_sp = 0.8,
                sd_slope = 0.4, sd_site = 0.4, sd_cell = 0.3, n_per = NULL,
                pars = NULL) {
  withr::with_seed(seed, {
    sp <- paste0("sp", seq_len(n_species)); st <- paste0("S", seq_len(n_sites))
    if (is.null(pars)) {
      pars <- list(a = stats::setNames(stats::rnorm(n_species, 0, sd_sp), sp),
                   b = stats::setNames(1.2 + stats::rnorm(n_species, 0, sd_slope), sp),
                   s = stats::setNames(stats::rnorm(n_sites, 0, sd_site), st),
                   c = matrix(stats::rnorm(n_species * n_sites, 0, sd_cell),
                              n_species, dimnames = list(sp, st)))
    }
    species <- if (is.null(n_per)) sample(sp, n, TRUE) else rep(sp, each = n_per)
    site <- sample(st, length(species), TRUE)
    lc <- stats::runif(length(species), stats::qlogis(0.1), stats::qlogis(0.9995))
    eta <- -0.5 + pars$a[species] + pars$b[species] * lc + pars$s[site] +
      pars$c[cbind(species, site)]
    list(data = tibble::tibble(site = factor(site, st), species = factor(species, sp),
                               confidence = stats::plogis(lc), logit_conf = lc,
                               tp = as.integer(stats::runif(length(lc)) < stats::plogis(eta))),
         pars = pars)
  })
}

# 1. Scaling: elapsed seconds of fit_calibration() by number of clips
forms <- calibration_models()[c("m0_global", "m2_species_slope", "m4_species_x_site")]
grid <- expand.grid(n = c(500, 1000, 2000, 4000, 8000, 16000, 32000),
                    model = names(forms), rep = 1:3, stringsAsFactors = FALSE)
sc <- mclapply(seq_len(nrow(grid)), function(i) {
  g <- grid[i, ]
  d <- gen(g$n, seed = 2026 + 100 * g$rep + g$n)$data
  t <- system.time(fit <- suppressWarnings(suppressMessages(
    fit_calibration(d, forms[[g$model]]))))[["elapsed"]]
  data.frame(g, seconds = t)
}, mc.cores = 1)   # timings in sequence, one fit at a time
sc <- do.call(rbind, sc)
sl <- do.call(rbind, lapply(split(sc, sc$model), function(x) {
  m <- stats::lm(log(seconds) ~ log(n), data = x[x$n >= 2000, ])
  data.frame(model = x$model[1], exponent = unname(stats::coef(m)[2]))
}))
write.csv(sc, file.path(out, "scaling-timing.csv"), row.names = FALSE)
write.csv(sl, file.path(out, "scaling-exponent.csv"), row.names = FALSE)
print(sl)

# 2. Alternatives: the global model against stats::glm(), and partial
# pooling (sheepdog, species random intercepts and slopes) against no
# pooling (one stats::glm() per species) and complete pooling (one
# stats::glm()), scored by log-loss on 2000 new clips per species from the
# same generating parameters. Species effects only (no site effects).
logloss <- function(y, p) {
  p <- pmin(pmax(p, 1e-6), 1 - 1e-6)
  -mean(y * log(p) + (1 - y) * log(1 - p))
}
alt <- expand.grid(n_per = c(10, 25, 50, 100, 200), rep = 1:50)
al <- mclapply(seq_len(nrow(alt)), function(i) {
  g <- alt[i, ]
  seed <- 9000 + 1000 * g$rep + g$n_per
  tr <- gen(NA, seed, sd_site = 0, sd_cell = 0, n_per = g$n_per)
  te <- gen(NA, seed + 1, n_per = 2000, pars = tr$pars)$data
  d <- tr$data
  ok <- tapply(d$tp, d$species, function(y) length(unique(y)) == 2)
  # sheepdog, global model, and the same model in stats::glm()
  g0 <- fit_calibration(d, tp ~ logit_conf)
  b0 <- stats::glm(tp ~ logit_conf, data = d, family = stats::binomial)
  # sheepdog, partial pooling
  m2 <- suppressWarnings(suppressMessages(
    fit_calibration(d, tp ~ logit_conf + (logit_conf | species))))
  # no pooling: one glm per species (fails to converge or separates with
  # few clips; its predictions are then extreme, which log-loss penalises)
  np <- numeric(nrow(te)); sep <- 0L
  for (s in levels(d$species)) {
    ds <- d[d$species == s, ]; it <- te$species == s
    if (length(unique(ds$tp)) < 2) { np[it] <- mean(ds$tp); sep <- sep + 1L; next }
    f <- withCallingHandlers(stats::glm(tp ~ logit_conf, data = ds, family = stats::binomial),
                             warning = function(w) { sep <<- sep + 1L; invokeRestart("muffleWarning") })
    np[it] <- stats::predict(f, newdata = te[it, ], type = "response")
  }
  data.frame(g, species_one_class = sum(!ok), no_pool_problems = sep,
             glm_max_abs_diff = max(abs(stats::coef(g0) - stats::coef(b0))),
             partial = logloss(te$tp, predict_tp(m2, te)),
             none = logloss(te$tp, np),
             complete = logloss(te$tp, predict_tp(g0, te)),
             oracle = logloss(te$tp, stats::plogis(-0.5 + tr$pars$a[as.character(te$species)] +
                                                     tr$pars$b[as.character(te$species)] * te$logit_conf)),
             singular = lme4::isSingular(m2))
}, mc.cores = cores)
al <- do.call(rbind, al)
write.csv(al, file.path(out, "alternatives-logloss.csv"), row.names = FALSE)
print(stats::aggregate(cbind(partial, none, complete, oracle, no_pool_problems,
                             glm_max_abs_diff) ~ n_per, al, mean), digits = 4)
writeLines(utils::capture.output(utils::sessionInfo()),
           file.path(out, "scaling-session.txt"))
