# Recall ceiling and recall at the threshold

Estimates how much of the true activity of a species the classifier can
recover. The occasions drawn with `sampling_mode = "random_recordings"`
and annotated by ear say where the species called, whatever the
classifier said; matched with the highest score of the species in each
occasion (from the selection tables), they give:

## Usage

``` r
recall_ceiling(
  validation,
  detections,
  thresholds = NULL,
  by = "species_folder",
  min_confidence = 0.1,
  occasion_unit = c("file", "minute"),
  remap_from = NULL,
  remap_to = NULL,
  threshold_column = "threshold",
  n_boot = 1000,
  cluster = "source_audio",
  conf = 0.95,
  seed = 2026
)
```

## Arguments

- validation:

  Reviewed clips (e.g. from
  [`read_validation_tables()`](https://provetelab.org/sheepdog/reference/read_validation_tables.md)),
  with the occasions of `"random_recordings"`: `site`, `species_code`,
  `occasion_id`, `sampling_mode`, `verdict` (`"positive"` when the
  species was heard in the occasion, `"negative"` when not; other
  verdicts are left out), `inclusion_prob` and the `cluster` column.
  Clips of other designs are ignored.

- detections:

  Predictions, as returned by
  [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md).

- thresholds:

  Thresholds at which the recall is computed: a numeric vector (the same
  for every group), or a table with the `by` columns and a `threshold`
  column, such as the output of
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)
  (`threshold_column` picks another column, such as
  `"threshold_conservative"` of
  [`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md)).
  `NULL` gives the ceiling only.

- by:

  Columns that define the groups: `"species_folder"` (the default, every
  site pooled) or `c("site", "species_folder")`.

- min_confidence:

  The lowest score kept in the selection tables (the minimum confidence
  BirdNET was run with). Predictions below it are not counted.

- occasion_unit:

  The occasion of the draw: `"file"` or `"minute"`.

- remap_from, remap_to:

  Remapping of the audio paths of `detections`, as in
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md).

- threshold_column:

  Column of `thresholds` with the threshold.

- n_boot:

  Number of bootstrap replicates; 0 skips the intervals.

- cluster:

  Column of `validation` whose levels are resampled whole:
  `"source_audio"` (the recording, the default) or `"night"`.

- conf:

  Probability of the intervals.

- seed:

  Seed of the bootstrap. The global random number generator is left as
  it was.

## Value

A tibble with one row per group (and threshold): the `by` columns,
`n_occasions` (annotated occasions), `n_present` (occasions with the
species), `n_missed` (occasions with the species and no prediction of
it), `recall_ceiling` with `ceiling_lower` and `ceiling_upper`; with
`thresholds`, also `threshold`, `share_above`, `recall` and
`recall_lower`, `recall_upper`. Groups with no occasion with the species
get `NA`.

## Details

- the **recall ceiling**: the share of the occasions with the species
  that have at least one prediction of it with a score of at least
  `min_confidence`. The species called in the other occasions, but the
  classifier gave it no score worth keeping, so no threshold recovers
  them;

- the **recall at a threshold** `t`: the share of the occasions with the
  species whose highest score is at least `t`. It is the ceiling times
  the share of the detected occasions whose highest score reaches `t`
  (`share_above`).

Both are ratios weighted by `1 / inclusion_prob`, so occasions drawn
with different probabilities (a different fraction per site) count for
the occasions they stand for. The intervals come from a bootstrap of
whole recordings (`cluster`) within each group.

**Reading it.** A low ceiling means that the classifier misses the
species altogether in many occasions with it: check whether a lower
`min_confidence` recovers them without many false positives, and if not,
the problem is the classifier, not the threshold. A high ceiling with a
low recall at the threshold means that the threshold, not the
classifier, loses the occasions; weigh it against the precision the
threshold buys
([`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md),
[`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md)).

**What is needed.** The occasion of the annotation and of the
predictions must be the same: give the `occasion_unit` of the draw, and
the `remap_from` / `remap_to` of the draw when the recordings moved. Few
occasions with the species give wide intervals: the ceiling of a species
seldom present needs many annotated occasions.

## See also

[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
(`"random_recordings"`),
[`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md),
[`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md),
[`threshold_record()`](https://provetelab.org/sheepdog/reference/threshold_record.md).

## Examples

``` r
if (FALSE) { # \dontrun{
det <- read_selection_tables("birdnet")
val <- read_validation_tables(files)
recall_ceiling(val, det, thresholds = c(0.5, 0.7, 0.9))

# at the threshold of each cell
thr <- suggest_thresholds(val, target_precision = 0.95)
recall_ceiling(val, det, thresholds = thr,
               by = c("site", "species_folder"))
} # }
```
