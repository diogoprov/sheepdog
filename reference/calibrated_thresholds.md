# Confidence thresholds from the calibration model

Derives a confidence threshold for each site x species from the
calibration model of stage 2
([`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)),
instead of from the reviewed clips of each cell alone, as
[`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)
does. The calibration model is the logistic regression of the verdict on
the logit of the score proposed by the BirdNET authors (Wood & Kahl
2024,
[doi:10.1007/s10336-024-02144-5](https://doi.org/10.1007/s10336-024-02144-5)
), with species and site effects, so a cell with few reviewed clips
borrows strength from the others.

## Usage

``` r
calibrated_thresholds(
  fit,
  target = 0.95,
  rule = c("probability", "precision"),
  scored = NULL,
  cells = NULL,
  min_confidence = 0.1,
  grid_step = 0.01,
  lower_prob = 0.05
)
```

## Arguments

- fit:

  Model returned by
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md).

- target:

  Target probability (`"probability"`) or precision (`"precision"`). The
  default, 0.95, is the `p_min` of
  [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md)
  and
  [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md),
  so that the probability threshold is the score equivalent of the cut
  on P(TP) used for the detection histories. It is the same for both
  rules; the `"precision"` threshold is lower for the same target (see
  Details).
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)
  uses 0.90 by default.

- rule:

  `"probability"` or `"precision"`; see Details.

- scored:

  Table returned by
  [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md),
  with `site`, `species`, `confidence` and `p_tp`. Required for
  `rule = "precision"`; with `rule = "probability"`, its site x species
  cells are used when `cells` is `NULL`.

- cells:

  Data frame of the cells to threshold, with `site` and `species` and
  any other variable of the calibration formula. By default, the cells
  of `scored` or, without it, every site x species of the calibration.

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

A tibble with the cell columns, `threshold` and, for
`rule = "probability"`, `p_tp_at_threshold` (and `threshold_lower` with
a `brms` model); for `rule = "precision"`, `precision_at_threshold`,
`n_above` (detections kept) and `n_detections`. `threshold` is `NA` when
no score of the grid reaches the target. With `"precision"`, a cell can
be `NA` while `"probability"` gives a threshold: the probability
threshold may lie above every detection of the cell, and then no set of
detections reaches the target.

## Details

Two rules are available:

- `rule = "probability"` (the rule of Wood & Kahl 2024): the lowest
  score `c` at which the calibrated probability that a detection is a
  true positive, P(TP \| score = c, site, species), reaches `target` and
  stays at or above it for every higher score. Only the model is needed.

- `rule = "precision"`: the lowest score `c` at which the expected
  precision of the detections kept, the mean of P(TP) over every
  detection of the cell with a score \>= `c`, reaches `target` and stays
  at or above it. It needs the scored detections of the selection tables
  ([`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md)),
  and answers the question that
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)
  answers with the reviewed clips: what share of the detections above
  the threshold are true? The threshold is lower than with
  `"probability"`, because the detections above `c` have higher
  probabilities than a detection at `c`.

The candidate thresholds are the points of a grid of scores (step
`grid_step`, from `min_confidence`), as in
[`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md).

With a model fitted with `engine = "brms"`, `rule = "probability"` also
returns `threshold_lower`: the lowest score at which the lower quantile
(`lower_prob`) of the posterior of P(TP) reaches `target`, a
conservative threshold that accounts for the uncertainty of the
calibration.

**Which clips to review.** The calibration models the verdict given the
score. Choosing the clips to review by their score only (for instance, a
sample stratified by score bins, as Wood & Kahl 2024 suggest) does not
bias P(TP \| score), as long as the model form is right; it does bias
the precision computed directly from the reviewed clips, which
[`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)
uses. The site-confirmation design of false-positive occupancy models
needs instead clips drawn at random
(`sampling_mode = "random_detections"` or `"random_recordings"` in
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)).

**Site effects.** With a site effect, P(TP \| score, site) mixes the
error of the classifier with how often the species calls at the site.
For a threshold this is what is wanted: the precision at a site depends
on both. It is not a measure of the classifier alone.

## See also

[`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)
for thresholds from the reviewed clips of each cell;
[`compare_thresholds()`](https://provetelab.org/sheepdog/reference/compare_thresholds.md)
to put both side by side;
[`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md),
which writes these thresholds to `thresholds.csv`.

## Examples

``` r
if (FALSE) { # \dontrun{
val <- read_validations(validation_files)
fit <- fit_calibration(val, calibration_models()$m4_species_x_site)
calibrated_thresholds(fit, target = 0.95)

# expected precision of the detections kept, from the selection tables
scored <- score_detections(tables, fit)
calibrated_thresholds(fit, target = 0.90, rule = "precision",
                      scored = scored)
} # }
```
