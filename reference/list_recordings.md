# List every recording made, from the audio folders

Builds the table of all recordings that `"random_recordings"` in
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
[`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
and [`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md)
take as `recordings`, by listing the audio files under `audio_dir`.
Unlike the list that those functions build when `recordings = NULL`, it
includes the recordings of folders without any prediction, which the
multiple-method design and the occasions of the occupancy models need.

## Usage

``` r
list_recordings(
  audio_dir,
  audio_pattern = "\\.(wav|flac|mp3)$",
  site = NULL,
  site_pattern = NULL,
  remap_from = NULL,
  remap_to = NULL,
  predictions = NULL,
  file = NULL
)
```

## Arguments

- audio_dir:

  Root folder of the audio files, searched recursively.

- audio_pattern:

  Regular expression for the audio file names (case insensitive).

- site:

  `NULL` (the site is the first folder below `audio_dir`) or a single
  site name for every file.

- site_pattern:

  Optional regular expression with one capture group that takes the site
  from the file name, for recordings of several sites in the same
  folder. For example, `"^[^_]+_([^_]+)_"` reads `Campus01` from
  `Campinas_Campus01_20261003_074339.flac`. It replaces the folder rule
  and cannot be combined with `site`.

- remap_from, remap_to:

  Replace the prefix `remap_from` of the listed paths by `remap_to`,
  e.g. `"/Volumes/NAS/"` and `"N:/"`, so that the paths match
  `Begin Path`. Backslashes are turned into forward slashes first.

- predictions:

  Optional table of predictions from
  [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md),
  to check that its audio files are in the list.

- file:

  Optional path of a CSV file to write the table to (e.g.
  `"recordings.csv"`).

## Value

A tibble with `site` and `source_audio`, one row per recording, sorted
by site and path (invisibly when `file` is given).

## Details

The site of each recording is the first folder below `audio_dir`, so
both `audio_dir/<site>/<file>` and
`audio_dir/<site>/<card or date>/<file>` work. Files directly in
`audio_dir` need `site`.

The paths must match those in the `Begin Path` column of the selection
tables, because the recordings are matched to the predictions by path.
When the audio was analysed on another computer (for instance, from a
network drive mapped as `N:`), list the files where they are and rewrite
the prefix with `remap_from` and `remap_to`, or pass the same
`remap_from` and `remap_to` to
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
so that `Begin Path` is rewritten to the local prefix instead. With
`predictions`, the function reports how many of the audio files of the
predictions are in the list.

File names are expected to carry the date and time as `YYYYMMDD_HHMMSS`,
as most recorders write them; the files whose names do not are reported.

## See also

[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
[`vignette("organising-data")`](https://provetelab.org/sheepdog/articles/organising-data.md).

## Examples

``` r
audio <- file.path(tempdir(), "audio")
for (s in c("ARA", "BAI")) dir.create(file.path(audio, s), recursive = TRUE)
file.create(file.path(audio, "ARA", c("ARA01_20211001_190000.wav",
                                     "ARA01_20211001_200000.wav")))
#> [1] TRUE TRUE
file.create(file.path(audio, "BAI", "BAI01_20211001_190000.wav"))
#> [1] TRUE
list_recordings(audio)
#> 3 recordings listed at 2 site(s).
#> # A tibble: 3 × 2
#>   site  source_audio                                       
#>   <chr> <chr>                                              
#> 1 ARA   /tmp/Rtmp2EI2Y7/audio/ARA/ARA01_20211001_190000.wav
#> 2 ARA   /tmp/Rtmp2EI2Y7/audio/ARA/ARA01_20211001_200000.wav
#> 3 BAI   /tmp/Rtmp2EI2Y7/audio/BAI/BAI01_20211001_190000.wav
```
