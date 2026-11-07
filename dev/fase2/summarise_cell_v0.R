# Summarises run_cell_v0.R against the criteria fixed in dev/fase2/README.md.
#   Rscript dev/fase2/summarise_cell_v0.R OUT_DIR [VAL2_DIR]
# With VAL2_DIR, sets 1 to 60 are also paired with the fits under prior A.
suppressPackageStartupMessages(library(dplyr))
a <- commandArgs(TRUE)
all <- file.path(a[1], "task_all.rds")
d <- if (file.exists(all)) readRDS(all) else
  bind_rows(lapply(list.files(a[1], "^task_[0-9].*rds$", full.names = TRUE), readRDS))
cat("data sets:", n_distinct(d$id), "\n")

fits <- d |> group_by(id, rep) |>
  summarise(rhat = max(rhat), ess = min(ess_bulk), div = first(divergent),
            secs = first(seconds), conv = first(ml_conv), .groups = "drop")
cat("max R-hat", max(fits$rhat), " min ESS", min(fits$ess),
    " fits with divergences", sum(fits$div > 0), " with R-hat >= 1.01",
    sum(fits$rhat >= 1.01), " ML not converged", sum(fits$conv != 0),
    " median s", median(fits$secs), "\n")

prob <- d |> filter(variable %in% c("beta[1]", "alpha[1]")) |>
  mutate(par = ifelse(variable == "beta[1]", "psi", "theta"),
         truth = ifelse(par == "psi", 0.5, theta),
         est = plogis(mean), l = plogis(lo), h = plogis(hi))
crit <- \(x) x |> group_by(par) |>
  summarise(n = n(), bias = mean(est - truth), ep = sd(est) / sqrt(n()),
            coverage = mean(l <= truth & truth <= h),
            above = sum(l > truth), below = sum(h < truth),
            width = mean(h - l), .groups = "drop") |>
  as.data.frame() |> print(digits = 3)
cat("\n== criterion 2, all sets ==\n"); crit(prob)
cat("\n== sets 1 to 60 ==\n"); crit(filter(prob, rep <= 60))
cat("\n== sets 61 onward ==\n"); crit(filter(prob, rep > 60))

th <- d |> filter(variable == "alpha[1]") |>
  mutate(ml = plogis(ml_alpha), d_plogis = plogis(mean) - ml,
         d_mean = theta_mean - ml, d_median = theta_median - ml,
         ml_cov = plogis(ml_alpha - 1.96 * ml_se) <= theta &
           theta <= plogis(ml_alpha + 1.96 * ml_se))
shift <- \(x) x |>
  summarise(n = n(), plogis_alpha = mean(d_plogis),
            ep_plogis = sd(d_plogis) / sqrt(n()), mean = mean(d_mean),
            ep_mean = sd(d_mean) / sqrt(n()), median = mean(d_median),
            ep_median = sd(d_median) / sqrt(n()),
            mean_minus_median = mean(theta_mean - theta_median),
            ml_bias = mean(ml - theta), ml_cov = mean(ml_cov)) |>
  as.data.frame() |> print(digits = 3)
cat("\n== shift against maximum likelihood, theta ==\n")
cat("all sets\n"); shift(th)
cat("sets 1 to 60\n"); shift(filter(th, rep <= 60))

if (length(a) > 1) {
  v <- readRDS(file.path(a[2], "task_all.rds")) |>
    filter(cut == 0.1, variable == "alpha[1]") |>
    select(id, a_mean = mean, a_lo = lo, a_hi = hi)
  x <- inner_join(th, v, by = "id") |>
    mutate(a = plogis(a_mean), diff = plogis(mean) - a,
           a_cov = plogis(a_lo) <= theta & theta <= plogis(a_hi),
           c_cov = plogis(lo) <= theta & theta <= plogis(hi))
  cat("\n== paired with prior A, same data ==\n")
  x |> summarise(n = n(), cov_A = mean(a_cov), cov_C = mean(c_cov),
                 lost = sum(a_cov & !c_cov), gained = sum(!a_cov & c_cov),
                 C_minus_A = mean(diff), ep = sd(diff) / sqrt(n()),
                 A_minus_ml = mean(a - ml), C_minus_ml = mean(d_plogis)) |>
    as.data.frame() |> print(digits = 3)
}
