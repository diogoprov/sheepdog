# Check the quality of the calibrated probabilities by species

[`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md)
scores each model over all the clips, which can hide a species whose
probabilities should not be trusted: the mean AUC rises when species
differ in precision, even if the score says little within a species, and
partial pooling lends such a species the curve of the others. This
function refits one model by cross-validation and scores the held-out
predictions within each group, asking three questions before the
probabilities are used:

## Usage

``` r
calibration_quality(
  validations,
  formula,
  k_folds = 5,
  seed = 2026,
  fold_group = NULL,
  by = "species",
  min_class = 10,
  auc_min = 0.7,
  slope_range = c(0.5, 1.5),
  intercept_max = 1
)
```

## Arguments

- validations:

  A data frame (or tibble) returned by
  [`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md),
  one row per reviewed clip.

- formula:

  A model formula, the formula of the model to check, e.g. the one
  chosen by
  [`select_calibration_model()`](https://provetelab.org/sheepdog/reference/select_calibration_model.md).

- k_folds:

  Integer scalar \>= 2, number of folds.

- seed:

  Integer scalar, seed of the fold assignment. The global random number
  generator is left as it was.

- fold_group:

  `NULL` or a character vector (one or more elements) of grouping
  columns, combined into one group ID. Do not include `species`,
  verdicts or confidence scores: these would split recordings or nights
  by species or by outcome. Group IDs must be nonmissing and nonempty.
  `NULL` keeps the original clip folds.

- by:

  Character vector (one or more elements) of columns of `validations`
  that define the groups: `"species"`, or `c("site", "species")` for the
  cells of the calibration, which hold fewer clips each.

- min_class:

  Numeric scalar, least number of true positives and of false positives
  for a group to be judged. With fewer, `status` is `"insufficient"`.

- auc_min:

  Numeric scalar in \[0, 1\], lowest acceptable `auc` and `auc_score`.

- slope_range:

  Numeric vector of length 2, increasing: acceptable range of
  `cal_slope`.

- intercept_max:

  Numeric scalar \>= 0, largest acceptable absolute `cal_intercept`.

## Value

A tibble (class `tbl_df`) with one row per group: the `by` columns, `n`,
`n_tp`, `n_fp`, `conf_min`, `conf_max`, `auc`, `auc_score`, `logloss`,
`logloss_null`, `logloss_gain`, `cal_intercept`, `cal_slope`, `status`
(`"ok"`, `"poor"` or `"insufficient"`) and `reason`. Measures that
cannot be computed (e.g. the AUC of a group with one verdict) are `NA`.
Folds whose fit failed are left out, with a warning.

## Details

- Does the model add information? `logloss_gain` is the log-loss of a
  null model, the share of true positives of the group in the training
  folds, minus the log-loss of the model. It plays the part of a
  comparison with an intercept-only model, on held-out clips.

- Does it discriminate? `auc` is the AUC of the held-out probabilities
  within the group, and `auc_score` that of the raw confidence score. An
  `auc` well above `auc_score` means that the discrimination comes from
  other terms of the model (e.g. site effects, when `by = "species"`),
  not from the score, so both must reach `auc_min`. Unlike the AUC of
  [`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md),
  these are not reversed when the ranking is inverted, so values below
  0.5 can occur.

- Are the probabilities correct? `cal_intercept` and `cal_slope` come
  from a logistic regression of the verdicts on the logit of the
  held-out probabilities (intercept 0 and slope 1 when well calibrated).
  AUC alone does not answer this: a model can rank clips well and still
  give wrong probabilities.

The default limits behind `status` (`auc_min`, `slope_range`,
`intercept_max` and `min_class`) are provisional screening values. They
were chosen by judgement, and were neither derived from the literature
nor validated on data, so a group near a limit is not a clear pass or
fail. They are meant to direct attention to a group, and should be
reviewed and set for each project. Read the measures along with
`status`. A group marked `"poor"` needs more clips, a different model or
a decision to leave the species out of the analyses that use P(TP).

The results depend on the design of the review. Discrimination is
measured over the scores that were reviewed, so the `"top"` design,
which concentrates the clips at high scores (see `conf_min` and
`conf_max`), can give a low AUC even with a good classifier. The clips
of `"random_detections"` cover the range of scores of the predictions.

The fits use maximum likelihood, also when the final model is fitted
with `engine = "brms"`. Use `fold_group` to keep the clips of a
recording or night on the same side of the split.

## See also

[`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md),
[`calibration_ppc()`](https://provetelab.org/sheepdog/reference/calibration_ppc.md)

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validations(list.files(file.path(ex, "validation"),
                                   full.names = TRUE))
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
# Species intercepts as fixed effects, so that lme4 is not needed
q <- calibration_quality(val, tp ~ logit_conf + species, k_folds = 3)
q[c("species", "n", "auc", "auc_score", "logloss_gain", "cal_slope",
    "status")]
#> # A tibble: 8 × 7
#>   species     n   auc auc_score logloss_gain cal_slope status
#>   <fct>   <int> <dbl>     <dbl>        <dbl>     <dbl> <chr> 
#> 1 boa_ran   320 0.974     0.974       0.356      2.37  poor  
#> 2 den_nan   320 0.792     0.792       0.140      0.875 ok    
#> 3 ela_bic   320 0.997     0.996       0.238      3.51  poor  
#> 4 lep_fus   249 0.782     0.788       0.126      0.800 ok    
#> 5 lep_pod   298 0.992     0.993       0.289      2.77  poor  
#> 6 phy_cuv   320 0.983     0.984       0.226      2.33  poor  
#> 7 pse_pla   320 0.544     0.543      -0.116      0.173 poor  
#> 8 sci_nas   320 0.729     0.738       0.0664     0.596 ok    
```
