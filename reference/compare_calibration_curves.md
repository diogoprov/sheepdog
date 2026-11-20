# Compare the logistic calibration with flexible curves

Checks the shape of the calibration curve before a threshold is taken
from it. For each group (by default, each species), fits the probability
that a reviewed clip is a true positive as a function of the logit of
its score with four curves: the logistic of
[`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
(linear in the logit), a quadratic, a GAM (`mgcv`) and a monotone
increasing GAM (`scam`). Each curve is judged where the threshold lies,
not on average, and its thresholds are compared with the model-free
threshold of the weighted precision
([`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)).

## Usage

``` r
compare_calibration_curves(
  validation,
  target = 0.95,
  by = "species_folder",
  curves = c("logistic", "quadratic", "gam", "monotone_gam"),
  weighted = NULL,
  k = 5,
  k_folds = 5,
  cv = TRUE,
  cluster = "source_audio",
  top_from = 0.7,
  bin_width = 0.05,
  min_n = 15,
  min_bin = 5,
  max_error = 0.03,
  tolerance = 0.03,
  n_boot = 0,
  conf = 0.95,
  grid_step = 0.01,
  seed = 2026
)
```

## Arguments

- validation:

  Reviewed clips, as for
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md):
  with `verdict` (`"positive"` or `"negative"`; others are left out),
  `confidence` and, for weights, `inclusion_prob`.

- target:

  Target probability (`threshold_p_tp`) and precision
  (`threshold_precision`, `threshold_weighted`). Several targets can be
  given: the curves and the cross-validation are fitted once per group,
  and the result has one row per group x target x curve.

- by:

  Columns of `validation` that define the groups fitted separately.
  `"species_folder"` by default; `c("site", "species_folder")` fits each
  cell.

- curves:

  Curves to fit, among `"logistic"`, `"quadratic"`, `"gam"` and
  `"monotone_gam"`. `"gam"` needs the package `mgcv` and
  `"monotone_gam"` the package `scam`; a curve whose package is missing
  is left out with a message.

- weighted:

  `NULL` (weight by `1 / inclusion_prob` the groups whose clips all have
  it), `TRUE` or `FALSE`.

- k:

  Basis dimension of the GAMs (reduced when the group has fewer distinct
  scores).

- k_folds:

  Number of folds of the cross-validation.

- cv:

  `FALSE` skips the cross-validation (`cv_logloss`, `cv_logloss_se` and
  `within_1se` are `NA`), when only the thresholds and the verdict,
  which does not use it, are needed.

- cluster:

  Column of `validation` whose levels are kept together in the folds
  (`"source_audio"`, the recording, by default). Without it, clips are
  split one by one.

- top_from, bin_width:

  Lower limit and width of the high score bins of `top_error`.

- min_n:

  Minimum number of clips of a group, of (effective) clips at or above a
  cut for it to count, and of effective clips in the high bins.

- min_bin:

  Minimum number of clips of a bin for it to enter `top_error`.

- max_error, tolerance:

  Largest `top_error_excess` and largest difference between the logistic
  and the weighted thresholds, in score units, for `"keep_logistic"`.

- n_boot:

  Number of bootstrap replicates of the difference between the logistic
  and the weighted thresholds (`0`, the default, skips it).

- conf:

  Probability of the bootstrap interval of the difference.

- grid_step:

  Step of the grid of scores of `threshold_p_tp` and of the curves
  returned.

- seed:

  Seed of the folds. The global random number generator is left as it
  was.

## Value

