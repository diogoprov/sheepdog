# Posterior predictive checks of the Curiango calibrations written by
# dev/benchmarks/curiango-export.R (one folder per classifier, with
# curiango_calibration_fit.rds and curiango_calibration_data.csv).
# Run from the repository root:
#   Rscript dev/benchmarks/curiango-ppc.R [EXPORT_DIR]
# EXPORT_DIR defaults to dev/benchmarks/results/curiango-export.
#
# The calibration is a Bernoulli model of the verdict of a test minute given
# its score, so the checks compare the observed share of true positives with
# its posterior predictive distribution:
# * overall;
# * by score bin (a reliability check; bins of 0.1, sparse bins merged with
#   the next until they hold at least 15 minutes);
# * by site;
# * by month of the recording (the test set is unevenly spread in time, and
#   a calibration that drifts with the season would bias the histories).
# For each group: observed share, posterior predictive mean and 90%
# interval, and the Bayesian p-value Pr(T(yrep) >= T(y)). Values below 0.05
# or above 0.95 are flagged. Figures: ppc_score.png, ppc_site.png and
# ppc_month.png in each folder. Dependencies: brms, dplyr, readr, ggplot2.
args <- commandArgs(trailingOnly = TRUE)
out <- if (length(args)) args[1] else "dev/benchmarks/results/curiango-export"
suppressPackageStartupMessages({library(dplyr); library(readr); library(ggplot2)})

# junta faixas com poucos minutos a faixa seguinte
score_bins <- function(conf, width = 0.1, min_n = 15) {
  cortes <- seq(0.1, 1, by = width)
  faixa <- findInterval(conf, cortes, rightmost.closed = TRUE)
  repeat {
    n <- table(faixa)
    pequenas <- as.integer(names(n)[n < min_n])
    if (length(pequenas) == 0 || length(n) == 1) break
    alvo <- pequenas[1]
    vizinhos <- sort(as.integer(names(n)))
    destino <- if (alvo == max(vizinhos)) max(vizinhos[vizinhos < alvo])
               else min(vizinhos[vizinhos > alvo])
    faixa[faixa == alvo] <- destino
  }
  rotulo <- tapply(conf, faixa, function(x) sprintf("%.2f-%.2f", min(x), max(x)))
  factor(rotulo[as.character(faixa)], levels = rotulo[order(as.integer(names(rotulo)))])
}

check_groups <- function(y, yrep, group, check) {
  bind_rows(lapply(split(seq_along(y), group, drop = TRUE), function(i) {
    t_rep <- rowMeans(yrep[, i, drop = FALSE])
    t_obs <- mean(y[i])
    tibble(n = length(i), observed = t_obs, pred_mean = mean(t_rep),
           pred_lo = unname(quantile(t_rep, 0.05)),
           pred_hi = unname(quantile(t_rep, 0.95)),
           p_value = mean(t_rep >= t_obs))
  }), .id = "group") |>
    mutate(check = check, flagged = p_value < 0.05 | p_value > 0.95, .before = 1)
}

plot_check <- function(tab, titulo, eixo) {
  ggplot(tab, aes(x = group)) +
    geom_linerange(aes(ymin = pred_lo, ymax = pred_hi), linewidth = 2.5,
                   colour = "grey75") +
    geom_point(aes(y = pred_mean), colour = "grey40", size = 2) +
    geom_point(aes(y = observed, shape = flagged), colour = "#1e5e4e", size = 2.6) +
    scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 4), name = "p < 0.05 or > 0.95") +
    labs(title = titulo, x = eixo,
         y = "Share of true positives\n(dot: observed; bar: 90% predictive)") +
    theme_minimal(base_size = 11) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "bottom")
}

resumo <- list()
for (cl in c("custom", "birdnet")) {
  d <- file.path(out, cl)
  fit <- readRDS(file.path(d, "curiango_calibration_fit.rds"))
  dados <- read_csv(file.path(d, "curiango_calibration_data.csv"), show_col_types = FALSE)
  set.seed(2026)
  yrep <- brms::posterior_predict(fit)
  y <- dados$tp
  stopifnot(ncol(yrep) == length(y))
  mes <- substr(regmatches(dados$source_audio,
                           regexpr("[0-9]{8}_[0-9]{6}", dados$source_audio)), 1, 6)
  tab <- bind_rows(
    check_groups(y, yrep, rep("all", length(y)), "overall"),
    check_groups(y, yrep, score_bins(dados$confidence), "score"),
    check_groups(y, yrep, dados$site, "site"),
    check_groups(y, yrep, mes, "month")
  ) |>
    mutate(classifier = cl, model = deparse1(stats::formula(fit)$formula), .before = 1)
  write_csv(tab, file.path(d, "ppc_summary.csv"))
  titulo <- paste0("Curiango ", cl, ": ", tab$model[1])
  ggsave(file.path(d, "ppc_score.png"), plot_check(filter(tab, check == "score"),
                                                   titulo, "Score of the minute"),
         width = 7, height = 4.5, dpi = 150, bg = "white")
  ggsave(file.path(d, "ppc_site.png"), plot_check(filter(tab, check == "site"),
                                                  titulo, "Site"),
         width = 6, height = 4.5, dpi = 150, bg = "white")
  ggsave(file.path(d, "ppc_month.png"), plot_check(filter(tab, check == "month"),
                                                   titulo, "Month (YYYYMM)"),
         width = 8, height = 4.5, dpi = 150, bg = "white")
  resumo[[cl]] <- tab
}

tab <- bind_rows(resumo)
write_csv(tab, file.path(out, "ppc_summary.csv"))
print(tab |> select(classifier, check, group, n, observed, pred_mean, pred_lo,
                    pred_hi, p_value, flagged), n = Inf, width = Inf)
