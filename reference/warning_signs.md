# Warning signs of a threshold, by species

Gathers, for each species, the warning signs that the detections left
after a threshold are not a reliable input for an ecological model, and
gives a verdict. The signs follow the threshold workflow (Larissa S. M.
Sugai, ACAD pilot); this function computes those that a review sample
can show:

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
  [`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md)).

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

- file:

  Optional path of a Markdown file to write the report to.

## Value

A tibble with one row per species: `species_folder`, `threshold` (the
median over its cells), `sign1_ceiling`, `sign1`, `sign2_tp_kept`,
`sign2`, `sign6_fp_spread`, `sign6`, `sign6_detail`,
`sign7_share_below`, `sign7`, `sign7_detail`, `sign8_verdict`, `sign8`,
`n_checked`, `n_raised` and `verdict`. The `signN` columns are `TRUE`
(raised), `FALSE` (clear) or `NA` (not checked).

## Details

|  |  |  |
|----|----|----|
| sign | what it says | from |
| 1 | low recall ceiling: in many occasions with the species, the classifier gave it no score at all | `recall`, the output of [`recall_ceiling()`](https://provetelab.org/sheepdog/reference/recall_ceiling.md) (needs `"random_recordings"` occasions annotated by ear) |
| 2 | the threshold discards most true positives | the reviewed clips: share of the positive clips at or above the threshold, weighted by `1 / inclusion_prob` |
| 6 | false positives vary by site or season | the reviewed clips: range of the false-positive rate among the levels of each `groups` column; the most frequent identity of the negative clips, when `validation` has `identity` |
| 7 | the threshold is not stable across groups | [`threshold_by_group()`](https://provetelab.org/sheepdog/reference/threshold_by_group.md) for each `groups` column |
| 8 | the logistic curve is wrong near the threshold | `curves`, the output of [`compare_calibration_curves()`](https://provetelab.org/sheepdog/reference/compare_calibration_curves.md) |

Signs 3, 4 and 5 (occupied sites lost, detected days that do not track
the true activity, false negatives that vary by site) need site-days
whose true activity is known, that is recordings annotated in full, and
are not computed here. A sign whose input is missing is `NA`, not
`FALSE`: it was not checked.

**Verdict.** A heuristic summary, not a test:

- `"not_trustworthy"`: the species has no threshold (no score reaches
  the target), no calibration curve reaches the target (sign 8), or
  three or more signs are raised;

- `"use_with_caveats"`: one or two signs are raised;

- `"trustworthy_with_care"`: every sign checked is clear. The signs not
  checked (`n_checked` \< 5) and signs 3 to 5 may still be raised;

- `"not_assessed"`: no sign could be checked.

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
if (FALSE) { # \dontrun{
thr <- suggest_thresholds(val, target_precision = 0.95, sustained = TRUE)
warning_signs(val, thr, groups = c("site", "month"),
              curves = compare_calibration_curves(val),
              recall = recall_ceiling(rr, det, thresholds = thr,
                                      by = c("site", "species_folder")),
              file = "warning_signs.md")
} # }
```
