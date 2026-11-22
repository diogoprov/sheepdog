# Precision by confidence bin

Precision (share of positive verdicts) of the reviewed clips, by site,
species and confidence bin. Clips without confidence (whole recordings
of `"random_recordings"`) are left out.

## Usage

``` r
precision_by_bin(
  validation,
  bins = seq(0.1, 1, by = 0.1),
  min_n = 15,
  by = NULL
)
```

## Arguments

- validation:

  A data frame (or tibble) returned by
  [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md),
  with columns `site`, `species_folder`, `verdict` and `confidence`. One
  row per clip.

- bins:

  Numeric vector of length \>= 2, increasing breaks of the confidence
  bins (left-closed).

- min_n:

  Integer scalar \>= 1. Minimum of reviewed clips for a bin to be taken
  seriously; bins with fewer are flagged in `low_support`.

- by:

  `NULL` or a character vector of column names of `validation` that
  split each site x species cell further, e.g. the bin of an
  environmental gradient or of an acoustic index joined from
  [`covariate_bins()`](https://provetelab.org/sheepdog/reference/covariate_bins.md).
  They show which parts of the gradient lack reviewed clips.

## Value

A tibble with `site`, `species_folder`, the `by` columns, `bin`,
`n_reviewed`, `n_positive`, `precision`, `precision_weighted` (only with
`inclusion_prob`) and `low_support`.

## Details

When `validation` has `inclusion_prob` (clips drawn with
`"random_detections"` in
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)),
the table also gets `precision_weighted`, the precision weighted by
`1 / inclusion_prob`. It estimates the precision among all the
predictions of the bin from which the clips were drawn, not only among
the reviewed ones; the two differ when the clips of a bin come from
strata drawn with different probabilities. It is `NA` in bins with any
clip without `inclusion_prob` (clips of `"top"`). A blind review
manifest may lack `inclusion_prob`: join it back from the full manifest
first.

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validation_tables(list.files(file.path(ex, "validation"),
                                         full.names = TRUE))
prec <- precision_by_bin(val, min_n = 10)
head(prec)
#> # A tibble: 6 × 7
#>   site  species_folder bin       n_reviewed n_positive precision low_support
#>   <chr> <chr>          <fct>          <int>      <int>     <dbl> <lgl>      
#> 1 ARA   boa_ran        [0.3,0.4)          1          1         1 TRUE       
#> 2 ARA   boa_ran        [0.4,0.5)          2          0         0 TRUE       
#> 3 ARA   boa_ran        [0.5,0.6)          4          4         1 TRUE       
#> 4 ARA   boa_ran        [0.6,0.7)         14         14         1 FALSE      
#> 5 ARA   boa_ran        [0.7,0.8)         18         18         1 FALSE      
#> 6 ARA   boa_ran        [0.8,0.9)         23         23         1 FALSE      
```
