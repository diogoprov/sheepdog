# The end-to-end flow of vignette("crywolf-integration") on the Curiango
# export of curiango-export.R, for both classifiers:
#   1. posterior predictive check of the calibration (calibration_ppc());
#   2. M versions of the detections of each occasion over the calibration
#      draws (occasion_draws(), written to occasion_draws.parquet);
#   3. crywolf reads the export and the versions (fp_read_sheepdog(),
#      fp_draws_data(), which reads the parquet when its settings match)
#      and fits the occupancy model with false positives to each version,
#      pooling the posteriors (fp_occu_mc(); Monte Carlo propagation).
# The occupancy model is that of crywolf's dev/mc-curiango/run-comparison.R
# with a constant false-positive rate: sites are nights at each recorder,
# occupancy ~ temp + rh + moon (night means, standardised; moon on the log
# scale), detection ~ bio + aci (minute indices, standardised).
# Run from the repository root, after curiango-export.R:
#   M=20 WORKERS=4 Rscript dev/benchmarks/curiango-flow.R [EXPORT_DIR]
# EXPORT_DIR defaults to dev/benchmarks/results/curiango-export. Needs
# crywolf >= 2.0.0.9000 with CmdStan, future and furrr. About 20 minutes per
# classifier with M = 20 and 4 workers of 4 chains (16 cores).
# Writes the small tables of the vignette to inst/benchmarks/:
#   curiango-flow-ppc.csv      the posterior predictive checks;
#   curiango-flow-versions.csv share of minutes with a detection per version;
#   curiango-flow-summary.csv  pooled posterior summaries (fp_occu_mc);
#   curiango-flow-fits.csv     convergence of each fit;
#   curiango-flow-session.txt  sessionInfo().
args <- commandArgs(trailingOnly = TRUE)
export <- if (length(args)) args[1] else "dev/benchmarks/results/curiango-export"
M <- as.integer(Sys.getenv("M", "20"))
workers <- as.integer(Sys.getenv("WORKERS", "4"))
iter <- as.integer(Sys.getenv("ITER", "1000"))
seed <- 2026
devtools::load_all(".", quiet = TRUE)
stopifnot(utils::packageVersion("crywolf") >= "2.0.0.9000")
suppressPackageStartupMessages(library(dplyr))
out <- "inst/benchmarks"

zs <- function(v) as.numeric(scale(v))
crywolf::fp_compile()
future::plan(future::multisession, workers = workers)
ppc <- versions_tab <- summaries <- fits <- list()

for (cl in c("custom", "birdnet")) {
  message("== ", cl)
  dir <- file.path(export, cl)

  # 1. a calibracao reproduz a proporcao de verdadeiros por faixa de score,
  # local e mes?
  fit <- readRDS(file.path(dir, "curiango_calibration_fit.rds"))
  print(calibration_diagnostics(fit))
  cal_data <- readr::read_csv(file.path(dir, "curiango_calibration_data.csv"),
                              col_types = readr::cols(month = "c"))
  ppc[[cl]] <- calibration_ppc(fit, cal_data, group = "month", seed = seed) |>
    mutate(classifier = cl, .before = 1)

  # 2. versoes das deteccoes por ocasiao
  od <- occasion_draws(dir, rule = "sample", n_draws = M, seed = seed)

  # 3. crywolf: leitura, versoes e ajuste
  x <- suppressMessages(crywolf::fp_read_sheepdog(dir, species = "nyc_alb"))
  occ <- x$occasions
  nights <- occ[!duplicated(occ$night_site_id), c("night_site_id", "temp", "rh", "moon")]
  nights <- mutate(nights, temp = zs(temp), rh = zs(rh), moon = zs(log(moon)))
  occ <- transmute(occ, site, occasion_id, night_site_id, bio = zs(bio), aci = zs(aci))
  versions <- crywolf::fp_draws_data(x, rule = "sample", n_draws = M, seed = seed,
                                     occasions = occ, sites = nights,
                                     site = "night_site_id")
  versions_tab[[cl]] <- tibble(
    classifier = cl, draw = attr(versions, "draws"),
    detection_rate = vapply(versions, function(d) mean(d$auto$y), numeric(1)))
  # as versoes do crywolf sao as do occasion_draws() gravado
  stopifnot(all.equal(versions_tab[[cl]]$detection_rate,
                      as.numeric(tapply(od$y, od$draw, sum, na.rm = TRUE)) /
                        nrow(versions[[1]]$auto)))

  t0 <- Sys.time()
  mc <- crywolf::fp_occu_mc(versions, occ = ~ temp + rh + moon, det = ~ bio + aci,
                            fp = ~ 1, chains = 4, parallel_chains = 4,
                            threads_per_chain = 1, iter_warmup = iter,
                            iter_sampling = iter, seed = 1, parallel = TRUE,
                            refresh = 0, show_messages = FALSE)
  minutes <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
  summaries[[cl]] <- summary(mc)$table |> mutate(classifier = cl, .before = 1)
  fits[[cl]] <- mc$diagnostics |> mutate(classifier = cl, .before = 1,
                                         minutes_total = minutes)
  print(summary(mc))
}

wr <- function(x, f) readr::write_csv(bind_rows(x), file.path(out, f), na = "")
wr(ppc, "curiango-flow-ppc.csv")
wr(versions_tab, "curiango-flow-versions.csv")
wr(summaries, "curiango-flow-summary.csv")
wr(fits, "curiango-flow-fits.csv")
writeLines(c(capture.output(sessionInfo()),
             paste("crywolf", utils::packageVersion("crywolf")),
             paste("M =", M, "; iter =", iter)),
           file.path(out, "curiango-flow-session.txt"))
