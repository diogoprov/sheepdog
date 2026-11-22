# Combine the review rounds of a design

Stacks the tables of the rounds of a `"random_detections"` design and
gives every clip the inclusion probability of the combined sample. Each
round of
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
draws among the occasions not drawn yet, so the occasions drawn in all
rounds are a simple random sample of each stratum, and every clip has
the probability `n_drawn / n_candidates`, whatever its round. The value
stored in the table of an earlier round is out of date as soon as
another round is drawn; this function recomputes it from the candidates
and the clips, so no earlier file is edited.

## Usage

``` r
combine_rounds(validation, candidates = NULL)
```

## Arguments

- validation:

  A character vector of paths, a data frame, or a list of these: the
  tables of all rounds (paths to the `validation_by_clip.csv` files or
  manifests), one row per clip, with the columns `site`, `species_code`,
  `occasion_id` and `sampling_mode`. Tables without `round` count as one
  round each, in the order given.

- candidates:

  `NULL`, a character scalar (path) or a data frame: the
  `candidates.csv` of the first round. `NULL` looks for it in the
  folders of `validation`.

## Value

The stacked table, in the order of the input, with `stratum`,
`n_candidates`, `n_drawn`, the cumulative `inclusion_prob` and
`n_rounds`, the number of rounds with clips of the site x species. Clips
of other sampling modes keep their `inclusion_prob`, `n_candidates` and
`n_drawn`, with `stratum` and `n_rounds` `NA`.

## Details

The probability is exact for a number of rounds fixed in advance. When
the rounds of a cell go on until it reaches a target, the decision to
stop depends on the verdicts, and the precision tends to be too high;
see
[`vignette("validation-effort")`](https://provetelab.org/sheepdog/articles/validation-effort.md).

## Rounds of other designs

The tables may also hold clips of other designs, such as a
`"score_bands"` round drawn after the random rounds to add clips near
the threshold (`previous` of the other design in
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)).
Only the `"random_detections"` clips form the cumulative sample: the
clips of the other designs are independent draws and keep their own
`inclusion_prob`, `n_candidates` and `n_drawn`, and an occasion drawn by
both designs is not taken as a repeated round. Weighted by
`1 / inclusion_prob`, the pooled table adds the Horvitz-Thompson totals
of the draws, so the weighted precision of
[`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md),
[`precision_by_bin()`](https://provetelab.org/sheepdog/reference/precision_by_bin.md)
and
[`compare_calibration_curves()`](https://provetelab.org/sheepdog/reference/compare_calibration_curves.md)
is still a ratio estimate. Clips of `"score_bands"` are chosen by their
score and are not for occupancy models
([`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
warns about them). See
[`vignette("validation-effort")`](https://provetelab.org/sheepdog/articles/validation-effort.md).

## See also

[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
[`read_validation_tables()`](https://provetelab.org/sheepdog/reference/read_validation_tables.md).
