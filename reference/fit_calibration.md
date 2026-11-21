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
  (e.g. `chains`, `iter`, `cores`, `backend`, `seed`). Without `seed`,
  one is drawn from R's random number generator (so
  [`set.seed()`](https://rdrr.io/r/base/Random.html) before the call
  makes the fit reproducible) and passed to
  [`brms::brm()`](https://paulbuerkner.com/brms/reference/brm.html).

## Value

A `glm`, `glmerMod` or `brmsfit` model, with the attribute
`sheepdog_levels` (the species and site levels), used by
[`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md)
and
[`plot_calibration()`](https://provetelab.org/sheepdog/reference/plot_calibration.md).
A `brmsfit` also carries the attribute `sheepdog_seed`, the seed given
to Stan, so that the fit can be repeated.

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

## Formula and model matrix

The formula uses the syntax of 'lme4' for random effects
(`(term | group)`) and is turned into model matrices by the fitting
function itself: [`stats::glm()`](https://rdrr.io/r/stats/glm.html) for
a formula without random effects,
[`lme4::glmer()`](https://rdrr.io/pkg/lme4/man/glmer.html) otherwise, or
[`brms::brm()`](https://paulbuerkner.com/brms/reference/brm.html).
sheepdog does not build the matrices. The response is `tp` (1 = true
positive, 0 = false positive) and the predictor of the score is
`logit_conf`, the logit of the BirdNET confidence bounded at 1e-4 and
1 - 1e-4 (see
[`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md));
the inverse transform, from the linear predictor to P(TP), is
[`stats::plogis()`](https://rdrr.io/r/stats/Logistic.html). Only the
columns named in the formula enter the model: the other columns of
`validations` (for example those kept with `keep` in
[`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md))
are neither used nor stored in the fitted object. The species and site
levels are stored in the attribute `sheepdog_levels`.

## Input checks and missing values

`validations` must be a data frame (a tibble, `data.frame` or
`data.table`; it is converted to a tibble) with the columns `site` and
`species` (factors or character vectors; ordered factors are used as
unordered), `tp` (0/1, or logical) and every variable of `formula`,
usually `logit_conf` (numeric, without NaN or infinite values; extra
classes such as 'units' are dropped). The response of `formula` must be
`tp`. Rows with a missing value in a variable of the formula are left
out with a message; this policy is fixed, the same in both engines, and
no missing value reaches the fitting function. Before the fit, an error
is raised when all the clips have the same verdict or when the fixed
effects are collinear (rank-deficient model matrix), a warning when the
verdicts are completely separated by the score (the maximum likelihood
slope is then infinite), and a message lists species with a single
verdict class or separated verdicts. With `engine = "brms"`, `prior`
must be a `brmsprior` object.

## Maximum likelihood fit

Models with random effects are fitted by
[`lme4::glmer()`](https://rdrr.io/pkg/lme4/man/glmer.html) with
`lme4::glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5))`:
the bound optimisation by quadratic approximation, with up to 100000
function evaluations, a larger budget than the 'lme4' default, for the
correlated random slopes of the larger calibration models. The
convergence tolerances are those of 'lme4' and cannot be changed from
sheepdog; convergence warnings of 'lme4' are passed on. Models without
random effects use the iteratively reweighted least squares of
[`stats::glm()`](https://rdrr.io/r/stats/glm.html) with its default
control.

## Bayesian computation

With `engine = "brms"`, the posterior is sampled with the No-U-Turn
Sampler (NUTS) of Stan (Carpenter et al. 2017,
[doi:10.18637/jss.v076.i01](https://doi.org/10.18637/jss.v076.i01) )
through 'brms' (Bürkner 2017,
[doi:10.18637/jss.v080.i01](https://doi.org/10.18637/jss.v080.i01) ).
The computational settings are those of
[`brms::brm()`](https://paulbuerkner.com/brms/reference/brm.html) unless
they are given in `...`: 4 chains of 2000 iterations each, of which the
first half (`warmup = floor(iter / 2)`) is warmup, without thinning
(`thin = 1`), and random initial values (`init = NULL`). Initial values
can be set with `init`, passed on to
[`brms::brm()`](https://paulbuerkner.com/brms/reference/brm.html); to
start from a previous fit, pass its posterior means as `init` or refit
the model. [`stats::update()`](https://rdrr.io/r/stats/update.html) on
the returned `brmsfit` runs the sampler again but returns an object
without the attributes `sheepdog_levels` and `sheepdog_seed`, so a model
refitted that way cannot be passed to
[`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md);
call `fit_calibration()` again instead.

