# Select the calibration model

Picks a model from the table of
[`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md).

## Usage

``` r
select_calibration_model(
  comparison,
  rule = c("one_se_logloss", "best_auc"),
  k_folds = 5
)
```

## Arguments

- comparison:

  A data frame (or tibble) returned by
  [`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md).

- rule:

  Character scalar, the selection rule: `"one_se_logloss"` (default) or
  `"best_auc"`.

- k_folds:

  Integer scalar \>= 2, number of folds of the comparison (for the
  standard error).

## Value

The name of the selected model.

## Details

- `"best_auc"`: the model with the highest mean AUC (the rule of
  [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md)
  in 2.x).

- `"one_se_logloss"`: among the models whose mean log-loss is within one
  standard error (`logloss_sd / sqrt(k_folds)`) of the lowest, the
  simplest (lowest `complexity`); models singular in most folds are left
  out, unless all are, which raises a warning. The log-loss rewards
  correct probabilities, not only their ranking, and the one-standard-
  error rule prefers the simpler model when the data cannot tell the
  candidates apart. This is the default of
  [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md)
  since 3.0.0.

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validations(list.files(file.path(ex, "validation"),
                                   full.names = TRUE))
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
if (requireNamespace("lme4", quietly = TRUE)) {
  cv <- compare_calibration_models(val, calibration_models()[1:2],
                                   k_folds = 3)
  select_calibration_model(cv, k_folds = 3)
  select_calibration_model(cv, rule = "best_auc")
}
#> Cross-validation (3 folds) of 2 models...
#> [1] "m1_species_intercept"
```
