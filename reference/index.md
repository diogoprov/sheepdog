# Package index

## Stage 1 - Validation data

Read BirdNET selection tables, select clips for manual review, and cut
and pack them. Each sampling design sends a different part of the night
to review; later rounds leave out what was reviewed.

![The same night of twelve recordings under the three sampling designs
of select_clips().](../figures/schematic_selection.png)

The same night of twelve recordings under the three sampling designs of
select_clips().

![Review rounds: what was reviewed leaves the pool, and combine_rounds()
gives one simple random sample.](../figures/schematic_rounds.png)

Review rounds: what was reviewed leaves the pool, and combine_rounds()
gives one simple random sample.

- [`extract_validation_clips()`](https://provetelab.org/sheepdog/reference/extract_validation_clips.md)
  : Build the validation clip set
- [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md)
  : Read BirdNET selection tables
- [`list_recordings()`](https://provetelab.org/sheepdog/reference/list_recordings.md)
  : List every recording made, from the audio folders
- [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
  : Select the clips to validate
- [`select_directed()`](https://provetelab.org/sheepdog/reference/select_directed.md)
  : Directed review round: units drawn with probability proportional to
  size
- [`covariate_bins()`](https://provetelab.org/sheepdog/reference/covariate_bins.md)
  : Bins of an occasion covariate for stratified clip selection
- [`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md)
  : Cut the selected clips
- [`pack_clips()`](https://provetelab.org/sheepdog/reference/pack_clips.md)
  : Pack the clips into one zip per species

## Stage 1 - Review app

Review the clips in a local app and read its verdicts.

![Review: each clip is heard and gets one
verdict.](../figures/schematic_review.png)

Review: each clip is heard and gets one verdict.

- [`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md) :
  Sample, review and export clips in a local app
- [`app_verdicts()`](https://provetelab.org/sheepdog/reference/app_verdicts.md)
  : Verdicts of the review app
- [`identity_categories()`](https://provetelab.org/sheepdog/reference/identity_categories.md)
  : Categories offered for the identity of a negative clip
- [`join_identities()`](https://provetelab.org/sheepdog/reference/join_identities.md)
  : Join identities of negative clips recorded outside the app
- [`confuser_summary()`](https://provetelab.org/sheepdog/reference/confuser_summary.md)
  : What the false positives of each class are

## Stage 1 - Several reviewers

Split the clips among reviewers, measure their agreement and combine
their verdicts.

![Several reviewers: a share of the clips goes to both, which gives
their agreement.](../figures/schematic_reviewers.png)

Several reviewers: a share of the clips goes to both, which gives their
agreement.

- [`assign_reviewers()`](https://provetelab.org/sheepdog/reference/assign_reviewers.md)
  : Assign the clips to several reviewers
- [`split_by_reviewer()`](https://provetelab.org/sheepdog/reference/split_by_reviewer.md)
  : Copy each reviewer's clips to their own folder
- [`reviewer_agreement()`](https://provetelab.org/sheepdog/reference/reviewer_agreement.md)
  : Agreement between reviewers
- [`consensus_verdicts()`](https://provetelab.org/sheepdog/reference/consensus_verdicts.md)
  : Consensus verdicts of several reviewers

## Stage 1 - After the review

Classify the reviewed clips and summarise precision, thresholds,
presence and retraining clips. The diagram shows what to do with each
label of
[`review_support()`](https://provetelab.org/sheepdog/reference/review_support.md),
and how to compare the empirical and model-based thresholds.

![What to do with each label of review_support(), and how to compare the
thresholds.](../figures/stage1_diagnostic.png)

What to do with each label of review_support(), and how to compare the
thresholds.

![The two thresholds on simulated data: the precision above each cut,
where each curve reaches p_min, the choice of model and the
comparison.](../figures/thresholds.png)

The two thresholds on simulated data: the precision above each cut,
where each curve reaches p_min, the choice of model and the comparison.

![The retraining loop, for when the classifier and not the review limits
precision.](../figures/schematic_retraining.png)

The retraining loop, for when the classifier and not the review limits
precision.

- [`post_validation()`](https://provetelab.org/sheepdog/reference/post_validation.md)
  : Summarise the manual validation
- [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md)
  : Classify the reviewed clips
- [`precision_by_bin()`](https://provetelab.org/sheepdog/reference/precision_by_bin.md)
  : Precision by confidence bin
- [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)
  : Suggest a confidence threshold per species
- [`review_support()`](https://provetelab.org/sheepdog/reference/review_support.md)
  : Review support of each cell: is more validation worth it?
- [`nightly_presence()`](https://provetelab.org/sheepdog/reference/nightly_presence.md)
  : Confirmed presence by night
- [`retraining_clips()`](https://provetelab.org/sheepdog/reference/retraining_clips.md)
  : Positive clips for retraining
- [`plot_precision()`](https://provetelab.org/sheepdog/reference/plot_precision.md)
  : Plot the precision curves
- [`read_validation_tables()`](https://provetelab.org/sheepdog/reference/read_validation_tables.md)
  : Read and stack the validation tables
- [`combine_rounds()`](https://provetelab.org/sheepdog/reference/combine_rounds.md)
  : Combine the review rounds of a design
- [`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md)
  : Build the training folders for BirdNET-Analyzer
- [`exclude_training_clips()`](https://provetelab.org/sheepdog/reference/exclude_training_clips.md)
  : Leave the training clips out of a manifest
- [`training_nights()`](https://provetelab.org/sheepdog/reference/training_nights.md)
  : Nights and recordings of clips used to train a classifier

## Stage 2 - Calibration

Calibrate confidence scores into probabilities of true detection and
build nightly detection histories. The diagram has the steps and checks
in order.

![Where false positives come from: the scores of true and false
detections overlap.](../figures/score_overlap.png)

Where false positives come from: the scores of true and false detections
overlap.

![The steps and checks of the calibration, in
order.](../figures/stage2_calibration.png)

The steps and checks of the calibration, in order.

![The reviewed clips give the curve, and every detection gets its
P(tp).](../figures/schematic_curve.png)

The reviewed clips give the curve, and every detection gets its P(tp).

![The detections of a night become one cell of the nightly
history.](../figures/schematic_nights.png)

The detections of a night become one cell of the nightly history.

- [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md)
  : Calibrate confidence scores and build detection histories
- [`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md)
  : Read the validation tables for calibration
- [`calibration_models()`](https://provetelab.org/sheepdog/reference/calibration_models.md)
  : Candidate calibration models
- [`calibration_folds()`](https://provetelab.org/sheepdog/reference/calibration_folds.md)
  : Assign cross-validation folds for calibration
- [`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md)
  : Compare calibration models by cross-validation
- [`select_calibration_model()`](https://provetelab.org/sheepdog/reference/select_calibration_model.md)
  : Select the calibration model
- [`calibration_quality()`](https://provetelab.org/sheepdog/reference/calibration_quality.md)
  : Check the quality of the calibrated probabilities by species
- [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
  : Fit the calibration model
- [`calibration_effort()`](https://provetelab.org/sheepdog/reference/calibration_effort.md)
  : Effort curve of the calibration
- [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md)
  : Score every detection with the calibration model
- [`calibrated_thresholds()`](https://provetelab.org/sheepdog/reference/calibrated_thresholds.md)
  : Confidence thresholds from the calibration model
- [`compare_thresholds()`](https://provetelab.org/sheepdog/reference/compare_thresholds.md)
  : Compare the empirical and the model-based thresholds
- [`detection_history()`](https://provetelab.org/sheepdog/reference/detection_history.md)
  : Nightly detection history
- [`threshold_history()`](https://provetelab.org/sheepdog/reference/threshold_history.md)
  : Nightly detection history from empirical thresholds
- [`summarise_history()`](https://provetelab.org/sheepdog/reference/summarise_history.md)
  : Summarise the detection history by site and species
- [`plot_calibration()`](https://provetelab.org/sheepdog/reference/plot_calibration.md)
  : Plot the calibration curves

## Stage 2 - Bayesian calibration

Fit the calibration with brms, check the prior and the fit, and
propagate the uncertainty to the histories and the matrices.

![The posterior of P(tp) gives one history per draw, and a mean and an
interval per cell of the matrices.](../figures/schematic_draws.png)

The posterior of P(tp) gives one history per draw, and a mean and an
interval per cell of the matrices.

- [`calibration_prior()`](https://provetelab.org/sheepdog/reference/calibration_prior.md)
  : Example prior for a Bayesian calibration model
- [`prior_predictive_calibration()`](https://provetelab.org/sheepdog/reference/prior_predictive_calibration.md)
  : Prior predictive calibration curves
- [`calibration_diagnostics()`](https://provetelab.org/sheepdog/reference/calibration_diagnostics.md)
  : Convergence diagnostics of a Bayesian calibration model
- [`calibration_sensitivity()`](https://provetelab.org/sheepdog/reference/calibration_sensitivity.md)
  : Prior and likelihood sensitivity of a Bayesian calibration model
- [`plot_calibration_draws()`](https://provetelab.org/sheepdog/reference/plot_calibration_draws.md)
  : Calibration curves of posterior (or prior) draws
- [`calibration_ppc()`](https://provetelab.org/sheepdog/reference/calibration_ppc.md)
  : Posterior predictive checks of a Bayesian calibration model
- [`plot_calibration_ppc()`](https://provetelab.org/sheepdog/reference/plot_calibration_ppc.md)
  : Plot posterior predictive checks of a calibration model
- [`history_draws()`](https://provetelab.org/sheepdog/reference/history_draws.md)
  : Nightly detection histories over posterior draws
- [`occasion_draws()`](https://provetelab.org/sheepdog/reference/occasion_draws.md)
  : Detections of each occasion over the draws of the calibration
- [`community_matrices_draws()`](https://provetelab.org/sheepdog/reference/community_matrices_draws.md)
  : Community matrices over posterior draws

## Stage 3 - Community matrices

Effort-standardised site x month matrices from calibrated histories. The
diagram also shows the occupancy export.

![Stage 3 in order, with the occupancy
export.](../figures/stage3_community.png)

Stage 3 in order, with the occupancy export.

![From the nightly history to the matrices and their
analysis.](../figures/schematic_matrix.png)

From the nightly history to the matrices and their analysis.

- [`build_community_matrices()`](https://provetelab.org/sheepdog/reference/build_community_matrices.md)
  : Write the community matrices
- [`community_matrices()`](https://provetelab.org/sheepdog/reference/community_matrices.md)
  : Community matrices from the detection history
- [`cell_status()`](https://provetelab.org/sheepdog/reference/cell_status.md)
  : Status of each site x species cell for the community matrices
- [`suggest_core_species()`](https://provetelab.org/sheepdog/reference/suggest_core_species.md)
  : Suggest the core species of the community matrices

## Occupancy models

Export the occasions, scores, reviewed clips and calibration draws for
occupancy models with false positives, such as those of crywolf. See
[How crywolf
works](https://provetelab.org/crywolf/articles/how-crywolf-works.html).

![From the reviewed clips to occupancy, by one score threshold or by the
calibration draws.](../figures/occupancy_routes.png)

From the reviewed clips to occupancy, by one score threshold or by the
calibration draws.

![An occupied site gives a detection on each night with probability p11,
and an empty site with probability p10.](../figures/occupancy_model.png)

An occupied site gives a detection on each night with probability p11,
and an empty site with probability p10.

![Sites with a few detections could be either occupied or
empty.](../figures/occupancy_mixture.png)

Sites with a few detections could be either occupied or empty.

![An occasion is a detection when any of its predictions reaches the
threshold.](../figures/occupancy_threshold.png)

An occasion is a detection when any of its predictions reaches the
threshold.

- [`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
  : Export the data of an occupancy model with false positives

## Package

- [`sheepdog`](https://provetelab.org/sheepdog/reference/sheepdog-package.md)
  [`sheepdog-package`](https://provetelab.org/sheepdog/reference/sheepdog-package.md)
  : sheepdog: Sample, Validate and Calibrate 'BirdNET' Detections
