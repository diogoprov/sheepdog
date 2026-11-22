# Stage 1 with the census of scores (decision of 20/11/2026, item 4 of the
# PLANO). The f0 of the verified-only stage 1 inherits the sampling error of
# ~917 weighted negatives in the low tail (censored share 0.46, 90% 0.43 to
# 0.50, against 0.41 in the deposit), and stage 2 then calls mid-score minutes
# calling to make up for it. Here f0 and the marginal share p of calling
# minutes are fitted together on
#   * the verified negatives of the random draw (ct01 + ct02): log f0(s), with
#     the weights 1 / pi1 normalised to mean 1 (they count as n minutes);
#   * every other minute of the deposit (including ct03, whose labels are
#     not used because its selection depended on y): log(p f1(s) + (1 - p) f0(s)).
# f1 stays where the positives of emissions_ct12.rds put it: with f1 free the
# census pushes it to the low scores and p rises to 0.13 (printed, not saved).
# Composite likelihood: the minutes are treated as independent here; the
# temporal dependence is left to stage 2, and the uncertainty comes from the
# bootstrap over site-nights of the whole deposit. Same two-normal censored
# mixtures and min_sd floor as emissions_2stage_curiango.R.
#   Rscript dev/fase2/emissions_census_curiango.R OUT_DIR PI_CSV [n_boot]
# OUT_DIR must already hold emissions_ct12.rds; writes emissions_census.rds.
source("dev/fase2/curiango_v1.R")

emis_census <- function(d, lab, y, w, min_sd = 0.2, n_boot = 0L, seed = 2026L, start = NULL,
                        f1_fixed = NULL) {
  st <- d$stan
  one <- function(s, cens, mu, sd) ifelse(cens == 0L, dnorm(s, mu, sd),
    ifelse(cens == 1L, pnorm(st$c_lo, mu, sd), pnorm(st$c_hi, mu, sd, lower.tail = FALSE)))
  mix <- function(q, s, cens) plogis(q[1]) * one(s, cens, q[2], min_sd + exp(q[3])) +
    (1 - plogis(q[1])) * one(s, cens, q[2] + exp(q[4]), min_sd + exp(q[5]))
  # par = (logit p, f0 [5], f1 [5]); with f1_fixed (internal scale, 5
  # values), par = (logit p, f0 [5]) and f1 stays where the positives put it
  full <- function(par) if (is.null(f1_fixed)) par else c(par, f1_fixed)
  nll <- function(par, k_lab, k_unl) {
    par <- full(par)
    p <- plogis(par[1]); q0 <- par[2:6]; q1 <- par[7:11]
    s <- st$s; ce <- st$cens
    l0 <- mix(q0, s[k_lab], ce[k_lab]); l1 <- mix(q1, s[k_lab], ce[k_lab])
    ll_lab <- sum(w[k_lab] * log(pmax(ifelse(y[k_lab] == 1L, l1, l0), 1e-300)))
    ll_unl <- sum(log(pmax(p * mix(q1, s[k_unl], ce[k_unl]) +
                             (1 - p) * mix(q0, s[k_unl], ce[k_unl]), 1e-300)))
    -(ll_lab + ll_unl)
  }
  fit <- function(k_lab, k_unl, par0) {
    o <- optim(par0, nll, k_lab = k_lab, k_unl = k_unl, method = "BFGS",
               control = list(maxit = 2000, reltol = 1e-10))
    if (o$convergence != 0) warning("optim did not converge: ", o$convergence)
    o$par
  }
  nat <- function(q) c(pi = plogis(q[1]), mu_a = q[2], sd_a = min_sd + exp(q[3]),
                       mu_b = q[2] + exp(q[4]), sd_b = min_sd + exp(q[5]))
  if (is.null(start)) start <- c(qlogis(0.03), 0, -2, 0.5, 0, 0, 0, -1, 1, 0, 0)
  if (!is.null(f1_fixed)) start <- start[1:6]
  k_lab <- which(lab); k_unl <- which(!lab)
  par <- full(fit(k_lab, k_unl, start))
  boot <- NULL
  if (n_boot > 0L) {
    un <- paste(d$minutes$site, d$night)
    g <- split(seq_len(st$N_occ), un)
    boot <- withr::with_seed(seed, do.call(rbind, lapply(seq_len(n_boot), \(b) {
      idx <- unlist(g[sample.int(length(g), replace = TRUE)], use.names = FALSE)
      pb <- full(fit(idx[lab[idx]], idx[!lab[idx]], par[seq_len(if (is.null(f1_fixed)) 11 else 6)]))
      rbind(c(class = 0, b = b, p = plogis(pb[1]), nat(pb[2:6])),
            c(class = 1, b = b, p = plogis(pb[1]), nat(pb[7:11])))
    })))
  }
  list(p = plogis(par[1]), f0 = nat(par[2:6]), f1 = nat(par[7:11]), par = par,
       e0 = log(pmax(mix(par[2:6], st$s, st$cens), 1e-300)),
       e1 = log(pmax(mix(par[7:11], st$s, st$cens), 1e-300)),
       n_lab = c(neg = sum(y[k_lab] == 0L), pos = sum(y[k_lab] == 1L)), boot = boot)
}

