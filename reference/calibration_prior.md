# Example prior for a Bayesian calibration model

Builds a weakly informative prior for a calibration formula, centred on
the hypothesis that the BirdNET score is already calibrated: on the
model scale (`tp ~ logit_conf`), intercept 0 and slope 1 mean P(TP) =
score. The data then show how far the classifier departs from it. Only
the classes present in the formula are returned:

## Usage

``` r
calibration_prior(formula, validations)
```

## Arguments

- formula:

  Calibration formula (see
  [`calibration_models()`](https://provetelab.org/sheepdog/reference/calibration_models.md)).

- validations:

  Table returned by
  [`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md).

## Value

A `brmsprior` object.

## Details

- `Intercept`: `normal(m, 1.5)`, where `m` is the mean of `logit_conf`
  among the reviewed clips. 'brms' centres the predictors, so its
  intercept is the logit of P(TP) at the mean logit score; with a slope
  of 1, an intercept equal to that mean gives P(TP) = score;

- `b` (slope of `logit_conf`): `normal(1, 1)` truncated at 0, centred on
  a calibrated score, wide enough to allow slopes from near 0 to near 3,
  and assuming that a higher score never lowers P(TP);

- other population-level terms, such as a continuous covariate of the
  occasion (`tp ~ logit_conf + temp`): `normal(0, 1)`, which suits a
  standardised covariate. 'brms' bounds a whole class, not a single
  coefficient, so with such terms the slope of `logit_conf` keeps
  `normal(1, 1)` without the truncation at 0. A warning is raised when
  such a numeric covariate is not standardised (absolute mean above 0.25
  or standard deviation outside 0.5 to 2);

- `sd` (standard deviations of the random effects): `exponential(1)`;

- `cor` (correlations between random effects): `lkj(2)`, which pulls the
  correlations away from +-1 (the singular fits of m4 with 'lme4').

This is an example, not a default:
[`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
with `engine = "brms"` requires the prior to be given explicitly. Check
what it implies on the probability scale with
[`prior_predictive_calibration()`](https://provetelab.org/sheepdog/reference/prior_predictive_calibration.md)
before fitting, and its influence on the posterior with
[`calibration_sensitivity()`](https://provetelab.org/sheepdog/reference/calibration_sensitivity.md).
On weakly informative priors and prior predictive checks see McElreath
(2020,
[doi:10.1201/9780429029608](https://doi.org/10.1201/9780429029608) ) and
Gelman et al. (2026, *Bayesian Workflow*, Chapman & Hall).

## Examples

``` r
if (requireNamespace("brms", quietly = TRUE)) {
  ex <- system.file("extdata", "example", package = "sheepdog")
  val <- read_validations(list.files(file.path(ex, "validation"),
                                     full.names = TRUE))
  f <- tp ~ logit_conf + (1 | species)
  prior <- calibration_prior(f, val)
  print(prior)
  # Any brmsprior can replace it, e.g. a narrower prior on the slope
  prior[prior$class == "b", "prior"] <- "normal(1, 0.5)"
  prior
}
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
#>               prior     class coef group resp dpar nlpar   lb   ub tag source
#>  normal(0.913, 1.5) Intercept                            <NA> <NA>       user
#>        normal(1, 1)         b                               0 <NA>       user
#>      exponential(1)        sd                            <NA> <NA>       user
#>               prior     class coef group resp dpar nlpar   lb   ub tag source
#>  normal(0.913, 1.5) Intercept                            <NA> <NA>       user
#>      normal(1, 0.5)         b                               0 <NA>       user
#>      exponential(1)        sd                            <NA> <NA>       user
```
