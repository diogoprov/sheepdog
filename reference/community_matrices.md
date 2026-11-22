# Community matrices from the detection history

Turns the calibrated nightly detection history into site x month
community matrices for multivariate ordinations (PCoA, NMDS, RDA).
Because those analyses do not model false positives, the entry rule is
strict:

- a species counts as detected on a night only when it had at least
  `k_min` reliable detections that night, i.e. detections with a
  calibrated probability \>= `p_min` of
  [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md)
  (column `detection_k<k_min>` of the history);

- only the core species enter the matrix: species whose calibration is
  reliable at every site. Other species would create artefactual beta
  diversity from differences in classifier recall among sites;

- each cell is the frequency of nights with detection, standardised by
  effort: nights with detection / nights recorded at that site x month.

## Usage

``` r
community_matrices(
  history,
  core_species,
  k_min = 2,
  min_nights_month = 5,
  drop_empty = FALSE
)
```

## Arguments

- history:

  A data frame (or tibble), the nightly detection history as returned by
  [`detection_history()`](https://provetelab.org/sheepdog/reference/detection_history.md),
  one row per site x species x night (v1.2.0
  `historico_deteccao_noite.csv` tables are also accepted).

- core_species:

  Character vector of length \>= 1, species codes (the `species` column)
  that enter the matrix.

- k_min:

  Integer scalar, one of 1, 2 or 3. Repetition rule: 1, 2 or 3 reliable
  detections on the night.

- min_nights_month:

  Numeric scalar. Site x month cells with fewer recorded nights are
  dropped from the matrices (unstable frequencies) and flagged in
  `effort`.

- drop_empty:

  Logical scalar. If `TRUE`, drops the site x month rows in which no
  core species was detected. Distances such as Bray-Curtis are undefined
  for them.

## Value

A list with three tibbles, `frequency` and `counts` (one row per site x
month, with `site`, `month`, `n_nights_recorded` and one column per core
species) and `effort` (`site`, `month`, `n_nights_recorded`,
`included`), plus `trials`: a numeric matrix with the dimensions of the
species columns of `counts` holding the nights recorded, the `Ntrials`
of a binomial model of the counts (e.g.
[`gllvm::gllvm()`](https://jenniniku.github.io/gllvm/reference/gllvm.html),
which needs a matrix when effort varies among samples). The row names of
`trials` are `<site>_<month>`.

## Details

Effort (nights recorded) is approximated by the number of distinct
nights in the history of the site, for any species. With dense
detections, every night actually recorded appears in the history.

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
history <- read.csv(file.path(ex, "nightly_detection_history.csv"),
                    colClasses = c(night = "character"))
mats <- community_matrices(history,
                           core_species = c("boa_ran", "ela_bic",
                                            "phy_cuv"),
                           k_min = 2, min_nights_month = 5)
mats$frequency
#> # A tibble: 23 × 6
#>    site  month   n_nights_recorded boa_ran ela_bic phy_cuv
#>    <chr> <chr>               <int>   <dbl>   <dbl>   <dbl>
#>  1 ARA   2021-10                 5     1         0       0
#>  2 ARA   2021-11                 5     1         1       1
#>  3 ARA   2021-12                 5     1         1       1
#>  4 ARA   2022-01                 5     1         1       1
#>  5 ARA   2022-02                 5     1         1       1
#>  6 ARA   2022-03                 5     1         0       0
#>  7 BAI   2021-10                 5     0         0       0
#>  8 BAI   2021-11                 5     0         1       1
#>  9 BAI   2021-12                 5     0.8       1       1
#> 10 BAI   2022-01                 5     1         1       1
#> # ℹ 13 more rows
# Site x month cells dropped for low effort
mats$effort[!mats$effort$included, ]
#>    site   month n_nights_recorded included
#> 19  XAR 2021-10                 3    FALSE
head(mats$trials)
#>             boa_ran ela_bic phy_cuv
#> ARA_2021-10       5       5       5
#> ARA_2021-11       5       5       5
#> ARA_2021-12       5       5       5
#> ARA_2022-01       5       5       5
#> ARA_2022-02       5       5       5
#> ARA_2022-03       5       5       5
```
