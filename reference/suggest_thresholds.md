# Suggest a confidence threshold per species

For each site and species (and each level of the `by` columns), the
lowest confidence `c` such that the precision among the reviewed clips
with confidence \>= `c` reaches `target_precision`, with at least
`min_n` clips. Candidate cuts are the observed confidences rounded to
two decimals.

## Usage

``` r
suggest_thresholds(validation, target_precision = 0.9, min_n = 15, by = NULL)
```

## Arguments

- validation:

  Table returned by
  [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md).

- target_precision:

  Target precision.

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

A tibble with `site`, `species_folder`, the `by` columns, `threshold`,
`n_support` and `precision_at_threshold` (`NA` when no cut reaches the
target). Without any reviewed clip with a confidence, the tibble has no
rows.
