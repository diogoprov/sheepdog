# Calibration curves of posterior (or prior) draws

Draws the population-level calibration curve, P(TP) against the score,
for `n_draws` draws of a Bayesian calibration model, without the species
and site effects. With a model from
[`prior_predictive_calibration()`](https://provetelab.org/sheepdog/reference/prior_predictive_calibration.md)
it shows what the prior implies on the probability scale (a prior
predictive check); with a fitted model, the uncertainty of the curve.
Needs the 'ggplot2' package.

## Usage

``` r
plot_calibration_draws(fit, n_draws = 100, p_min = 0.95, seed = 2026)
```

## Arguments

- fit:

  A `brmsfit` returned by
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
  with `engine = "brms"` or by
  [`prior_predictive_calibration()`](https://provetelab.org/sheepdog/reference/prior_predictive_calibration.md).

- n_draws:

  Integer scalar \>= 1, number of curves (at most the number of draws in
  `fit`).

- p_min:

  Numeric scalar in \[0, 1\], threshold drawn as a dashed line.

- seed:

  Integer scalar, seed of the choice of draws. The global random number
  generator is left as it was.

## Value

A ggplot object.

## Examples

``` r
if (FALSE) { # interactive() && requireNamespace("brms", quietly = TRUE)
# Sampling from the prior or the posterior compiles a Stan model, which
# takes minutes, so this example runs only interactively.
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validations(list.files(file.path(ex, "validation"),
                                   full.names = TRUE))
f <- tp ~ logit_conf + (1 | species)
prior <- calibration_prior(f, val)
# Prior predictive check
prior_fit <- prior_predictive_calibration(f, val, prior, chains = 2,
                                          seed = 1, refresh = 0)
plot_calibration_draws(prior_fit, n_draws = 100)
# Uncertainty of the fitted curve
fit <- fit_calibration(val, f, engine = "brms", prior = prior,
                       chains = 4, iter = 2000, seed = 1, refresh = 0)
plot_calibration_draws(fit, n_draws = 100, p_min = 0.95)
}
```
