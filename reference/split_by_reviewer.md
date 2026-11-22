# Copy each reviewer's clips to their own folder

Copies the cut clips of a manifest with reviewers
([`assign_reviewers()`](https://provetelab.org/sheepdog/reference/assign_reviewers.md))
to `<output_dir>/<reviewer>/<species_folder>/`, one folder tree per
reviewer, ready for the review tab of the BirdNET GUI. Clips with a
second reviewer are copied to both folders. After the review, classify
each reviewer's folder with
[`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md).

## Usage

``` r
split_by_reviewer(manifest, clips_dir, output_dir)
```

## Arguments

- manifest:

  A data frame (or tibble) returned by
  [`assign_reviewers()`](https://provetelab.org/sheepdog/reference/assign_reviewers.md),
  with columns `reviewer`, `second_reviewer`, `species_folder` and
  `clip_file`.

- clips_dir:

  Character scalar, path to the folder of the cut clips (the `clips`
  folder written by
  [`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md)).

- output_dir:

  Character scalar, path to the output folder.

## Value

A tibble with `reviewer`, `species_folder`, `clip_file` and `to`,
invisibly.

## Examples

``` r
man <- read.csv(system.file("extdata", "clip_manifest.csv",
                            package = "sheepdog"))
man <- assign_reviewers(man, c("ana", "bruno"), overlap = 0.25)
# Empty files stand in for the clips cut by cut_clips()
clips_dir <- file.path(tempdir(), "clips")
dir.create(file.path(clips_dir, unique(man$species_folder)),
           recursive = TRUE, showWarnings = FALSE)
invisible(file.create(file.path(clips_dir, man$species_folder,
                                man$clip_file)))
copies <- split_by_reviewer(man, clips_dir,
                            file.path(tempdir(), "by_reviewer"))
#> 15 clips copied to 2 reviewer folders in /tmp/Rtmpgb1liF/by_reviewer
table(copies$reviewer)
#> 
#>   ana bruno 
#>     8     7 
```
