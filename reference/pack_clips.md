# Pack the clips into one zip per species

Zips each species folder of `<output_dir>/clips` into
`<output_dir>/packages/<species_folder>.zip`: light validation packages
to send to the reviewers.

## Usage

``` r
pack_clips(manifest, output_dir)
```

## Arguments

- manifest:

  A data frame, the clip manifest (one row per clip), as returned by
  [`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md).

- output_dir:

  Character scalar, the `output_dir` given to
  [`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md).

## Value

The paths of the zip files, invisibly.

## Examples

``` r
man <- read.csv(system.file("extdata", "clip_manifest.csv",
                            package = "sheepdog"))
out <- file.path(tempdir(), "packs")
# Empty files stand in for the clips cut by cut_clips()
dir.create(file.path(out, "clips", unique(man$species_folder)),
           recursive = TRUE, showWarnings = FALSE)
invisible(file.create(file.path(out, "clips", man$species_folder,
                                man$clip_file)))
zips <- pack_clips(man, out)
#> Package boa_ran.zip: 0 MB
#> 1 validation package(s) in /tmp/RtmpAGFSf1/packs/packages
basename(zips)
#> [1] "boa_ran.zip"
```
