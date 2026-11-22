# rOpenSci statistical standards: gap table

Triage of the General (G), Regression (RE) and Bayesian (BS) standards
(srr standards v0.3.0) for sheepdog, made on 2026-11-21 for phase 1 of the
statistical software track. The tags themselves are in
`R/srr-stats-standards.R` (and, for G5.4, G5.4b and G5.5, in the tests).

| Category | Met | Not applicable | To do |
|---|---|---|---|
| G | 61 | 7 | 0 |
| RE | 40 | 8 | 0 |
| BS | 42 | 14 | 0 |
| Total | 143 | 29 | 0 |

Partially met standards are counted as to do. Counts updated after the
first part of phase 5; they were 125 met and 19 to do after phase 4
(tests), 51 met and 93 to do after phase 1, 78 met and 66 to do
after phase 2, and 97 met and 47 to do after phase 3.

## Phase 2: documentation

Done in phase 2: G1.1, G1.2, G1.3, G2.3b, G5.12, RE1.1, RE1.3a, RE2.0, RE3.2, RE4.3, RE4.10, RE4.12, RE4.16, BS1.2a, BS1.2c, BS1.3, BS1.3a, BS1.3b, BS1.4, BS2.7, BS2.8, BS2.12, BS4.0, BS4.3, BS6.2, plus RE1.3 and G2.3, which were waiting on RE1.3a and G2.3b. The documentation is in the help pages of `fit_calibration()` (sections on the model matrix, the maximum likelihood fit, the Bayesian computation and the methods for the fitted model), `read_validations()`, `score_detections()`, `calibration_prior()`, `prior_predictive_calibration()` and `calibration_diagnostics()`, in the package help page (glossary and option arguments), in the README (relation to existing implementations, prior, life cycle) and in `.github/CONTRIBUTING.md` (life cycle, tests that fit Stan models). The brms, Stan and R-hat references were checked against the CITATION files of the packages and Crossref.

Left for phase 5 (all closed there):

| Standard | Gap |
|---|---|
| G1.4a | about 170 internal functions carry plain comments, many in Portuguese; they need English roxygen blocks marked noRd. |
| G1.6 | no comparison with an alternative R implementation (e.g. a hand-coded per-species `stats::glm` calibration). |
| G2.0a | standardise the argument documentation on expected lengths. |
| G2.1a | standardise the argument documentation on expected types. |
| RE5.0 | `vignettes/performance.Rmd` gives absolute run times but not how they scale with the number of reviewed clips. |

## Phase 3: input checks

Done in phase 3: G2.0, G2.1, G2.2, G2.5, G2.9, G2.16, G3.0, G4.0, RE1.2,
RE2.1, RE2.4, RE2.4a, RE2.4b, BS2.1, BS2.2, BS2.6, BS3.0, BS3.1, BS7.4a.
Shared helpers in `R/checks.R` (`check_number()`, `check_prob()`,
`check_flag()`, `check_confidence()`, `check_validations()`,
`drop_missing()`, `check_calibration_data()`, `check_file_ext()`) are used
by `fit_calibration()`, `compare_calibration_models()`,
`read_validations()`, `read_selection_tables()`, `score_detections()`,
`history_draws()`, `calibration_diagnostics()`, `calibration_ppc()`,
`plot_calibration_draws()`, `calibration_prior()`, `select_clips()`,
`suggest_thresholds()`, `threshold_bootstrap()` and the functions that
write files. Tests are in `tests/testthat/test-checks.R`.

Completed in phase 5 (see below); the gaps were:

| Standard | Gap |
|---|---|
| G2.6, G2.7, G2.8, G2.11, G2.12 | calibration tables go through `check_validations()` (tibble conversion, extra classes dropped, list columns refused); the sampling and threshold functions have no entry routine. |
| G2.13, G2.14, G2.14a, G2.14b, G2.15 | the calibration functions drop rows with missing values with a message (a documented fixed policy); `select_clips()`, `suggest_thresholds()` and the summaries of the threshold functions have no explicit policy. |
| RE2.3 | covariates are not centred or scaled by an argument; `calibration_prior()` warns when they are not standardised. |

## Phase 4: tests

Done in phase 4: G5.2, G5.2a, G5.3, G5.6, G5.6a, G5.6b, G5.7, G5.8,
G5.8a, G5.8b, G5.8c, G5.8d, G5.9, G5.9a, G5.9b, G5.10, RE7.0, RE7.0a,
RE7.1, RE7.2, RE7.3, BS2.1a, BS2.13, BS2.14, BS7.0, BS7.1, BS7.2, BS7.3.

- Parameter recovery and performance (`tests/testthat/test-recovery.R`,
  simulator `sim_calibration()` in `helper-calibration.R`): intercept,
  slope and among-species standard deviation recovered within four
  standard errors under three seeds; the error and the standard error of
  the slope shrink with 16 times more clips; accessor methods and factor
  levels of the fitted objects.
