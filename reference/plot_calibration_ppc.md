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

  Table returned by
  [`calibration_ppc()`](https://provetelab.org/sheepdog/reference/calibration_ppc.md).

- check:

  The check to draw: `"score"`, `"site"`, `"species"`, `"overall"` or a
  column given in `group`.

## Value

A ggplot object.
