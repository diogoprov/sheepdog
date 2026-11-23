# Candidate calibration models

The family of logistic calibration models compared by
[`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md),
from a single logistic regression on the logit of the confidence score
to a binomial GLMM with random slopes by species and a site x species
intercept.

## Usage

``` r
calibration_models(uncorrelated = FALSE, single_species = FALSE)
```

## Arguments

- uncorrelated:

  Logical scalar. If `TRUE`, add `m5_species_x_site_uncorrelated`, the
  m4 structure without the correlation between the species intercepts
  and slopes. It avoids the singular fits of m4 when that correlation is
  estimated at +-1. `FALSE` keeps the candidates of 2.0.0.

- single_species:

  Logical scalar. If `TRUE`, use a family for one species: global
  logistic regression, a site intercept, and a site intercept and slope.
  With `uncorrelated = TRUE`, also include independent site intercepts
  and slopes. `FALSE` preserves the multispecies family.

## Value

A named list of formulas: `m0_global`, `m1_species_intercept`,
`m2_species_slope`, `m3_plus_site`, `m4_species_x_site` and, with
`uncorrelated = TRUE`, `m5_species_x_site_uncorrelated`. With
`single_species = TRUE`: `m0_global`, `m1_site_intercept`,
`m2_site_slope` and optionally `m3_site_slope_uncorrelated`.

## Details

The list goes from the simplest to the most complex model; that order is
the complexity used by
[`select_calibration_model()`](https://provetelab.org/sheepdog/reference/select_calibration_model.md).

## Examples

``` r
mods <- calibration_models()
names(mods)
#> [1] "m0_global"            "m1_species_intercept" "m2_species_slope"    
#> [4] "m3_plus_site"         "m4_species_x_site"   
mods$m2_species_slope
#> tp ~ logit_conf + (logit_conf | species)
#> <environment: 0x5cc374acc868>
# Family for a single species, with uncorrelated site effects
names(calibration_models(uncorrelated = TRUE, single_species = TRUE))
#> [1] "m0_global"                  "m1_site_intercept"         
#> [3] "m2_site_slope"              "m3_site_slope_uncorrelated"
```
