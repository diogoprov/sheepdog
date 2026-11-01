# Reviewing clips in the sheepdog app

The manual review of stage 1 can be done in the BirdNET GUI ([Reviewing
clips in the BirdNET
GUI](https://provetelab.org/sheepdog/articles/reviewing-in-the-gui.md))
or in a small app that comes with sheepdog. The app shows one clip at a
time, with its spectrogram, a player and the data of the clip (site,
night, hour, score and sampling design), and writes each verdict to a
CSV file as soon as the reviewer clicks. No clip is moved between
folders, and an interrupted session loses nothing.

The app runs on the reviewer’s computer, in the browser, and reads the
clips from disk; nothing is uploaded. It needs the packages ‘shiny’ and
‘av’:

``` r

install.packages(c("shiny", "av"))
```

## Opening the app

[`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md)
takes the clip manifest and the folder of cut clips, with one subfolder
per species, as written by
[`extract_validation_clips()`](https://provetelab.org/sheepdog/reference/extract_validation_clips.md)
or
[`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md):

``` r

library(sheepdog)
run_app("validation/clip_manifest.csv", "validation/clips",
        reviewer = "liliana", max_freq = 8)
```

The verdicts go to `verdicts.csv`, next to the manifest, unless
`verdicts_file` says otherwise. The name in `reviewer` is written with
each verdict. `max_freq` limits the spectrogram to the band of the
calls, in kHz (8 kHz covers most anuran calls); by default it shows the
whole band of the recording.

![The app with a clip of Leptodactylus
fuscus.](app-figures/review-app.jpg)

The app with a clip of *Leptodactylus fuscus*.

## Reviewing

On the left, the species filter and the option *Only clips not yet
reviewed* choose the clips in the queue, and a counter shows how many
have been reviewed. On the right, the spectrogram (time in seconds,
frequency in kHz, louder sounds darker), the player, which starts each
clip on its own, and the buttons:

| Button | Key | Verdict |
|----|----|----|
| Positive | `p` | the species is heard in the clip |
| Negative | `n` | it is not |
| Uncertain | `u` | the reviewer cannot tell |
| Next, Previous | right arrow or space, left arrow | none: moves through the queue |

After a verdict, the app moves to the next clip. A clip can be reviewed
again by going back to it (untick *Only clips not yet reviewed* to see
every clip); the last verdict counts. Closing the browser tab and
calling
[`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md)
again resumes where the review stopped.

`"uncertain"` verdicts are kept in the table but, like the
`"disagreement"` of
[`consensus_verdicts()`](https://provetelab.org/sheepdog/reference/consensus_verdicts.md),
left out of precision, thresholds and calibration, which use only
positive and negative verdicts. They mark clips worth a second listen.

## From the verdicts to the validation table

[`app_verdicts()`](https://provetelab.org/sheepdog/reference/app_verdicts.md)
joins the verdicts to the manifest and returns the same table as
[`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md),
the content of `validation_by_clip.csv`. From there, stage 1 goes on as
after a review in the BirdNET GUI:

``` r

validation <- app_verdicts("validation/clip_manifest.csv",
                           "validation/verdicts.csv",
                           clips_dir = "validation/clips",
                           reviewer = "liliana")
readr::write_csv(validation, "validation/validation_by_clip.csv")

precision_by_bin(validation)
suggest_thresholds(validation)
```

`clips_dir` fills `reviewed_path`, which
[`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md)
needs to copy the clips
([`vignette("retraining")`](https://provetelab.org/sheepdog/articles/retraining.md)).

## Several reviewers

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

## The verdicts file

`verdicts.csv` has one line per click: `clip_file`, `species_folder`,
`reviewer`, `verdict` and `time`. Lines are only appended, so the file
is also a record of the review: when it was done, and how often a
verdict was changed. Keep it with the validation data.
