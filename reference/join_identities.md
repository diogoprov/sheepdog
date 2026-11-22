# Join identities of negative clips recorded outside the app

Adds to a table of verdicts the identity of negative (and uncertain)
clips that a reviewer wrote elsewhere, for example in a spreadsheet with
one row per clip. The identities given in
[`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md) are
kept: an external identity only fills clips without one, and a clip
where the two differ is reported.

## Usage

``` r
join_identities(
  validation,
  identities,
  clip_col = "clip",
  identity_col = "identity",
  certainty_col = NULL,
  reviewer = NULL
)
```

## Arguments

- validation:

  A data frame (or tibble) of verdicts with `clip_file` and `verdict`,
  from
  [`app_verdicts()`](https://provetelab.org/sheepdog/reference/app_verdicts.md),
  [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md)
  or
  [`consensus_verdicts()`](https://provetelab.org/sheepdog/reference/consensus_verdicts.md).

- identities:

  A data frame (or tibble), or a character scalar with the path to a
  CSV, with one row per clip. Read a spreadsheet with
  `readxl::read_excel()` first.

- clip_col, identity_col:

  Character scalars, the columns of `identities` with the clip name (as
  in `clip_file`; a path is reduced to its file name) and the identity.

- certainty_col:

  `NULL` or a character scalar, the column of `identities` with the
  certainty, `"sure"` or `"probable"`. Without it, the certainty is left
  `NA`.

- reviewer:

  `NULL` or a character vector of reviewer names: with a table that has
  one row per clip and reviewer, only those reviewers' rows receive the
  identities.

## Value

`validation` with `identity` and `identity_certainty` filled.

## Details

Identities are trimmed of spaces; several identities of one clip,
separated by `|`, mean either of them. Warnings list the clips of
`identities` that are not in `validation` and the clips that received an
identity although their verdict is neither negative nor uncertain (a
sign that the verdict or the identity is wrong). A message gives how
many negative clips are still without an identity.

## See also

[`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md),
[`confuser_summary()`](https://provetelab.org/sheepdog/reference/confuser_summary.md),
[`identity_categories()`](https://provetelab.org/sheepdog/reference/identity_categories.md).

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read.csv(file.path(ex, "validation", "validation_by_clip_ARA.csv"))
# Identities of two negative clips, written in a spreadsheet
neg <- val$clip_file[val$verdict == "negative"][1:2]
ids <- data.frame(clip = neg, identity = c("insect", "bird|noise"),
                  certainty = c("sure", "probable"))
val <- join_identities(val, ids, certainty_col = "certainty")
#> 2 of 111 negative clip(s) with an identity.
val[val$clip_file %in% neg,
    c("clip_file", "verdict", "identity", "identity_certainty")]
#>                                          clip_file  verdict   identity
#> 1  0.469_2_ARA01_20211016_190000_165.0s_168.0s.wav negative     insect
#> 13   0.500_1_ARA01_20211022_010000_60.0s_63.0s.wav negative bird|noise
#>    identity_certainty
#> 1                sure
#> 13           probable
```
