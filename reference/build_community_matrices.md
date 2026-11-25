# Write the community matrices

Reads the nightly detection history written by
[`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md)
and writes the matrices of
[`community_matrices()`](https://provetelab.org/sheepdog/reference/community_matrices.md)
to `output_dir`: `frequency_matrix_site_month_k<k>.csv`,
`count_matrix_site_month_k<k>.csv` and `effort_site_month.csv` (which
also lists the dropped cells). This is the function form of the v1.2.0
script `gerar_matrizes_comunidade.R`.

## Usage

``` r
build_community_matrices(
  history_file,
  output_dir,
  core_species,
  k_min = 2,
  min_nights_month = 5
)
```

## Arguments

- history_file:

  Character scalar, path to `nightly_detection_history.csv` (or a v1.2.0
  `historico_deteccao_noite.csv`).

- output_dir:

  Character scalar, path to the output folder; created if needed.

- core_species:

  Character vector of length \>= 1, species codes (the `species` column)
  that enter the matrix.

- k_min:

  Integer scalar, one of 1, 2 or 3. Repetition rule: 1, 2 or 3 reliable
  detections on the night.

- min_nights_month:

  Non-negative numeric scalar. Site x month cells with fewer recorded
  nights are dropped from the matrices (unstable frequencies) and
  flagged in `effort`.

## Value

The list returned by
[`community_matrices()`](https://provetelab.org/sheepdog/reference/community_matrices.md),
invisibly.

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
out <- file.path(tempdir(), "matrices")
build_community_matrices(file.path(ex, "nightly_detection_history.csv"),
                         output_dir = out,
                         core_species = c("boa_ran", "ela_bic",
                                          "phy_cuv"),
                         k_min = 2)
#> Matrix: 23 rows (site x month) x 3 species | rule k >= 2
#> Effort: 23 site x month cells included; 1 dropped for having < 5 recorded nights (see effort_site_month.csv)
#> Files in: /tmp/RtmppCvLSL/matrices
list.files(out)
#> [1] "count_matrix_site_month_k2.csv"     "effort_site_month.csv"             
#> [3] "frequency_matrix_site_month_k2.csv"
```
