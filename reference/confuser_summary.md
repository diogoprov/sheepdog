# What the false positives of each class are

Counts, for each target class, the identities given to its negative
clips (and, optionally, its uncertain clips): the sounds the classifier
confuses with the target. The table points to hard negatives for
retraining and shows when a negative of one class is a positive of
another class of the classifier.

## Usage

``` r
confuser_summary(validation, verdicts = "negative", classes = NULL)
```

## Arguments

- validation:

  Table of verdicts with `species_code`, `verdict` and `identity`, from
  [`app_verdicts()`](https://provetelab.org/sheepdog/reference/app_verdicts.md)
  or
  [`join_identities()`](https://provetelab.org/sheepdog/reference/join_identities.md).

- verdicts:

  Verdicts counted: `"negative"` by default; add `"uncertain"` to
  include the uncertain clips.

- classes:

  Classes of the classifier, to flag identities that are classes
  themselves. By default, the `species_code` values of `validation`.

## Value

A tibble with one row per target class and identity: `species_code`,
`identity`, `n` (clips), `n_weighted`, `n_sure` (clips with certainty
`"sure"`), `share` (`n_weighted` over the clips of the class counted)
and `is_class` (the identity is a class of the classifier other than the
target), sorted by class and decreasing `n`.

## Details

A clip with several identities (`"a|b"`) counts once for each of them,
with weight `1 / k` in `n_weighted` for `k` identities, so that
`n_weighted` sums to the number of clips with an identity. Clips without
an identity are counted as `identity = NA`.

## See also

[`join_identities()`](https://provetelab.org/sheepdog/reference/join_identities.md),
[`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md).
