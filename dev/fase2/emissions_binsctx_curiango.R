# Stage 1 by score bin x context (21/11/2026, after curiango_teste_emissoes.R).
# Given w, the bin of a minute depends on the scores next to it: close to a
# burst both f1 and f0 move up, and a mid score there indicates calling about
# 2.5 times less than the same score far from a burst. Here the emissions
# condition on the previous minute only, so the likelihood stays proper (an
# autoregressive HMM, p(s_n | w_n, s_{n-1})):
#   context c_n = 1 if the previous minute (contiguous, same site-night) has
#   score >= 0.4, else 0 (also for the first minute after a gap);
#   f_w(b | c) normalised within each context.
# As in emissions_bins_curiango.R, calling minutes of cell (b, c) are the
# precision of the cell times its minutes in the deposit. Precision: 0 below
# 0.1 and 1 at >= 0.4 (as in the bins version); in the mid bins, a weighted
# logistic regression on the verified minutes of ct01 + ct02 (weights 1 / pi1),
# y ~ bin + context, because the cells next to a burst hold few labels.
#   Rscript dev/fase2/emissions_binsctx_curiango.R OUT_DIR PI_CSV
source("dev/fase2/curiango_v1.R")
breaks <- c(-1, 0.1, 0.2, 0.3, 0.4, 2)

context_prev <- function(prob, adj) {
  c(0L, as.integer(prob[-length(prob)] >= 0.4)) * as.integer(adj == 1L)
}

emis_binsctx <- function(b, cx, lab, y, w, nb = length(breaks) - 1L, a0 = 0.5) {
  k <- which(lab)
  mid <- k[b[k] %in% 2:(nb - 1L)]
  df <- data.frame(y = y[mid], b = factor(b[mid], 2:(nb - 1L)), cx = cx[mid], w = w[mid] / mean(w[mid]))
  g <- suppressWarnings(glm(y ~ b + cx, family = binomial, data = df, weights = w))
  grid <- expand.grid(b = 1:nb, cx = 0:1)
  prec <- rep(NA_real_, nrow(grid))
  prec[grid$b == 1L] <- 0; prec[grid$b == nb] <- 1
  im <- grid$b %in% 2:(nb - 1L)
  prec[im] <- predict(g, data.frame(b = factor(grid$b[im], 2:(nb - 1L)), cx = grid$cx[im]), type = "response")
  N <- vapply(seq_len(nrow(grid)), \(i) sum(b == grid$b[i] & cx == grid$cx[i]), 0)
  n1 <- prec * N; n0 <- N - n1
  f1 <- f0 <- numeric(nrow(grid))
  for (cc in 0:1) {
    s <- grid$cx == cc
    f1[s] <- (n1[s] + a0) / sum(n1[s] + a0)
    f0[s] <- (n0[s] + a0) / sum(n0[s] + a0)
  }
  cell <- b + nb * cx
  list(type = "binsctx", breaks = breaks, grid = grid, f0 = f0, f1 = f1, rate = prec, N = N,
       coef = coef(summary(g)), e0 = log(f0[cell]), e1 = log(f1[cell]))
}

if (sys.nframe() == 0L) {
  a <- commandArgs(TRUE)
  out <- a[1]
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  d <- curiango_v1("custom", c_lo = qlogis(0.1)); st <- d$stan; m <- d$minutes
  prob <- ifelse(st$cens == 1L, 0, plogis(st$s)); prob[st$cens == 2L] <- 1
  b <- as.integer(cut(prob, breaks, right = FALSE))
  cx <- context_prev(prob, st$adj)
  p <- read.csv(a[2])
  j <- match(paste(p$site, p$time), paste(m$site, format(m$time, "%Y-%m-%d %H:%M:%S")))
  stopifnot(!anyNA(j))
  k12 <- p$stage == "ct12"
  lab <- rep(FALSE, st$N_occ); lab[j[k12]] <- TRUE
  y <- rep(NA_integer_, st$N_occ); y[j[k12]] <- p$y[k12]
  w <- rep(1, st$N_occ); w[j[k12]] <- 1 / p$pi1[k12]
  r <- emis_binsctx(b, cx, lab, y, w)
  cat("ct12 por faixa x contexto x y:\n"); print(table(b = b[lab], cx = cx[lab], y = y[lab]))
  print(round(r$coef, 3))
  lb <- c("<0.1", "0.1-0.2", "0.2-0.3", "0.3-0.4", ">=0.4")
  print(data.frame(bin = lb[r$grid$b], context = r$grid$cx, minutes = r$N, precision = round(r$rate, 4),
                   calls = round(r$rate * r$N), f0 = signif(r$f0, 3), f1 = signif(r$f1, 3),
                   log_ratio = round(log(r$f1 / r$f0), 2)), row.names = FALSE)
  cat("minutos com canto implicados:", round(sum(r$rate * r$N)), "de", st$N_occ,
      "=", round(sum(r$rate * r$N) / st$N_occ, 4), "\n")
  saveRDS(r, file.path(out, "emissions_binsctx.rds"))
}
