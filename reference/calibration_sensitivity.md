# Prior and likelihood sensitivity of a Bayesian calibration model

Power-scaling sensitivity analysis with 'priorsense' (Kallioinen et al.
2024,
[doi:10.1007/s11222-023-10366-5](https://doi.org/10.1007/s11222-023-10366-5)
): how much the posterior changes when the prior or the likelihood is
up- or down-weighted. A prior-data conflict or a strongly informative
prior shows up as sensitivity to both.

## Usage

``` r
calibration_sensitivity(fit, variable = NULL, ...)
```

## Arguments

- fit:

  A `brmsfit` returned by
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
  with `engine = "brms"`.

- variable:

  `NULL` or a character vector of the names of the parameters to
  analyse. `NULL` takes the population-level effects and the standard
  deviations and correlations of the random effects (`b_`, `sd_`,
  `cor_`), leaving out the individual random effects.

- ...:

  Further arguments for
  [`priorsense::powerscale_sensitivity()`](https://mc-stan.org/priorsense/reference/powerscale-sensitivity.html).

## Value

The table of
[`priorsense::powerscale_sensitivity()`](https://mc-stan.org/priorsense/reference/powerscale-sensitivity.html).

## Examples

``` r
# Fitting a Bayesian calibration compiles a Stan model, which takes
# minutes, so this example is not run here.
if (FALSE) { # \dontrun{
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validations(list.files(file.path(ex, "validation"),
                                   full.names = TRUE))
f <- tp ~ logit_conf + (1 | species)
fit <- fit_calibration(val, f, engine = "brms",
                       prior = calibration_prior(f, val),
                       chains = 4, iter = 2000, seed = 1, refresh = 0)
calibration_sensitivity(fit)
# Only the slope on the logit of the score
calibration_sensitivity(fit, variable = "b_logit_conf")
} # }
```
