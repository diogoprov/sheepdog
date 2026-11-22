# Plot the calibration curves

Calibrated probability of a true detection against the confidence score,
one panel per species and one line per site, with the observed precision
by confidence bin as points. Needs the 'ggplot2' package.

## Usage

``` r
plot_calibration(
  fit,
  validations,
  min_confidence = 0.1,
  p_min = 0.95,
  model_name = "",
  interval = FALSE,
  level = 0.95
)
```

## Arguments

- fit:

  Model returned by
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md).

- validations:

  Table returned by
  [`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md).

- min_confidence:

  Detections below this confidence are not scored.

- p_min:

  Threshold on the calibrated probability (not on the confidence score).

- model_name:

  Name shown in the subtitle.

- interval:

  Draw a band around each curve: a pointwise confidence interval of
  P(TP) for `glm` and `glmerMod` fits, a credible interval for `brmsfit`
  fits. `FALSE` (default) draws the curves only.

- level:

  Coverage of the band, a single number in (0, 1).

## Value

A ggplot object.

## Details

For a `glm` fit the band is the Wald interval of the linear predictor
(`predict(se.fit = TRUE)`) transformed by
[`plogis()`](https://rdrr.io/r/stats/Logistic.html). For a `glmerMod`
fit it is the same interval computed from the covariance matrix of the
fixed effects only: the predicted random effects are treated as known,
so the band is narrower than one that also carried their uncertainty,
and levels not seen in the fit get the fixed-effects interval. For a
`brmsfit` the band holds the central quantiles of the posterior draws of
P(TP)
([`brms::posterior_epred()`](https://mc-stan.org/rstantools/reference/posterior_epred.html))
and carries all the parameter uncertainty.
