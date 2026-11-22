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

  A data frame (or tibble) of reviewed clips (e.g. from
  [`read_validation_tables()`](https://provetelab.org/sheepdog/reference/read_validation_tables.md)),
  one row per clip, with the occasions of `"random_recordings"`: `site`,
  `species_code`, `occasion_id`, `sampling_mode`, `verdict`
  (`"positive"` when the species was heard in the occasion, `"negative"`
  when not; other verdicts are left out), `inclusion_prob` and the
  `cluster` column. Clips of other designs are ignored.

- detections:

  A data frame (or tibble) of predictions, as returned by
  [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md),
  with columns `site`, `species_code`, `confidence`, `begin_path` and
  `file_offset`.

- thresholds:

  `NULL`, a numeric vector in \[0, 1\], or a data frame. Thresholds at
  which the recall is computed: a numeric vector (the same for every
  group), or a table with the `by` columns and a `threshold` column,
  such as the output of
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)
  (`threshold_column` picks another column, such as
  `"threshold_conservative"` of
  [`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md)).
  `NULL` gives the ceiling only.

- by:

  Character vector of one or more column names that define the groups:
  `"species_folder"` (the default, every site pooled) or
  `c("site", "species_folder")`.

- min_confidence:

  Numeric scalar, the lowest score kept in the selection tables (the
  minimum confidence BirdNET was run with). Predictions below it are not
  counted.

- occasion_unit:

  Character scalar, one of `"file"` or `"minute"`. The occasion of the
  draw.

- remap_from, remap_to:

  `NULL` or character scalars. Remapping of the audio paths of
  `detections`, as in
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md).

- threshold_column:

  Character scalar, the column of `thresholds` with the threshold.

- n_boot:

  Integer scalar \>= 0. Number of bootstrap replicates; 0 skips the
  intervals.

- cluster:

  Character scalar, the column of `validation` whose levels are
  resampled whole: `"source_audio"` (the recording, the default) or
  `"night"`. Used only when `n_boot > 0`.

- conf:

  Numeric scalar in (0, 1). Probability of the intervals.

- seed:

  Integer scalar, seed of the bootstrap. The global random number
  generator is left as it was.

## Value

A tibble (class `tbl_df`) with one row per group (and threshold): the
`by` columns, `n_occasions` (annotated occasions), `n_present`
(occasions with the species), `n_missed` (occasions with the species and
no prediction of it), `recall_ceiling` with `ceiling_lower` and
`ceiling_upper`; with `thresholds`, also `threshold`, `share_above`,
`recall` and `recall_lower`, `recall_upper`. Groups with no occasion
with the species get `NA`.

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
# six occasions annotated by ear at one site; the species is in four
sp <- "Boana raniceps_boa-ran"
val <- data.frame(
  site = "S1", species_code = sp,
  occasion_id = paste0("S1_2024010", 1:6, "_200000"),
  source_audio = paste0("/r/S1_2024010", 1:6, "_200000.wav"),
  sampling_mode = "random_recordings",
  verdict = rep(c("positive", "negative"), c(4, 2)),
  inclusion_prob = c(0.5, 0.5, 0.5, 0.25, 0.5, 0.5))
det <- data.frame(
  site = "S1", species_code = sp,
  begin_path = paste0("/r/S1_2024010", c(1, 1, 2, 4, 5), "_200000.wav"),
  file_offset = c(0, 3, 6, 0, 9),
  confidence = c(0.9, 0.3, 0.4, 0.6, 0.8))
recall_ceiling(val, det, thresholds = c(0.5, 0.7, 0.9), n_boot = 0)
#> # A tibble: 3 × 12
#>   species_folder n_occasions n_present n_missed recall_ceiling ceiling_lower
#>   <chr>                <int>     <int>    <int>          <dbl>         <dbl>
#> 1 boa_ran                  6         4        1            0.8            NA
#> 2 boa_ran                  6         4        1            0.8            NA
#> 3 boa_ran                  6         4        1            0.8            NA
#> # ℹ 6 more variables: ceiling_upper <dbl>, threshold <dbl>, share_above <dbl>,
#> #   recall <dbl>, recall_lower <dbl>, recall_upper <dbl>
```
