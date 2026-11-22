# Read the validation tables for calibration

Stacks the `validation_by_clip.csv` tables of several sites (output of
[`post_validation()`](https://provetelab.org/sheepdog/reference/post_validation.md))
and keeps the clips with a positive or negative verdict and a confidence
score. Tables written by v1.2.0 (`validacao_por_clipe.csv`) are also
read. Whole-recording clips of `"random_recordings"` have no confidence
and are left out.

## Usage

``` r
read_validations(files, site_map = NULL, keep = NULL)
```

## Arguments

- files:

  Character vector, paths to the `validation_by_clip.csv` files. Missing
  files are skipped with a warning.

- site_map:

  `NULL` or a named character vector to fix diverging site names, as
  `c(old = "new")`, e.g. `c(BEP2 = "BEP")`.

- keep:

  `NULL` or a character vector of input columns to retain, e.g.
  `c("source_audio", "night")` for grouped cross-validation. Missing
  columns raise an error rather than silently falling back to clip
  folds.

## Value

A tibble with `site` and `species` (factors; `species` is the species
folder code), `confidence`, `logit_conf` (logit of the confidence,
bounded at 1e-4 and 1 - 1e-4) and `tp` (1 = true positive, 0 = false
positive), plus the columns requested in `keep`.

## Transformations

The confidence is bounded at 1e-4 and 1 - 1e-4 before the logit
([`stats::qlogis()`](https://rdrr.io/r/stats/Logistic.html)), so that
scores of 0 or 1 give finite values; `stats::plogis(logit_conf)` returns
the bounded confidence. The verdict becomes the binary response `tp`,
and `site` and `species` become factors whose levels (in alphabetical
order) are stored by
[`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)
with the model. These transformations are always applied, because the
calibration models and
[`score_detections()`](https://provetelab.org/sheepdog/reference/score_detections.md)
expect them; the original `confidence` is kept alongside `logit_conf`.