if (sys.nframe() == 0L) {
  a <- commandArgs(TRUE)
  out <- a[1]; nb <- if (length(a) > 2) as.integer(a[3]) else 0L
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  d <- curiango_v1("custom", c_lo = qlogis(0.1)); st <- d$stan; m <- d$minutes
  p <- read.csv(a[2])
  km <- paste(m$site, format(m$time, "%Y-%m-%d %H:%M:%S"))
  j <- match(paste(p$site, p$time), km); stopifnot(!anyNA(j))
  ct12 <- p$stage == "ct12"
  lab <- rep(FALSE, st$N_occ); lab[j[ct12]] <- TRUE
  y <- rep(NA_integer_, st$N_occ); y[j[ct12]] <- p$y[ct12]
  w <- rep(1, st$N_occ); w[j[ct12]] <- (1 / p$pi1[ct12]) / mean(1 / p$pi1[ct12])
  old <- readRDS(file.path(out, "emissions_ct12.rds"))
  lq <- \(f) c(qlogis(f[["pi"]]), f[["mu_a"]], log(f[["sd_a"]] - 0.2),
               log(f[["mu_b"]] - f[["mu_a"]]), log(f[["sd_b"]] - 0.2))
  start <- c(qlogis(0.03), lq(old$f0), lq(old$f1))
  t0 <- Sys.time()
  # f1 livre (o censo empurra f1 para os scores baixos) e f1 fixa pelos
  # positivos do sorteio (f0 e p pelo censo); a segunda e a usada no estagio 2
  r_livre <- emis_census(d, lab, y, w, start = start)
  cat("f1 livre: p =", round(r_livre$p, 4), "\n")
  y_neg <- y; lab_neg <- lab & y %in% 0L
  r <- emis_census(d, lab_neg, y_neg, w, n_boot = nb, start = start, f1_fixed = lq(old$f1))
  cat("segundos:", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "\n")
  cat("p (fracao de minutos com canto, composta):", round(r$p, 4), "\n")
  print(round(rbind(f0_antiga = old$f0, f0_censo = r$f0, f1_antiga = old$f1, f1_censo = r$f1), 3))
  up <- \(f, t) f[["pi"]] * pnorm(t, f[["mu_a"]], f[["sd_a"]]) + (1 - f[["pi"]]) * pnorm(t, f[["mu_b"]], f[["sd_b"]])
  cat("massa censurada: f0 antiga", round(up(old$f0, st$c_lo), 4), " f0 censo", round(up(r$f0, st$c_lo), 4),
      " deposito", round(mean(st$cens == 1L), 4), "\n")
  cat("acima de 0,4: f1 antiga", round(1 - up(old$f1, qlogis(0.4)), 3), " f1 censo", round(1 - up(r$f1, qlogis(0.4)), 3), "\n")
  if (!is.null(r$boot)) {
    b <- as.data.frame(r$boot)
    print(aggregate(. ~ class, b[, -2], \(x) round(quantile(x, c(.05, .5, .95)), 3)))
  }
  saveRDS(r, file.path(out, "emissions_census.rds"))
}
