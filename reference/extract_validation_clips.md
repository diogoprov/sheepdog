# Build the validation clip set

Runs the whole first stage: reads the selection tables, selects the
clips, cuts them, writes `clip_manifest.csv` and zips one package per
species. This is the function form of the v1.2.0 script
`extrair_clipes_validacao.R`.

## Usage

``` r
extract_validation_clips(
  data_dir,
  output_dir,
  ...,
  table_pattern = "^BirdNET_SelectionTable\\.txt$",
  per_audio_pattern = "\\.BirdNET\\.selection\\.table\\.txt$",
  site_pattern = NULL,
  make_zip = TRUE,
  simulate = FALSE,
  classifier = NULL
)
```

## Arguments

- data_dir:

  Root folder, searched recursively.

- output_dir:

  Output folder; created if needed.

- ...:

  Sampling design, passed to
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
  (e.g. `sampling_mode`, `n_top`, `threshold`, `target_total`,
  `remap_from`, `remap_to`, and `previous` for a further round, in a new
  `output_dir`).

- table_pattern:

  Regular expression for the file names of combined tables.

- per_audio_pattern:

  Regular expression for the file names of per-audio tables. `NULL`
  reads only combined tables.

- site_pattern:

  Optional regular expression with one capture group that takes the site
  from the name of the audio file in `Begin Path`, instead of from the
  folder of the table. For example, `"^[^_]+_([^_]+)_"` reads `Campus01`
  from `Campinas_Campus01_20261003_074339.flac`. Use the same pattern in
  [`list_recordings()`](https://provetelab.org/sheepdog/reference/list_recordings.md).

- make_zip:

  Zip one package per species (skipped when `simulate` is `TRUE`).

- simulate:

  If `TRUE`, no audio is cut (the empty species folders are still
  created), but `status` tells what would be done. Useful to check a
  selection before cutting.

- classifier:

  Label of the classifier that produced the selection tables (e.g.
  `"FrogNet v2, BirdNET-Analyzer 2.4.0"`), recorded in
  `extraction_info.csv`. `NULL` records `NA`.

## Value

The manifest written to `clip_manifest.csv`, invisibly.

## Details

Output structure:

    <output_dir>/clips/<species_folder>/*.wav
    <output_dir>/packages/<species_folder>.zip
    <output_dir>/clip_manifest.csv
    <output_dir>/extraction_info.csv
    <output_dir>/candidates.csv

`extraction_info.csv` records the provenance of the run (one `key`,
`value` row per item): the date, the versions of sheepdog and R, the
folder of the selection tables, the `classifier` label and every
argument passed to
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md).
Keep it with the manifest: it tells later rounds which classifier
produced the clips (for instance, to leave out of a validation round the
clips used to retrain that classifier).

`candidates.csv` (`"random_detections"`) lists the candidate occasions
with their stratum: later rounds draw from it and
[`combine_rounds()`](https://provetelab.org/sheepdog/reference/combine_rounds.md)
reads it, so keep it with the manifest.

## Examples

``` r
if (FALSE) { # \dontrun{
# Check the selection first, then cut
extract_validation_clips("N:/Arara", "N:/Arara/validation",
                         remap_from = "N:/", remap_to = "/Volumes/Arara/",
                         simulate = TRUE)
} # }
```
