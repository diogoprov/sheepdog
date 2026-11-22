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
  remap_to = NULL,
  weighted = NULL
)
```

## Arguments

- validation:

  A data frame (or tibble) of reviewed clips, as for
  [`precision_by_bin()`](https://provetelab.org/sheepdog/reference/precision_by_bin.md)
  (the `validation_by_clip.csv` tables). One row per clip.

- detections:

  A data frame (or tibble) of predictions, as returned by
  [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md),
  with columns `site`, `species_code`, `confidence`, `begin_path` and
  `file_offset`. One row per prediction.

- conf_high:

  Numeric scalar, score from which a prediction counts as high.

- min_n:

  Integer scalar \>= 1. Minimum number of clips, as in
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md),
  and of unreviewed high-score detections for `"review more"`.

- min_precision:

  Numeric scalar in \[0, 1\]. Precision at high scores below which a
  cell is `"unreliable"`.

- target_precision:

  Numeric scalar in (0, 1). Target precision of
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md).

- by:

  `NULL` or a character vector of column names that split each cell,
  e.g. `"temp_bin"`. They must be columns of `covariates` (joined to
  both tables) or of both tables.

- covariates:

  `NULL` or a data frame (or tibble) of occasion covariates, such as the
  output of
  [`covariate_bins()`](https://provetelab.org/sheepdog/reference/covariate_bins.md),
  joined to the clips and to the predictions by the columns it shares
  with them among `site`, `night`, `recording_date`, `recording_hour`,
  `source_audio` and `occasion_id`, as in
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md).

- occasion_unit:

  Character scalar, the occasion of the occupancy model: `"file"` (the
  whole recording) or `"minute"` (minute of the file, from
  `file_offset`).

- remap_from, remap_to:

  `NULL` or character scalars. Replace the prefix `remap_from` of the
  `begin_path` paths by `remap_to`, e.g. `"N:/"` and
  `"/Volumes/Arara/"`. Backslashes are turned into forward slashes
  first.

- weighted:

  `NULL`, `TRUE` or `FALSE`. Passed to
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md),
  so that `"reached"` follows the same rule. `prec_high` stays
  unweighted.

## Value

A tibble with `site`, `species_folder`, the `by` columns, `n_reviewed`,
`n_fp` (false positives among them), `n_high` (reviewed clips with score
\>= `conf_high`), `prec_high` (their precision), `n_high_all`
(predictions with score \>= `conf_high`), `unreviewed_high`, `threshold`
and `diagnosis`, ordered by diagnosis. With a table of
[`combine_rounds()`](https://provetelab.org/sheepdog/reference/combine_rounds.md),
also `n_rounds` and `reached_last_round`: the cell has a threshold now
but had none before its last round.

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

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validation_tables(list.files(file.path(ex, "validation"),
                                         full.names = TRUE))
det <- read_selection_tables(file.path(ex, "birdnet"))
#> 4 combined table(s) and 0 per-audio table(s) found in 4 folder(s):
#>   - /home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/ARA: BirdNET_SelectionTable.txt
#>   - /home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/BAI: BirdNET_SelectionTable.txt
#>   - /home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/NHE: BirdNET_SelectionTable.txt
#>   - /home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/XAR: BirdNET_SelectionTable.txt
#> 7553 predictions read from 4 site(s).
sup <- review_support(val, det, conf_high = 0.7, min_n = 10)
sup[, c("site", "species_folder", "n_reviewed", "prec_high",
        "unreviewed_high", "threshold", "diagnosis")]
#> # A tibble: 32 × 7
#>    site  species_folder n_reviewed prec_high unreviewed_high threshold diagnosis
#>    <chr> <chr>               <int>     <dbl>           <int>     <dbl> <chr>    
#>  1 ARA   lep_fus                33     0                   0     NA    exhausted
#>  2 BAI   lep_fus                56     0                   0     NA    exhausted
#>  3 ARA   boa_ran                80     1                 122      0.36 reached  
#>  4 BAI   boa_ran                80     1                  25      0.39 reached  
#>  5 NHE   boa_ran                80     0.962              18      0.55 reached  
#>  6 XAR   boa_ran                80     0.980              29      0.58 reached  
#>  7 ARA   den_nan                80     0.943              57      0.56 reached  
#>  8 NHE   den_nan                80     0.818              47      0.77 reached  
#>  9 ARA   ela_bic                80     1                  42      0.13 reached  
#> 10 BAI   ela_bic                80     1                  51      0.23 reached  
#> # ℹ 22 more rows
```
