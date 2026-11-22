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

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validations(list.files(file.path(ex, "validation"),
                                   full.names = TRUE),
                        keep = "source_audio")
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
# Clips assigned within site x species
folds <- calibration_folds(val, k_folds = 5)
table(folds)
#> folds
#>   1   2   3   4   5 
#> 495 494 494 492 492 
# Clips of the same recording kept in the same fold
folds_rec <- calibration_folds(val, k_folds = 5, fold_group = "source_audio")
table(val$site, folds_rec)
#>      folds_rec
#>         1   2   3   4   5
#>   ARA 123 118 117 116 119
#>   BAI 122 118 127 113 114
#>   NHE 132 117 130 128 133
#>   XAR 110 128 142 117 143
```
