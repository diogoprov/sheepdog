# Consensus verdicts of several reviewers

Combines the verdicts of several reviewers into one validation table:
each clip keeps the verdict its reviewers agree on; clips with
conflicting verdicts get `verdict = "disagreement"` and are listed for a
consensus review. Disagreements are left out of the precision,
thresholds and calibration, which use only positive and negative
verdicts.

## Usage

``` r
consensus_verdicts(reviews)
```

## Arguments

- reviews:

  A data frame (or tibble) or a named list of data frames. One table of
  reviewed clips (as returned by
  [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md))
  with a `reviewer` column, or a named list of such tables, named by
  reviewer.

## Value

A tibble with one row per clip: the columns of the reviewed tables (from
the first reviewer of each clip), `verdict`, `n_reviewers` and
`reviewers` (names separated by `;`).
