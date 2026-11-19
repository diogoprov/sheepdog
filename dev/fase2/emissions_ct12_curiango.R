# Stage 1 emissions on the Curiango after the test-set reconstruction
# (decision of 19/11/2026, option (a) with (c) as sensitivity).
#   (a) only the random draw (ct01 + ct02, 960 verified), weights 1 / pi1
#       (pi1 = fitted inclusion given year-month, hour and site);
#   (c) all 1,199 verified; the ct03 minutes get pi3 corrected for selection
#       on the true state: pi3 * P(y | x, ct03) / P(y | x, population), with
#       P(y | x, population) from the weighted draw and x = (Clima_noite
#       score, [Clima_noite = 0], custom score). Assumes the selection on y is
#       a constant shift in log-odds given x (the interaction test says it is
#       not, LRT ~10 on 1 df), so (c) is a sensitivity only.
# pi1, pi3 come from curiango_pi_ct03.R (results/curiango_v1/pi_verificados.csv).
# The weights are kept fixed in the bootstrap over nights.
#   Rscript dev/fase2/emissions_ct12_curiango.R OUT_DIR PI_CSV [n_boot]
source("dev/fase2/emissions_2stage_curiango.R")
a <- commandArgs(TRUE)
out <- a[1]; nb <- if (length(a) > 2) as.integer(a[3]) else 0L
dir.create(out, recursive = TRUE, showWarnings = FALSE)
p <- read.csv(a[2])
d <- curiango_v1("custom", c_lo = qlogis(0.1))
m <- d$minutes
km <- paste(m$site, format(m$time, "%Y-%m-%d %H:%M:%S")); kp <- paste(p$site, p$time)
j <- match(km, kp)
stopifnot(sum(!is.na(j)) == nrow(p), all(d$stan$v[!is.na(j)] >= 0L))
lg <- function(x) qlogis(pmin(pmax(x, 1e-3), 0.999))
p <- transform(p, lbc = ifelse(bn_clima > 0, lg(bn_clima), 0), bc0 = as.integer(bn_clima == 0),
               lcu = lg(conf_custom))
ct12 <- p$stage == "ct12"
# (a)
use_a <- !is.na(j) & ct12[j] %in% TRUE
w_a <- rep(0, nrow(m)); w_a[use_a] <- 1 / p$pi1[j[use_a]]
# (c)
# bias-reduced fits (brglm2): the draw has no positive with custom < 0.1, and
# plain glm separates, giving ratios of order 1e15
p$wn <- (1 / p$pi1) / mean(1 / p$pi1[ct12])
g_pop <- suppressWarnings(glm(y ~ lbc + bc0 + lcu, binomial, p[ct12, ], weights = wn,
                              method = brglm2::brglmFit))
g_03 <- suppressWarnings(glm(y ~ lbc + bc0 + lcu, binomial, p[!ct12, ], method = brglm2::brglmFit))
py <- function(g, k) { q <- predict(g, p[k, ], type = "response"); ifelse(p$y[k] == 1, q, 1 - q) }
r <- py(g_03, !ct12) / py(g_pop, !ct12)
pic <- p$pi1; pic[!ct12] <- p$pi1[!ct12] + (1 - p$pi1[!ct12]) * pmin(1, p$pi3[!ct12] * r)
use_c <- !is.na(j)
w_c <- rep(0, nrow(m)); w_c[use_c] <- 1 / pic[j[use_c]]
cat("pi efetivo dos ct03 (c):", round(quantile(pic[!ct12], c(.05, .5, .95)), 3), "\n")
cat("ct03: razao r, positivos:", round(quantile(r[p$y[!ct12] == 1], c(.05, .5, .95)), 2),
    " negativos:", round(quantile(r[p$y[!ct12] == 0], c(.05, .5, .95)), 2), "\n")
# min_sd = 0.2: with 43 positives the f1 mixture otherwise collapses onto a
# spike (sd 0.03) at three heavily weighted scores
ra <- emis_2stage(d, n_boot = nb, use = use_a, w = w_a, min_sd = 0.2)
rc <- emis_2stage(d, n_boot = nb, use = use_c, w = w_c, min_sd = 0.2)
saveRDS(ra, file.path(out, "emissions_ct12.rds")); saveRDS(rc, file.path(out, "emissions_ct03r.rds"))
old <- file.path(out, "emissions_2stage.rds")
tab <- list(a_ct12 = ra, c_ct03r = rc)
if (file.exists(old)) tab <- c(tab, list(antigo_estratos = readRDS(old)))
for (nm in names(tab)) {
  cat("\n", nm, " n efetivo:", round(tab[[nm]]$n_eff, 1), "\n")
  print(round(rbind(f0 = tab[[nm]]$f0, f1 = tab[[nm]]$f1), 3))
  if (!is.null(tab[[nm]]$boot)) {
    b <- as.data.frame(tab[[nm]]$boot)
    print(aggregate(. ~ class, b[, -2], \(x) round(quantile(x, c(.05, .95)), 3)))
  }
}
# P(score > logit(0.4) | class) and the implied precision at the mean prevalence
pr <- function(f, t = qlogis(0.4)) f["pi"] * pnorm(t, f["mu_a"], f["sd_a"], lower.tail = FALSE) +
  (1 - f["pi"]) * pnorm(t, f["mu_b"], f["sd_b"], lower.tail = FALSE)
cat("\nP(s > logit 0,4 | y):\n")
print(round(sapply(tab, \(e) c(f0 = unname(pr(e$f0)), f1 = unname(pr(e$f1)))), 4))
