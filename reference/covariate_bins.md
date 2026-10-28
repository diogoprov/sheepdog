# Bins of an occasion covariate for stratified clip selection

Cuts a continuous covariate of the occasions (an environmental gradient,
such as the mean temperature of the night, or an acoustic index of the
recording or minute) into bins that can stratify the draw of
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
(`sampling_mode = "random_detections"`, argument `covariates`) and group
the checks of stage 1
([`precision_by_bin()`](https://provetelab.org/sheepdog/reference/precision_by_bin.md),
[`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)
and
[`cell_status()`](https://provetelab.org/sheepdog/reference/cell_status.md),
argument `by`).

## Usage

``` r
covariate_bins(
  covariates,
  var,
  key = c("site", "night"),
  n_bins = 3,
  breaks = NULL,
  within = "site",
  name = paste0(var, "_bin")
)
```

## Arguments

- covariates:

  Data frame with the `key` columns and `var`, one row per occasion (or
  per night, when the covariate is nightly).

- var:

  Name of the numeric column to cut.

- key:

  Columns that identify a row of `covariates` and are matched against
  the occasions in
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md):
  any of `site`, `night`, `recording_date`, `recording_hour`,
  `source_audio` and `occasion_id`. `night` and `recording_date` are
  dates written as `YYYYMMDD`.

- n_bins:

  Number of bins when `breaks` is `NULL`.

- breaks:

  Optional numeric vector of breaks shared by all groups, instead of
  quantiles (bins are left-closed; the last one includes its upper end).

- within:

  Columns within which quantile breaks are computed (`NULL` for
  quantiles over all rows). Ignored when `breaks` is given.

- name:

  Name of the new column. Defaults to `<var>_bin`.

## Value

The `key` columns (as character) and the bin, an ordered factor with
levels `q1`, `q2`, ... (quantile bins, from low to high values of `var`)
or the intervals of `breaks`. Rows with a missing `var` get a missing
bin.

## Details

The bins are computed on `covariates`, which should list every occasion
(with or without predictions), so that the same bins serve the draw and
every later table: the clip manifest and the validation tables keep
their usual columns, and the same table returned here is joined to them
by `key` (e.g. `site` and `night`) before the checks of stage 1. By
default the breaks are quantiles within each site: acoustic indices
depend on the gain and placement of each recorder, and quantiles over
all sites would mix the covariate with the site.

A covariate used to stratify the draw does not depend on the score, so
`inclusion_prob` stays exact. It may, however, be related to the verdict
(an acoustic index rises when the species calls; the false-positive rate
may change along a gradient). The calibration should then include the
bin (e.g. `tp ~ logit_conf + (1 | temp_bin)`) or weight the clips by the
inverse of `inclusion_prob`; see
[`vignette("validation-effort")`](https://provetelab.org/sheepdog/articles/validation-effort.md).

## Examples

``` r
nights <- data.frame(
  site  = rep(c("A", "B"), each = 6),
  night = rep(sprintf("202110%02d", 1:6), 2),
  temp  = c(18, 20, 22, 24, 26, 28, 15, 16, 17, 18, 19, 20))
covariate_bins(nights, "temp", n_bins = 3)
#> # A tibble: 12 × 3
#>    site  night    temp_bin
#>    <chr> <chr>    <ord>   
#>  1 A     20211001 q1      
#>  2 A     20211002 q1      
#>  3 A     20211003 q2      
#>  4 A     20211004 q2      
#>  5 A     20211005 q3      
#>  6 A     20211006 q3      
#>  7 B     20211001 q1      
#>  8 B     20211002 q1      
#>  9 B     20211003 q2      
#> 10 B     20211004 q2      
#> 11 B     20211005 q3      
#> 12 B     20211006 q3      
covariate_bins(nights, "temp", breaks = c(15, 20, 25, 30))
#>    site    night temp_bin
#> 1     A 20211001  [15,20)
#> 2     A 20211002  [20,25)
#> 3     A 20211003  [20,25)
#> 4     A 20211004  [20,25)
#> 5     A 20211005  [25,30]
#> 6     A 20211006  [25,30]
#> 7     B 20211001  [15,20)
#> 8     B 20211002  [15,20)
#> 9     B 20211003  [15,20)
#> 10    B 20211004  [15,20)
#> 11    B 20211005  [15,20)
#> 12    B 20211006  [20,25)
```
