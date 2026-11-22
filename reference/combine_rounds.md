# Combine the review rounds of a design

Stacks the tables of the rounds of a `"random_detections"` design and
gives every clip the inclusion probability of the combined sample. Each
round of
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
draws among the occasions not drawn yet, so the occasions drawn in all
rounds are a simple random sample of each stratum, and every clip has
the probability `n_drawn / n_candidates`, whatever its round. The value
stored in the table of an earlier round is out of date as soon as
another round is drawn; this function recomputes it from the candidates
and the clips, so no earlier file is edited.

## Usage

``` r
combine_rounds(validation, candidates = NULL)
```

## Arguments

- validation:

  A character vector of paths, a data frame, or a list of these: the
  tables of all rounds (paths to the `validation_by_clip.csv` files or
  manifests), one row per clip, with the columns `site`, `species_code`,
  `occasion_id` and `sampling_mode`. Tables without `round` count as one
  round each, in the order given.

- candidates:

  `NULL`, a character scalar (path) or a data frame: the
  `candidates.csv` of the first round. `NULL` looks for it in the
  folders of `validation`.

## Value

The stacked table, in the order of the input, with `stratum`,
`n_candidates`, `n_drawn`, the cumulative `inclusion_prob` and
`n_rounds`, the number of rounds with clips of the site x species. Clips
of other sampling modes keep their `inclusion_prob`, `n_candidates` and
`n_drawn`, with `stratum` and `n_rounds` `NA`.

## Details

The probability is exact for a number of rounds fixed in advance. When
the rounds of a cell go on until it reaches a target, the decision to
stop depends on the verdicts, and the precision tends to be too high;
see
[`vignette("validation-effort")`](https://provetelab.org/sheepdog/articles/validation-effort.md).

## Rounds of other designs

The tables may also hold clips of other designs, such as a
`"score_bands"` round drawn after the random rounds to add clips near
the threshold (`previous` of the other design in
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)).
Only the `"random_detections"` clips form the cumulative sample: the
clips of the other designs are independent draws and keep their own
`inclusion_prob`, `n_candidates` and `n_drawn`, and an occasion drawn by
both designs is not taken as a repeated round. Weighted by
`1 / inclusion_prob`, the pooled table adds the Horvitz-Thompson totals
of the draws, so the weighted precision of
[`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md),
[`precision_by_bin()`](https://provetelab.org/sheepdog/reference/precision_by_bin.md)
and
[`compare_calibration_curves()`](https://provetelab.org/sheepdog/reference/compare_calibration_curves.md)
is still a ratio estimate. Clips of `"score_bands"` are chosen by their
score and are not for occupancy models
([`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
warns about them). See
[`vignette("validation-effort")`](https://provetelab.org/sheepdog/articles/validation-effort.md).

## See also

[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
[`read_validation_tables()`](https://provetelab.org/sheepdog/reference/read_validation_tables.md).

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
det <- read_selection_tables(file.path(ex, "birdnet"))
#> 4 combined table(s) and 0 per-audio table(s) found in 4 folder(s):
#>   - /home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/ARA: BirdNET_SelectionTable.txt
#>   - /home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/BAI: BirdNET_SelectionTable.txt
#>   - /home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/NHE: BirdNET_SelectionTable.txt
#>   - /home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/XAR: BirdNET_SelectionTable.txt
#> 7553 predictions read from 4 site(s).
# two rounds of the same "random_detections" design; the second draws
# among the occasions not drawn in the first
r1 <- select_clips(det, "random_detections", threshold = 0.5,
                   strata = "site_species", n_top = 3)
#> Sampling mode: random_detections (occasion = file).
#> 96 occasions drawn (3 per site x species_code) among 1876 with a prediction >= 0.5.
#> 222 clips (every prediction >= 0.5 of the 96 occasions drawn).
cand <- attr(r1, "candidates")
r2 <- select_clips(det, "random_detections", threshold = 0.5,
                   strata = "site_species", n_top = 3,
                   previous = r1, candidates = cand)
#> `previous`: earlier rounds of this design, so their occasions leave the pool.
#> Sampling mode: random_detections (occasion = file).
#> Round 2: 96 occasions drawn among 1780 not drawn yet; 0 of 32 strata have no occasion left.
#> 258 clips (every prediction >= 0.5 of the 96 occasions drawn).
both <- combine_rounds(list(r1, r2), cand)
# every clip now has the probability of the combined sample
unique(both[, c("site", "species_folder", "n_candidates", "n_drawn",
                "inclusion_prob")])
#> # A tibble: 32 × 5
#>    site  species_folder n_candidates n_drawn inclusion_prob
#>    <chr> <chr>                 <int>   <dbl>          <dbl>
#>  1 ARA   boa_ran                  86       6         0.0698
#>  2 ARA   den_nan                  81       6         0.0741
#>  3 ARA   ela_bic                  53       6         0.113 
#>  4 ARA   lep_fus                   9       6         0.667 
#>  5 ARA   lep_pod                  52       6         0.115 
#>  6 ARA   phy_cuv                  58       6         0.103 
#>  7 ARA   pse_pla                  62       6         0.0968
#>  8 ARA   sci_nas                  75       6         0.08  
#>  9 BAI   boa_ran                  47       6         0.128 
#> 10 BAI   den_nan                  53       6         0.113 
#> # ℹ 22 more rows
```
