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

  Model returned by
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
  with `engine = "brms"`.

- variable:

  Parameters to analyse. `NULL` takes the population-level effects and
  the standard deviations and correlations of the random effects (`b_`,
  `sd_`, `cor_`), leaving out the individual random effects.

- ...:

  Further arguments for `priorsense::powerscale_sensitivity()`.

## Value

The table of `priorsense::powerscale_sensitivity()`.
