# Cached calibration benchmark results

These are derived benchmark tables, not raw acoustic recordings. They
are rendered by `vignettes/performance.Rmd`; model fitting and downloads
are opt-in scripts in `dev/benchmarks/` of the source repository.

The empirical Curiango data originate from Piatti et al.,
*Methodological choices influence ecological inference in passive
acoustic monitoring of a Neotropical nightjar*:
https://doi.org/10.5281/zenodo.21795898 (v2, CC BY 4.0), accompanying the Curiango manuscript. `curiango-source-manifest.json` records
pinned filenames, download URLs and MD5 hashes. The original benchmark
used explicit one-species site-effect candidates; `curiango-native.csv`
checks the new automatic family against the same comparison. Native
single-species timing was repeated three times per classifier.

The `curiango-flow-*` tables are rendered by
`vignettes/crywolf-integration.Rmd`: the end-to-end flow of
`dev/benchmarks/curiango-flow.R` on the export of
`dev/benchmarks/curiango-export.R` (one-minute recordings as occasions),
for both classifiers: posterior predictive checks of the calibration,
the share of minutes with a detection in each of 20 versions drawn by
`occasion_draws()`, and the pooled summaries and per-fit convergence of
`crywolf::fp_occu_mc()` (constant false-positive rate).

The multispecies results are SIMULATED. There was no real multispecies
validation dataset available. There are 20 independent seeds per scenario
(2026–2045), six sites and eight species, 24 training nights and 12
untouched test nights, and two windows per cell-night. Confidence is
uniform on [0.10, 0.9995]; binary window truth is logistic with specified
species/site effects, and heterogeneous scenarios include omitted
site-night variation. The original five candidate models are selected
using five folds of whole training nights. Cached results include 1,500
successful CV fits, 120 final rule outcomes, paired test loss, changes in
histories and core sets, and errors on matrices with matched species axes.

A nightly true detection means at least one true positive among the
simulated candidate windows; it is not latent occupancy. Timings are
machine-specific elapsed seconds, not a version-to-version speed-up.
R and dependency versions are recorded in the session files. Do not
claim universal superiority of either selection rule from these results.
