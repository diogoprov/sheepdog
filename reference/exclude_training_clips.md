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

  Clip manifest, as returned by
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
  or read from `clip_manifest.csv`.

- training_set:

  Table returned by
  [`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md)
  or
  [`training_nights()`](https://provetelab.org/sheepdog/reference/training_nights.md),
  or the path to a `training_set.csv`.

- level:

  What a training clip excludes; see Levels.

- any_species:

  Exclude across species?

- pattern:

  With a table of
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
