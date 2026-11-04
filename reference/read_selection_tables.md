# Read BirdNET selection tables

Finds the BirdNET selection tables (Raven format, tab-separated) under
`data_dir`, reads them and stacks them in one table. The site is the
name of the folder that contains the tables. The `output_` prefix of
BirdNET output folders is removed, so `output_UEM/` becomes site `UEM`.

## Usage

``` r
read_selection_tables(
  data_dir,
  table_pattern = "^BirdNET_SelectionTable\\.txt$",
  per_audio_pattern = "\\.BirdNET\\.selection\\.table\\.txt$",
  site_pattern = NULL
)
```

## Arguments

- data_dir:

  Root folder, searched recursively.

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

## Value

A tibble with one row per prediction, the column `site` first, followed
by the standardised table columns. The columns `begin_time`, `end_time`,
`species_code`, `confidence`, `begin_path` and `file_offset` are
required.

## Details

The BirdNET GUI writes the Raven selection tables in one of two ways,
and both are read:

- **combined**: one `BirdNET_SelectionTable.txt` per site folder,
  written when "Combine selection tables" is checked in the output
  settings (result type "Raven selection table");

- **one table per audio file** (the default of the GUI), named
  `<audio file>.BirdNET.selection.table.txt`. The tables of a folder are
  stacked in the order of their file names, and the `Selection` column
  is renumbered from 1, as in the combined table. The tables have the
  same columns as the combined one; in them, `Begin Time (s)` counts
  from the start of the audio file, like `File Offset (s)`, which is the
  column sheepdog uses to place a detection.

Run BirdNET once per site, so that the tables of each site end up in
their own folder: per-audio tables in subfolders of a site folder would
be read as separate sites. A folder that holds a combined table is read
from it alone, and its per-audio tables are ignored, with a message.
When the tables of several sites share a folder, `site_pattern` takes
the site from the name of the audio file of each prediction
(`Begin Path`) instead.

Column names are standardised to lower case without units or
punctuation, e.g. `Begin Time (s)` becomes `begin_time` and
`File Offset (s)` becomes `file_offset`.
