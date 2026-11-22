# Plot the calibration curves of compare_calibration_curves()

Observed precision by score bin (points, sized by the number of clips)
and the fitted curves, by group, with the target as a dashed line. The
curves should pass through the points near the target.

## Usage

``` r
plot_calibration_curves(x, validation = NULL, bin_width = 0.1)
```

## Arguments

- x:

  A data frame (tibble), the output of
  [`compare_calibration_curves()`](https://provetelab.org/sheepdog/reference/compare_calibration_curves.md).

- validation:

  `NULL` or a data frame (or tibble) of the reviewed clips, one row per
  clip, to show bins over the whole score range. Without it, only the
  high bins of `top_error` are shown.

- bin_width:

  Numeric scalar in (0, 1), width of the bins of the observed precision,
  over the whole score range.

## Value

A ggplot object.

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
validation <- read_validation_tables(list.files(file.path(ex, "validation"),
                                                full.names = TRUE))
cmp <- compare_calibration_curves(validation, curves = "logistic",
                                  k_folds = 3)
# Observed precision over the whole score range
if (requireNamespace("ggplot2", quietly = TRUE)) {
  plot_calibration_curves(cmp, validation = validation)
}
```
