# Community matrices over posterior draws

Builds the community matrices of
[`community_matrices()`](https://provetelab.org/sheepdog/reference/community_matrices.md)
for each draw of
[`history_draws()`](https://provetelab.org/sheepdog/reference/history_draws.md)
and summarises the frequency of each site x month x species cell by its
posterior mean and an interval, so that the uncertainty of the
calibration reaches the matrices. The per-draw frequencies are also
returned, e.g. to repeat an ordination on each draw.

## Usage

``` r
community_matrices_draws(
  history,
  core_species,
  k_min = 2,
  min_nights_month = 5,
  probs = c(0.05, 0.95)
)
```

## Arguments

- history:

  A data frame (or tibble) returned by
  [`history_draws()`](https://provetelab.org/sheepdog/reference/history_draws.md).

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

- probs:

  Numeric vector of length 2 in \[0, 1\], probabilities of the lower and
  upper limits of the interval.

## Value

A list with `summary` (`site`, `month`, `species`, `n_nights_recorded`,
`frequency_mean`, `frequency_lower`, `frequency_upper`) and `draws`
(`draw`, `site`, `month`, `species`, `frequency`).

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
history <- read.csv(file.path(ex, "nightly_detection_history.csv"),
                    colClasses = c(night = "character"))
# history_draws() needs a Bayesian calibration (see its example). As a
# stand-in, three "draws" in which each reliable detection of the
# example history is kept with probability 0.8
set.seed(1)
draws <- do.call(rbind, lapply(1:3, function(d) {
  h <- history
  h$n_reliable <- rbinom(nrow(h), h$n_reliable, 0.8)
  h$detection_k1 <- as.integer(h$n_reliable >= 1)
  h$detection_k2 <- as.integer(h$n_reliable >= 2)
  h$detection_k3 <- as.integer(h$n_reliable >= 3)
  cbind(draw = d, h)
}))
mats <- community_matrices_draws(draws,
                                 core_species = c("boa_ran", "phy_cuv"),
                                 k_min = 2)
mats$summary
#> # A tibble: 46 × 7
#>    site  month   species n_nights_recorded frequency_mean frequency_lower
#>    <chr> <chr>   <chr>               <int>          <dbl>           <dbl>
#>  1 ARA   2021-10 boa_ran                 5            1               1  
#>  2 ARA   2021-10 phy_cuv                 5            0               0  
#>  3 ARA   2021-11 boa_ran                 5            1               1  
#>  4 ARA   2021-11 phy_cuv                 5            1               1  
#>  5 ARA   2021-12 boa_ran                 5            0.8             0.8
#>  6 ARA   2021-12 phy_cuv                 5            1               1  
#>  7 ARA   2022-01 boa_ran                 5            1               1  
#>  8 ARA   2022-01 phy_cuv                 5            1               1  
#>  9 ARA   2022-02 boa_ran                 5            1               1  
#> 10 ARA   2022-02 phy_cuv                 5            1               1  
#> # ℹ 36 more rows
#> # ℹ 1 more variable: frequency_upper <dbl>
```
