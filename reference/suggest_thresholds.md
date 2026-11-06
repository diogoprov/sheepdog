# Suggest a confidence threshold per species

For each site and species (and each level of the `by` columns), the
lowest confidence `c` such that the precision among the reviewed clips
with confidence \>= `c` reaches `target_precision`, with at least
`min_n` clips. Candidate cuts are the observed confidences rounded to
two decimals.

## Usage

``` r
suggest_thresholds(
  validation,
  target_precision = 0.9,
  min_n = 15,
  by = NULL,
  weighted = NULL
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

## Value

A tibble with `site`, `species_folder`, the `by` columns, `threshold`,
`n_support`, `precision_at_threshold` (unweighted; `NA` when no cut
reaches the target). With `inclusion_prob`, also
`precision_weighted_at_threshold`, `n_eff` (Kish's effective sample size
at the threshold) and `precision_used` (`"weighted"` or `"unweighted"`,
the precision that chose the cut). Without any reviewed clip with a
confidence, the tibble has no rows.

## Details

The precision is computed from the reviewed clips of each cell alone, so
it is reliable only when the clips were drawn at random within the cell
and are numerous.
[`calibrated_thresholds()`](https://provetelab.org/sheepdog/reference/calibrated_thresholds.md)
derives the thresholds from the calibration model of stage 2 instead.

**Design weights.** Clips of `"random_detections"` have unequal
`inclusion_prob`: quiet strata are reviewed almost in full and choruses
lightly. The plain share of positive clips then estimates the precision
of the reviewed sample, not that of the predictions kept by the cut. So,
by default, a cell whose clips all have `inclusion_prob` is judged by
the precision weighted by `1 / inclusion_prob`, as in
[`precision_by_bin()`](https://provetelab.org/sheepdog/reference/precision_by_bin.md),
and `min_n` applies to Kish's effective sample size, \\(\sum w)^2 / \sum
w^2\\, so that a cut resting on a few heavily weighted clips is not
accepted. With equal inclusion probabilities, both choices give the same
threshold. The weights cost variance: when precision does not vary
between strata, the unweighted estimate is also unbiased and less
variable (`weighted = FALSE`).

A cell that mixes clips with and without `inclusion_prob` (`"top"` and
`"random_detections"`, say) cannot be weighted: it gets the unweighted
precision, with a warning, since `"top"` clips are not a probability
sample and should not set thresholds.

## See also

[`calibrated_thresholds()`](https://provetelab.org/sheepdog/reference/calibrated_thresholds.md)
for thresholds from the calibration model.
