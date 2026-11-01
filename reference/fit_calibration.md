# Fit the calibration model

Fits a calibration model to all the reviewed clips. The species and site
levels of `validations` are stored with the model, so that
[`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md)
can score new detections.

## Usage

``` r
fit_calibration(
  validations,
  formula,
  engine = c("lme4", "brms"),
  prior = NULL,
  ...
)
```

## Arguments

- validations:

  Table returned by
  [`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md).

- formula:

  Model formula, usually the best one of
  [`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md).

- engine:

  `"lme4"` or `"brms"`.

- prior:

  `engine = "brms"`: the prior (a `brmsprior` object), e.g. from
  [`calibration_prior()`](https://provetelab.org/sheepdog/reference/calibration_prior.md).
  Required.

- ...:

  `engine = "brms"`: further arguments for
  [`brms::brm()`](https://paulbuerkner.com/brms/reference/brm.html)
  (e.g. `chains`, `iter`, `cores`, `backend`, `seed`).

## Value

A `glm`, `glmerMod` or `brmsfit` model, with the attribute
`sheepdog_levels` (the species and site levels), used by
[`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md)
and
[`plot_calibration()`](https://provetelab.org/sheepdog/reference/plot_calibration.md).

## Details

With `engine = "lme4"` (default), the model is fitted by maximum
likelihood ('lme4' for random effects,
[`glm()`](https://rdrr.io/r/stats/glm.html) otherwise). A model with
random effects whose fit is singular (a variance estimated at zero or a
correlation at +-1) raises a warning: the fixed effects and the
predictions can still be used, but the variance components on the
boundary should not be interpreted, and a simpler model may predict as
well. Check them with
[`lme4::VarCorr()`](https://rdrr.io/pkg/nlme/man/VarCorr.html). The
other messages of
[`lme4::glmer()`](https://rdrr.io/pkg/lme4/man/glmer.html) are passed
on, prefixed by `lme4:`, and every message of the fit is kept in the
attribute `sheepdog_messages` of the model (convergence warnings of
'lme4' are warnings and are passed on as such).

With `engine = "brms"`, the model is fitted in a Bayesian framework with
'brms' (Bernoulli family, logit link). The prior must be given
explicitly;
[`calibration_prior()`](https://provetelab.org/sheepdog/reference/calibration_prior.md)
builds an example centred on an already calibrated score. After the fit,
[`calibration_diagnostics()`](https://provetelab.org/sheepdog/reference/calibration_diagnostics.md)
runs and a warning is raised when R-hat, the effective sample sizes or
the divergent transitions fail the usual limits. Check the prior with
[`prior_predictive_calibration()`](https://provetelab.org/sheepdog/reference/prior_predictive_calibration.md),
the fit with
[`brms::pp_check()`](https://mc-stan.org/bayesplot/reference/pp_check.html)
and the sensitivity to the prior with
[`calibration_sensitivity()`](https://provetelab.org/sheepdog/reference/calibration_sensitivity.md).
