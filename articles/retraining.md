# Retraining the classifier with validated clips

The manual review of stage 1 produces two kinds of labelled clips: clips
that contain the species (positives) and clips in which the classifier
detected the species but the reviewer did not hear it (negatives).
Besides measuring precision and feeding the calibration, both can be
used to retrain the BirdNET custom classifier. This article shows how to
turn the reviewed clips into a training data set in the layout that
BirdNET-Analyzer expects, how to keep an independent set for testing the
new classifier, and what has to be redone after retraining.

![The retraining loop: listen to the false positives, collect the
confirmed positives, build the training folders, train and re-run the
classifier, and leave the training clips out of the next draw. A new
random draw, review and diagnostic follow.](figures/retraining-loop.png)

The retraining loop: listen to the false positives, collect the
confirmed positives, build the training folders, train and re-run the
classifier, and leave the training clips out of the next draw. A new
random draw, review and diagnostic follow.

Training itself runs in BirdNET-Analyzer (Python), not in R. The
requirements quoted below come from the BirdNET-Analyzer documentation
(version 2.4.0, section `birdnet_analyzer.train` of the [command line
interface](https://birdnet-team.github.io/BirdNET-Analyzer/stable/usage/cli.html));
check the version you use, since the training options change between
releases.

``` r

library(sheepdog)
suppressPackageStartupMessages(library(dplyr))
ex <- system.file("extdata", "example", package = "sheepdog")
```

## What BirdNET-Analyzer expects

According to its documentation, the training script of BirdNET-Analyzer:

- takes a folder with **one subfolder per class**, and uses the folder
  names as labels. The recommended label format is
  `<scientific name>_<common name>`, although other formats work;
- accepts **negative samples** of a class in a folder with the same name
  prefixed by `-` (e.g. `-Boana raniceps_boa-ran`). Negative samples are
  used for training only, not for validation, and only when the folder
  with the positives of that class exists;
- treats a folder named `Noise`, `Background`, `Other` or `Silence` as a
  non-event class;
- resamples the audio to 48 kHz and works on 3 s segments;
- recommends at least 100 audio files per species, although training
  also works with fewer;
- accepts an independent test set (`--test_data`).

The documentation also states that custom classifiers trained with
BirdNET-Analyzer are licensed under CC BY-NC-SA 4.0.

The clips cut by sheepdog already fit this layout: they are 3 s segments
of the original recordings, and `species_code` keeps the full label of
the classifier (`<scientific name>_<code>`), which can be used as the
folder name so that the retrained classifier reports the same labels.

## The reviewed clips

We use the reviewed clips shipped with the package. In a real project
the review is done in the Review tab of the BirdNET GUI, which moves
each clip into a `Positive` or `Negative` subfolder; here we recreate
that folder structure with empty `.wav` files from the verdicts of the
example tables, and read it back with
[`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md),
which records where each clip was found (`reviewed_path`).

``` r

validation <- read_validation_tables(
  list.files(file.path(ex, "validation"), full.names = TRUE))

review_dir <- file.path(tempdir(), "review")
unlink(review_dir, recursive = TRUE)
dest <- file.path(review_dir, validation$species_folder,
                  ifelse(validation$verdict == "positive",
                         "Positive", "Negative"))
for (d in unique(dest)) dir.create(d, recursive = TRUE)
invisible(file.create(file.path(dest, validation$clip_file)))

reviewed <- validation |>
  select(-verdict, -reviewed_path) |>
  classify_review(review_dir) |>
  suppressMessages()
count(reviewed, species_code, verdict)
#> # A tibble: 16 × 3
#>    species_code                      verdict      n
#>    <chr>                             <chr>    <int>
#>  1 Boana raniceps_boa-ran            negative    88
#>  2 Boana raniceps_boa-ran            positive   232
#>  3 Dendropsophus nanus_den-nan       negative   161
#>  4 Dendropsophus nanus_den-nan       positive   159
#>  5 Elachistocleis bicolor_ela-bic    negative    34
#>  6 Elachistocleis bicolor_ela-bic    positive   286
#>  7 Leptodactylus fuscus_lep-fus      negative   151
#>  8 Leptodactylus fuscus_lep-fus      positive    98
#>  9 Leptodactylus podicipinus_lep-pod negative    43
#> 10 Leptodactylus podicipinus_lep-pod positive   255
#> 11 Physalaemus cuvieri_phy-cuv       negative    32
#> 12 Physalaemus cuvieri_phy-cuv       positive   288
#> 13 Pseudis platensis_pse-pla         negative   220
#> 14 Pseudis platensis_pse-pla         positive   100
#> 15 Scinax nasicus_sci-nas            negative   161
#> 16 Scinax nasicus_sci-nas            positive   159
```

[`read_validation_tables()`](https://provetelab.org/sheepdog/reference/read_validation_tables.md)
stacks the `validation_by_clip.csv` tables of several sites or rounds,
keeping every column and verdict.

## Keeping an independent test set

A retrained classifier has to be evaluated on clips that it did not see
during training. BirdNET-Analyzer holds out a validation split
(`--val_split`) drawn from the training folder itself, but clips from
the same site and night share background noise and calling individuals,
so a random split of clips tends to overstate performance (our
recommendation, not a statement of the BirdNET documentation).
[`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md)
offers two stricter tests, passed as `--test_data`:

- `split = "site"` keeps whole sites (`test_sites`) out of training, and
  measures how the classifier transfers to sites it was not trained on.
- `split = "night"` draws, in each site, a proportion `test_prop` of the
  nights for the test set, for all species together. Drawing the nights
  separately for each species would put the same recording in the
  training set for one species and in the test set for another; the
  checks printed at the end count such shared nights, which should be 0.

The draws use `seed`, so the split can be rebuilt. If other classifiers
will be compared on the same test set, the nights whose recordings they
were trained on must stay out of it too.
[`training_nights()`](https://provetelab.org/sheepdog/reference/training_nights.md)
reads the site and night from the names of their training clips (it also
lists folders recursively), and its table goes to `exclude_from_test`.
The default pattern expects names such as `ARA01_20211016_190000`; give
`pattern` for other naming schemes.

``` r

other_model <- training_nights("other_classifier/training_folders",
                               site_map = c(BEP2 = "BEP"))
build_training_set(reviewed, "birdnet_training", split = "night",
                   test_prop = 0.2, exclude_from_test = other_model,
                   max_per_site_species = 50, copy = FALSE)
```

`max_per_site_species` caps the positive training clips of each site x
species, taking them from the nights in turn so that as many nights as
possible are kept; the test set and the negatives are not reduced. With
`copy = FALSE`, only `training_set.csv` is written, so the split can be
checked on a computer without the clips; `remap_from` and `remap_to` fix
the paths when the clips are copied on another computer or drive. Below
we hold out one site of the example.

### A validation set by night

With `--test_data`, BirdNET-Analyzer uses the given folder as its
validation set, on which `--autotune` chooses the hyperparameters, in
place of the split by file it would otherwise draw from the training
folder (and which, for the reason above, leaks nights). Passing the test
set there would select the model on its own test set. `val_prop` draws a
third set, by night, from the training nights left after the test draw
and after `max_per_site_species`, never from `exclude_from_test`; its
clips go to `val/`, to be passed as `--test_data`, and `test/` is kept
for the final evaluation of the chosen model:

``` r

build_training_set(reviewed, "birdnet_training", split = "night",
                   test_prop = 0.2, val_prop = 0.15,
                   exclude_from_test = other_model,
                   max_per_site_species = 50, negatives_folder = "Noise",
                   copy = FALSE)
```

The validation draw uses `val_seed`, `seed + 1` by default, and gives
the same nights as a second call of
[`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md)
with `split = "night"` on the training rows of the first. The checks
then also count validation nights with training clips and validation
nights in `exclude_from_test`, which should be 0.

## Building the training folders

[`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md)
copies the reviewed clips into the BirdNET layout: positives in
`<set>/<species_code>/` and negatives in `<set>/-<species_code>/`, where
`<set>` is `train`, `val` or `test`. It reads each clip from
`reviewed_path`, the place where the review left it, leaves out
whole-recording clips (which have no confidence score), writes the table
of copied clips to `training_set.csv`, and warns about classes with
fewer positive training files than `min_files` (100 by default, the
number recommended by the BirdNET documentation).

In BirdNET-Analyzer 2.4.0, and in its main branch of October 2026, the
`-<species_code>` folders do not work as documented: their clips get the
label -1, which makes their loss negative and unbounded, inflates the
validation AUPRC, and keeps them all in the training split ([issue
1033](https://github.com/birdnet-team/BirdNET-Analyzer/issues/1033)).
Until this is fixed, `negatives_folder = "Noise"` puts every negative in
the non-event folder `Noise`, named `<species>-<site>-<clip_file>` to
keep its origin; their label is then 0 for every class.
`training_set.csv` records `Noise` as their `class_folder`, and
[`exclude_training_clips()`](https://provetelab.org/sheepdog/reference/exclude_training_clips.md)
works as before.

``` r

training_root <- file.path(tempdir(), "birdnet_training")
unlink(training_root, recursive = TRUE)
training_set <- build_training_set(reviewed, training_root,
                                   split = "site", test_sites = "NHE") |>
  suppressMessages()
#> Warning: Class(es) with fewer than 100 positive training files: Leptodactylus
#> fuscus_lep-fus (48), Pseudis platensis_pse-pla (76)

list.files(file.path(training_root, "train"))
#>  [1] "-Boana raniceps_boa-ran"            "-Dendropsophus nanus_den-nan"      
#>  [3] "-Elachistocleis bicolor_ela-bic"    "-Leptodactylus fuscus_lep-fus"     
#>  [5] "-Leptodactylus podicipinus_lep-pod" "-Physalaemus cuvieri_phy-cuv"      
#>  [7] "-Pseudis platensis_pse-pla"         "-Scinax nasicus_sci-nas"           
#>  [9] "Boana raniceps_boa-ran"             "Dendropsophus nanus_den-nan"       
#> [11] "Elachistocleis bicolor_ela-bic"     "Leptodactylus fuscus_lep-fus"      
#> [13] "Leptodactylus podicipinus_lep-pod"  "Physalaemus cuvieri_phy-cuv"       
#> [15] "Pseudis platensis_pse-pla"          "Scinax nasicus_sci-nas"
count(training_set, set, verdict)
#> # A tibble: 4 × 3
#>   set   verdict      n
#>   <chr> <chr>    <int>
#> 1 test  negative   275
#> 2 test  positive   365
#> 3 train negative   615
#> 4 train positive  1212
```

How many positive training files each class received:

``` r

n_pos <- training_set |>
  filter(set == "train", verdict == "positive") |>
  count(species_code) |>
  mutate(below_100 = n < 100)
n_pos
#> # A tibble: 8 × 3
#>   species_code                          n below_100
#>   <chr>                             <int> <lgl>    
#> 1 Boana raniceps_boa-ran              197 FALSE    
#> 2 Dendropsophus nanus_den-nan         118 FALSE    
#> 3 Elachistocleis bicolor_ela-bic      222 FALSE    
#> 4 Leptodactylus fuscus_lep-fus         48 TRUE     
#> 5 Leptodactylus podicipinus_lep-pod   194 FALSE    
#> 6 Physalaemus cuvieri_phy-cuv         217 FALSE    
#> 7 Pseudis platensis_pse-pla            76 TRUE     
#> 8 Scinax nasicus_sci-nas              140 FALSE
```

With the 2467 reviewed clips of the example, 2 of the 8 classes have
fewer than 100 positive training files. Classes with few positives are
the ones that most need clips from further review rounds before
retraining.

## Which clips to add

Three points about the composition of the training set follow from how
the clips were chosen (our recommendations, not statements of the
BirdNET documentation):

- **Clips from the `"top"` design are the easy cases.** They are the
  highest-scoring detections, so they teach the classifier little about
  the calls it currently misses or scores low. Positives from the
  `"random_detections"` and `"random_recordings"` designs (see
  [`vignette("sampling-designs")`](https://provetelab.org/sheepdog/articles/sampling-designs.md))
  cover lower scores and calls the classifier did not detect.
- **Negatives with high scores are the most informative.** They are the
  sounds the classifier confuses with the species. Species with many
  high-scoring false positives in
  [`precision_by_bin()`](https://provetelab.org/sheepdog/reference/precision_by_bin.md)
  (see
  [`vignette("validation-effort")`](https://provetelab.org/sheepdog/articles/validation-effort.md))
  are the ones for which negatives matter most.
- **Whole-recording clips** of `"random_recordings"` are longer than
  3 s. BirdNET-Analyzer crops long files (`--crop_mode`), but the label
  of a whole recording says only that the species was heard somewhere in
  it. Cut the annotated calls into 3 s clips before using them as
  positives.

## Training

Training runs in a Python environment with BirdNET-Analyzer installed.
The commands below follow the example of the documentation (they are not
run here):

``` sh
python -m birdnet_analyzer.train birdnet_training/train \
  --test_data birdnet_training/val \
  -o checkpoints/custom/Custom_Classifier.tflite

python -m birdnet_analyzer.analyze recordings/ \
  --classifier checkpoints/custom/Custom_Classifier.tflite
```

Use `--model_format raven` (or `both`) if the classifier will also be
used in Raven. Hyperparameters such as `--hidden_units`,
`--learning_rate`, `--dropout` and the upsampling options affect the
result; the documentation recommends trying several settings, or
`--autotune`. Without `val_prop`, pass `test/` as `--test_data` only
when no hyperparameter is chosen on it; otherwise evaluate on `test/`
afterwards, with the analysis of the test clips by the chosen
classifier.

## After retraining

A retrained classifier produces new confidence scores, so everything
that was estimated from the scores of the old one no longer applies:

1.  Run the new classifier over the recordings to obtain new selection
    tables.
2.  Draw and review a new set of clips (stage 1). Do not reuse the clips
    used for training: their scores are biased upwards on the data the
    classifier was trained on.
3.  Recalibrate (stage 2,
    [`vignette("calibration")`](https://provetelab.org/sheepdog/articles/calibration.md))
    and rebuild the detection histories and community matrices (stage
    3).

Keep `training_set.csv` with the new classifier. Before reviewing the
detections of the retrained classifier,
[`exclude_training_clips()`](https://provetelab.org/sheepdog/reference/exclude_training_clips.md)
drops from the new manifest the clips that overlap, for the same species
and recording, a clip used in training. With `level = "recording"` or
`"night"` it drops every clip of a recording or night used in training,
and with `any_species = TRUE` it does so for every species, since a
recording used to train one species was also heard by the classifier for
the others. It also takes the table of
[`training_nights()`](https://provetelab.org/sheepdog/reference/training_nights.md):

``` r

manifest_v2 <- select_clips(detections_v2, ...) |>
  exclude_training_clips(file.path(training_root, "training_set.csv"),
                         level = "recording", any_species = TRUE)
```

[`extract_validation_clips()`](https://provetelab.org/sheepdog/reference/extract_validation_clips.md)
records the `classifier` label in `extraction_info.csv`, so each
validation round can be traced to the classifier that produced its
clips.
