# Read and stack the validation tables

Stacks the `validation_by_clip.csv` tables of several runs or sites
(output of
[`post_validation()`](https://provetelab.org/sheepdog/reference/post_validation.md))
and keeps every column and every verdict, unlike
[`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md),
which keeps only what the calibration needs. Tables written by v1.2.0
(`validacao_por_clipe.csv`) are also read.

## Usage

``` r
read_validation_tables(files, candidates = NULL)
```

## Arguments

- files:

  Paths to the `validation_by_clip.csv` files. Missing files are skipped
  with a warning.

- candidates:

  For the rounds of one design: the `candidates.csv` of the first round,
  passed to
  [`combine_rounds()`](https://provetelab.org/sheepdog/reference/combine_rounds.md),
  which gives the clips their cumulative `inclusion_prob`. `NULL` only
  stacks the tables.

## Value

A tibble with the columns of the validation tables; `night` and
`recording_date` are character.
