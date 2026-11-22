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
  the `sheepdog-occupancy` schema (version 1.1), one folder per classifier,
  with a Bayesian calibration fitted to the ground-truth test set, its
  posterior draws and the night and minute covariates of the occasions.
  The test case of phase 1 of `dev/roadmap-integration.md`. The header of
  the script explains how the deposit maps on the schema, including what it
  lacks (window offsets). Output under
  `dev/benchmarks/results/curiango-export` (ignored).
- `curiango-flow.R [EXPORT_DIR]`: the end-to-end flow of
  `vignette("crywolf-integration")` on that export, for both classifiers:
  posterior predictive check of the calibration, `occasion_draws()`, and
  the Monte Carlo propagation in crywolf (`fp_draws_data()`,
  `fp_occu_mc()`). Needs crywolf >= 2.0.0.9000 and a CmdStan installation;
  about 20 minutes per classifier with M = 20 versions on 16 cores. Writes
  the small tables the vignette reads to
  `inst/benchmarks/curiango-flow-*.csv`.
- `curiango-mc-stability.R [DRAWS_DIR]`: choice of the number of versions
  M of the Monte Carlo propagation. After `curiango-flow.R` with a large M
  and `DRAWS_DIR` set (which saves the draws of each fit), it measures, for
  each parameter and M, the Monte Carlo standard error of the pooled mean
  and the spread of the mean and of the 95% interval bounds over random
  subsets of the fits, as shares of the posterior standard deviation.
  Writes `inst/benchmarks/curiango-mc-stability.csv`.
- `curiango-fig4-mc.R FIG4_DATA [MC_SUMMARY]`: the Monte Carlo path beside
  the threshold paths of the Curiango article (its Fig. 4, from the
  corrected analysis with minutes as occasions). The models share the
  occupancy covariates but not the detection model (the article has a
  recorder random effect); the comparison is approximate. Writes the
  figure and table to `dev/benchmarks/results/`.
- `curiango-ppc.R [EXPORT_DIR]`: posterior predictive checks of the two
  Curiango calibrations saved by `curiango-export.R`: share of true
  positives overall, by score bin, by site and by month, with Bayesian
  p-values and figures in each classifier folder.
- `scaling.R [N_CORES]`: elapsed time of `fit_calibration()` from 500 to
  32,000 simulated clips for three candidates (rOpenSci standard RE5.0), and
  log-loss of partial pooling against per-species and global `stats::glm()`
  fits on new clips (G1.6). Writes `inst/benchmarks/scaling-*.csv` and
  `alternatives-logloss.csv`.
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

### Monte Carlo propagation on the Curiango (1 November 2026)

`curiango-flow.R` with M = 50 versions per classifier and 1,000 warm-up
and 1,000 sampling iterations (sheepdog 3.3.0, crywolf 2.1.0; about
50 minutes per classifier with 4 workers). All 100 fits converged
(R-hat <= 1.01, no divergent transitions).

Choice of M (`inst/benchmarks/curiango-mc-stability.csv`). The Monte
Carlo standard error of a pooled mean is sd_between / sqrt(M), so its
share of the posterior standard deviation is sqrt(share_between / M),
with share_between the share of the pooled variance that lies between
fits (reported by `summary()` of `crywolf::fp_occu_mc()`). Keeping that
error below 10% of the posterior SD requires M >= 100 x share_between.
In practice: run a pilot with M = 20, read the largest share_between of
the parameters of interest, and set M = 100 x that share. On the
Curiango, the occupancy coefficients need M = 20 with BirdNET (largest
share 0.20) and about 76 with the custom classifier (0.76); all
parameters need about 60 and 97. The spread over random subsets of the
fits is smaller than the analytic error because the subsets are drawn
without replacement from the same 50 fits (finite-population
correction); use the analytic error.

Comparison with Fig. 4 of the article (`curiango-fig4-mc.R`). With
BirdNET the Monte Carlo path reproduces the MaxF1 path (temperature
-0.32 vs -0.31, humidity -0.57 vs -0.56, moon 0.09 vs 0.09). With the
custom classifier it agrees on humidity and moon but the temperature
effect shrinks to -0.06 (95% interval -0.24 to 0.11), against -0.25 under
MaxF1 and -0.50 under MaxPrecision. Calibration uncertainty dominates
the custom classifier (share_between 0.49-0.97; false-positive rate 0.044
against 0.014 with BirdNET), so its estimates carry more of the
calibration than of the data. The models differ in the detection part
(no recorder random effect here), so these are approximate comparisons,
not yet an ecological result.

Why the temperature effect of the custom classifier shrinks (1 November
2026). A recorder random intercept on detection does not explain it: four
versions fitted with and without it gave -0.035 and -0.028 (sd_recorder
0.52). The calibration does. In the 760 reviewed minutes of the custom
classifier, P(TP) at a given score falls on warm nights (logistic
regression with score and site: -0.37 per SD of night temperature,
SE 0.18, likelihood-ratio p = 0.03; no score x temperature interaction);
with BirdNET the slope is similar (-0.30) but not significant (n = 279).
A calibration without temperature gives warm nights too high a P(TP), so
the "sample" rule adds detections on those nights and offsets the negative
effect of temperature on occupancy. Refitting the calibration with the
night temperature (`CALIB_COVARIATE=temp ADAPT_DELTA=0.95
curiango-export.R`, schema 1.3; calibration slope -0.39, 95% CI -0.72 to
-0.07; R-hat 1.009, no divergences) and the occupancy model on 20 versions
(`CLASSIFIERS=custom M=20 curiango-flow.R`; R-hat <= 1.004, no
divergences) brings the temperature effect back to -0.40 (95% interval
-1.05 to -0.12), between the MaxF1 (-0.25) and MaxPrecision (-0.50) paths.
Humidity (-0.66) and moon (0.15) barely change. Calibration uncertainty
now dominates the temperature coefficient (share_between 0.90), so by the
rule above this estimate needs about 90 versions; with 20 its Monte Carlo
error is about 21% of the posterior SD. The calibration slope on
temperature partly reflects the same change in prevalence that the
occupancy model estimates; a joint model (phase 2) would estimate both
together instead of in two steps. 191 predictions fall on nights warmer
or colder than any reviewed minute, so their P(TP) is extrapolated.
Reading the exports of schema 1.3 needs crywolf >= 2.1.0.9000.
With M = 90 versions (`N_VERSIONS=90`, `M=90`; R-hat <= 1.006, no
divergences, smallest bulk ESS 1,964; about two hours with 4 workers) the
temperature effect is -0.40 (95% interval -0.78 to -0.09), with a Monte
Carlo error of 9.8% of the posterior SD (share_between 0.87). The mean is
the same as with M = 20; the lower bound of -1.05 at M = 20 was Monte Carlo
noise from a few versions. Humidity is -0.65 (-0.86 to -0.43) and moon
0.14 (-0.01 to 0.30); every parameter is within about 10% Monte Carlo error.

Times are elapsed seconds on one machine, not version-to-version speedups.
The two rules reuse the same CV fits. Full scientific conclusions and
limitations belong in `vignettes/performance.Rmd`.
