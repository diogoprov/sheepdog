# Calibrate confidence scores and build detection histories

Runs the whole calibration stage: reads the reviewed clips, compares the
candidate models by cross-validation, refits the best one to all the
clips, optionally draws the effort curve, scores every detection of the
complete selection tables and builds the nightly detection history.
Writes to `output_dir`:

- `model_comparison.csv`
  ([`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md));

- `calibration_folds.csv`, when `fold_group` is supplied: validation row
  number, site, species, grouping columns and assigned fold;

- `calibration_model.rds` and `calibration_model.txt` (the refitted best
  model and its summary);

- `calibration_curves.png`
  ([`plot_calibration()`](https://provetelab.org/sheepdog/reference/plot_calibration.md)),
  when 'ggplot2' is installed;

- `effort_curve.csv`
  ([`calibration_effort()`](https://provetelab.org/sheepdog/reference/calibration_effort.md)),
  when `effort_curve` is `TRUE`;

- `calibrated_detections_<site>.csv`, one per site
  ([`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md));

- `thresholds.csv`
  ([`calibrated_thresholds()`](https://provetelab.org/sheepdog/reference/calibrated_thresholds.md)
  with `rule = "probability"` and `target = p_min`): for each site x
  species, the lowest confidence score at which P(TP) reaches `p_min`,
  the score equivalent of the cut on P(TP) used by the detection
  history. Useful to filter detections in software that only takes a
  score threshold;

- `nightly_detection_history.csv`
  ([`detection_history()`](https://provetelab.org/sheepdog/reference/detection_history.md));

- `detection_summary.csv`
  ([`summarise_history()`](https://provetelab.org/sheepdog/reference/summarise_history.md)).

## Usage

``` r
calibrate(
  validation_files,
  prediction_tables,
  output_dir,
  site_map = NULL,
  min_confidence = 0.1,
  p_min = 0.95,
  min_detections_night = 1,
  dawn_hour = 12,
  k_folds = 5,
  select = c("one_se_logloss", "best_auc"),
  uncorrelated = FALSE,
  effort_curve = FALSE,
  effort_n = c(5, 10, 15, 20, 25, 30),
  effort_reps = 50,
  engine = c("lme4", "brms"),
  prior = NULL,
  brms_args = list(),
  rule = c("mean", "probability"),
  prob_min = 0.9,
  seed = 2026,
  fold_group = NULL
)
```

## Arguments

- validation_files:

  Character vector, paths to the `validation_by_clip.csv` files of the
  sites (v1.2.0 `validacao_por_clipe.csv` files are also read).

- prediction_tables:

  Named character vector of the complete selection tables, one element
  per site, named by site: the path of each combined table, or the
  folder of the per-audio tables of each site (see
  [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md)).

- output_dir:

  Character scalar, output folder; created if needed. The calibrated
  detections of a large project can take hundreds of MB.

- site_map:

  `NULL` or a named character vector to fix diverging site names, as
  `c(old = "new")`, e.g. `c(BEP2 = "BEP")`.

- min_confidence:

  Numeric scalar in \[0, 1\]. Detections below this confidence are not
  scored.

- p_min:

  Numeric scalar in \[0, 1\], threshold on the calibrated probability
  (not on the confidence score).

- min_detections_night:

  Integer scalar \>= 1, repetition rule: minimum number of reliable
  detections for a night with detection.

- dawn_hour:

  Numeric scalar in \[0, 24\]. Recordings that start before this hour
  belong to the night before.

- k_folds:

  Integer scalar \>= 2, number of folds.

- select:

  Character scalar, one of `"one_se_logloss"` (default) or `"best_auc"`:
  the rule to choose the model; see
  [`select_calibration_model()`](https://provetelab.org/sheepdog/reference/select_calibration_model.md).

- uncorrelated:

  Logical scalar. If `TRUE`, include the m4 variant without the species
  intercept-slope correlation among the candidates; see
  [`calibration_models()`](https://provetelab.org/sheepdog/reference/calibration_models.md).

- effort_curve:

  Logical scalar. If `TRUE`, draw the effort curve (slow).

- effort_n, effort_reps:

  Numeric vector of training sizes and integer scalar \>= 1 of
  repetitions of the effort curve.

- engine:

  Character scalar, one of `"lme4"` (default) or `"brms"`: the engine of
  the final fit (see
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)).
  The comparison of the candidate models always uses maximum likelihood
  (fast); with `"brms"`, the selected model is then refitted in a
  Bayesian framework, its convergence diagnostics are written to
  `calibration_diagnostics.csv`, and the scored detections carry
  `p_tp_lower` and `pr_reliable`.

- prior:

  `NULL`, a `brmsprior` object or a function. With `engine = "brms"`,
  the prior, as a `brmsprior` object or as a function of the selected
  formula and the validations that returns one, e.g. `calibration_prior`
  (whose classes then match the selected model). Required with `"brms"`.

- brms_args:

  A list. With `engine = "brms"`, list of further arguments for
  [`brms::brm()`](https://paulbuerkner.com/brms/reference/brm.html)
  (e.g. `list(chains = 4, cores = 4, backend = "cmdstanr")`). Without
  `seed` in this list, `seed` is also the seed of the Bayesian refit, so
  the whole run is reproducible; it is written to
  `calibration_model.txt`.

- rule:

  Character scalar, one of `"mean"` (default) or `"probability"`: when a
  detection is reliable. `"mean"`, its calibrated probability (the
  posterior mean with `engine = "brms"`) is \>= `p_min`;
  `"probability"`, the posterior probability that P(TP) \>= `p_min` (the
  `pr_reliable` of a model fitted with `engine = "brms"`) is \>=
  `prob_min`. The second rule propagates the uncertainty of the
  calibration and is more conservative where few clips were reviewed.

- prob_min:

  Numeric scalar in \[0, 1\]. With `rule = "probability"`, threshold on
  `pr_reliable`. `pr_reliable` is computed in
  [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md)
  for its `p_min`; use the same `p_min` in both.

- seed:

  Integer scalar, seed of the fold assignment. The global random number
  generator is left as it was.

- fold_group:

  `NULL` or a character vector (one or more elements) of grouping
  columns, combined into one group ID. Do not include `species`,
  verdicts or confidence scores: these would split recordings or nights
  by species or by outcome. Group IDs must be nonmissing and nonempty.
  `NULL` keeps the original clip folds.

## Value

A list with `comparison`, `quality` (from
[`calibration_quality()`](https://provetelab.org/sheepdog/reference/calibration_quality.md),
by species, or by site with one species, also written to
`calibration_quality.csv`), `fit`, `effort` (or `NULL`), `scored`,
`thresholds` and `history`, invisibly.

## Details

The candidate family follows the observed species and sites: one species
uses the site-effect family of
[`calibration_models()`](https://provetelab.org/sheepdog/reference/calibration_models.md),
and a single site omits non-estimable site random effects.

The model is chosen by
[`select_calibration_model()`](https://provetelab.org/sheepdog/reference/select_calibration_model.md)
with the rule `select`: by default, the simplest model within one
standard error of the lowest log-loss, leaving out models singular in
most folds (`"one_se_logloss"`). Use `select = "best_auc"` to reproduce
the 2.x selection by highest mean AUC. When the refit is singular,
[`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
warns; read `calibration_model.txt` and the comparison before using the
probabilities.

Wood & Kahl (2024,
[doi:10.1007/s10336-024-02144-5](https://doi.org/10.1007/s10336-024-02144-5)
) describe the conversion of BirdNET confidence scores into
probabilities for studies in which the predictions cannot all be
reviewed; calibration by logistic regression on logit(score) is applied,
for instance, by Owens et al. (2026,
[doi:10.64898/2026.06.01.729442](https://doi.org/10.64898/2026.06.01.729442)
). This function extends that approach with a hierarchical multi-species
structure. This is the function form of the v1.2.0 script
`calibracao.R`.

## Examples

``` r
# The whole workflow on the example data; outputs go to a temporary folder
# \donttest{
if (requireNamespace("lme4", quietly = TRUE)) {
  ex <- system.file("extdata", "example", package = "sheepdog")
  sites <- c("ARA", "BAI", "NHE", "XAR")
  val_files <- file.path(ex, "validation",
                         paste0("validation_by_clip_", sites, ".csv"))
  tables <- file.path(ex, "birdnet", sites, "BirdNET_SelectionTable.txt")
  names(tables) <- sites
  out <- file.path(tempdir(), "calibration")
  res <- calibrate(val_files, tables, out, k_folds = 3)
  res$comparison[c("model", "auc_mean", "logloss_mean")]
  head(res$history)
  list.files(out)
}
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
#> Cross-validation (3 folds) of 5 models...
#> Selected model (one_se_logloss): m1_species_intercept
#> Check these groups in calibration_quality.csv before using their probabilities: boa_ran, ela_bic, lep_pod, phy_cuv, pse_pla.
#> Scoring ARA (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/ARA/BirdNET_SelectionTable.txt)...
#>   1753 detections of calibrated species (0 of species NOT calibrated were dropped).
#> Scoring BAI (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/BAI/BirdNET_SelectionTable.txt)...
#>   1427 detections of calibrated species (0 of species NOT calibrated were dropped).
#> Scoring NHE (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/NHE/BirdNET_SelectionTable.txt)...
#>   2507 detections of calibrated species (0 of species NOT calibrated were dropped).
#> Scoring XAR (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/XAR/BirdNET_SelectionTable.txt)...
#>   1866 detections of calibrated species (0 of species NOT calibrated were dropped).
#> Nights with a reliable detection (p_tp >= 0.95): 339 (k = 1), 268 (k = 2), 217 (k = 3).
#> Done! Outputs in /tmp/RtmpnYqzB0/calibration
#> nightly_detection_history.csv is the input of the analyses; the column 'detection' uses k = 1; detection_k1/k2/k3 give the sensitivity to the rule.
#>  [1] "calibrated_detections_ARA.csv" "calibrated_detections_BAI.csv"
#>  [3] "calibrated_detections_NHE.csv" "calibrated_detections_XAR.csv"
#>  [5] "calibration_curves.png"        "calibration_model.rds"        
#>  [7] "calibration_model.txt"         "calibration_quality.csv"      
#>  [9] "detection_summary.csv"         "model_comparison.csv"         
#> [11] "nightly_detection_history.csv" "thresholds.csv"               
# }
```
