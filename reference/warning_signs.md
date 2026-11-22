# Warning signs of a threshold, by species

Gathers, for each species, the warning signs that the detections left
after a threshold carry problems an ecological model has to deal with
(recall that is low or uneven, false positives that change between sites
or seasons or cluster in recordings, a calibration curve of the wrong
shape), and sums them up in a verdict. The signs describe the
heterogeneity of the data, not whether the threshold reaches its target
precision (see "What the verdict says" below). They follow the threshold
workflow (Larissa S. M. Sugai, ACAD pilot); this function computes those
that a review sample can show:

## Usage

``` r
warning_signs(
  validation,
  thresholds,
  groups = NULL,
  curves = NULL,
  recall = NULL,
  target_precision = 0.95,
  min_n = 15,
  min_tp_kept = 0.25,
  max_fp_spread = 0.3,
  min_ceiling = 0.5,
  threshold_column = "threshold",
  cluster = "source_audio",
  max_deff = 2,
  file = NULL
)
```

## Arguments

- validation:

  Reviewed clips, as for
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md).

- thresholds:

  The threshold of each species or cell: a single number, or a table
  with `species_folder` (and optionally `site`) and a `threshold`
  column, such as the output of
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)
  (`threshold_column` picks another column, such as
  `"threshold_conservative"` of
  [`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md),
  the threshold to apply).

- groups:

  Columns of `validation` for signs 6 and 7, such as `"site"` or a month
  column. `NULL` uses `"site"` when there is more than one site.

- curves:

  Optional output of
  [`compare_calibration_curves()`](https://provetelab.org/sheepdog/reference/compare_calibration_curves.md)
  (sign 8). With curves fitted by site, the worst verdict of the species
  counts.

- recall:

  Optional output of
  [`recall_ceiling()`](https://provetelab.org/sheepdog/reference/recall_ceiling.md)
  (sign 1). With a ceiling per site, the lowest counts.

- target_precision:

  Target precision of the threshold (sign 7).

- min_n:

  Minimum number of clips of a group for it to count in signs 6 and 7.

- min_tp_kept:

  Sign 2 is raised when the share of the true positives kept by the
  threshold is below this.

- max_fp_spread:

  Sign 6 is raised when the false-positive rate of two levels of a group
  differs by more than this.

- min_ceiling:

  Sign 1 is raised when the recall ceiling is below this.

- threshold_column:

  Column of `thresholds` with the threshold.

- cluster:

  Column of `validation` with the recording (or other unit) of each
  clip, for sign 9. A missing column leaves sign 9 `NA`.

- max_deff:

  Sign 9 is raised when the design effect of the false positives above
  the threshold is above this.

- file:

  Optional path of a Markdown file to write the report to.

## Value

A tibble with one row per species: `species_folder`, `threshold` (the
median over its cells), `sign1_ceiling`, `sign1`, `sign2_tp_kept`,
`sign2`, `sign6_fp_spread`, `sign6`, `sign6_detail`,
`sign7_share_below`, `sign7`, `sign7_detail`, `sign8_verdict`, `sign8`,
`sign9_deff`, `sign9`, `n_checked`, `n_raised` and `verdict`. The
`signN` columns are `TRUE` (raised), `FALSE` (clear) or `NA` (not
checked).

## Details

|  |  |  |
|----|----|----|
| sign | what it says | from |
| 1 | low recall ceiling: in many occasions with the species, the classifier gave it no score at all | `recall`, the output of [`recall_ceiling()`](https://provetelab.org/sheepdog/reference/recall_ceiling.md) (needs `"random_recordings"` occasions annotated by ear) |
| 2 | the threshold discards most true positives | the reviewed clips: share of the positive clips at or above the threshold, weighted by `1 / inclusion_prob` |
| 6 | false positives vary by site or season | the reviewed clips: range of the false-positive rate among the levels of each `groups` column; the most frequent identity of the negative clips, when `validation` has `identity` |
| 7 | the threshold is not stable across groups | [`threshold_by_group()`](https://provetelab.org/sheepdog/reference/threshold_by_group.md) for each `groups` column |
| 8 | the logistic curve is wrong near the threshold | `curves`, the output of [`compare_calibration_curves()`](https://provetelab.org/sheepdog/reference/compare_calibration_curves.md) |
| 9 | false positives cluster in recordings | the reviewed clips at or above the threshold: design effect of the false positives by `cluster` |

Signs 3, 4 and 5 (occupied sites lost, detected days that do not track
the true activity, false negatives that vary by site) need site-days
whose true activity is known, that is recordings annotated in full, and
are not computed here. A sign whose input is missing is `NA`, not
`FALSE`: it was not checked.

**Sign 9.** Among the reviewed clips at or above the threshold of their
cell (all cells of the species together, unweighted), the false
positives may concentrate in a few recordings, for instance a recording
with an insect chorus or a similar species calling all night. The sign
gives the design effect of the false-positive indicator by `cluster`,
\\1 + (\bar m - 1)\rho\\, where \\\rho\\ is the intraclass correlation
(ANOVA estimator, truncated at 0) and \\\bar m = \sum m_i^2 / \sum m_i\\
the mean cluster size weighted by size. A design effect of 3 means that
the precision above the threshold is as uncertain as with a third of the
clips: intervals that treat clips as independent are too narrow
([`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md)
resamples whole recordings and does not have this problem), and false
positives that cluster in recordings can turn into false occupied sites.
It needs several reviewed clips per recording, as in designs that review
whole occasions; with one clip per recording it is `NA`. With no false
positive (or no true positive) above the threshold, the design effect is
1.

