# Summarises run_val_v0.R against the criteria of dev/fase2/README.md.
#   Rscript dev/fase2/summarise_val_v0.R OUT_DIR
suppressPackageStartupMessages(library(dplyr))
out <- commandArgs(TRUE)[1]
d <- bind_rows(lapply(list.files(out, "^task_.*rds$", full.names = TRUE),
                      readRDS))
cat("data sets:", n_distinct(d$id), " fits:", n_distinct(paste(d$id, d$cut)),
    " errors:", n_distinct(paste(d$id, d$cut)[!is.na(d$error)]), "\n")
d <- filter(d, is.na(error)) |>
  mutate(main = theta > 0.1 & frac > 0)

fits <- d |>
  group_by(main, theta, frac, delta, cut, id) |>
  summarise(ok = max(rhat) < 1.01 & first(divergent) == 0, .groups = "drop")
cat("\n== criterion 1: share of fits with R-hat < 1.01 and no divergences ==\n")
fits |> group_by(main, theta, frac, delta, cut) |>
  summarise(n = n(), ok = mean(ok), .groups = "drop") |>
  arrange(desc(main), theta, frac, delta, cut) |>
  as.data.frame() |> print(digits = 3)

prob <- d |>
  filter(variable %in% c("beta[1]", "alpha[1]")) |>
  mutate(par = ifelse(variable == "beta[1]", "psi", "theta"),
         truth = ifelse(par == "psi", 0.5, theta),
         est = plogis(mean), l = plogis(lo), h = plogis(hi),
         covered = l <= truth & truth <= h)
cat("\n== criterion 2: psi and theta, pooled over cuts ==\n")
prob |> group_by(main, par, theta, frac, delta) |>
  summarise(n = n(), bias = mean(est - truth), coverage = mean(covered),
            .groups = "drop") |>
  arrange(desc(main), par, theta, frac, delta) |>
  as.data.frame() |> print(digits = 3)
cat("\n== by cut ==\n")
prob |> group_by(main, par, cut, delta) |>
  summarise(n = n(), bias = mean(est - truth), coverage = mean(covered),
            .groups = "drop") |>
  arrange(desc(main), par, delta, cut) |> as.data.frame() |> print(digits = 3)

base <- prob |> filter(cut == 0.1) |> select(id, par, est0 = est)
cat("\n== criterion 4: paired change against c = logit(0.1) ==\n")
prob |> filter(cut > 0.1) |> inner_join(base, by = c("id", "par")) |>
  group_by(main, par, theta, frac, delta, cut) |>
  summarise(n = n(), mean_abs = mean(abs(est - est0)),
            p95 = quantile(abs(est - est0), 0.95), .groups = "drop") |>
  arrange(desc(main), par, theta, frac, delta, cut) |>
  as.data.frame() |> print(digits = 3)

cat("\n== slopes (reported only) ==\n")
d |> filter(variable %in% c("beta[2]", "alpha[2]")) |>
  mutate(truth = ifelse(variable == "beta[2]", -0.8, 0.6)) |>
  group_by(main, variable, delta) |>
  summarise(n = n(), bias = mean(mean - truth),
            coverage = mean(lo <= truth & truth <= hi), .groups = "drop") |>
  as.data.frame() |> print(digits = 3)
