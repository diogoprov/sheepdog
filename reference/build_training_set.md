# Build the training folders for BirdNET-Analyzer

Splits the reviewed clips into a training and a test set and copies them
into the folder layout that the training script of BirdNET-Analyzer
expects: one folder per class, named after the label (`species_code`, so
the retrained classifier keeps the labels of the current one), with the
negatives of a class in a folder with the same name prefixed by `-`. The
test clips go to a separate `test` folder, to be passed as
`--test_data`.

## Usage

``` r
build_training_set(
  validation,
  output_dir,
  split = c("site", "night", "site_species_night", "none"),
  test_sites = NULL,
  test_prop = 0.2,
  seed = 2026,
  max_per_site_species = NULL,
  exclude_from_test = NULL,
  negatives = TRUE,
  min_files = 100,
  copy = TRUE,
  remap_from = NULL,
  remap_to = NULL,
  strict = FALSE
)
```

## Arguments

- validation:

  Reviewed clips, as returned by
  [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md),
  [`post_validation()`](https://provetelab.org/sheepdog/reference/post_validation.md)
  (`$validation`) or
  [`read_validation_tables()`](https://provetelab.org/sheepdog/reference/read_validation_tables.md).
  It needs `site`, `species_code`, `clip_file`, `verdict` and
  `reviewed_path` (the path where the review left each clip), and
  `night` for the splits by night.

- output_dir:

  Output folder; `train/` and, if any clip is held out, `test/` are
  created in it.

- split:

  How to split the clips into training and test sets; see Splits.

- test_sites:

  Sites held out for testing with `split = "site"`. `NULL` puts every
  clip in `train/`.

- test_prop:

  Proportion of the nights of each site (or site x species) drawn for
  the test set.

- seed:

  Seed of the draws.

- max_per_site_species:

  Optional maximum number of positive training clips per site x species.
  Larger sets are reduced by taking clips from the nights in turn, in
  random order, which keeps as many nights as possible. Test clips and
  negatives are not reduced.

- exclude_from_test:

  Optional table with `site` and `night` (e.g. from
  [`training_nights()`](https://provetelab.org/sheepdog/reference/training_nights.md)):
  nights that must not be in the test set, such as nights whose
  recordings trained another classifier that will be compared on it.
  They are left out of the draw and stay in the training set.

- negatives:

  Include the negative clips, in `-<species_code>` folders.

- min_files:

  Minimum number of positive training files per class below which a
  warning is raised.

- copy:

  Copy the clips? With `FALSE`, only `training_set.csv` is written, so
  that the split can be built on a computer without the clips and copied
  later.

- remap_from, remap_to:

  Optional prefix of `reviewed_path` and its replacement, for clips
  reviewed on another computer or drive.

- strict:

  Raise an error if any check is above 0?

## Value

A tibble with one row per clip: `site`, `species_code`, `verdict`, `set`
(`"train"` or `"test"`), `class_folder`, `clip_file`, `source_audio`,
`clip_start`, `clip_end`, `from`, `to` and `night`, invisibly, with the
checks in the attribute `"checks"`. With `copy = TRUE`, clips that could
not be copied are left out.

## Details

The layout follows the documentation of BirdNET-Analyzer (version 2.4.0,
`birdnet_analyzer.train`), which also recommends at least 100 files per
species; classes below `min_files` in the training set raise a warning.
Whole-recording clips of `"random_recordings"` (longer than 3 s,
`confidence` = `NA`) are left out: their label says only that the
species was heard somewhere in the recording.

The table of clips is also written to `training_set.csv` in
`output_dir`; keep it with the classifier, to leave these clips out of
later validation rounds with
[`exclude_training_clips()`](https://provetelab.org/sheepdog/reference/exclude_training_clips.md).

## Splits

Clips of the same night are correlated, so a split by clip leaks
information from the training into the test set.

- `"site"`: the clips of `test_sites` form the test set, which then
  measures transfer to sites the classifier was not trained on.

- `"night"`: in each site, `ceiling(n * test_prop)` of its `n` nights
  are drawn for the test set, for all species together, so that no
  recording is training data for one species and test data for another.

- `"site_species_night"`: the nights are drawn within each site x
  species with at least two nights (the split of the 2.x scripts of the
  FrogNet project). The same night can then be in the training set for
  one species and in the test set for another, which breaks the
  independence of the test set; it is kept only to reproduce earlier
  training sets, and warns.

- `"none"`: every clip goes to the training set.

The draws use `seed` (and `seed + 1` for `max_per_site_species`) and
leave the global random number generator as it was. They follow the
order of the rows of `validation`: the same clips in another order give
another split.

## Checks

At the end, three counts are reported, and kept in the attribute
`"checks"` of the result: test nights (site x night) that also have
training clips, test nights listed in `exclude_from_test`, and test
clips that overlap a training clip of the same species in the same
recording. All should be 0 with `split = "night"`. With `strict = TRUE`,
any count above 0 is an error.

## See also

[`training_nights()`](https://provetelab.org/sheepdog/reference/training_nights.md),
[`exclude_training_clips()`](https://provetelab.org/sheepdog/reference/exclude_training_clips.md),
[`vignette("retraining")`](https://provetelab.org/sheepdog/articles/retraining.md).
