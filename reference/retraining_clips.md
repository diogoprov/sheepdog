# Positive clips for retraining

Lists the clips confirmed as positive, ready to retrain the classifier.

## Usage

``` r
retraining_clips(validation)
```

## Arguments

- validation:

  A data frame (or tibble) returned by
  [`classify_review()`](https://provetelab.org/sheepdog/reference/classify_review.md),
  with columns `site`, `species_folder`, `verdict` and `confidence`. One
  row per clip.

## Value

A tibble with `site`, `species_code`, `species_folder`, `clip_file`,
`reviewed_path`, `confidence`, `night`, `recording_hour` and
`source_audio`.

## Examples

``` r
val <- read.csv(system.file("extdata", "validation_by_clip.csv",
                            package = "sheepdog"))
retraining_clips(val)
#>   site           species_code species_folder
#> 1  ARA Boana raniceps_boa-ran        boa_ran
#> 2  ARA Boana raniceps_boa-ran        boa_ran
#> 3  ARA Boana raniceps_boa-ran        boa_ran
#> 4  ARA Boana raniceps_boa-ran        boa_ran
#> 5  ARA Boana raniceps_boa-ran        boa_ran
#> 6  ARA Boana raniceps_boa-ran        boa_ran
#> 7  ARA Boana raniceps_boa-ran        boa_ran
#> 8  ARA Boana raniceps_boa-ran        boa_ran
#>                                         clip_file
#> 1 0.913_1_ARA01_20220110_000000_114.0s_117.0s.wav
#> 2 0.789_1_ARA01_20220110_013000_135.0s_138.0s.wav
#> 3 0.938_2_ARA01_20220110_013000_159.0s_162.0s.wav
#> 4 0.622_3_ARA01_20220111_030000_123.0s_126.0s.wav
#> 5   0.552_1_ARA01_20220115_120000_21.0s_24.0s.wav
#> 6   0.964_2_ARA01_20220115_120000_36.0s_39.0s.wav
#> 7   0.723_3_ARA01_20220115_120000_54.0s_57.0s.wav
#> 8   0.705_1_ARA01_20220115_193000_87.0s_90.0s.wav
#>                                                                        reviewed_path
#> 1 /project/revisado/boa_ran/Positive/0.913_1_ARA01_20220110_000000_114.0s_117.0s.wav
#> 2 /project/revisado/boa_ran/Positive/0.789_1_ARA01_20220110_013000_135.0s_138.0s.wav
#> 3 /project/revisado/boa_ran/Positive/0.938_2_ARA01_20220110_013000_159.0s_162.0s.wav
#> 4 /project/revisado/boa_ran/Positive/0.622_3_ARA01_20220111_030000_123.0s_126.0s.wav
#> 5   /project/revisado/boa_ran/Positive/0.552_1_ARA01_20220115_120000_21.0s_24.0s.wav
#> 6   /project/revisado/boa_ran/Positive/0.964_2_ARA01_20220115_120000_36.0s_39.0s.wav
#> 7   /project/revisado/boa_ran/Positive/0.723_3_ARA01_20220115_120000_54.0s_57.0s.wav
#> 8   /project/revisado/boa_ran/Positive/0.705_1_ARA01_20220115_193000_87.0s_90.0s.wav
#>   confidence    night recording_hour
#> 1     0.9128 20220110              0
#> 2     0.7886 20220110              1
#> 3     0.9380 20220110              1
#> 4     0.6215 20220111              3
#> 5     0.5516 20220115             12
#> 6     0.9642 20220115             12
#> 7     0.7233 20220115             12
#> 8     0.7050 20220115             19
#>                                   source_audio
#> 1 /project/audio/ARA/ARA01_20220110_000000.wav
#> 2 /project/audio/ARA/ARA01_20220110_013000.wav
#> 3 /project/audio/ARA/ARA01_20220110_013000.wav
#> 4 /project/audio/ARA/ARA01_20220111_030000.wav
#> 5 /project/audio/ARA/ARA01_20220115_120000.wav
#> 6 /project/audio/ARA/ARA01_20220115_120000.wav
#> 7 /project/audio/ARA/ARA01_20220115_120000.wav
#> 8 /project/audio/ARA/ARA01_20220115_193000.wav
```
