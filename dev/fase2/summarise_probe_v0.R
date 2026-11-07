# Summarises probe_cell_v0.R.  Rscript dev/fase2/summarise_probe_v0.R FILE
suppressPackageStartupMessages(library(dplyr))
d <- readRDS(commandArgs(TRUE)[1]) |>
  mutate(est_p = plogis(est), lo = plogis(est - 1.96 * se),
         hi = plogis(est + 1.96 * se), cov = lo <= theta & theta <= hi)
cat("not converged:", sum(d$conv != 0), " no se:", sum(is.na(d$se)), "\n")
d |> filter(conv == 0, !is.na(se)) |>
  group_by(kind, frac, delta, theta) |>
  summarise(n = n(), bias = mean(est_p - theta),
            se_bias = sd(est_p) / sqrt(n()), med_bias = median(est_p) - first(theta),
            sd = sd(est_p), w = mean(hi - lo), cov = mean(cov),
            above = mean(lo > theta), below = mean(hi < theta), .groups = "drop") |>
  arrange(kind, frac, delta, theta) |>
  as.data.frame() |> print(digits = 3)
