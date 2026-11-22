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
