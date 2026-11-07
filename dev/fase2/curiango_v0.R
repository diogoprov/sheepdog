# Curiango data for model v0: site-nights as sites, minutes as occasions, the
# logit of the minute score censored at the classifier's minimum confidence.
# Sourced by emissions_curiango_v0.R and run_curiango_v0.R.
curiango_v0 <- function(classifier = c("custom", "birdnet"), c_lo = qlogis(0.1),
                        c_hi = qlogis(0.9999), prior_emissions = 1L) {
  classifier <- match.arg(classifier)
  zs <- function(x) as.numeric(scale(x))
  cu <- crywolf::curiango
  m <- cu$minutes[order(cu$minutes$site_night, cu$minutes$time), ]
  nt <- cu$nights[match(unique(m$site_night), cu$nights$site_night), ]
  # as in crywolf dev/curiango-dyn-common.R: means over the sites of each date
  daily <- stats::aggregate(cbind(temp, rh) ~ night, cu$nights, mean)
  daily$temp_d <- zs(daily$temp)
  daily$rh_d <- zs(daily$rh)
  k <- match(nt$night, daily$night)
  conf <- m[[paste0("conf_", classifier)]]
  raw <- suppressWarnings(qlogis(conf))
  cens <- ifelse(raw < c_lo, 1L, ifelse(raw > c_hi, 2L, 0L))
  ver <- match(paste(m$site_night, m$time),
               paste(cu$verified$site_night, cu$verified$time))
  v <- ifelse(is.na(ver), -1L, cu$verified$y[ver])
  stopifnot(sum(v >= 0L) == nrow(cu$verified))
  run <- rle(m$site_night)
  last <- cumsum(run$lengths)
  list(
    stan = list(
      N_site = length(last), N_occ = nrow(m),
      first = last - run$lengths + 1L, last = last,
      P_psi = 3L, X = cbind(1, daily$temp_d[k], daily$rh_d[k]),
      P_theta = 3L, D = cbind(1, zs(m$bio), zs(m$aci)),
      s = ifelse(cens == 0L, raw, 0), cens = cens, v = v,
      c_lo = c_lo, c_hi = c_hi, prior_emissions = prior_emissions
    ),
    minutes = m, night = nt$night[match(m$site_night, nt$site_night)]
  )
}
