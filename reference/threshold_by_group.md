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

  A data frame (or tibble) returned by
  [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md),
  with columns `site`, `species_folder`, `verdict` and `confidence`. One
  row per clip.

- thresholds:

  A data frame (or tibble) or a numeric scalar. The threshold of each
  cell: a table with `site`, `species_folder` and a `threshold` column
  (e.g. from
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md);
  `threshold_column` picks another column, such as
  `"threshold_conservative"` of
  [`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md)),
  or a single number for every cell.

- by:

  Character vector of one or more column names of `validation` that
  define the groups, e.g. `"recording_hour"`, a month column, or both.

- target_precision:

  Numeric scalar in (0, 1). Target precision.

- min_n:

  Integer scalar \>= 1. Minimum of reviewed clips for a bin to be taken
  seriously; bins with fewer are flagged in `low_support`.

- threshold_column:

  Character scalar, the column of `thresholds` with the threshold.

## Value

A tibble (class `tbl_df`) with `site`, `species_folder`, the `by`
columns, `threshold`, `n_above` (reviewed clips at or above it), `n_eff`
(effective sample size of Kish, with weights), `precision_above` and
`below_target`. A group with fewer than `min_n` clips above the
threshold gets `below_target = NA`.

## See also

[`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md),
[`threshold_record()`](https://provetelab.org/sheepdog/reference/threshold_record.md).

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validation_tables(file.path(ex, "validation",
                                        "validation_by_clip_ARA.csv"))
thr <- suggest_thresholds(val, target_precision = 0.90, min_n = 15)
# Does the threshold of each cell hold in every month?
val$month <- substr(val$recording_date, 1, 6)
threshold_by_group(val, thr, by = "month", target_precision = 0.90,
                   min_n = 5)
#> # A tibble: 34 × 8
#>    site  species_folder month  threshold n_above n_eff precision_above
#>    <chr> <chr>          <chr>      <dbl>   <int> <int>           <dbl>
#>  1 ARA   boa_ran        202110      0.36       6     6           0.667
#>  2 ARA   boa_ran        202111      0.36      16    16           1    
#>  3 ARA   boa_ran        202112      0.36      13    13           1    
#>  4 ARA   boa_ran        202201      0.36      15    15           1    
#>  5 ARA   boa_ran        202202      0.36      16    16           1    
#>  6 ARA   boa_ran        202203      0.36      14    14           1    
#>  7 ARA   den_nan        202110      0.56       7     7           0.714
#>  8 ARA   den_nan        202111      0.56      11    11           0.909
#>  9 ARA   den_nan        202112      0.56       9     9           1    
#> 10 ARA   den_nan        202201      0.56      11    11           1    
#> # ℹ 24 more rows
#> # ℹ 1 more variable: below_target <lgl>
# One threshold for every cell
threshold_by_group(val, 0.5, by = "month", min_n = 5)
#> # A tibble: 41 × 8
#>    site  species_folder month  threshold n_above n_eff precision_above
#>    <chr> <chr>          <chr>      <dbl>   <int> <int>           <dbl>
#>  1 ARA   boa_ran        202110       0.5       4     4           1    
#>  2 ARA   boa_ran        202111       0.5      16    16           1    
#>  3 ARA   boa_ran        202112       0.5      12    12           1    
#>  4 ARA   boa_ran        202201       0.5      15    15           1    
#>  5 ARA   boa_ran        202202       0.5      16    16           1    
#>  6 ARA   boa_ran        202203       0.5      14    14           1    
#>  7 ARA   den_nan        202110       0.5       9     9           0.667
#>  8 ARA   den_nan        202111       0.5      11    11           0.909
#>  9 ARA   den_nan        202112       0.5      10    10           1    
#> 10 ARA   den_nan        202201       0.5      14    14           1    
#> # ℹ 31 more rows
#> # ℹ 1 more variable: below_target <lgl>
```
