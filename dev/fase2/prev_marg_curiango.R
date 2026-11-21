# Marginal prevalence of calling minutes implied by a two-stage v1 fit on the
# Curiango (mean over minutes of psi * P(w = 1 | z = 1), forward recursion of
# the Markov chain), with diagnostics; same computation as prev_marg() in
# sim_surtos_curiango.R.
#   Rscript dev/fase2/prev_marg_curiango.R FIT_RDS [FIT_RDS ...]
source("dev/fase2/curiango_v1.R")
d <- curiango_v1("custom", c_lo = qlogis(0.1)); st <- d$stan
len <- st$last - st$first + 1L
site <- rep(seq_len(st$N_site), len); pos <- sequence(len); adj <- st$adj == 1L
idx_pos <- split(seq_len(st$N_occ), pos)
prev_marg <- function(dr) {
  B <- dr[, grep("^beta\\[", colnames(dr)), drop = FALSE]
  A <- dr[, grep("^alpha\\[", colnames(dr)), drop = FALSE]
  rho <- if ("rho[1]" %in% colnames(dr)) dr[, "rho[1]"] else rep(0, nrow(dr)); nd <- nrow(dr)
  psi <- plogis(st$X %*% t(B))
  soma <- numeric(nd); p1 <- NULL
  for (j in seq_along(idx_pos)) {
    k <- idx_pos[[j]]
    pe <- plogis(st$D[k, , drop = FALSE] %*% t(A))
    if (j == 1L) p1 <- pe else {
      pp <- p1[match(k - 1L, idx_pos[[j - 1L]]), , drop = FALSE]
      per <- plogis(st$D[k, , drop = FALSE] %*% t(A) + matrix(rho, length(k), nd, byrow = TRUE))
      ct <- adj[k]
      p1 <- pe
      p1[ct, ] <- pp[ct, , drop = FALSE] * per[ct, , drop = FALSE] +
        (1 - pp[ct, , drop = FALSE]) * pe[ct, , drop = FALSE]
    }
    soma <- soma + colSums(psi[site[k], , drop = FALSE] * p1)
  }
  soma / st$N_occ
}
for (f in commandArgs(TRUE)) {
  x <- readRDS(f); s <- x$summary
  pm <- prev_marg(x$draws[round(seq(1, nrow(x$draws), length.out = 1000)), , drop = FALSE])
  cat(f, "\n  prevalencia marginal:", round(quantile(pm, c(.05, .5, .95)), 4),
      "\n  divergencias:", sum(x$diag$num_divergent), " treedepth max:", sum(x$diag$num_max_treedepth),
      " E-BFMI min:", round(min(x$diag$ebfmi), 2), " R-hat max:", round(max(s$rhat, na.rm = TRUE), 3),
      " ESS bulk min:", round(min(s$ess_bulk, na.rm = TRUE)), "\n")
  print(s[s$variable %in% c("rho[1]", "psi_c", "theta_bar"), c("variable", "median", "q5", "q95")], digits = 3)
}
