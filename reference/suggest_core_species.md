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
