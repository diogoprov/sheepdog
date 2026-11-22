# Compare the empirical and the model-based thresholds

Puts side by side, for each site x species, the threshold from the
reviewed clips
([`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md))
and the ones from the calibration model
([`calibrated_thresholds()`](https://provetelab.org/sheepdog/reference/calibrated_thresholds.md)).
The first needs no model but needs a random sample and many clips per
cell; the second reaches cells with few clips, through partial pooling,
but rests on the form of the model.

## Usage

``` r
compare_thresholds(
  validation,
  fit,
  scored = NULL,
  target_p = 0.95,
  target_precision = 0.9,
  min_n = 15,
  tolerance = 0.05,
  quality = NULL,
  weighted = NULL,
  sustained = FALSE,
  min_confidence = 0.1,
  grid_step = 0.01,
  lower_prob = 0.05
)
```

## Arguments

- validation:

  A data frame (or tibble) of reviewed clips, as for
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md).
  One row per clip. For `random_detections` clips, the empirical
  threshold uses the weighted precision.

- fit:

  A model returned by
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
  (`glm`, `glmerMod` or `brmsfit`).

- scored:

  `NULL` or a data frame (or tibble) returned by
  [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md).
  Needed for `thr_model_precision`, `model_precision_at_empirical` and
  `flag`.

- target_p:

  Numeric scalar in (0, 1). Target of the `"probability"` rule.

- target_precision:

  Numeric scalar in (0, 1). Target precision of the empirical threshold
  and of the `"precision"` rule.

- min_n:

  Integer scalar \>= 1. Passed to
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md).

- tolerance:

  Numeric scalar, in score units. Largest difference between
  `thr_empirical` and `thr_model_precision` for `"agree"`.

- quality:

  `NULL` or a data frame (or tibble) returned by
  [`calibration_quality()`](https://provetelab.org/sheepdog/reference/calibration_quality.md),
  joined by the columns `site` and `species` that it has.

- weighted, sustained:

  `NULL`, `TRUE` or `FALSE` (`weighted`) and logical scalar
  (`sustained`). Passed to
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md).

- min_confidence:

  Numeric scalar in \[0, 1\]. Detections below this confidence are not
  scored.

- grid_step:

  Numeric scalar in (0, 0.5). Models fitted with `engine = "brms"`: step
  of the grid of scores on which the posterior is computed.

- lower_prob:

  Numeric scalar in (0, 1). Models fitted with `engine = "brms"`: the
  probability of the lower quantile of the posterior of P(TP) used for
  `threshold_lower`.

## Value

A tibble with one row per site x species: `site`, `species`,
`thr_empirical`, `prec_empirical` (the precision that chose the cut),
`n_support`, `thr_model_precision`, `thr_p_tp`, `p_tp_at_threshold`,
`thr_p_tp_lower` (with a `brms` model), `model_precision_at_empirical`
(the expected precision of the model at `thr_empirical`),
`max_reviewed`, `above_reviewed`, `quality` (with `quality`) and `flag`:
`"agree"`, `"disagree"`, `"model_only"`, `"empirical_only"` or `"none"`;
`NA` without `scored`.

## Details

**What to compare.** The two rules of the model answer different
questions. `thr_empirical` and `thr_model_precision` both ask what share
of the detections kept are true, so their agreement is direct evidence
that the calibration fits the data, and `flag` compares these two. A
large difference points to the model (form, missing covariate) or to the
sample (few clips, missing weights); check it before using the
threshold. The model thresholds require the target at every higher
score, and the empirical one by default does not; `sustained = TRUE`
applies the same rule, at the cost described in
[`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md).
`thr_p_tp`, the score from which a detection is at least `target_p`
likely to be true, is higher for the same target, is the cut on P(TP) of
[`detection_history()`](https://provetelab.org/sheepdog/reference/detection_history.md),
and does not enter `flag`.

**Before using the model.** Use a calibration whose candidates were
compared by cross-validation and whose
[`calibration_quality()`](https://provetelab.org/sheepdog/reference/calibration_quality.md)
status is `"ok"` for the species; give that table in `quality` to carry
the status into the output. A model threshold above the highest reviewed
score of the cell (`above_reviewed`) is an extrapolation.

**Reuse.** Clips used here to set the threshold should not be reused as
confirmation data in the occupancy model without saying so.

## See also

[`post_validation()`](https://provetelab.org/sheepdog/reference/post_validation.md),
which writes this table with `fit`.

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
files <- list.files(file.path(ex, "validation"), full.names = TRUE)
sites <- c("ARA", "BAI", "NHE", "XAR")
tables <- setNames(file.path(ex, "birdnet", sites,
                             "BirdNET_SelectionTable.txt"), sites)
fit <- fit_calibration(read_validations(files),
                       calibration_models()$m2_species_slope)
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
scored <- score_detections(tables, fit)
#> Scoring ARA (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/ARA/BirdNET_SelectionTable.txt)...
#>   1753 detections of calibrated species (0 of species NOT calibrated were dropped).
#> Scoring BAI (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/BAI/BirdNET_SelectionTable.txt)...
#>   1427 detections of calibrated species (0 of species NOT calibrated were dropped).
#> Scoring NHE (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/NHE/BirdNET_SelectionTable.txt)...
#>   2507 detections of calibrated species (0 of species NOT calibrated were dropped).
#> Scoring XAR (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/XAR/BirdNET_SelectionTable.txt)...
#>   1866 detections of calibrated species (0 of species NOT calibrated were dropped).
compare_thresholds(read_validation_tables(files), fit, scored)
#> # A tibble: 32 × 12
#>    site  species thr_empirical prec_empirical n_support thr_model_precision
#>    <chr> <chr>           <dbl>          <dbl>     <int>               <dbl>
#>  1 ARA   boa_ran          0.36          0.975        80                0.49
#>  2 BAI   boa_ran          0.39          0.912        68                0.55
#>  3 NHE   boa_ran          0.55          0.917        36                0.54
#>  4 XAR   boa_ran          0.58          0.917        60                0.52
#>  5 ARA   den_nan          0.56          0.911        56                0.88
#>  6 BAI   den_nan         NA            NA            NA                0.84
#>  7 NHE   den_nan          0.77          0.941        17                0.86
#>  8 XAR   den_nan         NA            NA            NA                0.84
#>  9 ARA   ela_bic          0.13          0.924        79                0.19
#> 10 BAI   ela_bic          0.23          0.949        79                0.27
#> # ℹ 22 more rows
#> # ℹ 6 more variables: thr_p_tp <dbl>, p_tp_at_threshold <dbl>,
#> #   model_precision_at_empirical <dbl>, max_reviewed <dbl>,
#> #   above_reviewed <lgl>, flag <chr>
```
