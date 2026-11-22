# Positive clips for retraining

Lists the clips confirmed as positive, ready to retrain the classifier.

## Usage

``` r
retraining_clips(validation)
```

## Arguments

- validation:

  A data frame (or tibble) returned by
  [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md),
  with columns `site`, `species_folder`, `verdict` and `confidence`. One
  row per clip.

## Value

A tibble (class `tbl_df`) with `site`, `species_code`, `species_folder`,
`clip_file`, `reviewed_path`, `confidence`, `night`, `recording_hour`
and `source_audio`.

## Examples

``` r
val <- read.csv(system.file("extdata", "validation_by_clip.csv",
                            package = "sheepdog"))
retraining_clips(val)
#> # A tibble: 8 × 9
#>   site  species_code    species_folder clip_file reviewed_path confidence  night
#>   <chr> <chr>           <chr>          <chr>     <chr>              <dbl>  <int>
#> 1 ARA   Boana raniceps… boa_ran        0.913_1_… /project/rev…      0.913 2.02e7
#> 2 ARA   Boana raniceps… boa_ran        0.789_1_… /project/rev…      0.789 2.02e7
#> 3 ARA   Boana raniceps… boa_ran        0.938_2_… /project/rev…      0.938 2.02e7
#> 4 ARA   Boana raniceps… boa_ran        0.622_3_… /project/rev…      0.622 2.02e7
#> 5 ARA   Boana raniceps… boa_ran        0.552_1_… /project/rev…      0.552 2.02e7
#> 6 ARA   Boana raniceps… boa_ran        0.964_2_… /project/rev…      0.964 2.02e7
#> 7 ARA   Boana raniceps… boa_ran        0.723_3_… /project/rev…      0.723 2.02e7
#> 8 ARA   Boana raniceps… boa_ran        0.705_1_… /project/rev…      0.705 2.02e7
#> # ℹ 2 more variables: recording_hour <int>, source_audio <chr>
```
