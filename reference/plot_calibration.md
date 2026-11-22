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

  A `glm`, `glmerMod` or `brmsfit` returned by
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md).

- validations:

  A data frame (or tibble) returned by
  [`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md),
  one row per reviewed clip.

- min_confidence:

  Numeric scalar in \[0, 1\]. Detections below this confidence are not
  scored.

- p_min:

  Numeric scalar in \[0, 1\], threshold on the calibrated probability
  (not on the confidence score).

- model_name:

  Character scalar, name shown in the subtitle.

- interval:

  Logical scalar. If `TRUE`, draw a band around each curve: a pointwise
  confidence interval of P(TP) for `glm` and `glmerMod` fits, a credible
  interval for `brmsfit` fits. `FALSE` (default) draws the curves only.

- level:

  Numeric scalar in (0, 1), coverage of the band.

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

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validations(list.files(file.path(ex, "validation"),
                                   full.names = TRUE))
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
if (requireNamespace("lme4", quietly = TRUE) &&
    requireNamespace("ggplot2", quietly = TRUE)) {
  fit <- fit_calibration(val, tp ~ logit_conf + (1 | species))
  plot_calibration(fit, val, model_name = "species intercept",
                   interval = TRUE)
}
```
