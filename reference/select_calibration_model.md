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

  Numeric scalar, number of folds of the comparison (for the standard
  error).

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
