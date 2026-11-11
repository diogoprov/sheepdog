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

  Clip manifest: a data frame or the path to `clip_manifest.csv` (from
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
  [`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md)
  or
  [`assign_reviewers()`](https://provetelab.org/sheepdog/reference/assign_reviewers.md)).
  With `output_dir`, by default `<output_dir>/clip_manifest.csv` when it
  exists.

- verdicts_file:

  CSV written by
  [`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md).

- clips_dir:

  Optional folder of the clips, to fill `reviewed_path` (needed by
  [`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md)).

- reviewer:

  Optional reviewer: only their verdicts are used. With `NULL`, every
  reviewer's verdicts are kept, one row per clip and reviewer, ready for
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
