# Nightly detection histories over posterior draws

Propagates the uncertainty of a Bayesian calibration model to the
detection histories: for each of `n_draws` draws of the posterior, a
detection is reliable when its probability in that draw is \>= `p_min`,
and the nightly history is rebuilt. The histories can then be turned
into community matrices with uncertainty by
[`community_matrices_draws()`](https://provetelab.org/sheepdog/reference/community_matrices_draws.md).

## Usage

``` r
history_draws(
  fit,
  scored,
  p_min = 0.95,
  n_draws = 200,
  min_detections_night = 1,
  min_confidence = 0.1,
  grid_step = 0.01,
  seed = 2026
)
```

## Arguments

- fit:

  Model returned by
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
  with `engine = "brms"`.

- scored:

  Table returned by
  [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md).

- p_min:

  Threshold on the calibrated probability (not on the confidence score).

- n_draws:

  Number of posterior draws.

- min_detections_night:

  Repetition rule: minimum number of reliable detections for a night
  with detection.

- min_confidence:

  Detections below this confidence are not scored.

- grid_step:

  Models fitted with `engine = "brms"`: step of the grid of scores on
  which the posterior is computed.

- seed:

  Seed of the choice of draws. The global random number generator is
  left as it was.

## Value

A tibble with `draw`, `site`, `species`, `night`, `n_detections`,
`n_reliable`, `detection_k1` to `detection_k3` and `detection`.

## Details

As in
[`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md),
the probabilities are computed on a grid of scores (step `grid_step`)
for each site x species and assigned to the detections by their rounded
score, which keeps the cost independent of the number of detections.
