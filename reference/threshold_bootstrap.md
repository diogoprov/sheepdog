# Uncertainty of the empirical threshold by bootstrap

Resamples whole recordings (or nights) of the reviewed clips of each
site x species cell, with replacement, and recomputes the threshold of
[`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)
in each replicate. Clips of the same recording are not independent, so
resampling clips one by one would make the interval too narrow.

## Usage

``` r
threshold_bootstrap(
  validation,
  target_precision = 0.9,
  min_n = 15,
  by = NULL,
  weighted = NULL,
  sustained = TRUE,
  n_boot = 1000,
  cluster = "source_audio",
  conf = 0.95,
  seed = 2026
)
```

## Arguments

- validation:

  Table returned by
  [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md).

- target_precision:

  Target precision.

- min_n:

  Minimum of reviewed clips for a bin to be taken seriously; bins with
  fewer are flagged in `low_support`.

- by:

  Optional columns of `validation` that split each site x species cell
  further, e.g. the bin of an environmental gradient or of an acoustic
  index joined from
  [`covariate_bins()`](https://provetelab.org/sheepdog/reference/covariate_bins.md).
  They show which parts of the gradient lack reviewed clips.

- weighted:

  Which precision chooses the cut. `NULL` (default): the weighted one in
  the cells whose clips all have `inclusion_prob`, the unweighted one
  elsewhere. `TRUE`: always the weighted one; cells with clips without
  `inclusion_prob` get no threshold, with a warning, and it is an error
  if no clip has it. `FALSE`: always the unweighted one, and `n_support`
  for `min_n`.

- sustained:

  Must the target also hold at every higher cut with at least `min_n`
  clips? See Sustained target.

- n_boot:

  Number of bootstrap replicates.

- cluster:

  Column of `validation` that defines the resampling unit:
  `"source_audio"` (the recording, the default) or `"night"`.

- conf:

  Probability of the conservative (upper) quantile.

- seed:

  Seed of the resampling. The global random number generator is left as
  it was.

## Value

A tibble with `site`, `species_folder`, the `by` columns, `threshold`
(from all the clips), `threshold_median`, `threshold_conservative`
(quantile `conf` of the replicates), `share_reached` (share of
replicates in which some score reaches the target) and `n_clusters`.

## Details

The threshold is the lowest score at which the precision of the reviewed
clips at or above it reaches `target_precision`, weighted by
`1 / inclusion_prob` when the clips have it (the weighted count of a
probability sample). The upper quantile of the replicates
(`threshold_conservative`) is the conservative threshold: with it, the
target is met in about `conf` of the replicates. A wide interval means
the precision curve is flat near the target, and a new round of review
near the threshold narrows it (a new round of
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
combined with the first by
[`combine_rounds()`](https://provetelab.org/sheepdog/reference/combine_rounds.md)).

## See also

[`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md),
[`threshold_by_group()`](https://provetelab.org/sheepdog/reference/threshold_by_group.md),
[`threshold_record()`](https://provetelab.org/sheepdog/reference/threshold_record.md).
