# Threshold record

Gathers, for each site x species cell, what is needed to reproduce and
judge a threshold: how it was set (weighted or not, the target, the
number of clips), its uncertainty
([`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md)),
whether it holds in every group
([`threshold_by_group()`](https://provetelab.org/sheepdog/reference/threshold_by_group.md))
and the provenance of the clips (`extraction_info.csv` of
[`extract_validation_clips()`](https://provetelab.org/sheepdog/reference/extract_validation_clips.md)
or of the app). With `file`, it also writes the record as a Markdown
table.

## Usage

``` r
threshold_record(
  thresholds,
  bootstrap = NULL,
  groups = NULL,
  extraction_info = NULL,
  target_precision = 0.9,
  file = NULL
)
```

## Arguments

- thresholds:

  Table from
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md).

- bootstrap:

  Optional table from
  [`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md).

- groups:

  Optional table from
  [`threshold_by_group()`](https://provetelab.org/sheepdog/reference/threshold_by_group.md).

- extraction_info:

  Optional path to `extraction_info.csv` (or the table read from it):
  its `key`, `value` rows are written at the top of the Markdown file.

- target_precision:

  Target precision used, recorded in the table.

- file:

  Optional path of a Markdown file to write.

## Value

A tibble, one row per cell, with the columns of `thresholds`,
`target_precision`, the bootstrap columns and, from `groups`,
`n_groups`, `n_groups_below` and `worst_group_precision`; invisibly when
`file` is given.

## See also

[`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md),
[`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md),
[`threshold_by_group()`](https://provetelab.org/sheepdog/reference/threshold_by_group.md).
