# Posterior predictive checks of a Bayesian calibration model

Compares the observed share of true positives among the reviewed clips
with its posterior predictive distribution, overall and within groups:
bins of score (a reliability check), sites, species and any column of
the validation data given in `group` (e.g. the month of the recording).
A calibration that fits on average can still miss within groups: a
detector whose precision drifts with the season, for instance, shows up
as months with observed shares outside their predictive intervals, and
would bias the detection histories built from the model.

## Usage

``` r
calibration_ppc(
  fit,
  validations = NULL,
  group = NULL,
  bin_width = 0.1,
  min_n = 15,
  prob = 0.9,
  flag = 0.05,
  n_draws = NULL,
  seed = 2026
)
```

## Arguments

- fit:

  Model returned by
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
  with `engine = "brms"`.

- validations:

  The calibration data the model was fitted to, in the same row order,
  with any columns named in `group` (keep them with
  `read_validations(keep = )`). `NULL` uses the data stored in `fit`,
  which only hold the columns of the formula.

- group:

  Optional character vector of columns of `validations` to check within,
  besides score bins, sites and species.

- bin_width:

  Width of the score bins. Bins with fewer than `min_n` clips are merged
  with their neighbour.

- min_n:

  Smallest number of clips in a score bin.

- prob:

  Probability of the predictive interval.

- flag:

  Groups with a p-value below `flag` or above `1 - flag` are flagged.

- n_draws:

  Number of posterior draws; `NULL` uses all.

- seed:

  Seed of the choice of draws and of the predictive simulation. The
  global random number generator is left as it was.

## Value

A tibble with one row per check and group: `check` (`"overall"`,
`"score"`, `"site"`, `"species"` or a column of `group`), `group`, `n`
(clips), `observed` (share of true positives), `pred_mean`, `pred_lower`
and `pred_upper` (posterior predictive mean and interval of the share),
`p_value` and `flagged`. Plot it with
[`plot_calibration_ppc()`](https://provetelab.org/sheepdog/reference/plot_calibration_ppc.md).

## Details

For each group, the test statistic is the share of true positives,
\\T(y) = \bar y\\, and the Bayesian p-value is the mid-p
\\\Pr(T(y^{rep}) \> T(y)) + \Pr(T(y^{rep}) = T(y)) / 2\\, so that ties,
frequent in small groups of binary verdicts, count half on each side.
Values close to 0 or 1 mean that the model under- or over-predicts the
share of true positives in that group (Gelman et al. 2013, *Bayesian
Data Analysis*, 3rd ed., ch. 6). The checks reuse the clips the model
was fitted to, so they are lenient: a flagged group is a misfit worth
modelling (e.g. a group effect in the calibration formula), whereas no
flag is not proof of a good fit.

## See also

[`calibration_diagnostics()`](https://provetelab.org/sheepdog/reference/calibration_diagnostics.md)
for convergence, which should be checked first.
