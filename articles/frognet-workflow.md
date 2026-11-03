# The FrogNet workflow

This vignette walks through the three stages of sheepdog as used in the
FrogNet project (anurans of the Pantanal and Cerrado, Mato Grosso do
Sul, Brazil). Paths, site names and the core species come from the
FrogNet scripts of v1.2.0; settings marked “example” are illustrative.
The FrogNet data are not distributed with the package, so the chunks
that read them are not run; the last section runs on the example files
shipped with the package.

``` r

library(sheepdog)
```

## Stage 1a: clips to validate

Each site folder holds a `BirdNET_SelectionTable.txt` that concatenates
the predictions of the custom classifier on every recording of the site.
It is written by the BirdNET GUI when “Combine selection tables” is
checked in the output settings. By default the GUI writes one table per
audio file instead; sheepdog reads those too and stacks the tables of
each site folder. The recordings live on a NAS mapped as `N:/` on
Windows; on a Mac the same paths are remapped.

Check the selection first with `simulate = TRUE`: the manifest is
written, but no audio is cut.

``` r

extract_validation_clips(
  data_dir   = "N:/Arara",
  output_dir = "N:/Arara/validation",
  n_top = 2,                     # top 2 per site x species x night x hour
  min_confidence = 0.1,
  hour_start = 17, hour_end = 2, # example: nights, small hours go to the
  alternate_days = TRUE,         #   night before; alternate nights
  target_total = 4000,           # clips per site, balanced among species
  balance_by_hour = TRUE,
  remap_from = "N:/", remap_to = "/Volumes/Arara/",
  simulate = TRUE
)
```

Then rerun with `simulate = FALSE` (the default). The clips go to
`validation/clips/<species>/`, one zip per species to
`validation/packages/`, and the map from each clip to its source to
`validation/clip_manifest.csv`. A rerun skips the clips already cut.

The steps can also run one by one.
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
is pure: it returns the manifest without touching audio, which helps to
try designs.

``` r

pred <- read_selection_tables("N:/Arara")
man  <- select_clips(pred, n_top = 2, target_total = 4000,
                     remap_from = "N:/", remap_to = "/Volumes/Arara/")
man  <- cut_clips(man, "N:/Arara/validation")
pack_clips(man, "N:/Arara/validation")
```

### Estimating false-positive rates

The `"top"` design serves retraining and calibration, not the estimation
of false-positive rates for occupancy models. For that, draw occasions
at random among those with a detection, with the same threshold as the
occupancy analysis (observation-confirmation design):

``` r

extract_validation_clips(
  "N:/Arara", "N:/Arara/validation_random",
  sampling_mode = "random_detections", threshold = 0.5,  # example values
  occasion_unit = "file", n_top = 1, target_total = 300,
  remap_from = "N:/", remap_to = "/Volumes/Arara/"
)
```