A tibble with one row per group x target x curve: the `by` columns,
`curve`, `target`, `n`, `n_positive`, `cv_logloss`, `cv_logloss_se`,
`within_1se` (log-loss within one standard error of the best curve of
the group), `top_error`, `top_error_excess`, `n_eff_top`, `max_p`,
`reaches_target`, `threshold_p_tp`, `threshold_precision`,
`threshold_weighted`, `diff_weighted`, `diff_weighted_lower`,
`diff_weighted_upper` (bootstrap interval of `diff_weighted`, logistic
only, with `n_boot > 0`), `above_reviewed` (a threshold above the
highest reviewed score is an extrapolation), `weighted` and `verdict`.
The attribute `"curves"` holds the fitted curves on the grid (`score`,
`p_tp`) and `"bins"` the observed precision by bin, for
[`plot_calibration_curves()`](https://provetelab.org/sheepdog/reference/plot_calibration_curves.md).

## Details

**What is compared.** For each curve:

- `cv_logloss`: log-loss of held-out clips in `k_folds`-fold
  cross-validation, with folds made of whole recordings (`cluster`), so
  that clips of the same recording are not split between fitting and
  testing. It is dominated by the bulk of the clips, mostly at low
  scores, and may tie across curves even when one is wrong near the
  threshold; use it together with `top_error`.

- `top_error`: calibration error in the high score bins (width
  `bin_width`, from `top_from` to 1): the mean, weighted by the
  effective number of clips of each bin, of the absolute difference
  between the observed precision of the bin and the mean probability
  predicted by the curve for its clips. Part of it is the sampling noise
  of the bins, shared by every curve, so `top_error_excess` (the error
  of the curve minus the smallest error of the flexible curves) is what
  the verdict uses.

- `threshold_p_tp`: the lowest score from which the curve stays at or
  above `target` (the rule `"probability"` of
  [`calibrated_thresholds()`](https://provetelab.org/sheepdog/reference/calibrated_thresholds.md)),
  on a grid of step `grid_step`. `max_p` is the highest value of the
  curve within the reviewed scores; when it stays below `target`, no
  score guarantees the target (`reaches_target = FALSE`).

- `threshold_precision`: the lowest score from which the precision of
  the clips kept, as predicted by the curve (the mean of the predicted
  probabilities of the reviewed clips at or above the cut, weighted by
  `1 / inclusion_prob`), stays at or above `target`. It answers the same
  question as the weighted count, `threshold_weighted`, so
  `diff_weighted` (their difference) is direct evidence on the shape of
  the curve.

**Verdict.** One per group, following the decision table of the
threshold workflow:

- `"too_few_clips"`: fewer than `min_n` clips, or fewer than two of
  either verdict; no curve is fitted.

- `"sample_more_near_threshold"`: fewer than `min_n` effective clips in
  the high score bins; a new round there
  (`sampling_mode = "score_bands"` in
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
  joined by
  [`combine_rounds()`](https://provetelab.org/sheepdog/reference/combine_rounds.md))
  is needed before deciding.

- `"no_curve_reaches_target"`: neither the flexible curves nor the
  weighted count give a threshold with precision `target` (with at least
  `min_n` effective clips above it). The curve levels off before the
  target, or reaches it only at the very top, and no usable score
  guarantees it: improve the classifier before setting a threshold.

- `"keep_logistic"`: the logistic has `top_error_excess <= max_error`
  and its `threshold_precision` agrees with the weighted count: within
  `tolerance` of it or, with `n_boot > 0`, either within `tolerance` or
  with a bootstrap interval of the difference that includes 0 (the two
  thresholds do not disagree more than the sample allows). A flexible
  curve may still fit better in log-loss, but away from the threshold.

- `"use_monotone_or_weighted"`: larger error in the high bins, or
  thresholds that disagree; take the threshold from the monotone GAM or
  from the weighted precision
  ([`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md),
  [`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md)).

**Bootstrap of the disagreement.** With `n_boot > 0`, the clips are
resampled by whole recordings (`cluster`) and, in each replicate, the
logistic is refitted and its `threshold_precision` and the weighted
count are recomputed. The quantiles of their difference give
`diff_weighted_lower` and `diff_weighted_upper` (row of the logistic),
so that a difference larger than `tolerance` counts against the logistic
only when it is larger than the sampling noise. Only the logistic and
the weighted count are resampled, since refitting the GAMs in each
replicate would be slow. When fewer than half of the replicates give
both thresholds, the interval is `NA` and the fixed `tolerance` is used.

**What the verdict detects.** The verdict is built to detect a drop of
the precision at the top of the scores, that is false positives with
high scores (for instance, a sound similar to the species), where the
logistic overestimates the precision near the threshold. It is not a
general choice of the best curve: when the shape departs from the
logistic in other ways, neither `"keep_logistic"` nor
`"use_monotone_or_weighted"` says which threshold has the smaller error,
and `cv_logloss` is a weak guide to that choice (see above). In
particular, `"keep_logistic"` does not guarantee the target when the
precision levels off just above it: the logistic then crosses the target
too early, and its threshold can miss it in most samples, while the
verdict, above all with the bootstrap interval of `n_boot`, often keeps
it. Read the verdict as a check of the shape of the curve, not as the
choice of the threshold to apply; for that, use the conservative
threshold of
[`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md)
(`threshold_conservative`), which also gives the uncertainty of the
threshold.

**Which clips.** Clips of any probability design can be used:
`"random_detections"` and `"score_bands"` clips carry `inclusion_prob`,
and are weighted by `1 / inclusion_prob` in the fits and in the
precision (`weighted = NULL` does so when every clip of the group has
it). Clips of `"top"` have no inclusion probability; with them, the
weighted count is not an estimate of the precision of the predictions.
Fitting with and without weights (`weighted = TRUE` and `FALSE`) is also
a check of the shape: similar thresholds mean the shape is right.

## References

Wood, C. M. & Kahl, S. (2024). Guidelines for appropriate use of BirdNET
scores and other detector outputs. *Journal of Ornithology*, 165,
777-782.
[doi:10.1007/s10336-024-02144-5](https://doi.org/10.1007/s10336-024-02144-5)

## See also

[`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md),
[`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md),
[`calibrated_thresholds()`](https://provetelab.org/sheepdog/reference/calibrated_thresholds.md),
[`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md),
[`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md).

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
validation <- read_validation_tables(list.files(file.path(ex, "validation"),
                                                full.names = TRUE))
# Two fast curves; "gam" and "monotone_gam" can be added but are slower
cmp <- compare_calibration_curves(validation, target = 0.95,
                                  curves = c("logistic", "quadratic"),
                                  k_folds = 3)
cmp[c("species_folder", "curve", "top_error", "threshold_precision",
      "threshold_weighted", "verdict")]
#> # A tibble: 16 × 6
#>    species_folder curve top_error threshold_precision threshold_weighted verdict
#>    <chr>          <chr>     <dbl>               <dbl>              <dbl> <chr>  
#>  1 boa_ran        logi…   4.36e-3                0.58               0.58 keep_l…
#>  2 boa_ran        quad…   4.65e-3                0.58               0.58 keep_l…
#>  3 den_nan        logi…   4.32e-2               NA                  0.91 use_mo…
#>  4 den_nan        quad…   4.33e-2               NA                  0.91 use_mo…
#>  5 ela_bic        logi…   1.69e-4                0.28               0.28 keep_l…
#>  6 ela_bic        quad…   3.74e-6                0.28               0.28 keep_l…
#>  7 lep_fus        logi…   5.94e-2               NA                 NA    no_cur…
#>  8 lep_fus        quad…   6.27e-2               NA                 NA    no_cur…
#>  9 lep_pod        logi…   9.19e-4                0.34               0.34 keep_l…
#> 10 lep_pod        quad…   1.34e-3                0.34               0.34 keep_l…
#> 11 phy_cuv        logi…   5.71e-3                0.24               0.24 keep_l…
#> 12 phy_cuv        quad…   6.04e-3                0.24               0.24 keep_l…
#> 13 pse_pla        logi…   1.33e-1               NA                 NA    no_cur…
#> 14 pse_pla        quad…   1.26e-1               NA                 NA    no_cur…
#> 15 sci_nas        logi…   7.99e-2               NA                  0.89 use_mo…
#> 16 sci_nas        quad…   9.64e-2                0.9                0.89 use_mo…
if (requireNamespace("ggplot2", quietly = TRUE)) plot_calibration_curves(cmp)
```
