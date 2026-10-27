# Posterior predictive checks of the Curiango calibrations written by
# dev/benchmarks/curiango-export.R (one folder per classifier, with
# curiango_calibration_fit.rds and curiango_calibration_data.csv).
# Run from the repository root:
#   Rscript dev/benchmarks/curiango-ppc.R [EXPORT_DIR]
# EXPORT_DIR defaults to dev/benchmarks/results/curiango-export.
#
# Uses calibration_ppc(): observed share of true positives against its
# posterior predictive distribution, overall, by score bin, by site and by
# month of the recording (the test set is unevenly spread in time, and a
# calibration that drifts with the season would bias the histories).
# Figures: ppc_score.png, ppc_site.png and ppc_month.png in each folder.
args <- commandArgs(trailingOnly = TRUE)
out <- if (length(args)) args[1] else "dev/benchmarks/results/curiango-export"
suppressPackageStartupMessages({
  library(dplyr); library(readr); library(ggplot2)
  devtools::load_all(quiet = TRUE)
})

resumo <- list()
for (cl in c("custom", "birdnet")) {
  d <- file.path(out, cl)
  fit <- readRDS(file.path(d, "curiango_calibration_fit.rds"))
  dados <- read_csv(file.path(d, "curiango_calibration_data.csv"),
                    show_col_types = FALSE) |>
    mutate(month = substr(regmatches(source_audio, regexpr("[0-9]{8}_[0-9]{6}",
                                                           source_audio)), 1, 6))
  tab <- calibration_ppc(fit, dados, group = "month") |>
    mutate(classifier = cl, model = deparse1(stats::formula(fit)$formula),
           .before = 1)
  write_csv(tab, file.path(d, "ppc_summary.csv"))
  titulo <- paste0("Curiango ", cl, ": ", tab$model[1])
  for (ch in c("score", "site", "month")) {
    ggsave(file.path(d, paste0("ppc_", ch, ".png")),
           plot_calibration_ppc(tab, ch) + labs(title = titulo),
           width = if (ch == "month") 8 else 7, height = 4.5, dpi = 150,
           bg = "white")
  }
  resumo[[cl]] <- tab
}

tab <- bind_rows(resumo)
write_csv(tab, file.path(out, "ppc_summary.csv"))
print(tab |> select(classifier, check, group, n, observed, pred_mean, pred_lower,
                    pred_upper, p_value, flagged), n = Inf, width = Inf)
