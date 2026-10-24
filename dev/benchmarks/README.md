# Calibration benchmarks

Run from a source checkout of sheepdog (3.2.0 or later).
These scripts are opt-in; they are never sourced by vignette/site builds.
The performance vignette reads small cached tables from `inst/benchmarks/`.
Do not label the multispecies simulation as empirical FrogNet validation:
Diogo confirmed that no real multispecies validation dataset is available.

## Scripts

- `curiango.R [DATA_DIR OUTPUT_DIR]`: reproduces the full original empirical
  report, with an explicit single-species candidate family, nested 5 x 5
  CV grouped by night and recording, seed stability, downstream histories,
  plots and paired site-night bootstrap. It downloads pinned Zenodo inputs
  if absent and checks MD5 hashes. Default inputs/intermediates are under
  `dev/benchmarks/data/curiango` and `dev/benchmarks/results/curiango` (ignored).
- `curiango-native.R [DATA_DIR]`: verifies the new automatic single-species
  family against the saved explicit-family comparison. Three fixed-seed
  CV repeats per classifier provide descriptive elapsed timings; all
  candidates fit successfully. Writes `curiango-native*.csv` and timing.
- `multispecies.R`: generates 20 independent datasets per scenario (seeds
  2026–2045), selects on five folds of whole training nights, refits and
  evaluates on untouched later nights. Six sites, eight species, 24 train
  nights, 12 test nights, two windows per cell-night. Three generating
  scenarios: global, species heterogeneity, added site/cell heterogeneity.
  It overwrites its caches and records fit warnings and session metadata.
- `curiango-export.R [DATA_DIR OUTPUT_DIR]`: exports the Curiango data in
  the `sheepdog-occupancy` schema (version 1), one folder per classifier,
  with a Bayesian calibration fitted to the ground-truth test set and its
  posterior draws. The test case of phase 1 of `dev/roadmap-integration.md`.
  The header of the script explains how the deposit maps on the schema,
  including what it lacks (window offsets; occasion covariates, written to
  `curiango_covariates.csv` outside the schema). Output under
  `dev/benchmarks/results/curiango-export` (ignored).
- `check-results.R`: checks the cached comparisons, selections, paired
  metrics, design sizes and artifact consistency without refitting models.

R packages: devtools, dplyr, tidyr, readr, lme4, pROC, tibble, withr, and
jsonlite for Zenodo metadata. Rendering also needs knitr, rmarkdown,
ggplot2 and Pandoc. Package APIs supply fits, candidate sets, selection,
grouped folds, histories, cell statuses and matrices. The historical
empirical script retains explicit candidates so a later automatic-family
change cannot silently change its comparison.

## Interpretation

The empirical files are Nyctidromus albicollis data from
https://doi.org/10.5281/zenodo.21795898 (CC BY 4.0; cite Piatti et al., DOI
10.1002/jav.03737). Original scores below 0.10 are excluded from calibration;
these are conditional precision/calibration evaluations, not classifier
recall estimates over the full annotation corpus.

For the simulation, test labels never enter selection. Matrix error uses
all eight species on matched axes; core sets are assessed separately.
Nightly truth is at least one true positive among simulated candidate
windows, not latent occupancy. Five-fold selection evaluates known sites,
not transfer to unseen sites. The generator is a controlled logistic
stress test, not a fitted model of the real FrogNet community.

Times are elapsed seconds on one machine, not version-to-version speedups.
The two rules reuse the same CV fits. Full scientific conclusions and
limitations belong in `vignettes/performance.Rmd`.
