# rOpenSci statistical standards: gap table

Triage of the General (G), Regression (RE) and Bayesian (BS) standards
(srr standards v0.3.0) for sheepdog, made on 2026-11-21 for phase 1 of the
statistical software track. The tags themselves are in
`R/srr-stats-standards.R` (and, for G5.4, G5.4b and G5.5, in the tests).

| Category | Met | Not applicable | To do |
|---|---|---|---|
| G | 30 | 7 | 31 |
| RE | 32 | 7 | 9 |
| BS | 35 | 14 | 7 |
| Total | 97 | 28 | 47 |

Partially met standards are counted as to do. Counts updated after phase 3
(input checks); they were 51 met and 93 to do after phase 1, and 78 met and
66 to do after phase 2.

## Phase 2: documentation

Done in phase 2: G1.1, G1.2, G1.3, G2.3b, G5.12, RE1.1, RE1.3a, RE2.0, RE3.2, RE4.3, RE4.10, RE4.12, RE4.16, BS1.2a, BS1.2c, BS1.3, BS1.3a, BS1.3b, BS1.4, BS2.7, BS2.8, BS2.12, BS4.0, BS4.3, BS6.2, plus RE1.3 and G2.3, which were waiting on RE1.3a and G2.3b. The documentation is in the help pages of `fit_calibration()` (sections on the model matrix, the maximum likelihood fit, the Bayesian computation and the methods for the fitted model), `read_validations()`, `score_detections()`, `calibration_prior()`, `prior_predictive_calibration()` and `calibration_diagnostics()`, in the package help page (glossary and option arguments), in the README (relation to existing implementations, prior, life cycle) and in `.github/CONTRIBUTING.md` (life cycle, tests that fit Stan models). The brms, Stan and R-hat references were checked against the CITATION files of the packages and Crossref.

Still to do:

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

Still to do (partly done for the calibration functions only):

| Standard | Gap |
|---|---|
| G2.6, G2.7, G2.8, G2.11, G2.12 | calibration tables go through `check_validations()` (tibble conversion, extra classes dropped, list columns refused); the sampling and threshold functions have no entry routine. |
| G2.13, G2.14, G2.14a, G2.14b, G2.15 | the calibration functions drop rows with missing values with a message (a documented fixed policy); `select_clips()`, `suggest_thresholds()` and the summaries of the threshold functions have no explicit policy. |
| RE2.3 | covariates are not centred or scaled by an argument; `calibration_prior()` warns when they are not standardised. |

## Phase 4: tests

| Standard | Gap |
|---|---|
| G5.2 | 64% of the stop/warning/message conditions are matched by tests (84% of errors, 66% of warnings, 15% of messages; strict matching). |
| G5.2a | 14 condition messages occur in more than one place. |
| G5.2b | see G5.2. |
| G5.3 | no-NA checks exist for several outputs but not for `threshold_bootstrap()` or for `fit_calibration()` predictions in general. |
| G5.6 | no test checks that `fit_calibration()` recovers a known intercept and slope from `simulate_validation()`. |
| G5.6a | see G5.6. |
| G5.6b | simulations use a single seed. |
| G5.7 | no test shows estimates improving as the number of reviewed clips grows. |
| G5.8 | `fit_calibration()` does not validate zero-row input, non-binary `tp`, missing `logit_conf` or single-class `tp`. |
| G5.8a | zero-row inputs are tested for several functions but not for `fit_calibration()`, `calibration_quality()` or `threshold_bootstrap()`. |
| G5.8b | no test with a character `confidence` or non-binary `tp` passed to the calibration functions. |
| G5.8c | all-TP or all-FP data and constant confidence are not tested in `fit_calibration()`. |
| G5.8d | singular fits are tested; separation and more random-effect levels than data are not. |
| G5.9 | no noise-susceptibility tests. |
| G5.9a | no test perturbs inputs by machine epsilon. |
| G5.9b | the same seed is tested to give the same result, but different seeds are not tested to give similar results. |
| G5.10 | two brms tests are gated by `SHEEPDOG_TEST_BRMS` and never run in CI. Planned: `SHEEPDOG_EXTENDED_TESTS` with the old name as alias, and an opt-in CI job. |
| RE1.3 | species and site levels are kept in `attr(fit, "sheepdog_levels")`, but this is neither documented nor tested. |
| RE7.0 | no test with exactly collinear predictors. |
| RE7.0a | see RE7.0. |
| RE7.1 | no test with `tp` perfectly determined by `logit_conf`. |
| RE7.2 | no test that `fit_calibration()` keeps the input factor levels in `sheepdog_levels`. |
| RE7.3 | no test of the accessor methods on returned objects. |
| BS2.1a | no test of input pre-processing in the brms fit. |
| BS2.13 | messages and warnings are separate conditions, but no test checks that warnings survive `suppressMessages()` in a brms fit. |
| BS2.14 | no dedicated test of suppressing warnings. |
| BS7.0 | no test of prior recovery. |
| BS7.1 | no test of prior recovery without data. |
| BS7.2 | no test of posterior recovery with `simulate_validation()`. |
| BS7.3 | no test of scaling with input size. |

## Phase 5: fixes and new options

BS5.0 (the seed was not passed to brms by `calibrate()` nor kept in the
fit) was fixed in phase 1 and is tagged in `tests/testthat/test-bayes.R`.

| Standard | Gap |
|---|---|
| RE3.3 | the lme4 optimiser and tolerances cannot be changed; planned `control` argument. |
| RE6.2 | `plot_calibration()` shows no interval for lme4 fits; uncertainty is shown only for brms fits by `plot_calibration_draws()`. |

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

Borderline calls a reviewer may contest: RE2.2, RE7.1a, BS1.5, BS5.4, BS2.5, BS3.2 and BS4.7.

## Other pkgcheck findings

From `pkgcheck::pkgcheck()` (version 0.3.4.5) on commit f3f7c12, before the
rOpenSci packaging files were merged:

- R CMD check: no errors, no warnings; test coverage 94.7%.
- 56 Rd files have no examples, including all calibration and Bayesian
  functions (`fit_calibration()`, `calibration_prior()`,
  `calibration_diagnostics()`, `compare_calibration_models()`,
  `calibration_ppc()`, `occasion_draws()`, `calibration_quality()`).
- Global assignment (`<<-`) in `R/app.R` and `R/calibrate.R` (in
  `fit_model()`), plus test helpers.
- `on.exit()` without `add = TRUE` in `R/app.R`.
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

