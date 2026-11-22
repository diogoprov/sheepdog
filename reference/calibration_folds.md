# Assign cross-validation folds for calibration

With `fold_group = NULL`, assigns clips within each site x species,
reproducing the original fold assignment. For grouped folds, give one or
more column names, e.g. `"source_audio"` for recordings or `"night"` for
nights. Site is always part of the grouping key. All species and clips
sharing that key go into the same fold; groups are shuffled and
distributed among folds within site, balancing group counts rather than
clip counts. Each site must have at least `k_folds` groups.

## Usage

``` r
calibration_folds(validations, k_folds = 5, seed = 2026, fold_group = NULL)
```

## Arguments

- validations:

  A data frame (or tibble), the calibration data, one row per reviewed
  clip, with `site`, `species` and any columns named in `fold_group`.
  Use `read_validations(keep = )` to retain metadata from validation
  files.

- k_folds:

  Integer scalar \>= 2, number of folds.

- seed:

  Integer scalar, seed of the assignment; the caller's random state is
  restored.

- fold_group:

  `NULL` or a character vector of grouping columns. Do not include
  `species`, verdicts or confidence scores: these would split recordings
  or nights by species or by outcome. Group IDs must be nonmissing and
  nonempty. `NULL` keeps the original clip folds.

## Value

Integer vector of fold numbers, in the input row order.

## Details

Grouped folds evaluate new recordings or nights at known sites, not
transfer to new sites. Unlike clip folds, they cannot guarantee that
each species appears in each training and test set. A test fold with
only one verdict has no AUC but still contributes probability scores.
