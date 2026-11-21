# rOpenSci statistical standards: gap table

Triage of the General (G), Regression (RE) and Bayesian (BS) standards
(srr standards v0.3.0) for sheepdog, made on 2026-11-21 for phase 1 of the
statistical software track. The tags themselves are in
`R/srr-stats-standards.R` (and, for G5.4, G5.4b and G5.5, in the tests).

| Category | Met | Not applicable | To do |
|---|---|---|---|
| G | 16 | 7 | 45 |
| RE | 18 | 7 | 23 |
| BS | 17 | 14 | 25 |
| Total | 51 | 28 | 93 |

Partially met standards are counted as to do.

## Phase 2: documentation

| Standard | Gap |
|---|---|
| G1.1 | state in the README how the package relates to existing implementations (designs with known inclusion probabilities, hierarchical calibration and occupancy export are new; the per-species logistic calibration follows Wood and Kahl 2024). |
| G1.2 | add a Life Cycle Statement (stability, deprecation policy for the legacy v1/v2 names, planned work) to CONTRIBUTING.md and the README. |
| G1.3 | terms are defined where they are used in the vignettes, but there is no central glossary (precision, recall ceiling, inclusion probability, occasion, calibration intercept and slope, effective n, P(TP)). |
| G1.4a | about 170 internal functions carry plain comments, many in Portuguese; they need English roxygen blocks marked noRd. |
| G1.6 | no comparison with an alternative R implementation (e.g. a hand-coded per-species `stats::glm` calibration). |
| G2.0a | standardise the argument documentation on expected lengths. |
| G2.1a | standardise the argument documentation on expected types. |
| G2.3b | option arguments are case-sensitive and this is not documented. |
| G5.12 | the conditions for running extended tests (environment variable, brms with a Stan backend, run time) are not documented. |
| RE1.1 | document that formulas are converted to model matrices by `stats::glm()`, `lme4::glmer()` or `brms::brm()`. |
| RE1.3a | document in `fit_calibration()` that columns outside the formula are not kept. |
| RE2.0 | the bounded logit and factor conversion in `read_validations()` are documented but cannot be switched off. |
| RE3.2 | the fixed lme4 control (`bobyqa`, `maxfun = 1e5`) is not documented. |
| RE4.3 | document `confint()` for glm and glmerMod and `brms::posterior_interval()` for brmsfit. |
| RE4.10 | document residuals for binary responses and point to `calibration_ppc()`. |
| RE4.12 | document the bounded logit transform and its inverse (`stats::plogis()`). |
| RE4.16 | new levels are predicted from fixed effects, but this is neither documented in `score_detections()` nor tested for new sites. |
| RE5.0 | `vignettes/performance.Rmd` gives absolute run times but not how they scale with the number of reviewed clips. |
| BS1.2a | the README does not show how to specify the prior. |
| BS1.2c | `calibration_prior()`, `fit_calibration()` and `prior_predictive_calibration()` have no examples. |
| BS1.3 | document the computational defaults passed to `brms::brm()` (warmup, thinning). |
| BS1.3a | document how to reuse a previous fit (`init` through `...`, or refit), noting that `update()` drops sheepdog attributes. |
| BS1.3b | document that only NUTS is supported for the diagnostics, although `algorithm` can be passed to `brms::brm()`. |
| BS1.4 | document that convergence checks always run after a brms fit and how to skip them. |
| BS2.7 | document `init` passed through `...` to `brms::brm()`. |
| BS2.8 | see BS1.3a. |
| BS2.12 | no verbosity parameter of its own; document `refresh`/`silent` of brms and `suppressMessages()`. |
| BS4.0 | document that sampling uses Stan's NUTS through brms, with verified references for brms and Stan. |
| BS4.3 | `calibration_diagnostics()` uses rank-normalised R-hat and bulk and tail ESS from the posterior package, without a documented reference. |
| BS6.2 | document trace plots with warmup distinguished. |

