# Organising the data

sheepdog never asks for a project file or a database: it reads folders
and tables, and takes the site, the night and the hour from where the
files are and from their names. This article describes the layout it
expects, how the paths written by BirdNET are matched to the audio, and
how to build the list of all recordings that some designs need.

## Three folders

A project has three kinds of files, and each lives best in its own
folder:

    audio/                            recordings, never modified
      ARA/
        ARA01_20211001_190000.wav
        ...
      BAI/
        card1/BAI01_20211001_190000.wav
        card2/...
    birdnet/                          BirdNET output, one run per site
      ARA/BirdNET_SelectionTable.txt  a combined table per site, or
      BAI/BAI01_20211001_190000.BirdNET.selection.table.txt
                                      one table per audio file
    validation/                       what sheepdog writes
      clip_manifest.csv
      clips/<species>/...             clips to review
      ...

- **Audio.** One folder per site, with any subfolders below it (memory
  cards, dates). The site is the first folder below the root. Recordings
  are only read, never moved or renamed.
- **BirdNET output.** Run BirdNET once per site, so that the selection
  tables of each site end up in their own folder:
  [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md)
  takes the site from the name of the folder that holds the tables (the
  prefix `output_` is dropped). Both the combined table and the
  per-audio tables of the BirdNET GUI are read.
- **Several sites in one folder.** When the recordings or the tables of
  several sites sit in the same folder, give `site_pattern`, a regular
  expression with the site in parentheses, to
  [`list_recordings()`](https://provetelab.org/sheepdog/reference/list_recordings.md),
  [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md)
  and
  [`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md):
  `"^[^_]+_([^_]+)_"` reads `Campus01` from
  `Campinas_Campus01_20261003_074339.flac`. The site then comes from the
  file name instead of the folder.
- **sheepdog outputs.** Clips, manifests, verdicts and calibration
  outputs go to a separate folder, so that a rerun never touches the
  audio or the BirdNET output.

The site names must be the same in the three places: the folder names of
the audio and of the BirdNET output, and later the `site` column of
every table.

## File names

The night and the hour come from the name of each recording, which must
carry the date and time as `YYYYMMDD_HHMMSS`, as most recorders
(AudioMoth, Song Meter and others) write them:
`ARA01_20211001_190000.wav` was recorded on 1 October 2021 at 19:00. In
the calibration, recordings that start before `dawn_hour` belong to the
night before. Do not rename the recordings after running BirdNET: the
selection tables keep the original path.

## Paths written by BirdNET

Every selection table has a `Begin Path` column with the full path of
the audio file as BirdNET saw it, for example
`N:\pam\audio\ARA\ARA01_...wav` on the Windows computer that ran the
analysis. sheepdog uses that path to cut the clips and to match the
predictions to the list of recordings. When the audio is reached by
another path (another computer, a drive mounted elsewhere), pass the old
and the new prefix to `remap_from` and `remap_to`:

``` r

man <- select_clips(pred, "random_detections", threshold = 0.5,
                    remap_from = "N:/pam/audio/",
                    remap_to = "/Volumes/NAS/pam/audio/")
```

Backslashes are turned into forward slashes before the prefix is
replaced.

## The list of all recordings

`"random_recordings"` in
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
the occasions of
[`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
and the sampling tab of
[`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md) need
the list of every recording made, including the ones in which BirdNET
predicted nothing. Without it, those functions list the audio files of
the folders that appear in `Begin Path`, which leaves out any folder
without a single prediction.
[`list_recordings()`](https://provetelab.org/sheepdog/reference/list_recordings.md)
builds the list from the audio folders instead. Here on a small
simulated tree:

``` r

library(sheepdog)

audio <- file.path(tempdir(), "audio")
for (s in c("ARA", "BAI/card1")) dir.create(file.path(audio, s),
                                            recursive = TRUE)
invisible(file.create(
  file.path(audio, "ARA", c("ARA01_20211001_190000.wav",
                            "ARA01_20211001_200000.wav")),
  file.path(audio, "BAI", "card1", "BAI01_20211001_190000.wav")))

rec <- list_recordings(audio)
#> 3 recordings listed at 2 site(s).
rec
#> # A tibble: 3 × 2
#>   site  source_audio                                             
#>   <chr> <chr>                                                    
#> 1 ARA   /tmp/RtmpaD1RUo/audio/ARA/ARA01_20211001_190000.wav      
#> 2 ARA   /tmp/RtmpaD1RUo/audio/ARA/ARA01_20211001_200000.wav      
#> 3 BAI   /tmp/RtmpaD1RUo/audio/BAI/card1/BAI01_20211001_190000.wav
```

The paths must match `Begin Path`. When the list is built on a computer
other than the one that ran BirdNET, rewrite the prefix with
`remap_from` and `remap_to`, and give the predictions to check the
match; the message says how many of their audio files are in the list:

``` r

pred <- read_selection_tables("birdnet")
rec <- list_recordings("/Volumes/NAS/pam/audio",
                       remap_from = "/Volumes/NAS/pam/audio/",
                       remap_to = "N:/pam/audio/",
                       predictions = pred,
                       file = "validation/recordings.csv")
```

The alternative is to keep the local paths in the list and pass the same
`remap_from` and `remap_to` to
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
which then rewrites `Begin Path` to the local prefix. Either way, the
CSV written with `file` can be given as `recordings` to
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
[`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
and [`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md).

## Where each function looks

| step | function | reads | writes |
|----|----|----|----|
| read predictions | [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md) | `birdnet/<site>/` | a table in R |
| list recordings | [`list_recordings()`](https://provetelab.org/sheepdog/reference/list_recordings.md) | `audio/<site>/` | `recordings.csv` |
| choose clips | [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md) | predictions, recordings | a manifest in R |
| cut clips | [`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md), [`extract_validation_clips()`](https://provetelab.org/sheepdog/reference/extract_validation_clips.md) | the audio, through `Begin Path` | `clips/<species>/`, `clip_manifest.csv` |
| review | file manager (`Positive`/`Negative` subfolders) or [`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md) | clips, manifest | folders, or a verdicts CSV |
| join verdicts | [`post_validation()`](https://provetelab.org/sheepdog/reference/post_validation.md) | review folder or `verdicts.csv`, manifest | `validation_by_clip.csv` and summaries |
| calibrate | [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md) | `validation_by_clip.csv`, selection tables | calibration outputs, detection histories |

See
[`vignette("sheepdog")`](https://provetelab.org/sheepdog/articles/sheepdog.md)
for the whole pipeline on the example data and
[`vignette("frognet-workflow")`](https://provetelab.org/sheepdog/articles/frognet-workflow.md)
for a project with a network drive mapped as `N:`.
