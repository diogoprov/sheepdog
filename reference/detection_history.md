# Nightly detection history

Aggregates the scored detections by site x species x night. A night has
a detection when at least `min_detections_night` detections have a
calibrated probability \>= `p_min`; the columns `detection_k1` to
`detection_k3` give the same rule with k = 1, 2 and 3, as a sensitivity
analysis.

## Usage

``` r
detection_history(
  scored,
  p_min = 0.95,
  min_detections_night = 1,
  rule = c("mean", "probability"),
  prob_min = 0.9
)
```

## Arguments

- scored:

  A data frame (or tibble) returned by
  [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md),
  one row per detection.

- p_min:

  Numeric scalar in \[0, 1\], threshold on the calibrated probability
  (not on the confidence score).

- min_detections_night:

  Integer scalar \>= 1, repetition rule: minimum number of reliable
  detections for a night with detection.

- rule:

  Character scalar, one of `"mean"` (default) or `"probability"`: when a
  detection is reliable. `"mean"`, its calibrated probability (the
  posterior mean with `engine = "brms"`) is \>= `p_min`;
  `"probability"`, the posterior probability that P(TP) \>= `p_min` (the
  `pr_reliable` of a model fitted with `engine = "brms"`) is \>=
  `prob_min`. The second rule propagates the uncertainty of the
  calibration and is more conservative where few clips were reviewed.

- prob_min:

  Numeric scalar in \[0, 1\]. With `rule = "probability"`, threshold on
  `pr_reliable`. `pr_reliable` is computed in
  [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md)
  for its `p_min`; use the same `p_min` in both.

## Value

A tibble (class `tbl_df`) with `site`, `species`, `night`,
`n_detections`, `n_reliable`, `p_tp_max`, `detection_k1`,
`detection_k2`, `detection_k3` and `detection`.

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validations(list.files(file.path(ex, "validation"),
                                   full.names = TRUE))
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
fit <- fit_calibration(val, tp ~ logit_conf + species)
sites <- c("ARA", "BAI", "NHE", "XAR")
tables <- file.path(ex, "birdnet", sites, "BirdNET_SelectionTable.txt")
names(tables) <- sites
scored <- score_detections(tables, fit)
#> Scoring ARA (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/ARA/BirdNET_SelectionTable.txt)...
#>   1753 detections of calibrated species (0 of species NOT calibrated were dropped).
#> Scoring BAI (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/BAI/BirdNET_SelectionTable.txt)...
#>   1427 detections of calibrated species (0 of species NOT calibrated were dropped).
#> Scoring NHE (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/NHE/BirdNET_SelectionTable.txt)...
#>   2507 detections of calibrated species (0 of species NOT calibrated were dropped).
#> Scoring XAR (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/XAR/BirdNET_SelectionTable.txt)...
#>   1866 detections of calibrated species (0 of species NOT calibrated were dropped).
history <- detection_history(scored, p_min = 0.95,
                             min_detections_night = 2)
head(history)
#> # A tibble: 6 × 10
#>   site  species night n_detections n_reliable p_tp_max detection_k1 detection_k2
#>   <chr> <fct>   <chr>        <int>      <int>    <dbl>        <int>        <int>
#> 1 ARA   boa_ran 2021…           10          1    0.954            1            0
#> 2 ARA   boa_ran 2021…           13          5    0.985            1            1
#> 3 ARA   boa_ran 2021…           16          3    0.978            1            1
#> 4 ARA   boa_ran 2021…           11          3    0.993            1            1
#> 5 ARA   boa_ran 2021…            8          1    0.976            1            0
#> 6 ARA   boa_ran 2021…           13          2    0.986            1            1
#> # ℹ 2 more variables: detection_k3 <int>, detection <int>
```
