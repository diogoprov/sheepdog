# Read predictions and recordings from a pamDP data package

Reads a data package in the pamDP format of pamflow (an adaptation of
Camtrap DP to passive acoustic monitoring) and returns the machine
predictions in the shape of
[`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md)
and the list of recordings in the shape of
[`list_recordings()`](https://provetelab.org/sheepdog/reference/list_recordings.md),
so that both can go to
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
[`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
and [`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md).

## Usage

``` r
read_pamdp(dir, site_column = "locationID", audio_root = NULL)
```

## Arguments

- dir:

  Folder of the data package.

- site_column:

  Column of `deployments.csv` that names the site: `"locationID"`
  (default), `"locationName"` or `"deploymentID"`. Deployments with this
  column empty take their `deploymentID`, with a message.

- audio_root:

  Optional folder that relative `filePath` values are resolved against
  (e.g. the folder of the audio files on this computer). `NULL` keeps
  `filePath` as it is. Paths that are absolute or URLs are never
  changed.

## Value

A list with two tibbles: `predictions`, one row per prediction, with
`site` first, the columns required by
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
(`begin_time`, `end_time`, `species_code`, `confidence`, `begin_path`,
`file_offset`) and `observation_id`, `deployment_id`, `media_id`,
`scientific_name`, `classified_by`, `low_freq` and `high_freq`; and
`recordings`, one row per audio file.

## Details

A pamDP package holds three tables: `deployments.csv` (one row per
recorder deployment, with its location), `media.csv` (one row per audio
file) and `observations.csv` (one row per classified event, with the
offsets `eventStart` and `eventEnd` in seconds from the start of the
audio file). When the folder has a `datapackage.json`, the paths of the
three tables are taken from its resources (`deployments`, `media`,
`observations`); otherwise the files are looked for by those names.

**Predictions.** Observations of a classifier are kept: those with
`classificationMethod` equal to `"machine"` (or empty) and a
`classificationProbability`, of type `"animal"` when `observationType`
is given, with a `scientificName` and a `mediaID` found in `media.csv`.
Observations classified by people (`classificationMethod = "human"`) are
left out with a message: pamDP has no field that links a human
classification to the prediction it checks, so they cannot be read as
verdicts. The columns are mapped as follows:

|  |  |
|----|----|
| pamDP | sheepdog |
| `classificationProbability` | `confidence` |
| `eventStart`, `eventEnd` | `begin_time`, `end_time`; `file_offset` = `eventStart` |
| `filePath` of the media | `begin_path` |
| `frequencyLow`, `frequencyHigh` | `low_freq`, `high_freq` |
| `scientificName` | `species_code`, see below |
| `site_column` of the deployment | `site` |

sheepdog names the folder of a species after the part of `species_code`
after the last underscore, as in BirdNET labels
(`"Adenomera diptyx_ade-dip"` gives `ade_dip`). The scientific name
alone has no such part, so `species_code` is built as the scientific
name and its lower-case, hyphenated form: `"Boana raniceps"` becomes
`"Boana raniceps_boana-raniceps"`, whose folder is `boana_raniceps`.

**Recordings.** Every row of `media.csv` is a recording, including the
ones without any prediction, which the occasions of the occupancy models
and `"random_recordings"` need. The table has `site` and `source_audio`
(the same path as `begin_path`), as
[`list_recordings()`](https://provetelab.org/sheepdog/reference/list_recordings.md)
does, plus `media_id`, `deployment_id`, `timestamp` and `file_length`
(seconds).

**Dates and hours.** sheepdog takes the date and hour of a recording
from its file name (`YYYYMMDD_HHMMSS`), not from the `timestamp` of
`media.csv`. The files whose names do not carry them are reported;
rename them, or the nights and hours of the occasions will be missing.

## References

Betancourt, N., Toro-Gómez, M., Cañas, J., Barona-Cortés, E., et al.
(2026). pamflow: an open-source workflow for simplified passive acoustic
monitoring data analysis. *Methods in Ecology and Evolution*.
[doi:10.1111/2041-210x.70432](https://doi.org/10.1111/2041-210x.70432)

Bubnicki, J. W., Norton, B., Baskauf, S. J., Bruce, T., et al. (2024).
Camtrap DP: an open standard for the FAIR exchange and archiving of
camera trap data. *Remote Sensing in Ecology and Conservation*, 10(3),
283-295. [doi:10.1002/rse2.374](https://doi.org/10.1002/rse2.374)

## See also

[`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md),
[`list_recordings()`](https://provetelab.org/sheepdog/reference/list_recordings.md),
[`vignette("organising-data")`](https://provetelab.org/sheepdog/articles/organising-data.md).

## Examples

``` r
dp <- file.path(tempdir(), "pamdp")
dir.create(dp, showWarnings = FALSE)
utils::write.csv(data.frame(
  deploymentID = c("d1", "d2"), locationID = c("ARA", "BAI"),
  latitude = -20, longitude = -54,
  deploymentStart = "2021-10-01T18:00:00-04:00",
  deploymentEnd = "2021-10-02T06:00:00-04:00"),
  file.path(dp, "deployments.csv"), row.names = FALSE)
utils::write.csv(data.frame(
  mediaID = c("m1", "m2", "m3"), deploymentID = c("d1", "d1", "d2"),
  timestamp = "2021-10-01T19:00:00-04:00",
  filePath = c("ARA/ARA01_20211001_190000.wav",
               "ARA/ARA01_20211001_200000.wav",
               "BAI/BAI01_20211001_190000.wav"),
  filePublic = FALSE, fileMediatype = "audio/wav", sampleRate = 48000,
  bitDepth = 16, fileLength = 60, numChannels = 1),
  file.path(dp, "media.csv"), row.names = FALSE)
utils::write.csv(data.frame(
  observationID = c("o1", "o2", "o3"), deploymentID = c("d1", "d1", "d2"),
  mediaID = c("m1", "m1", "m3"), eventStart = c(3, 12, 30),
  eventEnd = c(6, 15, 33), observationLevel = "event",
  observationType = "animal", scientificName = "Boana raniceps",
  classificationMethod = "machine", classifiedBy = "BirdNET 2.4",
  classificationProbability = c(0.91, 0.42, 0.77)),
  file.path(dp, "observations.csv"), row.names = FALSE)
pam <- read_pamdp(dp, audio_root = "/Volumes/NAS/audio")
#> 3 predictions of 1 species read from 2 site(s); 3 recordings.
pam$predictions
#> # A tibble: 3 × 14
#>   site  begin_time end_time low_freq high_freq species_code           confidence
#>   <chr>      <dbl>    <dbl>    <dbl>     <dbl> <chr>                       <dbl>
#> 1 ARA            3        6       NA        NA Boana raniceps_boana-…       0.91
#> 2 ARA           12       15       NA        NA Boana raniceps_boana-…       0.42
#> 3 BAI           30       33       NA        NA Boana raniceps_boana-…       0.77
#> # ℹ 7 more variables: begin_path <chr>, file_offset <dbl>,
#> #   observation_id <chr>, deployment_id <chr>, media_id <chr>,
#> #   scientific_name <chr>, classified_by <chr>
pam$recordings
#> # A tibble: 3 × 6
#>   site  source_audio                media_id deployment_id timestamp file_length
#>   <chr> <chr>                       <chr>    <chr>         <chr>           <dbl>
#> 1 ARA   /Volumes/NAS/audio/ARA/ARA… m1       d1            2021-10-…          60
#> 2 ARA   /Volumes/NAS/audio/ARA/ARA… m2       d1            2021-10-…          60
#> 3 BAI   /Volumes/NAS/audio/BAI/BAI… m3       d2            2021-10-…          60
```
