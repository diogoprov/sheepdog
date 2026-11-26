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

  `NULL` or a character scalar, path to the folder with the reviewed
  clips. For a review in the BirdNET GUI, the `clips` folder after the
  review, whose subfolders give the verdicts. With `verdicts_file`,
  optional: the folder of the clips, used to fill `reviewed_path`
  (needed by
  [`retraining_clips()`](https://provetelab.org/sheepdog/reference/retraining_clips.md)
  and
  [`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md)).

- manifest_path:

  Character scalar, path to the manifest of the same run as the reviewed
  clips (`clip_manifest.csv`, or a v1.2.0 `manifesto_clipes.csv`).

- output_dir:

  Character scalar, path to the output folder; created if needed.

- positive_pattern, negative_pattern:

  Character scalars, regular expressions (case-insensitive) that
  identify the positive and negative folders in the path of each clip.

- bins:

  Numeric vector of length \>= 2, increasing breaks of the confidence
  bins (left-closed).

- target_precision:

  Numeric scalar in (0, 1). Target precision.

- min_n:

  Integer scalar \>= 1. Minimum of reviewed clips for a bin to be taken
  seriously; bins with fewer are flagged in `low_support`.

- verdicts_file:

  `NULL` or a character scalar, path to the verdicts file written by
  [`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md),
  used instead of the subfolders of `review_dir`.

- reviewer:

  `NULL` or a character vector of reviewer names. With `verdicts_file`,
  the reviewer(s) whose verdicts are used, as in
  [`app_verdicts()`](https://provetelab.org/sheepdog/reference/app_verdicts.md).

- weighted, sustained:

  `NULL`, `TRUE` or `FALSE` (`weighted`) and logical scalar
  (`sustained`). Passed to
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md).

- previous:

  `NULL`, a character vector of paths, a data frame, or a list of data
  frames. For a later round of a design: the `validation_by_clip.csv` of
  the earlier rounds. `validation_by_clip.csv` keeps the clips of this
  round only; the summaries and `validation_combined.csv` cover all
  rounds, from
  [`combine_rounds()`](https://provetelab.org/sheepdog/reference/combine_rounds.md).

- candidates:

  `NULL`, a data frame, or a character scalar path. With `previous`, the
  `candidates.csv` of the first round. `NULL` looks for it beside
  `manifest_path` and `previous`.

- fit:

  `NULL` or a model returned by
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
  (`glm`, `glmerMod` or `brmsfit`). With it,
  [`compare_thresholds()`](https://provetelab.org/sheepdog/reference/compare_thresholds.md)
  writes `thresholds_compared.csv`.

- scored, quality:

  `NULL` or data frames (or tibbles). With `fit`, passed to
  [`compare_thresholds()`](https://provetelab.org/sheepdog/reference/compare_thresholds.md).

## Value

A named list (class `list`) with the tables `validation`, `precision`,
`thresholds`, `presence` and `retraining` (and `compared`, with `fit`),
invisibly.

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

## Examples

``` r
# Recreate the folders left by a review in the BirdNET GUI, with empty files
man <- system.file("extdata", "clip_manifest.csv", package = "sheepdog")
done <- read.csv(system.file("extdata", "validation_by_clip.csv",
                             package = "sheepdog"))
review_dir <- file.path(tempdir(), "clips_post")
sub <- ifelse(done$verdict == "positive", "Positive",
              ifelse(done$verdict == "negative", "Negative", ""))
dest <- file.path(review_dir, done$species_folder, sub)
for (d in unique(dest)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
invisible(file.create(file.path(dest, done$clip_file)))

out_dir <- file.path(tempdir(), "post_validation")
res <- post_validation(review_dir, manifest_path = man,
                       output_dir = out_dir, min_n = 3)
#> Clips in the manifest: 12
#>   negative: 3
#>   not_reviewed: 1
#>   positive: 8
#> The manifest has inclusion_prob: the precision tables also give the precision weighted by 1 / inclusion_prob.
#> Suggested thresholds (target precision 0.9): see suggested_thresholds.csv
#> 8 positive clips listed for retraining.
#> Done! Results in /tmp/RtmpAGFSf1/post_validation
res$thresholds
#> # A tibble: 1 × 8
#>   site  species_folder threshold n_support precision_at_threshold
#>   <chr> <chr>              <dbl>     <int>                  <dbl>
#> 1 ARA   boa_ran              0.7         6                      1
#> # ℹ 3 more variables: precision_weighted_at_threshold <dbl>, n_eff <dbl>,
#> #   precision_used <chr>
list.files(out_dir)
#> [1] "nightly_presence.csv"     "precision_by_bin.csv"    
#> [3] "precision_by_bin.png"     "retraining_clips.csv"    
#> [5] "suggested_thresholds.csv" "validation_by_clip.csv"  
unlink(c(review_dir, out_dir), recursive = TRUE)
```
