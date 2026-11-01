# Sample, review and export clips in a local app

Opens a 'shiny' app, in the browser, for stages 1 and 2 of the workflow.
The tabs depend on the arguments:

## Usage

``` r
run_app(
  manifest = NULL,
  clips_dir = NULL,
  verdicts_file = NULL,
  reviewer = NULL,
  max_freq = NULL,
  selection_dir = NULL,
  output_dir = NULL,
  recordings = NULL,
  classifier = NULL,
  launch.browser = interactive(),
  ...
)
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

- clips_dir:

  Folder of the cut clips, with one subfolder per species
  (`<clips_dir>/<species_folder>/<clip_file>`, as written by
  [`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md)).
  With `output_dir`, `<output_dir>/clips` by default.

- verdicts_file:

  CSV where the verdicts are written. By default, `verdicts.csv` in
  `output_dir` or next to `manifest` when it is a path.

- reviewer:

  Name of the reviewer, written with each verdict. With a manifest from
  [`assign_reviewers()`](https://provetelab.org/sheepdog/reference/assign_reviewers.md),
  only the clips assigned to this reviewer (as first or second reviewer)
  are shown.

- max_freq:

  Optional upper limit of the spectrogram, in kHz (e.g. `8` for most
  anuran calls). The whole band by default.

- selection_dir:

  Folder of the BirdNET selection tables (as in
  [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md)).
  Opens the Sampling and Export tabs.

- output_dir:

  Folder of the validation round: the clips, the manifest, the verdicts
  and the export (`<output_dir>/occupancy` by default) are written
  there.

- recordings:

  Optional table of all recordings (columns `site` and `source_audio`),
  or the path to its CSV: needed by `"random_recordings"` and, in the
  export, to keep the occasions without detections (see
  [`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)).

- classifier:

  Label of the classifier, recorded in `extraction_info.csv` and
  `schema.json`.

- launch.browser:

  Open the app in the browser? Passed to `shiny::runApp()`.

- ...:

  Further arguments to `shiny::runApp()`, e.g. `port`.

## Value

Called for its side effect; returns when the app is closed.

## Details

- **Sampling** (with `selection_dir` and `output_dir`): a form for the
  sampling design of
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md).
  *Draw* shows the clips per site and species and their inclusion
  probabilities without touching the audio; *Cut clips* cuts them with
  [`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md)
  and writes `clip_manifest.csv`, `extraction_info.csv` and `clips/` to
  `output_dir`, as
  [`extract_validation_clips()`](https://provetelab.org/sheepdog/reference/extract_validation_clips.md)
  does (without the zip packages). The new clips go straight to the
  Review tab.

- **Review**: the clips of a manifest one at a time, with the
  spectrogram and a player for each clip, its site, night, hour, score
  and design, and buttons to mark it positive, negative or uncertain.
  Each verdict is written at once to `verdicts_file`, so an interrupted
  session loses nothing and can be resumed. The tab replaces moving the
  clips into `Positive` and `Negative` folders in the BirdNET GUI;
  [`app_verdicts()`](https://provetelab.org/sheepdog/reference/app_verdicts.md)
  turns `verdicts_file` into the table that
  [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md)
  returns.

- **Export** (with `selection_dir` and `output_dir`): calls
  [`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
  with the detections of `selection_dir`, the verdicts of the Review tab
  (combined by
  [`consensus_verdicts()`](https://provetelab.org/sheepdog/reference/consensus_verdicts.md)
  when a clip has several reviewers) and, optionally, `recordings`, and
  shows the summary of `schema.json`. The score calibration is not in
  the app yet; call
  [`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
  with `fit` for it.

The app runs on the reviewer's computer and reads the clips from disk;
nothing is uploaded.

## Keyboard

In the Review tab: `p` positive, `n` negative, `u` uncertain, right
arrow or space next clip, left arrow previous clip.

## Verdicts file

A CSV with one line per click: `clip_file`, `species_folder`,
`reviewer`, `verdict` (`"positive"`, `"negative"` or `"uncertain"`) and
`time`. Lines are only appended; when a clip is marked again, the last
verdict of the reviewer counts. Several reviewers can share one file or
keep one each.

## See also

[`app_verdicts()`](https://provetelab.org/sheepdog/reference/app_verdicts.md),
`vignette("review-app")`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Review only
run_app("validation/clip_manifest.csv", "validation/clips",
        reviewer = "liliana")

# Sample, cut, review and export
run_app(selection_dir = "N:/Arara", output_dir = "validation",
        recordings = "recordings.csv", reviewer = "liliana",
        max_freq = 8)
} # }
```
