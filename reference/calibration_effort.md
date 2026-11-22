# Effort curve of the calibration

How many reviewed clips per site x species are needed to calibrate well?
For each training size, draws that many clips per cell (keeping at least
five for testing), fits the model and computes the AUC on the remaining
clips. Repetitions with fewer than 50 test clips, or whose fit fails,
are dropped.

## Usage

``` r
calibration_effort(
  validations,
  formula,
  n_train = c(5, 10, 15, 20, 25, 30),
  n_reps = 50,
  seed = 2026
)
```

## Arguments

- validations:

  A data frame (or tibble) returned by
  [`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md),
  one row per reviewed clip.

- formula:

  A model formula, usually the best one of
  [`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md).

- n_train:

  Numeric vector of whole numbers, training sizes (clips) per site x
  species.

- n_reps:

  Integer scalar \>= 1, repetitions per training size.

- seed:

  Integer scalar, seed of the draws. The global random number generator
  is left as it was.

## Value

A tibble with `n_per_cell` (the requested training size), `auc_mean`,
`auc_sd`, `n_train_mean` (mean clips per cell actually used for
training), `n_test_mean` (mean size of the test set) and `n_failed`
(repetitions dropped).

## Details

Cells with fewer than `n_train + 5` clips contribute all but five of
their clips, so the training size actually used can be below `n_train`;
it is reported in `n_train_mean`, with a warning. The test set shrinks
as `n_train` grows (`n_test_mean`), which widens `auc_sd`.

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validations(list.files(file.path(ex, "validation"),
                                   full.names = TRUE))
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
# A few repetitions of a model without random effects, to keep it fast
calibration_effort(val, tp ~ logit_conf, n_train = c(5, 10), n_reps = 5)
#> Effort curve (5 repetitions per n)...
#> # A tibble: 2 × 6
#>   n_per_cell auc_mean  auc_sd n_train_mean n_test_mean n_failed
#>        <dbl>    <dbl>   <dbl>        <dbl>       <dbl>    <int>
#> 1          5    0.862 0.00117            5        2307        0
#> 2         10    0.862 0.00301           10        2147        0
```
