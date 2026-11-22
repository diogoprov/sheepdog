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

  A data frame (or tibble) of verdicts with `species_code`, `verdict`
  and `identity`, from
  [`app_verdicts()`](https://provetelab.org/sheepdog/reference/app_verdicts.md)
  or
  [`join_identities()`](https://provetelab.org/sheepdog/reference/join_identities.md).

- verdicts:

  Character vector of the verdicts counted: `"negative"` by default; add
  `"uncertain"` to include the uncertain clips.

- classes:

  `NULL` or a character vector of the classes of the classifier, to flag
  identities that are classes themselves. `NULL` (default) uses the
  `species_code` values of `validation`.

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

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read.csv(file.path(ex, "validation", "validation_by_clip_ARA.csv"))
neg <- val$clip_file[val$verdict == "negative"][1:3]
ids <- data.frame(clip = neg, identity = c("insect", "insect", "bird|rain"))
val <- join_identities(val, ids)
#> 3 of 111 negative clip(s) with an identity.
confuser_summary(val)
#> # A tibble: 10 × 7
#>    species_code                 identity     n n_weighted n_sure  share is_class
#>    <chr>                        <chr>    <int>      <dbl>  <int>  <dbl> <lgl>   
#>  1 Boana raniceps_boa-ran       insect       2        2        0 1      FALSE   
#>  2 Dendropsophus nanus_den-nan  NA          13       13        0 0.929  FALSE   
#>  3 Dendropsophus nanus_den-nan  bird         1        0.5      0 0.0357 FALSE   
#>  4 Dendropsophus nanus_den-nan  rain         1        0.5      0 0.0357 FALSE   
#>  5 Elachistocleis bicolor_ela-… NA           7        7        0 1      FALSE   
#>  6 Leptodactylus fuscus_lep-fus NA          33       33        0 1      FALSE   
#>  7 Leptodactylus podicipinus_l… NA           7        7        0 1      FALSE   
#>  8 Physalaemus cuvieri_phy-cuv  NA           2        2        0 1      FALSE   
#>  9 Pseudis platensis_pse-pla    NA          31       31        0 1      FALSE   
#> 10 Scinax nasicus_sci-nas       NA          15       15        0 1      FALSE   
```