## Phase 3: input checks

| Standard | Gap |
|---|---|
| G2.0 | length assertions exist for some arguments (`k_folds`, `conf`, `window_step`, `n_versions`, `seed`, `score_breaks`) but not for scalar arguments of `select_clips()`, `suggest_thresholds()`, `threshold_bootstrap()` and `calibration_ppc()`. Planned: shared `check_*()` helpers. |
| G2.1 | data inputs of `fit_calibration()`, `compare_calibration_models()`, `suggest_thresholds()` and `select_clips()` are not checked for class or required columns. |
| G2.2 | unchecked scalar arguments (`threshold`, `n_top`, `target_precision`, `min_confidence`, `p_min`) accept vectors silently. |
| G2.3 | See G2.3a (met) and G2.3b (gap). |
| G2.5 | `fit_calibration()` relies on `levels(validations$species)` without checking that `site` and `species` are unordered factors. |
| G2.6 | one-dimensional arguments are not stripped of extra classes before use. |
| G2.7 | `data.frame` and tibble inputs work through dplyr, but inputs are not coerced at entry and `data.table` is untested. |
| G2.8 | no single entry routine coerces tabular inputs to one class. Planned: an internal `as_sheepdog_table()`. |
| G2.9 | rows dropped for missing confidence and values clamped by the bounded logit are not reported with a message. |
| G2.11 | columns with non-standard classes (e.g. `units`) are neither handled nor tested. |
| G2.12 | list columns are not handled. |
| G2.13 | missing-data checks exist in `calibration_folds()`, `calibration_quality()` and `read_pamdp()`, but not in `fit_calibration()`, `select_clips()` or `suggest_thresholds()`. |
| G2.14 | there is no option for how missing data are handled; either add an `na_action` argument or document a fixed per-function policy. |
| G2.14a | only `calibration_folds()` and `calibration_quality()` error on missing data. |
| G2.14b | rows with missing data are dropped, mostly without a message. |
| G2.15 | audit summaries reachable with missing inputs, or guarantee removal at entry (G2.13). |
| G2.16 | `confidence` is not checked for NaN, Inf or values outside [0, 1] at entry; the bounded logit clamps Inf silently. |
| G3.0 | grid lookups use integer indices and thresholds use rounded scores, but four floating-point `==` comparisons remain (`reviewers.R`, `select_clips.R`, `recall_ceiling.R`). |
| G4.0 | user-supplied file names in `list_recordings()`, `threshold_record()`, `warning_signs()` and `run_app()` are written without checking the extension. |
| RE1.2 | document the columns required by `fit_calibration()` and check them (formula class, columns present, `tp` in 0/1, factor `site` and `species`). |
| RE2.1 | `fit_calibration()` leaves missing values to the default `na.omit` of the fitting engine without a message. |
| RE2.3 | the default predictor `logit_conf` is centred internally by brms, but extra covariates receive a normal(0, 1) prior that assumes standardisation, which is neither checked nor documented in `fit_calibration()`. |
| RE2.4 | no pre-check for collinearity or separation in `fit_calibration()`. |
| RE2.4a | check the rank of the fixed-effects model matrix. |
| RE2.4b | check for complete separation of `tp` by `logit_conf`, globally and by species. |
| BS2.1 | input is a single data frame, but `fit_calibration()` does not check its columns. |
| BS2.2 | a prior is required for brms, but its class (`brmsprior`) is not checked. |
| BS2.6 | `chains` and `iter` are validated by brms, but the package's own `rhat_max`, `ess_min`, `n_draws`, `grid_step` and `lower_prob` are not checked. |
| BS3.0 | missing-value handling in the fit is not documented (see RE2.1). |
| BS3.1 | see RE2.4. |
| BS7.4a | the normal(0, 1) prior for extra covariates assumes standardisation, which is neither tested nor warned. |

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
