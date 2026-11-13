# Does one threshold hold in every group?

A threshold set for a whole site x species cell can give the target
precision on average and miss it in some months, hours or chorus
conditions. For each cell and each level of the `by` columns, this
function computes the precision of the reviewed clips at or above the
threshold of the cell, weighted by `1 / inclusion_prob` when the clips
have it, and flags the groups below `target_precision`.

## Usage

``` r
threshold_by_group(
  validation,
  thresholds,
  by,
  target_precision = 0.9,
  min_n = 15,
  threshold_column = "threshold"
)
```

## Arguments

- validation:

  Table returned by
  [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md).

- thresholds:

  The threshold of each cell: a table with `site`, `species_folder` and
  a `threshold` column (e.g. from
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md);
  `threshold_column` picks another column, such as
  `"threshold_conservative"` of
  [`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md)),
  or a single number for every cell.

- by:

  Columns of `validation` that define the groups, e.g.
  `"recording_hour"` or a month column.

- target_precision:

  Target precision.

- min_n:

  Minimum of reviewed clips for a bin to be taken seriously; bins with
  fewer are flagged in `low_support`.

- threshold_column:

  Column of `thresholds` with the threshold.

## Value

A tibble with `site`, `species_folder`, the `by` columns, `threshold`,
`n_above` (reviewed clips at or above it), `n_eff` (effective sample
size of Kish, with weights), `precision_above` and `below_target`. A
group with fewer than `min_n` clips above the threshold gets
`below_target = NA`.

## See also

[`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md),
[`threshold_record()`](https://provetelab.org/sheepdog/reference/threshold_record.md).
