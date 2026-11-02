# Score every detection with the calibration model

Reads the complete BirdNET selection tables (not only the reviewed
clips) and predicts, for each detection, the probability that it is a
true positive. Only species present in the calibration are scored. The
night of each detection is its recording date, or the day before for
recordings that start before `dawn_hour`.

## Usage

``` r
score_detections(
  tables,
  fit,
  min_confidence = 0.1,
  dawn_hour = 12,
  p_min = 0.95,
  lower_prob = 0.05,
  grid_step = 0.01
)
```

## Arguments

- tables:

  Named character vector, named by site (the site names of the
  calibration): the path of the combined selection table of each site,
  or the folder of its per-audio tables (see
  [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md)).

- fit:

  Model returned by
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md).

- min_confidence:

  Detections below this confidence are not scored.

- dawn_hour:

  Recordings that start before this hour belong to the night before.

- p_min, lower_prob:

  Models fitted with `engine = "brms"`: the threshold of `pr_reliable`
  and the probability of the lower quantile `p_tp_lower`.

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

## Value

A tibble with `site`, `species`, `date`, `night`, `hour`, `confidence`,
`p_tp`, `begin_path` and `file_offset`; with a model fitted with
`engine = "brms"`, also `p_tp_lower` and `pr_reliable`.
