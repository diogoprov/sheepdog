# Nightly detection history from empirical thresholds

The history of the empirical route: a detection is reliable when its
confidence reaches the threshold of its site x species cell, from
[`review_support()`](https://provetelab.org/sheepdog/reference/review_support.md)
or
[`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md),
with no calibration model. The result has the columns that
[`community_matrices()`](https://provetelab.org/sheepdog/reference/community_matrices.md)
and
[`summarise_history()`](https://provetelab.org/sheepdog/reference/summarise_history.md)
read, as the history of
[`detection_history()`](https://provetelab.org/sheepdog/reference/detection_history.md).

## Usage

``` r
threshold_history(
  detections,
  thresholds,
  min_confidence = 0.1,
  dawn_hour = 12,
  min_detections_night = 1
)
```

## Arguments

- detections:

  Predictions, from
  [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md),
  with `site`, `species_code`, `confidence` and `begin_path`. Use every
  prediction, not only those of the cells with a threshold.

- thresholds:

  Table with `site`, `species_folder` and `threshold`, one row per cell,
  such as the output of
  [`review_support()`](https://provetelab.org/sheepdog/reference/review_support.md).
  Cells with a missing threshold or without a row have no threshold.

- min_confidence:

  Predictions below this confidence are left out, as in
  [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md).
  This also sets which nights count as recorded.

- dawn_hour:

  Recordings that start before this hour belong to the night before.

- min_detections_night:

  Repetition rule: minimum number of reliable detections for a night
  with detection.

## Value

A tibble with `site`, `species` (the short code, as in
`species_folder`), `night`, `n_detections`, `n_reliable`,
`confidence_max`, `detection_k1`, `detection_k2`, `detection_k3` and
`detection`.

## Details

Every night with a detection stays in the history, also those of cells
without a threshold, because
[`community_matrices()`](https://provetelab.org/sheepdog/reference/community_matrices.md)
takes the effort from the distinct nights of the history. Leaving those
cells out would lower the nights recorded and raise the frequency of the
other species. In those cells `n_reliable` and the detection columns are
`NA`: nothing is known about them.
[`community_matrices()`](https://provetelab.org/sheepdog/reference/community_matrices.md)
does not count `NA` as a detection, so such a cell shows as 0 in the
matrices, which does not mean that the species is absent.

The threshold holds for the set of detections kept, not for each one;
see
[`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md).

## See also

[`review_support()`](https://provetelab.org/sheepdog/reference/review_support.md),
[`detection_history()`](https://provetelab.org/sheepdog/reference/detection_history.md),
[`community_matrices()`](https://provetelab.org/sheepdog/reference/community_matrices.md)

## Examples

``` r
detections <- data.frame(
  site = "A", species_code = "Boana raniceps_boa-ran",
  confidence = c(0.9, 0.8, 0.3),
  begin_path = c("A_20240110_200000.wav", "A_20240110_210000.wav",
                 "A_20240111_200000.wav"))
thresholds <- data.frame(site = "A", species_folder = "boa_ran",
                         threshold = 0.7)
threshold_history(detections, thresholds)
#> # A tibble: 2 × 10
#>   site  species night    n_detections n_reliable confidence_max detection_k1
#>   <chr> <chr>   <chr>           <int>      <int>          <dbl>        <int>
#> 1 A     boa_ran 20240110            2          2            0.9            1
#> 2 A     boa_ran 20240111            1          0            0.3            0
#> # ℹ 3 more variables: detection_k2 <int>, detection_k3 <int>, detection <int>
```