Only NUTS is supported. Other algorithms of
[`brms::brm()`](https://paulbuerkner.com/brms/reference/brm.html)
(`algorithm = "meanfield"`, for instance) can be passed through `...`,
but
[`calibration_diagnostics()`](https://provetelab.org/sheepdog/reference/calibration_diagnostics.md),
which reads the NUTS parameters, then fails. The convergence checks of
[`calibration_diagnostics()`](https://provetelab.org/sheepdog/reference/calibration_diagnostics.md)
always run after the fit and cannot be switched off; a model that fails
them raises a warning, which
[`suppressWarnings()`](https://rdrr.io/r/base/warning.html) silences.
sheepdog has no verbosity argument of its own: the progress output of
Stan is controlled by `refresh` (e.g. `refresh = 0`, passed on to the
Stan backend) and `silent` (e.g. `silent = 2`) of
[`brms::brm()`](https://paulbuerkner.com/brms/reference/brm.html), and
the messages of sheepdog by
[`suppressMessages()`](https://rdrr.io/r/base/message.html).

## Methods for the fitted model

The returned object keeps the class of the fitting function, so the
methods of `stats`, 'lme4' and 'brms' apply. Confidence intervals of the
coefficients come from
[`stats::confint()`](https://rdrr.io/r/stats/confint.html) for `glm` and
`glmerMod` models (profile likelihood by default; `method = "Wald"` for
a faster approximation of a `glmerMod`), and credible intervals from
[`brms::posterior_interval()`](https://mc-stan.org/rstantools/reference/posterior_interval.html)
or [`summary()`](https://rdrr.io/r/base/summary.html) for a `brmsfit`.
[`stats::residuals()`](https://rdrr.io/r/stats/residuals.html) returns
deviance residuals for `glm` and `glmerMod` models and, for a `brmsfit`,
the posterior summary of the response residuals (observed minus fitted
probability). With a binary response, residuals take two values for each
fitted probability and say little one by one; check the fit with the
calibration intercept and slope of
[`compare_calibration_models()`](https://provetelab.org/sheepdog/reference/compare_calibration_models.md),
with
[`calibration_quality()`](https://provetelab.org/sheepdog/reference/calibration_quality.md),
or with the binned posterior predictive check of
[`calibration_ppc()`](https://provetelab.org/sheepdog/reference/calibration_ppc.md)
for a `brmsfit`.

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validations(list.files(file.path(ex, "validation"),
                                   full.names = TRUE))
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
# Maximum likelihood, one species-level random intercept
if (requireNamespace("lme4", quietly = TRUE)) {
  fit <- fit_calibration(val, tp ~ logit_conf + (1 | species))
  print(lme4::fixef(fit))
  confint(fit, method = "Wald", parm = "beta_")
}
#> (Intercept)  logit_conf 
#>  -0.2060523   1.6030183 
#>                  2.5 %    97.5 %
#> (Intercept) -0.9305499 0.5184454
#> logit_conf   1.4584248 1.7476119

# Bayesian fit: the prior is always given explicitly. Fitting compiles a
# Stan model, which takes minutes, so this part is not run here.
if (FALSE) { # \dontrun{
f <- tp ~ logit_conf + (1 | species)
prior <- calibration_prior(f, val)
fit_b <- fit_calibration(val, f, engine = "brms", prior = prior,
                         chains = 4, iter = 2000, seed = 1,
                         refresh = 0)
calibration_diagnostics(fit_b)
brms::posterior_interval(fit_b)
} # }
```
