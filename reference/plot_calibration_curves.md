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

  Output of
  [`compare_calibration_curves()`](https://provetelab.org/sheepdog/reference/compare_calibration_curves.md).

- validation:

  Optional: the reviewed clips, to show bins over the whole score range.
  Without it, only the high bins of `top_error` are shown.

- bin_width:

  Width of the bins of the observed precision, over the whole score
  range.

## Value

A ggplot object.
