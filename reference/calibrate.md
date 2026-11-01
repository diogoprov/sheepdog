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

  Paths to the `validation_by_clip.csv` files of the sites (v1.2.0
  `validacao_por_clipe.csv` files are also read).

- prediction_tables:

  Named character vector of the complete selection tables, named by
  site.

- output_dir:

  Output folder; created if needed. The calibrated detections of a large
  project can take hundreds of MB.

- site_map:

  Optional named character vector to fix diverging site names, as
  `c(old = "new")`, e.g. `c(BEP2 = "BEP")`.

- min_confidence:

  Detections below this confidence are not scored.

- p_min:

  Threshold on the calibrated probability (not on the confidence score).

- min_detections_night:

  Repetition rule: minimum number of reliable detections for a night
  with detection.

- dawn_hour:

  Recordings that start before this hour belong to the night before.

- k_folds:

  Number of folds.

- select:

  Rule to choose the model; see
  [`select_calibration_model()`](https://provetelab.org/sheepdog/reference/select_calibration_model.md).

- uncorrelated:

  Include the m4 variant without the species intercept-slope correlation
  among the candidates; see
  [`calibration_models()`](https://provetelab.org/sheepdog/reference/calibration_models.md).

- effort_curve:

  Draw the effort curve (slow).

- effort_n, effort_reps:

  Training sizes and repetitions of the effort curve.

- engine:

  Engine of the final fit: `"lme4"` or `"brms"` (see
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)).
  The comparison of the candidate models always uses maximum likelihood
  (fast); with `"brms"`, the selected model is then refitted in a
  Bayesian framework, its convergence diagnostics are written to
  `calibration_diagnostics.csv`, and the scored detections carry
  `p_tp_lower` and `pr_reliable`.

- prior:

  `engine = "brms"`: the prior, as a `brmsprior` object or as a function
  of the selected formula and the validations that returns one, e.g.
  `calibration_prior` (whose classes then match the selected model).
  Required with `"brms"`.

- brms_args:

  `engine = "brms"`: list of further arguments for
  [`brms::brm()`](https://paulbuerkner.com/brms/reference/brm.html)
  (e.g. `list(chains = 4, cores = 4, backend = "cmdstanr")`).

- rule:

  When a detection is reliable: `"mean"`, its calibrated probability
  (the posterior mean with `engine = "brms"`) is \>= `p_min`;
  `"probability"`, the posterior probability that P(TP) \>= `p_min` (the
  `pr_reliable` of a model fitted with `engine = "brms"`) is \>=
  `prob_min`. The second rule propagates the uncertainty of the
  calibration and is more conservative where few clips were reviewed.

- prob_min:

  `rule = "probability"`: threshold on `pr_reliable`. `pr_reliable` is
  computed in
  [`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md)
  for its `p_min`; use the same `p_min` in both.

- seed:

  Seed of the fold assignment. The global random number generator is
  left as it was.

- fold_group:

  Optional character vector of grouping columns. Do not include
  `species`, verdicts or confidence scores: these would split recordings
  or nights by species or by outcome. Group IDs must be nonmissing and
  nonempty. `NULL` keeps the original clip folds.

## Value

A list with `comparison`, `fit`, `effort` (or `NULL`), `scored` and
`history`, invisibly.

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

Converting BirdNET confidence scores into probabilities is recommended
by the BirdNET authors (Wood & Kahl 2024,
[doi:10.1007/s10336-024-02144-5](https://doi.org/10.1007/s10336-024-02144-5)
); calibration by logistic regression on logit(score) is applied, for
instance, by Owens et al. (2026,
[doi:10.64898/2026.06.01.729442](https://doi.org/10.64898/2026.06.01.729442)
). This function extends that approach with a hierarchical multi-species
structure. This is the function form of the v1.2.0 script
`calibracao.R`.
