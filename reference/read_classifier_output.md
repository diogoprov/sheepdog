# Read the predictions of other classifiers

Reads the prediction files of classifiers other than BirdNET and returns
them in the shape of
[`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md),
so that they can go to
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
[`select_directed()`](https://provetelab.org/sheepdog/reference/select_directed.md),
[`threshold_history()`](https://provetelab.org/sheepdog/reference/threshold_history.md),
[`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
and
[`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md).

## Usage

``` r
read_classifier_output(
  files,
  format = c("perch", "opensoundscape", "arbimon"),
  score_scale = NULL,
  min_confidence = 0.1,
  site_pattern = NULL,
  audio_root = NULL,
  window_s = 5,
  recordings = NULL,
  label = NULL
)
```

## Arguments

- files:

  Character vector of paths to prediction files (CSV), or to folders
  searched recursively for `.csv` files.

- format:

  Character scalar, one of `"perch"`, `"opensoundscape"` or `"arbimon"`.

- score_scale:

  `NULL` or character scalar, one of `"logit"` or `"probability"`: the
  scale of the scores in the files. `NULL` takes `"logit"` for Perch and
  OpenSoundscape and `"probability"` for Arbimon.

- min_confidence:

  Numeric scalar in \[0, 1\]. Rows with a lower `confidence` are left
  out.

- site_pattern:

  `NULL` or character scalar, regular expression with one capture group
  that takes the site from the name of the audio file, as in
  [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md).
  `NULL` takes the folder of the audio file.

- audio_root:

  `NULL` or character scalar, folder that relative audio paths are
  resolved against (for Perch, the folder the embeddings were computed
  from). Absolute paths and URLs are kept as they are.

- window_s:

  Numeric scalar \> 0, length of the window in seconds, used for the
  Perch files that do not store its end.

- recordings:

  `NULL`, a data frame or a character scalar path to the `recordings`
  table of an Arbimon project backup, with the columns `recording_id`
  and `meta` (JSON with the original `filename`) or `filename`. Needed
  for the Arbimon "export all" files only.

- label:

  `NULL` or character scalar, the species of an Arbimon "export all"
  file (one job, one template). Needed for those files only.

## Value

A tibble with one row per prediction: `site`, `begin_time`, `end_time`,
`species_code`, `confidence`, `begin_path` and `file_offset` (the
columns required by
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)),
plus `label`, `score` (as in the file) and `classifier`; for Arbimon,
also `verdict`.

## Formats

**`"perch"`**: the inference CSV of Perch, written by
`write_inference_csv()` of perch-hoplite
(`perch_hoplite.agile.classifier`) or of the earlier perch repository
(`chirp.inference.classify`). One row per window and label whose logit
exceeds the threshold chosen when the file was written. Three headers
are recognised:

|  |  |
|----|----|
| Header | Writer |
| `idx,project,filename,window_start,window_end,label,logits` | perch-hoplite, from December 2025 |
| `idx,dataset_name,source_id,offset,label,logits` | perch-hoplite, 2025 |
| `filename, timestamp_s, label, logit` | perch (chirp) |

The file of the audio (`filename` or `source_id`) is relative to the
folder the embeddings were computed from: give that folder in
`audio_root`. The two older headers do not store the end of the window,
which is taken as the start plus `window_s` seconds (5 s, the window of
the Perch models).

**`"opensoundscape"`**: the table returned by
[`predict()`](https://rdrr.io/r/stats/predict.html) of an OpenSoundscape
model (`CNN` or the models of the bioacoustics model zoo, e.g. BirdNET
and Perch) and saved with `to_csv()`: the columns `file`, `start_time`
and `end_time`, then one column of scores per class. Windows whose
scores are missing (audio that could not be read) are left out.

**`"arbimon"`**: the results of a pattern matching job of Arbimon
(template matching; the score is a correlation between 0 and 1). Two
exports are recognised:

- the download of one job, with the columns `recording` (the name of the
  audio file), `site`, `species`, `songtype`, `x1`, `x2` (start and end
  of the match, in seconds from the start of the recording), `validated`
  and `score`; older exports name the minute column `min` and lack
  `frequency`, and both variants are read;

- the "export all results" of a project, one file per job, with the
  columns `x1`, `x2`, `score`, `validated`, `site_name`, `recording_id`
  and `audio_url`. It names neither the species nor the audio file: give
  the species in `label` and the `recordings` table of a project backup
  (`recordings.0001.csv`), whose `meta` column holds the original file
  name of each recording. Files without any result (empty files) are
  skipped.

The site is the Arbimon site (`site` or `site_name`) unless
`site_pattern` is given. The label is the species; a species with more
than one song type gets the song type in brackets
(`"Coccyzus minor (Simple Call)"`). The reviews done in Arbimon are kept
in `verdict`: `present` (or 1) is `"positive"`, `not present` is
`"negative"`, and `(not validated)`, empty or 0 is missing. The "export
all" files hold only 1 and 0, and whether 0 marks a rejected or an
unreviewed match is not documented, so a 0 is read as missing.

## Scores

sheepdog works with scores between 0 and 1, as BirdNET writes them.
Perch writes logits, and OpenSoundscape returns logits unless
[`predict()`](https://rdrr.io/r/stats/predict.html) was called with
`activation_layer = "sigmoid"` or `"softmax"`. Neither file records the
scale, so it is given in `score_scale`: with `"logit"` (the default of
both classifiers), `confidence` is the logistic function of the score,
`plogis(score)`; with `"probability"`, the score is used as it is and
must lie between 0 and 1. The calibration models work on the logit of
`confidence`, which for logits is the score itself, so no information is
lost. The original score is kept in `score`.

Arbimon correlations lie between 0 and 1 and are read as they are
(`score_scale = "probability"`, its default), although they are not
probabilities.

Rows with `confidence` below `min_confidence` are left out (0.1, the
default minimum confidence of BirdNET). A Perch file already lacks the
windows below the logit threshold used to write it; a logit of 0 is a
confidence of 0.5.

## Sites and labels

For Perch and OpenSoundscape, the site is the folder that holds each
audio file (`site_A/rec.wav` gives `site_A`), or is taken from the file
name with `site_pattern`, as in
[`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md).
The date and hour of a recording are read from its file name
(`YYYYMMDD_HHMMSS`) by the functions downstream, as for BirdNET.

sheepdog names the folder of a species after the part of `species_code`
after the last underscore. Labels of other classifiers are names or
codes without that part, so `species_code` is built as the label and its
lower-case form with every run of other characters replaced by a hyphen:
`"Boana raniceps"` gives `"Boana raniceps_boana-raniceps"`, whose folder
is `boana_raniceps`. The label is kept in `label`.

## References

Ghani, B., Denton, T., Kahl, S. and Klinck, H. (2023). Global birdsong
embeddings enable superior transfer learning for bioacoustic
classification. *Scientific Reports*, 13, 22876.
[doi:10.1038/s41598-023-49989-z](https://doi.org/10.1038/s41598-023-49989-z)

Lapp, S., Rhinehart, T., Freeland-Haynes, L., Khilnani, J., Syunkova, A.
and Kitzes, J. (2023). OpenSoundscape: an open-source bioacoustics
analysis package for Python. *Methods in Ecology and Evolution*, 14(9),
2321-2328.
[doi:10.1111/2041-210X.14196](https://doi.org/10.1111/2041-210X.14196)

Aide, T. M., Corrada-Bravo, C., Campos-Cerqueira, M., Milan, C., Vega,
G. and Alvarez, R. (2013). Real-time bioacoustics monitoring and
automated species identification. *PeerJ*, 1, e103.
[doi:10.7717/peerj.103](https://doi.org/10.7717/peerj.103)

## See also

[`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md)
for BirdNET,
[`read_pamdp()`](https://provetelab.org/sheepdog/reference/read_pamdp.md)
for pamDP data packages.
