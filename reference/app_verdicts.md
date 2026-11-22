# Verdicts of the review app

Joins the verdicts written by
[`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md) to
the clip manifest, giving the same table as
[`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md)
(the content of `validation_by_clip.csv`), so that the summaries of
stage 1, the agreement between reviewers and the calibration work as
with a review in the BirdNET GUI. `"uncertain"` verdicts are kept but,
like `"disagreement"`, left out of precision, thresholds and
calibration, which use only positive and negative verdicts.

## Usage

``` r
app_verdicts(manifest, verdicts_file, clips_dir = NULL, reviewer = NULL)
```

## Arguments

- manifest:

  `NULL`, a data frame (or tibble) or a character scalar path to
  `clip_manifest.csv`: the clip manifest (from
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
  [`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md)
  or
  [`assign_reviewers()`](https://provetelab.org/sheepdog/reference/assign_reviewers.md)),
  one row per clip. With `output_dir`, by default
  `<output_dir>/clip_manifest.csv` when it exists.

- verdicts_file:

  Character scalar, path to the CSV written by
  [`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md).

- clips_dir:

  `NULL` or a character scalar, folder of the clips, to fill
  `reviewed_path` (needed by
  [`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md)).

- reviewer:

  `NULL` or a character scalar, the reviewer: only their verdicts are
  used. With `NULL`, every reviewer's verdicts are kept, one row per
  clip and reviewer, ready for
  [`reviewer_agreement()`](https://provetelab.org/sheepdog/reference/reviewer_agreement.md)
  and
  [`consensus_verdicts()`](https://provetelab.org/sheepdog/reference/consensus_verdicts.md).

  A clip marked more than once by the same reviewer keeps the last
  verdict; a message says how many clips were marked again and how many
  of them changed verdict.

## Value

The manifest with `verdict` (`"positive"`, `"negative"`, `"uncertain"`
or `"not_reviewed"`), `reviewed_path`, `reviewer`, `identity` and
`identity_certainty` (`NA` when the reviewer gave no identity, or with a
verdicts file of an earlier version). With `reviewer = NULL`, a clip
reviewed by two reviewers has two rows, and a clip not yet reviewed has
one row with `reviewer = NA`.

## See also

[`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md),
[`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md).

## Examples

``` r
man <- system.file("extdata", "clip_manifest.csv", package = "sheepdog")
m <- read.csv(man)
# A verdicts file as written by run_app(), with two reviewers
f <- tempfile(fileext = ".csv")
write.csv(data.frame(
  clip_file = m$clip_file[c(1, 1, 2, 3)],
  species_folder = m$species_folder[c(1, 1, 2, 3)],
  reviewer = c("ana", "bruno", "ana", "bruno"),
  verdict = c("positive", "negative", "positive", "uncertain"),
  time = "2026-01-15T20:00:00-0300"
), f, row.names = FALSE)
# The verdicts of one reviewer
v <- app_verdicts(man, f, reviewer = "ana")
#> Clips in the review queue: 12
#>   not_reviewed: 10
#>   positive: 2
table(v$verdict)
#> 
#> not_reviewed     positive 
#>           10            2 
# Every reviewer: one row per clip and reviewer
v_all <- app_verdicts(man, f)
#> Clips in the review queue: 12
#>   negative: 1
#>   not_reviewed: 9
#>   positive: 2
#>   uncertain: 1
v_all[!is.na(v_all$reviewer), c("clip_file", "reviewer", "verdict")]
#> # A tibble: 4 × 3
#>   clip_file                                       reviewer verdict  
#>   <chr>                                           <chr>    <chr>    
#> 1 0.913_1_ARA01_20220110_000000_114.0s_117.0s.wav ana      positive 
#> 2 0.913_1_ARA01_20220110_000000_114.0s_117.0s.wav bruno    negative 
#> 3 0.789_1_ARA01_20220110_013000_135.0s_138.0s.wav ana      positive 
#> 4 0.938_2_ARA01_20220110_013000_159.0s_162.0s.wav bruno    uncertain
```