- Edge conditions, noise and seeds (`test-edge-cases.R`): zero rows,
  character, complex and non-binary input, all-missing and constant
  columns, collinear predictors, separation, a random-effect level per
  clip (now an error in `check_calibration_data()`), noise at machine
  precision, and fold seeds; bootstrap seeds in
  `test-threshold_workflow.R`.
- Bayesian tests: pre-processing, suppression of messages and warnings
  with a mocked `brms::brm()` (`test-bayes.R`); prior recovery, posterior
  recovery under two seeds and scaling with the data in
  `test-bayes-extended.R`.
- Extended tests: `SHEEPDOG_EXTENDED_TESTS=true` (alias
  `SHEEPDOG_TEST_BRMS`), run weekly and on demand by
  `.github/workflows/extended-tests.yaml`.
- Conditions: `dev/ropensci-stats/conditions.R` lists the 400 conditions
  and whether a test matches them. Messages shared by several functions
  now come from one helper each (`check_columns()`, `check_data_frame()`,
  `check_brmsfit()`, `check_reviewed()`, `stop_without_inclusion_prob()`,
  `check_strata_columns()`, `message_new_sites()`), so every message is
  raised from one place. The untested errors and warnings are tested in
  `test-conditions.R`. The script misses a few conditions whose test
  pattern includes a value (e.g. "No predictions within the hour window");
  they were checked by hand.

Completed in phase 5 (see below); the gap was:

| Standard | Gap |
|---|---|
| G5.2b | every error and warning is matched by a test; 34 of the 108 messages are not, mostly progress reports (Scoring, Done!, the hour and date windows of `select_clips()`) and notes on missing suggested packages. |

## Phase 5: fixes and new options

BS5.0 (the seed was not passed to brms by `calibrate()` nor kept in the
fit) was fixed in phase 1 and is tagged in `tests/testthat/test-bayes.R`.

Done in the first part of phase 5:

- RE3.3: `fit_calibration(control = )` (a `glmerControl()` object, a list
  of `glm.control()` arguments, or the sampler settings of `brms::brm()`);
  tests in `test-fit-options.R`.
- RE6.2: `plot_calibration(interval = TRUE, level = )`, Wald bands for
  `glm`, fixed-effects bands for `glmerMod`, posterior quantiles for
  `brmsfit`; the coverage of the `glm` band is tested.
- G2.6, G2.7, G2.8, G2.11, G2.12: `as_input_table()` in `R/checks.R` is
  the entry routine of the prediction tables (`check_detections()`, used by
  `select_clips()`, `select_directed()` and `threshold_history()`) and of
  the reviewed clips (`reviewed_with_confidence()`, used by every threshold
  function). Tests in `test-input-tables.R`.
- G2.13, G2.14, G2.14a, G2.14b, G2.15: the option `sheepdog.missing`
  ("omit", the default, leaves incomplete rows out with a message;
  "error" stops), applied by `drop_missing()` to the calibration data, the
  predictions and the reviewed clips; documented in `?sheepdog`. A reviewed
  clip without a score is a whole recording of `"random_recordings"`, not a
  missing value, unless `sampling_mode` says otherwise.
- G5.2b: `test-messages.R` triggers every progress message and note;
  `conditions.R` now finds a test for all 405 conditions. Missing
  suggested packages go through `has_suggested()`, which tests mock.
- RE5.0 and G1.6: `dev/benchmarks/scaling.R` and the performance vignette
  (time against 500 to 32,000 clips; partial pooling against per-species
  and global `glm()`).
- RE2.3 moved to not applicable (see below).

Part 2 (branch `claude/ropensci-stats-fase5b`):

- English internal names: local variables, internal arguments, temporary
  columns and the package object `occasion_key` (was `ocasiao_chave`) are
  now in English, and every plain comment was translated. Column names of
  input and output tables, exported arguments, user-facing strings and the
  legacy names read by `legacy.R` are unchanged. `utils::globalVariables()`
  was regenerated from `codetools` (212 names).
- G1.4a: all 199 internal functions carry a roxygen block with `@param`,
  `@return` and `@noRd`; `devtools::document()` writes no new `.Rd` file.
- G2.0a and G2.1a: each `@param` of the exported functions opens with the
  expected type and length.

Still to do: the generic adapter for other classifiers (item added on
2026-11-21), which needs a decision on the formats to support first.

## Not applicable

