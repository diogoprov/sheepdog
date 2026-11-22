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

  A model returned by
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
  (`glm`, `glmerMod` or `brmsfit`).

- validations:

  A data frame (or tibble) returned by
  [`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md),
  with columns `site`, `species`, `confidence` and `tp`: the clips the
  model was fitted to, one row per clip.

- p_min:

  Numeric scalar in (0, 1). Calibrated probability that makes a
  detection reliable, as in
  [`detection_history()`](https://provetelab.org/sheepdog/reference/detection_history.md).

- min_n:

  Non-negative numeric scalar. Minimum number of reviewed clips in a
  cell.

- by:

  `NULL` or a character vector of column names of `validations` that
  split each cell, e.g. the bin of an environmental gradient or of an
  acoustic index from
  [`covariate_bins()`](https://provetelab.org/sheepdog/reference/covariate_bins.md)
  (kept by `read_validations(keep = )` or joined afterwards). Each site
  x species x `by` cell gets its own status; the threshold uses the `by`
  columns only if the calibration model does.

## Value

A tibble (class `tbl_df`) with one row per site x species (x `by`):
`site`, `species`, the `by` columns, `n_reviewed`, `n_tp`,
`max_confidence` (highest reviewed score), `threshold` (lowest grid
score at which the calibrated probability reaches `p_min`; `NA` if
never), `status` and `reason`. The grid contains both observed endpoints
and steps of 0.01 within the reviewed range.

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

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validations(list.files(file.path(ex, "validation"),
                                   full.names = TRUE))
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
# A logistic calibration with fixed effects only
fit <- fit_calibration(val, tp ~ logit_conf * species + site)
status <- cell_status(fit, val, p_min = 0.95, min_n = 15)
table(status$species, status$status)
#>          
#>           probably_absent reliable unreliable
#>   boa_ran               0        4          0
#>   den_nan               0        4          0
#>   ela_bic               0        4          0
#>   lep_fus               2        2          0
#>   lep_pod               0        4          0
#>   phy_cuv               0        4          0
#>   pse_pla               0        0          4
#>   sci_nas               0        2          2
```
