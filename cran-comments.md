## Resubmission

This is a resubmission of sheepdog 3.4.0 (version 3.4.1). The incoming
pre-tests of 3.4.0 flagged two examples with elapsed time above 5 s
(compare_calibration_curves(): 11.3 s on Windows and 7.2 s on Debian;
warning_signs(): 5.2 s on Debian). Both examples are now lighter:
compare_calibration_curves() fits only the logistic and quadratic curves
with three cross-validation folds, and the example of warning_signs() uses
30 bootstrap replicates instead of 100. Locally, each now runs in under
1 s, against 2.3 s and 1.4 s before. No other changes.

Version 3.4.0 was itself a resubmission of 3.3.3, in response to the
review by Leonore Hochhauser:

- The Description no longer starts with "Tools to"; it now starts with
  "Checks whether automated detections ...".
- No example uses \dontrun{} any more. The examples of
  calibrated_thresholds(), compare_calibration_curves(),
  compare_thresholds(), extract_validation_clips(), recall_ceiling(),
  select_directed() and warning_signs() now run on the example data shipped
  in inst/extdata/example, so they are unwrapped.
  run_app() starts a 'shiny' app, so its example is wrapped in
  if (interactive()).

Since 3.3.3 the package also gained read_pamdp() and documentation
changes (see NEWS.md), hence the minor version.

## Test environment

- Local macOS, aarch64-apple-darwin23, R 4.6.1.
- R CMD check --as-cran, with all package vignettes built and rebuilt.
- The same check with crywolf removed from the library
  (`_R_CHECK_FORCE_SUGGESTS_=false`): 1 NOTE (new submission), tests and
  vignettes pass, and the tests needing crywolf are skipped.
- GitHub Actions: macOS, Windows and Linux (R release) and Linux
  (R-devel).

## R CMD check results

0 errors | 0 warnings | 2 notes

- New submission; crywolf (Suggests) is available from the
  Additional_repositories. On win-builder the same NOTE flags
  "Detections", "detections", "Chambert", "Kahl" and "et al." in
  DESCRIPTION as possibly misspelled; they are words and author names
  spelled correctly.
- The local HTML Tidy is too old to validate the HTML manual; this NOTE
  is local only.

Tests: 3036 passed, 0 failed; 3 optional tests skipped (Stan integration and optional dependencies).

## Optional repositories

crywolf is an optional Suggests dependency outside CRAN, available from
the repository declared in Additional_repositories
(https://diogoprov.r-universe.dev). Tests using optional dependencies are
conditional. Stan fitting is opt-in and is not run by normal CRAN checks.

## Size and benchmark material

The checked source archive is approximately 6.9 MB. The acoustic example
is simulated and contains no audio files. Cached performance tables are
small derived summaries; benchmark fitting and downloads are opt-in
scripts excluded from the source tarball. Vignette builds use the cached
tables and never download the original benchmark data or refit Stan.
Attribution and the source-data licence are recorded in
inst/benchmarks/README.md and the performance vignette.
