# Precision by confidence bin

Precision (share of positive verdicts) of the reviewed clips, by site,
species and confidence bin. Clips without confidence (whole recordings
of `"random_recordings"`) are left out.

## Usage

``` r
precision_by_bin(
  validation,
  bins = seq(0.1, 1, by = 0.1),
  min_n = 15,
  by = NULL
)
```

## Arguments

- validation:

  Table returned by
  [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md).

- bins:

  Breaks of the confidence bins (left-closed).

- min_n:

  Minimum of reviewed clips for a bin to be taken seriously; bins with
  fewer are flagged in `low_support`.

- by:

  Optional columns of `validation` that split each site x species cell
  further, e.g. the bin of an environmental gradient or of an acoustic
  index joined from
  [`covariate_bins()`](https://provetelab.org/sheepdog/reference/covariate_bins.md).
  They show which parts of the gradient lack reviewed clips.

## Value

A tibble with `site`, `species_folder`, the `by` columns, `bin`,
`n_reviewed`, `n_positive`, `precision` and `low_support`.
