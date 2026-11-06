# Summarise the manual validation

Runs the whole post-validation step: reads the verdicts of the reviewed
clips and writes, to `output_dir`:

- `validation_by_clip.csv`: manifest + verdict of each clip
  ([`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md)
  for a review in the BirdNET GUI,
  [`app_verdicts()`](https://provetelab.org/sheepdog/reference/app_verdicts.md)
  for a review in
  [`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md));

- `precision_by_bin.csv`: precision by species x confidence bin
  ([`precision_by_bin()`](https://provetelab.org/sheepdog/reference/precision_by_bin.md));

- `suggested_thresholds.csv`: lowest confidence reaching the target
  precision, by species
  ([`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md));

- `nightly_presence.csv`: confirmed presence by site x species x night
  ([`nightly_presence()`](https://provetelab.org/sheepdog/reference/nightly_presence.md));

- `retraining_clips.csv`: positive clips for retraining
  ([`retraining_clips()`](https://provetelab.org/sheepdog/reference/retraining_clips.md));

- `thresholds_compared.csv`: empirical and model thresholds, with `fit`
  ([`compare_thresholds()`](https://provetelab.org/sheepdog/reference/compare_thresholds.md));

- `precision_by_bin.png`: precision curves
  ([`plot_precision()`](https://provetelab.org/sheepdog/reference/plot_precision.md)),
  when 'ggplot2' is installed.

## Usage

``` r
post_validation(
  review_dir = NULL,
  manifest_path,
  output_dir,
  positive_pattern = "positiv",
  negative_pattern = "negativ",
  bins = seq(0.1, 1, by = 0.1),
  target_precision = 0.9,
  min_n = 15,
  verdicts_file = NULL,
  reviewer = NULL,
  weighted = NULL,
  previous = NULL,
  candidates = NULL,
  fit = NULL,
  scored = NULL,
  quality = NULL,
  sustained = FALSE
)
```

## Arguments

- review_dir:

  Folder with the reviewed clips. For a review in the BirdNET GUI, the
  `clips` folder after the review, whose subfolders give the verdicts.
  With `verdicts_file`, optional: the folder of the clips, used to fill
  `reviewed_path` (needed by
  [`retraining_clips()`](https://provetelab.org/sheepdog/reference/retraining_clips.md)
  and
  [`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md)).

- manifest_path:

  Path to the manifest of the same run as the reviewed clips
  (`clip_manifest.csv`, or a v1.2.0 `manifesto_clipes.csv`).

- output_dir:

  Output folder; created if needed.

- positive_pattern, negative_pattern:

  Regular expressions (case-insensitive) that identify the positive and
  negative folders in the path of each clip.

- bins:

  Breaks of the confidence bins (left-closed).

- target_precision:

  Target precision.

- min_n:

  Minimum of reviewed clips for a bin to be taken seriously; bins with
  fewer are flagged in `low_support`.

- verdicts_file:

  Optional verdicts file written by
  [`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md),
  used instead of the subfolders of `review_dir`.

- reviewer:

  With `verdicts_file`, optional reviewer(s) whose verdicts are used, as
  in
  [`app_verdicts()`](https://provetelab.org/sheepdog/reference/app_verdicts.md).

- weighted, sustained:

  Passed to
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md).

- previous:

  For a later round of a design: the `validation_by_clip.csv` of the
  earlier rounds. `validation_by_clip.csv` keeps the clips of this round
  only; the summaries and `validation_combined.csv` cover all rounds,
  from
  [`combine_rounds()`](https://provetelab.org/sheepdog/reference/combine_rounds.md).

- candidates:

  With `previous`, the `candidates.csv` of the first round. `NULL` looks
  for it beside `manifest_path` and `previous`.

- fit:

  Optional model of
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md).
  With it,
  [`compare_thresholds()`](https://provetelab.org/sheepdog/reference/compare_thresholds.md)
  writes `thresholds_compared.csv`.

- scored, quality:

  With `fit`, passed to
  [`compare_thresholds()`](https://provetelab.org/sheepdog/reference/compare_thresholds.md).

## Value

A list with the tables `validation`, `precision`, `thresholds`,
`presence` and `retraining` (and `compared`, with `fit`), invisibly.

## Details

The verdicts come from the folders of a review in the BirdNET GUI
(`review_dir`) or from the verdicts file of
[`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md)
(`verdicts_file`). In the second case, a clip marked more than once
keeps the last verdict of each reviewer, and clips reviewed by more than
one reviewer are combined with
[`consensus_verdicts()`](https://provetelab.org/sheepdog/reference/consensus_verdicts.md):
conflicting verdicts become `"disagreement"` and, like `"uncertain"`,
are left out of the precision and the thresholds.

With `inclusion_prob` in the manifest (clips of `"random_detections"`),
the precision tables also give the precision weighted by
`1 / inclusion_prob` (see
[`precision_by_bin()`](https://provetelab.org/sheepdog/reference/precision_by_bin.md)),
and that precision chooses the thresholds, unless `weighted = FALSE`;
see
[`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md).

This is the function form of the v1.2.0 script `pos_validacao.R`.
