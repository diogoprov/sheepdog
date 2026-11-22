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

## Examples

``` r
reviews <- list(
  ana = data.frame(species_folder = "boa_ran",
                   clip_file = paste0("clip", 1:4, ".wav"),
                   verdict = c("positive", "positive", "negative",
                               "uncertain")),
  bruno = data.frame(species_folder = "boa_ran",
                     clip_file = paste0("clip", 1:3, ".wav"),
                     verdict = c("positive", "negative", "negative"))
)
consensus_verdicts(reviews)
#> 1 clip(s) with conflicting verdicts marked "disagreement" for a consensus review.
#>   species_folder clip_file      verdict n_reviewers reviewers
#> 1        boa_ran clip1.wav     positive           2 ana;bruno
#> 2        boa_ran clip2.wav disagreement           2 ana;bruno
#> 3        boa_ran clip3.wav     negative           2 ana;bruno
#> 4        boa_ran clip4.wav    uncertain           0      <NA>
```
