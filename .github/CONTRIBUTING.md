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
