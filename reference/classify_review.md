# Classify the reviewed clips

Reads the result of the manual review done in the BirdNET GUI and joins
it to the clip manifest. The GUI organises the review by moving each
clip into subfolders such as `<species>/Positive` and
`<species>/Negative`, so the verdict of each clip comes from the path
where it is found. Clips still in the species folder are not reviewed.

## Usage

``` r
classify_review(
  manifest,
  review_dir,
  positive_pattern = "positiv",
  negative_pattern = "negativ"
)
```

## Arguments

- manifest:

  A data frame (or tibble) or a character scalar. The clip manifest, one
  row per clip, or the path to `clip_manifest.csv`. Manifests written by
  v1.2.0 (`manifesto_clipes.csv`) are also read.

- review_dir:

  Character scalar, path to the folder with the reviewed clips (the
  `clips` folder of the validation package, after the review).

- positive_pattern, negative_pattern:

  Character scalars, regular expressions (case-insensitive) that
  identify the positive and negative folders in the path of each clip.

## Value

The manifest with two more columns: `verdict` (`"positive"`,
`"negative"`, `"not_reviewed"` or `"clip_missing"`) and `reviewed_path`,
the path where the clip was found. This is the table written to
`validation_by_clip.csv`.

## Examples

``` r
# The review in the BirdNET GUI leaves each clip in a Positive or Negative
# subfolder. Recreate that layout with empty files from a reviewed table
man <- system.file("extdata", "clip_manifest.csv", package = "sheepdog")
done <- read.csv(system.file("extdata", "validation_by_clip.csv",
                             package = "sheepdog"))
review_dir <- file.path(tempdir(), "clips_reviewed")
sub <- ifelse(done$verdict == "positive", "Positive",
              ifelse(done$verdict == "negative", "Negative", ""))
dest <- file.path(review_dir, done$species_folder, sub)
for (d in unique(dest)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
invisible(file.create(file.path(dest, done$clip_file)))

val <- classify_review(man, review_dir)
#> Clips in the manifest: 12
#>   negative: 3
#>   not_reviewed: 1
#>   positive: 8
table(val$verdict)
#> 
#>     negative not_reviewed     positive 
#>            3            1            8 
unlink(review_dir, recursive = TRUE)
```
