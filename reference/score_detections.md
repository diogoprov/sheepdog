# Score every detection with the calibration model

Reads the complete BirdNET selection tables, or takes a table of
predictions already read (not only the reviewed clips), and predicts,
for each detection, the probability that it is a true positive. Only
species present in the calibration are scored. The night of each
detection is its recording date, or the day before for recordings that
start before `dawn_hour`.

## Usage

``` r
score_detections(
  tables,
  fit,
  min_confidence = 0.1,
  dawn_hour = 12,
  p_min = 0.95,
  lower_prob = 0.05,
  grid_step = 0.01
)
```

## Arguments

- tables:

  Either a data frame (or tibble) of predictions, one row per
  prediction, with the columns `site`, `species_code`, `confidence`,
  `begin_path` and `file_offset`, as returned by
  [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md)
  or
  [`read_classifier_output()`](https://provetelab.org/sheepdog/reference/read_classifier_output.md);
  or a named character vector, one element per site, named by site (the
  site names of the calibration): the path of the combined selection
  table of each site, or the folder of its per-audio tables (see
  [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md)).

- fit:

  A `glm`, `glmerMod` or `brmsfit` returned by
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md).

- min_confidence:

  Numeric scalar in \[0, 1\]. Detections below this confidence are not
  scored.

- dawn_hour:

  Numeric scalar in \[0, 24\]. Recordings that start before this hour
  belong to the night before.

- p_min, lower_prob:

  Numeric scalars, `p_min` in \[0, 1\] and `lower_prob` in (0, 1).
  Models fitted with `engine = "brms"`: the threshold of `pr_reliable`
  and the probability of the lower quantile `p_tp_lower`.

- grid_step:

  Numeric scalar in (0, 0.5). Models fitted with `engine = "brms"`: step
  of the grid of scores on which the posterior is computed.

## Value

A tibble with `site`, `species`, `date`, `night`, `hour`, `confidence`,
`p_tp`, `begin_path` and `file_offset`; with a model fitted with
`engine = "brms"`, also `p_tp_lower` and `pr_reliable`.

## Details

With a model fitted with `engine = "brms"`, the posterior of P(TP) is
computed once on a grid of scores (step `grid_step`) for each site x
species and assigned to the detections by their score rounded to the
grid, so that the cost does not depend on the number of detections; the
rounding error is small next to the uncertainty of the calibration. Each
detection then gets the posterior mean (`p_tp`), a lower quantile
(`p_tp_lower`) and the posterior probability that P(TP) \>= `p_min`
(`pr_reliable`).
[`detection_history()`](https://provetelab.org/sheepdog/reference/detection_history.md)
can use either rule.

Sites or species levels absent from the calibration are new levels for
the model. Detections of species that were not calibrated are dropped
(with a message giving their number). Detections at a site that was not
in the calibration are scored with a warning. With a `glm` or `glmerMod`
model (`allow.new.levels = TRUE` of 'lme4'), the effects of the new site
are set to zero, so P(TP) comes from the fixed and species effects only.
With a `brmsfit` (`allow_new_levels = TRUE` of 'brms'), the effects of
the new site are drawn from the fitted random-effects distribution,
which widens the posterior of P(TP).

## Examples

``` r
ex <- system.file("extdata", "example", package = "sheepdog")
val <- read_validations(list.files(file.path(ex, "validation"),
                                   full.names = TRUE))
#> 2467 reviewed clips (1577 TP / 890 FP) of 8 species at 4 sites.
fit <- fit_calibration(val, tp ~ logit_conf + species)
sites <- c("ARA", "BAI", "NHE", "XAR")
tables <- file.path(ex, "birdnet", sites, "BirdNET_SelectionTable.txt")
names(tables) <- sites
scored <- score_detections(tables, fit, min_confidence = 0.1)
#> Scoring ARA (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/ARA/BirdNET_SelectionTable.txt)...
#>   1753 detections of calibrated species (0 of species NOT calibrated were dropped).
#> Scoring BAI (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/BAI/BirdNET_SelectionTable.txt)...
#>   1427 detections of calibrated species (0 of species NOT calibrated were dropped).
#> Scoring NHE (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/NHE/BirdNET_SelectionTable.txt)...
#>   2507 detections of calibrated species (0 of species NOT calibrated were dropped).
#> Scoring XAR (/home/runner/work/_temp/Library/sheepdog/extdata/example/birdnet/XAR/BirdNET_SelectionTable.txt)...
#>   1866 detections of calibrated species (0 of species NOT calibrated were dropped).
head(scored)
#> # A tibble: 6 × 9
#>   site  species date     night     hour confidence  p_tp begin_path  file_offset
#>   <chr> <fct>   <chr>    <chr>    <int>      <dbl> <dbl> <chr>             <dbl>
#> 1 ARA   boa_ran 20211001 20211001    19      0.504 0.512 "N:\\pam\\…          57
#> 2 ARA   den_nan 20211001 20211001    19      0.372 0.147 "N:\\pam\\…          66
#> 3 ARA   lep_fus 20211001 20211001    19      0.267 0.111 "N:\\pam\\…         150
#> 4 ARA   pse_pla 20211001 20211001    19      0.873 0.744 "N:\\pam\\…         165
#> 5 ARA   lep_pod 20211001 20211001    19      0.846 0.969 "N:\\pam\\…         174
#> 6 ARA   lep_pod 20211001 20211001    19      0.479 0.640 "N:\\pam\\…         177
```
