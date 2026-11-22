# Assign the clips to several reviewers

Splits the clips of a manifest among reviewers, balanced within each
species, and gives a fraction of them to a second reviewer, so that the
agreement between reviewers can be measured with
[`reviewer_agreement()`](https://provetelab.org/sheepdog/reference/reviewer_agreement.md).
The overlap is drawn within each species, so every species gets doubly
reviewed clips.

## Usage

``` r
assign_reviewers(manifest, reviewers, overlap = 0.1, seed = 2026)
```

## Arguments

- manifest:

  A data frame (or tibble), the clip manifest as returned by
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
  or
  [`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md).
  One row per clip.

- reviewers:

  Character vector of length \>= 2, unique names of the reviewers.

- overlap:

  Numeric scalar in \[0, 1\]. Fraction of the clips of each species
  reviewed by two reviewers.

- seed:

  Integer scalar, seed of the draws. The global random number generator
  is left as it was.

## Value

A tibble (class `tbl_df`): the manifest with `reviewer` (the first
reviewer of each clip) and `second_reviewer` (`NA` for clips reviewed
once).

## Details

Cut the clips with
[`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md)
first, then copy each reviewer's share to their own folder with
[`split_by_reviewer()`](https://provetelab.org/sheepdog/reference/split_by_reviewer.md).

## Examples

``` r
man <- read.csv(system.file("extdata", "clip_manifest.csv",
                            package = "sheepdog"))
man <- assign_reviewers(man, c("ana", "bruno", "carla"), overlap = 0.5)
table(man$species_folder, man$reviewer)
#>          
#>           ana bruno carla
#>   boa_ran   4     4     4
sum(!is.na(man$second_reviewer))
#> [1] 6
```
