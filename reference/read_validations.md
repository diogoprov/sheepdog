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

  `NULL` or a character vector (one or more elements) of input columns
  to retain, e.g. `c("source_audio", "night")` for grouped
  cross-validation. Missing columns raise an error rather than silently
  falling back to clip folds.

## Value

A tibble (class `tbl_df`) with `site` and `species` (factors; `species`
is the species folder code), `confidence`, `logit_conf` (logit of the
confidence, bounded at 1e-4 and 1 - 1e-4) and `tp` (1 = true positive, 0
= false positive), plus the columns requested in `keep`.

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

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
files <- list.files(file.path(ex, "validation"), full.names = TRUE)
val <- read_validations(files)
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
head(val)
#> # A tibble: 6 × 5
#>   site  species confidence logit_conf    tp
#>   <fct> <fct>        <dbl>      <dbl> <int>
#> 1 ARA   boa_ran      0.469     -0.123     0
#> 2 ARA   boa_ran      0.804      1.41      1
#> 3 ARA   boa_ran      0.867      1.87      1
#> 4 ARA   boa_ran      0.850      1.74      1
#> 5 ARA   boa_ran      0.847      1.71      1
#> 6 ARA   boa_ran      0.932      2.61      1
# Keep the recording of each clip, e.g. for grouped folds
val_rec <- read_validations(files, keep = "source_audio")
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
table(val_rec$site)
#> 
#> ARA BAI NHE XAR 
#> 593 594 640 640 
```
