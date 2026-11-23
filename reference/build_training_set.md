# Build the training folders for BirdNET-Analyzer

Splits the reviewed clips into a training and a test set and copies them
into the folder layout that the training script of BirdNET-Analyzer
expects: one folder per class, named after the label (`species_code`, so
the retrained classifier keeps the labels of the current one), with the
negatives of a class in a folder with the same name prefixed by `-` (or
all negatives in one non-event folder; see Negatives). The test clips go
to a separate `test` folder; with `val_prop`, a validation set by night
goes to `val`, to be passed as `--test_data` (see Splits).

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
  val_prop = NULL,
  val_seed = seed + 1,
  negatives = TRUE,
  negatives_folder = NULL,
  min_files = 100,
  copy = TRUE,
  remap_from = NULL,
  remap_to = NULL,
  strict = FALSE
)
```

## Arguments

- validation:

  A data frame of reviewed clips, one row per clip, as returned by
  [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md),
  [`post_validation()`](https://provetelab.org/sheepdog/reference/post_validation.md)
  (`$validation`) or
  [`read_validation_tables()`](https://provetelab.org/sheepdog/reference/read_validation_tables.md).
  It needs `site`, `species_code`, `clip_file`, `verdict` and
  `reviewed_path` (the path where the review left each clip), and
  `night` for the splits by night.

- output_dir:

  Character scalar, path to the output folder; `train/` and, if any clip
  is held out, `test/` are created in it.

- split:

  Character scalar, one of `"site"`, `"night"`, `"site_species_night"`
  or `"none"`: how to split the clips into training and test sets; see
  Splits.

- test_sites:

  `NULL` or character vector, sites held out for testing with
  `split = "site"`. `NULL` puts every clip in `train/`.

- test_prop:

  Numeric scalar in (0, 1), proportion of the nights of each site (or
  site x species) drawn for the test set.

- seed:

  Numeric scalar, seed of the draws.

- max_per_site_species:

  `NULL` or integer scalar, maximum number of positive training clips
  per site x species. Larger sets are reduced by taking clips from the
  nights in turn, in random order, which keeps as many nights as
  possible. Test clips and negatives are not reduced.

- exclude_from_test:

  `NULL` or a data frame with `site` and `night`, one row per night
  (e.g. from
  [`training_nights()`](https://provetelab.org/sheepdog/reference/training_nights.md)):
  nights that must not be in the test set, such as nights whose
  recordings trained another classifier that will be compared on it.
  They are left out of the draws of the test and validation sets and
  stay in the training set.

- val_prop:

  `NULL` or numeric scalar in (0, 1), proportion of the training nights
  of each site drawn for the validation set (`val/`); see Splits. `NULL`
  draws none.

- val_seed:

  Numeric scalar, seed of the validation draw. The default, `seed + 1`,
  is also the seed of `max_per_site_species`; the two draws are
  separate, and the default reproduces the training sets of the
  DiverSons project.

- negatives:

  Logical scalar. If `TRUE`, include the negative clips.

- negatives_folder:

  `NULL` or character scalar. `NULL` puts the negatives of each class in
  a `-<species_code>` folder. A non-event class of BirdNET-Analyzer
  (`"Noise"`, `"Other"`, `"Background"` or `"Silence"`) puts all of them
  in that folder instead; see Negatives.

- min_files:

  Numeric scalar, minimum number of positive training files per class
  below which a warning is raised.

- copy:

  Logical scalar. If `TRUE`, copy the clips; with `FALSE`, only
  `training_set.csv` is written, so that the split can be built on a
  computer without the clips and copied later.

- remap_from, remap_to:

  `NULL` or character scalars, prefix of `reviewed_path` and its
  replacement, for clips reviewed on another computer or drive.

- strict:

  Logical scalar. If `TRUE`, raise an error if any check is above 0.

## Value

A tibble with one row per clip: `site`, `species_code`, `verdict`, `set`
(`"train"`, `"val"` or `"test"`), `class_folder`, `clip_file`,
`source_audio`, `clip_start`, `clip_end`, `from`, `to` and `night`,
invisibly, with the checks in the attribute `"checks"`. With
`copy = TRUE`, clips that could not be copied are left out.

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
  DiverSons project). The same night can then be in the training set for
  one species and in the test set for another, which breaks the
  independence of the test set; it is kept only to reproduce earlier
  training sets, and warns.

- `"none"`: every clip goes to the training set.

With `val_prop`, a validation set is drawn after the test set and after
`max_per_site_species`, among the nights left in the training set: in
each site, `ceiling(n * val_prop)` of its `n` training nights, never
from `exclude_from_test`. Its clips go to `val/`. BirdNET-Analyzer draws
its own validation set by file, which leaks nights, and its autotune
chooses the hyperparameters on it; pass `val/` as `--test_data` so that
the validation is by night, and keep `test/` for the final evaluation.
The result is the same as a second call of `build_training_set()` with
`split = "night"`, `test_prop = val_prop` and `seed = val_seed` on the
training rows of the first.

The draws use `seed` (`seed + 1` for `max_per_site_species`, and
`val_seed` for the validation set) and leave the global random number
generator as it was. They follow the order of the rows of `validation`:
the same clips in another order give another split.

## Negatives

BirdNET-Analyzer (version 2.4.0 and its main branch of October 2026)
gives the label -1 to the clips of `-<species_code>` folders. That label
enters the loss functions unchanged, which makes the loss of those clips
negative and unbounded; `keras.metrics.AUC` does not count -1 as a
negative, which inflates the validation AUPRC whenever the validation
set holds such clips; and the internal random split puts all of them in
the training set. Clips of the non-event folders (`"Noise"`, `"Other"`,
`"Background"`, `"Silence"`, in any case) get the label 0 and do not
have these problems (reported in
<https://github.com/birdnet-team/BirdNET-Analyzer/issues/1033>). Until
it is fixed, use `negatives_folder = "Noise"`: every negative goes to
that folder, as `<species>-<site>-<clip_file>` (the short species code
after the last `_` of `species_code`), so that the file keeps its origin
and clips of different species do not collide. The negatives then train
the classifier against all classes, not only their own.

## Checks

At the end, the counts are reported, and kept in the attribute
`"checks"` of the result: test nights (site x night) that also have
training clips, test nights listed in `exclude_from_test`, and test
clips that overlap a training clip of the same species in the same
recording; with `val_prop`, also validation nights with training clips
and validation nights listed in `exclude_from_test`. All should be 0
with `split = "night"`. With `strict = TRUE`, any count above 0 is an
error.

## See also

[`training_nights()`](https://provetelab.org/sheepdog/reference/training_nights.md),
[`exclude_training_clips()`](https://provetelab.org/sheepdog/reference/exclude_training_clips.md),
[`vignette("retraining")`](https://provetelab.org/sheepdog/articles/retraining.md).

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validation_tables(list.files(file.path(ex, "validation"),
                                         full.names = TRUE))
# Recreate the folders of a review in the BirdNET GUI, with empty files,
# and read back where each clip is (reviewed_path)
review_dir <- file.path(tempdir(), "clips_training")
dest <- file.path(review_dir, val$species_folder,
                  ifelse(val$verdict == "positive", "Positive", "Negative"))
for (d in unique(dest)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
invisible(file.create(file.path(dest, val$clip_file)))
reviewed <- classify_review(val[, setdiff(names(val),
                                          c("verdict", "reviewed_path"))],
                            review_dir)
#> Clips in the manifest: 2467
#>   negative: 890
#>   positive: 1577

# Hold out one site for testing; copy = FALSE writes only training_set.csv
out_dir <- file.path(tempdir(), "birdnet_training")
ts <- build_training_set(reviewed, out_dir, split = "site",
                         test_sites = "NHE", min_files = 20,
                         copy = FALSE)
#> 2467 clips listed in training_set.csv (nothing copied) in /tmp/RtmpRwTikI/birdnet_training (1827 train, 640 test).
#> Checks (all should be 0 with split = "night"):
#>   test_nights_in_train: 0
#>   test_nights_excluded: 0
#>   test_clips_overlapping_train: 0
table(ts$set, ts$verdict)
#>        
#>         negative positive
#>   test       275      365
#>   train      615     1212

# Or a split by night, with all negatives in the non-event class "Noise"
ts_night <- build_training_set(reviewed, out_dir, split = "night",
                               test_prop = 0.2, negatives_folder = "Noise",
                               min_files = 20, copy = FALSE)
#> 2467 clips listed in training_set.csv (nothing copied) in /tmp/RtmpRwTikI/birdnet_training (1937 train, 530 test).
#> Checks (all should be 0 with split = "night"):
#>   test_nights_in_train: 0
#>   test_nights_excluded: 0
#>   test_clips_overlapping_train: 0
attr(ts_night, "checks")
#>         test_nights_in_train         test_nights_excluded 
#>                            0                            0 
#> test_clips_overlapping_train 
#>                            0 
unlink(c(review_dir, out_dir), recursive = TRUE)
```
