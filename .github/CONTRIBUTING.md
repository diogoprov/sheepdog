# Contributing to sheepdog

Thank you for considering a contribution. This document explains how to
report problems and how to propose changes.

## Reporting a bug or asking a question

Open an issue at <https://github.com/diogoprov/sheepdog/issues>. Please
include:

- a minimal reproducible example, ideally made with
  [reprex](https://reprex.tidyverse.org) (the example data in
  `system.file("extdata", "example", package = "sheepdog")` is usually
  enough to reproduce a problem without sharing your recordings);
- the output of `sessionInfo()` and the version of sheepdog
  (`packageVersion("sheepdog")`);
- for problems with BirdNET outputs, the BirdNET-Analyzer version and model
  that produced the selection tables.

## Proposing a change

Small fixes (typos, documentation) can go straight to a pull request. For
larger changes, such as a new sampling design or a new calibration model,
please open an issue first so that we can agree on the approach.

1. Fork the repository and create a branch from `main`.
2. Make your change. Document new or changed functions with
   [roxygen2](https://roxygen2.r-lib.org) and run `devtools::document()`.
   The documentation also runs the roclet of
   [srr](https://docs.ropensci.org/srr/), which tracks the rOpenSci
   statistical standards, so install srr first
   (`install.packages("srr", repos = "https://ropensci-review-tools.r-universe.dev")`).
3. Add tests with [testthat](https://testthat.r-lib.org) under
   `tests/testthat/`. Tests that need Stan, `crywolf` or other optional
   packages must be skipped when those packages are missing.
4. Run `devtools::check()` and make sure it finishes with no errors or
   warnings.
5. Add a bullet to the top of `NEWS.md` describing the change.
6. Open a pull request against `main`. Continuous integration runs
   `R CMD check` on Windows, macOS and Linux and reports test coverage.

## Extended tests

The default test run (`devtools::test()`, `R CMD check`) never compiles a
Stan model: the code paths of `engine = "brms"` are tested with a mocked
`brms::brm()`. The extended tests, which fit real Bayesian models, are
switched on by an environment variable (`SHEEPDOG_TEST_BRMS = "true"`, the
earlier name, still works):

```r
Sys.setenv(SHEEPDOG_EXTENDED_TESTS = "true")
devtools::test(filter = "bayes|calibrated_thresholds")
```

They check that sampling from the prior alone recovers the prior, that the
posterior recovers the intercept and slope of simulated data, and how the
posterior precision and the sampling time scale with the number of
reviewed clips, besides running the brms code paths end to end. They need
'brms' with a working Stan backend ('rstan' or 'cmdstanr' with CmdStan
installed) and the suggested packages 'posterior' and 'lme4'. They use the
example data in `system.file("extdata", "example", package = "sheepdog")`
and simulations, and download nothing. Compilation dominates the run time,
about ten minutes on a laptop, and memory use is that of a normal Stan
compilation. The GitHub Actions workflow `extended-tests.yaml` runs them
every Monday and can be started by hand from the Actions tab. Run them
before changing `fit_calibration()`, `score_detections()`, `history_draws()`
or any other function that handles a `brmsfit`.

The condition messages of the package (errors, warnings and messages) are
listed, with whether a test matches them, by
`Rscript dev/ropensci-stats/conditions.R`; each message is raised from one
place in the code.

## Life cycle

sheepdog is stable and actively maintained. Its version numbers follow
[semantic versioning](https://semver.org): a change in the major version
(as in 2.x to 3.0.0) may break existing code, and is documented in `NEWS.md`
and, when it changes results, in a migration article such as
`vignette("migration-3.0.0")`. Changes to defaults that alter results are
announced with a warning before they take effect. Files written by earlier
versions (clip manifests, validation tables and detection histories, back
to the scripts of v1.2.0) remain readable. Planned work is tracked in the
[issues](https://github.com/diogoprov/sheepdog/issues), including the
alignment with the rOpenSci standards for statistical software.

## Code style

- Follow the [tidyverse style guide](https://style.tidyverse.org) and use
  the native pipe `|>`.
- Exported functions use `snake_case` names in the object_verb or
  verb_object pattern already used in the package.
- Talk to the user with `message()`, `warning()` and `stop()`, not with
  `print()` or `cat()`, except inside `print()` and `format()` methods.
- Functions that write files take the output path or folder as an argument.

## Code of conduct

Please note that this project is released with a
[Contributor Code of Conduct](CODE_OF_CONDUCT.md). By contributing, you
agree to abide by its terms.
