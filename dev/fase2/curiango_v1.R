# Curiango data for model v1: the data of curiango_v0() plus `adj`, which
# marks minutes whose previous minute of the same site-night is one step back
# (15 min). Same rule as crywolf's fp_occu(markov = ): the step is the
# smallest interval within site-nights.
source("dev/fase2/curiango_v0.R")
curiango_v1 <- function(classifier = c("custom", "birdnet"), c_lo = qlogis(0.1),
                        c_hi = qlogis(0.9999)) {
  d <- curiango_v0(classifier, c_lo = c_lo, c_hi = c_hi)
  m <- d$minutes
  t <- as.numeric(m$time)
  n <- length(t)
  same <- c(FALSE, m$site_night[-1] == m$site_night[-n])
  dt <- c(NA, diff(t))
  step <- min(dt[same])
  d$stan$adj <- as.integer(same & abs(dt - step) <= 1e-8 * step)
  d$stan$prior_emissions <- NULL
  d
}
