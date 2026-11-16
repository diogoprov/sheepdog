# Summary of sim_oob.R by scenario x n x target.
#   Rscript dev/oob-6b/summarise_oob.R RES_RDS
r <- readRDS(commandArgs(TRUE)[1])
tol <- 0.02
r$fail <- r$prec_true < r$target - tol
r$fail_cons <- r$prec_true_cons < r$target - tol
r$flag_fixed <- is.na(r$lb_fixed) | r$lb_fixed < r$target - tol
r$flag_oob <- is.na(r$lb_oob) | r$lb_oob < r$target - tol
r$flag_q20f <- is.na(r$q20_fixed) | r$q20_fixed < r$target - tol
r$flag_q20o <- is.na(r$q20_oob) | r$q20_oob < r$target - tol
r$flag_mean <- is.na(r$mean_oob) | r$mean_oob < r$target - tol
key <- interaction(r$scen, r$n, r$target, drop = TRUE, lex.order = TRUE)
tab <- do.call(rbind, lapply(split(r, key), function(d) {
  h <- d[!is.na(d$t_hat), ]
  rate <- \(x) if (length(x) == 0) NA_real_ else mean(x)
  data.frame(
    scen = d$scen[1], n = d$n[1], target = d$target[1],
    has_thr = mean(!is.na(d$t_hat)),
    fail = rate(h$fail),
    fixed_flag = rate(h$flag_fixed),
    fixed_fail_clear = rate(h$fail[!h$flag_fixed]),
    fixed_sens = rate(h$flag_fixed[h$fail]),
    q20f_flag = rate(h$flag_q20f),
    q20f_fail_clear = rate(h$fail[!h$flag_q20f]),
    q20o_flag = rate(h$flag_q20o),
    q20o_fail_clear = rate(h$fail[!h$flag_q20o]),
    mean_flag = rate(h$flag_mean),
    mean_fail_clear = rate(h$fail[!h$flag_mean]),
    mean_sens = rate(h$flag_mean[h$fail]),
    oob_bias = mean(h$mean_oob - h$prec_true, na.rm = TRUE),
    naive_bias = mean(h$prec_true - h$target),
    cons_has = mean(!is.na(d$t_cons)),
    cons_fail = rate(d$fail_cons[!is.na(d$t_cons)]))
}))
rownames(tab) <- NULL
print(format(tab, digits = 2), row.names = FALSE)
invisible(tab)
