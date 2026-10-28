# Status of each site x species cell for the community matrices

Classifies each site x species cell of the calibration by whether its
detections can enter a community matrix, separating the absence of a
species from a calibration that does not work:

## Usage

``` r
cell_status(fit, validations, p_min = 0.95, min_n = 15, by = NULL)
```

## Arguments

- fit:

  Model returned by
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md).

- validations:

  Table returned by
  [`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md),
  the clips the model was fitted to.

- p_min:

  Calibrated probability that makes a detection reliable, as in
  [`detection_history()`](https://provetelab.org/sheepdog/reference/detection_history.md).

- min_n:

  Minimum number of reviewed clips in a cell.

- by:

  Optional columns of `validations` that split each cell, e.g. the bin
  of an environmental gradient or of an acoustic index from
  [`covariate_bins()`](https://provetelab.org/sheepdog/reference/covariate_bins.md)
  (kept by `read_validations(keep = )` or joined afterwards). Each site
  x species x `by` cell gets its own status; the threshold uses the `by`
  columns only if the calibration model does.

## Value

A tibble with one row per site x species (x `by`): `site`, `species`,
the `by` columns, `n_reviewed`, `n_tp`, `max_confidence` (highest
reviewed score), `threshold` (lowest grid score at which the calibrated
probability reaches `p_min`; `NA` if never), `status` and `reason`. The
grid contains both observed endpoints and steps of 0.01 within the
reviewed range.

## Details

- `"reliable"`: the calibrated curve reaches `p_min` within the range of
  reviewed scores of the cell, and the cell has at least `min_n`
  reviewed clips;

- `"probably_absent"`: clips were reviewed but none was a true positive.
  The species can enter the matrix with zeros at that site;

- `"unreliable"`: true positives were reviewed, but the curve never
  reaches `p_min` within the reviewed scores, or the cell has fewer than
  `min_n` reviewed clips, or no clip at all was reviewed. A zero in such
  a cell could be a false negative.

[`suggest_core_species()`](https://provetelab.org/sheepdog/reference/suggest_core_species.md)
keeps the species without unreliable cells. The final choice of core
species remains with the analyst.
