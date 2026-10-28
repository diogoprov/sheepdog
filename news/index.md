# Changelog

## sheepdog (development version)

- The contract test reads the fixture `export-1.3` in crywolf as well
  (with crywolf \>= 2.1.0.9000): `fp_draws_data()` returns the versions
  of `occasion_draws.parquet` and refuses a different seed.
- New
  [`review_support()`](https://provetelab.org/sheepdog/reference/review_support.md):
  for each site x species cell, the reviewed clips at high scores, their
  precision, the high-score detections not yet reviewed, the threshold
  of
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)
  and a diagnosis (`"reached"`, `"exhausted"`, `"unreliable"`,
  `"review more"`, `"not reviewed"`). It replaces the code of the
  `support` table of
  [`vignette("validation-effort")`](https://provetelab.org/sheepdog/articles/validation-effort.md)
  and gives the same result. With `by` and `covariates` (e.g. from
  [`covariate_bins()`](https://provetelab.org/sheepdog/reference/covariate_bins.md)),
  the diagnosis is repeated within the bins of an environmental gradient
  or acoustic index, counting the unreviewed detections by bin too.
- [`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
  exports a calibration on continuous covariates of the occasion
  (`tp ~ logit_conf + temp_z`), schema `sheepdog-occupancy` 1.3: P(TP)
  is computed for each prediction, the versions of the detections are
  drawn in the export and written to `occasion_draws.parquet`, and
  `calibration_draws.parquet` is not written. `schema.json` records the
  covariates (`calibration$covariates`), their range in the calibration
  data and their standardisation (`covariate_scaling`). New arguments
  `n_versions`, `rule`, `p_min` and `covariate_scaling`; without
  covariates, `n_versions` calls
  [`occasion_draws()`](https://provetelab.org/sheepdog/reference/occasion_draws.md)
  on the folder (schema 1.2).
  [`occasion_draws()`](https://provetelab.org/sheepdog/reference/occasion_draws.md)
  refuses a folder of schema 1.3, which has no grid. New fixture
  `tests/testthat/fixtures/export-1.3`, checked by the contract test.
  Agreed with crywolf (`dev/proposal-calibration-covariates.md` there),
  which will read version 1.3 later.
- [`calibration_prior()`](https://provetelab.org/sheepdog/reference/calibration_prior.md)
  gives other population-level terms, such as a continuous covariate, a
  `normal(0, 1)` prior; the slope of `logit_conf` then keeps
  `normal(1, 1)` without the truncation at 0, since ‘brms’ cannot bound
  a single coefficient.
- New
  [`covariate_bins()`](https://provetelab.org/sheepdog/reference/covariate_bins.md)
  cuts a covariate of the occasions (an environmental gradient, such as
  the temperature of the night, or an acoustic index of the recording or
  minute) into bins, by default quantiles within each site.
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
  gains `covariates`, so that the `"random_detections"` draw can be
  stratified by those bins (`strata = "temp_bin"`) with exact inclusion
  probabilities, and a message recalls that a stratum related to the
  verdict should enter the calibration.
  [`precision_by_bin()`](https://provetelab.org/sheepdog/reference/precision_by_bin.md),
  [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)
  and
  [`cell_status()`](https://provetelab.org/sheepdog/reference/cell_status.md)
  gain `by`, to check each site x species cell within the bins.
  [`vignette("validation-effort")`](https://provetelab.org/sheepdog/articles/validation-effort.md)
  has a new section, “Stage 1 along a gradient”, with both examples and
  their caveats.
- `man/sheepdog-package.Rd` lists the three authors (it was not
  regenerated when `Authors@R` changed).
- [`vignette("crywolf-integration")`](https://provetelab.org/sheepdog/articles/crywolf-integration.md):
  the Curiango data come from seven recorders, not four, and the
  calibration model is chosen among three candidates, not two.
- Larissa S. M. Sugai and Liliana Piatti, who designed the validation
  protocol, are now listed as authors (`Authors@R` and `CITATION.cff`).
- New
  [`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
  writes, in one folder, the data of an occupancy model with false
  positives (schema `sheepdog-occupancy`, version 1): every occasion,
  with or without predictions (`occasions.csv`), the predictions above
  `min_confidence` (`detections.csv`) and their highest score per
  occasion x species (`scores.csv`), the reviewed clips with their
  design and inclusion probability (`validation.csv`), the recordings
  annotated by ear (`recordings_verified.csv`), the site covariates
  (`sites.csv`) and, with a model fitted with `engine = "brms"`,
  posterior draws of P(TP) on a grid of scores
  (`calibration_draws.parquet`). `schema.json` records the version of
  the schema and the settings of the export.
  [`vignette("crywolf-integration")`](https://provetelab.org/sheepdog/articles/crywolf-integration.md)
  documents every column.
- ‘jsonlite’ is imported and ‘arrow’ is suggested, for the export.
- [`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
  drops predictions that repeat the site, recording, offset and species
  of another (e.g. a selection table read twice), with a warning, and
  warns when most occasion x species with several predictions share a
  single score, a sign that one score per occasion was copied to several
  rows.
- [`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
  writes version 1.1 of the `sheepdog-occupancy` schema, which only adds
  to version 1: `occasion_covariates` appends covariates of the
  occasions (matched by `occasion_id` or by recording) to
  `occasions.csv`, and `calibration_keys` exports a calibration that
  depends on a property of the occasion, such as the month
  (`tp ~ logit_conf + (1 | month)`): each key becomes a text column of
  `occasions.csv` and of `calibration_draws.parquet`, which covers every
  level found among the occasions (levels absent from the calibration
  data are drawn as new levels). `schema.json` lists them in
  `occasion_covariates` and `calibration$keys`. A small export of the
  example data in this schema, made by `data-raw/make_export_fixture.R`,
  is shared with crywolf as a test fixture.
- New
  [`occasion_draws()`](https://provetelab.org/sheepdog/reference/occasion_draws.md)
  turns an export with calibration draws into one version of the
  detection data per posterior draw: in each draw an occasion is a
  detection when at least one of its predictions is judged true, either
  at random with its probability of being true (`"sample"`) or above
  `p_min` (`"threshold"`). It writes `occasion_draws.parquet` in the
  export (schema version 1.2), so that any occupancy software can
  propagate the uncertainty of the calibration. The random numbers
  follow those of `crywolf::fp_draws_data()`, and a test checks that
  both give the same detections; `tests/testthat/fixtures/export-1.2/`
  holds the shared case.
- [`vignette("crywolf-integration")`](https://provetelab.org/sheepdog/articles/crywolf-integration.md)
  runs the whole flow on the Curiango data (one-minute recordings, two
  classifiers): export, posterior predictive check of the calibration,
  [`occasion_draws()`](https://provetelab.org/sheepdog/reference/occasion_draws.md)
  and the Monte Carlo propagation in crywolf (`fp_draws_data()`,
  `fp_occu_mc()`), with results cached in
  `inst/benchmarks/curiango-flow-*.csv`.
- A contract test (`tests/testthat/test-contract.R`, the counterpart of
  crywolf’s `test-read_sheepdog.R`) checks that exports follow the
  schema documented in
  [`vignette("crywolf-integration")`](https://provetelab.org/sheepdog/articles/crywolf-integration.md):
  the fields of `schema.json` and the row counts it declares, the
  columns and keys of every table, `scores.csv` against
  `detections.csv`, calibration keys as text covering every level of the
  occasions, and the layout of `occasion_draws.parquet`. With crywolf
  installed, it also checks that crywolf reads each export and the
  stored occasion draws.
- New
  [`calibration_ppc()`](https://provetelab.org/sheepdog/reference/calibration_ppc.md)
  checks a Bayesian calibration model against the reviewed clips: the
  observed share of true positives against its posterior predictive
  distribution, overall and by score bin, site, species and any column
  of the validation data (e.g. month), with a mid-p Bayesian p-value.
  [`plot_calibration_ppc()`](https://provetelab.org/sheepdog/reference/plot_calibration_ppc.md)
  draws one check.
- [`vignette("sampling-designs")`](https://provetelab.org/sheepdog/articles/sampling-designs.md)
  gains a section on recorders that run the classifier on the device and
  discard the audio: keep a probability sample of the raw audio, drawn
  without looking at the scores, so that the calibration and the
  false-positive rate can still be estimated.
- The v1.2.0 reproduction test compares the `auc_sd` column of the
  effort curve with a relative tolerance of 1e-2 (1e-3 elsewhere): with
  lme4 2.1-0 this standard deviation over three small fits moves by
  about 0.4%.

## sheepdog 3.2.1

- Added fast tests for posterior matrix uncertainty, training
  provenance, overlap boundaries, missing clips and degenerate reviewer
  agreement.
- Corrected the minimum dplyr version for join relationship checks.
- Fixed the performance article index and replaced an unresolved
  manuscript DOI link with the validated Zenodo data citation.
- Declared the repositories needed by the optional crywolf integration
  in `Additional_repositories` for CRAN checks.

## sheepdog 3.2.0

- `calibration_models(single_species = TRUE)` provides global and site-
  effect candidates for one species, including an optional uncorrelated
  site-slope model.
  [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md)
  and
  [`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md)
  automatically choose candidates from the observed species and sites;
  explicit model lists still override automatic selection in the latter.
  The multispecies candidate family and its ordering are unchanged.
- New performance vignette summarises the Curiango benchmark, regression
  checks and a reproducible multispecies simulation with held-out
  nights.

## sheepdog 3.1.0

- [`cell_status()`](https://provetelab.org/sheepdog/reference/cell_status.md)
  includes both observed score endpoints in its grid and never
  extrapolates below the reviewed minimum. Crossings between 0.99 and
  the reviewed maximum are no longer missed.
- New
  [`calibration_folds()`](https://provetelab.org/sheepdog/reference/calibration_folds.md)
  exposes reproducible fold assignments.
  [`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md)
  and
  [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md)
  accept `fold_group`, e.g. `"source_audio"` or `"night"`, to keep
  groups intact across species within a site. The default clip
  assignment is unchanged.
- `read_validations(keep = )` optionally retains grouping metadata;
  [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md)
  requests it automatically and saves grouped assignments in
  `calibration_folds.csv`. Missing IDs and insufficient groups raise
  clear errors. Single-verdict test folds retain probability scores and
  have missing AUC without counting as failed fits.

## sheepdog 3.0.0

### Breaking changes

- [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md)
  and
  [`select_calibration_model()`](https://provetelab.org/sheepdog/reference/select_calibration_model.md)
  now default to `"one_se_logloss"`: choose the simplest candidate
  within one standard error of the lowest cross-validated log-loss,
  excluding candidates singular in most folds unless all are singular
  (with a warning). Supply `select = "best_auc"` (or `rule = "best_auc"`
  in the selector) to retain the 2.x selection. The comparison table
  still reports all metrics and is ordered by AUC; its first row is not
  necessarily the selected model. See the migration guide for a
  reproducible example.

### Documentation and infrastructure

- Added the 2.x to 3.0.0 migration guide.
- CI measures test coverage with `covr` and uploads an HTML report and
  Cobertura XML as workflow artifacts, without a third-party token.

### Documentation

- New article “Reviewing clips in the BirdNET GUI” (site only): the
  review in the Review tab of the BirdNET-Analyzer GUI, from the folder
  of clips to the `Positive` and `Negative` folders read by
  [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md),
  with screenshots in English and Portuguese (where the result folders
  are `positivo` and `negativo`), the regression panel of the GUI
  compared with the calibration of stage 2, and the review with several
  reviewers.

### Sampling

- `select_clips(strata = )` gains the presets `"hour"` (pooling the
  nights), `"week"` (ISO week of the night) and `"month"`, and accepts a
  character vector of column names for strata defined by the user, e.g.
  `c("month", "moon")` with a column added to the detections before the
  call. `site` and `species_code` are always added to the strata,
  columns that depend on the score (`confidence`, `rank`) are refused,
  and every stratum column must be constant within an occasion.

### Calibration

- [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
  (and
  [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md))
  passes on the messages of
  [`lme4::glmer()`](https://rdrr.io/pkg/lme4/man/glmer.html), prefixed
  by `lme4:`, instead of hiding them; the message on singular fits is
  not repeated, since it already becomes a warning. Every message of the
  fit is kept in the attribute `sheepdog_messages` of the model, and
  [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md)
  appends them to `calibration_model.txt`. The fits of the
  cross-validation folds and of the effort curve stay quiet.

## sheepdog 2.2.0

### Calibration

- [`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md)
  also scores the predicted probabilities on the held-out folds:
  log-loss and Brier score (proper scoring rules), calibration intercept
  and slope, the share of singular fold fits (`prop_singular`) and the
  position of each model (`complexity`).
- New
  [`select_calibration_model()`](https://provetelab.org/sheepdog/reference/select_calibration_model.md),
  with the rules `"best_auc"` (the rule of 2.x) and `"one_se_logloss"`
  (the simplest model within one standard error of the lowest log-loss,
  leaving out singular fits).
  [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md)
  takes the rule in `select`; the default stays `"best_auc"` until
  3.0.0, when it becomes `"one_se_logloss"`.
- `calibration_models(uncorrelated = TRUE)` adds
  `m5_species_x_site_uncorrelated`, the m4 structure without the
  correlation between the species intercepts and slopes, which avoids
  the singular fits of m4;
  [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md)
  takes it with `uncorrelated = TRUE`.

### Bayesian calibration

- [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
  gains `engine = "brms"`: the model is fitted with ‘brms’ (Bernoulli,
  logit link). The prior must be given explicitly. Convergence
  diagnostics run after the fit and warn when R-hat, the effective
  sample sizes or the divergent transitions fail the usual limits.
- New
  [`calibration_prior()`](https://provetelab.org/sheepdog/reference/calibration_prior.md):
  a weakly informative example prior centred on an already calibrated
  score (slope 1, intercept at the mean logit score), with the slope
  truncated at 0, `exponential(1)` on the standard deviations and
  `lkj(2)` on the correlations; only the classes present in the formula
  are returned.
- New
  [`prior_predictive_calibration()`](https://provetelab.org/sheepdog/reference/prior_predictive_calibration.md)
  and
  [`plot_calibration_draws()`](https://provetelab.org/sheepdog/reference/plot_calibration_draws.md)
  for prior predictive checks and for the uncertainty of the fitted
  curve;
  [`calibration_diagnostics()`](https://provetelab.org/sheepdog/reference/calibration_diagnostics.md);
  [`calibration_sensitivity()`](https://provetelab.org/sheepdog/reference/calibration_sensitivity.md),
  a power-scaling sensitivity analysis with ‘priorsense’.
- [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md)
  with a ‘brms’ model computes the posterior on a grid of scores per
  site x species and returns `p_tp` (posterior mean), `p_tp_lower` and
  `pr_reliable` (posterior probability that P(TP) \>= `p_min`).
- [`detection_history()`](https://provetelab.org/sheepdog/reference/detection_history.md)
  gains `rule = c("mean", "probability")` and `prob_min`: a detection is
  reliable when its posterior mean reaches `p_min`, or when
  `pr_reliable` reaches `prob_min`.
- New
  [`history_draws()`](https://provetelab.org/sheepdog/reference/history_draws.md)
  and
  [`community_matrices_draws()`](https://provetelab.org/sheepdog/reference/community_matrices_draws.md):
  the detection histories and the community matrices over posterior
  draws, with the posterior mean and an interval for each cell.
- [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md)
  gains `engine`, `prior` (a prior or a function of the selected
  formula, such as `calibration_prior`), `brms_args`, `rule` and
  `prob_min`; with ‘brms’ it also writes `calibration_diagnostics.csv`.
- New
  [`vignette("bayesian-calibration")`](https://provetelab.org/sheepdog/articles/bayesian-calibration.md),
  precomputed.
- ‘brms’, ‘posterior’ and ‘priorsense’ are suggested packages.

### Sampling

- [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
  gains `strata` (`"night_hour"`, the rule of 2.0.0, `"night"` or
  `"site_species"`) for the occasion draw of `"random_detections"`. With
  one recording per hour, the default stratum holds a single occasion
  and draws nothing; a coarser stratum makes the draw random. A coarser
  stratum combined with `balance_by_hour = TRUE` under a target or limit
  warns that `inclusion_prob` is conditional on the first draw.
- [`extract_validation_clips()`](https://provetelab.org/sheepdog/reference/extract_validation_clips.md)
  writes `extraction_info.csv` with the provenance of the run (date,
  versions of sheepdog and R, folder of the tables, the new `classifier`
  label and every argument of
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)).
- The message on predictions dropped by `min_confidence` is no longer
  printed when none is dropped.

### Review and retraining

- New
  [`read_validation_tables()`](https://provetelab.org/sheepdog/reference/read_validation_tables.md):
  stacks the `validation_by_clip.csv` tables of several sites or rounds
  with every column and verdict (unlike
  [`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md),
  which keeps only what the calibration needs).
- New
  [`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md):
  copies the reviewed clips into the training layout of BirdNET-Analyzer
  (positives in `<species_code>/`, negatives in `-<species_code>/`),
  with the sites in `test_sites` in a separate `test` folder for
  `--test_data`; writes `training_set.csv` and warns about classes with
  fewer positive files than `min_files`.
- New
  [`exclude_training_clips()`](https://provetelab.org/sheepdog/reference/exclude_training_clips.md):
  drops from a manifest the clips that overlap a clip used in training
  (same species and recording).
- [`vignette("retraining")`](https://provetelab.org/sheepdog/articles/retraining.md)
  uses the new functions.

### Community matrices

- New
  [`cell_status()`](https://provetelab.org/sheepdog/reference/cell_status.md):
  classifies each site x species cell of the calibration as `"reliable"`
  (the calibrated curve reaches `p_min` within the reviewed scores, with
  at least `min_n` clips), `"probably_absent"` (no true positive among
  the reviewed clips) or `"unreliable"`, separating the absence of a
  species from a calibration that fails.
- New
  [`suggest_core_species()`](https://provetelab.org/sheepdog/reference/suggest_core_species.md):
  the species with no unreliable cell.
- [`community_matrices()`](https://provetelab.org/sheepdog/reference/community_matrices.md)
  gains `drop_empty` (drop the site x month rows without any core
  species) and returns `trials`, the matrix of nights recorded with the
  dimensions of the species counts, for the `Ntrials` of a binomial
  model such as
  [`gllvm::gllvm()`](https://jenniniku.github.io/gllvm/reference/gllvm.html).
- [`vignette("community-matrices")`](https://provetelab.org/sheepdog/articles/community-matrices.md)
  uses the new functions.

### Several reviewers

- New
  [`assign_reviewers()`](https://provetelab.org/sheepdog/reference/assign_reviewers.md):
  splits the clips of a manifest among reviewers, balanced within
  species, with a fraction (`overlap`) given to a second reviewer.
- New
  [`split_by_reviewer()`](https://provetelab.org/sheepdog/reference/split_by_reviewer.md):
  copies each reviewer’s clips to their own folder tree for the BirdNET
  GUI.
- New
  [`reviewer_agreement()`](https://provetelab.org/sheepdog/reference/reviewer_agreement.md):
  agreement and kappa per species on the clips reviewed more than once
  (Cohen’s kappa for two reviewers, Fleiss’ kappa otherwise).
- New
  [`consensus_verdicts()`](https://provetelab.org/sheepdog/reference/consensus_verdicts.md):
  one verdict per clip; conflicting clips get `verdict = "disagreement"`
  and are left out of precision and calibration.

## sheepdog 2.1.0

### Bug fixes

- [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md)
  classified the clips wrongly on Windows when `review_dir` had
  backslashes (e.g. `E:\validation\clips`): the name of the review
  folder entered the search for the verdict, so a folder named after a
  verdict marked every clip with it.

### Warnings and diagnostics

- [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
  warns when the fitted GLMM is singular (a variance estimated at zero
  or a correlation at +-1);
  [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md)
  passes the warning on.
- [`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md)
  warns about, and counts in the new column `n_failed`, the folds whose
  fit failed; before, they were silently left out of the mean AUC.
- [`calibration_effort()`](https://provetelab.org/sheepdog/reference/calibration_effort.md)
  warns when `n_train` exceeds the smallest site x species cell minus
  five, and returns `n_train_mean`, `n_test_mean` and `n_failed`.
- The documentation of
  [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
  explains that `target_total` gives rare species higher inclusion
  probabilities (weight pooled estimates by `1 / inclusion_prob`) and
  that the default `recording_fraction = 0.01` draws one recording per
  site in small projects.

### Documentation

- New articles, run on a simulated example data set:
  [`vignette("sheepdog")`](https://provetelab.org/sheepdog/articles/sheepdog.md)
  (Get started),
  [`vignette("sampling-designs")`](https://provetelab.org/sheepdog/articles/sampling-designs.md),
  [`vignette("validation-effort")`](https://provetelab.org/sheepdog/articles/validation-effort.md),
  [`vignette("calibration")`](https://provetelab.org/sheepdog/articles/calibration.md),
  [`vignette("community-matrices")`](https://provetelab.org/sheepdog/articles/community-matrices.md)
  and
  [`vignette("retraining")`](https://provetelab.org/sheepdog/articles/retraining.md)
  (training folders for BirdNET-Analyzer from the reviewed clips).
- The example data set (4 sites x 8 species x 6 months; selection
  tables, the list of recordings, reviewed clips and a calibrated
  nightly history) ships in
  `system.file("extdata", "example", package = "sheepdog")`;
  `data-raw/make_example_data.R` generates it.
- [`plot_precision()`](https://provetelab.org/sheepdog/reference/plot_precision.md)
  draws one line per site when the table has several sites; before, the
  lines of different sites were joined in the same panel (also in the
  `precision_by_bin.png` of
  [`post_validation()`](https://provetelab.org/sheepdog/reference/post_validation.md)).
- [`vignette("community-matrices")`](https://provetelab.org/sheepdog/articles/community-matrices.md)
  uses a PCoA on square-root Bray-Curtis
  ([`ape::pcoa()`](https://rdrr.io/pkg/ape/man/pcoa.html)) and a
  binomial GLLVM (‘gllvm’) for a model-based ordination and a test of
  the season effect; ‘ape’, ‘gllvm’ and ‘vegan’ are suggested packages,
  used only there.
- The vignette `crywolf-contract` is now `crywolf-integration`
  (“Integration with crywolf”).
- The repository was renamed to `diogoprov/sheepdog`; the package site
  is <https://provetelab.org/sheepdog/>.
- The package can be installed from r-universe
  (`install.packages("sheepdog", repos = c("https://diogoprov.r-universe.dev", "https://cloud.r-project.org"))`),
  with binaries for Windows, macOS and Linux.

### Tests

- The comparisons with the v1.2.0 outputs tolerate floating-point
  differences between platforms (relative tolerance 1e-3 for the
  calibration outputs, 1e-8 for the others); R CMD check runs on macOS,
  Windows and Ubuntu in GitHub Actions.

## sheepdog 2.0.0

The four scripts of birdnet-validation-sampler v1.2.0 become the R
package **sheepdog**. With the same settings and seed, the package
writes the same tables as v1.2.0, after the renaming below; the test
suite checks this against outputs of the v1.2.0 scripts on simulated
data. The scripts are preserved in the `v1.2.0` tag.

### From scripts to functions

| v1.2.0 script | sheepdog |
|----|----|
| `extrair_clipes_validacao.R` | [`extract_validation_clips()`](https://provetelab.org/sheepdog/reference/extract_validation_clips.md); steps [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md), [`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md), [`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md), [`pack_clips()`](https://provetelab.org/sheepdog/reference/pack_clips.md) |
| `pos_validacao.R` | [`post_validation()`](https://provetelab.org/sheepdog/reference/post_validation.md); steps [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md), [`precision_by_bin()`](https://provetelab.org/sheepdog/reference/precision_by_bin.md), [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md), [`nightly_presence()`](https://provetelab.org/sheepdog/reference/nightly_presence.md), [`retraining_clips()`](https://provetelab.org/sheepdog/reference/retraining_clips.md), [`plot_precision()`](https://provetelab.org/sheepdog/reference/plot_precision.md) |
| `calibracao.R` | [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md); steps [`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md), [`calibration_models()`](https://provetelab.org/sheepdog/reference/calibration_models.md), [`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md), [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md), [`calibration_effort()`](https://provetelab.org/sheepdog/reference/calibration_effort.md), [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md), [`detection_history()`](https://provetelab.org/sheepdog/reference/detection_history.md), [`summarise_history()`](https://provetelab.org/sheepdog/reference/summarise_history.md), [`plot_calibration()`](https://provetelab.org/sheepdog/reference/plot_calibration.md) |
| `gerar_matrizes_comunidade.R` | [`build_community_matrices()`](https://provetelab.org/sheepdog/reference/build_community_matrices.md); step [`community_matrices()`](https://provetelab.org/sheepdog/reference/community_matrices.md) |

[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
is a pure function: it returns the clip manifest without reading or
writing audio.

### Settings become arguments

Defaults are those of the `config` blocks, except project paths and
project-specific lists, which are now required arguments (or `NULL`).

| v1.2.0 `config` | argument |
|----|----|
| `dir_dados`, `padrao_tabela` | `data_dir`, `table_pattern` |
| `dir_saida` | `output_dir` |
| `modo_amostragem` | `sampling_mode` |
| `unidade_ocasiao` (`"arquivo"`, `"minuto"`) | `occasion_unit` (`"file"`, `"minute"`) |
| `limiar` | `threshold` |
| `n_top` | `n_top` |
| `fracao_gravacoes`, `n_gravacoes_por_local` | `recording_fraction`, `n_recordings_per_site` |
| `tabela_gravacoes`, `padrao_audio`, `duracao_gravacao` | `recordings`, `audio_pattern`, `recording_duration` |
| `conf_minima` | `min_confidence` |
| `locais`, `especies` | `sites`, `species` |
| `data_inicio`, `data_fim` | `date_start`, `date_end` |
| `hora_inicio`, `hora_fim` | `hour_start`, `hour_end` |
| `alternar_dias` | `alternate_days` |
| `meta_total`, `max_por_especie` | `target_total`, `max_per_species` |
| `balancear_por_hora` | `balance_by_hour` |
| `remap_de`, `remap_para` | `remap_from`, `remap_to` |
| `fazer_zip`, `simular` | `make_zip`, `simulate` |
| seed 2026 (fixed) | `seed = 2026` |
| `dir_validado`, `caminho_manifesto` | `review_dir`, `manifest_path` |
| `padrao_positivo`, `padrao_negativo` | `positive_pattern`, `negative_pattern` |
| `faixas`, `precisao_alvo`, `n_minimo` | `bins`, `target_precision`, `min_n` |
| `arquivos_validacao`, `tabelas_predicao` | `validation_files`, `prediction_tables` |
| `normalizar_locais` | `site_map` (default `NULL`) |
| `p_min`, `min_deteccoes_noite`, `hora_madrugada` | `p_min`, `min_detections_night`, `dawn_hour` |
| `k_folds`, `semente` | `k_folds`, `seed` |
| `fazer_curva_esforco`, `esforco_n`, `esforco_repeticoes` | `effort_curve`, `effort_n`, `effort_reps` |
| `arquivo_historico` | `history_file` |
| `k_min`, `especies_nucleo`, `min_noites_mes` | `k_min`, `core_species` (required), `min_nights_month` |

### Output files, columns and values in English

- Files: `manifesto_clipes.csv` → `clip_manifest.csv`;
  `validacao_por_clipe.csv` → `validation_by_clip.csv`;
  `precisao_por_faixa` → `precision_by_bin`; `thresholds_sugeridos` →
  `suggested_thresholds`; `presenca_por_noite` → `nightly_presence`;
  `clipes_para_retreino` → `retraining_clips`; `comparacao_modelos` →
  `model_comparison`; `modelo_calibracao` → `calibration_model`;
  `curvas_calibradas` → `calibration_curves`; `curva_esforco` →
  `effort_curve`; `deteccoes_calibradas_<local>` →
  `calibrated_detections_<site>`; `historico_deteccao_noite` →
  `nightly_detection_history`; `resumo_deteccao_especie_local` →
  `detection_summary`; `matriz_frequencia_local_mes_k<k>` →
  `frequency_matrix_site_month_k<k>`; `matriz_contagens_local_mes_k<k>`
  → `count_matrix_site_month_k<k>`; `esforco_local_mes` →
  `effort_site_month`. Folders `clipes/` and `pacotes/` → `clips/` and
  `packages/`.
- Columns and values of the manifest and the validation table: see
  `vignette("crywolf-contract")`. Other columns: `especie` → `species`,
  `data` → `date`, `hora` → `hour`, `n_deteccoes` → `n_detections`,
  `n_confiaveis` → `n_reliable`, `deteccao(_k1..k3)` →
  `detection(_k1..k3)`, `faixa` → `bin`, `n_validados` → `n_reviewed`,
  `n_positivos` → `n_positive`, `precisao` → `precision`,
  `pouco_suporte` → `low_support`, `n_suporte` → `n_support`,
  `precisao_no_corte` → `precision_at_threshold`, `n_clipes` →
  `n_clips`, `presenca` → `presence` (`confirmed`,
  `not_detected_in_reviewed`, `not_reviewed`), `conf_max_positivo` →
  `max_confidence_positive`, `modelo` → `model`, `auc_media`/`auc_dp` →
  `auc_mean`/`auc_sd`, `n_por_celula` → `n_per_cell`, `noites(_k1..k3)`
  → `nights(_k1..k3)`, `mes` → `month`, `n_noites_gravadas` →
  `n_nights_recorded`, `incluido` → `included`, `n_noites_deteccao` →
  `n_nights_detected`, `frequencia` → `frequency`.
- Calibration models: `m1_int_especie` → `m1_species_intercept`,
  `m2_slope_especie` → `m2_species_slope`, `m3_mais_local` →
  `m3_plus_site`, `m4_especie_x_local` → `m4_species_x_site`; the model
  terms use `species` and `site`.
- Whole-recording clips are named `rec_...` instead of `grav_...`.
- Messages, warnings and errors are in English.

### Reading v1.2.0 files

[`post_validation()`](https://provetelab.org/sheepdog/reference/post_validation.md),
[`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md),
[`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md),
[`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md),
[`community_matrices()`](https://provetelab.org/sheepdog/reference/community_matrices.md)
and
[`build_community_matrices()`](https://provetelab.org/sheepdog/reference/build_community_matrices.md)
read manifests, validation tables and histories written by v1.2.0 and
rename them on reading, so validated data stay usable.

### Changes in behaviour

- Random draws use
  [`withr::with_seed()`](https://withr.r-lib.org/reference/with_seed.html):
  the draws are those of v1.2.0, and the global random number generator
  is left as it was.
- [`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)
  returns an empty table when no reviewed clip has a confidence score
  (whole recordings only); v1.2.0 wrote a row of `NA`.
- The verdict patterns of the review are case-insensitive and only match
  the subfolders below `review_dir`, not the review folder itself.
- A manifest without a `confidence` column is accepted.
- [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md)
  warns about prediction tables named after a site that is not in the
  calibration, and keeps the site name in the output.
- The random-effects models of the calibration need ‘lme4’, and the
  package now stops when it is missing instead of letting those fits
  fail.
- ‘av’, ‘lme4’ and ‘ggplot2’ are suggested packages, needed only to cut
  audio, to fit hierarchical models and to draw the figures.
