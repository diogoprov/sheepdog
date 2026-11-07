# Does "stays above the target" suit the empirical thresholds? (sheepdog#104)
# Cells with n reviewed clips, scores uniform on (0.1, 0.99), a true logistic
# curve. For each rule: share of cells without a threshold, mean threshold, and
# true precision of the detections kept by the threshold.
#   Rscript dev/sustained-threshold-rule.R   (from the package root)
suppressMessages(devtools::load_all(quiet = TRUE))
curve <- function(x) plogis(-1 + 1.2 * qlogis(x))
xs <- seq(0.1, 0.99, by = 0.0005)
true_prec <- function(c0) mean(curve(xs[xs >= c0]))
one <- function(n, min_n) {
  conf <- runif(n, 0.1, 0.99)
  v <- tibble::tibble(site = "A", species_folder = "sp", confidence = conf,
                      verdict = ifelse(rbinom(n, 1, curve(conf)) == 1,
                                       "positive", "negative"))
  c(first = suggest_thresholds(v, 0.9, min_n, sustained = FALSE)$threshold,
    sustained = suggest_thresholds(v, 0.9, min_n, sustained = TRUE)$threshold)
}
set.seed(2026)
truth <- xs[which(vapply(xs, true_prec, 0) >= 0.9)[1]]
cat("cut with true precision 0.90:", truth, "\n")
res <- do.call(rbind, lapply(c(50, 100, 300, 1500), \(n) {
  r <- replicate(400, one(n, 15))
  do.call(rbind, lapply(rownames(r), \(k) {
    x <- r[k, ]; ok <- x[!is.na(x)]; tp <- vapply(ok, true_prec, 0)
    data.frame(n = n, rule = k, share_na = mean(is.na(x)), mean_cut = mean(ok),
               true_prec = mean(tp), below_target = mean(tp < 0.9))
  }))
}))
print(res, digits = 3)
