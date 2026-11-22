# Cut the selected clips

Cuts each clip of the manifest from its source recording into
`<output_dir>/clips/<species_folder>/<clip_file>`, one folder per
species, ready for the review tab of the BirdNET GUI. Clips that already
exist are not cut again, so an interrupted run resumes where it stopped.
Missing or unreadable recordings do not stop the run; they are flagged
in `status`.

## Usage

``` r
cut_clips(manifest, output_dir, simulate = FALSE)
```

## Arguments

- manifest:

  A data frame, the clip manifest (one row per clip), as returned by
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md).

- output_dir:

  Character scalar, path to the output folder; created if needed.

- simulate:

  Logical scalar. If `TRUE`, no audio is cut (the empty species folders
  are still created), but `status` tells what would be done. Useful to
  check a selection before cutting.

## Value

The manifest with the column `status` after `begin_path`: one of `"ok"`,
`"already_exists"`, `"audio_not_found"`, `"simulated"` or
`"error: <message>"`.

## Details

Cutting uses the 'ffmpeg' library bundled with the 'av' package.
