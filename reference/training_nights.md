# Nights and recordings of clips used to train a classifier

Reads the site, date and time of the source recording from the names of
training clips (of the current classifier, or of the reference library
folders of another one) and returns their recordings and nights. Pass
the result to `exclude_from_test` of
[`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md),
so that a test set does not hold nights another compared classifier was
trained on, or to
[`exclude_training_clips()`](https://provetelab.org/sheepdog/reference/exclude_training_clips.md).

## Usage

``` r
training_nights(
  files,
  pattern = paste0("(?<site>[A-Za-z]+)[A-Za-z0-9]*",
    "_(?<date>\\d{8})_(?<time>\\d{6})"),
  site_map = NULL,
  night_cutoff = 12
)
```

## Arguments

- files:

  File names or paths of training clips. Elements that are folders are
  listed recursively.

- pattern:

  Perl regular expression with the named groups `site`, `date`
  (`YYYYMMDD`) and `time` (`HHMMSS`). The default takes the letters
  before the recorder number, the date and the time of names such as
  `ARA01_20211016_190000` or
  `..._ARA_ARA01_20230121_203000_12.0s_15.0s.wav`.

- site_map:

  Optional named character vector to fix diverging site names, e.g.
  `c(BEP2 = "BEP")`, as in
  [`read_validations()`](https://provetelab.org/sheepdog/reference/read_validations.md).

- night_cutoff:

  Recordings that start before this hour belong to the night of the day
  before, as in
  [`detection_history()`](https://provetelab.org/sheepdog/reference/detection_history.md).

## Value

A tibble with `file`, `site`, `recording` (site, date and time of the
source recording, before `site_map`) and `night` (`YYYYMMDD`). Names
that do not match `pattern` are left out with a warning.

## See also

[`build_training_set()`](https://provetelab.org/sheepdog/reference/build_training_set.md),
[`exclude_training_clips()`](https://provetelab.org/sheepdog/reference/exclude_training_clips.md).

## Examples

``` r
training_nights(c("ARA01_20211016_190000_3.0s_6.0s.wav",
                  "ARA01_20211017_013000_9.0s_12.0s.wav",
                  "FNJV_0042_Boana_raniceps.wav"))
#> Warning: 1 file name(s) do not match `pattern` and were left out: FNJV_0042_Boana_raniceps.wav
#> # A tibble: 2 × 4
#>   file                                 site  recording           night   
#>   <chr>                                <chr> <chr>               <chr>   
#> 1 ARA01_20211016_190000_3.0s_6.0s.wav  ARA   ARA_20211016_190000 20211016
#> 2 ARA01_20211017_013000_9.0s_12.0s.wav ARA   ARA_20211017_013000 20211016
```
