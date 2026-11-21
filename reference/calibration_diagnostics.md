# Convergence diagnostics of a Bayesian calibration model

Reports the largest R-hat, the smallest bulk and tail effective sample
sizes and the number of divergent transitions of a model fitted with
`engine = "brms"`, and whether they pass the usual limits.

## Usage

``` r
calibration_diagnostics(fit, rhat_max = 1.01, ess_min = 400)
```

## Arguments

- fit:

  Model returned by
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
  with `engine = "brms"`.

- rhat_max:

  Largest acceptable R-hat.

- ess_min:

  Smallest acceptable bulk and tail effective sample size.

## Value

A one-row tibble with `max_rhat`, `min_ess_bulk`, `min_ess_tail`,
`n_divergent` and `ok`.

## Details

R-hat is the rank-normalised, folded split-R-hat and the effective
sample sizes are the bulk and tail ESS of Vehtari et al. (2021,
[doi:10.1214/20-BA1221](https://doi.org/10.1214/20-BA1221) ), computed
by
[`posterior::summarise_draws()`](https://mc-stan.org/posterior/reference/draws_summary.html)
over all the parameters of the model. The defaults (R-hat \<= 1.01, bulk
and tail ESS \>= 400) are the limits recommended in that paper for 4
chains. Divergent transitions are read from the NUTS parameters of the
fit
([`brms::nuts_params()`](https://mc-stan.org/bayesplot/reference/bayesplot-extractors.html)),
so only models sampled with NUTS can be checked.

The diagnostics are summaries; inspect the chains as well. `plot(fit)`
(a method of 'brms') draws the trace and the density of the post-warmup
draws of each population-level parameter. To see the warmup next to the
sampling phase, use
[`bayesplot::mcmc_trace()`](https://mc-stan.org/bayesplot/reference/MCMC-traces.html)
with its `n_warmup` argument on
`brms::as_draws_array(fit, inc_warmup = TRUE)`, which requires the
warmup draws to have been saved by the Stan backend.
