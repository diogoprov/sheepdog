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
  sustained = NULL,
  n_boot = 1000,
  cluster = "source_audio",
  conf = 0.95,
  seed = 2026
)
```

## Arguments

- validation:

  A data frame (or tibble) returned by
  [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md),
  with columns `site`, `species_folder`, `verdict` and `confidence`. One
  row per clip.

- target_precision:

  Numeric scalar in (0, 1). Target precision.

- min_n:

  Integer scalar \>= 1. Minimum of reviewed clips for a bin to be taken
  seriously; bins with fewer are flagged in `low_support`.

- by:

  `NULL` or a character vector of column names of `validation` that
  split each site x species cell further, e.g. the bin of an
  environmental gradient or of an acoustic index joined from
  [`covariate_bins()`](https://provetelab.org/sheepdog/reference/covariate_bins.md).
  They show which parts of the gradient lack reviewed clips.

- weighted:

  `NULL`, `TRUE` or `FALSE`. Which precision chooses the cut. `NULL`
  (default): the weighted one in the cells whose clips all have
  `inclusion_prob`, the unweighted one elsewhere. `TRUE`: always the
  weighted one; cells with clips without `inclusion_prob` get no
  threshold, with a warning, and it is an error if no clip has it.
  `FALSE`: always the unweighted one, and `n_support` for `min_n`.

- sustained:

  `NULL` or logical scalar. If `TRUE`, the target must also hold at
  every higher cut with at least `min_n` clips (see
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)).
  `NULL`, the default, currently means `TRUE` and warns once per
  session: in the next minor version the default becomes `FALSE`, as in
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md),
  so that the point `threshold` matches it. Set `sustained` to keep the
  current thresholds.

- n_boot:

  Integer scalar \>= 1. Number of bootstrap replicates.

- cluster:

  Character scalar, the column of `validation` that defines the
  resampling unit: `"source_audio"` (the recording, the default),
  `"night"` or any other column. Resampling is done within each site x
  species cell (and `by` group), so the unit must vary within it:
  `"site"` is not a valid unit here. A cell with a single unit gets `NA`
  in `threshold_median`, `threshold_conservative` and `share_reached`,
  with a warning, since resampling it gives no information on the
  uncertainty. With few units (say, fewer than 10), the quantiles of the
  replicates are rough.

- conf:

  Numeric scalar in (0, 1). Probability of the conservative (upper)
  quantile.

- seed:

  Integer scalar, seed of the resampling. The global random number
  generator is left as it was.

## Value

A tibble (class `tbl_df`) with `site`, `species_folder`, the `by`
columns, `threshold` (from all the clips), `threshold_median`,
`threshold_conservative` (quantile `conf` of the replicates),
`share_reached` (share of replicates in which some score reaches the
target) and `n_clusters`.

## Details

The threshold is the lowest score at which the precision of the reviewed
clips at or above it reaches `target_precision`, weighted by
`1 / inclusion_prob` when the clips have it (the weighted count of a
probability sample). The upper quantile of the replicates
(`threshold_conservative`) is the conservative threshold: with it, the
target is met in about `conf` of the replicates.

**Which threshold to apply.** Use `threshold_conservative`, not the
point `threshold`, for the detections that are kept (for instance in
[`threshold_history()`](https://provetelab.org/sheepdog/reference/threshold_history.md)
and
[`warning_signs()`](https://provetelab.org/sheepdog/reference/warning_signs.md)).
The point threshold is nearly unbiased, but it falls below the cut that
gives the target in a large share of samples, by sampling variation
alone, and no warning sign computed from the same sample tells those
samples apart. The conservative threshold trades some recall for that
guarantee. With few reviewed clips per cell (about 100 or fewer), or a
precision that levels off near the target, even the conservative
threshold can miss it: review more clips near the threshold. A wide
interval means the precision curve is flat near the target, and a new
round of review near the threshold narrows it (a new round of
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
combined with the first by
[`combine_rounds()`](https://provetelab.org/sheepdog/reference/combine_rounds.md)).

## See also

[`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md),
[`threshold_by_group()`](https://provetelab.org/sheepdog/reference/threshold_by_group.md),
[`threshold_record()`](https://provetelab.org/sheepdog/reference/threshold_record.md).

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validation_tables(file.path(ex, "validation",
                                        "validation_by_clip_ARA.csv"))
# Resamples whole recordings; use n_boot = 1000 or more in practice
boot <- threshold_bootstrap(val, target_precision = 0.90, min_n = 15,
                            sustained = TRUE, n_boot = 100)
boot[, c("species_folder", "threshold", "threshold_conservative")]
#> # A tibble: 8 × 3
#>   species_folder threshold threshold_conservative
#>   <chr>              <dbl>                  <dbl>
#> 1 boa_ran             0.36                  0.5  
#> 2 den_nan             0.56                  0.851
#> 3 ela_bic             0.13                  0.262
#> 4 lep_fus            NA                    NA    
#> 5 lep_pod             0.1                   0.273
#> 6 phy_cuv             0.19                  0.38 
#> 7 pse_pla            NA                     0.81 
#> 8 sci_nas             0.76                  0.76 
```
