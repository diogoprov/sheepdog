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

A tibble with `site`, `species`, `night`, `n_detections`, `n_reliable`,
`p_tp_max`, `detection_k1`, `detection_k2`, `detection_k3` and
`detection`.
