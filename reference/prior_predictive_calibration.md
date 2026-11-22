# Prior predictive calibration curves

Samples the calibration model from the prior only (no data enter the
likelihood), so that the curves it implies on the probability scale can
be checked before the model is fitted. Plot them with
[`plot_calibration()`](https://provetelab.org/sheepdog/reference/plot_calibration.md).

## Usage

``` r
prior_predictive_calibration(formula, validations, prior, ...)
```

## Arguments

- formula:

  A model formula, the calibration formula (see
  [`calibration_models()`](https://provetelab.org/sheepdog/reference/calibration_models.md)).

- validations:

  A data frame (or tibble) returned by
  [`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md),
  one row per reviewed clip.

- prior:

  A `brmsprior` object, the prior, e.g. from
  [`calibration_prior()`](https://provetelab.org/sheepdog/reference/calibration_prior.md).

- ...:

  Further arguments for
  [`brms::brm()`](https://paulbuerkner.com/brms/reference/brm.html)
  (e.g. `chains`, `iter`, `backend`, `seed`).

## Value

A `brmsfit` sampled from the prior, usable in
[`plot_calibration()`](https://provetelab.org/sheepdog/reference/plot_calibration.md).

## Examples

``` r
# Sampling from the prior compiles a Stan model, which takes minutes
if (FALSE) { # \dontrun{
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validations(list.files(file.path(ex, "validation"),
                                   full.names = TRUE))
f <- tp ~ logit_conf + (1 | species)
prior_fit <- prior_predictive_calibration(f, val, calibration_prior(f, val),
                                          chains = 2, seed = 1,
                                          refresh = 0)
plot_calibration_draws(prior_fit)
} # }
```
