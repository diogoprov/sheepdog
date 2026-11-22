# Plot posterior predictive checks of a calibration model

Draws, for one check of
[`calibration_ppc()`](https://provetelab.org/sheepdog/reference/calibration_ppc.md),
the observed share of true positives of each group over its posterior
predictive mean and interval. Flagged groups are drawn as crosses.

## Usage

``` r
plot_calibration_ppc(ppc, check = "score")
```

## Arguments

- ppc:

  A data frame (tibble) returned by
  [`calibration_ppc()`](https://provetelab.org/sheepdog/reference/calibration_ppc.md).

- check:

  Character scalar, the check to draw: `"score"`, `"site"`, `"species"`,
  `"overall"` or a column given in `group`.

## Value

A ggplot object.

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validations(list.files(file.path(ex, "validation"),
                                   full.names = TRUE),
                        keep = "recording_date")
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
val$month <- substr(val$recording_date, 5, 6)
# Fitting compiles a Stan model, which takes minutes, so it is not run here.
if (FALSE) { # \dontrun{
f <- tp ~ logit_conf + (1 | species)
fit_b <- fit_calibration(val, f, engine = "brms",
                         prior = calibration_prior(f, val),
                         chains = 4, iter = 2000, seed = 1, refresh = 0)
ppc <- calibration_ppc(fit_b, val, group = "month")
plot_calibration_ppc(ppc, check = "score")
plot_calibration_ppc(ppc, check = "month")
} # }
```
