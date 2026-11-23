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

  A data frame (or tibble) returned by
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md),
  with columns `site`, `species_folder` and `threshold`.

- bootstrap:

  `NULL` or a data frame (or tibble) returned by
  [`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md).

- groups:

  `NULL` or a data frame (or tibble) returned by
  [`threshold_by_group()`](https://provetelab.org/sheepdog/reference/threshold_by_group.md).

- extraction_info:

  `NULL`, a character scalar with the path to `extraction_info.csv`, or
  the data frame read from it: its `key`, `value` rows are written at
  the top of the Markdown file.

- target_precision:

  Numeric scalar, target precision used, recorded in the table.

- file:

  `NULL` or a character scalar, path of a Markdown file to write.

## Value

A tibble (class `tbl_df`), one row per cell, with the columns of
`thresholds`, `target_precision`, the bootstrap columns and, from
`groups`, `n_groups`, `n_groups_below` and `worst_group_precision`;
invisibly when `file` is given.

## See also

[`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md),
[`threshold_bootstrap()`](https://provetelab.org/sheepdog/reference/threshold_bootstrap.md),
[`threshold_by_group()`](https://provetelab.org/sheepdog/reference/threshold_by_group.md).

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validation_tables(file.path(ex, "validation",
                                        "validation_by_clip_ARA.csv"))
thr <- suggest_thresholds(val, target_precision = 0.90, min_n = 15,
                          sustained = TRUE)
boot <- threshold_bootstrap(val, target_precision = 0.90, min_n = 15,
                            sustained = TRUE, n_boot = 100)
val$month <- substr(val$recording_date, 1, 6)
groups <- threshold_by_group(val, boot, by = "month", min_n = 5,
                             threshold_column = "threshold_conservative")
threshold_record(thr, bootstrap = boot, groups = groups)
#> # A tibble: 8 × 13
#>   site  species_folder threshold n_support precision_at_threshold
#>   <chr> <chr>              <dbl>     <int>                  <dbl>
#> 1 ARA   boa_ran             0.36        80                  0.975
#> 2 ARA   den_nan             0.56        56                  0.911
#> 3 ARA   ela_bic             0.13        79                  0.924
#> 4 ARA   lep_fus            NA           NA                 NA    
#> 5 ARA   lep_pod             0.1         80                  0.912
#> 6 ARA   phy_cuv             0.19        79                  0.987
#> 7 ARA   pse_pla            NA           NA                 NA    
#> 8 ARA   sci_nas             0.76        24                  0.958
#> # ℹ 8 more variables: target_precision <dbl>, threshold_median <dbl>,
#> #   threshold_conservative <dbl>, share_reached <dbl>, n_clusters <int>,
#> #   n_groups <int>, n_groups_below <int>, worst_group_precision <dbl>
# Also write the record as a Markdown table
md <- file.path(tempdir(), "threshold_record.md")
threshold_record(thr, bootstrap = boot, groups = groups, file = md)
#> Threshold record written to /tmp/RtmpEfjhan/threshold_record.md
head(readLines(md))
#> [1] "# Threshold record"                           
#> [2] ""                                             
#> [3] "Written by sheepdog 3.4.1.9000 on 2026-11-23."
#> [4] ""                                             
#> [5] "## Thresholds"                                
#> [6] ""                                             
```
