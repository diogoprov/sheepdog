# Leave the training clips out of a manifest

Drops from a clip manifest the clips that share data with the clips used
to train the classifier (the `training_set.csv` written by
[`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md),
or the table of
[`training_nights()`](https://provetelab.org/sheepdog/reference/training_nights.md)).
Use it before reviewing the detections of a retrained classifier: scores
of the clips it was trained on are biased upwards.

## Usage

``` r
exclude_training_clips(
  manifest,
  training_set,
  level = c("clip", "recording", "night"),
  any_species = FALSE,
  pattern = NULL
)
```

## Arguments

- manifest:

  A data frame, the clip manifest (one row per clip), as returned by
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
  or read from `clip_manifest.csv`.

- training_set:

  A data frame returned by
  [`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md)
  or
  [`training_nights()`](https://provetelab.org/sheepdog/reference/training_nights.md),
  or a character scalar, path to a `training_set.csv`.

- level:

  Character scalar, one of `"clip"`, `"recording"` or `"night"`: what a
  training clip excludes; see Levels.

- any_species:

  Logical scalar. If `TRUE`, exclude across species.

- pattern:

  `NULL` or character scalar. With a table of
  [`training_nights()`](https://provetelab.org/sheepdog/reference/training_nights.md)
  and `level = "recording"`, the regular expression that reads the
  recordings from `source_audio`. By default, the one recorded in the
  table by
  [`training_nights()`](https://provetelab.org/sheepdog/reference/training_nights.md)
  (lost if the table was rebuilt, e.g. by
  [`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html)),
  else the default of
  [`training_nights()`](https://provetelab.org/sheepdog/reference/training_nights.md).

## Value

The manifest without the excluded clips.

## Levels

- `"clip"`: clips that overlap in time a training clip of the same
  recording.

- `"recording"`: every clip of a recording with a training clip.

- `"night"`: every clip of a site x night with a training clip.

With `any_species = FALSE`, only clips of the same species are dropped;
with `TRUE`, a recording or night used to train one species is left out
for all of them. A table of
[`training_nights()`](https://provetelab.org/sheepdog/reference/training_nights.md)
has no species, clip times or `source_audio`: it takes
`level = "recording"` or `"night"`, always for any species. With
`"recording"`, the site, date and time are read from `source_audio` of
the manifest with `pattern`, which should be the one given to
[`training_nights()`](https://provetelab.org/sheepdog/reference/training_nights.md).

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
det <- read_selection_tables(file.path(ex, "birdnet"))
#> 4 combined table(s) and 0 per-audio table(s) found in 4 folder(s):
#>   - /home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/ARA: BirdNET_SelectionTable.txt
#>   - /home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/BAI: BirdNET_SelectionTable.txt
#>   - /home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/NHE: BirdNET_SelectionTable.txt
#>   - /home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/XAR: BirdNET_SelectionTable.txt
#> 7553 predictions read from 4 site(s).
man <- select_clips(det, sampling_mode = "top", n_top = 1)
#> Sampling mode: top (occasion = file).
#> 2298 clips selected (top 1 per site x species x night x hour) of 8 species.

# nights whose recordings were used to train the classifier, read from the
# names of its training clips
trained <- training_nights(c("ARA01_20211016_190000_3.0s_6.0s.wav",
                             "BAI01_20211020_220000_9.0s_12.0s.wav"))
man2 <- exclude_training_clips(man, trained, level = "night")
#> A table of training_nights() has no species: clips of every species are excluded.
#> 12 clip(s) sharing a night with the training clips left out of the manifest.
nrow(man) - nrow(man2)
#> [1] 12
```
