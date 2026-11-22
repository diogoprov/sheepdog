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
