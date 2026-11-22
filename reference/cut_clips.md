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

A data frame of the class of `manifest` (`data.frame`, or `tbl_df` for a
tibble): the manifest with the column `status` after `begin_path`: one
of `"ok"`, `"already_exists"`, `"audio_not_found"`, `"simulated"` or
`"error: <message>"`.

## Details

Cutting uses the 'ffmpeg' library bundled with the 'av' package.

## Examples

``` r
# A 5-s silent recording (16-bit PCM WAV), written with base R
wav <- file.path(tempdir(), "S01_20220110_190000.wav")
n <- 5 * 8000
con <- file(wav, "wb")
writeChar("RIFF", con, eos = NULL)
writeBin(as.integer(36 + 2 * n), con, size = 4, endian = "little")
writeChar("WAVEfmt ", con, eos = NULL)
writeBin(16L, con, size = 4, endian = "little")
writeBin(c(1L, 1L), con, size = 2, endian = "little")
writeBin(c(8000L, 16000L), con, size = 4, endian = "little")
writeBin(c(2L, 16L), con, size = 2, endian = "little")
writeChar("data", con, eos = NULL)
writeBin(as.integer(2 * n), con, size = 4, endian = "little")
writeBin(integer(n), con, size = 2, endian = "little")
close(con)
man <- data.frame(species_folder = "boa_ran",
                  clip_file = c("clip1.wav", "clip2.wav"),
                  clip_start = c(0, 2), duration = 3,
                  source_audio = wav, begin_path = wav)
out <- file.path(tempdir(), "validation")
# Check the manifest without cutting
cut_clips(man, out, simulate = TRUE)$status
#> Simulating the cut of 2 clips...
#>   simulated: 2
#> [1] "simulated" "simulated"
# Cut the clips (needs the 'av' package)
if (requireNamespace("av", quietly = TRUE)) {
  man <- cut_clips(man, out)
  print(man$status)
  list.files(file.path(out, "clips"), recursive = TRUE)
}
```
