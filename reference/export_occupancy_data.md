# Export the data of an occupancy model with false positives

Writes, in one folder, everything an occupancy model with false
positives needs from a passive acoustic survey: the occasions, the
classifier scores, the reviewed clips with their sampling design and,
optionally, posterior draws of a Bayesian calibration. The folder
follows the `sheepdog-occupancy` schema, version 1, described in
[`vignette("crywolf-integration")`](https://provetelab.org/sheepdog/articles/crywolf-integration.md);
the crywolf package reads it, but any software can, since every table is
a plain CSV file (the calibration draws are a Parquet file).

## Usage

``` r
export_occupancy_data(
  output_dir,
  detections,
  recordings = NULL,
  validation = NULL,
  fit = NULL,
  sites = NULL,
  occasion_unit = c("file", "minute"),
  recording_duration = NULL,
  min_confidence = 0.1,
  dawn_hour = 12,
  species = NULL,
  n_draws = 100,
  grid_step = 0.01,
  seed = 2026,
  audio_pattern = "\\.(wav|flac|mp3)$",
  remap_from = NULL,
  remap_to = NULL,
  classifier = NULL,
  overwrite = FALSE
)
```

## Arguments

- output_dir:

  Folder to write. Created if needed.

- detections:

  Predictions, as returned by
  [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md).

- recordings:

  The list of all recordings, as a data frame or the path to a CSV file
  with the columns `site` and `source_audio`, as in
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md).
  `NULL` lists the audio files in the folders of the recordings that
  have predictions, which then must be reachable (see `remap_from`).

- validation:

  Reviewed clips: paths to `validation_by_clip.csv` files (output of
  [`post_validation()`](https://provetelab.org/sheepdog/reference/post_validation.md))
  or a data frame with their columns, e.g. from
  [`read_validation_tables()`](https://provetelab.org/sheepdog/reference/read_validation_tables.md)
  or
  [`consensus_verdicts()`](https://provetelab.org/sheepdog/reference/consensus_verdicts.md).
  `NULL` writes no validation tables.

- fit:

  Optional model from
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
  with `engine = "brms"`, for `calibration_draws.parquet`.

- sites:

  Optional data frame of site covariates, with a `site` column.

- occasion_unit:

  The occasion of the occupancy model: `"file"` (a recording) or
  `"minute"`. Use the value of the clip extraction, so that the
  `occasion_id` of the reviewed clips match.

- recording_duration:

  Length of the recordings (s). Needed for minute occasions unless the
  'av' package can read the files.

- min_confidence:

  Predictions below this confidence are not written; it is also the
  lower end of the grid of the calibration draws. Use the
  `min_confidence` of the BirdNET run or higher.

- dawn_hour:

  Recordings that start before this hour belong to the night before.

- species:

  Restrict to these short species codes (the last part of
  `species_code`, e.g. `"boa-ran"`). `NULL` keeps all.

- n_draws:

  Number of posterior draws of the calibration.

- grid_step:

  Step of the grid of scores of the calibration draws.

- seed:

  Seed of the choice of draws. The global random number generator is
  left as it was.

- audio_pattern:

  Regular expression for the audio files listed when `recordings` is
  `NULL`.

- remap_from, remap_to:

  Replace the prefix `remap_from` of the `begin_path` paths by
  `remap_to`, e.g. `"N:/"` and `"/Volumes/Arara/"`. Backslashes are
  turned into forward slashes first.

- classifier:

  Optional label of the classifier, recorded in `schema.json`.

- overwrite:

  Replace an existing export in `output_dir`?

## Value

Invisibly, a list with the tables written (tibbles) and the schema (a
list).

## Tables

- `occasions.csv`: one row per occasion (a recording, or a minute of a
  recording), with or without predictions.

- `detections.csv`: one row per prediction with confidence \>=
  `min_confidence`.

- `scores.csv`: one row per occasion x species with at least one
  prediction: the highest score and the number of predictions. Occasion
  x species pairs absent from this table had no prediction \>=
  `min_confidence` (a censored score).

- `validation.csv`: the reviewed clips of the `"top"` and
  `"random_detections"` designs, with their verdict and inclusion
  probability (only when `validation` is given).

- `recordings_verified.csv`: the occasions annotated by ear in the
  `"random_recordings"` design, with the state of each occasion (only
  when `validation` holds such clips).

- `sites.csv`: one row per site, with the covariates of `sites`.

- `calibration_draws.parquet`: posterior draws of P(TP) on a grid of
  scores for each site x species with predictions (only when `fit` is
  given; needs the 'arrow' package).

- `schema.json`: name and version of the schema, the settings of the
  export, the lists of sites and species and the number of rows of each
  table.

Two checks guard against inputs that would inflate the detections:
predictions repeating the site, recording, offset and species of another
(e.g. a selection table read twice) are dropped with a warning, and a
warning is given when most occasion x species with several predictions
have the same score in all of them, a sign that one score per occasion
was copied to several rows.

A clip verdict and the state of an occasion are kept apart on purpose: a
positive clip proves that the species called in its occasion, but a
negative clip only says that this prediction was a false positive (the
species may still have called, with a lower score). A recording
annotated by ear gives the state of the whole occasion.

## See also

[`vignette("crywolf-integration")`](https://provetelab.org/sheepdog/articles/crywolf-integration.md)
for the columns of each table.
