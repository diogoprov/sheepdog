# Plot the precision curves

One panel per species: precision by confidence bin, with the target
precision as a dashed line and bins with low support shown faded. With
more than one site, each site is a line of its own colour. Needs the
'ggplot2' package.

## Usage

``` r
plot_precision(
  precision,
  bins = seq(0.1, 1, by = 0.1),
  target_precision = 0.9,
  min_n = 15
)
```

## Arguments

- precision:

  A data frame (or tibble) returned by
  [`precision_by_bin()`](https://provetelab.org/sheepdog/reference/precision_by_bin.md).

- bins:

  Numeric vector of length \>= 2, increasing breaks of the confidence
  bins (left-closed).

- target_precision:

  Numeric scalar in (0, 1). Target precision.

- min_n:

  Integer scalar \>= 1. Minimum of reviewed clips for a bin to be taken
  seriously; bins with fewer are flagged in `low_support`.

## Value

A ggplot object.
