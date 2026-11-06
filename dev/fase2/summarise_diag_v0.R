# Compares the refits of run_diag_v0.R with the original fits.
#   Rscript dev/fase2/summarise_diag_v0.R DIAG_DIR
suppressPackageStartupMessages(library(dplyr))
out <- commandArgs(TRUE)[1]
new <- bind_rows(lapply(list.files(out, "^refit_.*rds$", full.names = TRUE),
                        readRDS))
old <- readRDS("dev/fase2/results/val_v0/task_all.rds") |>
  semi_join(new, by = c("id", "cut"))
fit_level <- function(d) d |>
  group_by(theta, frac, delta, cut, id) |>
  summarise(maxr = max(rhat), ess = min(ess_bulk), dv = first(divergent),
            secs = first(seconds), worst = variable[which.max(rhat)],
            .groups = "drop") |>
  mutate(ok = maxr < 1.01 & dv == 0)
fn <- fit_level(new); fo <- fit_level(old)
tab <- function(f) f |> group_by(delta, cut) |>
  summarise(n = n(), ok = mean(ok), rhat_bad = mean(maxr >= 1.01),
            div_bad = mean(dv > 0), max_div = max(dv), max_rhat = max(maxr),
            min_ess = min(ess), med_secs = median(secs), .groups = "drop") |>
  as.data.frame()
cat("== original ==\n"); print(tab(fo), digits = 3)
cat("\n== refit (adapt_delta 0.95, 1000+1000; 4000 draws, 4000 transitions) ==\n")
print(tab(fn), digits = 3)
cat("\nby cut, refit ok:\n"); print(as.data.frame(fn |> group_by(cut) |>
  summarise(n = n(), ok = mean(ok), .groups = "drop")), digits = 3)
cat("\nstill failing:\n")
print(as.data.frame(filter(fn, !ok) |>
  select(theta, frac, delta, cut, id, maxr, ess, dv, worst)), digits = 4)
cat("\nchange in posterior means, refit - original:\n")
j <- inner_join(select(new, id, cut, delta, variable, m1 = mean, lo1 = lo, hi1 = hi),
                select(old, id, cut, variable, m0 = mean, lo0 = lo, hi0 = hi),
                by = c("id", "cut", "variable"))
pr <- j |> filter(variable %in% c("beta[1]", "alpha[1]")) |>
  mutate(d = abs(plogis(m1) - plogis(m0)))
print(as.data.frame(pr |> group_by(variable, cut) |>
  summarise(mean_abs = mean(d), max_abs = max(d), .groups = "drop")), digits = 3)
print(as.data.frame(j |> filter(variable %in% c("lambda0", "sigma0", "delta")) |>
  group_by(variable, cut) |>
  summarise(width_old = mean(hi0 - lo0), width_new = mean(hi1 - lo1),
            mean_abs = mean(abs(m1 - m0)), .groups = "drop")), digits = 3)