Every detection \>= 0.5 of a drawn occasion is cut, and the manifest
records `inclusion_prob`. See
[`vignette("crywolf-integration")`](https://provetelab.org/sheepdog/articles/crywolf-integration.md)
for the hand-off to occupancy models.

## Stage 1b: after the review

The reviewers classify the clips in the review tab of the BirdNET GUI,
which moves each clip into `Positive/` or `Negative/` subfolders.

``` r

# a FrogNet run cut by v1.2.0: the old manifest is read as well
post_validation(
  review_dir    = "E:/validacao_UEMS_meta4000/clipes",
  manifest_path = "E:/validacao_UEMS_meta4000/manifesto_clipes.csv",
  output_dir    = "E:/validacao_UEMS_meta4000/results",
  target_precision = 0.90, min_n = 15
)
```

This writes `validation_by_clip.csv` (the verdict of each clip), the
precision by confidence bin, the lowest threshold reaching the target
precision by species, the confirmed presence by night and the positive
clips for retraining.

A round reviewed in the sheepdog app
([`run_app()`](https://provetelab.org/sheepdog/reference/run_app.md))
has a verdicts file instead of subfolders.
[`post_validation()`](https://provetelab.org/sheepdog/reference/post_validation.md)
reads it with `verdicts_file`; `review_dir` then only points to the
clips:

``` r

post_validation(
  review_dir    = "N:/Arara/validation_random/clips",
  manifest_path = "N:/Arara/validation_random/clip_manifest.csv",
  output_dir    = "N:/Arara/validation_random/results",
  verdicts_file = "N:/Arara/validation_random/verdicts.csv"
)
```

A clip marked more than once keeps the last verdict, and a message says
how many were marked again. For a `"random_detections"` round, give the
manifest that still has `inclusion_prob`, not a blind copy without it:
the precision tables then also give the precision weighted by
`1 / inclusion_prob`, which estimates the precision among all the
detections above the threshold rather than among the reviewed clips.

## Stage 2: calibration

The reviewed clips of every site calibrate the confidence score into a
probability of true detection. In FrogNet the manifest of site BEP came
out as `BEP2` and UEMS is abbreviated UEM, so `site_map` fixes the
names.

``` r

dir_proj <- "~/Library/CloudStorage/Box-Box/Meus Artigos/2026-codigo FrogNet"
sites <- c("UEMS", "MIM", "ARA", "BAI", "XAR", "REF", "BEP")
res <- calibrate(
  validation_files  = file.path(dir_proj,
                                paste0("validacao_por_clipe_", sites, ".csv")),
  prediction_tables = c(
    UEM = file.path(dir_proj, "BirdNET_SelectionTable_UEMS.txt"),
    MIM = file.path(dir_proj, "BirdNET_SelectionTable_MIM.txt"),
    ARA = file.path(dir_proj, "BirdNET_SelectionTable_ARA.txt"),
    BAI = file.path(dir_proj, "BirdNET_SelectionTable_BAI.txt"),
    XAR = file.path(dir_proj, "BirdNET_SelectionTable_XAR.txt"),
    REF = file.path(dir_proj, "BirdNET_SelectionTable_REF.txt"),
    BEP = file.path(dir_proj, "BirdNET_SelectionTable_BEP.txt")),
  output_dir = "~/FrogNet_calibration",
  site_map   = c(BEP2 = "BEP", UEMS = "UEM"),
  p_min = 0.95, min_detections_night = 1
)
res$comparison
```

The candidate models go from a logistic regression on logit(confidence)
to a binomial GLMM with random slopes by species and a site x species
intercept. They are compared by 5-fold cross-validation stratified by
site x species, and the best one is refitted to all the clips. Check the
comparison and the calibration curves (`calibration_curves.png`) before
using the probabilities. The calibrated detections of seven sites take
about 700 MB, so keep `output_dir` outside a synced folder.

`nightly_detection_history.csv` gives, for each site x species x night,
the number of detections with P(TP) \>= `p_min`, and whether the night
has a detection under the repetition rules k = 1, 2 and 3.

In FrogNet (2026), 6,304 reviewed clips (16 species x 7 sites) gave an
AUC of 0.93 for the hierarchical model against 0.82 for the score alone,
and about 3.15 million detections were scored.

## Stage 3: community matrices

Ordinations (PCoA, NMDS, RDA) have no layer that absorbs false
positives, so the entry rule is strict: at least two reliable detections
in the night, only the core species (reliable calibration at every
site), and site x month cells with at least five recorded nights.

``` r

build_community_matrices(
  "~/FrogNet_calibration/nightly_detection_history.csv",
  "~/FrogNet_community_matrices",
  core_species = c("boa_ran", "den_nan", "phy_alb", "rhi_dip", "sci_nas",
                   "lep_pod", "lep_fus", "pse_par", "pit_azu", "lys_lim"),
  k_min = 2, min_nights_month = 5
)
```

The six species with problematic calibration in FrogNet (`tra_typ`,
`boa_pun`, `den_min`, `sci_fuv`, `ade_dip`, `lep_ele`) stay out; use
them at most in a sensitivity analysis.

## A runnable example

The example validation table shipped with the package comes from
simulated data:

``` r

library(sheepdog)
val <- readr::read_csv(
  system.file("extdata", "validation_by_clip.csv", package = "sheepdog"),
  show_col_types = FALSE)
precision_by_bin(val, min_n = 3)
#> # A tibble: 4 × 8
#>   site  species_folder bin    n_reviewed n_positive precision precision_weighted
#>   <chr> <chr>          <fct>       <int>      <int>     <dbl>              <dbl>
#> 1 ARA   boa_ran        [0.5,…          3          1     0.333              0.375
#> 2 ARA   boa_ran        [0.6,…          2          1     0.5                0.5  
#> 3 ARA   boa_ran        [0.7,…          3          3     1                  1    
#> 4 ARA   boa_ran        [0.9,…          3          3     1                  1    
#> # ℹ 1 more variable: low_support <lgl>
nightly_presence(val)
#> # A tibble: 3 × 8
#>   site  species_folder    night n_clips n_reviewed n_positive presence 
#>   <chr> <chr>             <dbl>   <int>      <int>      <int> <chr>    
#> 1 ARA   boa_ran        20220110       3          3          3 confirmed
#> 2 ARA   boa_ran        20220111       4          3          1 confirmed
#> 3 ARA   boa_ran        20220115       5          5          4 confirmed
#> # ℹ 1 more variable: max_confidence_positive <dbl>
```
