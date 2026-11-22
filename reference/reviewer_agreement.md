# Agreement between reviewers

Measures, for each species, the agreement between reviewers on the clips
reviewed more than once: the proportion of agreement and kappa, which
discounts the agreement expected by chance. When a species has exactly
two reviewers, this is Cohen's kappa, with the marginal frequencies of
each reviewer (Cohen 1960,
[doi:10.1177/001316446002000104](https://doi.org/10.1177/001316446002000104)
); with more reviewers, or different pairs of reviewers on different
clips, Fleiss' kappa (Fleiss 1971,
[doi:10.1037/h0031619](https://doi.org/10.1037/h0031619) ). Only
positive and negative verdicts count.

## Usage

``` r
reviewer_agreement(reviews)
```

## Arguments

- reviews:

  A data frame (or tibble) or a named list of data frames. One table of
  reviewed clips (as returned by
  [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md))
  with a `reviewer` column, or a named list of such tables, named by
  reviewer.

## Value

A tibble with `species_folder`, `n_clips` (clips with at least two
verdicts), `n_reviewers`, `agreement`, `kappa` and `method`.