**Verdict.** A heuristic summary of the signs, not a test:

- `"not_trustworthy"`: the species has no threshold (no score reaches
  the target), no calibration curve reaches the target (sign 8), or
  three or more signs are raised;

- `"use_with_caveats"`: one or two signs are raised;

- `"trustworthy_with_care"`: every sign checked is clear. The signs not
  checked (`n_checked` \< 6) and signs 3 to 5 may still be raised;

- `"not_assessed"`: no sign could be checked.

**What the verdict says.** The verdict is a diagnosis of the
heterogeneity of the data, not of the reliability of the threshold, and
it is not a probability that the threshold misses its target. Two
reasons:

- the signs are checks whose reach grows with the sample: with more
  reviewed clips, more groups reach `min_n` and enter signs 6 and 7, and
  smaller differences are seen. A large sample therefore tends to raise
  more signs even when its threshold is more precise, and a small one
  can clear every sign with a threshold that misses the target;

- a threshold taken from a review sample misses its target mostly
  through sampling variation, which no sign computed from the same
  sample tells apart. In resamples of a real data set, samples with
  every sign clear missed the target more often than samples judged
  `"not_trustworthy"`, and in simulations a clear verdict was reassuring
  only in a small share of the samples. Changing the rule of the verdict
  (more signs required, intervals for signs 6 and 7) did not reorder it.

Read the verdict as a list of what to look at, and of what the
ecological model should account for (false positives by site or season,
clustered false positives, a low recall ceiling), together with the
value of each sign (the `sign1_ceiling`, `sign2_tp_kept`,
`sign6_fp_spread`, `sign7_share_below` and `sign9_deff` columns). For
the reliability of the threshold, apply the conservative threshold of
[`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md)
(`threshold_conservative`), whatever the verdict.

**Which clips.** Signs 2 and 6 are rates of the predictions, so they use
the clips with an inclusion probability (`"random_detections"`,
`"score_bands"`, `"directed_pps"`), weighted by `1 / inclusion_prob`.
Without any such clip they use every reviewed clip, unweighted, with a
message: clips of `"top"` are not a random sample, and the rates are
then only indicative.

## See also

[`recall_ceiling()`](https://provetelab.org/sheepdog/reference/recall_ceiling.md),
[`compare_calibration_curves()`](https://provetelab.org/sheepdog/reference/compare_calibration_curves.md),
[`threshold_by_group()`](https://provetelab.org/sheepdog/reference/threshold_by_group.md),
[`threshold_record()`](https://provetelab.org/sheepdog/reference/threshold_record.md),
[`confuser_summary()`](https://provetelab.org/sheepdog/reference/confuser_summary.md).

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validation_tables(list.files(file.path(ex, "validation"),
                                         full.names = TRUE))
thr <- threshold_bootstrap(val, target_precision = 0.95, n_boot = 30)
warning_signs(val, thr, groups = "site",
              threshold_column = "threshold_conservative",
              file = tempfile(fileext = ".md"))
#> No reviewed clip has `inclusion_prob`: signs 2 and 6 use every clip, unweighted, and are only indicative.
#> Warning signs written to /tmp/RtmpnKV61V/file19652baba8ab.md
#> # A tibble: 8 × 19
#>   species_folder threshold sign1_ceiling sign1 sign2_tp_kept sign2
#>   <chr>              <dbl>         <dbl> <lgl>         <dbl> <lgl>
#> 1 boa_ran            0.674            NA NA            0.858 FALSE
#> 2 den_nan            0.77             NA NA            0.290 FALSE
#> 3 ela_bic            0.417            NA NA            0.997 FALSE
#> 4 lep_fus            0.716            NA NA            0.276 FALSE
#> 5 lep_pod            0.46             NA NA            0.976 FALSE
#> 6 phy_cuv            0.536            NA NA            0.913 FALSE
#> 7 pse_pla            0.81             NA NA            0.245 TRUE 
#> 8 sci_nas            0.805            NA NA            0.311 FALSE
#> # ℹ 13 more variables: sign6_fp_spread <dbl>, sign6 <lgl>, sign6_detail <chr>,
#> #   sign7_share_below <dbl>, sign7 <lgl>, sign7_detail <chr>,
#> #   sign8_verdict <chr>, sign8 <lgl>, sign9_deff <dbl>, sign9 <lgl>,
#> #   n_checked <dbl>, n_raised <dbl>, verdict <chr>
```
