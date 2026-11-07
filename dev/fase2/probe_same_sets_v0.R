# Maximum likelihood on the data sets of the second validation, paired with the
# posterior means of Stan, at c = logit(0.1), in the cells with 5% verified.
#   Rscript dev/fase2/probe_same_sets_v0.R [N_WORKERS]
suppressPackageStartupMessages({library(parallel); library(dplyr)})
src <- parse("dev/fase2/probe_cell_v0.R")
keep <- vapply(src, \(e) is.call(e) && identical(e[[1]], as.name("<-")) &&
                 as.character(e[[2]])[1] %in% c("unpack", "fit_ml", "run_set"), TRUE)
for (e in src[keep]) eval(e)
source("dev/fase2/v0.R")
w <- commandArgs(TRUE); workers <- if (length(w)) as.integer(w[1]) else 10L
d <- readRDS("dev/fase2/results/val2_v0/task_all.rds") |>
  filter(cut == 0.1, frac == 0.05, variable == "alpha[1]")
g <- distinct(d, theta, frac, delta, rep, id) |> mutate(seed = id)
res <- mclapply(split(g, seq_len(nrow(g))), run_set, mc.cores = workers)
ml <- bind_rows(res) |> filter(kind == "free") |>
  mutate(ml = plogis(est), lo_ml = plogis(est - 1.96 * se),
         hi_ml = plogis(est + 1.96 * se))
x <- inner_join(ml, select(d, id, st = mean, lo, hi), by = "id") |>
  mutate(stan = plogis(st), l = plogis(lo), h = plogis(hi))
x |> group_by(theta, delta) |>
  summarise(n = n(), bias_ml = mean(ml - theta),
            ep_ml = sd(ml) / sqrt(n()), bias_stan = mean(stan - theta),
            diff = mean(stan - ml), r = cor(stan, ml),
            cov_ml = mean(lo_ml <= theta & theta <= hi_ml),
            cov_stan = mean(l <= theta & theta <= h), .groups = "drop") |>
  as.data.frame() |> print(digits = 3)
