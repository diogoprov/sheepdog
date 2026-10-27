# Detections of each occasion over the draws of the calibration

Turns an export of
[`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
with calibration draws into one version of the detection data per
posterior draw: in each draw, an occasion is a detection when at least
one of its predictions is judged true. Any occupancy software can then
fit its model to each version and pool the posteriors, so that the
uncertainty of the calibration reaches the ecological estimates (Monte
Carlo propagation). This is the occasion-level counterpart of
[`history_draws()`](https://provetelab.org/sheepdog/reference/history_draws.md),
which works by night.

## Usage

``` r
occasion_draws(
  export_dir,
  species = NULL,
  rule = c("sample", "threshold"),
  p_min = 0.95,
  n_draws = NULL,
  seed = 2026,
  write = TRUE
)
```

## Arguments

- export_dir:

  Folder written by
  [`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
  with `fit`.

- species:

  Optional species to process, matched against `species` (the short
  code, e.g. `"phy_cuv"`) or `species_code` of `detections.csv`. All
  species with calibration draws by default.

- rule:

  `"sample"` or `"threshold"`; see Rules.

- p_min:

  Threshold of `rule = "threshold"`.

- n_draws:

  Optional number of calibration draws to use: the first ones, in
  increasing order of their identifiers. All by default.

- seed:

  Seed of `rule = "sample"`.

- write:

  Write `occasion_draws.parquet` in `export_dir` and record it in
  `schema.json` (schema version 1.2)? An existing table is replaced.

## Value

A tibble with `draw`, `site`, `occasion_id`, `species` and `y` (1
detection, 0 none, `NA` not scored), with one row per draw and occasion
with at least one exported prediction of the species. The other
occasions of `occasions.csv` are non-detections in every draw. Returned
invisibly when `write = TRUE`.

## Rules

With `rule = "sample"` (default), a prediction whose probability of
being true is `p` in a draw is judged true with probability `p`, so no
threshold is involved; this assumes that the predictions of an occasion
are true or false independently, given the calibration. With
`rule = "threshold"`, it is judged true when `p >= p_min`, as in
[`history_draws()`](https://provetelab.org/sheepdog/reference/history_draws.md);
this keeps only the predictions the calibration is nearly sure of and
gives fewer detections.

## Matching

A prediction takes the value of the grid point nearest its score and of
the calibration keys of its occasion (`schema.json$calibration$keys`,
e.g. the month). An occasion with a prediction that has no calibration
draws (a species, site or key level absent from
`calibration_draws.parquet`) cannot be scored: it is `NA` in every draw,
with a warning, not a non-detection.

## Reproducibility

The random numbers follow those of `crywolf::fp_draws_data()`, so that
both give the same detections for the same export, rule and seed: the
seed is set once per species with R's default generators
(Mersenne-Twister, Inversion, Rejection), and each draw, in increasing
order of its identifier, takes one uniform number per scored prediction,
in the order of `detections.csv`. The first `n` draws of a call are
therefore the same as those of a call with `n_draws = n`. Species are
processed one at a time, in alphabetical order, each from the seed. The
global random number generator is left as it was.

## See also

[`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md),
[`history_draws()`](https://provetelab.org/sheepdog/reference/history_draws.md),
[`vignette("crywolf-integration")`](https://provetelab.org/sheepdog/articles/crywolf-integration.md).