| Standard | Reason |
|---|---|
| G2.14c | Imputing reviewer verdicts or classifier confidences would bias the precision and calibration estimates that the package exists to provide, so missing values are never replaced. |
| G3.1 | The package computes no covariances; variance components come from model fits in lme4 or brms. |
| G3.1a | The package computes no covariances (see G3.1). |
| G5.0 | No standard reference data sets exist for the validation and calibration of acoustic classifier outputs. Tests use the package example data (`inst/extdata/example`) and surveys simulated with known generating parameters (`tests/testthat/helper-simulate.R`). |
| G5.4c | There are no published numeric outputs of these methods to store as test values. |
| G5.11 | Extended tests use only data shipped with the package; nothing is downloaded. |
| G5.11a | No downloads are needed (see G5.11). |
| RE2.3 | `logit_conf` stays on its natural scale: its zero is a score of 0.5, the scale of `calibration_prior()`, and `score_detections()` carries no other covariate, so centring would only relabel coefficients. Users centre other covariates before the call; `calibration_prior()` warns when they are not standardised. |
| RE2.2 | Clips without a verdict are not training data: calibration is fitted on reviewed clips only and then used to predict P(TP) for every detection, which is the purpose of the package. |
| RE4.1 | Optional standard. A model object is always fitted, because convergence diagnostics run immediately after fitting. |
| RE4.14 | The package makes no forecasts or temporal extrapolation; it predicts P(TP) at observed scores. |
| RE4.15 | No forecasts (see RE4.14). |
| RE6.3 | No forecasts (see RE4.14). |
| RE7.1a | With a binary response a noiseless relation is complete separation, for which logistic regression does not converge, so speed with noiseless data is not a meaningful comparison. |
| RE7.4 | No forecasts (see RE4.14). |
| BS1.0 | The package documentation does not use the term "hyperparameter" for the calibration priors; it appears only in `build_training_set()`, about the autotune of BirdNET-Analyzer training. |
| BS1.5 | A single composite convergence check is used (rank-normalised R-hat, bulk and tail ESS, divergences), so there are no alternative checkers to compare. |
| BS2.3 | Priors are `brmsprior` objects, one row per parameter class, not vectors of distributional parameters; brms validates them against the model parameters. |
| BS2.4 | brms matches each prior to the parameter classes of the model, and `calibration_prior()` only creates classes that exist in the model. |
| BS2.5 | Numerical validity of prior parameters is checked by brms and Stan when the model is built. |
| BS2.9 | Seeding is delegated to Stan through brms: one seed per fit, with distinct streams per chain. |
| BS2.10 | The package does not accept seeds per chain; a scalar seed is passed to brms. |
| BS2.11 | The package has no starting-value parameter of its own; `init` belongs to `brms::brm()`. |
| BS3.2 | With the single default predictor `logit_conf`, perfect collinearity arises only from user covariates, where the appropriate response is an error (BS3.1) rather than an alternative routine. |
| BS4.1 | The package implements no sampler of its own. |
| BS4.4 | Stan runs a fixed number of iterations; there is no stopping on convergence. |
| BS4.6 | No convergence checker with automatic stopping. |
| BS4.7 | No convergence checker with automatic stopping; the thresholds `rhat_max` and `ess_min` only classify a fit. |
| BS5.4 | A single composite convergence check is used (see BS1.5). |

Borderline calls a reviewer may contest: RE2.2, RE2.3, RE7.1a, BS1.5, BS5.4, BS2.5, BS3.2 and BS4.7.

## Other pkgcheck findings

From `pkgcheck::pkgcheck()` (version 0.3.4.5) on commit f3f7c12, before the
rOpenSci packaging files were merged:

- R CMD check: no errors, no warnings; test coverage 94.7%.
- 56 Rd files had no examples, including all calibration and Bayesian
  functions. Fixed on 2026-11-22: every exported function has examples;
  those that fit a brms model (or need an export written with one) are in
  `\dontrun{}`, and `calibrate()` is in `\donttest{}`.
- Global assignment (`<<-`) in `R/app.R` and `R/calibrate.R` (in
  `fit_model()`): fixed on 2026-11-22 with a local environment. The test
  helpers still use it.
- `on.exit()` without `add = TRUE` in `R/app.R`: fixed on 2026-11-22.
- Five exported names also exist in other packages: `calibrate()`,
  `plot_calibration()`, `plot_precision()`, `run_app()` and
  `suggest_thresholds()`.
- The goodpractice lints (long functions, cyclomatic complexity, long lines,
  `1:length()`, `any(is.na())` and others) are listed in the full report and
  are left for a later clean-up.

## autotest

`autotest::autotest_package()` (and a run function by function) stops on
every function with "'\_' is an unrecognized escape in character string
(test-rounds.R:230:136)". No file of the package contains `\_`, and line 230
of `tests/testthat/test-rounds.R` has fewer than 136 characters, so the
error comes from the code that autotest generates or parses, not from
sheepdog. autotest gave no result to triage; it should be tried again with a
newer version before submission.

