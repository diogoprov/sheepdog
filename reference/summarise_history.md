# Summarise the detection history by site and species

Summarise the detection history by site and species

## Usage

``` r
summarise_history(history)
```

## Arguments

- history:

  A data frame (or tibble) returned by
  [`detection_history()`](https://provetelab.org/sheepdog/reference/detection_history.md).

## Value

A tibble (class `tbl_df`) with `site`, `species`, `nights` (nights with
any scored detection) and `nights_k1` to `nights_k3` (nights with
detection under each repetition rule).

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validations(list.files(file.path(ex, "validation"),
                                   full.names = TRUE))
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
fit <- fit_calibration(val, tp ~ logit_conf + species)
sites <- c("ARA", "BAI", "NHE", "XAR")
tables <- file.path(ex, "birdnet", sites, "BirdNET_SelectionTable.txt")
names(tables) <- sites
history <- detection_history(score_detections(tables, fit))
#> Scoring ARA (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/ARA/BirdNET_SelectionTable.txt)...
#>   1753 detections of calibrated species (0 of species NOT calibrated were dropped).
#> Scoring BAI (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/BAI/BirdNET_SelectionTable.txt)...
#>   1427 detections of calibrated species (0 of species NOT calibrated were dropped).
#> Scoring NHE (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/NHE/BirdNET_SelectionTable.txt)...
#>   2507 detections of calibrated species (0 of species NOT calibrated were dropped).
#> Scoring XAR (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/XAR/BirdNET_SelectionTable.txt)...
#>   1866 detections of calibrated species (0 of species NOT calibrated were dropped).
summarise_history(history)
#> # A tibble: 32 × 6
#>    site  species nights nights_k1 nights_k2 nights_k3
#>    <chr> <fct>    <int>     <int>     <int>     <int>
#>  1 ARA   boa_ran     30        24        18        12
#>  2 ARA   den_nan     30         3         0         0
#>  3 ARA   ela_bic     24        19        19        16
#>  4 ARA   lep_fus     21         0         0         0
#>  5 ARA   lep_pod     22        19        16        15
#>  6 ARA   phy_cuv     24        19        19        19
#>  7 ARA   pse_pla     30         1         0         0
#>  8 ARA   sci_nas     30         7         3         0
#>  9 BAI   boa_ran     29        14        11         7
#> 10 BAI   den_nan     30         4         3         1
#> # ℹ 22 more rows
```
