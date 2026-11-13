# Sampling, reviewing and exporting in the sheepdog app

The manual review of stage 1 can be done in the BirdNET GUI ([Reviewing
clips in the BirdNET
GUI](https://provetelab.org/sheepdog/articles/reviewing-in-the-gui.md))
or in a small app that comes with sheepdog. The app can also draw and
cut the clips and write the occupancy export, so that a validation round
runs from the selection tables to the tables of the occupancy model
without leaving it. In the Review tab, the app shows one clip at a time,
with its spectrogram, a player and the data of the clip (site, night,
hour, score and sampling design), and writes each verdict to a CSV file
as soon as the reviewer clicks. No clip is moved between folders, and an
interrupted session loses nothing.

The app runs on the reviewer’s computer, in the browser, and reads the
clips from disk; nothing is uploaded. It needs the packages ‘shiny’ and
‘av’:

``` r

install.packages(c("shiny", "av"))
```

## Opening the app

For a whole validation round, give
[`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md) the
folder of the BirdNET selection tables and the folder of the round. The
app opens on the Intro tab, a figure of what each sampling mode,
occasion and stratum picks, followed by the Sampling, Review and Export
tabs:

``` r

library(sheepdog)
run_app(selection_dir = "N:/Arara", output_dir = "validation",
        recordings = "recordings.csv", reviewer = "liliana",
        max_freq = 8, classifier = "FrogNet v2")
```

`recordings`, the table of every recording (`site`, `source_audio`), is
needed by the `"random_recordings"` design and keeps, in the export, the
occasions without detections. Everything the app writes goes to
`output_dir`: `clip_manifest.csv`, `extraction_info.csv`, `clips/`,
`verdicts.csv` and the export in `occupancy/`.

To review clips already cut,
[`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md)
takes the clip manifest and the folder of cut clips, with one subfolder
per species, as written by
[`extract_validation_clips()`](https://provetelab.org/sheepdog/reference/extract_validation_clips.md)
or
[`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md):

``` r

run_app("validation/clip_manifest.csv", "validation/clips",
        reviewer = "liliana", max_freq = 8)
```

and opens only the Review tab.

The verdicts go to `verdicts.csv`, next to the manifest, unless
`verdicts_file` says otherwise. The name in `reviewer` is written with
each verdict. `max_freq` limits the spectrogram to the band of the
calls, in kHz: 12 kHz by default (8 kHz covers most anuran calls), and
`NULL` shows the whole band of the recording. It can also be changed in
the Review tab.

[`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md) can
also be called with no arguments, and the folders chosen in the app
(next section). When it was given folders, the app opens by asking
whether they are still right: *Keep them*, or *Change them* in the Audio
panel.

## The Intro tab and the Audio panel

The Intro tab has two pages, on the left. *Graphical abstract* is the
figure of the sampling designs. *Audio panel* holds the folders of the
round, each with a *Browse…* button that opens the folder dialog of the
system (RStudio, macOS, Windows, or Linux with a display):

- **Audio folder** (`audio_dir` in
  [`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md)):
  the folder of the recordings, subfolders included. Every recording is
  listed with
  [`list_recordings()`](https://provetelab.org/sheepdog/reference/list_recordings.md)
  and written to `recordings.csv`, in the validation folder or in the
  `recordings` CSV given to
  [`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md).
- **BirdNET results** (`selection_dir`): the folder of the selection
  tables.
- **Validation folder** (`output_dir`): where the clips, the manifest,
  the verdicts and the export are written. It is created if missing.
- **Site from the file name** (`site_pattern`): optional. The site is
  normally the name of the folder of each site. When the recordings or
  the tables of several sites share one folder, give a regular
  expression with the site in parentheses: `^[^_]+_([^_]+)_` reads
  `Campus01` from `Campinas_Campus01_20261003_074339.flac`.

*Apply and reload* checks the folders, reads them and reloads the app;
on an error, the previous folders are kept. The *Loaded* box shows the
number of predictions and recordings, the clip manifest and the clips to
review. The Sampling and Export tabs ask for the BirdNET results and the
validation folder until both are set.

Below the folders, a grid shows the recordings per site (columns) and
night (rows); recordings before noon belong to the night before. The
size of each square is the number of recordings that night, and its
colour the share of the hours recorded that night with at least one
prediction, at any score. Hovering over a square shows the recordings,
the hours and the number of predictions. The *Species* box limits the
colour and the counts to the chosen species. Without the audio folder,
only the recordings with predictions are counted, and the panel says so.
The grid shows at a glance the nights a recorder stopped and the sites
or nights with few predictions.

![The app with a clip of Leptodactylus
fuscus.](app-figures/review-app.jpg)

The app with a clip of *Leptodactylus fuscus*.

## Drawing and cutting the clips

The Sampling tab is a form for the sampling design of
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
([`vignette("sampling-designs")`](https://provetelab.org/sheepdog/articles/sampling-designs.md)
explains each choice): the mode (`"top"`, `"random_detections"` or
`"random_recordings"`), the occasion, the threshold of the occupancy
analysis, `n_top`, the strata of `"random_detections"`, a total per site
or a maximum per site and species, the minimum score, filters by site,
species and hour, the seed, and the remapping of the audio paths when
the recordings moved since BirdNET read them.

After each draw, the app checks that the recordings of the drawn clips
exist. When some are missing and *Audio folder* names the folder where
the recordings are now (subfolders included), the app looks for them
there by file name and asks whether to use the files it found. If you
accept, the manifest keeps the BirdNET path in `begin_path` and the new
one in `source_audio`, and `extraction_info.csv` records the audio
folder.

*Draw* runs
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
without touching the audio and shows the number of clips per site and
species and the inclusion probability of the clips of each species
(minimum, median and maximum), which the estimates of precision use as
weights. Messages and warnings of
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
are shown above the tables; with `"top"`, the app also reminds that
those clips serve retraining and calibration but do not estimate the
false-positive rate.

*Cut clips* cuts the drawn clips with
[`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md)
and writes `clip_manifest.csv`, `extraction_info.csv` (the provenance of
the round, with every argument of the draw) and `clips/`, as
[`extract_validation_clips()`](https://provetelab.org/sheepdog/reference/extract_validation_clips.md)
does, without the zip packages. With *Simulate*, nothing is cut and the
table tells, per species, whether each recording was found. The new
clips go straight to the Review tab. The app does not write over an
existing `clip_manifest.csv` unless *Replace* is ticked, since the
verdicts already given refer to its clips.

## Reviewing

![Review: each clip is heard and gets one
verdict.](figures/schematic_review.png)

Review: each clip is heard and gets one verdict.

On the left, the species filter and the option *Only clips not yet
reviewed* choose the clips in the queue, and a counter shows how many
have been reviewed. On the right, above the spectrogram, the position in
the queue (for example, *Clip 2 of 945 \| 1 of 945 clips reviewed*) and
the controls of the spectrogram:

- **Palette**: Gray (louder sounds darker), Viridis, Inferno, Mako or
  Heat;
- **FFT window**: 256 to 2048 samples, with 90% overlap. Larger windows
  sharpen the frequency and blur the time;
- **Max. kHz**: the top of the plot (12 kHz by default); empty shows the
  whole band;
- **Brightness** and **Contrast**.

Below, the spectrogram (time in seconds, frequency in kHz), with a
dashed line that follows the audio while it plays, the player, which
starts each clip on its own, and the buttons:

| Button         | Key                     | Verdict                          |
|----------------|-------------------------|----------------------------------|
| Positive       | `p`                     | the species is heard in the clip |
| Negative       | `n`                     | it is not                        |
| Uncertain      | `u`                     | the reviewer cannot tell         |
| Next, Previous | right arrow, left arrow | none: moves through the queue    |
| Play, pause    | space                   | none: plays or pauses the clip   |

After a verdict, the app moves to the next clip. A clip can be reviewed
again by going back to it (untick *Only clips not yet reviewed* to see
every clip); the last verdict counts. Closing the browser tab and
calling
[`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md)
again resumes where the review stopped.

With `run_app(..., blind = TRUE)`, the review is blind: the Review tab
hides the score, the sampling design and the clip file name (which
starts with the score), and the clips come in an order shuffled once per
reviewer, the same each time the app is opened, instead of the order of
the manifest, which follows the score. The species stays visible, since
the verdict is about it.

`"uncertain"` verdicts are kept in the table but, like the
`"disagreement"` of
[`consensus_verdicts()`](https://provetelab.org/sheepdog/reference/consensus_verdicts.md),
left out of precision, thresholds and calibration, which use only
positive and negative verdicts. They mark clips worth a second listen.

### What a negative clip is

Below the buttons, the optional field *Identity of a negative or
uncertain clip* records what the sound is: another species, often
another class of the classifier, or a category such as an insect or
rain. Type free text, or choose one or more suggestions: the species of
the manifest and
[`identity_categories()`](https://provetelab.org/sheepdog/reference/identity_categories.md)
(`bird`, `insect`, `rain`, `other_anuran`, `noise`, `unknown`). Two or
more choices mean either of them. Mark the identity *sure* or
*probable*, then click *Negative* or *Uncertain*. The field is cleared
at each verdict and ignored for positive clips, so an identity cannot
end up on a positive.

Identities written elsewhere, for example in a spreadsheet with one row
per clip, are added to the validation table with
[`join_identities()`](https://provetelab.org/sheepdog/reference/join_identities.md).
It keeps the identities given in the app, and warns about clips that are
not in the table and about identities given to clips that are not
negative or uncertain:

``` r

ids <- readxl::read_excel("identities_liliana.xlsx")
validation <- join_identities(validation, ids, clip_col = "clip",
                              identity_col = "identity")
confuser_summary(validation)
```

[`confuser_summary()`](https://provetelab.org/sheepdog/reference/confuser_summary.md)
counts, for each target class, the identities of its negative clips. Its
`is_class` column marks identities that are classes of the classifier
themselves, where a false positive of one class is a true positive of
another, and the most frequent identities are the hard negatives worth
adding to the training set
([`vignette("retraining")`](https://provetelab.org/sheepdog/articles/retraining.md)).

## From the verdicts to the validation table

[`post_validation()`](https://provetelab.org/sheepdog/reference/post_validation.md)
reads the verdicts file in place of the review folders and writes the
same outputs as after a review in the BirdNET GUI
(`validation_by_clip.csv`, the precision by bin, the suggested
thresholds, the nightly presence and the clips for retraining):

``` r

res <- post_validation("validation/clips",
                       manifest_path = "validation/clip_manifest.csv",
                       output_dir = "validation/post",
                       verdicts_file = "validation/verdicts.csv")
```

The verdicts file keeps every click, so a clip marked twice has two
lines. The last verdict of each reviewer counts, and a message says how
many clips were marked again and how many of them changed verdict. Clips
reviewed by more than one reviewer are combined with
[`consensus_verdicts()`](https://provetelab.org/sheepdog/reference/consensus_verdicts.md)
(next section); `reviewer = "liliana"` uses the verdicts of one reviewer
only. The first argument, the folder of the clips, fills
`reviewed_path`, which
[`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md)
needs to copy the clips
([`vignette("retraining")`](https://provetelab.org/sheepdog/articles/retraining.md)).

When the clips were drawn with `"random_detections"`, keep
`inclusion_prob` in the manifest given to
[`post_validation()`](https://provetelab.org/sheepdog/reference/post_validation.md):
the precision tables then also give the precision weighted by
`1 / inclusion_prob` (`precision_weighted`). If the reviewers worked
from a blind manifest without it, pass the full manifest instead, since
the verdicts are matched by `species_folder` and `clip_file`.

[`app_verdicts()`](https://provetelab.org/sheepdog/reference/app_verdicts.md)
returns the validation table alone, for those who want to run the steps
one by one:

``` r

validation <- app_verdicts("validation/clip_manifest.csv",
                           "validation/verdicts.csv",
                           clips_dir = "validation/clips",
                           reviewer = "liliana")
precision_by_bin(validation)
suggest_thresholds(validation)
```

## Several reviewers

![Several reviewers: a share of the clips goes to both, which gives
their agreement.](figures/schematic_reviewers.png)

Several reviewers: a share of the clips goes to both, which gives their
agreement.

With
[`assign_reviewers()`](https://provetelab.org/sheepdog/reference/assign_reviewers.md),
each reviewer opens the app with their own name, and the queue shows
only their clips, including those shared with a second reviewer. There
is no need for
[`split_by_reviewer()`](https://provetelab.org/sheepdog/reference/split_by_reviewer.md):
every reviewer reads the same `clips` folder, on a shared drive or a
copy of it.

``` r

manifest <- assign_reviewers(readr::read_csv("validation/clip_manifest.csv"),
                             reviewers = c("larissa", "liliana"),
                             overlap = 0.1)
readr::write_csv(manifest, "validation/clip_manifest.csv")

# each reviewer, on their own computer
run_app("validation/clip_manifest.csv", "validation/clips",
        verdicts_file = "validation/verdicts_larissa.csv",
        reviewer = "larissa")
```

The reviewers can write to one shared `verdicts.csv` or keep one file
each. With one file each, stack them before reading:

``` r

verdicts <- list.files("validation", "^verdicts_.*\\.csv$",
                       full.names = TRUE) |>
  lapply(readr::read_csv, col_types = readr::cols(.default = "c")) |>
  dplyr::bind_rows()
readr::write_csv(verdicts, "validation/verdicts.csv")
```

With `reviewer = NULL`,
[`app_verdicts()`](https://provetelab.org/sheepdog/reference/app_verdicts.md)
keeps every reviewer’s verdicts, one row per clip and reviewer, ready
for the agreement and the consensus:

``` r

all_reviews <- app_verdicts("validation/clip_manifest.csv",
                            "validation/verdicts.csv",
                            clips_dir = "validation/clips") |>
  dplyr::filter(!is.na(reviewer))

reviewer_agreement(all_reviews)
validation <- consensus_verdicts(all_reviews)
```

## Exporting for the occupancy model

The Export tab calls
[`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
with the detections of `selection_dir`, `recordings` and the verdicts of
the Review tab. When a clip has verdicts from several reviewers, they
are combined by
[`consensus_verdicts()`](https://provetelab.org/sheepdog/reference/consensus_verdicts.md);
clips not yet reviewed are left out. Choose the occasion used in the
draw (`"file"` or `"minute"`), the minimum score and the folder of the
export (`validation/occupancy` by default). After the export, the app
shows the schema version and the number of rows of each table. The score
calibration is not in the app yet: for the calibrated tables, call
[`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
with `fit`
([`vignette("calibration")`](https://provetelab.org/sheepdog/articles/calibration.md)).

## The verdicts file

`verdicts.csv` has one line per click: `clip_file`, `species_folder`,
`reviewer`, `verdict`, `time`, `identity` and `identity_certainty` (the
last two empty without an identity). A file written by an earlier
version, without the identity columns, is read as before and rewritten
once with them empty at its next verdict. Lines are only appended, so
the file is also a record of the review: when it was done, and how often
a verdict was changed. Keep it with the validation data.
