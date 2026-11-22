# Compare calibration models by cross-validation

Fits each candidate model with k-fold cross-validation and scores the
predicted probabilities on the held-out folds. Folds are stratified
within site x species by default. With `fold_group`, recordings or
nights are kept intact across species; see
[`calibration_folds()`](https://provetelab.org/sheepdog/reference/calibration_folds.md).
Models with random effects need the 'lme4' package.

## Usage

``` r
compare_calibration_models(
  validations,
  models = NULL,
  k_folds = 5,
  seed = 2026,
  fold_group = NULL
)
```

## Arguments

- validations:

  A data frame (or tibble) returned by
  [`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md),
  one row per reviewed clip.

- models:

  `NULL` or a named list of model formulas. `NULL` chooses the family
  from the observed species and sites: site-effect models for one
  species, the original family for multiple species, and no site random
  effects when only one site is observed. Supply an explicit list to
  reproduce a particular candidate set.

- k_folds:

  Integer scalar \>= 2, number of folds.

- seed:

  Integer scalar, seed of the fold assignment. The global random number
  generator is left as it was.

- fold_group:

  `NULL` or a character vector (one or more elements) of grouping
  columns, combined into one group ID. Do not include `species`,
  verdicts or confidence scores: these would split recordings or nights
  by species or by outcome. Group IDs must be nonmissing and nonempty.
  `NULL` keeps the original clip folds.

## Value

A tibble with `model`, `formula`, `auc_mean`, `auc_sd`, `n_failed`
(folds whose fit failed, left out of the means), `logloss_mean`,
`logloss_sd`, `brier_mean`, `brier_sd`, `cal_intercept` and `cal_slope`
(means over the folds), `prop_singular` (share of the fold fits that
were singular) and `complexity` (position of the model in `models`),
ordered from the highest mean AUC. Failed folds also raise a warning. A
test fold with only one verdict has missing AUC but contributes log-loss
and Brier; it is not a failed fit.

## Details

The AUC measures discrimination (whether true detections get higher
probabilities than false ones). The log-loss and the Brier score are
proper scoring rules: they reward probabilities close to the observed
outcomes, which is what matters when the probabilities are compared with
`p_min` (Gneiting & Raftery 2007,
[doi:10.1198/016214506000001437](https://doi.org/10.1198/016214506000001437)
). The calibration intercept and slope come from a logistic regression
of the verdicts on the logit of the predicted probabilities in each test
fold: a well calibrated model has intercept 0 and slope 1; a slope below
1 means probabilities too extreme (overfitting).

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validations(list.files(file.path(ex, "validation"),
                                   full.names = TRUE))
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
# Global model and species random intercept; the latter needs lme4
if (requireNamespace("lme4", quietly = TRUE)) {
  cv <- compare_calibration_models(val, calibration_models()[1:2],
                                   k_folds = 3)
  cv[c("model", "auc_mean", "logloss_mean", "cal_slope", "prop_singular")]
}
#> Cross-validation (3 folds) of 2 models...
#> # A tibble: 2 × 5
#>   model                auc_mean logloss_mean cal_slope prop_singular
#>   <chr>                   <dbl>        <dbl>     <dbl>         <dbl>
#> 1 m1_species_intercept    0.903        0.378      1.01             0
#> 2 m0_global               0.863        0.438      1.02             0
```
