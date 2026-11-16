# Summary of sim_pamflow.R by scenario x n x target x arm.
#   Rscript dev/oob-6b/summarise_pamflow.R RES_RDS
r <- readRDS(commandArgs(TRUE)[1])
tol <- 0.02
key <- interaction(r$scen, r$n, r$target, r$arm, drop = TRUE, lex.order = TRUE)
tab <- do.call(rbind, lapply(split(r, key), function(d) {
  h <- d[!is.na(d$threshold), ]
  rate <- \(x) if (length(x) == 0) NA_real_ else mean(x, na.rm = TRUE)
  data.frame(scen = d$scen[1], n = d$n[1], target = d$target[1],
             arm = d$arm[1],
             has_thr = mean(!is.na(d$threshold)),
             thr_mean = rate(h$threshold),
             fail_prec = rate(h$prec_true < h$target - tol),
             fail_local = rate(h$local_true < h$target - tol),
             prec_mean = rate(h$prec_true),
             recall = rate(h$recall))
}))
rownames(tab) <- NULL
print(format(tab, digits = 2), row.names = FALSE)
invisible(tab)
