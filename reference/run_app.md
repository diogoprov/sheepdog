# Review the clips in a local app

Opens a 'shiny' app, in the browser, to review the clips of a manifest
one at a time: the spectrogram and a player for each clip, its site,
night, hour, score and design, and buttons to mark it positive, negative
or uncertain. Each verdict is written at once to `verdicts_file`, so an
interrupted session loses nothing and can be resumed. The app replaces
moving the clips into `Positive` and `Negative` folders in the BirdNET
GUI;
[`app_verdicts()`](https://provetelab.org/sheepdog/reference/app_verdicts.md)
turns `verdicts_file` into the table that
[`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md)
returns.

## Usage

``` r
run_app(
  manifest,
  clips_dir,
  verdicts_file = NULL,
  reviewer = NULL,
  max_freq = NULL,
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

- clips_dir:

  Folder of the cut clips, with one subfolder per species
  (`<clips_dir>/<species_folder>/<clip_file>`, as written by
  [`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md)).

- verdicts_file:

  CSV where the verdicts are written. By default, `verdicts.csv` next to
  `manifest` when it is a path.

- reviewer:

  Name of the reviewer, written with each verdict. With a manifest from
  [`assign_reviewers()`](https://provetelab.org/sheepdog/reference/assign_reviewers.md),
  only the clips assigned to this reviewer (as first or second reviewer)
  are shown.

- max_freq:

  Optional upper limit of the spectrogram, in kHz (e.g. `8` for most
  anuran calls). The whole band by default.

- launch.browser:

  Open the app in the browser? Passed to `shiny::runApp()`.

- ...:

  Further arguments to `shiny::runApp()`, e.g. `port`.

## Value

Called for its side effect; returns when the app is closed.

## Details

The app runs on the reviewer's computer and reads the clips from disk;
nothing is uploaded.

## Keyboard

`p` positive, `n` negative, `u` uncertain, right arrow or space next
clip, left arrow previous clip.

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
run_app("validation/clip_manifest.csv", "validation/clips",
        reviewer = "liliana")
} # }
```
