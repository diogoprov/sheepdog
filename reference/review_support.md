# Review support of each cell: is more validation worth it?

For each site x species cell (and each level of the `by` columns, such
as the bin of an environmental gradient or of an acoustic index), counts
the reviewed clips at high scores, their precision, and the high-score
detections of the selection tables that were not reviewed, and labels
the cell:

## Usage

``` r
review_support(
  validation,
  detections,
  conf_high = 0.7,
  min_n = 15,
  min_precision = 0.5,
  target_precision = 0.9,
  by = NULL,
  covariates = NULL,
  occasion_unit = c("file", "minute"),
  remap_from = NULL,
  remap_to = NULL
)
```

## Arguments

- validation:

  Reviewed clips, as for
  [`precision_by_bin()`](https://provetelab.org/sheepdog/reference/precision_by_bin.md)
  (the `validation_by_clip.csv` tables).

- detections:

  Predictions, as returned by
  [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md).

- conf_high:

  Score from which a prediction counts as high.

- min_n:

  Minimum number of clips, as in
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md),
  and of unreviewed high-score detections for `"review more"`.

- min_precision:

  Precision at high scores below which a cell is `"unreliable"`.

- target_precision:

  Target precision of
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md).

- by:

  Optional columns that split each cell, e.g. `"temp_bin"`. They must be
  columns of `covariates` (joined to both tables) or of both tables.

- covariates:

  Optional table of occasion covariates, such as the output of
  [`covariate_bins()`](https://provetelab.org/sheepdog/reference/covariate_bins.md),
  joined to the clips and to the predictions by the columns it shares
  with them among `site`, `night`, `recording_date`, `recording_hour`,
  `source_audio` and `occasion_id`, as in
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md).

- occasion_unit:

  The occasion of the occupancy model: `"file"` (the whole recording) or
  `"minute"` (minute of the file, from `file_offset`).

- remap_from, remap_to:

  Replace the prefix `remap_from` of the `begin_path` paths by
  `remap_to`, e.g. `"N:/"` and `"/Volumes/Arara/"`. Backslashes are
  turned into forward slashes first.

## Value

A tibble with `site`, `species_folder`, the `by` columns, `n_reviewed`,
`n_fp` (false positives among them), `n_high` (reviewed clips with score
\>= `conf_high`), `prec_high` (their precision), `n_high_all`
(predictions with score \>= `conf_high`), `unreviewed_high`, `threshold`
and `diagnosis`, ordered by diagnosis.

## Details

- `"reached"`:
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)
  found a threshold that reaches `target_precision` with at least
  `min_n` clips;

- `"exhausted"`: fewer than `min_n` high-score detections are left to
  review, so more effort cannot add support;

- `"unreliable"`: precision at high scores is below `min_precision`, so
  more review would only confirm it (retrain the classifier instead);

- `"review more"`: high-score detections remain and precision there is
  intermediate, so a further round of review may reach a threshold;

- `"not reviewed"`: the cell has detections but no reviewed clip.

The cut-offs (`conf_high`, `min_n`, `min_precision`) are illustrative
defaults: set them from the precision the study needs. Splitting cells
by `by` lowers the number of clips per cell, so more cells fall short of
`min_n`; compare with the reading without `by`. These labels interpret
counts; they are not a statistical test.

## See also

[`vignette("validation-effort")`](https://provetelab.org/sheepdog/articles/validation-effort.md).
