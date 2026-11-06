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

  Reviewed clips, as for
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md).
  For `random_detections` clips, the empirical threshold uses the
  weighted precision.

- fit:

  Model returned by
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md).

- scored:

  Table returned by
  [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md).
  Needed for `thr_model_precision`, `model_precision_at_empirical` and
  `flag`.

- target_p:

  Target of the `"probability"` rule.

- target_precision:

  Target precision of the empirical threshold and of the `"precision"`
  rule.

- min_n:

  Passed to
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md).

- tolerance:

  Largest difference between `thr_empirical` and `thr_model_precision`,
  in score units, for `"agree"`.

- quality:

  Optional table of
  [`calibration_quality()`](https://provetelab.org/sheepdog/reference/calibration_quality.md),
  joined by the columns `site` and `species` that it has.

- weighted, sustained:

  Passed to
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md).

- min_confidence:

  Detections below this confidence are not scored.

- grid_step:

  Models fitted with `engine = "brms"`: step of the grid of scores on
  which the posterior is computed.

  With a model fitted with `engine = "brms"`, the posterior of P(TP) is
  computed once on a grid of scores (step `grid_step`) for each site x
  species and assigned to the detections by their score rounded to the
  grid, so that the cost does not depend on the number of detections;
  the rounding error is small next to the uncertainty of the
  calibration. Each detection then gets the posterior mean (`p_tp`), a
  lower quantile (`p_tp_lower`) and the posterior probability that P(TP)
  \>= `p_min` (`pr_reliable`).
  [`detection_history()`](https://provetelab.org/sheepdog/reference/detection_history.md)
  can use either rule.

- lower_prob:

  Models fitted with `engine = "brms"`: the probability of the lower
  quantile of the posterior of P(TP) used for `threshold_lower`.

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
if (FALSE) { # \dontrun{
fit <- fit_calibration(read_validations(files),
                       calibration_models()$m4_species_x_site)
scored <- score_detections(tables, fit)
compare_thresholds(read_validation_tables(files), fit, scored)
} # }
```
