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

  The tables of all rounds: paths to the `validation_by_clip.csv` files
  or manifests, a data frame, or a list of these. Tables without `round`
  count as one round each, in the order given.

- candidates:

  The `candidates.csv` of the first round, as a path or a data frame.
  `NULL` looks for it in the folders of `validation`.

## Value

The stacked table, with `stratum`, `n_candidates`, `n_drawn`, the
cumulative `inclusion_prob` and `n_rounds`, the number of rounds with
clips of the site x species. Clips of other sampling modes are kept as
they are, with these columns `NA`.

## Details

The probability is exact for a number of rounds fixed in advance. When
the rounds of a cell go on until it reaches a target, the decision to
stop depends on the verdicts, and the precision tends to be too high;
see
[`vignette("validation-effort")`](https://provetelab.org/sheepdog/articles/validation-effort.md).

## See also

[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
[`read_validation_tables()`](https://provetelab.org/sheepdog/reference/read_validation_tables.md).
