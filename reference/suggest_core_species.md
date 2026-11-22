# Suggest the core species of the community matrices

Keeps the species with no unreliable site x species cell in the table of
[`cell_status()`](https://provetelab.org/sheepdog/reference/cell_status.md):
reliable at every site, or reliable where present and probably absent
elsewhere.

## Usage

``` r
suggest_core_species(status)
```

## Arguments

- status:

  A data frame (or tibble) returned by
  [`cell_status()`](https://provetelab.org/sheepdog/reference/cell_status.md).

## Value

A character vector of species codes (the `species` column of the
history).

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validations(list.files(file.path(ex, "validation"),
                                   full.names = TRUE))
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
fit <- fit_calibration(val, tp ~ logit_conf * species + site)
status <- cell_status(fit, val, p_min = 0.95, min_n = 15)
suggest_core_species(status)
#> [1] "boa_ran" "den_nan" "ela_bic" "lep_fus" "lep_pod" "phy_cuv"
```
