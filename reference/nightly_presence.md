# Confirmed presence by night

Summarises the verdicts by site, species and night. A night is
`"confirmed"` when at least one clip is positive,
`"not_detected_in_reviewed"` when clips were reviewed but none was
positive, and `"not_reviewed"` otherwise.

## Usage

``` r
nightly_presence(validation)
```

## Arguments

- validation:

  A data frame (or tibble) returned by
  [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md),
  with columns `site`, `species_folder`, `verdict` and `confidence`. One
  row per clip.

## Value

A tibble with `site`, `species_folder`, `night`, `n_clips`,
`n_reviewed`, `n_positive`, `presence` and `max_confidence_positive`.

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validation_tables(list.files(file.path(ex, "validation"),
                                         full.names = TRUE))
pres <- nightly_presence(val)
table(pres$species_folder, pres$presence)
#>          
#>           confirmed not_detected_in_reviewed
#>   boa_ran        66                       40
#>   den_nan        66                       48
#>   ela_bic        84                       14
#>   lep_fus        44                       56
#>   lep_pod        76                       18
#>   phy_cuv        78                       16
#>   pse_pla        55                       57
#>   sci_nas        79                       35
```
