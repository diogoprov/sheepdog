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
#> 1 ARA   /tmp/RtmpN4SgqH/audio/ARA/ARA01_20211001_190000.wav      
#> 2 ARA   /tmp/RtmpN4SgqH/audio/ARA/ARA01_20211001_200000.wav      
#> 3 BAI   /tmp/RtmpN4SgqH/audio/BAI/card1/BAI01_20211001_190000.wav
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

## Predictions in a pamDP data package

pamflow (Betancourt et al. 2026) standardises passive acoustic data in
pamDP, an adaptation of Camtrap DP (Bubnicki et al. 2024) with three
tables: `deployments.csv`, `media.csv` and `observations.csv`.
[`read_pamdp()`](https://provetelab.org/sheepdog/reference/read_pamdp.md)
reads such a package and returns the machine predictions in the shape of
[`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md)
and the list of recordings in the shape of
[`list_recordings()`](https://provetelab.org/sheepdog/reference/list_recordings.md).
The list comes from `media.csv`, so it includes the audio files without
any prediction:

``` r

pam <- read_pamdp("pamdp", audio_root = "/Volumes/NAS/pam/audio")
clips <- select_clips(pam$predictions, sampling_mode = "score_bands",
                      recordings = pam$recordings)
```

- **Site:** taken from `locationID` of the deployment (`site_column`
  changes it).
- **Species:** `species_code` is the scientific name followed by its
  lower-case, hyphenated form, so that `"Boana raniceps"` goes to the
  folder `boana_raniceps`.
- **Paths:** relative `filePath` values are resolved against
  `audio_root`.
- **Dates and hours:** sheepdog still reads them from the file names
  (`YYYYMMDD_HHMMSS`), not from the `timestamp` of `media.csv`.
- **Human classifications:** left out, because pamDP has no field that
  ties them to the prediction they check.
- **Which functions accept the tables:**
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
  [`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
  and
  [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md),
  and through the manifest the review app.
  [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md)
  still reads BirdNET selection tables from disk.

## Predictions of Perch, OpenSoundscape and Arbimon

[`read_classifier_output()`](https://provetelab.org/sheepdog/reference/read_classifier_output.md)
reads the prediction files of other classifiers and returns them in the
same shape:

- `format = "perch"`: the inference CSV written by
  `write_inference_csv()` of perch-hoplite or of the earlier perch
  repository, one row per window and label above the logit threshold
  chosen when it was written;
- `format = "opensoundscape"`: the table of
  [`predict()`](https://rdrr.io/r/stats/predict.html) saved with
  `to_csv()`, with `file`, `start_time`, `end_time` and one column per
  class.

``` r

pred <- read_classifier_output("perch/inference.csv", format = "perch",
                               audio_root = "/Volumes/NAS/pam/audio")
recs <- list_recordings("/Volumes/NAS/pam/audio")
clips <- select_clips(pred, sampling_mode = "score_bands",
                      recordings = recs)
```

- **Scores:** both classifiers write logits by default, and neither file
  says so. With `score_scale = "logit"` (the default), `confidence` is
  `plogis(score)`; use `score_scale = "probability"` when the model
  applied a sigmoid. The calibration works on the logit of `confidence`,
  which is then the original score. Rows below `min_confidence` (0.1)
  are left out.
- **Site:** the folder of each audio file, or `site_pattern` on its
  name.
- **Species:** built from the label as for pamDP (`"Wood Thrush"` goes
  to the folder `wood_thrush`); the label is kept in `label`.
- **Calibration:** pass the table to
  [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md).

`format = "arbimon"` reads the results of Arbimon pattern matching jobs.
The download of a job names the audio file (`recording`), the site and
the species, and is read on its own. The “export all results” files name
neither the species nor the audio file, so they also need the species in
`label` and the `recordings` table of a project backup, which holds the
original file names:

``` r

pm <- read_classifier_output("arbimon/pm-job_116143.csv", format = "arbimon",
                             label = "Boana raniceps",
                             recordings = "backup/recordings.0001.csv",
                             audio_root = "/Volumes/NAS/pam/audio")
```

The site is the Arbimon site, the score (a correlation between 0 and 1)
is used as it is, and the reviews done in Arbimon are kept in `verdict`.
The dates and hours still come from the file names, so files named by
Arbimon in another pattern need to be renamed to `YYYYMMDD_HHMMSS`.

## Where each function looks

| step | function | reads | writes |
|----|----|----|----|
| read predictions | [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md) | `birdnet/<site>/` | a table in R |
| list recordings | [`list_recordings()`](https://provetelab.org/sheepdog/reference/list_recordings.md) | `audio/<site>/` | `recordings.csv` |
| or read a pamDP package | [`read_pamdp()`](https://provetelab.org/sheepdog/reference/read_pamdp.md) | `deployments.csv`, `media.csv`, `observations.csv` | predictions and recordings in R |
| or read Perch, OpenSoundscape or Arbimon | [`read_classifier_output()`](https://provetelab.org/sheepdog/reference/read_classifier_output.md) | prediction CSVs | a table in R |
| choose clips | [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md) | predictions, recordings | a manifest in R |
| cut clips | [`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md), [`extract_validation_clips()`](https://provetelab.org/sheepdog/reference/extract_validation_clips.md) | the audio, through `Begin Path` | `clips/<species>/`, `clip_manifest.csv` |
| review | file manager (`Positive`/`Negative` subfolders) or [`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md) | clips, manifest | folders, or a verdicts CSV |
| join verdicts | [`post_validation()`](https://provetelab.org/sheepdog/reference/post_validation.md) | review folder or `verdicts.csv`, manifest | `validation_by_clip.csv` and summaries |
| calibrate | [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md) | `validation_by_clip.csv`, selection tables | calibration outputs, detection histories |

See
[`vignette("sheepdog")`](https://provetelab.org/sheepdog/articles/sheepdog.md)
for the whole pipeline on the example data and
[`vignette("diversons-workflow")`](https://provetelab.org/sheepdog/articles/diversons-workflow.md)
for a project with a network drive mapped as `N:`.

## References

Betancourt, N., Toro-Gómez, M., Cañas, J., Barona-Cortés, E., et al.
(2026). pamflow: an open-source workflow for simplified passive acoustic
monitoring data analysis. *Methods in Ecology and Evolution*.
<https://doi.org/10.1111/2041-210x.70432>

Bubnicki, J. W., Norton, B., Baskauf, S. J., Bruce, T., et al. (2024).
Camtrap DP: an open standard for the FAIR exchange and archiving of
camera trap data. *Remote Sensing in Ecology and Conservation*, 10(3),
283-295. <https://doi.org/10.1002/rse2.374>
