# sheepdog

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.22696210.svg)](https://doi.org/10.5281/zenodo.22696210)
[![License:
MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://provetelab.org/sheepdog/LICENSE.md)
[![r-universe](https://diogoprov.r-universe.dev/sheepdog/badges/version)](https://diogoprov.r-universe.dev/sheepdog)
[![Codecov](https://codecov.io/gh/diogoprov/sheepdog/graph/badge.svg)](https://app.codecov.io/gh/diogoprov/sheepdog)

In the fable, the boy cries “wolf!” and the villagers have to decide
whether the wolf is real. **sheepdog** does that check for automated
predictions from
[BirdNET](https://github.com/birdnet-team/BirdNET-Analyzer) pretrained
and custom classifiers in passive acoustic monitoring (PAM). It runs
three stages:

1.  **Validation data.** Build clip sets for manual review from the
    BirdNET selection tables: top-score, random-occasion or
    random-recording designs, one folder per species, ready for the
    review tab of the BirdNET GUI or for the review app of the package
    ([`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md)).
    The random draws can be stratified along an environmental gradient.
    Then summarise the reviewed clips: precision by confidence bin,
    suggested thresholds, confirmed presence by night, clips for
    retraining and the cells that still need review.
2.  **Calibration.** Turn confidence scores into probabilities of true
    detection with hierarchical logistic models (species and site x
    species effects, compared by cross-validation), fitted with ‘lme4’
    or, in a Bayesian framework, with ‘brms’. Score every detection and
    build nightly detection histories.
3.  **Community matrices.** Turn the calibrated histories into
    effort-standardised site x month matrices for multivariate
    ordinations.

sheepdog was developed for the FrogNet project (anurans of the Pantanal
and Cerrado, Mato Grosso do Sul, Brazil), but it works with the output
of any BirdNET pretrained and custom classifier.
[`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
writes its validation and calibration outputs in a documented format for
occupancy models with false positives, such as those fitted with
[crywolf](https://github.com/diogoprov/crywolf). The two packages are
independent: sheepdog does not depend on crywolf.

![The three stages of sheepdog](reference/figures/pipeline.png)

The three stages of sheepdog

## Installation

Install the package from
[r-universe](https://diogoprov.r-universe.dev/sheepdog), which provides
binaries for Windows, macOS and Linux:

``` r

install.packages("sheepdog",
                 repos = c("https://diogoprov.r-universe.dev",
                           "https://cloud.r-project.org"))
```

The development version can be installed from GitHub:

``` r

# install.packages("remotes")
remotes::install_github("diogoprov/sheepdog")
```

Cutting the clips for review (the 3-s windows that BirdNET analyses, or
whole recordings in the random-recording design) needs
[av](https://cran.r-project.org/package=av) (it bundles ffmpeg), the
hierarchical calibration needs
[lme4](https://cran.r-project.org/package=lme4), and the figures need
[ggplot2](https://cran.r-project.org/package=ggplot2):

``` r

install.packages(c("av", "lme4", "ggplot2"))
```

## Calibration performance

In threshold-based approaches, calibration automatically compares global
and site-effect models per species; with one site, it keeps only
estimable candidates. Explicit model lists remain available in
[`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md).

The [performance
article](https://provetelab.org/sheepdog/articles/performance.html)
summarises the Curiango benchmark, regression checks, computing times
and an explicitly simulated multispecies benchmark. The results do not
show a consistent advantage of one selection rule across datasets.

## Grouped calibration folds

Use `calibrate(..., fold_group = "source_audio")` to keep recordings
intact, or `fold_group = "night"` to keep nights intact across species
at each site. The input validation tables must contain those metadata;
each site needs at least `k_folds` groups. The default remains clip
folds. For a manual workflow, retain the metadata with
`read_validations(..., keep = c("source_audio", "night"))` and inspect
the assignment with
[`calibration_folds()`](https://provetelab.org/sheepdog/reference/calibration_folds.md).
See the calibration article for examples and limitations.

## Migrating from 2.x

In 3.0.0, calibration defaults to `select = "one_se_logloss"`. Use
`select = "best_auc"` to preserve the 2.x model selection. See the
[migration
guide](https://provetelab.org/sheepdog/articles/migration-3.0.0.html)
for details and comparison of downstream results.

## Usage

``` r

library(sheepdog)

# 1a. Clips to review: check the selection first, then cut
extract_validation_clips("N:/Arara", "N:/Arara/validation",
                         remap_from = "N:/", remap_to = "/Volumes/Arara/",
                         simulate = TRUE)
extract_validation_clips("N:/Arara", "N:/Arara/validation",
                         remap_from = "N:/", remap_to = "/Volumes/Arara/")

# 1b. After the review in the BirdNET GUI
post_validation(review_dir    = "N:/Arara/validation/clips",
                manifest_path = "N:/Arara/validation/clip_manifest.csv",
                output_dir    = "N:/Arara/validation/results")

# or after the review in the app, run_app()
post_validation(manifest_path = "N:/Arara/validation/clip_manifest.csv",
                output_dir    = "N:/Arara/validation/results",
                verdicts_file = "N:/Arara/validation/verdicts.csv")

# 2. Calibration and nightly detection histories
calibrate(validation_files  = c("UEM/validation_by_clip.csv",
                                "ARA/validation_by_clip.csv"),
          prediction_tables = c(UEM = "UEM/BirdNET_SelectionTable.txt",
                                ARA = "ARA/BirdNET_SelectionTable.txt"),
          output_dir        = "calibration")

# 3. Community matrices
build_community_matrices("calibration/nightly_detection_history.csv",
                         "community_matrices",
                         core_species = c("boa_ran", "den_nan", "phy_alb"))
```

Each stage is also available as separate functions:

| Stage | Functions |
|----|----|
| 1\. Selecting and cutting clips | [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md), [`list_recordings()`](https://provetelab.org/sheepdog/reference/list_recordings.md) (every recording made, with or without predictions), [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md) (a pure function that returns the clip manifest without touching audio), [`covariate_bins()`](https://provetelab.org/sheepdog/reference/covariate_bins.md) (strata along a gradient), [`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md), [`pack_clips()`](https://provetelab.org/sheepdog/reference/pack_clips.md) |
| 1\. Review app | [`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md) (local ‘shiny’ app: choose the folders and see the recordings per site and night, draw and cut the clips, review them with spectrogram, player and keyboard verdicts written to a CSV, and export the occupancy tables), [`app_verdicts()`](https://provetelab.org/sheepdog/reference/app_verdicts.md) |
| 1\. Several reviewers | [`assign_reviewers()`](https://provetelab.org/sheepdog/reference/assign_reviewers.md), [`split_by_reviewer()`](https://provetelab.org/sheepdog/reference/split_by_reviewer.md), [`reviewer_agreement()`](https://provetelab.org/sheepdog/reference/reviewer_agreement.md) (Cohen’s or Fleiss’ kappa), [`consensus_verdicts()`](https://provetelab.org/sheepdog/reference/consensus_verdicts.md) |
| 1\. After the review | [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md), [`precision_by_bin()`](https://provetelab.org/sheepdog/reference/precision_by_bin.md), [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md), [`plot_precision()`](https://provetelab.org/sheepdog/reference/plot_precision.md), [`nightly_presence()`](https://provetelab.org/sheepdog/reference/nightly_presence.md), [`retraining_clips()`](https://provetelab.org/sheepdog/reference/retraining_clips.md), [`read_validation_tables()`](https://provetelab.org/sheepdog/reference/read_validation_tables.md), [`review_support()`](https://provetelab.org/sheepdog/reference/review_support.md) (cells, or bins, that still need review) |
| 1\. Retraining | [`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md) (training folders for BirdNET-Analyzer), [`exclude_training_clips()`](https://provetelab.org/sheepdog/reference/exclude_training_clips.md), [`training_nights()`](https://provetelab.org/sheepdog/reference/training_nights.md) |
| 2\. Calibration | [`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md), [`calibration_models()`](https://provetelab.org/sheepdog/reference/calibration_models.md), [`calibration_folds()`](https://provetelab.org/sheepdog/reference/calibration_folds.md), [`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md), [`select_calibration_model()`](https://provetelab.org/sheepdog/reference/select_calibration_model.md), [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md), [`calibration_quality()`](https://provetelab.org/sheepdog/reference/calibration_quality.md) (held-out quality of P(TP) by species), [`calibrated_thresholds()`](https://provetelab.org/sheepdog/reference/calibrated_thresholds.md) (a threshold per site x species from the model), [`calibration_effort()`](https://provetelab.org/sheepdog/reference/calibration_effort.md), [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md), [`detection_history()`](https://provetelab.org/sheepdog/reference/detection_history.md), [`summarise_history()`](https://provetelab.org/sheepdog/reference/summarise_history.md) |
| 2\. Bayesian calibration | [`calibration_prior()`](https://provetelab.org/sheepdog/reference/calibration_prior.md), [`prior_predictive_calibration()`](https://provetelab.org/sheepdog/reference/prior_predictive_calibration.md), [`calibration_diagnostics()`](https://provetelab.org/sheepdog/reference/calibration_diagnostics.md), [`calibration_ppc()`](https://provetelab.org/sheepdog/reference/calibration_ppc.md), [`plot_calibration_ppc()`](https://provetelab.org/sheepdog/reference/plot_calibration_ppc.md), [`calibration_sensitivity()`](https://provetelab.org/sheepdog/reference/calibration_sensitivity.md), [`plot_calibration_draws()`](https://provetelab.org/sheepdog/reference/plot_calibration_draws.md), [`history_draws()`](https://provetelab.org/sheepdog/reference/history_draws.md) |
| Occupancy data | [`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md) (schema `sheepdog-occupancy`), [`occasion_draws()`](https://provetelab.org/sheepdog/reference/occasion_draws.md) (one detection data set per posterior draw) |
| 3\. Community matrices | [`cell_status()`](https://provetelab.org/sheepdog/reference/cell_status.md), [`suggest_core_species()`](https://provetelab.org/sheepdog/reference/suggest_core_species.md), [`community_matrices()`](https://provetelab.org/sheepdog/reference/community_matrices.md), [`community_matrices_draws()`](https://provetelab.org/sheepdog/reference/community_matrices_draws.md) |

The [articles](https://provetelab.org/sheepdog/articles/) cover each
stage with runnable examples;
[`vignette("frognet-workflow")`](https://provetelab.org/sheepdog/articles/frognet-workflow.md)
shows the complete workflow.

The selection tables must have the standard BirdNET/Raven columns
`Begin Time (s)`, `End Time (s)`, `Species Code`, `Confidence`,
`Begin Path` and `File Offset (s)`, and the recordings must be named
`..._YYYYMMDD_HHMMSS`. The site is the name of the folder; when the
files of several sites share a folder, `site_pattern` reads it from the
file name.

## Sampling designs

[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
and
[`extract_validation_clips()`](https://provetelab.org/sheepdog/reference/extract_validation_clips.md)
take `sampling_mode`:

- `"top"` (default) keeps the *N* predictions with the highest
  confidence per site x species x night x hour. It serves retraining and
  the score-to-probability calibration (the model is conditional on the
  score). It does **not** serve to estimate false-positive rates:
  top-score clips hold fewer false positives than a random sample.
- `"random_detections"` follows the observation-confirmation design of
  [Chambert et al. (2015)](https://doi.org/10.1890/14-1507.1): occasions
  with at least one prediction \>= `threshold` are drawn at random
  within strata that do not depend on the score, and every prediction
  \>= `threshold` of a drawn occasion is cut.
- `"random_recordings"` follows the multiple-method design of [Miller et
  al. (2011)](https://doi.org/10.1890/10-1396.1): recordings (or
  minutes) are drawn among all those recorded, with or without
  predictions, for annotation by ear. The clip is the whole recording
  and `confidence` is `NA`.

![The first stage,
extract_validation_clips()](reference/figures/extraction_flow.png)

The first stage, extract_validation_clips()

The manifest records `occasion_id`, `n_detections_occasion` and
`inclusion_prob` (the probability that the occasion was drawn), with
which
[`post_validation()`](https://provetelab.org/sheepdog/reference/post_validation.md)
also reports the precision weighted by `1 / inclusion_prob` and uses it
to suggest the thresholds. Every draw uses a fixed seed, so a rerun
selects the same clips, and the cut is idempotent: an interrupted run
resumes where it stopped.

## Calibration

Converting BirdNET confidence scores into probabilities is recommended
by the BirdNET authors ([Wood & Kahl
2024](https://doi.org/10.1007/s10336-024-02144-5)); calibration by
logistic regression on logit(score) is applied, for instance, by [Owens
et al. (2026)](https://doi.org/10.64898/2026.06.01.729442).
[`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md)
extends that approach with a hierarchical multi-species structure,

    tp ~ logit(conf) + (logit(conf) | species) + (1 | site:species)

because the same score corresponds to very different probabilities of a
true detection across species and sites. The candidate models are
compared by stratified k-fold cross-validation, which scores both
discrimination (AUC) and the predicted probabilities (log-loss, Brier
score, calibration intercept and slope);
[`select_calibration_model()`](https://provetelab.org/sheepdog/reference/select_calibration_model.md)
picks a model by the highest AUC or by the simplest model within one
standard error of the lowest log-loss, leaving out singular fits.
[`calibration_quality()`](https://provetelab.org/sheepdog/reference/calibration_quality.md)
then scores the held-out predictions of that model species by species,
against a null model, because measures over all the clips can hide a
species whose score says little.

The selected model can also be fitted in a Bayesian framework with
‘brms’ (`engine = "brms"`), with an explicit prior, convergence
diagnostics, posterior predictive and prior sensitivity checks. Each
detection then gets the posterior probability that it is reliable, and
the uncertainty of the calibration can be propagated to the detection
histories and the community matrices
([`vignette("bayesian-calibration")`](https://provetelab.org/sheepdog/articles/bayesian-calibration.md)).

## Integration with crywolf

`clip_manifest.csv` and `validation_by_clip.csv` are the hand-off to
occupancy models with false positives.
[`vignette("crywolf-integration")`](https://provetelab.org/sheepdog/articles/crywolf-integration.md)
specifies their columns, types and the definition of an occasion;
example files are in `system.file("extdata", package = "sheepdog")`. Do
not pass the whole-recording clips of `"random_recordings"`
(`confidence = NA`) to the `validation` argument of
[`crywolf::fp_aggregate()`](https://provetelab.org/crywolf/reference/fp_aggregate.html):
they are the second method (manual annotation), not confirmations of
detections.

[`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
writes occasions, detections, verdicts and, with a Bayesian calibration,
its posterior draws to one folder, described by `schema.json` (schema
`sheepdog-occupancy`).
[`occasion_draws()`](https://provetelab.org/sheepdog/reference/occasion_draws.md)
turns that folder into one detection data set per posterior draw, so
that any occupancy software can propagate the uncertainty of the
calibration; crywolf reads the folder directly.

## From the scripts (v1.2.0) to the package (v2.0.0)

Up to v1.2.0 this repository held four R scripts. Version 2.0.0 turns
them into the sheepdog package, with English function names, arguments,
output columns and values. `NEWS.md` maps every script setting to its
argument and every old column to its new name. The package reads
manifests, validation tables and histories written by v1.2.0, so
validated data stay usable. The scripts are preserved in the [v1.2.0
tag](https://github.com/diogoprov/sheepdog/tree/v1.2.0).

## Authorship and citation

Developed by **Diogo B. Provete** (Universidade Federal de Mato Grosso
do Sul), from the protocol design of **Larissa S. M. Sugai** (Cornell
Lab of Ornithology) and **Liliana Piatti** (UFMS), within the FrogNet
project. Code written with AI assistance (Claude, Anthropic), with human
review and tests.

If sheepdog is useful in your work, please cite it (GitHub’s “Cite this
repository” button uses `CITATION.cff`):

> Provete, D. B., Sugai, L. S. M., & Piatti, L. (2026). *sheepdog:
> sample, validate and calibrate BirdNET detections for passive acoustic
> monitoring*. Zenodo. <https://doi.org/10.5281/zenodo.22696209>

The hex sticker uses a dog silhouette by Mozillian from
[PhyloPic](https://www.phylopic.org/images/d3e8133c-e669-4881-9111-b44145f94212)
(CC0 1.0).

## License

[MIT](https://provetelab.org/sheepdog/LICENSE.md)
