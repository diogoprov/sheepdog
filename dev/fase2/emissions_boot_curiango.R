# Per-minute stage 1 log densities for replicates of the night bootstrap of
# the emissions (emis$boot from emissions_ct12_curiango.R), so that stage 2
# (run_curiango_2stage.R) can be refitted on each replicate and the stage 1
# uncertainty enters the pooled posterior. The sds in emis$boot already carry
# the min_sd floor (natural scale).
#   Rscript dev/fase2/emissions_boot_curiango.R EMIS_RDS OUT_DIR [n_rep]
source("dev/fase2/curiango_v1.R")
a <- commandArgs(TRUE)
em <- readRDS(a[1]); out <- a[2]; nr <- if (length(a) > 2) as.integer(a[3]) else 20L
dir.create(out, recursive = TRUE, showWarnings = FALSE)
st <- curiango_v1("custom", c_lo = qlogis(0.1))$stan
one <- function(cens, mu, sd) ifelse(cens == 0L, dnorm(st$s, mu, sd),
  ifelse(cens == 1L, pnorm(st$c_lo, mu, sd), pnorm(st$c_hi, mu, sd, lower.tail = FALSE)))
ld <- function(p) log(pmax(p[["pi"]] * one(st$cens, p[["mu_a"]], p[["sd_a"]]) +
  (1 - p[["pi"]]) * one(st$cens, p[["mu_b"]], p[["sd_b"]]), 1e-300))
b <- as.data.frame(em$boot)
for (r in seq_len(nr)) {
  f0 <- unlist(b[b$class == 0 & b$b == r, c("pi", "mu_a", "sd_a", "mu_b", "sd_b")])
  f1 <- unlist(b[b$class == 1 & b$b == r, c("pi", "mu_a", "sd_a", "mu_b", "sd_b")])
  saveRDS(list(rate = em$rate, f0 = f0, f1 = f1, n_eff = em$n_eff, e0 = ld(f0), e1 = ld(f1), rep = r),
          file.path(out, sprintf("emis_b%02d.rds", r)))
}
cat("replicas gravadas:", nr, "\n")
